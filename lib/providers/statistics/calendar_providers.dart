import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';
// 精确导入而非 barrel 自引用，避免 all_providers.dart export 本文件时形成循环依赖
import 'package:spitout/providers/core/database_providers.dart';

/// 当前选中的日历月份（默认当前月）
final calendarSelectedMonthProvider =
    NotifierProvider<SimpleStateNotifier<DateTime>, DateTime>(() {
  return SimpleStateNotifier((ref) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  });
});

/// 当前选中的日期（默认 null，未选中任何日期）
final calendarSelectedDateProvider =
    NotifierProvider<SimpleStateNotifier<DateTime?>, DateTime?>(
  () => SimpleStateNotifier((ref) => null),
);

/// 获取指定月份的每日统计
/// 参数: (ledgerId, month)
final dailyTotalsByMonthProvider = FutureProvider.autoDispose
    .family<Map<String, double>, ({int ledgerId, DateTime month})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);
    return repo.getDailyTotalsByMonth(
      ledgerId: params.ledgerId,
      month: params.month,
    );
  },
);

/// 获取选中日期的交易详情（不含标签/附件字段）
/// 参数: (ledgerId, date)
final transactionsByDateProvider = FutureProvider.autoDispose.family<
    List<({Transaction t, Category? category})>,
    ({int ledgerId, DateTime date})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);
    return repo.getTransactionsByDate(
      ledgerId: params.ledgerId,
      date: params.date,
    );
  },
);

/// 日历可翻到的最早月份:账本最早支出交易所在月的 1 号。
///
/// 无数据/无账本时保守回退 2020-01-01,避免历史交易早于硬编码下限时
/// 无法翻页查看(数据仍在,用户会误以为丢失)。
final calendarEarliestDateProvider = FutureProvider<DateTime>((ref) async {
  // 监听刷新触发:导入/同步历史数据后最早日期需要重算。
  ref.watch(calendarRefreshProvider);
  final ledger = ref.watch(currentLedgerProvider).value;
  if (ledger == null) return DateTime(2020, 1, 1);
  final earliest = await ref
      .watch(repositoryProvider)
      .earliestExpenseDate(ledgerId: ledger.id);
  if (earliest == null) return DateTime(2020, 1, 1);
  return DateTime(earliest.year, earliest.month, 1);
});

/// 日历刷新触发器（添加/删除交易后触发）
final calendarRefreshProvider =
    NotifierProvider<TickStateNotifier, int>(() => TickStateNotifier((ref) => 0));
