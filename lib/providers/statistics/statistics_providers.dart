import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/core/database_providers.dart';

// 统计：某账本的记账天数与总笔数
final countsForLedgerProvider = FutureProvider.family
    .autoDispose<({int dayCount, int txCount}), int>((ref, ledgerId) async {
  final repo = ref.watch(repositoryProvider);
  // 依赖 tick 触发刷新
  ref.watch(statsRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return repo.getCountsForLedger(ledgerId: ledgerId);
});

// 统计刷新 tick（全局）：每次 +1 触发统计相关 Provider 重新获取
final statsRefreshProvider = StateProvider<int>((ref) => 0);

// 统计：月度支出汇总最近值（避免 loading 闪烁），全局仅支出模式
final lastMonthlyTotalsProvider = StateProvider.family<double?, ({int ledgerId, DateTime month})>((ref, params) => null);

// 统计：月度支出汇总（全局仅支出模式，只返回支出金额）
final monthlyTotalsProvider = FutureProvider.family
    .autoDispose<double, ({int ledgerId, DateTime month})>(
        (ref, params) async {
  final repo = ref.watch(repositoryProvider);
  // 依赖 tick 触发刷新
  ref.watch(statsRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  final res = await repo.monthlyTotals(ledgerId: params.ledgerId, month: params.month);
  // 全局仅支出模式, repo 直接返回 double
  final expense = res;
  // 写入最近一次成功值，供 UI 在刷新期间显示旧值
  ref.read(lastMonthlyTotalsProvider(params).notifier).state = expense;
  return expense;
});

// 统计：今日支出最近值（避免 loading 闪烁）
final lastTodayExpenseProvider =
    StateProvider.family<double?, int>((ref, ledgerId) => null);

// 统计：今日支出（本地时区自然日，全局仅支出模式）
// now 在 provider 内部取 DateTime.now(),外部只需传 ledgerId。
// 对应设计稿首页"本月支出汇总卡"的"今日"列。
final todayExpenseProvider = FutureProvider.family
    .autoDispose<double, int>((ref, ledgerId) async {
  final repo = ref.watch(repositoryProvider);
  // 依赖 tick 触发刷新(与 monthlyTotals 同 tick,手动刷新/恢复后同步更新)
  ref.watch(statsRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  final expense =
      await repo.todayExpense(ledgerId: ledgerId, now: DateTime.now());
  ref.read(lastTodayExpenseProvider(ledgerId).notifier).state = expense;
  return expense;
});

// 统计：本周支出最近值（避免 loading 闪烁）
final lastWeekExpenseProvider =
    StateProvider.family<double?, int>((ref, ledgerId) => null);

// 统计：本周支出（周一为起始的自然周，全局仅支出模式）
// 对应设计稿首页"本月支出汇总卡"的"本周"列。
final weekExpenseProvider = FutureProvider.family
    .autoDispose<double, int>((ref, ledgerId) async {
  final repo = ref.watch(repositoryProvider);
  ref.watch(statsRefreshProvider);
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  final expense =
      await repo.weekExpense(ledgerId: ledgerId, now: DateTime.now());
  ref.read(lastWeekExpenseProvider(ledgerId).notifier).state = expense;
  return expense;
});

// ---------- 统计页（AnalyticsPage）专用 provider ----------

/// 统计页：当前账本是否有任意支出交易（区分全局空数据 vs 局部空数据）。
/// watch statsRefresh 确保同步/导入后重判。
final analyticsHasAnyExpenseProvider = FutureProvider<bool>((ref) async {
  ref.watch(statsRefreshProvider);
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  if (ledger == null) return false;
  final repo = ref.watch(repositoryProvider);
  return repo.hasAnyExpenseTx(ledgerId: ledger.id);
});

/// 统计页：当前账本支出交易的最早/最晚时间（本地时区），用于子 Tab 按真实
/// 数据范围生成。无数据返回 (null, null)。
final analyticsDataRangeProvider =
    FutureProvider<({DateTime? earliest, DateTime? latest})>((ref) async {
  ref.watch(statsRefreshProvider);
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  if (ledger == null) return (earliest: null, latest: null);
  final repo = ref.watch(repositoryProvider);
  final results = await Future.wait<dynamic>([
    repo.earliestExpenseDate(ledgerId: ledger.id),
    repo.latestExpenseDate(ledgerId: ledger.id),
  ]);
  return (earliest: results[0] as DateTime?, latest: results[1] as DateTime?);
});