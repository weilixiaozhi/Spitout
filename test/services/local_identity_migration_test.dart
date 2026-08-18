// LocalIdentityMigrationService 存量身份修复测试。
//
// 覆盖归属模型契约：
//   1. repairAuthorIdsByStorageMode：本地账本所有作者位收敛为 localSelfId；
//      云端账本把 localSelfId 改写为 cloudUserId（其他成员 id 保留）；
//   2. repairLocalLedgersToLocalSelfId：仅修复本地账本，云端账本不动（启动期兜底）；
//   3. migrateLedgerToCloudUserId：仅迁移指定账本（转云端路径复用）。

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/services/data/local_identity_migration_service.dart';

import '../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;

  setUp(() async {
    resetGlobalTestState();
    await logger.clear();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    await logger.clear();
  });

  Future<int> createLedger({
    String? ownerUserId,
    String storageMode = 'local',
    bool isShared = false,
  }) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'test',
            ownerUserId: ownerUserId != null
                ? Value(ownerUserId)
                : const Value.absent(),
            storageMode: Value(storageMode),
            isShared: Value(isShared),
          ),
        );
  }

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

  Future<void> createVirtualUser({
    required int ledgerId,
    String? syncId,
  }) async {
    await db.into(db.ledgerVirtualUsers).insert(
          LedgerVirtualUsersCompanion.insert(
            ledgerId: ledgerId,
            name: '虚拟用户',
            syncId: syncId != null ? Value(syncId) : const Value.absent(),
          ),
        );
  }

  Future<void> createHistory({
    required int recordId,
    required String operatorUserId,
  }) async {
    await db.into(db.recordEditHistories).insert(
          RecordEditHistoriesCompanion.insert(
            recordId: recordId,
            version: 1,
            operatorUserId: Value(operatorUserId),
            summary: 's',
          ),
        );
  }

  /// 断言未知账本被保守跳过时留下足够定位数据的告警。
  void expectUnknownLedgerWarning(int ledgerId) {
    final warnings = logger.logs
        .where((entry) =>
            entry.level == LogLevel.warning &&
            entry.tag == 'LocalIdentityMigration')
        .map((entry) => entry.message);
    expect(
      warnings,
      contains(
        '跳过未知归属账本身份修复: ledgerId=$ledgerId '
        'storageMode=future isShared=false',
      ),
    );
  }

  group('repairAuthorIdsByStorageMode', () {
    test('本地账本：混存的云 userId 与 localSelfId 全部收敛为 localSelfId', () async {
      const localSelfId = 'local-uuid';
      const cloudUserId = 'cloud-user';
      final ledgerId = await createLedger(ownerUserId: cloudUserId);
      final txId = await createTx(
        ledgerId: ledgerId,
        paidByUserId: cloudUserId,
        createdByUserId: localSelfId,
        lastEditedByUserId: cloudUserId,
      );
      await createHistory(recordId: txId, operatorUserId: cloudUserId);

      await LocalIdentityMigrationService.repairAuthorIdsByStorageMode(
        db: db,
        localSelfId: localSelfId,
        cloudUserId: cloudUserId,
      );

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .getSingle();
      expect(tx.paidByUserId, localSelfId);
      expect(tx.createdByUserId, localSelfId);
      expect(tx.lastEditedByUserId, localSelfId);

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingle();
      expect(ledger.ownerUserId, localSelfId);

      final history = await (db.select(db.recordEditHistories)
            ..where((h) => h.recordId.equals(txId)))
          .getSingle();
      expect(history.operatorUserId, localSelfId);
    });

    test('本地账本：虚拟用户 id 保留，AA 引用收敛且去重', () async {
      const localSelfId = 'local-uuid';
      const cloudUserId = 'cloud-user';
      const virtualId = 'vu-sync';
      final ledgerId = await createLedger();
      await createVirtualUser(ledgerId: ledgerId, syncId: virtualId);
      final txId = await createTx(
        ledgerId: ledgerId,
        paidByUserId: virtualId,
        aaParticipants: '["$virtualId","$cloudUserId","$localSelfId"]',
        aaSplits: '{"$virtualId":"5.00","$cloudUserId":"5.00","$localSelfId":"10.00"}',
      );

      await LocalIdentityMigrationService.repairAuthorIdsByStorageMode(
        db: db,
        localSelfId: localSelfId,
        cloudUserId: cloudUserId,
      );

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .getSingle();
      expect(tx.paidByUserId, virtualId, reason: '虚拟用户 id 不属于作者身份，不得改写');
      expect(tx.aaParticipants, '["$virtualId","$localSelfId"]',
          reason: '虚拟用户保留、其他身份收敛为 localSelfId 并去重');
      expect(tx.aaSplits, '{"$localSelfId":"10.00","$virtualId":"5.00"}',
          reason: '本地已有金额保留，外来身份并入本地不覆盖');
    });

    test('云端账本：localSelfId → cloudUserId，其他成员 id 保留', () async {
      const localSelfId = 'local-uuid';
      const cloudUserId = 'cloud-user';
      const memberId = 'member-1';
      final ledgerId = await createLedger(
        ownerUserId: localSelfId,
        storageMode: 'cloud',
      );
      final txId = await createTx(
        ledgerId: ledgerId,
        paidByUserId: localSelfId,
        createdByUserId: memberId,
      );

      await LocalIdentityMigrationService.repairAuthorIdsByStorageMode(
        db: db,
        localSelfId: localSelfId,
        cloudUserId: cloudUserId,
      );

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .getSingle();
      expect(tx.paidByUserId, cloudUserId);
      expect(tx.createdByUserId, memberId, reason: '其他成员 id 不得改写');

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingle();
      expect(ledger.ownerUserId, cloudUserId);
    });

    test('未知归属账本：保守跳过并记录诊断', () async {
      const localSelfId = 'local-uuid';
      const cloudUserId = 'cloud-user';
      final ledgerId = await createLedger(
        ownerUserId: cloudUserId,
        storageMode: 'future',
      );

      await LocalIdentityMigrationService.repairAuthorIdsByStorageMode(
        db: db,
        localSelfId: localSelfId,
        cloudUserId: cloudUserId,
      );

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingle();
      expect(ledger.ownerUserId, cloudUserId, reason: '未知归属不得破坏性改写为本地身份');
      expectUnknownLedgerWarning(ledgerId);
    });
  });

  group('repairLocalLedgersToLocalSelfId', () {
    test('仅修复本地账本，云端账本不动', () async {
      const localSelfId = 'local-uuid';
      const cloudUserId = 'cloud-user';
      final localId = await createLedger(ownerUserId: cloudUserId);
      final localTx = await createTx(
        ledgerId: localId,
        paidByUserId: cloudUserId,
      );
      final cloudId = await createLedger(
        ownerUserId: localSelfId,
        storageMode: 'cloud',
      );
      final cloudTx = await createTx(
        ledgerId: cloudId,
        paidByUserId: localSelfId,
      );

      await LocalIdentityMigrationService.repairLocalLedgersToLocalSelfId(
        db: db,
        localSelfId: localSelfId,
      );

      final local = await (db.select(db.transactions)
            ..where((t) => t.id.equals(localTx)))
          .getSingle();
      expect(local.paidByUserId, localSelfId);
      expect(
        (await (db.select(db.ledgers)
                  ..where((l) => l.id.equals(localId)))
              .getSingle())
            .ownerUserId,
        localSelfId,
      );

      final cloud = await (db.select(db.transactions)
            ..where((t) => t.id.equals(cloudTx)))
          .getSingle();
      expect(cloud.paidByUserId, localSelfId,
          reason: '云端账本由登录后修复处理，启动期本地修复不得改动');
    });

    test('未知归属账本：启动修复保持原样并记录诊断', () async {
      const localSelfId = 'local-uuid';
      const cloudUserId = 'cloud-user';
      final ledgerId = await createLedger(
        ownerUserId: cloudUserId,
        storageMode: 'future',
      );

      await LocalIdentityMigrationService.repairLocalLedgersToLocalSelfId(
        db: db,
        localSelfId: localSelfId,
      );

      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingle();
      expect(ledger.ownerUserId, cloudUserId);
      expectUnknownLedgerWarning(ledgerId);
    });
  });

  group('migrateLedgerToCloudUserId', () {
    test('仅迁移指定账本，不影响其他账本', () async {
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
      expect(t1.paidByUserId, cloudUserId);
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

    test('仅改写指定账本的 aa 字段，不影响其他账本', () async {
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
      expect(t2.aaParticipants, '["$localSelfId"]');
      expect(t2.aaSplits, '{"$localSelfId":"30.00"}');
    });
  });
}
