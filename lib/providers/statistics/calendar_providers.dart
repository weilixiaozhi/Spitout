import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
// 精确导入而非 barrel 自引用，避免 providers.dart export 本文件时形成循环依赖
import 'package:spitout/providers/core/database_providers.dart';

/// 获取指定月份的每日统计
/// 参数: (ledgerId, month)
final dailyTotalsByMonthProvider = FutureProvider.autoDispose
    .family<Map<String, double>, ({int ledgerId, DateTime month})>(
  (ref, params) async {
    // 监听统一数据变更信号：任意业务表写入都会触发每日金额重算。
    ref.watch(dataChangeSignalProvider);

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
    // 监听统一数据变更信号：任意业务表写入都会触发当日列表重算。
    ref.watch(dataChangeSignalProvider);

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
  // 监听统一数据变更信号：导入/同步历史数据后最早日期需要重算。
  ref.watch(dataChangeSignalProvider);
  final ledger = ref.watch(currentLedgerProvider).value;
  if (ledger == null) return DateTime(2020, 1, 1);
  final earliest = await ref
      .watch(repositoryProvider)
      .earliestExpenseDate(ledgerId: ledger.id);
  if (earliest == null) return DateTime(2020, 1, 1);
  return DateTime(earliest.year, earliest.month, 1);
});
