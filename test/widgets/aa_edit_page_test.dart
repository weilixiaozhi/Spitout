/// AaEditPage 不分摊入口 widget 测试。
///
/// 验证需求落地(新交互):
/// - 不分摊交易也允许进入 AaEditPage,默认选中不分摊;
/// - 主体卡内「分摊方式」三态切换按钮(单点循环),不分摊时下方无分摊配置卡;
/// - 完成按钮在不分摊模式下直接 pop 出 aaMode=1 的 AaEditResult;
/// - 切换到人均/指定后,下方出现分摊配置卡(支出人 + 参与人标题 + 参与人列表)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/core/identity/local_user_identity.dart';
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
///
/// [localSelfId] 用于桩操作者身份:默认不传时走真实 UUID(不在名册,
/// 未手选不触发默认支出人填充);传名册内 id 时验证「我」锁定逻辑。
Future<void> _openAaEdit(
  WidgetTester tester, {
  required AaEditPageArgs args,
  required void Function(AaEditResult? r) onResult,
  String displayName = '',
  String? localSelfId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aaParticipantOptionsProvider.overrideWith(
          (ref, ledgerId) async => _options,
        ),
        currentLedgerProvider.overrideWith((ref) => Stream.value(null)),
        displayNameProvider.overrideWith((ref) => displayName),
        // 云实例桩为 null:未手选时默认支出人解析走 localSelfId 兜底。
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
        if (localSelfId != null)
          localSelfIdProvider.overrideWith((ref) async => localSelfId),
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
    // 不分摊时不展示支出人/参与人配置卡
    expect(find.text('支出人'), findsNothing);
    expect(find.text('参与人'), findsNothing);
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

    // 指定分摊:出现支出人 / 参与人配置(合计行文案已改「参与人」)
    expect(find.text('支出人'), findsOneWidget);
    expect(find.text('参与人'), findsOneWidget);
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

    // 人均分摊:3 人均摊 90 → 每人 ¥ 30
    expect(find.text('¥ 30'), findsNWidgets(3));
  });

  testWidgets('支出人:新建未手选,回传 paidByUserId=null(落库层回填创建人)', (tester) async {
    AaEditResult? result;
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
      onResult: (r) => result = r,
    );

    // 未手选支出人:昵称为空时显示「未设置昵称(我)」(默认支出人 = 创建人,非「未知」)
    expect(find.text('未设置昵称(我)'), findsOneWidget);

    // 直接确认:人均模式回传 null,参与人 null = 全部成员
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.aaMode, 0);
    expect(result!.paidByUserId, isNull);
    expect(result!.aaParticipants, isNull);
  });

  testWidgets('支出人:新建未手选但已设昵称时,显示昵称', (tester) async {
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
      displayName: '小计',
    );

    // 未手选支出人:昵称优先于「我」,展示本地昵称
    expect(find.text('小计'), findsOneWidget);
    expect(find.text('未知'), findsNothing);
  });

  testWidgets('支出人:新建手选后,回传手选值', (tester) async {
    AaEditResult? result;
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
      onResult: (r) => result = r,
    );

    // 点击支出人行打开选择 sheet,选中「李四」(u2)
    await tester.tap(find.text('支出人'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('李四').last);
    await tester.pumpAndSettle();

    // 确认回传手选值 u2
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.paidByUserId, 'u2');
  });

  testWidgets('支出人:未手选时锁定操作者「我」所在行,顶部显示名册名', (tester) async {
    AaEditResult? result;
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
      onResult: (r) => result = r,
      // 操作者身份 = u1(名册中「张三」):未手选应锁定「我」所在行。
      localSelfId: 'u1',
    );

    // 顶部支出人展示名册名「张三」(与锁定行同名),而非「未知」。
    expect(find.text('张三'), findsNWidgets(2)); // 顶部支出人行 + 参与人行
    expect(find.text('未知'), findsNothing);

    // 防反选锁定:点击「张三」勾选框不取消,人均金额仍按 3 人分摊(30.00)。
    await tester.tap(find.byKey(const ValueKey('aa-checkbox-u1')));
    await tester.pumpAndSettle();
    expect(find.text('¥ 30'), findsNWidgets(3));

    // 未手选:确认回传 paidByUserId=null(落库层回填操作者),不写手选值。
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.paidByUserId, isNull);
  });

  testWidgets('支出人:操作者不在名册时,不锁定任何参与人行', (tester) async {
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
      // 操作者身份 = unknown-id,不在名册(u1/u2/vu_1)中。
      localSelfId: 'unknown-id',
    );

    // 顶部支出人展示本地昵称/「我」兜底,不反查名册。
    expect(find.text('未设置昵称(我)'), findsOneWidget);
    expect(find.text('未知'), findsNothing);

    // 未锁定任何参与人:「张三」行可正常取消勾选 → 人均按 2 人分摊(45)。
    // 勾选切换在行首 Checkbox 上,点击昵称文本不会触发。
    final zhangSanRow = find
        .ancestor(of: find.text('张三'), matching: find.byType(Row))
        .first;
    await tester.tap(
        find.descendant(of: zhangSanRow, matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();
    // 人均模式所有参与人行(含未勾选)都展示同一人均值:3 行 ¥ 45。
    expect(find.text('¥ 45'), findsNWidgets(3));
  });

  testWidgets('支出人:编辑回填原值,未手选保持原值回传', (tester) async {
    AaEditResult? result;
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 90,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.perPerson,
        paidByUserId: 'u1',
      ),
      onResult: (r) => result = r,
    );

    // 编辑回填支出人 u1,未手选:确认回传原值 u1(编辑不覆盖)
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.paidByUserId, 'u1');
  });
}
