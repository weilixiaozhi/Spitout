/// NoteInputRow 清空按钮显隐回归测试。
///
/// 修复点：清空按钮改为 ValueListenableBuilder 监听 controller 自身，
/// 输入内容变化后按钮即时出现 / 消失，不依赖父层重建。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/note_input_row.dart';

void main() {
  /// 构建备注输入行测试宿主。
  Widget buildRow(TextEditingController controller, ValueChanged<String> onPicked) {
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
        home: Scaffold(
          body: NoteInputRow(
            noteController: controller,
            noteFocusNode: FocusNode(),
            onNotePicked: onPicked,
          ),
        ),
      ),
    );
  }

  testWidgets('输入内容变化后清空按钮即时显隐（不依赖父层重建）', (tester) async {
    final controller = TextEditingController();
    final picked = <String>[];

    await tester.pumpWidget(buildRow(controller, picked.add));

    expect(find.byIcon(AppIcons.cancel), findsNothing);

    // 直接改 controller（模拟外部回填 / 输入法写入），父组件不重建
    controller.text = '午餐';
    await tester.pump();
    expect(find.byIcon(AppIcons.cancel), findsOneWidget,
        reason: '输入非空后清空按钮应立即出现');

    await tester.tap(find.byIcon(AppIcons.cancel));
    expect(picked, ['']);

    controller.clear();
    await tester.pump();
    expect(find.byIcon(AppIcons.cancel), findsNothing,
        reason: '清空后按钮应立即消失');

    controller.dispose();
  });

  testWidgets('备注输入行高度固定 35（需求 30-35 取上限）', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(buildRow(controller, (_) {}));

    final height = tester.getSize(find.byType(NoteInputRow)).height;
    expect(height, closeTo(35, 0.5),
        reason: '备注行应压缩到 35px，避免挤占下方金额栏与键盘');

    controller.dispose();
  });
}
