// SyncCoordinator 行为测试：真实 SQLite(in-memory) + 真实 SyncEngine +
// FakeSpitoutCloudProvider，验证「local_changes 未推送行 → 250ms 防抖 →
// triggerAutoSync → 自动同步推送」这一数据驱动同步触发链路（依赖倒置端口注入，
// UI 不直连 syncEngine）。
//
// 设计意图：同步触发必须由 local_changes 表的数据变更驱动；本测试覆盖
// 防抖合并、空行回显跳过、dispose 取消挂起定时器三类核心行为，并用
// provider.pushedBatches / pullCalls 断言真实副作用，而非 mock 方法调用。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_coordinator.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ChangeTracker changeTracker;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;
  late SyncCoordinator coordinator;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    changeTracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: changeTracker);
    provider = FakeSpitoutCloudProvider();
    engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: changeTracker,
      repo: repo,
    );
    coordinator = SyncCoordinator(localChanges: changeTracker, engine: engine)
      ..start();
  });

  tearDown(() async {
    coordinator.dispose();
    await db.close();
  });

  /// 建一本已绑定云端的账本。
  Future<int> createCloudLedger() async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L',
            syncId: const Value('ledger-1'),
            storageMode: const Value('cloud'),
          ),
        );
  }

  /// 往账本里写入一条交易（经 repo 登记 local_changes）。
  Future<void> insertTx(int ledgerId, String txSyncId) async {
    await repo.insertTransactionsBatch([
      TransactionsCompanion.insert(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 9950,
        syncId: Value(txSyncId),
      ),
    ]);
  }

  /// 轮询等待条件成立（自动同步含 2s 防抖，避免固定 sleep 造成 flaky）。
  Future<void> waitFor(bool Function() condition,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('waitFor 超时：条件在 $timeout 内未成立');
  }

  group('SyncCoordinator 数据驱动同步', () {
    test('启动后无未推送变更 → 不触发任何同步', () async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(provider.pushedBatches, isEmpty);
      expect(provider.pullCalls, isEmpty);
    });

    test('写入未推送变更 → 防抖后自动同步并推送到云端', () async {
      final ledgerId = await createCloudLedger();
      await insertTx(ledgerId, 'tx-1');
      // 防抖窗口内不应有网络副作用
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(provider.pullCalls, isEmpty);

      await waitFor(() => provider.pushedBatches.isNotEmpty);
      expect(provider.pushedBatches, hasLength(1));
      // fullPush 批次可能先推 ledger 实体，再推交易实体：按 syncId 定位断言。
      final txChange = provider.pushedBatches.first
          .where((c) => c['entity_sync_id'] == 'tx-1')
          .toList();
      expect(txChange, hasLength(1));
      expect(txChange.first['action'], 'upsert');

      // 推送完成后 local_changes 全部回填 pushedAt
      final remaining = await changeTracker.getUnpushedCount();
      expect(remaining, 0);
    });

    test('防抖窗口内连续写入多条 → 合并为一次自动同步', () async {
      final ledgerId = await createCloudLedger();
      await insertTx(ledgerId, 'tx-1');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await insertTx(ledgerId, 'tx-2');

      await waitFor(() => provider.pushedBatches.isNotEmpty);
      expect(provider.pushedBatches, hasLength(1),
          reason: '高频写入应被双层防抖合并为单次同步');
      final txIds = provider.pushedBatches.first
          .map((c) => c['entity_sync_id'] as String?)
          .whereType<String>()
          .where((id) => id.startsWith('tx-'))
          .toList();
      expect(txIds, containsAll(['tx-1', 'tx-2']),
          reason: '两条未推送交易变更应随同一次同步全部推送');
    });

    test('markPushed 空行回显 → 取消挂起防抖，不再触发冗余同步', () async {
      final ledgerId = await createCloudLedger();
      await insertTx(ledgerId, 'tx-1');
      final unpushed = await changeTracker.getUnpushedChangesForLedger(ledgerId);
      await changeTracker.markPushed(
        unpushed.map((c) => c.id).toList(),
      );
      // 越过防抖 + 自动同步窗口，验证没有任何网络副作用
      await Future<void>.delayed(const Duration(milliseconds: 3500));
      expect(provider.pullCalls, isEmpty,
          reason: 'markPushed 后的空行回显不应再触发自动同步');
      expect(provider.pushedBatches, isEmpty);
    });

    test('dispose 取消挂起防抖 → 不再触发同步', () async {
      final ledgerId = await createCloudLedger();
      await insertTx(ledgerId, 'tx-1');
      coordinator.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 3500));
      expect(provider.pushedBatches, isEmpty);
      expect(provider.pullCalls, isEmpty);
    });

    test('重复 start 幂等：旧订阅先取消再重建，仍能触发', () async {
      coordinator.start();
      final ledgerId = await createCloudLedger();
      await insertTx(ledgerId, 'tx-1');
      await waitFor(() => provider.pushedBatches.isNotEmpty);
      expect(provider.pushedBatches, hasLength(1));
    });
  });
}
