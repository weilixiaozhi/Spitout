// currentLedgerPersistProvider 回退逻辑单元测试。
//
// 验证「启动时恢复 current_ledger_id 并校验本地存在性，失效/缺失则回退本地第一个
// 账本」的四种场景。覆盖此前未测试的兜底分支。
//
// 防串扰设计：每个用例都显式用 resetGlobalTestState() 复位 SharedPreferences（setUp
// 与 tearDown 双保险），插入单一账本并捕获其自增 id 隔离其它用例残留。

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/providers/core/database_providers.dart';

/// 打开独立内存数据库，并插入一个账本，返回其自增 id。
/// 每个用例使用各自独立的数据库实例，配合 prefs 复位，避免跨用例状态串扰。
Future<int> _insertSingleLedger(SpitoutDatabase db, String name) async {
  return db.into(db.ledgers).insert(LedgersCompanion.insert(name: name));
}

/// 触发 currentLedgerPersistProvider 的启动解析，并等待其完成。
///
/// 解析内部读取 repositoryProvider 拿到 repo，再异步校验账本存在性，最后把
/// 生效的 ledgerId 写入 currentLedgerIdProvider.notifier.state。FutureProvider
/// 允许直接 await `.future` 等解析收敛（含可能的 prefs 写回），避免竞态。
Future<void> _triggerAndAwaitResolve(
  ProviderContainer container, {
  Map<String, Object>? initialPrefs,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs ?? {});
  // 同步读取 repositoryProvider 强制仓储实例就绪（与解析内部读取的是同一实例）。
  container.read(repositoryProvider);
  // 触发启动解析并等待完成（读取 prefs + 校验账本存在性 + 写回 currentLedgerIdProvider）。
  await container.read(currentLedgerPersistProvider.future);
  // 让出事件循环，等待监听回调（如持久化写回）彻底收敛。
  await Future.delayed(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetGlobalTestState());
  tearDown(() => resetGlobalTestState());

  test('持久化的账本仍有效 → 沿用用户上次选择（不回退）', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final id = await _insertSingleLedger(db, '有效账本');
    // 预设 prefs 为真实存在的账本 id。
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    await _triggerAndAwaitResolve(container, initialPrefs: {'current_ledger_id': id});

    expect(container.read(currentLedgerIdProvider), id);
    container.dispose();
    await db.close();
  });

  test('持久化的账本已不存在 → 回退到本地第一个账本', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final id = await _insertSingleLedger(db, '回退账本');
    // 预设一个不存在的账本 id（777），应回退到本地第一个账本 id。
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    await _triggerAndAwaitResolve(container, initialPrefs: {'current_ledger_id': 777});

    expect(container.read(currentLedgerIdProvider), id);
    container.dispose();
    await db.close();
  });

  test('无持久化值（首次安装/覆盖更新清空）→ 回退到本地第一个账本', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final id = await _insertSingleLedger(db, '首个账本');
    // 无 prefs 存储，应回退到本地第一个账本 id。
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    await _triggerAndAwaitResolve(container, initialPrefs: {});

    expect(container.read(currentLedgerIdProvider), id);
    container.dispose();
    await db.close();
  });

  test('本地确实无任何账本 → 保持未选中哨兵，当前账本为 null', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    // 不插入任何账本；无 prefs 存储。
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    await _triggerAndAwaitResolve(container, initialPrefs: {});

    // 无账本时 resolved 为 null → currentLedgerIdProvider 保持哨兵 0；
    // 同时 currentLedgerProvider（仓储已就绪）对 ledgerId=0 发射 null，即真正的空状态。
    expect(container.read(currentLedgerIdProvider), 0);
    expect(container.read(currentLedgerProvider).value, isNull);
    container.dispose();
    await db.close();
  });

  // 回归测试：复现「新用户引导」的真实时序 —— 启动解析先对空库跑过
  // （只执行一次且不会重跑），之后引导流程才 seed 出账本。此前无任何用例
  // 覆盖该顺序，导致 d961918 引入的回归（重装后默认账本未选中）被漏放行。
  test('空库先触发启动解析 → 后插入账本 → selectFirstLedger 显式选中并写回 prefs', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    // 第一步：空库触发启动解析（模拟 main() 预加载阶段），应保持哨兵 0。
    await _triggerAndAwaitResolve(container, initialPrefs: {});
    expect(container.read(currentLedgerIdProvider), 0,
        reason: '空库时启动解析不应选中任何账本');

    // 第二步：模拟引导完成后 SeedService.ensureSeed 创建默认账本。
    // 注意启动解析是一次性的，此时重新 read provider 不会重跑解析。
    final id = await _insertSingleLedger(db, '引导默认账本');
    container.read(currentLedgerPersistProvider);
    await Future.delayed(const Duration(milliseconds: 150));
    expect(container.read(currentLedgerIdProvider), 0,
        reason: '启动解析不会重跑，仅靠它无法感知账本从无到有');

    // 第三步：引导完成处显式调用 selectFirstLedger（welcome_page 的修复点），
    // 应选中首个账本并把 id 写回 prefs，保证下次启动稳定恢复。
    await selectFirstLedger(container.read);
    expect(container.read(currentLedgerIdProvider), id);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('current_ledger_id'), id);

    container.dispose();
    await db.close();
  });

  test('selectFirstLedger 幂等：当前选中账本仍有效时不覆盖用户选择', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    // 插入两个账本，用户当前选中第二个（非 first），selectFirstLedger 不应改动。
    await _insertSingleLedger(db, '第一个账本');
    final second = await _insertSingleLedger(db, '第二个账本');
    SharedPreferences.setMockInitialValues({'current_ledger_id': second});
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container.read(repositoryProvider);
    container.read(currentLedgerIdProvider.notifier).set(second);

    await selectFirstLedger(container.read);

    expect(container.read(currentLedgerIdProvider), second,
        reason: '已选中且有效的账本必须被尊重，不得被回退到 first');
    container.dispose();
    await db.close();
  });

  // 回归测试：复现「本地备份恢复」场景 —— 恢复前 currentLedgerIdProvider 指向旧库
  // 账本 id（来自 prefs），恢复后新库账本 id 全变。此前恢复分支只 invalidate 不重选，
  // 导致 currentLedgerIdProvider 仍指向旧 id、currentLedgerProvider 查不到 → 首页误判
  // 空状态，只能靠重启触发 currentLedgerPersistProvider 的启动解析回退。现恢复后复用
  // selectFirstLedger 显式校验：当前 id 在新库无效 → 回退新库首个账本并写回 prefs。
  test('本地备份恢复后：旧账本 id 在新库失效 → 回退新库首个账本并写回 prefs', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final newLedger = await _insertSingleLedger(db, '恢复后的账本');
    // 模拟恢复前 prefs/内存里残留的旧账本 id（旧库已不存在于新库）。
    SharedPreferences.setMockInitialValues({'current_ledger_id': 999});
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    // 恢复前 currentLedgerIdProvider 已被旧值占据（相当于启动时解析出的旧 id）。
    container.read(repositoryProvider);
    container.read(currentLedgerIdProvider.notifier).set(999);

    // 恢复成功 → invalidate 新库 → 复用 selectFirstLedger 校验并回退（local_backup_page 的修复点）。
    await selectFirstLedger(container.read);

    expect(container.read(currentLedgerIdProvider), newLedger,
        reason: '旧 id 在新库无效时必须回退到新库首个账本，而非保持失效的旧 id');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('current_ledger_id'), newLedger,
        reason: '回退后必须把生效的账本 id 写回 prefs，保证下次启动稳定恢复');
    container.dispose();
    await db.close();
  });
}
