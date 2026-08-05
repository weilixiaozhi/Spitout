/// WheelPicker 初始值不在列表中的回归测试。
///
/// 修复点：initial 不在 items 时，内部 selected 修正为列表首项，
/// 「确定」不再返回列表外的值。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/widgets/wheel_picker.dart';

void main() {
  testWidgets('initial 不在 items 中时，确定返回列表首项', (tester) async {
    int? result;

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
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showWheelPicker<int>(
                    context,
                    initial: 99,
                    items: const [1, 2, 3],
                    labelBuilder: (v) => '$v',
                    title: '选择频率',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('选择频率'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, 1,
        reason: 'initial=99 不在列表时，确定必须返回列表首项而非列表外的 99');
  });
}
