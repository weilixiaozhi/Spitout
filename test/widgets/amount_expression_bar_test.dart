/// AmountExpressionBar（记账编辑器金额栏）布局回归测试。
///
/// 本次需求（键盘布局重构）：金额栏是键盘容器 6 行中的 1 行，行高由父级
/// SizedBox 提供；币种框 / 金额区 / 删除键三个区块统一 stretch 填满整行；
/// 币种框/删除键为深灰块、金额区为白色块、圆角 5px、水平键距 2px。
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
  Widget buildHarness({double rowHeight = 80}) {
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
                txCurrency: 'CNY',
                ledgerBase: 'CNY',
                amountStr: '0',
                acc: 0,
                op: null,
                opGlyph: (o) => o,
                equalsTotal: 0,
                calcState: 'waiting',
                conversionPreview: null,
                rateFetching: false,
                rateMissing: false,
                rateMissingHint: '',
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

  testWidgets('币种/删除深灰块、金额区白色块、圆角 5px、键距 2px', (tester) async {
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
    expect(chipDeco.color, SpitoutColors.lightKeyOther);
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

    // 币种框 ↔ 金额区水平键距 2px
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('amount_area'))).dx -
          tester
              .getTopRight(find.byKey(const ValueKey('amount_currency_chip')))
              .dx,
      KeypadLayout.gap,
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
}
