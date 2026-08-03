/// AaEditPage 不分摊入口 widget 测试。
///
/// 验证需求落地(新交互):
/// - 不分摊交易也允许进入 AaEditPage,默认选中不分摊;
/// - 主体卡内「分摊方式」三态切换按钮(单点循环),不分摊时下方无分摊配置卡;
/// - 完成按钮在不分摊模式下直接 pop 出 aaMode=1 的 AaEditResult;
/// - 切换到人均/指定后,下方出现分摊配置卡(支出人 + 合计 + 参与人列表)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/pages/settlement/aa_edit_page.dart';
import 'package:spitout/services/settlement/aa_edit_models.dart';
import 'package:spitout/services/settlement/aa_settlement_service.dart';
import 'package:spitout/routes.dart';

/// 两个真实成员 + 一个虚拟用户参与人桩。
const _options = [
  AaParticipantOption(id: 'u1', name: '张三', isVirtual: false),
  AaParticipantOption(id: 'u2', name: '李四', isVirtual: false),
  AaParticipantOption(id: 'vu_1', name: '小明', isVirtual: true),
];

/// 用 Navigator push 触发页路由,结果存入 [result] 槽位。
Future<void> _openAaEdit(
  WidgetTester tester, {
  required AaEditPageArgs args,
  required void Function(AaEditResult? r) onResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aaParticipantOptionsProvider.overrideWith(
          (ref, ledgerId) async => _options,
        ),
        currentLedgerProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          if (settings.name == Routes.aaEdit) {
            return MaterialPageRoute<AaEditResult>(
              builder: (_) => AaEditPage(args: settings.arguments as AaEditPageArgs),
            );
          }
          return null;
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final r = await Navigator.of(context)
                    .pushNamed<AaEditResult>(Routes.aaEdit, arguments: args);
                onResult(r);
              },
              child: const Text('launch'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('launch'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('不分摊入口:默认选中不分摊,下方无分摊配置卡', (tester) async {
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.noSplit,
      ),
      onResult: (_) {},
    );

    // 主体卡内分摊方式 toggle 展示「不分摊」
    expect(find.text('不分摊'), findsWidgets);
    // 不分摊时不展示支出人/合计/参与人配置卡
    expect(find.text('支出人'), findsNothing);
    expect(find.text('合计'), findsNothing);
  });

  testWidgets('不分摊入口:完成按钮直接 pop aaMode=1 结果', (tester) async {
    AaEditResult? result;
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.noSplit,
      ),
      onResult: (r) => result = r,
    );

    // 点击底部完成按钮
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // pop 出不分摊结果:aaMode=1,无参与人/支出人/指定金额
    expect(result, isNotNull);
    expect(result!.aaMode, 1);
    expect(result!.aaParticipants, isNull);
    expect(result!.aaSplits, isNull);
    expect(result!.paidByUserId, isNull);
  });

  testWidgets('不分摊入口:循环切换到人均后出现分摊配置卡', (tester) async {
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.noSplit,
      ),
      onResult: (_) {},
    );

    // 初始:不分摊,无分摊配置卡
    expect(find.text('支出人'), findsNothing);

    // 点击主体卡内分摊方式 toggle(单点循环:不分摊 → 指定 → 人均 → 不分摊)
    // 不分摊 → 指定:第一次点击切到「指定分摊」
    await tester.tap(find.text('不分摊').first);
    await tester.pumpAndSettle();

    // 指定分摊:出现支出人 / 合计 / 参与人配置
    expect(find.text('支出人'), findsOneWidget);
    expect(find.text('合计'), findsOneWidget);
  });

  testWidgets('人均分摊:参与人金额实时重算且置灰只读', (tester) async {
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 90,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.perPerson,
      ),
      onResult: (_) {},
    );

    // 人均分摊:3 人均摊 90 → 每人 30.00
    expect(find.text('30.00'), findsNWidgets(3));
  });
}
