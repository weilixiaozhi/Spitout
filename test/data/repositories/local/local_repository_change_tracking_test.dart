// LocalRepository 变更追踪路径测试（changeTracker 注入后）。
//
// 锚点（分层规则 3/4）：写入与 change 登记必须同一事务，保证「本地已生效但
// 云漏推」的静默丢失不可能发生；每类实体写操作都要产生对应的 local_changes
// 行（transaction:create/update/delete、category:create/update/delete、
// virtual_user 等），SyncCoordinator 才能按数据变更驱动同步。
//
// 覆盖此前未触达的分支：
//   - updateTransaction 币种/快照联动补全的 6 条路径
//   - 带 tracker 的 delete / batch insert / companion insert /
//     按 syncId 批量更新 / 跨账本移动重算
//   - 分类 CRUD / 批量删除 / 提升 / 迁移的 change 登记
//   - clearLedgerTransactions 逐条登记 delete
library;

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/data/repositories/transaction_repository.dart'
    show TransactionUpdateBySyncIdData;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<int> createLedger({String name = '账本', String currency = 'CNY'}) =>
      repo.createLedger(name: name, currency: currency);

  Future<int> addExpense(
    int ledgerId, {
    int amount = 100,
    DateTime? happenedAt,
    int? categoryId,
    String? currencyCode,
    int? nativeAmount,
    String? syncId,
    int? aaMode,
    bool excludeFromStats = false,
  }) =>
      repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: amount,
        happenedAt: happenedAt ?? DateTime(2026, 8, 8),
        categoryId: categoryId,
        currencyCode: currencyCode,
        nativeAmount: nativeAmount,
        syncId: syncId,
        aaMode: aaMode,
        excludeFromStats: excludeFromStats,
      );

  Future<List<LocalChange>> txChanges(int ledgerId) =>
      tracker.getUnpushedChangesForLedger(ledgerId);

  Future<List<LocalChange>> globalChanges() =>
      tracker.getUnpushedChangesForLedger(0);

  group('updateTransaction 币种/快照联动', () {
    test('只传币种且币种未变、金额未变 → 沿用旧快照', () async {
      final ledgerId = await createLedger(name: 'fx');
      final txId = await addExpense(
        ledgerId,
        amount: 1000,
        currencyCode: 'USD',
        nativeAmount: 7200,
      );

      await repo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 1000,
        happenedAt: DateTime(2026, 8, 8),
        currencyCode: 'USD',
      );

      final tx = await repo.getTransactionById(txId);
      expect(tx?.nativeAmount, 7200);
    });

    test('只传币种、金额变了 → 按隐含汇率缩放快照', () async {
      final ledgerId = await createLedger(name: 'fx2');
      final txId = await addExpense(
        ledgerId,
        amount: 1000,
        currencyCode: 'USD',
        nativeAmount: 7200,
      );

      await repo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 2000,
        happenedAt: DateTime(2026, 8, 8),
        currencyCode: 'USD',
      );

      final tx = await repo.getTransactionById(txId);
      expect(tx?.nativeAmount, 14400);
    });

    test('只传币种、旧行无快照 → 快照=金额(1:1)', () async {
      final ledgerId = await createLedger(name: 'fx3');
      final txId = await addExpense(ledgerId, amount: 500);

      await repo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 500,
        happenedAt: DateTime(2026, 8, 8),
        currencyCode: 'USD',
      );

      final tx = await repo.getTransactionById(txId);
      expect(tx?.nativeAmount, 500);
    });

    test('只传快照 → 沿用旧币种并写入快照（成对约束由写入层兜底）', () async {
      final ledgerId = await createLedger(name: 'fx4');
      final txId = await addExpense(ledgerId, amount: 500);

      await repo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 500,
        happenedAt: DateTime(2026, 8, 8),
        nativeAmount: 888,
      );

      final tx = await repo.getTransactionById(txId);
      expect(tx?.nativeAmount, 888);
      expect(tx?.currencyCode, 'CNY');
    });

    test('两字段都不传、同币种改金额 → 快照跟金额', () async {
      final ledgerId = await createLedger(name: 'fx5');
      final txId = await addExpense(ledgerId, amount: 300);

      await repo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 600,
        happenedAt: DateTime(2026, 8, 8),
      );

      final tx = await repo.getTransactionById(txId);
      expect(tx?.nativeAmount, 600);
    });

    test('两字段都不传、外币改金额 → 按旧快照隐含汇率缩放', () async {
      final ledgerId = await createLedger(name: 'fx6');
      final txId = await addExpense(
        ledgerId,
        amount: 1000,
        currencyCode: 'JPY',
        nativeAmount: 5000,
      );

      await repo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 2000,
        happenedAt: DateTime(2026, 8, 8),
      );

      final tx = await repo.getTransactionById(txId);
      expect(tx?.nativeAmount, 10000);
    });

    test('带 tracker + syncId 更新 → 登记 transaction:update', () async {
      final ledgerId = await createLedger(name: 'track-update');
      final txId = await addExpense(ledgerId, syncId: 'tx-upd');

      final version = await repo.updateTransaction(
        id: txId,
        type: 'expense',
        amount: 999,
        happenedAt: DateTime(2026, 8, 8),
      );
      expect(version, 2);

      final changes = await txChanges(ledgerId);
      final update = changes.where((c) => c.entityType == 'transaction');
      expect(update.map((c) => c.action), contains('update'));
      expect(update.last.entitySyncId, 'tx-upd');
    });
  });

  group('带 tracker 的交易写路径', () {
    test('deleteTransaction 登记 delete change 且删除历史', () async {
      final ledgerId = await createLedger(name: 'track-del');
      final txId = await addExpense(ledgerId, syncId: 'tx-del');
      await repo.appendEditHistory(
        recordId: txId,
        version: 2,
        summary: '编辑过',
      );

      await repo.deleteTransaction(txId);

      final changes = await txChanges(ledgerId);
      expect(
        changes.map((c) => '${c.entityType}:${c.action}'),
        contains('transaction:delete'),
      );
      expect(await repo.getEditHistories(txId), isEmpty);
    });

    test('deleteTransaction 无 syncId → 只删不登记', () async {
      final ledgerId = await createLedger(name: 'track-del2');
      // 直接落库绕过自动 syncId 生成（模拟未同步的本地数据）
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 100,
              happenedAt: d.Value(DateTime(2026, 8, 8)),
            ),
          );

      await repo.deleteTransaction(txId);

      final changes = await txChanges(ledgerId);
      expect(changes.where((c) => c.entityType == 'transaction'), isEmpty);
    });

    test('insertTransactionsBatchWithRelations 批量登记 create', () async {
      final ledgerId = await createLedger(name: 'batch-rel');
      final ids = await repo.insertTransactionsBatchWithRelations(
        transactions: [
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 100,
            happenedAt: d.Value(DateTime(2026, 8, 8)),
          ),
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 200,
            happenedAt: d.Value(DateTime(2026, 8, 9)),
          ),
        ],
      );

      expect(ids, hasLength(2));
      final changes = (await txChanges(ledgerId))
          .where((c) => c.entityType == 'transaction')
          .toList();
      expect(changes.map((c) => c.action), everyElement('create'));
      expect(changes, hasLength(2));
      expect(changes.every((c) => c.entitySyncId.isNotEmpty), isTrue);
    });

    test('insertTransactionCompanion 登记 create', () async {
      final ledgerId = await createLedger(name: 'companion');
      final id = await repo.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 300,
          happenedAt: d.Value(DateTime(2026, 8, 8)),
        ),
      );

      expect(id, greaterThan(0));
      final changes = (await txChanges(ledgerId))
          .where((c) => c.entityType == 'transaction')
          .toList();
      expect(changes.single.action, 'create');
      expect(changes.single.entityId, id);
    });

    test('updateTransactionsBatchBySyncId 批量登记 update', () async {
      final ledgerId = await createLedger(name: 'batch-upd');
      await addExpense(ledgerId, syncId: 'b1');
      await addExpense(ledgerId, syncId: 'b2');

      final map = await repo.updateTransactionsBatchBySyncId([
        TransactionUpdateBySyncIdData(
          syncId: 'b1',
          type: 'expense',
          amount: 111,
          happenedAt: DateTime(2026, 8, 8),
        ),
        TransactionUpdateBySyncIdData(
          syncId: 'b2',
          type: 'expense',
          amount: 222,
          happenedAt: DateTime(2026, 8, 8),
        ),
      ]);
      expect(map, hasLength(2));

      final updates = (await txChanges(ledgerId))
          .where((c) => c.action == 'update')
          .toList();
      expect(updates.map((c) => c.entitySyncId).toSet(), {'b1', 'b2'});
    });

    test('clearLedgerTransactions 逐条登记 delete', () async {
      final ledgerId = await createLedger(name: 'clear-tx');
      await addExpense(ledgerId, syncId: 'c1');
      await addExpense(ledgerId, syncId: 'c2');
      // 无 syncId → 跳过登记（直接落库，绕过自动生成）
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 100,
              happenedAt: d.Value(DateTime(2026, 8, 8)),
            ),
          );

      final n = await repo.clearLedgerTransactions(ledgerId);
      expect(n, 3);

      final deletes = (await txChanges(ledgerId))
          .where((c) => c.action == 'delete')
          .toList();
      expect(deletes.map((c) => c.entitySyncId).toSet(), {'c1', 'c2'});
    });
  });

  group('updateTransactionLedger 跨账本移动重算', () {
    test('外币交易移入其他本位币账本 → 按新账本汇率重算快照并登记', () async {
      // 源账本 CNY，交易 USD；目标账本 JPY。
      final source = await createLedger(name: 'src', currency: 'CNY');
      final target = await createLedger(name: 'dst', currency: 'JPY');
      await repo.upsertAutoRates(
        base: 'JPY',
        rateDate: '2026-08-08',
        rates: {'USD': '150'},
        source: 'server',
        fetchedAt: DateTime(2026, 8, 8),
      );
      final txId = await addExpense(
        source,
        amount: 1000,
        currencyCode: 'USD',
        nativeAmount: 7200,
        syncId: 'mv-1',
      );

      await repo.updateTransactionLedger(id: txId, ledgerId: target);

      final tx = await repo.getTransactionById(txId);
      expect(tx?.ledgerId, target);
      // 1 USD = 150 JPY → 1000 分 USD = 150000 分 JPY
      expect(tx?.nativeAmount, 150000);

      final changes = (await txChanges(target))
          .where((c) => c.action == 'update')
          .toList();
      expect(changes.single.entitySyncId, 'mv-1');
    });

    test('同币种账本移动 → 快照=金额，无汇率也安全', () async {
      final source = await createLedger(name: 's2', currency: 'CNY');
      final target = await createLedger(name: 't2', currency: 'CNY');
      final txId = await addExpense(source, amount: 1234, syncId: 'mv-2');

      await repo.updateTransactionLedger(id: txId, ledgerId: target);

      final tx = await repo.getTransactionById(txId);
      expect(tx?.nativeAmount, 1234);
    });
  });

  group('带 tracker 的分类写路径', () {
    test('createCategory / createSubCategory 登记 user-global create', () async {
      final parentId = await repo.createCategory(
        name: '餐饮',
        kind: 'expense',
      );
      final childId = await repo.createSubCategory(
        parentId: parentId,
        name: '外卖',
        kind: 'expense',
      );

      final changes = await globalChanges();
      final creates = changes
          .where((c) => c.entityType == 'category')
          .toList();
      expect(creates.map((c) => c.entityId).toSet(), {parentId, childId});
      expect(creates.map((c) => c.action), everyElement('create'));
      expect(creates.every((c) => c.entitySyncId.isNotEmpty), isTrue);
    });

    test('updateCategory / deleteCategory 登记 update/delete', () async {
      final catId = await repo.createCategory(
        name: '交通',
        kind: 'expense',
      );

      await repo.updateCategory(catId, name: '出行');
      var changes = (await globalChanges())
          .where((c) => c.entityType == 'category')
          .toList();
      expect(changes.map((c) => c.action), contains('update'));

      await repo.deleteCategory(catId);
      changes = (await globalChanges())
          .where((c) => c.entityType == 'category')
          .toList();
      expect(changes.map((c) => c.action), contains('delete'));
    });

    test('deleteCategoriesByIds 连子分类一起登记，无 syncId 跳过', () async {
      final parent = await repo.createCategory(
        name: '服装',
        kind: 'expense',
        syncId: 'cat-parent',
      );
      final child = await repo.createSubCategory(
        parentId: parent,
        name: '鞋子',
        kind: 'expense',
      );
      // 直接落库一个无 syncId 的分类（模拟种子/未同步数据）
      final noSync = await db.into(db.categories).insert(
            CategoriesCompanion.insert(name: '本地未同步', kind: 'expense'),
          );

      await repo.deleteCategoriesByIds([parent, noSync]);

      final deletes = (await globalChanges())
          .where((c) => c.action == 'delete')
          .toList();
      // parent + child 登记（子分类被连带删除），noSync 跳过
      expect(deletes.map((c) => c.entityId).toSet(), {parent, child});
      expect(await repo.findCategoryBySyntheticId(child), isNull);
    });

    test('deleteTransactionsByCategoryIds 登记受影响交易 delete', () async {
      final ledgerId = await createLedger(name: 'del-by-cat');
      final catId = await repo.createCategory(
        name: '购物',
        kind: 'expense',
        syncId: 'cat-shopping',
      );
      await addExpense(ledgerId, categoryId: catId, syncId: 'tx-c1');
      // 无 syncId 交易（直接落库）
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 100,
              categoryId: d.Value(catId),
              happenedAt: d.Value(DateTime(2026, 8, 8)),
            ),
          );

      final n = await repo.deleteTransactionsByCategoryIds([catId]);
      expect(n, 2);

      final deletes = (await txChanges(ledgerId))
          .where((c) => c.action == 'delete')
          .toList();
      expect(deletes.map((c) => c.entitySyncId), ['tx-c1']);
    });

    test('promoteSubCategoriesToTopLevel 登记 update', () async {
      final parent = await repo.createCategory(
        name: '旧父类',
        kind: 'expense',
        syncId: 'cat-old-parent',
      );
      final child = await repo.createSubCategory(
        parentId: parent,
        name: '升级子类',
        kind: 'expense',
      );

      final n = await repo.promoteSubCategoriesToTopLevel(parent);
      expect(n, 1);

      final updates = (await globalChanges())
          .where((c) => c.action == 'update')
          .toList();
      expect(updates.map((c) => c.entityId), contains(child));
      final promoted = await repo.findCategoryBySyntheticId(child);
      expect(promoted?.level, 1);
      expect(promoted?.parentId, isNull);
    });

    test('migrateCategory 登记受影响交易 update', () async {
      final ledgerId = await createLedger(name: 'migrate');
      final from = await repo.createCategory(
        name: '旧分类',
        kind: 'expense',
        syncId: 'cat-from',
      );
      final to = await repo.createCategory(
        name: '新分类',
        kind: 'expense',
        syncId: 'cat-to',
      );
      await addExpense(ledgerId, categoryId: from, syncId: 'tx-m1');

      final n = await repo.migrateCategory(
        fromCategoryId: from,
        toCategoryId: to,
      );
      expect(n, 1);

      final updates = (await txChanges(ledgerId))
          .where((c) => c.action == 'update')
          .toList();
      expect(updates.single.entitySyncId, 'tx-m1');
      final tx = await repo
          .getTransactionsByLedger(ledgerId)
          .then((list) => list.single);
      expect(tx.categoryId, to);
    });

    test('migrateCategoryTransactions 登记交易 update 与子分类移动', () async {
      final ledgerId = await createLedger(name: 'migrate-all');
      final from = await repo.createCategory(
        name: '旧父类',
        kind: 'expense',
        syncId: 'cat-old-parent',
      );
      final child = await repo.createSubCategory(
        parentId: from,
        name: '旧子类',
        kind: 'expense',
        syncId: 'cat-old-child',
      );
      final to = await repo.createCategory(
        name: '新父类',
        kind: 'expense',
        syncId: 'cat-new-parent',
      );
      await addExpense(ledgerId, categoryId: child, syncId: 'tx-mig-child');

      final result = await repo.migrateCategoryTransactions(
        fromCategoryId: from,
        toCategoryId: to,
      );
      expect(result.migratedSubCategories, 1);

      final changes = (await txChanges(ledgerId))
          .where((c) => c.action == 'update')
          .toList();
      expect(changes.map((c) => c.entitySyncId), contains('tx-mig-child'));

      final categoryUpdates = (await globalChanges())
          .where((c) => c.action == 'update')
          .toList();
      expect(categoryUpdates.map((c) => c.entityId), contains(child));

      final moved = await repo.findCategoryBySyntheticId(child);
      expect(moved?.parentId, to);
    });

    test('batchInsertCategories 预填 syncId 并批量登记 create', () async {
      await repo.batchInsertCategories([
        CategoriesCompanion.insert(
          name: '批量A',
          kind: 'expense',
        ),
        CategoriesCompanion.insert(
          name: '批量B',
          kind: 'expense',
          syncId: d.Value('cat-batch-b'),
        ),
      ]);

      final creates = (await globalChanges())
          .where((c) => c.action == 'create')
          .toList();
      expect(creates, hasLength(2));
      expect(creates.every((c) => c.entitySyncId.isNotEmpty), isTrue);
      expect(
        creates.map((c) => c.entitySyncId),
        contains('cat-batch-b'),
      );
    });

    test('insertCategory 预填 syncId 并登记 create', () async {
      final id = await repo.insertCategory(
        CategoriesCompanion.insert(name: '单个', kind: 'expense'),
      );

      final creates = (await globalChanges())
          .where((c) => c.action == 'create')
          .toList();
      expect(creates.single.entityId, id);
      expect(creates.single.entitySyncId.isNotEmpty, isTrue);
    });
  });
}
