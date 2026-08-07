/// storage_mode 三路闸门单元测试。
///
/// 验证"纯本地账本(storage_mode='local')永不上云"的核心不变量:
///   1. ChangeTracker 源头过滤:本地账本变更不写 local_changes;
///   2. SyncEngine.sync() 对本地账本直接返回 0/0 不推送;
///   3. SyncEngine.fullPush() 对本地账本是 no-op。
///
/// 云端账本(storage_mode='cloud')与未知账本(不存在)的行为符合预期,确保不回归。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;

  setUp(() {
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

  tearDown(() async => db.close());

  group('ChangeTracker 源头闸门', () {
    test('本地账本(storage_mode=local)变更不写 local_changes', () async {
      final id = await repo.createLedger(name: 'local', storageMode: 'local');
      await changeTracker.recordLedgerChange(
        ledgerId: id,
        entityType: 'transaction',
        action: 'upsert',
        entityId: 1,
        entitySyncId: 'tx-sync-1',
      );
      final changes = await changeTracker.getUnpushedChangesForLedger(id);
      expect(changes, isEmpty,
          reason: '本地账本变更应被源头拦截,不进入 local_changes');
    });

    test('云端账本(storage_mode=cloud)变更正常写入 local_changes', () async {
      final id = await repo.createLedger(name: 'cloud', storageMode: 'cloud');
      await changeTracker.recordLedgerChange(
        ledgerId: id,
        entityType: 'transaction',
        action: 'upsert',
        entityId: 1,
        entitySyncId: 'tx-sync-1',
      );
      final changes = await changeTracker.getUnpushedChangesForLedger(id);
      // createLedger 自身会登记一条 ledger:upsert（规则4:数据层驱动同步）,
      // 这里只关注手工记录的 transaction 变更是否通过闸门。
      final txChanges =
          changes.where((c) => c.entityType == 'transaction').toList();
      expect(txChanges, hasLength(1),
          reason: '云端账本变更应正常进入 local_changes');
      expect(changes.where((c) => c.entityType == 'ledger'), hasLength(1),
          reason: '新建云端账本应自动登记 ledger:upsert');
    });

    test('未知账本(不存在)变更仍写入 local_changes', () async {
      await changeTracker.recordLedgerChange(
        ledgerId: 999,
        entityType: 'transaction',
        action: 'upsert',
        entityId: 1,
        entitySyncId: 'tx-sync-1',
      );
      final changes = await changeTracker.getUnpushedChangesForLedger(999);
      expect(changes, hasLength(1),
          reason: '未知账本变更不应被闸门误伤');
    });
  });

  group('SyncEngine 入口闸门', () {
    test('sync() 对本地账本直接返回 0/0 不推送', () async {
      final id = await repo.createLedger(name: 'local', storageMode: 'local');
      final result = await engine.sync(ledgerId: id.toString());
      expect(result.pushed, 0);
      expect(result.pulled, 0);
    });

    test('pullIncremental 对本地账本直接返回 0 不发起云端拉取', () async {
      final id = await repo.createLedger(name: 'local', storageMode: 'local');
      final pulled = await engine.pullIncremental(ledgerId: id);
      expect(pulled, 0,
          reason: '本地账本下拉刷新不得触发云端增量拉取');
    });

    test('pullIncrementalWithHeal 对本地账本直接返回空 outcome', () async {
      final id = await repo.createLedger(name: 'local', storageMode: 'local');
      final outcome = await engine.pullIncrementalWithHeal(ledgerId: id);
      expect(outcome.incremental, 0);
      expect(outcome.didHeal, isFalse);
      expect(outcome.gapRemaining, isFalse);
    });

    test('fullPush 对本地账本是 no-op(不抛异常)', () async {
      final id = await repo.createLedger(name: 'local', storageMode: 'local');
      // 本地账本不应触发任何推送;这里只验证不抛异常、安全跳过。
      await engine.fullPush(ledgerId: id);
    });
  });
}
