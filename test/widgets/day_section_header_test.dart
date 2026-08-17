/// 日期分组头组件字体规范测试。
///
/// 锁定日期/星期/日支出汇总金额均走 caption(10px)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/widgets/day_section_header.dart';

void main() {
  testWidgets('日期/星期/日汇总金额均 10px caption', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(
          body: DaySectionHeader(dateText: '2026-01-01', expense: 123.45),
        ),
      ),
    );

    final dateStyle = tester.widget<Text>(find.text('2026-01-01')).style;
    expect(dateStyle?.fontSize, 10, reason: '日期应为 10px caption');
    final weekStyle = tester.widget<Text>(find.text('星期四')).style;
    expect(weekStyle?.fontSize, 10, reason: '星期应为 10px caption');
    final amountStyle =
        tester.widget<Text>(find.textContaining('123.45')).style;
    expect(amountStyle?.fontSize, 10, reason: '日汇总金额应为 10px caption');
  });
}
