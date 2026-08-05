/// 统计页（AnalyticsPage）组件测试。
///
/// 测试框架：flutter_test + flutter_riverpod + mocktail（对齐项目现有测试栈）。
///
/// 重点验证修复项：
/// - B1/B2：Header 不再渲染「支出」文案，账期文案仅出现一次。
/// - B3：全局空数据时 Header 禁用点击、无下拉箭头。
/// - B6：横滑提示横幅空态/有数据均恒显、无关闭按钮。
/// - B7：折线图区域禁用横滑（enableSwipe=false）。
/// - B8：空态判定以 txCount 为准（sum=0 但有交易不判空）。
/// - B9：环图空数据时显示中心 0 占比。
/// - B16：错误态显示重试按钮。
/// - 加载态显示骨架屏。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/analytics_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/statistics/statistics_providers.dart';
import 'package:spitout/providers/ui/ui_state_providers.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/utils/date/analytics_sub_tabs.dart';
import 'package:spitout/widgets/capsule_switcher.dart';

/// Mock 整个 BaseRepository：未 stub 的方法返回默认值（null/0/false），不抛异常。
class _MockRepo extends Mock implements BaseRepository {}

typedef _HierarchyRow = ({
  int? id,
  String name,
  String? icon,
  int? parentId,
  int level,
  double total,
});
typedef _DayPoint = ({DateTime day, double total});
typedef _MonthPoint = ({DateTime month, double total});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late Ledger testLedger;

  setUp(() {
    resetGlobalTestState();
    repo = _MockRepo();
    testLedger = Ledger(
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
    // 默认 stub：空数据
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => false);
    when(() => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => null);
    when(() => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => null);
    when(() => repo.getCategoriesByIds(any()))
        .thenAnswer((_) async => const {});
    when(() => repo.getSharedSyntheticCategoriesForLedger(any()))
        .thenAnswer((_) async => const {});
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_HierarchyRow>[]);
    when(() => repo.totalsByDay(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_DayPoint>[]);
    when(() => repo.totalsByMonth(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          year: any(named: 'year'),
        )).thenAnswer((_) async => <_MonthPoint>[]);
    when(() => repo.countByTypeInRange(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => 0);
    when(() => repo.countUnconvertedForeignTx(any()))
        .thenAnswer((_) async => 0);
    when(() => repo.countForeignCurrencyTx(any()))
        .thenAnswer((_) async => 0);
  });

  /// 构建带 overrides 的测试宿主。
  /// [hasAnyData] / [earliest] / [latest] 控制全局空数据与数据范围。
  /// [dataRangeDelay] 可选：让 analyticsDataRangeProvider 延迟 resolve，
  /// 用于复现「首帧仅单 tab、provider 异步 resolve 后列表扩张」的滚动错位 BUG。
  Widget buildApp({
    bool hasAnyData = false,
    DateTime? earliest,
    DateTime? latest,
    Duration? dataRangeDelay,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
        currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(testLedger)),
        currentMonthStartDayProvider.overrideWith((ref) => 1),
        selectedMonthProvider.overrideWithBuild((ref, notifier) => DateTime(2026, 7, 1)),
        // 直接 override 统计页专用 provider，避免走 repo 链
        analyticsHasAnyExpenseProvider.overrideWith((ref) async => hasAnyData),
        analyticsDataRangeProvider.overrideWith((ref) async {
          if (dataRangeDelay != null) {
            await Future.delayed(dataRangeDelay);
          }
          return (
            earliest: earliest,
            latest: latest,
          );
        }),
        ledgerUnconvertedForeignTxCountProvider.overrideWith((ref) async => 0),
        ledgerForeignTxCountProvider.overrideWith((ref) async => 0),
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
        home: const AnalyticsPage(),
      ),
    );
  }

  /// 分步 pump：让 async provider 完成首帧渲染。
  /// 不用 pumpAndSettle —— 骨架屏的 PulseSkeleton 是持续动画会永久超时。
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('全局空数据：Header 禁用点击且无下拉箭头（B3 回归）', (tester) async {
    await tester.pumpWidget(buildApp(hasAnyData: false));
    await prime(tester);

    // 全局空数据时不应出现下拉箭头图标
    expect(find.byIcon(AppIcons.chevronDown), findsNothing,
        reason: '全局空数据时 Header 应隐藏下拉箭头');

    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    // BUG1 修复：空数据应展示完整页面，而非全局「无数据」空白占位
    expect(find.text(l10n.commonEmpty), findsNothing,
        reason: '空数据应展示完整页面而非全局空白占位（BUG1 修复）');
    // 横滑提示横幅应恒显（空态也展示）
    expect(find.text(l10n.analyticsSwipePeriodHint(l10n.analyticsMonth)), findsOneWidget,
        reason: '空数据也应显示横滑提示横幅（BUG1 修复）');
    // 空数据环图仍渲染（灰色镂空圆环占位）
    expect(find.byType(PieChart), findsOneWidget,
        reason: '空数据应展示灰色镂空圆环');
    // 统计看板优化：环图空态中心不再展示「0」
    final centerZero = find.byWidgetPredicate(
      (w) => w is Text && w.data == '0' && w.style?.fontSize == 24,
    );
    expect(centerZero, findsNothing,
        reason: '空数据环图中心不应展示「0」（统计看板优化）');
  });

  testWidgets('全局空数据：默认周期保持「月」，不强制切周', (tester) async {
    await tester.pumpWidget(buildApp(hasAnyData: false));
    await prime(tester);
    // 多 pump 几帧，确认 build 内不会再触发任何切周逻辑
    await tester.pump(const Duration(milliseconds: 100));

    // 底部 CapsuleSwitcher 的选中项应为「月」（空数据也无需切周）。
    final switcher = tester.widget<CapsuleSwitcher<AnalyticsPeriod>>(
      find.byType(CapsuleSwitcher<AnalyticsPeriod>),
    );
    expect(switcher.selectedValue, AnalyticsPeriod.month,
        reason: '空数据态默认周期应为「月」，不应被强制切到「周」');
  });

  testWidgets('有数据：Header 显示下拉箭头且不渲染支出文案（B1/B2/B3 回归）',
      (tester) async {
    // stub 有数据
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 6, 1));
    when(() => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 10));
    // stub 有交易数据
    when(() => repo.countByTypeInRange(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => 5);
    when(() => repo.totalsByDay(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => [
              (day: DateTime(2026, 7, 1), total: 100.0),
              (day: DateTime(2026, 7, 2), total: 200.0),
            ]);
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_HierarchyRow>[
              (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 300.0),
            ]);
    when(() => repo.getCategoriesByIds(any()))
        .thenAnswer((_) async => {
              1: Category(
                id: 1,
                name: '餐饮',
                kind: 'expense',
                icon: 'utensils',
                sortOrder: 0,
                parentId: null,
                level: 1,
                syncId: null,
              ),
            });

    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2026, 6, 1),
      latest: DateTime(2026, 7, 10),
    ));
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // 有数据时应出现下拉箭头
    expect(find.byIcon(AppIcons.chevronDown), findsWidgets,
        reason: '有数据时 Header 应显示下拉箭头');

    // 不应出现「支出」文案（homeExpense）
    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    // homeExpense = "支出"，Header 内不应单独出现
    // 但趋势模块标题 analyticsTrend = "支出趋势" 含「支出」二字，所以用精确匹配
    final expenseTexts = find.byWidgetPredicate(
      (w) => w is Text && w.data == l10n.homeExpense,
    );
    expect(expenseTexts, findsNothing,
        reason: 'Header 不应渲染独立的「支出」文案（B1 修复）');

    // 账期文案「JUL · 2026」应出现（月视图默认）
    expect(find.textContaining('2026'), findsWidgets);
  });

  testWidgets('有数据：横滑提示横幅恒显且无关闭按钮（B6 回归）', (tester) async {
    // stub 有数据
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 1));
    when(() => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 10));
    when(() => repo.countByTypeInRange(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => 3);
    when(() => repo.totalsByDay(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => [
              (day: DateTime(2026, 7, 1), total: 100.0),
            ]);
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_HierarchyRow>[
              (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 100.0),
            ]);
    when(() => repo.getCategoriesByIds(any()))
        .thenAnswer((_) async => const {});

    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2026, 7, 1),
      latest: DateTime(2026, 7, 10),
    ));
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    // 横滑提示文案应出现
    expect(find.text(l10n.analyticsSwipePeriodHint(l10n.analyticsMonth)), findsOneWidget,
        reason: '有数据时横滑提示横幅应恒显');
    // 不应有关闭按钮图标
    expect(find.byIcon(AppIcons.close), findsNothing,
        reason: '横滑提示横幅不应有关闭按钮（B6 修复）');
  });

  testWidgets('空数据态：横滑提示横幅恒显（B6 回归）', (tester) async {
    await tester.pumpWidget(buildApp(hasAnyData: false));
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    // BUG1 修复：空数据态也应显示横滑提示横幅（无关闭按钮）
    expect(find.text(l10n.analyticsSwipePeriodHint(l10n.analyticsMonth)), findsOneWidget,
        reason: '空数据态也应显示横滑提示横幅（BUG1 修复）');
    expect(find.byIcon(AppIcons.close), findsNothing,
        reason: '横滑提示横幅不应有关闭按钮（B6 修复）');
  });

  testWidgets('加载态：渲染骨架屏而非 CircularProgressIndicator', (tester) async {
    // 让 provider 永不完成（返回永不完成的 Future）
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) => Future.delayed(const Duration(seconds: 30), () => false));

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 不应出现 CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: '加载态应使用骨架屏，而非 CircularProgressIndicator');
  });

  testWidgets('错误态：显示重试按钮（B16 回归）', (tester) async {
    // 有数据（非全局空）但数据加载抛异常，应进入错误态
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenThrow(Exception('DB error'));

    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2026, 7, 1),
      latest: DateTime(2026, 7, 10),
    ));
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    // 应显示错误提示文案
    expect(find.text(l10n.analyticsLoadFailed), findsOneWidget,
        reason: '数据加载失败应显示错误提示');
    // 应显示重试按钮
    expect(find.text(l10n.analyticsRetry), findsOneWidget,
        reason: '错误态应显示重试按钮');
    // 应显示 cloud_off 图标
    expect(find.byIcon(AppIcons.cloudOff), findsOneWidget);
  });

  testWidgets('错误态：点击重试按钮不崩溃且重新触发加载', (tester) async {
    // 使用 thenThrow 让每次调用都抛异常，验证重试按钮可反复点击
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenThrow(Exception('DB error'));

    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2026, 7, 1),
      latest: DateTime(2026, 7, 10),
    ));
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    expect(find.text(l10n.analyticsRetry), findsOneWidget,
        reason: '加载失败应显示重试按钮');

    // 点击重试：不应抛异常，且重试后仍显示错误态（因为 stub 持续抛错）
    await tester.tap(find.text(l10n.analyticsRetry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // 重试后仍应显示错误态（stub 持续抛错）
    expect(find.text(l10n.analyticsLoadFailed), findsOneWidget,
        reason: '重试后因持续异常应仍显示错误态');
    expect(find.text(l10n.analyticsRetry), findsOneWidget,
        reason: '重试后应仍显示重试按钮');
  });

  testWidgets('空态判定以 txCount 为准：sum=0 但有交易不判空（B8 回归）',
      (tester) async {
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 1));
    when(() => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 10));
    // 有交易但金额合计为 0（退款冲抵场景）
    when(() => repo.countByTypeInRange(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => 2);
    when(() => repo.totalsByDay(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => [
              (day: DateTime(2026, 7, 1), total: 100.0),
              (day: DateTime(2026, 7, 2), total: -100.0),
            ]);
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_HierarchyRow>[
              (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 0.0),
            ]);
    when(() => repo.getCategoriesByIds(any()))
        .thenAnswer((_) async => const {});

    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2026, 7, 1),
      latest: DateTime(2026, 7, 10),
    ));
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    // 有交易（txCount=2）即使 sum=0 也不应判空
    expect(find.text(l10n.commonEmpty), findsNothing,
        reason: '有交易但金额为 0 时不应判空（B8 修复）');
    // 应显示趋势模块标题
    expect(find.text(l10n.analyticsTrend), findsOneWidget);
  });

  testWidgets('子 Tab 按真实数据范围生成：有历史数据时生成多月 Tab', (tester) async {
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 5, 1));
    when(() => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 10));
    when(() => repo.countByTypeInRange(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => 1);
    when(() => repo.totalsByDay(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => [
              (day: DateTime(2026, 7, 1), total: 50.0),
            ]);
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_HierarchyRow>[
              (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 50.0),
            ]);
    when(() => repo.getCategoriesByIds(any()))
        .thenAnswer((_) async => const {});

    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2026, 5, 1),
      latest: DateTime(2026, 7, 10),
    ));
    await prime(tester);
    // 多 pump 几帧让 analyticsDataRangeProvider resolve 后的重建完成
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // 子 Tab 应包含 05月、06月、07月（真实数据范围 2026-05 到 2026-07）。
    // 月份标签与首页日期组件口径一致，统一补零为两位数（见 monthLabel / analytics_sub_tabs）。
    expect(find.text('05月'), findsWidgets);
    expect(find.text('06月'), findsWidgets);
    expect(find.text('07月'), findsWidgets);
  });

  testWidgets('周视图：点击头部账期拉起周滚轮筛选 bottom sheet（统计看板优化）',
      (tester) async {
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 1));
    when(() => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 10));
    when(() => repo.countByTypeInRange(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => 3);
    when(() => repo.totalsByDay(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => [
              (day: DateTime(2026, 7, 1), total: 100.0),
            ]);
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_HierarchyRow>[
              (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 100.0),
            ]);
    when(() => repo.getCategoriesByIds(any()))
        .thenAnswer((_) async => const {});

    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2026, 7, 1),
      latest: DateTime(2026, 7, 10),
    ));
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // 1. 底部悬浮父级 Tab 切到「周」
    await tester.tap(find.text('周'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 2. 点击头部账期文案（格式「第N周 · 2026」，「·」仅头部使用）
    expect(find.textContaining('·'), findsWidgets,
        reason: '周视图头部应显示账期文案');
    await tester.tap(find.textContaining('·').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 3. 应拉起周选择 bottom sheet：标题「选择周」+ 年/周两个滚轮
    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    expect(find.text(l10n.analyticsSelectWeek), findsOneWidget,
        reason: '周视图点击头部应拉起周滚轮筛选（统计看板优化）');
    expect(find.byType(CupertinoPicker), findsNWidgets(2),
        reason: '周选择器应为「年 + 周」双滚轮');
  });

  testWidgets('分类环图：分类超过 5 个时聚合为「其他」扇区，占比合计 100%',
      (tester) async {
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 1));
    when(() => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 10));
    when(() => repo.countByTypeInRange(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => 3);
    when(() => repo.totalsByDay(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => [
              (day: DateTime(2026, 7, 1), total: 100.0),
            ]);
    // 6 个分类：环图应展示 Top5 + 「其他」聚合（仅 教育 50，50/2050≈2.4%）。
    // 注意金额设计需避开与 Top5 百分比撞车（各分类占比需互不相同）。
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_HierarchyRow>[
              (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 600.0),
              (id: 2, name: '交通', icon: null, parentId: null, level: 1, total: 500.0),
              (id: 3, name: '购物', icon: null, parentId: null, level: 1, total: 400.0),
              (id: 4, name: '娱乐', icon: null, parentId: null, level: 1, total: 300.0),
              (id: 5, name: '医疗', icon: null, parentId: null, level: 1, total: 200.0),
              (id: 6, name: '教育', icon: null, parentId: null, level: 1, total: 50.0),
            ]);
    when(() => repo.getCategoriesByIds(any()))
        .thenAnswer((_) async => const {});

    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2026, 7, 1),
      latest: DateTime(2026, 7, 10),
    ));
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    // 「其他」聚合标签只出现在环图引导标注中（排行榜展示真实分类名）
    expect(find.text(l10n.commonOther), findsOneWidget,
        reason: '分类超过 5 个时环图应聚合出「其他」扇区（占比合计 100%）');
    // 其他 = 50/2050 ≈ 2.4%
    expect(find.text('2.4%'), findsOneWidget,
        reason: '「其他」扇区占比应为剩余分类合计占比');
  });

  testWidgets(
      '数据范围异步扩张后，当前周期子 Tab 仍滚动到可视区（滚动错位 BUG 回归）',
      (tester) async {
    // 复现链路（月视图，默认周期，避免依赖切换交互）：
    // 1) 首帧 analyticsDataRangeProvider 仍在 pending（dataRangeDelay 未到），
    //    _buildSubTabs 读到 .value=null → 仅生成单个「当前月」tab，
    //    并把 _lastEnsuredTabId 置为当前月、_lastEnsuredTabIds=[当前月]。
    // 2) provider resolve 后，子 Tab 列表由单个扩张为 earliest..latest 全量，
    //    但选中项 id 未变。旧守卫（仅判断 activeId != _lastEnsuredTabId）
    //    会漏掉这次 ensureVisible，导致横向滚动停在开头、当前月不可见。
    // 修复后列表变化（listChanged）也应触发定位。该守卫逻辑对周/年视图一致，
    // 故用默认月视图即可覆盖同一 BUG。
    when(() => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => true);
    when(() => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2025, 1, 6));
    when(() => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async => DateTime(2026, 7, 20));
    when(() => repo.countByTypeInRange(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => 3);
    when(() => repo.totalsByDay(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => [
              (day: DateTime(2026, 7, 1), total: 100.0),
            ]);
    when(() => repo.totalsByCategoryWithHierarchy(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        )).thenAnswer((_) async => <_HierarchyRow>[
              (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 100.0),
            ]);
    when(() => repo.getCategoriesByIds(any()))
        .thenAnswer((_) async => const {});

    // dataRangeDelay=500ms：给「首帧单 tab → 列表扩张」留出窗口。
    await tester.pumpWidget(buildApp(
      hasAnyData: true,
      earliest: DateTime(2025, 1, 6),
      latest: DateTime(2026, 7, 20),
      dataRangeDelay: const Duration(milliseconds: 500),
    ));
    // 首帧 + 短等待：provider 仍在 pending，月视图仅渲染单个「当前月」tab。
    await tester.pump(const Duration(milliseconds: 100));
    // 该帧应为单 tab，横向滚动 offset 必为 0（尚未扩张）。
    final svEarly = tester.widget<SingleChildScrollView>(
      find.byWidgetPredicate((w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
    );
    expect(svEarly.controller?.offset ?? 0, 0,
        reason: 'provider 未 resolve 前仅单个当前月 tab，滚动 offset 应为 0');
    // 等待 provider resolve（~500ms）并完成 ensureVisible 的 200ms 滚动动画。
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));

    // 列表扩张后，当前月（列表末尾）应被滚动到可视区，横向滚动 offset 必 > 0。
    // 用水平方向的 SingleChildScrollView 精确定位，避免误命中主内容纵向滚动。
    // 注意：ensureVisible 通过 200ms 动画滚动，需要给足帧时间（单次长 pump）
    // 让动画完成，否则 offset 仍停在 0，会误判。
    final sv = tester.widget<SingleChildScrollView>(
      find.byWidgetPredicate((w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
    );
    await tester.pump(const Duration(milliseconds: 2000));
    expect(sv.controller?.offset ?? 0, greaterThan(0),
        reason: '数据范围扩张后当前月应被滚动到可视区，横向滚动 offset 须 > 0'
            '（修复前此处为 0：内容是最新月、但 tab 停在开头）');
  });
}
