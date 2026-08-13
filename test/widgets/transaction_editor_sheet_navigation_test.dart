// 记账 sheet 内「编辑分类」入口的导航栈行为组件测试
//
// sheet 内「编辑分类」通过 pushNamed(Routes.categoryManage) 打开新页，
// 不做任何栈复用 / popUntil，核心验证：
//   1. 点「编辑分类」→ 新 manage 页 push，sheet 仍留在栈上（不被连带 pop）；
//   2. 已输入的金额在返回后完整保留（记账现场不丢）。
//
// 注意：宿主 MaterialApp 必须挂 onGenerateRoute: appRoute，
// 否则 pushNamed(Routes.categoryManage) 解析失败导致黑屏。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/data/models/category_picker_tree.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/category/category_manage_page.dart';
import 'package:spitout/providers/category/category_picker_providers.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/router.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/utils/currency/rate_math.dart';
import 'package:spitout/widgets/amount_expression_bar.dart';
import 'package:spitout/widgets/amount_keypad.dart';
import 'package:spitout/widgets/category_grid_section.dart';
import 'package:spitout/widgets/keypad_constants.dart';
import 'package:spitout/widgets/note_input_row.dart';
import 'package:spitout/widgets/transaction_editor_sheet.dart';
import 'package:spitout/widgets/transaction_editor_sheet_entry.dart';

/// Mock 整个 LocalRepository，未 stub 的方法返回默认值不抛异常。
class _MockRepo extends Mock implements LocalRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  /// 构建测试宿主：
  /// - ProviderScope 注入 mock repo 与空分类树（sheet 显示「编辑分类」入口）；
  /// - MaterialApp 挂 onGenerateRoute: appRoute，保证命名路由可解析；
  /// - home 提供「打开记账」按钮，通过 showTransactionEditorSheet 拉起 sheet。
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 0),
        // 本位币固定为 CNY，避免依赖 currentLedgerProvider
        currentLedgerCurrencyProvider.overrideWith((ref) => 'CNY'),
        // 汇率表置空：本位币记账不触发汇率拉取，杜绝网络调用
        effectiveRatesForLedgerProvider.overrideWith(
          (ref) async => <String, EffectiveRate>{},
        ),
        // 空分类树：CategoryGridSection 渲染空态 + 居中「编辑分类」入口
        categoryPickerTreeProvider('expense').overrideWith(
          (ref) => Stream<CategoryPickerTree>.value(
            const CategoryPickerTree(topLevel: [], children: {}),
          ),
        ),
        // manage 页依赖：空分类列表即可正常渲染
        categoriesWithCountProvider.overrideWith(
          (ref) =>
              Stream<
                List<({db.Category category, int transactionCount})>
              >.value(const []),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        onGenerateRoute: appRoute,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showTransactionEditorSheet(context),
                child: const Text('open-sheet'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 金额显示区中定位指定金额文本（避免与键盘上的数字键混淆）
  Finder amountText(String amount) => find.descendant(
    of: find.byType(AmountExpressionBar),
    matching: find.text(amount),
  );

  testWidgets('记账 sheet 点「编辑分类」→ 新 manage 页 push、sheet 保留现场', (tester) async {
    await tester.pumpWidget(buildApp());

    // 1. 打开记账 sheet
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();

    expect(
      find.byType(TransactionEditorSheet),
      findsOneWidget,
      reason: '记账 sheet 应打开',
    );

    // 2. 输入金额 12（点数字键 1、2）
    await tester.tap(
      find.descendant(of: find.byType(AmountKeypad), matching: find.text('1')),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(AmountKeypad), matching: find.text('2')),
    );
    await tester.pump();
    expect(amountText('12'), findsOneWidget, reason: '金额 12 应已输入');

    // 3. 点「编辑分类」：pushNamed(Routes.categoryManage) 新压一页
    await tester.tap(find.text('编辑分类'));
    await tester.pumpAndSettle();

    // 4. 新 manage 页 push 成功，且 sheet 仍在栈上（未被连带 pop）
    // 注：被全屏路由覆盖后 sheet 转为 offstage，需 skipOffstage: false 断言其仍挂载
    expect(
      find.byType(CategoryManagePage),
      findsOneWidget,
      reason: '应 push 出分类管理页',
    );
    expect(
      find.byType(TransactionEditorSheet, skipOffstage: false),
      findsOneWidget,
      reason: 'sheet 应保留在导航栈上（offstage 但未销毁）',
    );

    // 5. 系统返回键：pop manage 页回到 sheet
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // 6. sheet 内容未丢：金额 12 仍在
    expect(
      find.byType(TransactionEditorSheet),
      findsOneWidget,
      reason: '返回后 sheet 应重新可见',
    );
    expect(amountText('12'), findsOneWidget, reason: '返回后已输入的金额应保留');
  });

  testWidgets('记账 sheet 键盘容器：6 行均分、备注行矮 5、间距 4、内边距 8/40、无阴影', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();

    // 单行高 h：金额栏 = h、键盘 4 行均分（(键盘高-3×2)/4）、备注 = h-10
    final keypadSize = tester.getSize(find.byType(AmountKeypad));
    final h = (keypadSize.height - 3 * KeypadLayout.rowGap) / 4;
    expect(
      tester.getSize(find.byType(AmountExpressionBar)).height,
      closeTo(h, 0.5),
      reason: '金额栏高度应等于单行高',
    );
    expect(
      tester.getSize(find.byType(NoteInputRow)).height,
      closeTo(h - KeypadLayout.noteRowDelta, 0.5),
      reason: '备注行永远比其余 5 行矮 5px',
    );

    // 相邻两行纵向间距全局 4px：备注 ↔ 金额栏、金额栏 ↔ 键盘
    final noteBottom = tester.getBottomLeft(find.byType(NoteInputRow)).dy;
    final barTop = tester.getTopLeft(find.byType(AmountExpressionBar)).dy;
    expect(barTop - noteBottom, KeypadLayout.rowGap, reason: '备注行与金额栏间距应为 4');

    final barBottom = tester.getBottomLeft(find.byType(AmountExpressionBar)).dy;
    final keypadTop = tester.getTopLeft(find.byType(AmountKeypad)).dy;
    expect(keypadTop - barBottom, KeypadLayout.rowGap, reason: '金额栏与键盘间距应为 4');

    // 键盘区高度按可用高度占比计算：测试面 600 高 → 固定 40% = 240px
    final keyboardContainer = find.byWidgetPredicate(
      (w) => w is Container && w.color == SpitoutColors.lightKeypadBackground,
    );
    expect(
      tester.getSize(keyboardContainer).height,
      240,
      reason: '键盘区高度应为可用高度 40%',
    );

    // 分类区吃键盘区之外的剩余空间（保底 100px）
    final categoryH = tester.getSize(find.byType(CategoryGridSection)).height;
    expect(categoryH, greaterThan(200), reason: '分类区应吃掉剩余空间，而非停在保底 100px');
    expect(categoryH, lessThan(400), reason: '分类区不应再被键盘区挤到只剩一行');

    // 底部键盘容器内边距：上 8 / 左 8 / 右 8 / 下 40
    final bottomPadding = find.byWidgetPredicate(
      (w) =>
          w is Padding &&
          w.padding == const EdgeInsets.fromLTRB(8, 8, 8, 40),
    );
    expect(bottomPadding, findsWidgets, reason: '底部键盘容器内边距应为上 8 / 下 40');

    // 无向上阴影
    final shadowed = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).boxShadow != null,
    );
    expect(shadowed, findsNothing, reason: '底部键盘容器不应有向上阴影');
  });

  testWidgets('系统键盘拉起时键盘区保持目标高度，收缩由分类区承担', (tester) async {
    // 用 400x800 竖屏模拟主流手机：全屏可用高度 40% 目标 = 320px
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();

    final keypadContainer = find.byWidgetPredicate(
      (w) => w is Container && w.color == SpitoutColors.lightKeypadBackground,
    );
    final closedKeypadH = tester.getSize(keypadContainer).height;
    final closedCategoryH = tester.getSize(
      find.byType(CategoryGridSection),
    ).height;

    // 模拟备注聚焦后系统键盘拉起（底部 inset 300px）
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final openKeypadH = tester.getSize(keypadContainer).height;
    final openCategoryH = tester.getSize(
      find.byType(CategoryGridSection),
    ).height;

    expect(
      openKeypadH,
      closedKeypadH,
      reason: '系统键盘拉起时键盘区应保持目标高度，不再整体压缩',
    );
    expect(
      openCategoryH,
      lessThan(closedCategoryH),
      reason: '系统键盘拉起时收缩应主要由分类区承担',
    );
    expect(
      openCategoryH,
      greaterThanOrEqualTo(0),
      reason: '分类区不应溢出布局',
    );
  });
}
