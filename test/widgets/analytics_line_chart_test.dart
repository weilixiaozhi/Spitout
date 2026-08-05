/// AnalyticsLineChart 数值单位契约回归测试。
///
/// 锁定：values 的单位是「元」（展示口径），数值标注按元取整展示。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/line_chart.dart';

void main() {
  test('数值标注按「元」取整：12.5 显示 13，而非整数分口径的 1250', () {
    expect(formatChartValueLabel(12.5), '13',
        reason: 'values 单位=元，标注按元取整展示');
    expect(formatChartValueLabel(1250), '1.3k',
        reason: '若误传整数分，展示会变成 k 级数字，属单位契约破坏');
  });
}
