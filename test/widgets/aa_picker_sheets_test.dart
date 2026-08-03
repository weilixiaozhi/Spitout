/// AA 分摊选择组件 widget 测试。
///
/// 覆盖三个 sheet 的核心契约:
/// - showAaModePickerSheet:渲染人均/指定两个选项,点击返回对应 AaMode;
/// - showAaParticipantPickerSheet(多选):初值 null 时默认全选,完成返回
///   all=true(运行时展开);反选某成员后完成返回其余名单;lockedId 行
///   不可反选(支出人必是参与人);全选态完成仍返回 all=true;
/// - showAaPayerPickerSheet(单选):点击成员行即返回其标识。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/services/settlement/aa_edit_models.dart';
import 'package:spitout/services/settlement/aa_settlement_service.dart';
import 'package:spitout/widgets/aa_mode_picker_sheet.dart';
import 'package:spitout/widgets/aa_participant_picker_sheet.dart';

/// 测试用参与人桩数据:两个真实成员 + 一个虚拟用户。
const _options = [
  AaParticipantOption(id: 'u1', name: '张三', isVirtual: false),
  AaParticipantOption(id: 'u2', name: '李四', isVirtual: false),
  AaParticipantOption(id: 'vu_1', name: '小明', isVirtual: true),
];

/// 通用测试壳:提供 l10n 与一个触发按钮,点击后调用 [launch],
/// 结果存入 [result] 槽位供断言。
Widget _shell<V>({
  required Future<V> Function(BuildContext context) launch,
  required void Function(V value) onResult,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(await launch(context)),
          child: const Text('launch'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('launch'));
  await tester.pumpAndSettle();
}

void main() {
  group('showAaModePickerSheet(分摊方式单选)', () {
    testWidgets('渲染人均/指定两个选项', (tester) async {
      await tester.pumpWidget(_shell<AaMode?>(
        launch: (context) =>
            showAaModePickerSheet(context, selected: AaMode.perPerson),
        onResult: (_) {},
      ));
      await _open(tester);

      expect(find.text('人均分摊'), findsOneWidget);
      expect(find.text('指定分摊'), findsOneWidget);
    });

    testWidgets('点击「指定分摊」返回 AaMode.custom', (tester) async {
      AaMode? result;
      var returned = false;
      await tester.pumpWidget(_shell<AaMode?>(
        launch: (context) =>
            showAaModePickerSheet(context, selected: AaMode.perPerson),
        onResult: (v) {
          returned = true;
          result = v;
        },
      ));
      await _open(tester);

      await tester.tap(find.text('指定分摊'));
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(result, AaMode.custom);
    });
  });

  group('showAaParticipantPickerSheet(参与人多选)', () {
    testWidgets('初值 null 时默认全选,完成返回 all=true', (tester) async {
      AaParticipantSelection? result;
      await tester.pumpWidget(_shell<AaParticipantSelection?>(
        launch: (context) => showAaParticipantPickerSheet(
          context,
          options: _options,
          initialSelectedIds: null,
        ),
        onResult: (v) => result = v,
      ));
      await _open(tester);

      // 初值 null 展开为全部 options,所有行应显示勾选态。
      expect(find.byIcon(LucideIcons.check), findsNWidgets(3));

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.all, isTrue, reason: '初值 null = 全部成员,全选即落 null');
      expect(result!.ids, isEmpty);
    });

    testWidgets('反选某成员后完成,返回其余成员名单', (tester) async {
      AaParticipantSelection? result;
      await tester.pumpWidget(_shell<AaParticipantSelection?>(
        launch: (context) => showAaParticipantPickerSheet(
          context,
          options: _options,
          initialSelectedIds: null,
        ),
        onResult: (v) => result = v,
      ));
      await _open(tester);

      // 直接反选李四(全选起步),完成应返回除李四外的具体名单。
      await tester.tap(find.text('李四'));
      await tester.pump();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.all, isFalse);
      expect(result!.ids, containsAll(['u1', 'vu_1']));
      expect(result!.ids, isNot(contains('u2')));
    });

    testWidgets('指定初值回显并完成,返回初值名单', (tester) async {
      AaParticipantSelection? result;
      await tester.pumpWidget(_shell<AaParticipantSelection?>(
        launch: (context) => showAaParticipantPickerSheet(
          context,
          options: _options,
          initialSelectedIds: const ['u1'],
        ),
        onResult: (v) => result = v,
      ));
      await _open(tester);

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.all, isFalse);
      expect(result!.ids, ['u1']);
    });

    testWidgets('lockedId 行不可反选,完成时仍在选中集合内', (tester) async {
      AaParticipantSelection? result;
      await tester.pumpWidget(_shell<AaParticipantSelection?>(
        launch: (context) => showAaParticipantPickerSheet(
          context,
          options: _options,
          // 指定初值排除 u1,但 u1 是 lockedId,应被强制补入且不可反选。
          initialSelectedIds: const ['u2'],
          lockedId: 'u1',
        ),
        onResult: (v) => result = v,
      ));
      await _open(tester);

      // 尝试反选张三(lockedId),应无效,张三仍保持勾选。
      await tester.tap(find.text('张三'));
      await tester.pump();
      expect(find.byIcon(LucideIcons.check), findsNWidgets(2));

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.all, isFalse);
      expect(result!.ids, containsAll(['u1', 'u2']));
    });

    testWidgets('lockedId + 全选完成返回 all=true', (tester) async {
      AaParticipantSelection? result;
      await tester.pumpWidget(_shell<AaParticipantSelection?>(
        launch: (context) => showAaParticipantPickerSheet(
          context,
          options: _options,
          initialSelectedIds: null,
          lockedId: 'u1',
        ),
        onResult: (v) => result = v,
      ));
      await _open(tester);

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.all, isTrue, reason: '全选即落 null,运行时展开');
      expect(result!.ids, isEmpty);
    });
  });

  group('showAaPayerPickerSheet(支出人单选)', () {
    testWidgets('点击成员行即返回该成员标识', (tester) async {
      String? result;
      var returned = false;
      await tester.pumpWidget(_shell<String?>(
        launch: (context) =>
            showAaPayerPickerSheet(context, options: _options, selectedId: 'u1'),
        onResult: (v) {
          returned = true;
          result = v;
        },
      ));
      await _open(tester);

      await tester.tap(find.text('小明'));
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(result, 'vu_1');
    });
  });
}
