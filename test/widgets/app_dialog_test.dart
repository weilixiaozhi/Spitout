/// AppDialog 消息渲染测试。
///
/// 消息按原文展示，不做 replaceAll('\\n', '\n') 替换——
/// 避免文案中字面量的反斜杠 n（如路径 / 用户数据）被误改成换行。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/widgets/app_dialog.dart';

void main() {
  testWidgets('消息中的字面量反斜杠 n 保持原文，不被改写为换行', (tester) async {
    const literalBackslashN = r'C:\tmp\note';

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
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                AppDialog.info<int>(
                  context,
                  title: '标题',
                  message: literalBackslashN,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text(literalBackslashN),
      findsOneWidget,
      reason: '字面量 \\n 必须原样展示，不能被替换成真实换行',
    );
  });
}
