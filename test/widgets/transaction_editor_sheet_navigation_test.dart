// 记账 sheet 内「编辑分类」入口的导航栈行为组件测试
//
// 背景：导航环重构后，sheet 内「编辑分类」改为 pushNamed(Routes.categoryManage)，
// 不再做任何栈复用 / popUntil。本测试是本轮重构唯一真正防回归的用例，
// 核心验证 D1/D2 已冻结决策：
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
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/data/repositories/category_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/category/category_manage_page.dart';
import 'package:spitout/providers/category/category_picker_providers.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/router.dart';
import 'package:spitout/utils/currency/rate_math.dart';
import 'package:spitout/widgets/amount_expression_bar.dart';
import 'package:spitout/widgets/amount_keypad.dart';
import 'package:spitout/widgets/transaction_editor_sheet.dart';
import 'package:spitout/widgets/transaction_editor_sheet_entry.dart';

/// Mock 整个 BaseRepository，未 stub 的方法返回默认值不抛异常。
class _MockRepo extends Mock implements BaseRepository {}

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
        currentLedgerIdProvider.overrideWith((ref) => 0),
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
          (ref) => Stream<List<({db.Category category, int transactionCount})>>.value(
            const [],
          ),
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

    expect(find.byType(TransactionEditorSheet), findsOneWidget,
        reason: '记账 sheet 应打开');

    // 2. 输入金额 12（点数字键 1、2）
    await tester.tap(find.descendant(
      of: find.byType(AmountKeypad),
      matching: find.text('1'),
    ));
    await tester.pump();
    await tester.tap(find.descendant(
      of: find.byType(AmountKeypad),
      matching: find.text('2'),
    ));
    await tester.pump();
    expect(amountText('12'), findsOneWidget, reason: '金额 12 应已输入');

    // 3. 点「编辑分类」：pushNamed(Routes.categoryManage) 新压一页
    await tester.tap(find.text('编辑分类'));
    await tester.pumpAndSettle();

    // 4. 新 manage 页 push 成功，且 sheet 仍在栈上（未被连带 pop）
    // 注：被全屏路由覆盖后 sheet 转为 offstage，需 skipOffstage: false 断言其仍挂载
    expect(find.byType(CategoryManagePage), findsOneWidget,
        reason: '应 push 出分类管理页');
    expect(find.byType(TransactionEditorSheet, skipOffstage: false), findsOneWidget,
        reason: 'sheet 应保留在导航栈上（offstage 但未销毁）');

    // 5. 系统返回键：pop manage 页回到 sheet
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // 6. sheet 内容未丢：金额 12 仍在
    expect(find.byType(TransactionEditorSheet), findsOneWidget,
        reason: '返回后 sheet 应重新可见');
    expect(amountText('12'), findsOneWidget,
        reason: '返回后已输入的金额应保留');
  });
}
