/// 统计页子 Tab 生成算法（纯函数，便于单元测试）。
///
/// 设计意图：
/// - 无任何数据时，仅返回当前周期一个 Tab。
/// - 有数据时，按 earliest..latest 生成连续 Tab 列表（即便中间空也保留）。
/// - earliest == latest 时只返回一个 Tab。
/// - 列表按时间升序排列，UI 层默认选中最后一项（最新数据）。
library;

// 周日期纯函数（mondayOf / weekNumber / weeksInYear / mondayOfWeek）定义于
// lib/utils/date/week_math.dart，本文件直接复用。
import 'week_math.dart';

/// 统计周期类型枚举（'week'/'month'/'year' 的强类型版本）。
enum AnalyticsPeriod { week, month, year }

/// 子 Tab 项：id 唯一标识、label 显示文案、start/end 半开区间 [start, end)。
class AnalyticsSubTab {
  final String id;
  final String label;
  final DateTime start;
  final DateTime end;

  const AnalyticsSubTab({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
  });
}

/// 生成子 Tab 列表。
///
/// [period] 周期类型；[earliest]/[latest] 为账本内有数据的最早/最晚交易时间（本地时区），
/// 可为 null 表示无数据；[now] 注入当前时间便于测试；[monthStartDay] 账本每月起始日(1-28)，
/// 仅影响月/年视图的区间切分（与 periodForLabel 口径一致）。
///
/// 返回按时间升序的 Tab 列表；无数据时返回仅含「当前周期」一项的列表。
List<AnalyticsSubTab> generateSubTabs({
  required AnalyticsPeriod period,
  required DateTime? earliest,
  required DateTime? latest,
  required DateTime now,
  required int monthStartDay,
  required String Function(int month) monthLabel,
  required String Function(int weekNumber) weekNLabel,
    required String thisWeekLabel,
    required String Function(int year) yearLabel,
  }) {
  // 无数据时仅显示当前周/月/年
  if (earliest == null || latest == null) {
    return [_currentPeriodTab(period, now, monthStartDay, monthLabel, weekNLabel, thisWeekLabel, yearLabel)];
  }

  switch (period) {
    case AnalyticsPeriod.month:
      return _generateMonthTabs(earliest, latest, now, monthStartDay, monthLabel);
    case AnalyticsPeriod.year:
      return _generateYearTabs(earliest, latest, now, yearLabel);
    case AnalyticsPeriod.week:
      return _generateWeekTabs(earliest, latest, now, weekNLabel, thisWeekLabel);
  }
}

/// 生成当前周期对应的单个 Tab（无数据兜底）。
AnalyticsSubTab _currentPeriodTab(
  AnalyticsPeriod period,
  DateTime now,
  int monthStartDay,
  String Function(int month) monthLabel,
  String Function(int weekNumber) weekNLabel,
  String thisWeekLabel,
  String Function(int year) yearLabel,
) {
  switch (period) {
    case AnalyticsPeriod.month:
      final label = labelForMonth(now);
      final start = DateTime(label.year, label.month, monthStartDay.clamp(1, 28));
      final end = DateTime(label.year, label.month + 1, monthStartDay.clamp(1, 28));
      return AnalyticsSubTab(
        id: '${label.year}-${label.month.toString().padLeft(2, '0')}',
        label: monthLabel(label.month),
        start: start,
        end: end,
      );
    case AnalyticsPeriod.year:
      final y = now.year;
      return AnalyticsSubTab(
        id: '$y',
        label: yearLabel(y),
        start: DateTime(y, 1, 1),
        end: DateTime(y + 1, 1, 1),
      );
    case AnalyticsPeriod.week:
      final monday = mondayOf(now);
      return AnalyticsSubTab(
        id: '${monday.year}-W${weekNumber(monday)}',
        label: thisWeekLabel,
        start: monday,
        end: monday.add(const Duration(days: 7)),
      );
  }
}

/// 月视图 Tab：从 earliest 所在标签月到 latest 所在标签月，按月递增。
List<AnalyticsSubTab> _generateMonthTabs(
  DateTime earliest,
  DateTime latest,
  DateTime now,
  int monthStartDay,
  String Function(int month) monthLabel,
) {
  final sd = monthStartDay.clamp(1, 28);
  final startLabel = labelForMonth(earliest, sd);
  final endLabel = labelForMonth(latest, sd);
  final tabs = <AnalyticsSubTab>[];
  DateTime cur = DateTime(startLabel.year, startLabel.month, 1);
  final end = DateTime(endLabel.year, endLabel.month, 1);
  // 上限保护：极端情况（数据跨度过大）避免无限循环，最多 240 个月（20 年）。
  int guard = 0;
  while (!cur.isAfter(end) && guard < 240) {
    final start = DateTime(cur.year, cur.month, sd);
    final e = DateTime(cur.year, cur.month + 1, sd);
    tabs.add(AnalyticsSubTab(
      id: '${cur.year}-${cur.month.toString().padLeft(2, '0')}',
      label: monthLabel(cur.month),
      start: start,
      end: e,
    ));
    cur = DateTime(cur.year, cur.month + 1, 1);
    guard++;
  }
  return tabs;
}

/// 年视图 Tab：从 earliest 所在年到 latest 所在年，按年递增。
List<AnalyticsSubTab> _generateYearTabs(
  DateTime earliest,
  DateTime latest,
  DateTime now,
  String Function(int year) yearLabel,
) {
  final startY = earliest.year;
  final endY = latest.year;
  final tabs = <AnalyticsSubTab>[];
  for (var y = startY; y <= endY; y++) {
    tabs.add(AnalyticsSubTab(
      id: '$y',
      label: yearLabel(y),
      start: DateTime(y, 1, 1),
      end: DateTime(y + 1, 1, 1),
    ));
  }
  return tabs;
}

/// 周视图 Tab：从 earliest 所在周一到 latest 所在周一，按周一递增。
List<AnalyticsSubTab> _generateWeekTabs(
  DateTime earliest,
  DateTime latest,
  DateTime now,
  String Function(int weekNumber) weekNLabel,
  String thisWeekLabel,
) {
  final startMonday = mondayOf(earliest);
  final endMonday = mondayOf(latest);
  final tabs = <AnalyticsSubTab>[];
  DateTime cur = startMonday;
  // 上限保护：最多 520 周（约 10 年）。
  int guard = 0;
  while (!cur.isAfter(endMonday) && guard < 520) {
    final wn = weekNumber(cur);
    tabs.add(AnalyticsSubTab(
      id: '${cur.year}-W$wn',
      label: weekNLabel(wn),
      start: cur,
      end: cur.add(const Duration(days: 7)),
    ));
    cur = cur.add(const Duration(days: 7));
    guard++;
  }
  return tabs;
}

/// 日期所属的「标签月」(year, month)，与 month_range.labelForDate 对齐：
/// date.day >= startDay 归当月，否则归上月。
DateTime labelForMonth(DateTime date, [int startDay = 1]) {
  final d = startDay < 1 ? 1 : (startDay > 28 ? 28 : startDay);
  if (date.day >= d) return DateTime(date.year, date.month, 1);
  return DateTime(date.year, date.month - 1, 1);
}


