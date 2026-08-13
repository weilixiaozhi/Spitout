import 'package:drift/drift.dart' as d;

import 'package:spitout/data/db.dart';
import 'package:spitout/utils/date/month_range.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';

/// 本地统计Repository实现
/// 基于 Drift 数据库实现
class LocalStatisticsRepository {
  final SpitoutDatabase db;

  LocalStatisticsRepository(this.db);

  Future<List<({int? id, String name, String? icon, double total})>> totalsByCategory({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.excludeFromStats.equals(false) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end)))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);
    final rows = await q.get();
    final shared = await _loadSharedCategoriesForLedger(ledgerId);
    final map = <int?, int>{};
    final names = <int?, String>{};
    final icons = <int?, String?>{};
    for (final r in rows) {
      final t = r.readTable(db.transactions);
      final c = r.readTableOrNull(db.categories);
      int? id = c?.id;
      String name = c?.name ?? '未分类';
      String? icon = c?.icon;
      // Editor 写的 tx categoryId 为空,但 categorySyncIdOverride
      // 指向 Owner 的分类 syncId — 查 SharedLedgerCategories 兜底。
      if (c == null && t.categorySyncIdOverride != null) {
        final s = shared[t.categorySyncIdOverride!];
        if (s != null) {
          id = syntheticIdForSyncId(s.syncId);
          name = s.name;
          icon = s.icon;
        }
      }
      names[id] = name;
      icons[id] = icon;
      map.update(id, (v) => v + (t.nativeAmount ?? t.amount),
          ifAbsent: () => t.nativeAmount ?? t.amount);
    }
    final list = map.entries
        .map((e) => (id: e.key, name: names[e.key] ?? '未分类', icon: icons[e.key], total: e.value / 100))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// 加载当前账本的 SharedLedger 分类索引(by syncId)。单人账本返回空 map,
  /// 共享账本返回 Owner user-global 的镜像。
  Future<Map<String, SharedLedgerCategory>> _loadSharedCategoriesForLedger(
      int ledgerId) async {
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final syncId = ledger?.syncId;
    if (syncId == null || syncId.isEmpty) return const {};
    final rows = await (db.select(db.sharedLedgerCategories)
          ..where((t) => t.ledgerSyncId.equals(syncId)))
        .get();
    return {for (final r in rows) r.syncId: r};
  }

  Future<Map<int, Category>> getSharedSyntheticCategoriesForLedger(
      int ledgerId) async {
    final shared = await _loadSharedCategoriesForLedger(ledgerId);
    if (shared.isEmpty) return const {};
    return {
      for (final s in shared.values)
        syntheticIdForSyncId(s.syncId): Category(
          id: syntheticIdForSyncId(s.syncId),
          name: s.name,
          kind: s.kind,
          icon: s.icon,
          sortOrder: s.sortOrder,
          // 二级分类层级:转 synthetic 父 id,让 analytics 的
          // L2→L1 rollup 找到 SharedLedger* 父分类(主表查不到这些 negative id)。
          parentId: (s.parentSyncId != null && s.parentSyncId!.isNotEmpty)
              ? syntheticIdForSyncId(s.parentSyncId!)
              : null,
          level: s.level,
          syncId: s.syncId,
        )
    };
  }

  Future<List<({int? id, String name, String? icon, int? parentId, int level, double total})>>
      totalsByCategoryWithHierarchy({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final q = (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.excludeFromStats.equals(false) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end)))
        .join([
      d.leftOuterJoin(db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);

    final rows = await q.get();
    final shared = await _loadSharedCategoriesForLedger(ledgerId);
    final map = <int?, int>{};
    final categoryInfo = <int?, ({String name, String? icon, int? parentId, int level})>{};

    for (final r in rows) {
      final t = r.readTable(db.transactions);
      final c = r.readTableOrNull(db.categories);
      int? id = c?.id;

      if (c != null) {
        categoryInfo[id] = (
          name: c.name,
          icon: c.icon,
          parentId: c.parentId,
          level: c.level,
        );
      } else if (t.categorySyncIdOverride != null &&
          shared[t.categorySyncIdOverride!] != null) {
        // Editor 写的 tx 用 categorySyncIdOverride 指向 Owner
        // 的分类,主表 join 不到,查 SharedLedger* 兜底。用 synthetic 负 id
        // 做聚合 key,跟 picker filter 保持一致。
        // 二级分类层级:SharedLedger* 行有父分类 syncId — 转 synthetic 负 id
        // 写入 parentId,让 analytics 的 L2→L1 rollup 正确累加,而不是把 L2 当 orphan 丢掉。
        final s = shared[t.categorySyncIdOverride!]!;
        id = syntheticIdForSyncId(s.syncId);
        final pSyncId = s.parentSyncId;
        final parentSyntheticId = (pSyncId != null && pSyncId.isNotEmpty)
            ? syntheticIdForSyncId(pSyncId)
            : null;
        categoryInfo[id] = (
          name: s.name,
          icon: s.icon,
          parentId: parentSyntheticId,
          level: s.level,
        );
      } else {
        categoryInfo[id] = (
          name: '未分类',
          icon: null,
          parentId: null,
          level: 1,
        );
      }

      map.update(id, (v) => v + (t.nativeAmount ?? t.amount),
          ifAbsent: () => t.nativeAmount ?? t.amount);
    }

    final list = map.entries.map((e) {
      final info = categoryInfo[e.key]!;
      return (
        id: e.key,
        name: info.name,
        icon: info.icon,
        parentId: info.parentId,
        level: info.level,
        total: e.value / 100,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return list;
  }

  Future<List<({DateTime day, double total})>> totalsByDay({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.excludeFromStats.equals(false) &
              t.happenedAt.isBiggerOrEqualValue(start) & t.happenedAt.isSmallerThanValue(end)))
        .get();
    final map = <DateTime, int>{};
    for (final t in rows) {
      final dt = t.happenedAt.toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      map.update(day, (v) => v + (t.nativeAmount ?? t.amount),
          ifAbsent: () => t.nativeAmount ?? t.amount);
    }
    // ensure full range continuity
    final result = <({DateTime day, double total})>[];
    for (DateTime d = DateTime(start.year, start.month, start.day);
        d.isBefore(end);
        d = d.add(const Duration(days: 1))) {
      result.add((day: d, total: (map[d] ?? 0) / 100));
    }
    return result;
  }

  Future<List<({DateTime month, double total})>> totalsByMonth({
    required int ledgerId,
    required String type,
    required int year,
  }) async {
    final sd = await _monthStartDayOf(ledgerId);
    final yr = yearRangeFor(year, sd);
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.excludeFromStats.equals(false) &
              t.happenedAt.isBiggerOrEqualValue(yr.start) &
              t.happenedAt.isSmallerThanValue(yr.end)))
        .get();
    final map = <int, int>{};
    for (final t in rows) {
      // 年范围 [当年1月周期起点, 次年1月周期起点) 内的标签必属 year,直接取 month
      final label = labelForDate(t.happenedAt.toLocal(), sd);
      map.update(label.month, (v) => v + (t.nativeAmount ?? t.amount),
          ifAbsent: () => t.nativeAmount ?? t.amount);
    }
    final result = <({DateTime month, double total})>[];
    for (int m = 1; m <= 12; m++) {
      result.add((month: DateTime(year, m, 1), total: (map[m] ?? 0) / 100));
    }
    return result;
  }

  Future<List<({int year, double total})>> totalsByYearSeries({
    required int ledgerId,
    required String type,
  }) async {
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals(type) &
              t.excludeFromStats.equals(false)))
        .get();
    if (rows.isEmpty) return const [];
    final sd = await _monthStartDayOf(ledgerId);
    final map = <int, int>{};
    int minYear = 9999, maxYear = 0;
    for (final t in rows) {
      final y = labelForDate(t.happenedAt.toLocal(), sd).year;
      if (y < minYear) minYear = y;
      if (y > maxYear) maxYear = y;
      map.update(y, (v) => v + (t.nativeAmount ?? t.amount),
          ifAbsent: () => t.nativeAmount ?? t.amount);
    }
    final out = <({int year, double total})>[];
    for (int y = minYear; y <= maxYear; y++) {
      out.add((year: y, total: (map[y] ?? 0) / 100));
    }
    return out;
  }

  Future<DateTime?> earliestExpenseDate({required int ledgerId}) async {
    // 取该账本最早一笔支出（未排除统计）的 happened_at，本地时区
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals('expense') &
              t.excludeFromStats.equals(false))
          ..orderBy([(t) => d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.asc)])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return rows.first.happenedAt.toLocal();
  }

  Future<DateTime?> latestExpenseDate({required int ledgerId}) async {
    // 取该账本最晚一笔支出（未排除统计）的 happened_at，本地时区
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.type.equals('expense') &
              t.excludeFromStats.equals(false))
          ..orderBy([(t) => d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc)])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return rows.first.happenedAt.toLocal();
  }

  Future<bool> hasAnyExpenseTx({required int ledgerId}) async {
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions '
      'WHERE ledger_id = ?1 AND type = ?2 AND exclude_from_stats = 0',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<String>('expense'),
      ],
      readsFrom: {db.transactions},
    ).getSingle();
    final v = row.data['c'];
    if (v is int) return v > 0;
    if (v is BigInt) return v > BigInt.zero;
    if (v is num) return v > 0;
    return false;
  }

  Future<double> totalsInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    // 全局仅支出模式，SQL 简化为只聚合支出
    final result = await db.customSelect(
      '''
      SELECT
        COALESCE(SUM(COALESCE(native_amount, amount)), 0) AS expense
      FROM transactions
      WHERE ledger_id = ?1 AND happened_at >= ?2 AND happened_at < ?3
        AND exclude_from_stats = 0
        AND type = 'expense'
      ''',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<DateTime>(start),
        d.Variable<DateTime>(end),
      ],
      readsFrom: {db.transactions},
    ).getSingle();

    // SQL 聚合结果为整数分,转"元"再返回(展示/统计口径保持元)。
    final cents = (result.data['expense'] as num?)?.toDouble() ?? 0.0;
    return cents / 100;
  }

  /// 读取账本的自定义每月起始日(1-28);账本缺失或查询异常时按 1(自然月)降级
  /// —— watch 流经 Stream.fromFuture 包裹,这里抛错会让流永久进 error 态。
  Future<int> _monthStartDayOf(int ledgerId) async {
    try {
      final row = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingleOrNull();
      return (row?.monthStartDay ?? 1).clamp(1, 28);
    } catch (_) {
      return 1;
    }
  }

  Future<double> monthlyTotals({
    required int ledgerId,
    required DateTime month,
  }) async {
    final sd = await _monthStartDayOf(ledgerId);
    final range = periodForLabel(month.year, month.month, sd);
    final start = range.start;
    final end = range.end;

    // 全局仅支出模式，SQL 简化为只聚合支出
    final result = await db.customSelect(
      '''
      SELECT
        COALESCE(SUM(COALESCE(native_amount, amount)), 0) AS expense
      FROM transactions
      WHERE ledger_id = ?1 AND happened_at >= ?2 AND happened_at < ?3
        AND exclude_from_stats = 0
        AND type = 'expense'
      ''',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<DateTime>(start),
        d.Variable<DateTime>(end),
      ],
      readsFrom: {db.transactions},
    ).getSingle();

    final cents = (result.data['expense'] as num?)?.toDouble() ?? 0.0;
    return cents / 100;
  }

  Future<double> todayExpense({
    required int ledgerId,
    required DateTime now,
  }) async {
    // 本地时区自然日 [0:00, 次日0:00),复用 totalsInRange 聚合逻辑。
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return totalsInRange(ledgerId: ledgerId, start: start, end: end);
  }

  Future<double> weekExpense({
    required int ledgerId,
    required DateTime now,
  }) async {
    // 周一为一周起始(weekday: 1=周一...7=周日),回退到本周一 0:00,加 7 天为下周一。
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return totalsInRange(ledgerId: ledgerId, start: weekStart, end: weekEnd);
  }

  Future<double> yearlyTotals({
    required int ledgerId,
    required int year,
  }) async {
    final sd = await _monthStartDayOf(ledgerId);
    final range = yearRangeFor(year, sd);
    final start = range.start;
    final end = range.end;

    // 全局仅支出模式，SQL 简化为只聚合支出
    final result = await db.customSelect(
      '''
      SELECT
        COALESCE(SUM(COALESCE(native_amount, amount)), 0) AS expense
      FROM transactions
      WHERE ledger_id = ?1 AND happened_at >= ?2 AND happened_at < ?3
        AND exclude_from_stats = 0
        AND type = 'expense'
      ''',
      variables: [
        d.Variable<int>(ledgerId),
        d.Variable<DateTime>(start),
        d.Variable<DateTime>(end),
      ],
      readsFrom: {db.transactions},
    ).getSingle();

    final cents = (result.data['expense'] as num?)?.toDouble() ?? 0.0;
    return cents / 100;
  }
}
