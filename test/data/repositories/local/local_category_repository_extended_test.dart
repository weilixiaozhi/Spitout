// LocalCategoryRepository 补充测试。
//
// 覆盖此前未触达的分支：作用域判重（parentId 分支）、更新/排序/全名、
// 计数与汇总（含排除统计/多币种快照）、迁移守卫、共享账本 synthetic 分类
// 的 watch 流（负 id 反查、父子链、re-emit、取消订阅）。
//
// 锚点：分类树契约「同一父级作用域内 (name, kind) 唯一、跨父级/跨层级允许
// 同名」，以及共享账本 Editor 视角「SharedLedgerCategories 是唯一数据源、
// 负 id 由 syncId 稳定派生」。
library;

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_category_repository.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalCategoryRepository repo;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalCategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 创建可指定本位币的支出账本，供跨账本隔离场景复用。
  Future<int> createExpenseLedger({
    String name = '账本',
    String currency = 'CNY',
  }) async {
    final id = await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            name: name,
            currency: d.Value(currency),
          ),
        );
    return id;
  }

  Future<int> insertTx({
    required int ledgerId,
    required int amount,
    int? categoryId,
    bool excludeFromStats = false,
    String? currencyCode,
    int? nativeAmount,
  }) =>
      db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: amount,
              categoryId: d.Value(categoryId),
              excludeFromStats: d.Value(excludeFromStats),
              currencyCode: d.Value(currencyCode),
              nativeAmount: d.Value(nativeAmount),
              happenedAt: d.Value(DateTime(2026, 8, 8)),
            ),
          );

  group('事务与作用域判重', () {
    test('runInTransaction 透传', () async {
      final id = await repo.runInTransaction(
        () => repo.createCategory(name: '事务分类', kind: 'expense'),
      );
      expect(await repo.getCategoryById(id), isNotNull);
    });

    test('createCategory 指定父级时按父级作用域判重', () async {
      final parent = await repo.createCategory(name: '服装', kind: 'expense');
      final child = await repo.createCategory(
        name: '鞋子',
        kind: 'expense',
        parentId: parent,
        level: 2,
      );
      expect(child, greaterThan(0));

      // 同父级重名抛错
      expect(
        () => repo.createCategory(
          name: '鞋子',
          kind: 'expense',
          parentId: parent,
          level: 2,
        ),
        throwsA(isA<Object>()),
      );
      // 不同父级允许同名
      final otherParent =
          await repo.createCategory(name: '购物', kind: 'expense');
      final otherChild = await repo.createCategory(
        name: '鞋子',
        kind: 'expense',
        parentId: otherParent,
        level: 2,
      );
      expect(otherChild, isNot(child));
    });
  });

  group('更新与排序', () {
    test('updateCategory 改名/图标/清空父级/改层级', () async {
      final parent = await repo.createCategory(name: '旧父', kind: 'expense');
      final child = await repo.createCategory(
        name: '旧子',
        kind: 'expense',
        parentId: parent,
        level: 2,
      );

      await repo.updateCategory(child, name: '新子', icon: 'shirt');
      final updated = await repo.getCategoryById(child);
      expect(updated?.name, '新子');
      expect(updated?.icon, 'shirt');

      // parentId=-1 → 清空父级并回到一级
      await repo.updateCategory(child, parentId: -1, level: 1);
      final promoted = await repo.getCategoryById(child);
      expect(promoted?.parentId, isNull);
      expect(promoted?.level, 1);
    });

    test('updateCategorySortOrders 批量写排序', () async {
      final a = await repo.createCategory(name: 'A', kind: 'expense');
      final b = await repo.createCategory(name: 'B', kind: 'expense');
      await repo.updateCategorySortOrders([(id: a, sortOrder: 9), (id: b, sortOrder: 1)]);

      final byId = await repo.getCategoriesByIds([a, b]);
      expect(byId[a]?.sortOrder, 9);
      expect(byId[b]?.sortOrder, 1);
    });

    test('getCategoryFullName 一级/子级/父级缺失', () async {
      final parent = await repo.createCategory(name: '餐饮', kind: 'expense');
      final child = await repo.createCategory(
        name: '外卖',
        kind: 'expense',
        parentId: parent,
        level: 2,
      );
      expect(await repo.getCategoryFullName(parent), '餐饮');
      expect(await repo.getCategoryFullName(child), '餐饮 / 外卖');
      expect(await repo.getCategoryFullName(9999), '');

      // 父级被删（绕过 fail-loud 直接落库，模拟历史脏数据）后降级返回子级名
      await (db.delete(db.categories)..where((c) => c.id.equals(parent))).go();
      expect(await repo.getCategoryFullName(child), '外卖');
    });
  });

  group('计数与汇总', () {
    test('hasSubCategories / getSubCategoryCount', () async {
      final parent = await repo.createCategory(name: '父', kind: 'expense');
      expect(await repo.hasSubCategories(parent), isFalse);
      expect(await repo.getSubCategoryCount(parent), 0);

      await repo.createCategory(
        name: '子',
        kind: 'expense',
        parentId: parent,
        level: 2,
      );
      expect(await repo.hasSubCategories(parent), isTrue);
      expect(await repo.getSubCategoryCount(parent), 1);
    });

    test('getAllCategoryTransactionCounts 含左连接补零', () async {
      final ledgerId = await createExpenseLedger();
      final emptyCat = await repo.createCategory(name: '空', kind: 'expense');
      final usedCat = await repo.createCategory(name: '有账', kind: 'expense');
      await insertTx(ledgerId: ledgerId, amount: 100, categoryId: usedCat);
      await insertTx(ledgerId: ledgerId, amount: 200, categoryId: usedCat);

      final counts = await repo.getAllCategoryTransactionCounts();
      expect(counts[usedCat], 2);
      expect(counts[emptyCat], 0);
    });

    test('getCategorySummary 按 native_amount 汇总并排除 excludeFromStats', () async {
      final ledgerId = await createExpenseLedger();
      final catId = await repo.createCategory(name: '餐饮', kind: 'expense');
      await insertTx(
        ledgerId: ledgerId,
        amount: 1000,
        categoryId: catId,
        currencyCode: 'USD',
        nativeAmount: 7200,
      );
      await insertTx(
        ledgerId: ledgerId,
        amount: 500,
        categoryId: catId,
        excludeFromStats: true,
      );
      await insertTx(ledgerId: ledgerId, amount: 300, categoryId: catId);

      final summary = await repo.getCategorySummary(
        catId,
        ledgerId: ledgerId,
      );
      expect(summary.totalCount, 3); // 笔数含排除项
      expect(summary.totalAmount, 75.0); // 72 + 3，排除 5
      expect(summary.averageAmount, 37.5);
    });

    test('分类汇总与排序按账本隔离不同本位币', () async {
      final cnyLedgerId = await createExpenseLedger(
        name: '人民币账本',
        currency: 'CNY',
      );
      final usdLedgerId = await createExpenseLedger(
        name: '美元账本',
        currency: 'USD',
      );
      final catId = await repo.createCategory(name: '共用分类', kind: 'expense');

      await insertTx(
        ledgerId: cnyLedgerId,
        amount: 10000,
        categoryId: catId,
        currencyCode: 'CNY',
        nativeAmount: 10000,
      );
      await insertTx(
        ledgerId: cnyLedgerId,
        amount: 5000,
        categoryId: catId,
        currencyCode: 'CNY',
        nativeAmount: 5000,
      );
      await insertTx(
        ledgerId: usdLedgerId,
        amount: 2500,
        categoryId: catId,
        currencyCode: 'USD',
        nativeAmount: 2500,
      );

      final summary = await repo.getCategorySummary(
        catId,
        ledgerId: cnyLedgerId,
      );
      expect(summary.totalCount, 2);
      expect(summary.totalAmount, 150.0);
      expect(summary.averageAmount, 75.0);

      final sorted = await repo.getTransactionsByCategoryWithSort(
        catId,
        ledgerId: cnyLedgerId,
        sortBy: 'amount',
      );
      expect(sorted, hasLength(2));
      expect(sorted.every((tx) => tx.ledgerId == cnyLedgerId), isTrue);
      expect(sorted.map((tx) => tx.nativeAmount), [10000, 5000]);
    });
  });

  group('分类交易查询', () {
    test('getTransactionsByCategoryWithSort 按金额/时间排序', () async {
      final ledgerId = await createExpenseLedger();
      final catId = await repo.createCategory(name: '交通', kind: 'expense');
      await insertTx(
        ledgerId: ledgerId,
        amount: 1000,
        categoryId: catId,
        currencyCode: 'USD',
        nativeAmount: 700,
      );
      await insertTx(ledgerId: ledgerId, amount: 2000, categoryId: catId);

      // amount 排序按折算值（USD 快照 700 < 2000）
      final byAmount = await repo.getTransactionsByCategoryWithSort(
        catId,
        ledgerId: ledgerId,
        sortBy: 'amount',
      );
      expect(byAmount.first.amount, 2000);
      expect(byAmount.last.amount, 1000);

      final byAmountAsc = await repo.getTransactionsByCategoryWithSort(
        catId,
        ledgerId: ledgerId,
        sortBy: 'amount',
        ascending: true,
      );
      expect(byAmountAsc.first.amount, 1000);

      final byTime = await repo.getTransactionsByCategoryWithSort(
        catId,
        ledgerId: ledgerId,
      );
      expect(byTime, hasLength(2));
    });
  });

  group('迁移', () {
    test('二级分类迁移交易（无子分类分支）', () async {
      final ledgerId = await createExpenseLedger();
      final from = await repo.createCategory(
        name: '旧子',
        kind: 'expense',
        level: 2,
      );
      final to = await repo.createCategory(name: '新父', kind: 'expense');
      await insertTx(ledgerId: ledgerId, amount: 100, categoryId: from);

      final result = await repo.migrateCategoryTransactions(
        fromCategoryId: from,
        toCategoryId: to,
      );
      expect(result.migratedTransactions, 1);
      expect(result.migratedSubCategories, 0);

      final tx = await (db.select(db.transactions)
            ..where((t) => t.categoryId.equals(to)))
          .getSingle();
      expect(tx.amount, 100);
    });

    test('getCategoryMigrationInfo 目标缺失/相同分类不可迁移', () async {
      final a = await repo.createCategory(name: 'A', kind: 'expense');
      final b = await repo.createCategory(name: 'B', kind: 'expense');

      final noTarget = await repo.getCategoryMigrationInfo(
        fromCategoryId: a,
        toCategoryId: 9999,
      );
      expect(noTarget.canMigrate, isFalse);

      final same = await repo.getCategoryMigrationInfo(
        fromCategoryId: a,
        toCategoryId: a,
      );
      expect(same.canMigrate, isFalse);

      final ledgerId = await createExpenseLedger();
      await insertTx(ledgerId: ledgerId, amount: 100, categoryId: a);
      final ok = await repo.getCategoryMigrationInfo(
        fromCategoryId: a,
        toCategoryId: b,
      );
      expect(ok.canMigrate, isTrue);
    });
  });

  group('共享账本 synthetic watch 流', () {
    Future<int> createSharedLedger(String syncId) => db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: '共享',
            syncId: d.Value(syncId),
            isShared: d.Value(true),
          ),
        );

    Future<void> addSharedCategory({
      required String ledgerSyncId,
      required String syncId,
      required String name,
      int level = 1,
      String? parentSyncId,
    }) =>
        db.into(db.sharedLedgerCategories).insert(
              SharedLedgerCategoriesCompanion.insert(
                ledgerSyncId: ledgerSyncId,
                syncId: syncId,
                name: name,
                kind: 'expense',
                level: d.Value(level),
                parentSyncId: d.Value(parentSyncId),
                updatedAt: DateTime(2026, 8, 8),
              ),
            );

    Future<void> insertOverrideTx({
      required int ledgerId,
      required String categorySyncId,
      int amount = 100,
    }) =>
        db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                ledgerId: ledgerId,
                type: 'expense',
                amount: amount,
                categorySyncIdOverride: d.Value(categorySyncId),
                happenedAt: d.Value(DateTime(2026, 8, 8)),
              ),
            );

    test('watchCategory 负 id 反查共享分类（含父链与过滤）', () async {
      final ledgerId = await createSharedLedger('led-s1');
      await addSharedCategory(
        ledgerSyncId: 'led-s1',
        syncId: 'cat-p1',
        name: '共享父',
      );
      await addSharedCategory(
        ledgerSyncId: 'led-s1',
        syncId: 'cat-c1',
        name: '共享子',
        level: 2,
        parentSyncId: 'cat-p1',
      );
      final synthParent = syntheticIdForSyncId('cat-p1');
      final synthChild = syntheticIdForSyncId('cat-c1');

      final parent = await repo
          .watchCategory(synthParent, ledgerSyncId: 'led-s1')
          .first;
      expect(parent?.name, '共享父');
      expect(parent?.id, synthParent);
      expect(parent?.syncId, 'cat-p1');

      final child = await repo
          .watchCategory(synthChild, ledgerSyncId: 'led-s1')
          .first;
      expect(child?.parentId, synthParent);

      // 其他账本反查不到（ledgerSyncId 过滤）
      final other = await repo
          .watchCategory(synthParent, ledgerSyncId: 'led-other')
          .first;
      expect(other, isNull);
      expect(ledgerId, greaterThan(0));
    });

    test('watchTransactionsByCategory 负 id 单分类与含子分类', () async {
      final ledgerId = await createSharedLedger('led-s2');
      await addSharedCategory(
        ledgerSyncId: 'led-s2',
        syncId: 'cat-x',
        name: '共享餐饮',
      );
      await addSharedCategory(
        ledgerSyncId: 'led-s2',
        syncId: 'cat-x-sub',
        name: '共享外卖',
        level: 2,
        parentSyncId: 'cat-x',
      );
      final synth = syntheticIdForSyncId('cat-x');

      final direct = await repo
          .watchTransactionsByCategory(synth, ledgerId: ledgerId)
          .first;
      expect(direct, isEmpty);

      await insertOverrideTx(
        ledgerId: ledgerId,
        categorySyncId: 'cat-x-sub',
        amount: 250,
      );

      // 单分类视角：只含自身 override
      final single = await repo
          .watchTransactionsByCategory(synth, ledgerId: ledgerId)
          .first;
      expect(single, isEmpty);
      final subSynth = syntheticIdForSyncId('cat-x-sub');
      final subView = await repo
          .watchTransactionsByCategory(subSynth, ledgerId: ledgerId)
          .first;
      expect(subView.single.amount, 250);

      // 含子分类视角：父分类能看到子分类交易
      final withSubs = await repo
          .watchTransactionsByCategory(
            synth,
            ledgerId: ledgerId,
            includeSubCategories: true,
          )
          .first;
      expect(withSubs.single.amount, 250);
    });

    test('watchTransactionsByCategory 负 id 无匹配 → 空列表', () async {
      final ledgerId = await createSharedLedger('led-s3');
      final ghost = syntheticIdForSyncId('ghost-cat');
      final list = await repo
          .watchTransactionsByCategory(ghost, ledgerId: ledgerId)
          .first;
      expect(list, isEmpty);
    });

    test('watchCategory 共享分类变化后 re-emit', () async {
      await createSharedLedger('led-s4');
      await addSharedCategory(
        ledgerSyncId: 'led-s4',
        syncId: 'cat-live',
        name: '旧名',
      );
      final synth = syntheticIdForSyncId('cat-live');

      final stream = repo.watchCategory(synth, ledgerSyncId: 'led-s4');
      final events = <Category?>[];
      final sub = stream.listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await (db.update(db.sharedLedgerCategories)
            ..where((t) => t.syncId.equals('cat-live')))
          .write(const SharedLedgerCategoriesCompanion(name: d.Value('新名')));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
      expect(events.map((c) => c?.name), contains('新名'));
    });

    test('getAllCategoriesIncludingShared 并共享分类且按 synthetic id 去重', () async {
      await repo.createCategory(name: '本地', kind: 'expense');
      await createSharedLedger('led-s5');
      await addSharedCategory(
        ledgerSyncId: 'led-s5',
        syncId: 'cat-dup',
        name: '共享A',
      );
      // 同一 owner 分类镜像到两个账本 → 只保留一个 synthetic id
      await createSharedLedger('led-s6');
      await addSharedCategory(
        ledgerSyncId: 'led-s6',
        syncId: 'cat-dup',
        name: '共享A-镜像',
      );

      final all = await repo.getAllCategoriesIncludingShared();
      expect(all, hasLength(2));
      final shared = all.where((c) => c.id < 0).toList();
      expect(shared, hasLength(1));
      expect(shared.single.syncId, 'cat-dup');
    });

    test('batchInsertCategories / insertCategory 落库', () async {
      await repo.batchInsertCategories([
        CategoriesCompanion.insert(name: '批量A', kind: 'expense'),
        CategoriesCompanion.insert(name: '批量B', kind: 'expense'),
      ]);
      final id = await repo.insertCategory(
        CategoriesCompanion.insert(name: '单个', kind: 'expense'),
      );
      expect(id, greaterThan(0));
      expect(await repo.getAllCategories(), hasLength(3));
    });
  });

  group('picker 过滤', () {
    test('getUsableCategories 按 kind 过滤并复用层级规则', () async {
      await repo.createCategory(name: '餐饮', kind: 'expense');
      await repo.createCategory(name: '工资', kind: 'income');

      final usable = await repo.getUsableCategories('expense');
      expect(usable.single.name, '餐饮');
    });

    test('isCategoryNameDuplicate 支持 excludeId 与父级作用域', () async {
      final parent = await repo.createCategory(name: '父', kind: 'expense');
      final child = await repo.createCategory(
        name: '子',
        kind: 'expense',
        parentId: parent,
        level: 2,
      );

      expect(
        await repo.isCategoryNameDuplicate(
          name: '子',
          kind: 'expense',
          parentId: parent,
        ),
        isTrue,
      );
      expect(
        await repo.isCategoryNameDuplicate(
          name: '子',
          kind: 'expense',
          parentId: parent,
          excludeId: child,
        ),
        isFalse,
      );
    });

    test('filterCategoriesForLedgerPicker 共享 Editor 替换为主表', () async {
      await repo.createCategory(name: '本地分类', kind: 'expense');
      final sharedId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: '共享账本',
              syncId: d.Value('led-picker'),
              isShared: d.Value(true),
              myRole: d.Value('editor'),
            ),
          );
      await db.into(db.sharedLedgerCategories).insert(
            SharedLedgerCategoriesCompanion.insert(
              ledgerSyncId: 'led-picker',
              syncId: 'cat-picker',
              name: '共享分类',
              kind: 'expense',
              updatedAt: DateTime(2026, 8, 8),
            ),
          );
      final all = await repo.getAllCategories();
      final filtered = await repo.filterCategoriesForLedgerPicker(
        all,
        ledgerId: sharedId,
      );
      expect(filtered.single.name, '共享分类');
      expect(filtered.single.id, lessThan(0));
    });
  });
}
