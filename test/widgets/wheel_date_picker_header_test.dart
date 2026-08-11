/// 日期选择 sheet 头部与汇率选择 sheet 头部一致性回归测试。
///
/// 需求锚点：记账编辑器日期选择 sheet 的头部（圆角 + 拖拽条，无顶部描边）
/// 应与汇率选择 sheet（currency_picker_sheet.dart）完全一致，
/// 保证两处弹层头部视觉与代码逻辑统一。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/widgets/wheel_date_picker.dart';

void main() {
  Future<void> pumpDateSheet(WidgetTester tester) async {
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
        home: Scaffold(
          body: WheelDatePicker(
            initial: DateTime(2026, 8, 8, 9, 30),
            mode: WheelDatePickerMode.datetime,
            title: '选择时间',
            subtitle: '选择时间提示',
            confirmLabel: '完成',
          ),
        ),
      ),
    );
  }

  testWidgets('日期选择 sheet 顶部无描边、圆角 16px', (tester) async {
    await pumpDateSheet(tester);
    final ctx = tester.element(find.byType(WheelDatePicker));

    // 定位 sheet 外层圆角容器：surfaceSheet 背景 + 顶部 16px 圆角
    final sheet = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color ==
                SpitoutTokens.surfaceSheet(ctx) &&
            (w.decoration! as BoxDecoration).borderRadius ==
                const BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
    final deco = sheet.decoration! as BoxDecoration;

    expect(
      deco.border,
      isNull,
      reason: '顶部不应有描边，统一只保留 36x4 拖拽条',
    );
  });

  testWidgets('日期选择 sheet 拖拽条与汇率选择 sheet 一致：36x4、上 8 下 4、主题 token 自适应色', (tester) async {
    await pumpDateSheet(tester);
    final ctx = tester.element(find.byType(WheelDatePicker));

    final handle = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints == const BoxConstraints.tightFor(width: 36, height: 4),
      ),
    );
    expect(handle, isNotNull, reason: '头部应渲染 36x4 拖拽条');

    // 拖拽条外层统一间距（上 8 / 下 4），由共享组件 SheetGrabHandle 提供。
    final wrapper = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byWidget(handle),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(
      wrapper.padding,
      const EdgeInsets.only(top: 8, bottom: 4),
      reason: '拖拽条间距应与汇率选择 sheet 一致',
    );

    final deco = handle.decoration! as BoxDecoration;
    expect(
      deco.color,
      SpitoutTokens.grabHandleColor(ctx),
      reason: '拖拽条颜色应统一走 SpitoutTokens.grabHandleColor，不硬编码',
    );
    expect(
      deco.borderRadius,
      BorderRadius.circular(2),
      reason: '拖拽条圆角应与汇率选择 sheet 一致',
    );
  });
}
