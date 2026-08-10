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

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/pages/statistics/aa_edit_page.dart';
import 'package:spitout/services/statistics/aa_edit_models.dart';
import 'package:spitout/services/statistics/aa_statistics_service.dart';
import 'package:spitout/core/router/routes.dart';
import 'package:spitout/theme/icons/app_icons.dart';

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
        displayNameProvider.overrideWithBuild((ref, notifier) => displayName),
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

/// 取参与人勾选框外层 Container 的边框,用于验证锁定态去边框/普通态留边框。
Border? _checkboxBorder(WidgetTester tester, String id) {
  final container = tester.widget<Container>(
    find
        .descendant(
            of: find.byKey(ValueKey('aa-checkbox-$id')),
            matching: find.byType(Container))
        .first,
  );
  // BoxDecoration.border 的静态类型为 BoxBorder?,实际放入的恒为 Border。
  return (container.decoration as BoxDecoration?)?.border as Border?;
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

  testWidgets('人均分摊:已勾选行展示人均金额,取消勾选金额栏不显示', (tester) async {
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

    // 人均分摊:3 人均摊 90 → 已勾选行只读展示 ¥ 30
    expect(find.text('¥ 30'), findsNWidgets(3));

    // 取消勾选「李四」(u2):金额实时重算为 90/2=45,
    // u2 行金额栏不显示,剩 2 行展示 ¥ 45。
    await tester.tap(find.byKey(const ValueKey('aa-checkbox-u2')));
    await tester.pumpAndSettle();
    expect(find.text('¥ 45'), findsNWidgets(2));
    final u2Row = find
        .ancestor(
            of: find.byKey(const ValueKey('aa-checkbox-u2')),
            matching: find.byType(Row))
        .first;
    expect(
        find.descendant(of: u2Row, matching: find.text('¥ 45')),
        findsNothing);
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

    // 未手选支出人:昵称为空时显示「未设置昵称 (我)」(默认支出人 = 创建人,非「未知」)
    expect(find.text('未设置昵称 (我)', findRichText: true), findsOneWidget);

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

    // 未手选支出人:昵称优先于「我」,展示本地昵称 + 共享「(我)」后缀
    expect(find.text('小计 (我)', findRichText: true), findsOneWidget);
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

    // 确认回传:参与人仍为全部成员(null = 未被取消)。
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.aaParticipants, isNull);
    // 未手选:回传 paidByUserId=null(落库层回填操作者),不写手选值。
    expect(result!.paidByUserId, isNull);
  });

  testWidgets('支出人:操作者不在名册时,不锁定任何参与人行', (tester) async {
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
      // 操作者身份 = unknown-id,不在名册(u1/u2/vu_1)中。
      localSelfId: 'unknown-id',
    );

    // 顶部支出人展示本地昵称/「我」兜底,不反查名册。
    expect(find.text('未设置昵称 (我)', findRichText: true), findsOneWidget);
    expect(find.text('未知'), findsNothing);

    // 未锁定任何参与人:「张三」行可正常取消勾选。
    // 勾选切换在行首 Checkbox 上,点击昵称文本不会触发。
    final zhangSanRow = find
        .ancestor(of: find.text('张三'), matching: find.byType(Row))
        .first;
    await tester.tap(
        find.descendant(of: zhangSanRow, matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();

    // 取消勾选后张三行金额栏不显示:仅剩 2 行展示人均 ¥ 45(90 / 2)。
    expect(find.text('¥ 45'), findsNWidgets(2));

    // 确认回传参与人名单:张三(u1)退出,剩李四(u2)/小明(vu_1)。
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.aaParticipants, ['u2', 'vu_1']);
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

  testWidgets('指定分摊:支出人金额可编辑,确认回传修改值', (tester) async {
    AaEditResult? result;
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.custom,
        paidByUserId: 'u1',
        splits: {'u1': '30', 'u2': '30', 'vu_1': '40'},
      ),
      onResult: (r) => result = r,
    );

    // 支出人(u1)行金额为可编辑输入框(金额可调,仅勾选锁定)。
    // 用勾选框 key 定位参与人行,避免命中顶部支出人行的同名文本。
    final u1Row = find
        .ancestor(
            of: find.byKey(const ValueKey('aa-checkbox-u1')),
            matching: find.byType(Row))
        .first;
    final u1Field =
        find.descendant(of: u1Row, matching: find.byType(TextField));
    expect(u1Field, findsOneWidget);

    // 支出人金额 30 → 40,李四 30 → 20,合计 100 与交易金额持平
    await tester.enterText(u1Field, '40');
    await tester.pump();
    final u2Row = find
        .ancestor(
            of: find.byKey(const ValueKey('aa-checkbox-u2')),
            matching: find.byType(Row))
        .first;
    await tester.enterText(
        find.descendant(of: u2Row, matching: find.byType(TextField)), '20');
    await tester.pump();
    expect(find.text('¥ 100 / ¥ 100'), findsOneWidget);

    // 确认回传修改后的支出人金额
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.aaSplits!['u1'], '40.00');
    expect(result!.aaSplits!['u2'], '20.00');
    expect(result!.aaSplits!['vu_1'], '40.00');
  });

  testWidgets('指定分摊:取消勾选后总额不含其金额,金额栏不显示', (tester) async {
    AaEditResult? result;
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.custom,
        paidByUserId: 'u1',
        splits: {'u1': '30', 'u2': '30', 'vu_1': '40'},
      ),
      onResult: (r) => result = r,
    );

    // 初始:3 个金额输入框(支出人 + 2 参与人)
    expect(find.byType(TextField), findsNWidgets(3));

    // 取消勾选「李四」(u2)
    await tester.tap(find.byKey(const ValueKey('aa-checkbox-u2')));
    await tester.pumpAndSettle();

    // 总额/差额不含 u2 金额:仅 30(u1)+ 40(vu_1)= 70 / 100
    expect(find.text('¥ 70 / ¥ 100'), findsOneWidget);
    // u2 行金额栏不显示:输入框剩 2 个,且 u2 行内无金额组件
    expect(find.byType(TextField), findsNWidgets(2));
    final u2Row = find
        .ancestor(
            of: find.byKey(const ValueKey('aa-checkbox-u2')),
            matching: find.byType(Row))
        .first;
    expect(
        find.descendant(of: u2Row, matching: find.byType(TextField)),
        findsNothing);

    // 确认:u2 不参与分摊,指定金额不含 u2
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.aaParticipants, ['u1', 'vu_1']);
    expect(result!.aaSplits!.keys, isNot(contains('u2')));
  });

  testWidgets('复选框:支出人锁定态去掉边框,普通参与人保留边框', (tester) async {
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.custom,
        paidByUserId: 'u1',
      ),
      onResult: (_) {},
    );

    // 支出人(u1)锁定态复选框:边框透明(去边框,仅灰底+白勾)。
    final lockedBorder = _checkboxBorder(tester, 'u1');
    expect(lockedBorder, isNotNull);
    expect(lockedBorder!.top.color, Colors.transparent);

    // 普通参与人(u2)复选框:保留可点击边框(非透明)。
    final normalBorder = _checkboxBorder(tester, 'u2');
    expect(normalBorder, isNotNull);
    expect(normalBorder!.top.color, isNot(Colors.transparent));
  });

  testWidgets('指定分摊:新建默认不填充金额,合计为 0/总额', (tester) async {
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.custom,
        paidByUserId: 'u1',
      ),
      onResult: (_) {},
    );

    // 新建指定分摊:3 个金额输入框内容均为空(默认不预填人均金额)。
    expect(find.byType(TextField), findsNWidgets(3));
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
    }
    // 空金额不触发清空按钮,且合计为 0 / 总额(偏差态,由用户按需填写)。
    expect(find.byIcon(AppIcons.cancel), findsNothing);
    expect(find.text('¥ 0 / ¥ 100'), findsOneWidget);
  });

  testWidgets('指定分摊:金额输入有内容显示圆形清空按钮,点击清空', (tester) async {
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.custom,
        paidByUserId: 'u1',
        splits: {'u1': '30', 'u2': '30', 'vu_1': '40'},
      ),
      onResult: (_) {},
    );

    // 3 个金额框均有内容 → 每行右侧显示圆形 x 清空按钮。
    expect(find.byIcon(AppIcons.cancel), findsNWidgets(3));

    // 点击支出人(u1)行清空按钮:金额清空、按钮消失、合计不含 u1 金额。
    final u1Row = find
        .ancestor(
            of: find.byKey(const ValueKey('aa-checkbox-u1')),
            matching: find.byType(Row))
        .first;
    await tester.tap(
        find.descendant(of: u1Row, matching: find.byIcon(AppIcons.cancel)));
    await tester.pump();

    expect(find.byIcon(AppIcons.cancel), findsNWidgets(2));
    expect(find.text('¥ 70 / ¥ 100'), findsOneWidget);
  });

  testWidgets('分摊页右对齐:账单详情值/分摊方式按钮/合计/人均金额右侧在同一条直线', (tester) async {
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.perPerson,
      ),
      onResult: (_) {},
    );

    // 四个「右侧内容」：
    // - 账单详情模块的金额值（¥ 100）
    // - 分摊方式模块的三态切换按钮
    // - 分摊配置卡的合计行（¥ 100 / ¥ 100）
    // - 参与人行的只读人均金额（¥ 33.33）
    final subjectAmount = find.text('¥ 100');
    final toggle = find.byKey(const ValueKey('aa_mode_toggle'));
    final total = find.text('¥ 100 / ¥ 100');
    final perPerson = find.text('¥ 33.33').first;

    expect(subjectAmount, findsOneWidget);
    expect(toggle, findsOneWidget);
    expect(total, findsOneWidget);
    expect(perPerson, findsOneWidget);

    final subjectRight = tester.getTopRight(subjectAmount).dx;
    final toggleRight = tester.getTopRight(toggle).dx;
    final totalRight = tester.getTopRight(total).dx;
    final perPersonRight = tester.getTopRight(perPerson).dx;

    expect(
      subjectRight,
      closeTo(toggleRight, 0.5),
      reason: '账单详情值应与分摊方式按钮右对齐在同一条直线',
    );
    expect(
      totalRight,
      closeTo(toggleRight, 0.5),
      reason: '合计行应与分摊方式按钮右对齐在同一条直线',
    );
    expect(
      perPersonRight,
      closeTo(toggleRight, 0.5),
      reason: '参与人金额应与分摊方式按钮右对齐在同一条直线',
    );
  });

  testWidgets('分摊方式按钮与记账编辑器一致:80x24、圆角 5', (tester) async {
    await _openAaEdit(
      tester,
      args: AaEditPageArgs(
        ledgerId: 1,
        amount: 100,
        currencyCode: 'CNY',
        categoryName: '餐饮',
        date: DateTime(2026, 8, 3),
        mode: AaMode.perPerson,
      ),
      onResult: (_) {},
    );

    final toggle = find.byKey(const ValueKey('aa_mode_toggle'));
    expect(toggle, findsOneWidget);
    expect(tester.getSize(toggle), const Size(80, 24));

    final box = tester.widget<Container>(toggle);
    final deco = box.decoration! as BoxDecoration;
    expect(
      deco.borderRadius,
      BorderRadius.circular(5),
      reason: '按钮缩小后圆角应同步减少（6 → 5）',
    );
  });
}
