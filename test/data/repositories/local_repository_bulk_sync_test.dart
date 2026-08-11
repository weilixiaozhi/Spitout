// LocalRepository 批量方法的变更记录契约测试。
//
// 锁死:
//   - insertTransactionsBatch / clearLedgerTransactions / deleteLedger
//     等批量方法必须为每行实体登记一条 local_changes,SyncEngine 才能把
//     它们推到云端。
//   - changeTracker == null 时(本地 only / 未配置 cloud)不记录、不抛错。
//
// 历史 bug(2026-04 修复前):
//   - CSV 导入交易走 insertTransactionsBatch,但 wrapper 直接 delegate 没
//     登记 local_changes,导入完云端永远拿不到数据。
//   - "清空账本"走 clearLedgerTransactions 裸 SQL bulk delete,UI 调了
//     PostProcessor.sync 但 ChangeTracker 是空的,云端继续保留所有交易。
//   - "删除账本"只登记 ledger_snapshot:delete 一条,级联删除的 transactions
//     没有 transaction:delete 变更。
//
// 这里用 in-memory Drift DB + 真实 ChangeTracker 跑端到端断言。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/data/repositories/support/change_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
  });

  tearDown(() async {
    await db.close();
  });

  group('insertTransactionsBatch', () {
    test('为每条插入的交易登记 transaction:create change', () async {
      // 先建账本,batch insert 才能挂在它下面
      final ledgerId = await repo.createLedger(name: 'test');

      final n = await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1000,
        ),
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'income',
          amount: 2000,
        ),
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 3000,
        ),
      ]);

      expect(n, 3);
      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      // ledger 创建本身也会登记一条 ledger:update —— 数据库仓库层 createLedger
      // 走的子仓库直接 insert 没经过 wrapper,所以这里只看到 transaction:create 三条
      final txChanges = changes
          .where((c) => c.entityType == 'transaction')
          .toList();
      expect(txChanges.length, 3);
      for (final c in txChanges) {
        expect(c.action, 'create');
        expect(c.ledgerId, ledgerId);
        expect(c.entitySyncId.isNotEmpty, isTrue);
      }
    });

    test('changeTracker 为 null 时不记录、不抛错', () async {
      final repoNoTracker = LocalRepository(db);
      final ledgerId = await repoNoTracker.createLedger(name: 'no-track');

      final n = await repoNoTracker.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 500,
        ),
      ]);

      expect(n, 1);
      // tracker 还是同一个,但 repoNoTracker 没注入它,所以它看不到任何 change
      final changes = await tracker.getUnpushedChanges();
      expect(changes, isEmpty);
    });

    test('items 已经带 syncId 时复用,不覆盖', () async {
      final ledgerId = await repo.createLedger(name: 'reuse');

      const presetSyncId = 'preset-uuid-123';
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 100,
          syncId: const Value(presetSyncId),
        ),
      ]);

      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final txChange = changes.firstWhere((c) => c.entityType == 'transaction');
      expect(txChange.entitySyncId, presetSyncId);
    });
  });

  group('clearLedgerTransactions', () {
    test('为每条被清空的交易登记 transaction:delete change', () async {
      final ledgerId = await repo.createLedger(name: 'test');

      // 先插 5 条交易
      await repo.insertTransactionsBatch([
        for (var i = 0; i < 5; i++)
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: i * 100,
          ),
      ]);
      // 清掉之前的 create change,只看 clear 产生的 delete change
      final beforeIds = (await tracker.getUnpushedChanges())
          .map((c) => c.id)
          .toList();
      await tracker.markPushed(beforeIds);

      final n = await repo.clearLedgerTransactions(ledgerId);

      expect(n, 5);
      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final deletes = changes
          .where((c) => c.entityType == 'transaction' && c.action == 'delete')
          .toList();
      expect(deletes.length, 5);
    });

    test('changeTracker 为 null 时只删,不记录、不抛错', () async {
      final repoNoTracker = LocalRepository(db);
      final ledgerId = await repoNoTracker.createLedger(name: 'no-track');
      await repoNoTracker.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 100,
        ),
      ]);

      final n = await repoNoTracker.clearLedgerTransactions(ledgerId);
      expect(n, 1);
    });
  });

  group('deleteLedger', () {
    test('登记级联 transaction:delete + ledger_snapshot:delete', () async {
      final ledgerId = await repo.createLedger(name: 'test');
      // 取出 ledger.syncId,后面验证 ledger_snapshot:delete 的 entitySyncId
      // 必须等于这个值,不能是 id.toString() —— 否则 server 找不到要删的 ledger。
      final ledgerRow = await (db.select(
        db.ledgers,
      )..where((l) => l.id.equals(ledgerId))).getSingle();
      final expectedLedgerSyncId = ledgerRow.syncId!;

      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 10000,
        ),
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'income',
          amount: 20000,
        ),
      ]);
      // 清掉 create change,只看 delete 后产生的
      final beforeIds = (await tracker.getUnpushedChanges())
          .map((c) => c.id)
          .toList();
      await tracker.markPushed(beforeIds);

      await repo.deleteLedger(ledgerId);

      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final txDeletes = changes
          .where((c) => c.entityType == 'transaction' && c.action == 'delete')
          .toList();
      final snapshotDeletes = changes
          .where(
            (c) => c.entityType == 'ledger_snapshot' && c.action == 'delete',
          )
          .toList();

      expect(txDeletes.length, 2, reason: '级联删除的 2 条交易需要登记 transaction:delete');
      expect(
        snapshotDeletes.length,
        1,
        reason: '账本本身需要登记 1 条 ledger_snapshot:delete',
      );
      // 关键:必须用 ledger.syncId 作为 entity_sync_id,server 才能按
      // external_id 找到要删的 ledger;用本地 id 无法定位远端账本。
      expect(snapshotDeletes.first.entitySyncId, expectedLedgerSyncId);
    });
  });

  group('insertTransactionCompanion (单条插入)', () {
    test('登记 transaction:create change', () async {
      final ledgerId = await repo.createLedger(name: 'test-ledger');

      await repo.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 5000,
        ),
      );

      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final creates = changes
          .where((c) => c.entityType == 'transaction' && c.action == 'create')
          .toList();
      expect(
        creates.length,
        1,
        reason:
            'data_import_service 给带标签/附件的交易走这条单条插入路径,'
            '必须登记 transaction:create change 才能同步到云端',
      );
    });

    test('changeTracker 为 null 时不记录、不抛错', () async {
      final repoNoTracker = LocalRepository(db);
      final ledgerId = await repoNoTracker.createLedger(name: 'no-track');

      await repoNoTracker.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1000,
        ),
      );

      final changes = await tracker.getUnpushedChanges();
      expect(changes, isEmpty);
    });
  });

  group('删除交易清理编辑历史', () {
    Future<int> seedTxWithHistory(int ledgerId, String syncId) async {
      final txId = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 1000,
              syncId: Value(syncId),
            ),
          );
      await db
          .into(db.recordEditHistories)
          .insert(
            RecordEditHistoriesCompanion.insert(
              recordId: txId,
              version: 2,
              summary: 'seed edit',
            ),
          );
      return txId;
    }

    Future<int> historyCount() =>
        db.select(db.recordEditHistories).get().then((rows) => rows.length);

    test('批量按 syncId 删除交易时同步清理编辑历史', () async {
      final ledgerId = await repo.createLedger(name: 'history-batch');
      await seedTxWithHistory(ledgerId, 'tx-1');
      await seedTxWithHistory(ledgerId, 'tx-2');

      final deleted = await repo.deleteTransactionsBatchBySyncIds([
        'tx-1',
        'tx-2',
      ]);

      expect(deleted, 2);
      expect(await historyCount(), 0);
    });

    test('清空账本时同步清理编辑历史', () async {
      final ledgerId = await repo.createLedger(name: 'history-clear');
      await seedTxWithHistory(ledgerId, 'tx-1');

      final deleted = await repo.clearLedgerTransactions(ledgerId);

      expect(deleted, 1);
      expect(await historyCount(), 0);
    });

    test('删除账本时同步清理编辑历史', () async {
      final ledgerId = await repo.createLedger(name: 'history-delete');
      await seedTxWithHistory(ledgerId, 'tx-1');

      await repo.deleteLedger(ledgerId);

      expect(await historyCount(), 0);
    });

    test('purgeSharedLedger 同步清理编辑历史', () async {
      final ledgerId = await db
          .into(db.ledgers)
          .insert(
            LedgersCompanion.insert(
              name: 'history-purge',
              syncId: const Value('ext-1'),
              isShared: const Value(true),
              myRole: const Value('owner'),
            ),
          );
      await seedTxWithHistory(ledgerId, 'tx-1');

      await repo.purgeSharedLedger('ext-1');

      expect(await historyCount(), 0);
    });

    test('purgeAllCloudLedgers 同步清理编辑历史', () async {
      final ledgerId = await db
          .into(db.ledgers)
          .insert(
            LedgersCompanion.insert(
              name: 'history-purge-all',
              syncId: const Value('ext-2'),
              isShared: const Value(true),
              myRole: const Value('owner'),
            ),
          );
      await seedTxWithHistory(ledgerId, 'tx-1');

      await repo.purgeAllCloudLedgers();

      expect(await historyCount(), 0);
    });
  });

  group('单条写路径写库与变更登记同事务', () {
    test('addTransaction 登记变更失败时回滚交易', () async {
      final repoNoFail = LocalRepository(db);
      final ledgerId = await repoNoFail.createLedger(name: 'atomic-add');
      repoNoFail.changeTracker = _ThrowingChangeRecorder();

      await expectLater(
        repoNoFail.addTransaction(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1000,
          happenedAt: DateTime(2026, 8, 5),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.localChanges).get(), isEmpty);
    });

    test('updateTransaction 登记变更失败时回滚金额与版本', () async {
      final repoNoFail = LocalRepository(db);
      final ledgerId = await repoNoFail.createLedger(name: 'atomic-update');
      final id = await repoNoFail.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 1000,
        happenedAt: DateTime(2026, 8, 5),
      );
      repoNoFail.changeTracker = _ThrowingChangeRecorder();

      await expectLater(
        repoNoFail.updateTransaction(id: id, type: 'expense', amount: 2000),
        throwsA(isA<StateError>()),
      );

      final tx = await repoNoFail.getTransactionById(id);
      expect(tx!.amount, 1000);
      expect(tx.version, 1);
      expect(await db.select(db.localChanges).get(), isEmpty);
    });
  });

  group('upsertCategory / insertCategory 变更登记', () {
    test('upsertCategory 新建时登记 create,命中已有时不重复登记', () async {
      final first = await repo.upsertCategory(name: '同步分类', kind: 'expense');
      expect(first.created, isTrue);
      final changesAfterCreate = await tracker.getUnpushedChangesForLedger(0);
      expect(
        changesAfterCreate.where((c) => c.entityType == 'category'),
        hasLength(1),
      );

      final second = await repo.upsertCategory(name: '同步分类', kind: 'expense');
      expect(second.id, first.id);
      expect(second.created, isFalse);
      final changesAfterHit = await tracker.getUnpushedChangesForLedger(0);
      expect(
        changesAfterHit.where((c) => c.entityType == 'category'),
        hasLength(1),
      );
    });

    test('insertCategory 缺 syncId 时预填并登记 create', () async {
      final id = await repo.insertCategory(
        CategoriesCompanion.insert(name: '单插分类', kind: 'expense'),
      );
      final cat = await repo.getCategoryById(id);
      expect(cat!.syncId, isNotNull);
      final changes = await tracker.getUnpushedChangesForLedger(0);
      expect(changes, hasLength(1));
      expect(changes.single.entityType, 'category');
      expect(changes.single.action, 'create');
    });
  });

  test('updateTransaction 不存在的 id 抛 StateError,不返回假版本号', () async {
    await expectLater(
      repo.updateTransaction(id: 9999, type: 'expense', amount: 100),
      throwsA(isA<StateError>()),
    );
    expect(await db.select(db.recordEditHistories).get(), isEmpty);
  });
}

/// 用于注入“登记变更必定失败”的测试替身:验证写库与登记在同一事务内。
class _ThrowingChangeRecorder implements ChangeRecorder {
  @override
  Future<void> recordUserGlobalChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required String action,
    String? payloadJson,
  }) => throw StateError('injected record failure');

  @override
  Future<void> recordLedgerChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  }) => throw StateError('injected record failure');

  @override
  Future<void> recordLedgerChanges({
    required List<
      ({
        String entityType,
        int entityId,
        String entitySyncId,
        int ledgerId,
        String action,
        String? payloadJson,
      })
    >
    changes,
  }) => throw StateError('injected record failure');

  @override
  Future<void> recordUserGlobalChanges({
    required List<
      ({
        String entityType,
        int entityId,
        String entitySyncId,
        String action,
        String? payloadJson,
      })
    >
    changes,
  }) => throw StateError('injected record failure');
}
