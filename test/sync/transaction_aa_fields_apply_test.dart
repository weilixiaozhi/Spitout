/// AA 分摊字段同步 apply 路径测试(文档 §九 测试计划 #2 同步)。
///
/// 覆盖:
/// - 远端 upsert 携带 AA 字段 → 本地正确写入(round-trip)。
/// - 远端 upsert 省略 AA 字段(缺键) → 本地已有值保留(缺键保护 R1)。
/// - 远端 upsert 显式 null → 本地覆盖为 null。
/// - 虚拟用户 create/update/delete 投影 apply。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';
import 'package:drift/drift.dart' show Value;

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;

  setUp(() async {
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

  tearDown(() async => db.close());

  Future<int> seedLedger({String syncId = 'L1', bool aaEnabled = true}) async {
    final lid = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          monthStartDay: const Value(1),
          syncId: Value(syncId),
          aaEnabled: Value(aaEnabled),
        ));
    return lid;
  }

  group('transaction AA 字段 apply', () {
    test('远端 upsert 携带 AA 字段 → 本地正确写入', () async {
      await seedLedger();
      const txSyncId = 'tx-aa-1';

      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: txSyncId,
        ledgerId: 'L1',
        payload: {
          'syncId': txSyncId,
          'type': 'expense',
          'amount': 30.0,
          'happenedAt': '2026-06-18T00:00:00Z',
          'paidByUserId': 'u1',
          'aaMode': 2,
          'aaParticipants': '["u1","u2","u3"]',
          'aaSplits': '{"u1":"10.00","u2":"10.00","u3":"10.00"}',
        },
      );

      await engine.pull('');

      final tx = await repo.getTransactionBySyncId(txSyncId);
      expect(tx, isNotNull);
      expect(tx!.paidByUserId, 'u1');
      expect(tx.aaMode, 2);
      expect(tx.aaParticipants, '["u1","u2","u3"]');
      expect(tx.aaSplits, '{"u1":"10.00","u2":"10.00","u3":"10.00"}');
    });

    test('远端 upsert 省略 AA 字段(缺键) → 本地已有值保留', () async {
      final lid = await seedLedger();
      const txSyncId = 'tx-aa-2';

      // 本地先建一条带 AA 字段的交易
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 30,
        happenedAt: DateTime(2026, 6, 18),
        syncId: txSyncId,
        paidByUserId: 'u1',
        aaMode: 2,
        aaParticipants: '["u1","u2"]',
        aaSplits: '{"u1":"15.00","u2":"15.00"}',
      );

      // 远端推同 syncId 的 upsert,只改 amount,省略所有 AA 键
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: txSyncId,
        ledgerId: 'L1',
        payload: {
          'syncId': txSyncId,
          'type': 'expense',
          'amount': 50,
          'happenedAt': '2026-06-18T00:00:00Z',
          // 故意省略 paidByUserId/aaMode/aaParticipants/aaSplits
        },
      );

      await engine.pull('');

      final tx = await repo.getTransactionBySyncId(txSyncId);
      expect(tx, isNotNull);
      expect(tx!.amount, 50, reason: 'amount 应被远端更新');
      expect(tx.paidByUserId, 'u1', reason: '缺键不应清空本地 paidByUserId');
      expect(tx.aaMode, 2, reason: '缺键不应清空本地 aaMode');
      expect(tx.aaParticipants, '["u1","u2"]',
          reason: '缺键不应清空本地 aaParticipants');
      expect(tx.aaSplits, '{"u1":"15.00","u2":"15.00"}',
          reason: '缺键不应清空本地 aaSplits');
    });

    test('远端 upsert 显式 aaMode=null → 覆盖本地为 null', () async {
      final lid = await seedLedger();
      const txSyncId = 'tx-aa-3';

      // 本地先建 aaMode=2 的交易
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 30,
        happenedAt: DateTime(2026, 6, 18),
        syncId: txSyncId,
        aaMode: 2,
      );

      // 远端显式 aaMode=null → 视为人均,覆盖本地
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: txSyncId,
        ledgerId: 'L1',
        payload: {
          'syncId': txSyncId,
          'type': 'expense',
          'amount': 30,
          'happenedAt': '2026-06-18T00:00:00Z',
          'aaMode': null,
        },
      );

      await engine.pull('');

      final tx = await repo.getTransactionBySyncId(txSyncId);
      expect(tx, isNotNull);
      expect(tx!.aaMode, isNull, reason: '显式 null 应覆盖本地为 null(人均)');
    });
  });

  group('ledger aaEnabled apply', () {
    test('远端 ledger upsert 携带 aaEnabled → 本地更新', () async {
      await seedLedger(syncId: 'L2', aaEnabled: false);

      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'L2',
        ledgerId: 'L2',
        payload: {
          'syncId': 'L2',
          'ledgerName': '测试账本',
          'currency': 'CNY',
          'aaEnabled': true,
        },
      );

      await engine.pull('');

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.syncId.equals('L2')))
          .getSingle();
      expect(ledger.aaEnabled, true);
    });

    test('远端 ledger upsert 省略 aaEnabled(缺键) → 本地保留', () async {
      await seedLedger(syncId: 'L3', aaEnabled: true);

      // 远端 payload 不含 aaEnabled 键(老 server)
      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'L3',
        ledgerId: 'L3',
        payload: {
          'syncId': 'L3',
          'ledgerName': '改名',
          'currency': 'CNY',
          // 故意省略 aaEnabled
        },
      );

      await engine.pull('');

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.syncId.equals('L3')))
          .getSingle();
      expect(ledger.aaEnabled, true, reason: '缺键不应清空本地 aaEnabled');
      expect(ledger.name, '改名');
    });
  });

  group('virtual_user apply', () {
    test('远端 create → 本地新建虚拟用户', () async {
      final lid = await seedLedger(syncId: 'L4');

      provider.pushFakeChange(
        entityType: 'virtual_user',
        entitySyncId: 'vu-1',
        ledgerId: 'L4',
        payload: {
          'syncId': 'vu-1',
          'name': '室友',
        },
      );

      await engine.pull('');

      final vu = await repo.getBySyncId('vu-1');
      expect(vu, isNotNull);
      expect(vu!.name, '室友');
      expect(vu.ledgerId, lid);
    });

    test('远端 update → 本地重命名', () async {
      await seedLedger(syncId: 'L5');

      // 先 create
      provider.pushFakeChange(
        entityType: 'virtual_user',
        entitySyncId: 'vu-2',
        ledgerId: 'L5',
        payload: {'syncId': 'vu-2', 'name': '旧名'},
      );
      await engine.pull('');

      // 再 update
      provider.pushFakeChange(
        entityType: 'virtual_user',
        entitySyncId: 'vu-2',
        ledgerId: 'L5',
        payload: {'syncId': 'vu-2', 'name': '新名'},
      );
      await engine.pull('');

      final vu = await repo.getBySyncId('vu-2');
      expect(vu, isNotNull);
      expect(vu!.name, '新名');
    });

    test('远端 delete → 本地硬删', () async {
      await seedLedger(syncId: 'L6');

      // 先 create
      provider.pushFakeChange(
        entityType: 'virtual_user',
        entitySyncId: 'vu-3',
        ledgerId: 'L6',
        payload: {'syncId': 'vu-3', 'name': '待删'},
      );
      await engine.pull('');
      expect(await repo.getBySyncId('vu-3'), isNotNull);

      // delete
      provider.pushFakeChange(
        entityType: 'virtual_user',
        entitySyncId: 'vu-3',
        ledgerId: 'L6',
        action: 'delete',
      );
      await engine.pull('');

      expect(await repo.getBySyncId('vu-3'), isNull,
          reason: '硬删后本地应无此虚拟用户');
    });
  });
}
