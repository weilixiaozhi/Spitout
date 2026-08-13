// 周期账单编辑页（RecurringTransactionEditPage）组件测试。
//
// 需求锚点（以页面行为为准）：
//   1. 新建模式：默认「每月 + 间隔 1 + 今天开始 + 永久周期」，保存按钮禁用；
//   2. 金额非法（空/0/负/非数字）时保存按钮保持禁用，金额合法后仍需账本与分类；
//   3. 账本/分类选择走弹窗，选中后回填名称；
//   4. 频率切换：每天隐藏「间隔 + 每月第几天」，每周/每月/每年展示间隔，仅每月展示第几天；
//   5. 日期选择走滚轮 sheet，结束日期可清除回「永久周期」；
//   6. 新建保存调用 addRecurringTransaction 并以金额分/账本/分类/频率/间隔/日/备注参数化；
//   7. 编辑模式预填全部字段，保存调用 updateRecurringTransaction；
//   8. 编辑时开始日期早于最后生成日期 → clearLastGeneratedDate=true，否则 false；
//   9. 删除走确认弹窗：确认调用 deleteRecurringTransaction 并返回，取消不调用；
//  10. 保存/删除失败 toast 提示统一失败文案，不向上抛异常。

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/transaction/recurring_transaction_edit_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/app_route.dart';

/// Mock 整个 LocalRepository：未 stub 的方法返回默认值，不抛异常。
class _MockRepo extends Mock implements LocalRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late db.Category testCategory;
  late db.Ledger testLedger;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final todayLabel = DateFormat.yMd().format(today);

  db.Ledger buildLedger() => db.Ledger(
        id: 1,
        name: '测试账本',
        currency: 'CNY',
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        monthStartDay: 1,
        storageMode: 'local',
        aaEnabled: false,
      );

  db.Category buildCategory() => db.Category(
        id: 1,
        name: '餐饮',
        kind: 'expense',
        icon: 'utensils',
        sortOrder: 0,
        parentId: null,
        level: 1,
      );

  db.RecurringTransaction buildRecurring({
    DateTime? lastGeneratedDate,
  }) {
    return db.RecurringTransaction(
      id: 1,
      ledgerId: 1,
      type: 'expense',
      amount: 5000,
      categoryId: 1,
      note: '房租',
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: 15,
      startDate: DateTime(2026, 1, 1),
      lastGeneratedDate: lastGeneratedDate,
      enabled: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  /// 构建页面宿主：页面由基底路由 push 进入，便于断言保存/删除后的 pop 行为。
  Widget buildApp({db.RecurringTransaction? recurring}) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 0),
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
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  appPageRoute(
                    builder: (_) => recurring == null
                        ? const RecurringTransactionEditPage()
                        : RecurringTransactionEditPage(recurring: recurring),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 进入编辑页并等待首帧稳定。
  Future<void> openPage(WidgetTester tester,
      {db.RecurringTransaction? recurring}) async {
    await tester.pumpWidget(buildApp(recurring: recurring));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// 通过滚轮选择器把指定滚轮拖动 [delta] 格（正数=向后一项，负数=向前一项）。
  ///
  /// 设计意图：CupertinoPicker itemExtent=52，拖动 60px 稳定落在相邻项；
  /// 返回后调用方再点「确定」让选择器返回值。
  Future<void> dragWheel(WidgetTester tester, int delta) async {
    await tester.drag(
      find.byType(CupertinoPicker).last,
      Offset(0, -delta * 60.0),
    );
    await tester.pumpAndSettle();
  }

  /// 注册编辑页所需的全部 mock 查询。
  void registerLookups() {
    when(() => repo.getCategoryById(1)).thenAnswer((_) async => testCategory);
    when(() => repo.getLedgerById(1)).thenAnswer((_) async => testLedger);
    when(() => repo.getAllLedgers())
        .thenAnswer((_) async => [testLedger]);
    when(() => repo.getTopLevelCategories('expense'))
        .thenAnswer((_) async => [testCategory]);
    // 分类弹窗会为每个一级分类查子分类并做共享账本过滤，缺 stub 会让
    // FutureBuilder 停在加载态（CircularProgressIndicator 永不停止）。
    when(() => repo.getSubCategories(any())).thenAnswer((_) async => <db.Category>[]);
    when(
      () => repo.filterCategoriesForLedgerPicker(
        any(),
        ledgerId: any(named: 'ledgerId'),
        topLevelOnly: any(named: 'topLevelOnly'),
      ),
    ).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as List<db.Category>,
    );
  }

  setUp(() {
    repo = _MockRepo();
    testCategory = buildCategory();
    testLedger = buildLedger();
    registerLookups();
  });

  testWidgets('新建模式初始状态：每月/间隔1/今天开始/永久周期/保存禁用', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    final pageScrollable = find.byType(Scrollable).first;
    expect(find.text(l10n.recurringTransactionAdd), findsWidgets);
    expect(find.text(l10n.recurringTransactionMonthly), findsOneWidget);
    expect(find.text(l10n.recurringTransactionEveryNMonths(1)), findsOneWidget);
    expect(find.text('${today.day}'), findsOneWidget,
        reason: '每月第几天默认今天');

    // 日期字段在长表单下半区，先滚动到可视区再断言。
    await tester.scrollUntilVisible(
      find.text(l10n.recurringTransactionNoEndDate),
      100,
      scrollable: pageScrollable,
    );
    expect(find.text(todayLabel), findsOneWidget, reason: '开始日期默认今天');
    expect(find.text(l10n.recurringTransactionNoEndDate), findsOneWidget);

    final saveButton = find.widgetWithText(FilledButton, l10n.commonSave);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull,
        reason: '账本/分类/金额未填时保存必须禁用');
  });

  testWidgets('金额校验：空/0/负数/非数字均保持保存禁用', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    final amountField = find.widgetWithText(TextFormField, l10n.importFieldAmount);
    final saveButton = find.widgetWithText(FilledButton, l10n.commonSave);
    bool saveDisabled() =>
        tester.widget<FilledButton>(saveButton).onPressed == null;

    expect(saveDisabled(), isTrue);

    for (final invalid in ['', '0', '-5', 'abc', '1.234']) {
      await tester.enterText(amountField, invalid);
      await tester.pump();
      expect(saveDisabled(), isTrue, reason: '非法金额 $invalid 必须禁用保存');
    }

    // 金额合法但账本/分类未选，仍禁用。
    await tester.enterText(amountField, '50');
    await tester.pump();
    expect(saveDisabled(), isTrue, reason: '仅金额合法但缺账本/分类时仍禁用');
  });

  testWidgets('账本选择：弹窗选中后回填账本名', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    // InputDecorator 的 label 与内容同文案（选择账本），取内容文本（.last）落点。
    await tester.tap(find.text(l10n.ledgerSelect).last);
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsOneWidget);
    await tester.tap(find.text('测试账本'));
    await tester.pumpAndSettle();

    expect(find.text('测试账本'), findsOneWidget, reason: '选中后账本选择器应回填名称');
  });

  testWidgets('分类选择：弹窗选中后回填分类名', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    await tester.tap(find.text(l10n.commonSearch));
    await tester.pumpAndSettle();

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget, reason: '选中后分类选择器应回填名称');
  });

  testWidgets('完整新建保存：参数化调用 addRecurringTransaction 并返回', (tester) async {
    when(
      () => repo.addRecurringTransaction(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        note: any(named: 'note'),
        frequency: any(named: 'frequency'),
        interval: any(named: 'interval'),
        dayOfMonth: any(named: 'dayOfMonth'),
        dayOfWeek: any(named: 'dayOfWeek'),
        monthOfYear: any(named: 'monthOfYear'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => 1);

    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.importFieldAmount),
      '50',
    );
    await tester.pump();
    await tester.tap(find.text(l10n.ledgerSelect).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonSearch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
    await tester.pumpAndSettle();

    verify(
      () => repo.addRecurringTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 5000,
        categoryId: 1,
        note: null,
        frequency: 'monthly',
        interval: 1,
        dayOfMonth: today.day,
        dayOfWeek: null,
        monthOfYear: null,
        // 页面初始化为 DateTime.now()（带时间分量），只校验日期语义。
        startDate: any(named: 'startDate'),
        endDate: null,
      ),
    ).called(1);
    expect(find.byType(RecurringTransactionEditPage), findsNothing,
        reason: '保存成功后应返回上一页');
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('频率切换为每周：展示每周、间隔可调、隐藏每月第几天', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    // 打开频率滚轮（默认每月，向前一格到每周）
    await tester.tap(find.text(l10n.recurringTransactionMonthly));
    await tester.pumpAndSettle();
    expect(find.text(l10n.recurringTransactionFrequency), findsWidgets);
    await dragWheel(tester, -1);
    await tester.tap(find.text(l10n.commonOk));
    await tester.pumpAndSettle();

    expect(find.text(l10n.recurringTransactionWeekly), findsOneWidget);
    expect(find.text(l10n.recurringTransactionEveryNWeeks(1)), findsOneWidget,
        reason: '每周模式下间隔选择器应展示并跟随频率');
    expect(find.text(l10n.recurringTransactionDayOfMonth), findsNothing,
        reason: '仅每月模式展示「每月第几天」');
  });

  testWidgets('频率切换为每天：隐藏间隔与每月第几天', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    await tester.tap(find.text(l10n.recurringTransactionMonthly));
    await tester.pumpAndSettle();
    // 每月(2) → 每周(1) → 每天(0)，分两段拖动保证落点稳定。
    await dragWheel(tester, -1);
    await tester.pumpAndSettle();
    await dragWheel(tester, -1);
    await tester.tap(find.text(l10n.commonOk));
    await tester.pumpAndSettle();

    expect(find.text(l10n.recurringTransactionDaily), findsOneWidget);
    expect(find.text(l10n.recurringTransactionInterval), findsNothing,
        reason: '每天模式无需间隔');
    expect(find.text(l10n.recurringTransactionDayOfMonth), findsNothing,
        reason: '每天模式无需每月第几天');
  });

  testWidgets('间隔选择：每周模式下选 2 显示「每 2 周」', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    // 切到每周
    await tester.tap(find.text(l10n.recurringTransactionMonthly));
    await tester.pumpAndSettle();
    await dragWheel(tester, -1);
    await tester.tap(find.text(l10n.commonOk));
    await tester.pumpAndSettle();

    // 打开间隔滚轮（默认 1，向后一格到 2）
    await tester.tap(find.text(l10n.recurringTransactionEveryNWeeks(1)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.recurringTransactionInterval), findsWidgets);
    await dragWheel(tester, 1);
    await tester.tap(find.text(l10n.commonOk));
    await tester.pumpAndSettle();

    expect(find.text(l10n.recurringTransactionEveryNWeeks(2)), findsOneWidget);
  });

  testWidgets('每月第几天选择：滚动后滚轮选择并更新字段', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    final expectedDay = (today.day + 1 > 31) ? 31 : today.day + 1;

    await tester.scrollUntilVisible(
      find.text(l10n.recurringTransactionDayOfMonth),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.recurringTransactionDayOfMonth));
    await tester.pumpAndSettle();
    await dragWheel(tester, 1);
    await tester.tap(find.text(l10n.commonOk));
    await tester.pumpAndSettle();

    expect(find.text('$expectedDay'), findsOneWidget,
        reason: '每月第几天应随滚轮选择更新');
  });

  testWidgets('日期选择：开始/结束日期滚轮确认后展示，结束日期可清除', (tester) async {
    await openPage(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    final pageScrollable = find.byType(Scrollable).first;

    // 开始日期：默认今天，滚动到可视区后打开 sheet 直接完成。
    await tester.scrollUntilVisible(
      find.text(todayLabel),
      100,
      scrollable: pageScrollable,
    );
    // scrollUntilVisible 只保证「出现」，日期字段在列表最底部可能仍被裁切，
    // 再补滚一段确保点击落点完整可见。
    await tester.drag(pageScrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text(todayLabel));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsWidgets);
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();
    expect(find.text(todayLabel), findsWidgets);

    // 结束日期：同样选择今天并展示。
    await tester.scrollUntilVisible(
      find.text(l10n.recurringTransactionNoEndDate),
      100,
      scrollable: pageScrollable,
    );
    await tester.drag(pageScrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recurringTransactionNoEndDate));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();
    expect(find.text(todayLabel), findsNWidgets(2),
        reason: '开始与结束日期均展示今天');

    // 清除结束日期 → 回到「永久周期」。
    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    expect(find.text(l10n.recurringTransactionNoEndDate), findsOneWidget);
    expect(find.text(todayLabel), findsOneWidget, reason: '仅剩开始日期');
  });

  testWidgets('编辑模式：标题为编辑且预填金额/备注/分类/账本/删除按钮', (tester) async {
    await openPage(tester, recurring: buildRecurring());

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    expect(find.text(l10n.recurringTransactionEdit), findsWidgets);
    expect(find.text('50.00'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('测试账本'), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsOneWidget,
        reason: '编辑模式应展示删除入口');

    // 备注输入框在长表单底部，先滚动再断言预填内容。
    await tester.scrollUntilVisible(
      find.text('房租'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('房租'), findsOneWidget);
  });

  testWidgets('编辑保存：调用 updateRecurringTransaction 且不重置生成日期', (tester) async {
    when(
      () => repo.updateRecurringTransaction(
        id: any(named: 'id'),
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        note: any(named: 'note'),
        frequency: any(named: 'frequency'),
        interval: any(named: 'interval'),
        dayOfMonth: any(named: 'dayOfMonth'),
        dayOfWeek: any(named: 'dayOfWeek'),
        monthOfYear: any(named: 'monthOfYear'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        enabled: any(named: 'enabled'),
        clearLastGeneratedDate: any(named: 'clearLastGeneratedDate'),
      ),
    ).thenAnswer((_) async {});

    // 模板 lastGeneratedDate=null，普通编辑不应请求重置锚点。
    await openPage(tester, recurring: buildRecurring());
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateRecurringTransaction(
        id: 1,
        ledgerId: 1,
        type: 'expense',
        amount: 5000,
        categoryId: 1,
        note: '房租',
        frequency: 'monthly',
        interval: 1,
        dayOfMonth: 15,
        dayOfWeek: null,
        monthOfYear: null,
        startDate: DateTime(2026, 1, 1),
        endDate: null,
        enabled: true,
        clearLastGeneratedDate: false,
      ),
    ).called(1);
    expect(find.byType(RecurringTransactionEditPage), findsNothing);
  });

  testWidgets('编辑保存：开始日期早于最后生成日期时重置锚点', (tester) async {
    when(
      () => repo.updateRecurringTransaction(
        id: any(named: 'id'),
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        note: any(named: 'note'),
        frequency: any(named: 'frequency'),
        interval: any(named: 'interval'),
        dayOfMonth: any(named: 'dayOfMonth'),
        dayOfWeek: any(named: 'dayOfWeek'),
        monthOfYear: any(named: 'monthOfYear'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        enabled: any(named: 'enabled'),
        clearLastGeneratedDate: any(named: 'clearLastGeneratedDate'),
      ),
    ).thenAnswer((_) async {});

    // lastGeneratedDate=2026-03-01 晚于 startDate=2026-01-01：
    // 用户把开始日期改早会触发重复补生成，必须重置锚点。
    await openPage(
      tester,
      recurring: buildRecurring(lastGeneratedDate: DateTime(2026, 3, 1)),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateRecurringTransaction(
        id: any(named: 'id'),
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        note: any(named: 'note'),
        frequency: any(named: 'frequency'),
        interval: any(named: 'interval'),
        dayOfMonth: any(named: 'dayOfMonth'),
        dayOfWeek: any(named: 'dayOfWeek'),
        monthOfYear: any(named: 'monthOfYear'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        enabled: any(named: 'enabled'),
        clearLastGeneratedDate: true,
      ),
    ).called(1);
  });

  testWidgets('删除：确认后调用 deleteRecurringTransaction 并返回', (tester) async {
    when(() => repo.deleteRecurringTransaction(any())).thenAnswer((_) async {});

    await openPage(tester, recurring: buildRecurring());
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.recurringTransactionDeleteConfirm), findsOneWidget);

    await tester.tap(find.text(l10n.commonDelete).last);
    await tester.pumpAndSettle();

    verify(() => repo.deleteRecurringTransaction(1)).called(1);
    expect(find.byType(RecurringTransactionEditPage), findsNothing,
        reason: '删除成功后应返回上一页');
  });

  testWidgets('删除取消：不调用 repository', (tester) async {
    await openPage(tester, recurring: buildRecurring());
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    verifyNever(() => repo.deleteRecurringTransaction(any()));
    expect(find.byType(RecurringTransactionEditPage), findsOneWidget,
        reason: '取消后停留在编辑页');
  });

  testWidgets('保存失败：toast 提示统一失败文案且不返回', (tester) async {
    when(
      () => repo.addRecurringTransaction(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        note: any(named: 'note'),
        frequency: any(named: 'frequency'),
        interval: any(named: 'interval'),
        dayOfMonth: any(named: 'dayOfMonth'),
        dayOfWeek: any(named: 'dayOfWeek'),
        monthOfYear: any(named: 'monthOfYear'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenThrow(Exception('db down'));

    await openPage(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.importFieldAmount),
      '50',
    );
    await tester.pump();
    await tester.tap(find.text(l10n.ledgerSelect).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonSearch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
    await tester.pumpAndSettle();

    expect(find.text(l10n.commonOperationFailed), findsOneWidget);
    expect(find.byType(RecurringTransactionEditPage), findsOneWidget,
        reason: '保存失败不应返回上一页');
    expect(tester.takeException(), isNull);
    // 推进 toast 自动消失定时器，避免残留 pending timer。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('删除失败：toast 提示且停留编辑页', (tester) async {
    when(() => repo.deleteRecurringTransaction(any()))
        .thenThrow(Exception('db down'));

    await openPage(tester, recurring: buildRecurring());
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete).last);
    await tester.pumpAndSettle();

    expect(find.text(l10n.commonOperationFailed), findsOneWidget);
    expect(find.byType(RecurringTransactionEditPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
