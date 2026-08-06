/// 刀1 测试:checkAccountHealth(账户级) vs checkLedgerHealth(账本级) 口径拆分。
///
/// 覆盖:
/// 1. checkAccountHealth(carrierLedgerId: null) → 返回 null(无云端账本),
///    且不发起任何 stats 请求;
/// 2. 报告载体标记:checkAccountHealth 报告带 carrierLedgerId,
///    checkLedgerHealth 报告 carrierLedgerId == null(刀3 UI 显隐依赖);
/// 3. 口径差异:账户级 unpushed 用**全局**(跨账本),账本级用 **per-ledger**;
/// 4. 无 syncId 账本 → 直接 error,不发起 stats 请求(与 checkLedgerHealth 同款
///    DEEP 修复,账户级面板同样不能拿本地自增 id 拼 server 路径);
/// 5. 远端计数正确透传(ledgerStatsOverrides 桩)。
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart'
    show SpitoutCloudLedgerStats;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

Future<(SpitoutDatabase, ChangeTracker, LocalRepository, FakeSpitoutCloudProvider,
    SyncEngine)> _harness() async {
  final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
  final changeTracker = ChangeTracker(db);
  final repo = LocalRepository(db, changeTracker: changeTracker);
  final provider = FakeSpitoutCloudProvider();
  final engine = SyncEngine(
    db: db,
    provider: provider,
    changeTracker: changeTracker,
    repo: repo,
  );
  return (db, changeTracker, repo, provider, engine);
}

/// 插入一个云端账本(有 syncId),返回本地 id。
Future<int> _insertCloudLedger(
  SpitoutDatabase db, {
  required String name,
  required String syncId,
}) {
  return db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          name: name,
          syncId: Value(syncId),
          storageMode: const Value('cloud'),
        ),
      );
}

void main() {
  setUp(() {
    // recordLedgerChange → ChangeTracker._insert → logger 需要注册
    // MethodChannel handler,必须先把 Flutter binding 初始化。
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGlobalTestState();
    SharedPreferences.setMockInitialValues({});
  });

  group('checkAccountHealth(账户级)', () {
    test('carrierLedgerId 为 null(无云端账本)→ 返回 null,不发起 stats 请求', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final report = await engine.checkAccountHealth();

      expect(report, isNull);
      expect(provider.readLedgerStatsCalls, 0,
          reason: '无载体账本时不应发起任何远端请求');
    });

    test('报告带 carrierLedgerId;checkLedgerHealth 不带(刀3 显隐依赖)', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final ledgerA = await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      provider.ledgerStatsOverrides['ledger-a'] = const SpitoutCloudLedgerStats(
        transactionCount: 0,
        transactionTotal: 0,

        categoryCount: 0,
        categoryTotal: 0,
      );

      final accountReport = await engine.checkAccountHealth(carrierLedgerId: ledgerA);
      final ledgerReport = await engine.checkLedgerHealth(ledgerId: ledgerA);

      expect(accountReport, isNotNull);
      expect(accountReport!.carrierLedgerId, ledgerA,
          reason: '账户级报告必须声明载体账本,UI 据此决定「当前账本」组显隐');
      expect(ledgerReport.carrierLedgerId, isNull,
          reason: '账本级报告(自愈闸门)不带载体标记');
    });

    test('unpushed 用全局口径(跨账本);checkLedgerHealth 用 per-ledger', () async {
      final (db, changeTracker, _, _, engine) = await _harness();
      addTearDown(db.close);

      final ledgerA = await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      final ledgerB = await _insertCloudLedger(db, name: 'B', syncId: 'ledger-b');

      // 账本 A:1 条未推送变更;账本 B:2 条未推送变更。
      await changeTracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 11,
        entitySyncId: 'tx-11',
        ledgerId: ledgerA,
        action: 'create',
      );
      await changeTracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 21,
        entitySyncId: 'tx-21',
        ledgerId: ledgerB,
        action: 'create',
      );
      await changeTracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 22,
        entitySyncId: 'tx-22',
        ledgerId: ledgerB,
        action: 'create',
      );

      final accountReport = await engine.checkAccountHealth(carrierLedgerId: ledgerA);
      final ledgerReport = await engine.checkLedgerHealth(ledgerId: ledgerA);

      expect(accountReport!.unpushedChanges, 3,
          reason: '账户级面板展示全账户未推送变更(跨账本)');
      expect(ledgerReport.unpushedChanges, 1,
          reason: '账本级自愈闸门只认本账本未推送变更,排除其他账本的假阳性');
    });

    test('本地无 syncId 账本 → 直接 error,不发起 stats 请求', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final localId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Local',
              storageMode: const Value('local'),
            ),
          );

      final report = await engine.checkAccountHealth(carrierLedgerId: localId);

      expect(report, isNotNull);
      expect(report!.error, isNotNull,
          reason: '无 syncId 必须判定检测失败,不能拿本地 id 拼 server 路径');
      expect(provider.readLedgerStatsCalls, 0,
          reason: '删兜底后不应发起必然 404 的 stats 请求');
    });

    test('远端 stats 计数正确透传到账户级报告', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final ledgerA = await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      // 本地 2 条已同步交易(有 syncId),远端报 3 条 —— 模拟云端多 1。
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerA,
              type: 'expense',
              amount: 10000,
              categoryId: const Value(null),
              syncId: const Value('tx-1'),
            ),
          );
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerA,
              type: 'expense',
              amount: 5000,
              categoryId: const Value(null),
              syncId: const Value('tx-2'),
            ),
          );
      provider.ledgerStatsOverrides['ledger-a'] = const SpitoutCloudLedgerStats(
        transactionCount: 3,
        transactionTotal: 3,

        categoryCount: 1,
        categoryTotal: 1,
      );

      final report = await engine.checkAccountHealth(carrierLedgerId: ledgerA);

      expect(report, isNotNull);
      expect(report!.ledgerTx.local, 2);
      expect(report.ledgerTx.remote, 3);
      expect(report.hasDiff, isTrue,
          reason: '本地 2 条 vs 远端 3 条 → 面板应提示有差异');
      expect(report.categories.remote, 1);
    });

    test('纯本地账本交易不计入账户级 totalTx(不上云不制造假差异)', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final ledgerA = await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      final localId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Local',
              storageMode: const Value('local'),
            ),
          );
      // 云端账本 1 条 + 本地账本 2 条;本地账本交易同样有本地 UUID syncId。
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerA,
              type: 'expense',
              amount: 10000,
              categoryId: const Value(null),
              syncId: const Value('tx-cloud-1'),
            ),
          );
      for (final sid in ['tx-local-1', 'tx-local-2']) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                ledgerId: localId,
                type: 'expense',
                amount: 500,
                categoryId: const Value(null),
                syncId: Value(sid),
              ),
            );
      }
      provider.ledgerStatsOverrides['ledger-a'] = const SpitoutCloudLedgerStats(
        transactionCount: 1,
        transactionTotal: 1,
        categoryCount: 0,
        categoryTotal: 0,
      );

      final report = await engine.checkAccountHealth(carrierLedgerId: ledgerA);

      expect(report, isNotNull);
      expect(report!.totalTx.local, 1,
          reason: '纯本地账本不上云,其交易不得计入账户级全量口径');
      expect(report.totalTx.remote, 1);
      expect(report.hasDiff, isFalse,
          reason: '本地账本交易计入后会永久显示"本地比云端多"的假差异');
    });
  });

  group('checkAccountHealth 输出剥离(不传 carrierLedgerId)', () {
    /// 不传参 = 用户当前选中的是本地账本。
    ///
    /// 此时内部仍需按 id 升序自选一本云账本去打 /stats —— 那是账户级
    /// totalTx / categories 的唯一数据源,不能省。但「自选」纯属工程锚点,
    /// 没有任何用户语义,绝不能外泄成 carrierLedgerId,否则 UI 会顶着
    /// 「当前账本」表头显示一本用户根本没选中的账本的数据。
    test('不传参 → ledgerTx 剥离为 missing、carrierLedgerId 为 null,但账户级计数仍真实',
        () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final ledgerA =
          await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      // 本地 2 条已同步交易挂在 A 上。
      for (final sid in ['tx-1', 'tx-2']) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                ledgerId: ledgerA,
                type: 'expense',
                amount: 1000,
                categoryId: const Value(null),
                syncId: Value(sid),
              ),
            );
      }
      provider.ledgerStatsOverrides['ledger-a'] = const SpitoutCloudLedgerStats(
        transactionCount: 7,
        transactionTotal: 9,

        categoryCount: 4,
        categoryTotal: 4,
      );

      final report = await engine.checkAccountHealth();

      expect(report, isNotNull);
      // 剥离:当前账本组的数据源被抹掉,UI 据此隐藏「当前账本」组。
      expect(report!.carrierLedgerId, isNull,
          reason: '自选锚点是内部工程细节,绝不外泄为 carrierLedgerId');
      expect(report.ledgerTx.local, 0);
      expect(report.ledgerTx.remote, -1,
          reason: 'ledgerTx 必须为 SyncCountPair.missing(),不得透传自选账本口径');
      // 账户级面板不降级:内部锚点照常打 stats,totalTx / categories 保持真实。
      expect(report.totalTx.remote, 9, reason: '账户级 totalTx 必须来自真实 stats');
      expect(report.categories.remote, 4,
          reason: '账户级 categories 必须来自真实 stats');
      expect(provider.readLedgerStatsCalls, 1,
          reason: '内部锚点仍要打一次 stats,否则账户级面板会降级为占位值');
    });

    test('不传参且 stats 抛错 → error 分支同样剥离(ledgerTx missing、carrier null)',
        () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      // 不注册 override → Fake 抛错,走 error 分支。
      provider.failingReadLedgerStats = true;

      final report = await engine.checkAccountHealth();

      expect(report, isNotNull);
      expect(report!.error, isNotNull);
      expect(report.carrierLedgerId, isNull,
          reason: 'error 分支同样不得外泄自选锚点');
      expect(report.ledgerTx.remote, -1);
      expect(report.ledgerTx.local, 0,
          reason: 'ledgerTx 走 missing(),local 恒 0');
    });

    test('显式传参 → 维持原语义(ledgerTx 真实、carrierLedgerId 回填)', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final ledgerA =
          await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      final ledgerB =
          await _insertCloudLedger(db, name: 'B', syncId: 'ledger-b');
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerB,
              type: 'expense',
              amount: 1000,
              categoryId: const Value(null),
              syncId: const Value('tx-b1'),
            ),
          );
      provider.ledgerStatsOverrides['ledger-b'] = const SpitoutCloudLedgerStats(
        transactionCount: 5,
        transactionTotal: 5,

        categoryCount: 0,
        categoryTotal: 0,
      );

      // 传 B(不是 id 升序第一本 A)→ 必须以 B 为锚点,证明不再绑死 A。
      final report = await engine.checkAccountHealth(carrierLedgerId: ledgerB);

      expect(report, isNotNull);
      expect(report!.carrierLedgerId, ledgerB);
      expect(report.ledgerTx.local, 1);
      expect(report.ledgerTx.remote, 5);
      expect(ledgerA, lessThan(ledgerB), reason: 'A 的 id 更小,确保测的是非首本');
    });
  });

  group('anySelfHealBroken(账户级熔断)', () {
    test('无任何熔断 → false', () async {
      final (db, _, _, _, engine) = await _harness();
      addTearDown(db.close);

      expect(engine.anySelfHealBroken(), isFalse);
    });

    test('任一云账本熔断 → true(与当前选中账本完全解耦)', () async {
      final (db, _, _, _, engine) = await _harness();
      addTearDown(db.close);

      engine.debugMarkSelfHealBroken('42');

      expect(engine.anySelfHealBroken(), isTrue,
          reason: 'S4:A 熔断、选中 B 或本地账本时,状态行同样要红字');
      expect(engine.selfHealBroken('42'), isTrue);
      expect(engine.selfHealBroken('7'), isFalse,
          reason: 'per-ledger 口径不受影响');
    });

    test('熔断已过期 → false', () async {
      final (db, _, _, _, engine) = await _harness();
      addTearDown(db.close);

      engine.debugMarkSelfHealBroken('42',
          duration: const Duration(milliseconds: -1));

      expect(engine.anySelfHealBroken(), isFalse);
    });
  });
}
