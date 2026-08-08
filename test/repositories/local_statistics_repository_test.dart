// LocalStatisticsRepository 全方法测试：真实 SQLite 上验证统计聚合语义。
//
// 覆盖：按分类汇总（含共享账本 Editor 的 synthetic 分类）、层级汇总、
// 按日/月/年序列、最早/最晚支出、是否有支出、区间/月度/今日/本周/年度聚合，
// 以及 excludeFromStats 过滤与自定义月起始日的分账期语义。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/data/repositories/local/local_statistics_repository.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';

void main() {
  late SpitoutDatabase db;
  late LocalRepository repo;
  late LocalStatisticsRepository stats;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    stats = LocalStatisticsRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> seedLedger({int monthStartDay = 1}) {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: '统计账本',
            monthStartDay: Value(monthStartDay),
          ),
        );
  }

  Future<int> seedCategory(String name, {int? parentId, int level = 1}) {
    return db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            kind: 'expense',
            parentId: Value(parentId),
            level: Value(level),
            syncId: Value('cat-$name'),
          ),
        );
  }

  group('totalsByCategory', () {
    test('按分类聚合 + 未分类兜底 + exclude 过滤', () async {
      final lid = await seedLedger();
      final foodId = await seedCategory('餐饮');
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 7, 1);

      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 3000,
        categoryId: foodId,
        happenedAt: DateTime(2026, 6, 10),
      );
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 2000,
        happenedAt: DateTime(2026, 6, 11),
      );
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 9999,
        excludeFromStats: true,
        happenedAt: DateTime(2026, 6, 12),
      );

      final rows = await stats.totalsByCategory(
        ledgerId: lid,
        type: 'expense',
        start: start,
        end: end,
      );
      expect(rows, hasLength(2));
      expect(rows.firstWhere((r) => r.id == foodId).total, 30.0);
      expect(rows.firstWhere((r) => r.name == '未分类').total, 20.0);
    });
  });

  group('totalsByCategoryWithHierarchy', () {
    test('二级分类带 parentId 与 level', () async {
      final lid = await seedLedger();
      final parentId = await seedCategory('购物');
      final childId = await seedCategory('鞋子', parentId: parentId, level: 2);
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 7, 1);

      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 5000,
        categoryId: childId,
        happenedAt: DateTime(2026, 6, 10),
      );

      final rows = await stats.totalsByCategoryWithHierarchy(
        ledgerId: lid,
        type: 'expense',
        start: start,
        end: end,
      );
      final child = rows.firstWhere((r) => r.id == childId);
      expect(child.parentId, parentId);
      expect(child.level, 2);
      expect(child.total, 50.0);
    });

    test('共享账本 Editor：categorySyncIdOverride → synthetic 分类', () async {
      final lid = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: '共享账本',
              syncId: const Value('shared-ledger-1'),
              isShared: const Value(true),
              myRole: const Value('editor'),
            ),
          );
      // Owner 侧共享分类（镜像表）
      await db.into(db.sharedLedgerCategories).insert(
            SharedLedgerCategoriesCompanion.insert(
              ledgerSyncId: 'shared-ledger-1',
              syncId: 'owner-cat-1',
              name: '主人分类',
              kind: 'expense',
              level: const Value(2),
              parentSyncId: const Value('owner-cat-0'),
              updatedAt: DateTime(2026, 6, 1),
            ),
          );
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 1200,
        categorySyncIdOverride: 'owner-cat-1',
        happenedAt: DateTime(2026, 6, 10),
      );

      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 7, 1);
      final rows = await stats.totalsByCategoryWithHierarchy(
        ledgerId: lid,
        type: 'expense',
        start: start,
        end: end,
      );
      expect(rows, hasLength(1));
      expect(rows.first.name, '主人分类');
      expect(rows.first.id, syntheticIdForSyncId('owner-cat-1'));
      expect(rows.first.parentId, syntheticIdForSyncId('owner-cat-0'));
      expect(rows.first.total, 12.0);

      // synthetic 分类查询接口同样命中
      final synthetic = await stats.getSharedSyntheticCategoriesForLedger(lid);
      expect(synthetic[syntheticIdForSyncId('owner-cat-1')]?.name, '主人分类');
    });
  });

  group('时间序列聚合', () {
    test('totalsByDay 全区间连续（无数据日补 0）', () async {
      final lid = await seedLedger();
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 1000,
        happenedAt: DateTime(2026, 6, 10, 12),
      );
      final rows = await stats.totalsByDay(
        ledgerId: lid,
        type: 'expense',
        start: DateTime(2026, 6, 9),
        end: DateTime(2026, 6, 12),
      );
      expect(rows, hasLength(3));
      expect(rows[0].total, 0.0);
      expect(rows[1].total, 10.0);
      expect(rows[2].total, 0.0);
    });

    test('totalsByMonth 按自定义月起始日分账期', () async {
      final lid = await seedLedger(monthStartDay: 15);
      // 6/10 属于 5/15-6/14 账期（5 月标签）
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 3000,
        happenedAt: DateTime(2026, 6, 10),
      );
      // 6/20 属于 6/15-7/14 账期（6 月标签）
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 4000,
        happenedAt: DateTime(2026, 6, 20),
      );

      final rows = await stats.totalsByMonth(
        ledgerId: lid,
        type: 'expense',
        year: 2026,
      );
      expect(rows, hasLength(12));
      expect(rows[4].total, 30.0, reason: '6/10 归入 5 月账期');
      expect(rows[5].total, 40.0, reason: '6/20 归入 6 月账期');
    });

    test('totalsByYearSeries 跨年序列；空库返回空列表', () async {
      final lid = await seedLedger();
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 1000,
        happenedAt: DateTime(2025, 12, 31),
      );
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 2000,
        happenedAt: DateTime(2026, 1, 1),
      );
      final rows = await stats.totalsByYearSeries(
        ledgerId: lid,
        type: 'expense',
      );
      expect(rows.map((r) => r.year), [2025, 2026]);
      expect(rows.first.total, 10.0);

      final emptyLid = await seedLedger();
      expect(
        await stats.totalsByYearSeries(ledgerId: emptyLid, type: 'expense'),
        isEmpty,
      );
    });
  });

  group('日期边界与聚合金额', () {
    test('earliest/latest/hasAnyExpense：空库与有数据', () async {
      final lid = await seedLedger();
      expect(await stats.earliestExpenseDate(ledgerId: lid), isNull);
      expect(await stats.latestExpenseDate(ledgerId: lid), isNull);
      expect(await stats.hasAnyExpenseTx(ledgerId: lid), isFalse);

      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 1000,
        happenedAt: DateTime(2026, 6, 5),
      );
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 2000,
        happenedAt: DateTime(2026, 6, 20),
      );
      expect(await stats.earliestExpenseDate(ledgerId: lid),
          DateTime(2026, 6, 5));
      expect(await stats.latestExpenseDate(ledgerId: lid),
          DateTime(2026, 6, 20));
      expect(await stats.hasAnyExpenseTx(ledgerId: lid), isTrue);
    });

    test('totalsInRange / monthlyTotals / today / week / year', () async {
      final lid = await seedLedger();
      // 今日
      final now = DateTime(2026, 7, 8, 15);
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 1100,
        happenedAt: now,
      );
      // 本周一（7/6 周一）
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 2200,
        happenedAt: DateTime(2026, 7, 6, 9),
      );
      // 本月初（7/1）
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 3300,
        happenedAt: DateTime(2026, 7, 1, 9),
      );
      // 去年（2025 年）
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 4400,
        happenedAt: DateTime(2025, 7, 1),
      );

      expect(await stats.todayExpense(ledgerId: lid, now: now), 11.0);
      expect(
        await stats.weekExpense(ledgerId: lid, now: now),
        33.0,
        reason: '本周 = 周一 22 + 今日 11',
      );
      expect(
        await stats.monthlyTotals(ledgerId: lid, month: DateTime(2026, 7)),
        66.0,
      );
      expect(await stats.yearlyTotals(ledgerId: lid, year: 2026), 66.0);
      expect(await stats.yearlyTotals(ledgerId: lid, year: 2025), 44.0);
      expect(
        await stats.totalsInRange(
          ledgerId: lid,
          start: DateTime(2026, 1, 1),
          end: DateTime(2027, 1, 1),
        ),
        66.0,
      );
    });
  });
}
