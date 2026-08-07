/// AmountExpressionBar（记账编辑器金额栏）布局回归测试。
///
/// 金额栏是键盘容器 6 行中的 1 行，行高由父级 SizedBox 提供；
/// 币种框 / 金额区 / 删除键三个区块统一 stretch 填满整行；
/// 币种框/金额区为白色块、删除键为深灰块、圆角 5px、水平键距 4px。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/widgets/amount_expression_bar.dart';
import 'package:spitout/widgets/keypad_constants.dart';
import 'package:spitout/widgets/press_key.dart';

void main() {
  Widget buildHarness({
    double rowHeight = 80,
    String txCurrency = 'CNY',
    String ledgerBase = 'CNY',
    String amountStr = '0',
    String calcState = 'waiting',
    double acc = 0,
    String? op,
    double equalsTotal = 0,
    String? conversionPreview,
    bool rateFetching = false,
    bool rateMissing = false,
    String rateMissingHint = '',
  }) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        // 与记账 sheet 一致：父级键盘容器以固定行高 SizedBox 提供约束
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: rowHeight,
              child: AmountExpressionBar(
                txCurrency: txCurrency,
                ledgerBase: ledgerBase,
                amountStr: amountStr,
                acc: acc,
                op: op,
                opGlyph: (o) => o,
                equalsTotal: equalsTotal,
                calcState: calcState,
                conversionPreview: conversionPreview,
                rateFetching: rateFetching,
                rateMissing: rateMissing,
                rateMissingHint: rateMissingHint,
                onPickCurrency: () {},
                onEditRate: () {},
                onClearAmount: () {},
                onDeleteOne: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('金额栏整行等高：币种/金额/删除三区块统一填满父级行高', (tester) async {
    await tester.pumpWidget(buildHarness(rowHeight: 80));

    expect(
      tester.getSize(find.byType(AmountExpressionBar)).height,
      80,
      reason: '金额栏整行高度应等于父级行高',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('amount_currency_chip'))).height,
      80,
      reason: '币种框高度应等于行高',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('amount_area'))).height,
      80,
      reason: '金额显示区高度应等于行高',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('amount_delete_key'))).height,
      80,
      reason: '删除键高度应等于行高',
    );
  });

  testWidgets('币种/金额区/删除块配色：币种白、金额白、删除深灰、圆角 5px、键距 4px', (tester) async {
    await tester.pumpWidget(buildHarness(rowHeight: 80));

    // 币种框与金额区背景色
    final chip = tester.widget<Container>(
      find.byKey(const ValueKey('amount_currency_chip')),
    );
    final area = tester.widget<Container>(
      find.byKey(const ValueKey('amount_area')),
    );
    final chipDeco = chip.decoration! as BoxDecoration;
    final areaDeco = area.decoration! as BoxDecoration;
    expect(chipDeco.color, SpitoutColors.lightKeyDigit);
    expect(areaDeco.color, SpitoutColors.lightKeyDigit);
    expect(
      chipDeco.borderRadius,
      BorderRadius.circular(KeypadLayout.keyRadius),
    );
    expect(
      areaDeco.borderRadius,
      BorderRadius.circular(KeypadLayout.keyRadius),
    );

    // 删除键背景与圆角
    final deleteKey = find.ancestor(
      of: find.byKey(const ValueKey('amount_delete_key')),
      matching: find.byType(PressKey),
    );
    final delete = tester.widget<PressKey>(deleteKey);
    expect(delete.backgroundColor, SpitoutColors.lightKeyOther);
    expect(delete.borderRadius, BorderRadius.circular(KeypadLayout.keyRadius));

    // 币种框 ↔ 金额区水平键距 4px
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('amount_area'))).dx -
          tester
              .getTopRight(find.byKey(const ValueKey('amount_currency_chip')))
              .dx,
      KeypadLayout.gap,
    );
  });

  testWidgets('外币折算预览：金额区第二行，正常行高下可见', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        rowHeight: 80,
        txCurrency: 'USD',
        ledgerBase: 'CNY',
        conversionPreview: '≈ 86.40 CNY',
      ),
    );

    final preview = find.descendant(
      of: find.byKey(const ValueKey('amount_area')),
      matching: find.text('≈ 86.40 CNY'),
    );
    expect(preview, findsOneWidget, reason: '折算预览应显示在金额区内第二行');
  });

  testWidgets('外币折算预览：短屏行高 25 也始终显示（不隐藏）', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        rowHeight: 25,
        txCurrency: 'USD',
        ledgerBase: 'CNY',
        conversionPreview: '≈ 86.40 CNY',
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('amount_area')),
        matching: find.text('≈ 86.40 CNY'),
      ),
      findsOneWidget,
      reason: '短屏行高变小时预览应保留（字号收缩，不隐藏）',
    );
  });

  testWidgets('外币折算预览：计算中（operating）也显示', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        rowHeight: 80,
        txCurrency: 'USD',
        ledgerBase: 'CNY',
        amountStr: '20',
        calcState: 'operating',
        acc: 10,
        op: '+',
        equalsTotal: 30,
        conversionPreview: '≈ 86.40 CNY',
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('amount_area')),
        matching: find.text('≈ 86.40 CNY'),
      ),
      findsOneWidget,
      reason: '按运算符进入计算中后折算预览不应消失',
    );
  });

  testWidgets('币种触发器走全局展示格式：ISO + (符号)，如 CNY (¥)', (tester) async {
    await tester.pumpWidget(buildHarness(rowHeight: 80));

    // 与 currency_flag.dart 的 currencyFlagLabel 全局口径一致：
    // 「ISO + 空格 + 半角括号包裹的币种符号」，避免各页面币种写法不统一。
    expect(
      find.text('CNY (¥)'),
      findsOneWidget,
      reason: '币种触发器应展示全局统一的「ISO + (符号)」格式',
    );
  });

  testWidgets('币种字体大小从行高 h 派生（与数字键统一）', (tester) async {
    await tester.pumpWidget(buildHarness(rowHeight: 40));
    final small = tester.widget<Text>(find.text('CNY (¥)')).style!.fontSize;

    await tester.pumpWidget(buildHarness(rowHeight: 80));
    final large = tester.widget<Text>(find.text('CNY (¥)')).style!.fontSize;

    expect(small, closeTo((40 * 0.36).clamp(12.0, 20.0), 0.01));
    expect(large, closeTo((80 * 0.36).clamp(12.0, 20.0), 0.01));
    expect(large, greaterThan(small!), reason: '行高变大时币种字体应同步变大');
  });

  testWidgets('金额超宽时自动滚动到末尾：reverse 视图应停在 offset 0', (tester) async {
    await tester.pumpWidget(buildHarness(rowHeight: 80, amountStr: '0'));
    final scrollable = find.descendant(
      of: find.byType(AmountExpressionBar),
      matching: find.byType(Scrollable),
    );

    const long = '123456789012345678901234567890';
    await tester.pumpWidget(buildHarness(rowHeight: 80, amountStr: long));
    await tester.pump(); // 执行 post-frame 的滚动到末尾

    final pos = tester.state<ScrollableState>(scrollable.first).position;
    expect(pos.maxScrollExtent, greaterThan(0), reason: '金额应超出可视区');
    expect(
      pos.pixels,
      0,
      reason: 'reverse 横向滚动视图 offset 0 才是内容末端（最新输入），'
          '跳到 maxScrollExtent 会滚回开头',
    );
  });

  testWidgets('operating 算式超宽时滚动到 = 预览（reverse 视图 offset 0）', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness(rowHeight: 80, amountStr: '0'));
    final scrollable = find.descendant(
      of: find.byType(AmountExpressionBar),
      matching: find.byType(Scrollable),
    );

    await tester.pumpWidget(
      buildHarness(
        rowHeight: 80,
        amountStr: '11111111111111111111',
        calcState: 'operating',
        acc: 999999,
        op: '+',
        equalsTotal: 1e19,
      ),
    );
    await tester.pump(); // 执行 post-frame 的滚动到末尾

    final pos = tester.state<ScrollableState>(scrollable.first).position;
    expect(pos.maxScrollExtent, greaterThan(0), reason: '算式应超出可视区');
    expect(
      pos.pixels,
      0,
      reason: 'operating 模式应把 `= 预览` 滚到可见，而不是停在累加值/运算符',
    );
  });
}
