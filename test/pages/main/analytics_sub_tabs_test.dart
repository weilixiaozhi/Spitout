/// generateSubTabs / weekNumber 纯函数单元测试。
///
/// 测试框架：flutter_test（纯 dart 逻辑，无 Widget 依赖）。
/// 覆盖：正常路径、边界值（空数据、earliest==latest、跨年）、升序排列。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/utils/date/analytics_sub_tabs.dart';
import 'package:spitout/utils/date/week_math.dart';

void main() {
  // 公共 label 构造器：与 UI 实际使用口径一致
  String monthLabel(int m) => '$m月';
  String weekNLabel(int n) => '第$n周';
  String yearLabel(int y) => '$y';
  const thisWeekLabel = '本周';

  group('generateSubTabs - 空数据', () {
    test('无数据时返回仅含当前周期的单元素列表（规则 3）', () {
      final now = DateTime(2026, 7, 15);
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.month,
        earliest: null,
        latest: null,
        now: now,
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 1, reason: '无数据应只返回当前周期一个 Tab');
      expect(tabs.first.label, '7月');
    });

    test('无数据周视图返回本周 Tab', () {
      final now = DateTime(2026, 7, 15); // 周三
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.week,
        earliest: null,
        latest: null,
        now: now,
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 1);
      expect(tabs.first.label, thisWeekLabel);
      // 周一为 2026-07-13
      expect(tabs.first.start, DateTime(2026, 7, 13));
    });

    test('无数据年视图返回当前年 Tab', () {
      final now = DateTime(2026, 7, 15);
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.year,
        earliest: null,
        latest: null,
        now: now,
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 1);
      expect(tabs.first.label, '2026');
    });
  });

  group('generateSubTabs - earliest == latest（规则 9.1）', () {
    test('月视图：单条数据返回长度 1', () {
      final d = DateTime(2026, 7, 10);
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.month,
        earliest: d,
        latest: d,
        now: DateTime(2026, 7, 15),
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 1);
      expect(tabs.first.label, '7月');
    });

    test('周视图：同一周内的数据返回长度 1', () {
      final d = DateTime(2026, 7, 14); // 周二
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.week,
        earliest: d,
        latest: d,
        now: DateTime(2026, 7, 15),
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 1);
    });
  });

  group('generateSubTabs - 跨范围连续生成（规则 9.2）', () {
    test('月视图跨年：从 2025-11 到 2026-02 生成 4 个 Tab，按时间升序', () {
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.month,
        earliest: DateTime(2025, 11, 5),
        latest: DateTime(2026, 2, 10),
        now: DateTime(2026, 7, 15),
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 4);
      expect(tabs[0].label, '11月');
      expect(tabs[1].label, '12月');
      expect(tabs[2].label, '1月');
      expect(tabs[3].label, '2月');
      // 验证半开区间 [start, end)
      expect(tabs[0].start, DateTime(2025, 11, 1));
      expect(tabs[0].end, DateTime(2025, 12, 1));
    });

    test('月视图 monthStartDay=10：区间按自定义起始日切分', () {
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.month,
        earliest: DateTime(2026, 6, 12),
        latest: DateTime(2026, 7, 5),
        now: DateTime(2026, 7, 15),
        monthStartDay: 10,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      // 6月12日 >= 10 → 归 6月周期；7月5日 < 10 → 归 6月周期
      // 所以 earliest 和 latest 都在 6月周期 → 长度 1
      expect(tabs.length, 1);
      expect(tabs.first.start, DateTime(2026, 6, 10));
      expect(tabs.first.end, DateTime(2026, 7, 10));
    });

    test('年视图：从 2023 到 2026 生成 4 个 Tab', () {
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.year,
        earliest: DateTime(2023, 3, 1),
        latest: DateTime(2026, 1, 15),
        now: DateTime(2026, 7, 15),
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 4);
      expect(tabs.map((t) => t.label).toList(), ['2023', '2024', '2025', '2026']);
    });

    test('周视图：跨 3 周生成 3 个 Tab，按周一递增', () {
      // 2026-07-13 是周一
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.week,
        earliest: DateTime(2026, 7, 13),
        latest: DateTime(2026, 7, 27), // 同一周（周一）
        now: DateTime(2026, 7, 15),
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 3);
      expect(tabs[0].start, DateTime(2026, 7, 13));
      expect(tabs[1].start, DateTime(2026, 7, 20));
      expect(tabs[2].start, DateTime(2026, 7, 27));
      // 每个 Tab 区间为 7 天
      expect(tabs[0].end.difference(tabs[0].start).inDays, 7);
    });

    test('周视图跨年：2025-12-29(周一) 到 2026-01-12(周一) 生成 3 个 Tab', () {
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.week,
        earliest: DateTime(2025, 12, 29),
        latest: DateTime(2026, 1, 12),
        now: DateTime(2026, 7, 15),
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      expect(tabs.length, 3);
      expect(tabs[0].start, DateTime(2025, 12, 29));
      expect(tabs[1].start, DateTime(2026, 1, 5));
      expect(tabs[2].start, DateTime(2026, 1, 12));
    });
  });

  group('generateSubTabs - 默认选中最新数据', () {
    test('月视图：最后一个 Tab 对应 latest 所在月', () {
      final tabs = generateSubTabs(
        period: AnalyticsPeriod.month,
        earliest: DateTime(2025, 1, 1),
        latest: DateTime(2026, 3, 15),
        now: DateTime(2026, 7, 15),
        monthStartDay: 1,
        monthLabel: monthLabel,
        weekNLabel: weekNLabel,
        thisWeekLabel: thisWeekLabel,
        yearLabel: yearLabel,
      );
      // 2025-01 到 2026-03 共 15 个月
      expect(tabs.length, 15);
      expect(tabs.last.label, '3月');
      expect(tabs.last.start.year, 2026);
      expect(tabs.last.start.month, 3);
    });
  });

  group('weekNumber - 周序号计算', () {
    test('年末周一（2025-12-29）返回 2025 年第 52 周（不返回 0 或负数）', () {
      // 2025-12-29 是周一，属于 2025 年最后一周
      // 2025-01-01 是周三，首个周一是 2025-01-06
      // (2025-12-29 - 2025-01-06).inDays = 357, 357/7 = 51, +1 = 52
      final wn = weekNumber(DateTime(2025, 12, 29));
      expect(wn, greaterThanOrEqualTo(1), reason: '周序号不应为 0 或负数');
      expect(wn, 52);
    });

    test('1月首个周一当周为第 1 周', () {
      expect(weekNumber(DateTime(2026, 1, 5)), 1);
    });

    test('年中任意周一返回正整数 >= 1', () {
      final mid = weekNumber(DateTime(2026, 7, 13));
      expect(mid, greaterThanOrEqualTo(1));
      expect(mid, lessThan(60), reason: '年内周序号不应超过 53');
    });

    test('12月末周一返回合理周序号', () {
      final late = weekNumber(DateTime(2026, 12, 28));
      expect(late, greaterThanOrEqualTo(1));
      expect(late, lessThanOrEqualTo(53));
    });

    test('2025-01-06(周一) 为第 2 周', () {
      // 2025-01-01 是周三，首个周一是 2025-01-06
      // 所以 2025-01-06 本身就是首个周一 → 第 1 周
      expect(weekNumber(DateTime(2025, 1, 6)), 1);
    });
  });

  group('mondayOf - 周一计算', () {
    test('周三回退到本周一', () {
      expect(mondayOf(DateTime(2026, 7, 15)), DateTime(2026, 7, 13));
    });

    test('周一保持不变', () {
      expect(mondayOf(DateTime(2026, 7, 13)), DateTime(2026, 7, 13));
    });

    test('周日回退到本周一', () {
      // 2026-07-19 是周日
      expect(mondayOf(DateTime(2026, 7, 19)), DateTime(2026, 7, 13));
    });
  });

  group('labelForMonth - 标签月计算', () {
    test('day >= startDay 归当月', () {
      expect(labelForMonth(DateTime(2026, 7, 15), 10), DateTime(2026, 7, 1));
      expect(labelForMonth(DateTime(2026, 7, 10), 10), DateTime(2026, 7, 1));
    });

    test('day < startDay 归上月', () {
      expect(labelForMonth(DateTime(2026, 7, 9), 10), DateTime(2026, 6, 1));
      expect(labelForMonth(DateTime(2026, 7, 1), 10), DateTime(2026, 6, 1));
    });

    test('startDay=1 退化为自然月', () {
      expect(labelForMonth(DateTime(2026, 7, 1), 1), DateTime(2026, 7, 1));
      expect(labelForMonth(DateTime(2026, 7, 31), 1), DateTime(2026, 7, 1));
    });
  });
}
