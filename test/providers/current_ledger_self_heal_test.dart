// 「当前账本失效自愈」回归测试（TDD 红→绿）。
//
// 背景：清账本的路径很多（切本地模式全量 purge / 换账号 per-ledger GC /
// 手动删当前账本），逐路径点状修复容易漏。本组测试
// 锁定统一的防御性设计——不关心「谁清的」，只监听「当前账本解析为 null」
// 这一个事实，自动回退到本地第一个账本；确无账本则重置哨兵 0。
//
// 覆盖场景：
//   1. selectFirstLedger 空表 + 僵尸 ID → 显式重置哨兵 0（改动3）；
//   2. 当前账本被删、本地仍有其它账本 → 自愈回退第一个账本（改动4 主监听）；
//   3. 当前账本被删、本地已无账本 → 自愈重置哨兵 0（改动4 主监听空表分支）；
//   4. 哨兵 0 + 账本延迟到位 + 刷新 tick → 回退第一个账本（改动4 兜底监听）；
//   5. 启动竞态：prefs 保存的是「非首个」账本时，自愈不得覆盖用户上次选择
//      （triggerId 重校验守卫，防止启动窗口期 watchLedger(0) 的 null 误触发）。
//
// 防串扰设计：与 current_ledger_persist_test.dart 相同——每用例独立内存库 +
// resetGlobalTestState() 复位 prefs（setUp/tearDown 双保险）。

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/refresh_ticks.dart';

/// 插入一个账本并返回其自增 id。
Future<int> _insertLedger(SpitoutDatabase db, String name) async {
  return db.into(db.ledgers).insert(LedgersCompanion.insert(name: name));
}

/// 按 id 删除账本行（模拟 purge / GC / 手动删除的最终落库效果，
/// drift 的表监听会因此让 watchLedger 重新发射）。
Future<void> _deleteLedger(SpitoutDatabase db, int id) async {
  await (db.delete(db.ledgers)..where((t) => t.id.equals(id))).go();
}

/// 激活 currentLedgerPersistProvider（含启动解析 + 自愈监听），
/// 并让出事件循环等待异步链路（prefs 读取 → db 校验 → state 写入 → 自愈
/// 二次查询）彻底收敛。in-memory 库单次往返在毫秒级，400ms 足够覆盖多轮。
Future<void> _activateAndSettle(
  ProviderContainer container, {
  Map<String, Object>? initialPrefs,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs ?? {});
  // 先强制仓储实例就绪（与 provider 体内读取的是同一实例）。
  container.read(repositoryProvider);
  // Riverpod 3 下 read 一次后 provider 会被暂停，内部 ref.listen 自愈监听不会触发；
  // 仿照 app.dart 根组件的常驻 watch，保持一个真实监听直到 container dispose。
  container.listen(currentLedgerPersistProvider, (_, _) {});
  // 显式等待启动解析完成（FutureProvider 可直接 await），再等待监听链路收敛。
  await container.read(currentLedgerPersistProvider.future);
  await Future.delayed(const Duration(milliseconds: 400));
}

/// 等待自愈异步链路（drift 流重发 → getAllLedgers → state 写入）完成。
Future<void> _settleHeal() =>
    Future.delayed(const Duration(milliseconds: 400));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetGlobalTestState());
  tearDown(() => resetGlobalTestState());

  test('selectFirstLedger：空表 + 僵尸 ID → 显式重置哨兵 0', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    SharedPreferences.setMockInitialValues({});
    container.read(repositoryProvider);
    // 模拟换账号 GC 后残留的僵尸 id：内存态指向早已不存在的账本。
    container.read(currentLedgerIdProvider.notifier).set(999);

    await selectFirstLedger(container.read);

    expect(container.read(currentLedgerIdProvider), 0,
        reason: '空表时必须清掉僵尸 ID 回到哨兵 0，而不是保留失效 id 令首页永久空状态');
    container.dispose();
    await db.close();
  });

  test('自愈：当前账本被删、本地仍有其它账本 → 自动回退第一个账本', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final first = await _insertLedger(db, '第一个账本');
    final second = await _insertLedger(db, '第二个账本');
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    // 启动解析：prefs 指向第二个账本（有效），沿用用户选择。
    await _activateAndSettle(container,
        initialPrefs: {'current_ledger_id': second});
    expect(container.read(currentLedgerIdProvider), second);

    // 模拟任意清账本路径把当前账本删掉（purge / GC / 手动删）。
    await _deleteLedger(db, second);
    await _settleHeal();

    expect(container.read(currentLedgerIdProvider), first,
        reason: '当前账本失效且本地仍有账本时，自愈必须回退到第一个账本');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('current_ledger_id'), first,
        reason: '持久化监听应把自愈结果写回 prefs，保证下次启动稳定恢复');
    container.dispose();
    await db.close();
  });

  test('自愈：当前账本被删、本地已无账本 → 重置哨兵 0（不残留僵尸 ID）', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final only = await _insertLedger(db, '唯一账本');
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    await _activateAndSettle(container,
        initialPrefs: {'current_ledger_id': only});
    expect(container.read(currentLedgerIdProvider), only);

    // 唯一账本被删 → 库空。
    await _deleteLedger(db, only);
    await _settleHeal();

    expect(container.read(currentLedgerIdProvider), 0,
        reason: '确无账本时必须回到哨兵 0，由真正的空状态引导新建，而非僵尸 ID');
    container.dispose();
    await db.close();
  });

  test('兜底：哨兵 0 + 账本延迟到位 + 刷新 tick → 回退第一个账本', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    // 启动时空库：解析后保持哨兵 0。
    await _activateAndSettle(container, initialPrefs: {});
    expect(container.read(currentLedgerIdProvider), 0);

    // 模拟换账号后新账本延迟同步到位，随后同步链路 bump 账本列表刷新 tick。
    final arrived = await _insertLedger(db, '同步到位的账本');
    container.read(ledgerListRefreshProvider.notifier).tick();
    await _settleHeal();

    expect(container.read(currentLedgerIdProvider), arrived,
        reason: '账本到位后必须自动选中首个可用账本，避免空状态卡死');
    container.dispose();
    await db.close();
  });

  test('启动竞态：prefs 保存非首个账本时，自愈不得覆盖用户上次选择', () async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    await _insertLedger(db, '第一个账本');
    final saved = await _insertLedger(db, '用户上次选中的第二个账本');
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    // 启动瞬间 id=0，watchLedger(0) 会真实发射 AsyncData(null)（非 Loading），
    // 自愈与启动解析的 prefs 恢复并发竞跑——无论谁先完成，最终必须收敛到 saved。
    await _activateAndSettle(container,
        initialPrefs: {'current_ledger_id': saved});

    expect(container.read(currentLedgerIdProvider), saved,
        reason: '自愈是兜底而非抢跑：启动窗口期不得把用户保存的非首个账本覆盖成第一个');
    container.dispose();
    await db.close();
  });
}
