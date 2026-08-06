/// AmountExpressionBar（记账编辑器金额栏）尺寸回归测试。
///
/// 本次需求：金额栏整行高度 35，币种框 / 金额区 / 删除键三个区块统一 35，
/// 保证底部输入区紧凑、把空间留给键盘。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/widgets/amount_expression_bar.dart';

void main() {
  Widget buildHarness() {
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
        // 用可滚动容器解除纵向 tight 约束：金额栏内部 Column 按内容收缩，
        // 与记账 sheet 内 mainAxisSize.min 的实际环境一致。
        home: Scaffold(
          body: SingleChildScrollView(
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
    );
  }

  testWidgets('金额栏整行高度 35，币种/金额/删除三区块统一 35', (tester) async {
    await tester.pumpWidget(buildHarness());

    expect(tester.getSize(find.byType(AmountExpressionBar)).height, 35,
        reason: '金额栏整行高度应为 35');
    expect(
      tester
          .getSize(find.byKey(const ValueKey('amount_currency_chip')))
          .height,
      35,
      reason: '币种框高度应为 35',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('amount_area'))).height,
      35,
      reason: '金额显示区高度应为 35',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('amount_delete_key'))).height,
      35,
      reason: '删除键高度应为 35',
    );
  });

  testWidgets('币种触发器走全局展示格式：ISO + (符号)，如 CNY (¥)', (tester) async {
    await tester.pumpWidget(buildHarness());

    // 与 currency_flag.dart 的 currencyFlagLabel 全局口径一致：
    // 「ISO + 空格 + 半角括号包裹的币种符号」，避免各页面币种写法不统一。
    expect(find.text('CNY (¥)'), findsOneWidget,
        reason: '币种触发器应展示全局统一的「ISO + (符号)」格式');
  });
}
