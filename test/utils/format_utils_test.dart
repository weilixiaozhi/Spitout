// format_utils 展示文案工具测试。
//
// 需求锚点：
//   1. translateLedgerName 把「默认账本」的多语言历史名称统一翻译为当前语言；
//   2. monthLabel：英文 JAN..DEC 缩写，中文/韩文补零月份；
//   3. monthYearLabel 拼接「月份 · 年份」。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/utils/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BuildContext> pumpHost(WidgetTester tester, String locale) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(locale),
        home: const SizedBox(),
      ),
    );
    return tester.element(find.byType(SizedBox));
  }

  testWidgets('translateLedgerName 翻译默认账本历史名称', (tester) async {
    final context = await pumpHost(tester, 'zh');
    expect(translateLedgerName(context, 'Default Ledger'), '默认账本');
    expect(translateLedgerName(context, '自定义账本'), '自定义账本');
  });

  testWidgets('monthLabel：英文缩写 / 中文补零', (tester) async {
    final en = await pumpHost(tester, 'en');
    expect(monthLabel(en, 7), 'JUL');
    expect(monthLabel(en, 1), 'JAN');

    final zh = await pumpHost(tester, 'zh');
    expect(monthLabel(zh, 7), '07月');
  });

  testWidgets('monthYearLabel 拼接月份与年份', (tester) async {
    final zh = await pumpHost(tester, 'zh');
    expect(monthYearLabel(zh, 7, 2026), contains('07月'));
    expect(monthYearLabel(zh, 7, 2026), contains('2026'));
  });
}
