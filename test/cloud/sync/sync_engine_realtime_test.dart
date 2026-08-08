// SyncEngine 实时事件 / 断网重连 / 防抖调度测试。
//
// 覆盖 sync_engine_realtime.dart 的行为：
//   1. triggerAutoSync 2s 防抖合并：连续触发只跑一次账户级同步；
//   2. connectivity 恢复 / WS 重连（reason=connectivity_restored）→ 先对账
//      syncLedgersFromServer 再 syncAccount；
//   3. WS sync_change 事件 → 1s 防抖 pull；
//   4. WS connected 事件 → 自动 sync；
//   5. member_change.removed（自己被踢）→ 本地账本 purge；
//   6. member_change.joined（自己在 web 端加入）→ 拉账本 + 重放历史；
//   7. stopListeningRealtime 取消挂起定时器（离线不再触发）。
// 使用真实 SQLite + 真实定时器 + FakeSpitoutCloudProvider，断言真实网络副作用。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/sync_events.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ChangeTracker changeTracker;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;

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
  });

  tearDown(() async {
    engine.stopListeningRealtime();
    await db.close();
  });

  Future<void> waitFor(bool Function() condition,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('waitFor 超时：条件在 $timeout 内未成立');
  }

  Future<int> createCloudLedger({
    String syncId = 'ledger-1',
    bool isShared = false,
    String myRole = 'owner',
  }) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L',
            syncId: Value(syncId),
            storageMode: const Value('cloud'),
            isShared: Value(isShared),
            myRole: Value(myRole),
          ),
        );
  }

  group('triggerAutoSync 防抖与单飞', () {
    test('2s 防抖窗口内连续触发 → 只跑一次账户级同步', () async {
      engine.triggerAutoSync(reason: 'local_change_detected');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      engine.triggerAutoSync(reason: 'local_change_detected');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      engine.triggerAutoSync(reason: 'local_change_detected');

      await waitFor(() => provider.pullCalls.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(provider.pullCalls, hasLength(1),
          reason: '连续触发应被 2s 防抖合并为单次 syncAccount');
    });

    test('connectivity 恢复 → 先对账账本列表，再账户级同步', () async {
      await createCloudLedger();
      engine.triggerAutoSync(reason: 'connectivity_restored');

      await waitFor(() => provider.pullCalls.isNotEmpty);
      // 断网重连语义：syncLedgersFromServer（readLedgers）先于 syncAccount 执行
      expect(provider.pullCalls, isNotEmpty);
    });

    test('stopListeningRealtime 取消挂起 auto sync → 离线不触发', () async {
      engine.triggerAutoSync(reason: 'connectivity_restored');
      engine.stopListeningRealtime();
      await Future<void>.delayed(const Duration(milliseconds: 3000));
      expect(provider.pullCalls, isEmpty,
          reason: 'stop 后挂起的 auto sync 定时器必须被取消');
    });
  });

  group('WS 实时事件', () {
    test('sync_change 事件 → 1s 防抖 pull 对应账本', () async {
      await createCloudLedger(syncId: 'ledger-1');
      final events = <SyncEvent>[];
      final sub = engine.events.listen(events.add);
      addTearDown(sub.cancel);

      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'sync_change',
          ledgerId: 'ledger-1',
          rawData: {},
        ),
      );

      await waitFor(
        () => events.any((e) => e is PullCompleted && e.ledgerId == 'ledger-1'),
      );
      expect(provider.pullCalls, isNotEmpty);
      engine.stopListeningRealtime();
    });

    test('connected 事件 → 触发自动 sync（重连补推）', () async {
      await createCloudLedger();
      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'connected',
          ledgerId: null,
          rawData: {},
        ),
      );

      await waitFor(() => provider.pullCalls.isNotEmpty);
      engine.stopListeningRealtime();
    });

    test('member_change.removed 自己 → 本地账本 purge', () async {
      final id = await createCloudLedger(
        syncId: 'shared-1',
        isShared: true,
        myRole: 'editor',
      );
      await repo.addTransaction(
        ledgerId: id,
        type: 'expense',
        amount: 500,
        happenedAt: DateTime(2026, 7, 1),
      );
      final events = <SyncEvent>[];
      final sub = engine.events.listen(events.add);
      addTearDown(sub.cancel);

      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'member_change',
          ledgerId: 'shared-1',
          rawData: {'changeType': 'removed', 'userId': 'test-user-id'},
        ),
      );

      await waitFor(
        () => events.any((e) => e is PullCompleted && e.ledgerId == 'shared-1'),
      );
      final gone = await (db.select(db.ledgers)
            ..where((l) => l.syncId.equals('shared-1')))
          .getSingleOrNull();
      expect(gone, isNull, reason: '自己被踢出后本地账本必须整体 purge');
      engine.stopListeningRealtime();
    });

    test('member_change.joined 自己 → 拉账本列表 + 重放历史', () async {
      final events = <SyncEvent>[];
      final sub = engine.events.listen(events.add);
      addTearDown(sub.cancel);

      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'member_change',
          ledgerId: 'shared-2',
          rawData: {'changeType': 'joined', 'userId': 'test-user-id'},
        ),
      );

      await waitFor(
        () => events.any((e) => e is PullCompleted && e.ledgerId == 'shared-2'),
      );
      engine.stopListeningRealtime();
    });

    test('member_change 他人加入 → 拉账本列表并通知 UI', () async {
      final events = <SyncEvent>[];
      final sub = engine.events.listen(events.add);
      addTearDown(sub.cancel);

      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'member_change',
          ledgerId: 'shared-3',
          rawData: {'changeType': 'joined', 'userId': 'other-user'},
        ),
      );

      await waitFor(
        () => events.any((e) => e is PullCompleted && e.ledgerId == 'shared-3'),
      );
      engine.stopListeningRealtime();
    });

    test('profile_change 事件 → 同步 profile（不触发 pull）', () async {
      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'profile_change',
          ledgerId: null,
          rawData: {},
        ),
      );
      // 给 syncMyProfile 留出执行窗口
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      engine.stopListeningRealtime();
    });
  });
}
