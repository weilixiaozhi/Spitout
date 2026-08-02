/// 周日期纯函数工具集（仅依赖 dart:core，不触碰任何业务层）。
///
/// 设计意图：这些函数统一描述「以周一为一周起点」的周序号 / 周一换算规则，
/// 被统计页子 Tab 生成（utils/date/analytics_sub_tabs.dart）与周选择器
/// （widgets/wheel_date_picker.dart）共享，widgets 只需向下依赖 utils。
library;

/// 取某日期所在周的周一（00:00）。周起点统一为周一。
DateTime mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// 计算某周一所在的「年内周序号」（1-based）。
///
/// 以「年内首个周一」为第 1 周起点，避免年初非周一时算出第 0 周或负数。
int weekNumber(DateTime monday) {
  final y = monday.year;
  // 找当年首个周一：1月1日往前找到第一个 weekday==1 的日期
  DateTime firstDay = DateTime(y, 1, 1);
  // 1月1日的 weekday: 1=周一..7=周日
  // 首个周一 = 1月1日 + (8 - weekday) % 7 天（如果1月1日是周一则为0天）
  final offset = (8 - firstDay.weekday) % 7;
  final firstMonday = firstDay.add(Duration(days: offset));
  if (!monday.isBefore(firstMonday)) {
    return (monday.difference(firstMonday).inDays ~/ 7) + 1;
  }
  // 周一在首个周一之前（1月初），归到上一年最后一周或本年第1周
  // 为避免负数，统一返回 1（属于本年第一周区间）
  return 1;
}

/// 某年按「年内首个周一为第 1 周」口径的总周数（52 或 53）。
/// 供周选择器滚轮确定当年可选项数量。
int weeksInYear(int year) {
  return weekNumber(mondayOf(DateTime(year, 12, 31)));
}

/// [weekNumber] 的逆运算：返回 [year] 年第 [weekN] 周的周一。
/// 供周选择器把「年 + 周序号」还原为具体账期起点。
/// 注意：weekN=1 对应该年首个周一（与 weekNumber 主口径一致）。
DateTime mondayOfWeek(int year, int weekN) {
  final firstDay = DateTime(year, 1, 1);
  final offset = (8 - firstDay.weekday) % 7;
  final firstMonday = firstDay.add(Duration(days: offset));
  return firstMonday.add(Duration(days: (weekN - 1) * 7));
}
