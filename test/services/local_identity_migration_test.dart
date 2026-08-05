// LocalIdentityMigrationService 迁移服务测试。
//
// 覆盖方案 B 核心契约:
//   1. migrateToCloudUserId: 把库中所有 localSelfId 引用改写为 cloudUserId
//      (transactions 三字段 + ledgers.ownerUserId + record_edit_histories.operatorUserId)
//   2. 幂等:同一 cloudUserId 第二次调用不重跑(标记位命中)
//   3. migrateLedgerToCloudUserId: 仅迁移指定账本,不影响其他账本

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/services/data/local_identity_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late SpitoutDatabase db;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => db.close());

  /// 插入账本,返回 id。
  Future<int> createLedger({String? ownerUserId}) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'test',
            ownerUserId: ownerUserId != null
                ? Value(ownerUserId)
                : const Value.absent(),
          ),
        );
  }

  /// 插入交易,返回 id。
  Future<int> createTx({
    required int ledgerId,
    String? paidByUserId,
    String? createdByUserId,
    String? lastEditedByUserId,
    String? aaParticipants,
    String? aaSplits,
  }) async {
    return db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 10000,
            happenedAt: Value(DateTime(2026, 1, 1)),
            paidByUserId: paidByUserId != null
                ? Value(paidByUserId)
                : const Value.absent(),
            createdByUserId: createdByUserId != null
                ? Value(createdByUserId)
                : const Value.absent(),
            lastEditedByUserId: lastEditedByUserId != null
                ? Value(lastEditedByUserId)
                : const Value.absent(),
            aaParticipants: aaParticipants != null
                ? Value(aaParticipants)
                : const Value.absent(),
            aaSplits: aaSplits != null
                ? Value(aaSplits)
                : const Value.absent(),
          ),
        );
  }

  group('migrateToCloudUserId', () {
    test('把所有 localSelfId 引用改写为 cloudUserId', () async {
      const localSelfId = 'local-uuid-111';
      const cloudUserId = 'cloud-user-222';
      final ledgerId = await createLedger(ownerUserId: localSelfId);
      final txId = await createTx(
        ledgerId: ledgerId,
        paidByUserId: localSelfId,
        createdByUserId: localSelfId,
        lastEditedByUserId: localSelfId,
      );

      await LocalIdentityMigrationService.migrateToCloudUserId(
        db: db,
        cloudUserId: cloudUserId,
        localSelfId: localSelfId,
      );

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .getSingle();
      expect(tx.paidByUserId, cloudUserId);
      expect(tx.createdByUserId, cloudUserId);
      expect(tx.lastEditedByUserId, cloudUserId);

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingle();
      expect(ledger.ownerUserId, cloudUserId);
    });

    test('aaParticipants/aaSplits 里的 localSelfId 一并改写', () async {
      const localSelfId = 'local-uuid-aa';
      const cloudUserId = 'cloud-user-aa';
      final ledgerId = await createLedger();
      await createTx(
        ledgerId: ledgerId,
        paidByUserId: localSelfId,
        aaParticipants: '["$localSelfId","u2","vu-1"]',
        aaSplits: '{"$localSelfId":"20.00","u2":"20.00","vu-1":"10.00"}',
      );

      await LocalIdentityMigrationService.migrateToCloudUserId(
        db: db,
        cloudUserId: cloudUserId,
        localSelfId: localSelfId,
      );

      final tx = (await db.select(db.transactions).get()).single;
      expect(tx.aaParticipants, '["$cloudUserId","u2","vu-1"]',
          reason: 'aaParticipants 中的本地身份应改写为云身份');
      expect(tx.aaSplits,
          '{"u2":"20.00","vu-1":"10.00","$cloudUserId":"20.00"}',
          reason: 'aaSplits 的 key 应改写为云身份且金额不变');
    });

    test('aa 字段中 localSelfId 与 cloudUserId 并存时去重且不丢云端金额', () async {
      const localSelfId = 'local-uuid-dup';
      const cloudUserId = 'cloud-user-dup';
      final ledgerId = await createLedger();
      await createTx(
        ledgerId: ledgerId,
        aaParticipants: '["$localSelfId","$cloudUserId"]',
        aaSplits: '{"$localSelfId":"5.00","$cloudUserId":"7.00"}',
      );

      await LocalIdentityMigrationService.migrateToCloudUserId(
        db: db,
        cloudUserId: cloudUserId,
        localSelfId: localSelfId,
      );

      final tx = (await db.select(db.transactions).get()).single;
      expect(tx.aaParticipants, '["$cloudUserId"]',
          reason: '并存时替换后应去重，避免同一参与人出现两次');
      expect(tx.aaSplits, '{"$cloudUserId":"7.00"}',
          reason: '云端已有金额应保留，不覆盖为本地旧值');
    });

    test('幂等:同一 cloudUserId 第二次调用不重跑', () async {
      const localSelfId = 'local-uuid-333';
      const cloudUserId = 'cloud-user-444';
      final ledgerId = await createLedger(ownerUserId: localSelfId);

      await LocalIdentityMigrationService.migrateToCloudUserId(
        db: db,
        cloudUserId: cloudUserId,
        localSelfId: localSelfId,
      );
      // 第二次调用应跳过(标记位命中)。
      await LocalIdentityMigrationService.migrateToCloudUserId(
        db: db,
        cloudUserId: cloudUserId,
        localSelfId: localSelfId,
      );

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingle();
      expect(ledger.ownerUserId, cloudUserId);
    });

    test('不同 cloudUserId 不命中标记位,会重新迁移', () async {
      const localSelfId = 'local-uuid-555';
      const cloudUserId1 = 'cloud-user-666';
      const cloudUserId2 = 'cloud-user-777';
      final ledgerId = await createLedger(ownerUserId: localSelfId);

      await LocalIdentityMigrationService.migrateToCloudUserId(
        db: db,
        cloudUserId: cloudUserId1,
        localSelfId: localSelfId,
      );
      // 此时 ownerUserId 已是 cloudUserId1,无 localSelfId 可迁移,
      // 但标记位不同,第二次调用仍会执行(UPDATE 0 行,不报错)。
      await LocalIdentityMigrationService.migrateToCloudUserId(
        db: db,
        cloudUserId: cloudUserId2,
        localSelfId: localSelfId,
      );

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingle();
      // 仍是 cloudUserId1(第二次迁移无 localSelfId 可改)。
      expect(ledger.ownerUserId, cloudUserId1);
    });
  });

  group('migrateLedgerToCloudUserId', () {
    test('仅迁移指定账本,不影响其他账本', () async {
      const localSelfId = 'local-uuid-888';
      const cloudUserId = 'cloud-user-999';
      final ledger1 = await createLedger(ownerUserId: localSelfId);
      final ledger2 = await createLedger(ownerUserId: localSelfId);
      final tx1 = await createTx(
        ledgerId: ledger1,
        paidByUserId: localSelfId,
      );
      final tx2 = await createTx(
        ledgerId: ledger2,
        paidByUserId: localSelfId,
      );

      await LocalIdentityMigrationService.migrateLedgerToCloudUserId(
        db: db,
        ledgerId: ledger1,
        cloudUserId: cloudUserId,
        localSelfId: localSelfId,
      );

      final t1 = await (db.select(db.transactions)
            ..where((t) => t.id.equals(tx1)))
          .getSingle();
      final t2 = await (db.select(db.transactions)
            ..where((t) => t.id.equals(tx2)))
          .getSingle();
      // ledger1 的交易被迁移。
      expect(t1.paidByUserId, cloudUserId);
      // ledger2 的交易不受影响。
      expect(t2.paidByUserId, localSelfId);

      final l1 = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledger1)))
          .getSingle();
      final l2 = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledger2)))
          .getSingle();
      expect(l1.ownerUserId, cloudUserId);
      expect(l2.ownerUserId, localSelfId);
    });

    test('仅改写指定账本的 aa 字段,不影响其他账本', () async {
      const localSelfId = 'local-uuid-aa-ledger';
      const cloudUserId = 'cloud-user-aa-ledger';
      final ledger1 = await createLedger();
      final ledger2 = await createLedger();
      await createTx(
        ledgerId: ledger1,
        aaParticipants: '["$localSelfId"]',
        aaSplits: '{"$localSelfId":"30.00"}',
      );
      await createTx(
        ledgerId: ledger2,
        aaParticipants: '["$localSelfId"]',
        aaSplits: '{"$localSelfId":"30.00"}',
      );

      await LocalIdentityMigrationService.migrateLedgerToCloudUserId(
        db: db,
        ledgerId: ledger1,
        cloudUserId: cloudUserId,
        localSelfId: localSelfId,
      );

      final txs = await db.select(db.transactions).get();
      final t1 = txs.firstWhere((t) => t.ledgerId == ledger1);
      final t2 = txs.firstWhere((t) => t.ledgerId == ledger2);
      expect(t1.aaParticipants, '["$cloudUserId"]');
      expect(t1.aaSplits, '{"$cloudUserId":"30.00"}');
      expect(t2.aaParticipants, '["$localSelfId"]',
          reason: '其他账本的 aa 引用不应被改写');
      expect(t2.aaSplits, '{"$localSelfId":"30.00"}');
    });
  });
}
