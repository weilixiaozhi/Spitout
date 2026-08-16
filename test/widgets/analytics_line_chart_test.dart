/// AnalyticsLineChart 数值单位契约回归测试。
///
/// 锁定：values 的单位是「元」（展示口径），数值标注按元展示，
/// 最多两位小数并去掉末尾多余的 0（与首页金额口径一致）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/line_chart.dart';

void main() {
  test('数值标注按「元」展示，最多两位小数、去尾零：12.5→12.5、12.51→12.51、1250→1.25k', () {
    expect(formatChartValueLabel(12.5), '12.5',
        reason: 'values 单位=元，一位小数足够时不必补 0');
    expect(formatChartValueLabel(12.51), '12.51',
        reason: '两位小数按需保留');
    expect(formatChartValueLabel(1250), '1.25k',
        reason: '若误传整数分，展示会变成 k 级数字，属单位契约破坏');
    expect(formatChartValueLabel(2400), '2.4k',
        reason: 'k 缩写同样去尾零');
    expect(formatChartValueLabel(12500), '1.25w',
        reason: 'w 缩写保留两位小数并去尾零');
  });
}
