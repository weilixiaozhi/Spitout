/// WheelDatePicker 边界测试。
///
/// - 入口校验 minDate ≤ maxDate，避免年份列表为空时 CupertinoPicker 崩溃；
/// - datetime 模式时/分列按边界日逐列钳制，不整体改值。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/widgets/wheel_date_picker.dart';

void main() {
  testWidgets('minDate 晚于 maxDate 时入口直接抛 ArgumentError', (tester) async {
    BuildContext? ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      () => showWheelDatePicker(
        ctx!,
        initial: DateTime(2026, 8, 5),
        minDate: DateTime(2026, 8, 10),
        maxDate: DateTime(2026, 8, 1),
      ),
      throwsArgumentError,
    );
  });

  test('datetime 模式小时列按边界日钳制', () {
    final date = DateTime(2026, 8, 5);
    final min = DateTime(2026, 8, 5, 9, 0);
    final max = DateTime(2026, 8, 5, 18, 30);

    final hours = hourRangeForDateTime(date: date, min: min, max: max);

    expect(hours.first, 9, reason: '边界日（min=09:00）小时列应从 09 开始，08 不可选');
    expect(hours.contains(8), isFalse);
    expect(hours.last, 18, reason: '边界日（max=18:30）小时列应到 18 结束');
    expect(hours.contains(19), isFalse);
  });

  test('datetime 模式分钟列在边界小时被钳制', () {
    final date = DateTime(2026, 8, 5);
    final min = DateTime(2026, 8, 5, 9, 0);
    final max = DateTime(2026, 8, 5, 18, 30);

    // 非边界小时：0-59 全量
    final freeMinutes = minuteRangeForDateTime(
      date: date,
      hour: 12,
      min: min,
      max: max,
    );
    expect(freeMinutes, hasLength(60));

    // 边界小时 18：到 30 结束
    final maxMinutes = minuteRangeForDateTime(
      date: date,
      hour: 18,
      min: min,
      max: max,
    );
    expect(maxMinutes.last, 30);
    expect(maxMinutes.contains(31), isFalse);
  });
}
