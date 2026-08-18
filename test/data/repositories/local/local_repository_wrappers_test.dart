// LocalRepository 薄委托层测试（changeTracker == null 场景）。
//
// LocalRepository 是门面：绝大多数方法直接把请求转发给各子仓库。测试锚点
// 是「转发不能丢参数 / 不能静默改语义」，覆盖此前未触达的委托路径：
//   - 账本：purge 系列 / 最大 id / watch 流
//   - 交易：watch 流 / syncId 系列 / 编辑历史 / 外币集合
//   - 分类：picker 过滤 / 计数 / 汇总 / 迁移信息
//   - 统计 / 周期 / 虚拟用户 / 汇率门面方法
library;

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createLedger({
    String name = '账本',
    String? syncId,
    String storageMode = 'local',
    int monthStartDay = 1,
    String currency = 'CNY',
  }) async {
    final id = await repo.createLedger(
      name: name,
      storageMode: storageMode,
      currency: currency,
    );
    if (syncId != null) {
      await repo.updateLedgerSyncId(id: id, syncId: syncId);
    }
    if (monthStartDay != 1) {
      await repo.updateLedger(id: id, monthStartDay: monthStartDay);
    }
    return id;
  }

  Future<int> addExpense(
    int ledgerId, {
    int amount = 100,
    DateTime? happenedAt,
    int? categoryId,
    String? currencyCode,
    int? nativeAmount,
  }) =>
      repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: amount,
        happenedAt: happenedAt ?? DateTime(2026, 8, 8, 12),
        categoryId: categoryId,
        currencyCode: currencyCode,
        nativeAmount: nativeAmount,
      );

  group('runInTransaction / 基础账本委托', () {
    test('runInTransaction 透传并在事务内提交', () async {
      final id = await repo.runInTransaction(
        () => createLedger(name: '事务账本'),
      );
      expect(await repo.getLedgerById(id), isNotNull);
    });

    test('watchLedgers / watchLedger 实时发射', () async {
      final id = await createLedger(name: 'watch');
      expect(await repo.watchLedgers().first, hasLength(1));
      final single = await repo.watchLedger(id).first;
      expect(single?.name, 'watch');
    });

    test('getMaxLedgerId / getNextFreeLedgerId 语义', () async {
      final a = await createLedger(name: 'a');
      await createLedger(name: 'b');
      expect(await repo.getMaxLedgerId(), greaterThanOrEqualTo(a));
      expect(await repo.getNextFreeLedgerId(), greaterThan(await repo.getMaxLedgerId()));
    });
  });

  group('purge / 清理委托', () {
    test('clearLocalChangesForLedger 只清指定账本的待推送变更', () async {
      final ledgerId = await createLedger(name: 'clear');
      await db.into(db.localChanges).insert(
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: 1,
              entitySyncId: 'tx-1',
              ledgerId: ledgerId,
              action: 'create',
            ),
          );
      await db.into(db.localChanges).insert(
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: 2,
              entitySyncId: 'tx-2',
              ledgerId: ledgerId + 100,
              action: 'create',
            ),
          );

      await repo.clearLocalChangesForLedger(ledgerId);

      final left = await db.select(db.localChanges).get();
      expect(left.single.ledgerId, ledgerId + 100);
    });

    test('normalizeOrphanCloudLedgers 把孤儿云账本改回本地', () async {
      final id = await createLedger(
        name: '孤儿云',
        syncId: 'orphan-1',
        storageMode: 'cloud',
      );
      final stats = await repo.normalizeOrphanCloudLedgers();
      expect(stats, (personal: 1, shared: 0));
      final ledger = await repo.getLedgerById(id);
      expect(ledger?.storageMode, 'local');
      expect(ledger?.syncId, isNull);
    });
  });

  group('交易 watch 流委托', () {
    test('watchRecentTransactions 按时间倒序 + limit', () async {
      final ledgerId = await createLedger(name: 'tx');
      await addExpense(ledgerId, amount: 100, happenedAt: DateTime(2026, 8, 8));
      await addExpense(ledgerId, amount: 200, happenedAt: DateTime(2026, 8, 9));
      await addExpense(ledgerId, amount: 300, happenedAt: DateTime(2026, 8, 10));

      final recent = await repo.watchRecentTransactions(
        ledgerId: ledgerId,
        limit: 2,
      ).first;
      expect(recent.map((t) => t.amount), [300, 200]);
    });

    test('watchTransactionsInMonth 按自然月过滤', () async {
      final ledgerId = await createLedger(name: 'month');
      await addExpense(ledgerId, happenedAt: DateTime(2026, 8, 15));
      await addExpense(ledgerId, happenedAt: DateTime(2026, 7, 15));

      final august = await repo
          .watchTransactionsInMonth(
            ledgerId: ledgerId,
            month: DateTime(2026, 8),
          )
          .first;
      expect(august, hasLength(1));
    });

    test('watchTransactionsWithCategory 系列流返回 tuple', () async {
      final ledgerId = await createLedger(name: 'tuple');
      final catId = await repo.createCategory(name: '餐饮', kind: 'expense');
      await addExpense(ledgerId, categoryId: catId);

      final all = await repo.watchTransactionsWithCategoryAll().first;
      expect(all.single.category?.name, '餐饮');

      final inMonth = await repo
          .watchTransactionsWithCategoryInMonth(
            ledgerId: ledgerId,
            month: DateTime(2026, 8),
          )
          .first;
      expect(inMonth, hasLength(1));

      final inYear = await repo
          .watchTransactionsWithCategoryInYear(
            ledgerId: ledgerId,
            year: 2026,
          )
          .first;
      expect(inYear, hasLength(1));

      final inRange = await repo
          .watchTransactionsForCategoryInRange(
            ledgerId: ledgerId,
            start: DateTime(2026, 8, 1),
            end: DateTime(2026, 9, 1),
            categoryId: catId,
            type: 'expense',
          )
          .first;
      expect(inRange, hasLength(1));
    });

    test('watchExcludedAaTransactions 只含排除统计的交易', () async {
      final ledgerId = await createLedger(name: 'excl');
      final excludedId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 100,
        happenedAt: DateTime(2026, 8, 8),
        aaMode: 1,
      );
      await addExpense(ledgerId);

      final list = await repo.watchExcludedAaTransactions(ledgerId).first;
      expect(list.single.t.id, excludedId);
    });
  });

  group('syncId / 编辑历史 / 外币集合委托', () {
    test('getTransactionBySyncId / updateTransactionBySyncId / '
        'deleteTransactionBySyncId', () async {
      final ledgerId = await createLedger(name: 'syncid');
      final txId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 100,
        happenedAt: DateTime(2026, 8, 8),
        syncId: 'tx-sync-1',
      );

      expect(
        (await repo.getTransactionBySyncId('tx-sync-1'))?.id,
        txId,
      );
      expect(await repo.getTransactionBySyncId('missing'), isNull);

      await repo.updateTransactionBySyncId(
        syncId: 'tx-sync-1',
        type: 'expense',
        amount: 250,
        happenedAt: DateTime(2026, 8, 9),
        note: '改过',
      );
      expect((await repo.getTransactionById(txId))?.amount, 250);

      await repo.deleteTransactionBySyncId('tx-sync-1');
      expect(await repo.getTransactionById(txId), isNull);
    });

    test('getEditHistories / appendEditHistory 版本倒序', () async {
      final ledgerId = await createLedger(name: 'hist');
      final txId = await addExpense(ledgerId);
      await repo.appendEditHistory(
        recordId: txId,
        version: 2,
        operatorUserId: 'u1',
        summary: '第一次编辑',
      );
      await repo.appendEditHistory(
        recordId: txId,
        version: 3,
        summary: '第二次编辑',
      );

      final histories = await repo.getEditHistories(txId);
      expect(histories.map((h) => h.version), [3, 2]);
      expect(histories.first.summary, '第二次编辑');
    });

    test('getLedgerForeignCurrencies 排除本位币、COALESCE 兜底', () async {
      final ledgerId = await createLedger(name: 'fx', currency: 'CNY');
      await addExpense(ledgerId, currencyCode: 'USD', nativeAmount: 720);
      await addExpense(ledgerId, currencyCode: 'JPY', nativeAmount: 1400);
      await addExpense(ledgerId);

      final currencies = await repo.getLedgerForeignCurrencies(ledgerId);
      expect(currencies, {'USD', 'JPY'});
    });
  });

  group('分类委托', () {
    test('picker 过滤 / 树 / 计数 / 汇总', () async {
      final parentId = await repo.createCategory(
        name: '餐饮',
        kind: 'expense',
        sortOrder: 1,
      );
      final childId = await repo.createSubCategory(
        parentId: parentId,
        name: '外卖',
        kind: 'expense',
      );
      final incomeId = await repo.createCategory(
        name: '工资',
        kind: 'income',
      );

      final all = await repo.getAllCategories();
      // 无账本上下文时按文档语义透传（个人账本/Owner 直接读主表）
      final filtered = await repo.filterCategoriesForLedgerPicker(all);
      expect(filtered, all);

      final byIds = await repo.getCategoriesByIds([parentId, childId]);
      expect(byIds.keys, containsAll([parentId, childId]));

      final top = await repo.getTopLevelCategories('expense');
      expect(top.map((c) => c.id), contains(parentId));

      final subs = await repo.getSubCategories(parentId);
      expect(subs.single.id, childId);

      final tree = await repo.getCategoryTree('expense');
      expect(tree.topLevel.map((c) => c.id), contains(parentId));

      final usable = await repo.getUsableCategories('expense');
      expect(usable, isNotEmpty);

      expect(await repo.hasSubCategories(parentId), isTrue);
      expect(await repo.getSubCategoryCount(parentId), 1);
      expect(await repo.getTransactionCountByCategory(parentId), 0);
      final allCounts = await repo.getAllCategoryTransactionCounts();
      expect(allCounts[parentId], 0);
      expect(allCounts, hasLength(3));
      expect(
        await repo.isCategoryNameDuplicate(name: '餐饮', kind: 'expense'),
        isTrue,
      );
      expect(
        await repo.isCategoryNameDuplicate(
          name: '餐饮',
          kind: 'expense',
          excludeId: parentId,
        ),
        isFalse,
      );

      // income 分类不参与 expense 树
      expect(await repo.getTopLevelCategories('income'), hasLength(1));
      expect(incomeId, isNot(parentId));
    });

    test('共享账本 Editor 视角 picker 替换为 synthetic 分类', () async {
      final sharedId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: '共享账本',
              syncId: d.Value('led-shared'),
              isShared: d.Value(true),
              myRole: d.Value('editor'),
            ),
          );
      await db.into(db.sharedLedgerCategories).insert(
            SharedLedgerCategoriesCompanion.insert(
              ledgerSyncId: 'led-shared',
              syncId: 'cat-shared-1',
              name: '共享餐饮',
              kind: 'expense',
              sortOrder: d.Value(1),
              level: d.Value(1),
              updatedAt: DateTime(2026, 8, 8),
            ),
          );

      final all = await repo.getAllCategories();
      final filtered = await repo.filterCategoriesForLedgerPicker(
        all,
        ledgerId: sharedId,
        kind: 'expense',
      );
      expect(filtered.single.name, '共享餐饮');
      expect(filtered.single.id, lessThan(0));
      expect(filtered.single.parentId, isNull);
    });

    test('分类汇总与按分类查交易（含 amount 排序）', () async {
      final ledgerId = await createLedger(name: 'cat-sum');
      final catId = await repo.createCategory(name: '交通', kind: 'expense');
      await addExpense(ledgerId, categoryId: catId, amount: 1000);
      await addExpense(ledgerId, categoryId: catId, amount: 2000);

      final summary = await repo.getCategorySummary(
        catId,
        ledgerId: ledgerId,
      );
      expect(summary.totalCount, 2);
      expect(summary.totalAmount, 30.0);
      expect(summary.averageAmount, 15.0);

      final byCat = await repo.getTransactionsByCategory(catId);
      expect(byCat, hasLength(2));

      final byAmount = await repo.getTransactionsByCategoryWithSort(
        catId,
        ledgerId: ledgerId,
        sortBy: 'amount',
      );
      expect(byAmount.first.amount, 2000);

      final byTime = await repo.getTransactionsByCategoryWithSort(
        catId,
        ledgerId: ledgerId,
        sortBy: 'time',
        ascending: true,
      );
      expect(byTime.first.amount, 1000);
    });

    test('getCategoryMigrationInfo 与迁移守卫', () async {
      final a = await repo.createCategory(name: '旧', kind: 'expense');
      final b = await repo.createCategory(name: '新', kind: 'expense');

      final info = await repo.getCategoryMigrationInfo(
        fromCategoryId: a,
        toCategoryId: b,
      );
      expect(info.transactionCount, 0);
      expect(info.canMigrate, isFalse);

      final ledgerId = await createLedger(name: 'mig');
      await addExpense(ledgerId, categoryId: a);
      final info2 = await repo.getCategoryMigrationInfo(
        fromCategoryId: a,
        toCategoryId: b,
      );
      expect(info2.canMigrate, isTrue);
    });
  });

  group('统计委托', () {
    test('totals 系列按账本/时间窗聚合', () async {
      final ledgerId = await createLedger(name: 'stat');
      final catId = await repo.createCategory(name: '餐饮', kind: 'expense');
      await addExpense(ledgerId, categoryId: catId, amount: 1200,
          happenedAt: DateTime(2026, 8, 8));
      await addExpense(ledgerId, amount: 800,
          happenedAt: DateTime(2026, 8, 20));

      final byCat = await repo.totalsByCategory(
        ledgerId: ledgerId,
        type: 'expense',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );
      expect(byCat.map((r) => r.name), contains('餐饮'));

      final hierarchy = await repo.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId,
        type: 'expense',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );
      expect(hierarchy, isNotEmpty);

      final byDay = await repo.totalsByDay(
        ledgerId: ledgerId,
        type: 'expense',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );
      // 按月聚合返回整月每一天（空日补 0），只校验有交易的两天
      expect(
        byDay.firstWhere((r) => r.day == DateTime(2026, 8, 8)).total,
        12.0,
      );
      expect(
        byDay.firstWhere((r) => r.day == DateTime(2026, 8, 20)).total,
        8.0,
      );

      final byMonth = await repo.totalsByMonth(
        ledgerId: ledgerId,
        type: 'expense',
        year: 2026,
      );
      // 返回整年 12 个月（空月补 0），只校验 8 月
      expect(
        byMonth.firstWhere((r) => r.month == DateTime(2026, 8)).total,
        20.0,
      );
      expect(
        byMonth.firstWhere((r) => r.month == DateTime(2026, 1)).total,
        0.0,
      );

      final byYear = await repo.totalsByYearSeries(
        ledgerId: ledgerId,
        type: 'expense',
      );
      expect(
        byYear.firstWhere((r) => r.year == 2026).total,
        20.0,
      );

      expect(
        await repo.earliestExpenseDate(ledgerId: ledgerId),
        DateTime(2026, 8, 8),
      );
      expect(
        await repo.latestExpenseDate(ledgerId: ledgerId),
        DateTime(2026, 8, 20),
      );
      expect(await repo.hasAnyExpenseTx(ledgerId: ledgerId), isTrue);
      expect(
        await repo.totalsInRange(
          ledgerId: ledgerId,
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 9, 1),
        ),
        20.0,
      );
      expect(
        await repo.monthlyTotals(ledgerId: ledgerId, month: DateTime(2026, 8)),
        20.0,
      );
      expect(
        await repo.todayExpense(
          ledgerId: ledgerId,
          now: DateTime(2026, 8, 8),
        ),
        12.0,
      );
      expect(
        await repo.weekExpense(ledgerId: ledgerId, now: DateTime(2026, 8, 9)),
        12.0,
      );
      expect(
        await repo.yearlyTotals(ledgerId: ledgerId, year: 2026),
        20.0,
      );
    });

    test('getSharedSyntheticCategoriesForLedger 映射共享分类', () async {
      final ledgerId = await createLedger(
        name: '共享账本',
        syncId: 'led-shared',
      );
      await db.into(db.sharedLedgerCategories).insert(
            SharedLedgerCategoriesCompanion.insert(
              ledgerSyncId: 'led-shared',
              syncId: 'cat-shared',
              name: '共享餐饮',
              kind: 'expense',
              updatedAt: DateTime(2026, 8, 8),
            ),
          );

      final map = await repo.getSharedSyntheticCategoriesForLedger(ledgerId);
      expect(map.values.single.name, '共享餐饮');
    });
  });

  group('周期模板委托', () {
    test('CRUD + watch 流', () async {
      final ledgerId = await createLedger(name: 'recurring');
      final id = await repo.addRecurringTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 5000,
        frequency: 'monthly',
        interval: 1,
        dayOfMonth: 15,
        startDate: DateTime(2026, 1, 1),
      );

      expect(
        (await repo.getRecurringTransactionsByLedger(ledgerId)).single.id,
        id,
      );
      expect(
        (await repo.getEnabledRecurringTransactions(ledgerId)).single.id,
        id,
      );
      expect(
        (await repo.watchAllRecurringTransactions().first).single.id,
        id,
      );
      expect(
        (await repo.watchRecurringTransactionsByLedger(ledgerId).first)
            .single
            .id,
        id,
      );

      await repo.updateRecurringTransaction(
        id: id,
        ledgerId: ledgerId,
        type: 'expense',
        amount: 6000,
        frequency: 'monthly',
        interval: 2,
        dayOfMonth: 20,
        startDate: DateTime(2026, 1, 1),
      );
      final updated = (await repo.getRecurringTransactionsByLedger(ledgerId))
          .single;
      expect(updated.amount, 6000);
      expect(updated.interval, 2);

      await repo.toggleRecurringTransaction(id, false);
      expect(
        (await repo.getRecurringTransactionsByLedger(ledgerId)).single.enabled,
        isFalse,
      );
      expect(
        await repo.getEnabledRecurringTransactions(ledgerId),
        isEmpty,
      );

      await repo.updateLastGeneratedDate(id, DateTime(2026, 8, 1));
      expect(
        (await repo.getRecurringTransactionsByLedger(ledgerId))
            .single
            .lastGeneratedDate,
        DateTime(2026, 8, 1),
      );

      await repo.batchInsertRecurringTransactions([
        RecurringTransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 100,
          frequency: 'daily',
          interval: d.Value(1),
          startDate: DateTime(2026, 8, 1),
        ),
      ]);
      expect(
        await repo.getRecurringTransactionsByLedger(ledgerId),
        hasLength(2),
      );

      await repo.deleteRecurringTransaction(id);
      expect(
        await repo.getRecurringTransactionsByLedger(ledgerId),
        hasLength(1),
      );
    });
  });

  group('虚拟用户委托', () {
    test('create / rename / delete / 查询 / 引用检查', () async {
      final ledgerId = await createLedger(name: 'vu');
      final id = await repo.create(ledgerId: ledgerId, name: '张三');

      expect((await repo.getByLedger(ledgerId)).single.id, id);
      expect((await repo.getBySyncId('任意'))?.id, isNot(id));
      expect(await repo.watchByLedger(ledgerId).first, hasLength(1));
      expect(await repo.isReferencedByAnyTransaction(id), isFalse);

      await repo.rename(id: id, name: '李四');
      expect((await repo.getByLedger(ledgerId)).single.name, '李四');

      expect(await repo.delete(id), isTrue);
      expect(await repo.getByLedger(ledgerId), isEmpty);
    });
  });

  group('汇率委托', () {
    test('auto rates 与 override 读写', () async {
      await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-08-08',
        rates: {'USD': '7.2', 'JPY': '0.05'},
        source: 'server',
        fetchedAt: DateTime(2026, 8, 8),
      );

      final latest = await repo.getLatestAutoRates('CNY');
      expect(latest, hasLength(2));
      expect(await repo.getLastFetchedAt('CNY'), DateTime(2026, 8, 8));

      await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.3');
      final overrides = await repo.getOverrides('CNY');
      expect(overrides.single.rate, '7.3');
      expect(await repo.watchOverrides('CNY').first, hasLength(1));

      await repo.removeOverride(base: 'CNY', quote: 'USD');
      expect(await repo.getOverrides('CNY'), isEmpty);
    });
  });

  group('零碎委托补充', () {
    test('交易查询系列委托', () async {
      final ledgerId = await createLedger(name: 'misc-tx');
      final catId = await repo.createCategory(name: '餐饮', kind: 'expense');
      await addExpense(ledgerId, categoryId: catId, amount: 100);
      await addExpense(ledgerId, categoryId: catId, amount: 200);

      final withCat = await repo.transactionsWithCategoryAll();
      expect(withCat, hasLength(2));
      expect(withCat.every((r) => r.category != null), isTrue);

      final recent = await repo.getRecentTransactionsWithCategory(
        ledgerId: ledgerId,
        limit: 1,
      );
      expect(recent.single.t.amount, 200);

      final count = await repo.countByTypeInRange(
        ledgerId: ledgerId,
        type: 'expense',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );
      expect(count, 2);

      expect(await repo.getTransactionsByLedger(ledgerId), hasLength(2));
      // aaMode=1 不分摊 → 从 AA 统计中排除；null/0 纳入
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 50,
        happenedAt: DateTime(2026, 8, 8),
        aaMode: 1,
      );
      expect(await repo.getAaTransactionsByLedger(ledgerId), hasLength(2));
      expect(
        await repo.getTransactionsByLedgerInRange(
          ledgerId: ledgerId,
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 9, 1),
        ),
        hasLength(3),
      );

      await repo.markTxAuthor(txId: recent.single.t.id, userId: 'u1',
          isCreate: false);
      final marked = await repo.getTransactionById(recent.single.t.id);
      expect(marked?.lastEditedByUserId, 'u1');
    });

    test('日历查询系列委托', () async {
      final ledgerId = await createLedger(name: 'misc-cal');
      await addExpense(ledgerId, amount: 100, happenedAt: DateTime(2026, 8, 8));

      final daily = await repo.getDailyTotalsByMonth(
        ledgerId: ledgerId,
        month: DateTime(2026, 8),
      );
      expect(daily['2026-08-08'], 1.0);

      final byDate = await repo.getTransactionsByDate(
        ledgerId: ledgerId,
        date: DateTime(2026, 8, 8),
      );
      expect(byDate.single.t.amount, 100);
    });

    test('分类迁移/排序/全名/watch 流委托', () async {
      final parent = await repo.createCategory(name: '餐饮', kind: 'expense');
      final child = await repo.createSubCategory(
        parentId: parent,
        name: '外卖',
        kind: 'expense',
      );
      final target = await repo.createCategory(name: '饮食', kind: 'expense');

      final migrated = await repo.migrateCategoryTransactions(
        fromCategoryId: parent,
        toCategoryId: target,
      );
      expect(migrated.migratedSubCategories, 1);

      final info = await repo.getCategoryMigrationInfo(
        fromCategoryId: child,
        toCategoryId: target,
      );
      expect(info, isA<({int transactionCount, bool canMigrate})>());

      await repo.updateCategorySortOrders([(id: parent, sortOrder: 5)]);
      // 子分类已随迁移移动到目标分类下
      expect(await repo.getCategoryFullName(child), '饮食 / 外卖');

      expect(await repo.watchCategory(parent).first, isNotNull);
      expect(
        await repo.watchTransactionsByCategory(parent, includeSubCategories: true)
            .first,
        isEmpty,
      );
      // 子分类已迁到目标分类下
      expect(await repo.watchCategoryWithSubs(target).first, hasLength(2));
      expect(await repo.watchCategoriesWithCount().first, hasLength(3));

      final includingShared = await repo.getAllCategoriesIncludingShared();
      expect(includingShared, hasLength(3));

      await repo.batchInsertCategories([
        CategoriesCompanion.insert(name: '批量', kind: 'expense'),
      ]);
      final inserted = await repo.insertCategory(
        CategoriesCompanion.insert(name: '单个', kind: 'expense'),
      );
      expect(inserted, greaterThan(0));
      expect(await repo.getAllCategories(), hasLength(5));
    });

    test('getUsedCurrencies 聚合账本内币种', () async {
      final ledgerId = await createLedger(name: 'cur');
      await addExpense(ledgerId, currencyCode: 'USD', nativeAmount: 100);
      await addExpense(ledgerId, currencyCode: 'JPY', nativeAmount: 200);

      expect(await repo.getUsedCurrencies(), {'USD', 'JPY'});
    });
  });
}
