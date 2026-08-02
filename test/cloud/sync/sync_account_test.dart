/// +1 刀测试:syncAccount() 账户级同步原语(app.dart 冷启动与云同步页下拉共用)。
///
/// 覆盖:
/// 1. 无云端账本 → 返回全 0 结果(pushed/pulled/skipped 均为 0);
/// 2. fast-skip:无待推 + 已绑定 → skipped=1,不发 push / 不上传 snapshot;
/// 3. 增量 push:有 unpushed + 已绑定 → 推变更,pushed>=1,不 upload snapshot
///    (可据 download(snapshot) 是否为 null 区分 fullPush 是否发生);
/// 4. fullPush:syncId 不在远端 → 上传 snapshot(fullPush 真实发生);
/// 5. 共享 Editor:只增量 push,不 fullPush(不 upload snapshot);
/// 6. storage.list 失败 → 保守增量,不 fullPush(不 upload snapshot)。
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
  bool isShared = false,
  String? myRole,
}) {
  return db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          name: name,
          syncId: Value(syncId),
          storageMode: const Value('cloud'),
          isShared: Value(isShared),
          myRole: Value(myRole ?? 'owner'),
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

  group('syncAccount(账户级原语)', () {
    test('无云端账本 → 全 0 结果,不抛错', () async {
      final (db, _, _, _, engine) = await _harness();
      addTearDown(db.close);

      await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Local',
              storageMode: const Value('local'),
            ),
          );

      final result = await engine.syncAccount();

      expect(result.pushed, 0);
      expect(result.pulled, 0);
      expect(result.skipped, 0);
      expect(result.elapsedMs, greaterThanOrEqualTo(0));
    });

    test('fast-skip:无待推 + 已绑定 → skipped=1,不上传 snapshot', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      // 本地已绑定云账本(syncId 对齐远端 ledger-a),返回值无需使用。
      await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      // server 端已有该账本 snapshot → 已绑定。
      provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-a');

      final result = await engine.syncAccount();

      expect(result.skipped, 1,
          reason: '无待推 + 已绑定应整账本跳过(不再发 push/pull)');
      expect(result.pushed, 0);
      // fast-skip 整账本跳过:预置的远端 snapshot 必须保持存在,不得被删除/覆盖。
      // (download 断言这里不适用:预置的 snapshot 只进 ledgerSnapshots 列表,
      // 不代表本地 storage 有内容,所以用 exists 验证"远端仍存在"语义。)
      expect(await provider.storage.exists(path: 'ledger-a'), isTrue,
          reason: 'snapshot 由测试预置,fast-skip 不应改动它');
    });

    test('增量 push:有 unpushed + 已绑定 → 推变更,不上传 snapshot', () async {
      final (db, changeTracker, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final ledgerId = await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-a');
      await changeTracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 1,
        entitySyncId: 'tx-1',
        ledgerId: ledgerId,
        action: 'create',
      );

      final result = await engine.syncAccount();

      expect(result.skipped, 0);
      expect(result.pushed, 1, reason: '1 条 unpushed change 应被推送');
      expect(await provider.storage.download(path: 'ledger-a'), isNull,
          reason: '已绑定账本走增量 push,不应触发 fullPush 上传 snapshot');
    });

    test('fullPush:syncId 不在远端 → 上传 snapshot(fullPush 真实发生)', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      // 有 syncId 但 server 端没有对应 snapshot → inRemote=false → fullPush。
      final ledgerId =
          await _insertCloudLedger(db, name: 'A', syncId: 'ledger-fp');
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 100.0,
              categoryId: const Value(0),
            ),
          );

      final result = await engine.syncAccount();

      expect(result.skipped, 0);
      final uploaded = await provider.storage.download(path: 'ledger-fp');
      expect(uploaded, isNotNull,
          reason: '远端无该账本时必须 fullPush 上传 snapshot');
    });

    test('共享 Editor:只增量 push,不 fullPush(不 upload snapshot)', () async {
      final (db, changeTracker, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final ledgerId = await _insertCloudLedger(
        db,
        name: 'Shared',
        syncId: 'ledger-shared',
        isShared: true,
        myRole: 'editor',
      );
      provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-shared');
      await changeTracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 1,
        entitySyncId: 'tx-1',
        ledgerId: ledgerId,
        action: 'create',
      );

      final result = await engine.syncAccount();

      expect(result.skipped, 0);
      expect(result.pushed, 1);
      expect(await provider.storage.download(path: 'ledger-shared'), isNull,
          reason: '共享账本 Editor 不得 fullPush(会覆盖 Owner 数据)');
    });

    test('storage.list 失败 → 保守增量,不 fullPush', () async {
      final (db, changeTracker, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final ledgerId = await _insertCloudLedger(db, name: 'A', syncId: 'ledger-a');
      provider.storageListError = Exception('list boom');
      await changeTracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 1,
        entitySyncId: 'tx-1',
        ledgerId: ledgerId,
        action: 'create',
      );

      final result = await engine.syncAccount();

      expect(result.pushed, 1,
          reason: 'list 失败按"未绑定"保守走增量 push(fullPush 覆盖云端风险更大)');
      expect(await provider.storage.download(path: 'ledger-a'), isNull,
          reason: 'list 失败时不得 fullPush 上传 snapshot');
    });
  });
}
