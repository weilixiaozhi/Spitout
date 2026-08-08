// 周起始/周序号纯函数测试。
//
// 需求锚点：
//   1. mondayOf 返回所在周周一（00:00）；
//   2. weekNumber 以「年内首个周一」为第 1 周，年初周一前统一归 1；
//   3. weeksInYear 52/53 口径与 weekNumber 一致；
//   4. mondayOfWeek 是 weekNumber 的逆运算。

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/utils/date/week_math.dart';

void main() {
  test('mondayOf：周内任意一天归到周一', () {
    expect(mondayOf(DateTime(2026, 8, 6)), DateTime(2026, 8, 3)); // 周四
    expect(mondayOf(DateTime(2026, 8, 3)), DateTime(2026, 8, 3)); // 周一本身
    expect(mondayOf(DateTime(2026, 8, 9)), DateTime(2026, 8, 3)); // 周日
  });

  test('weekNumber：年内首个周一为第 1 周', () {
    // 2026-01-01 是周四 → 首个周一为 01-05
    expect(weekNumber(DateTime(2026, 1, 5)), 1);
    expect(weekNumber(DateTime(2026, 1, 12)), 2);
    // 年初早于首个周一（01-01..01-04）归 1，避免 0/负数
    expect(weekNumber(DateTime(2026, 1, 1)), 1);
  });

  test('weeksInYear 与 weekNumber 一致', () {
    final weeks = weeksInYear(2026);
    expect(weeks, weekNumber(mondayOf(DateTime(2026, 12, 31))));
    expect(weeks, 52);
  });

  test('mondayOfWeek 是 weekNumber 的逆运算', () {
    final monday = mondayOfWeek(2026, 2);
    expect(monday, DateTime(2026, 1, 12));
    expect(weekNumber(monday), 2);
  });
}
