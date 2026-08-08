/// AnalyticsPage 行为流测试（第二弹）：父级周期切换、回到当前周期、周期选择器、
/// 内容区横滑切账期、分类详情跳转、外币补折算横幅与脚注。
///
/// 第一弹（analytics_page_test.dart）覆盖空态/加载态/错误态/环图聚合等渲染分支；
/// 本文件补齐「用户切换周期与点击动作」引发的状态变化，避免交互分支与渲染分支
/// 混在同一文件里难以对照。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart' show Category;
import 'package:spitout/data/models.dart' show Ledger;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/analytics_page.dart';
import 'package:spitout/pages/transaction/category_detail_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/utils/date/week_math.dart';
import 'package:spitout/widgets/category_icon.dart';
import 'package:spitout/widgets/category_rank_row.dart';

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
    when(
      () => repo.hasAnyExpenseTx(ledgerId: any(named: 'ledgerId')),
    ).thenAnswer((_) async => true);
    when(
      () => repo.earliestExpenseDate(ledgerId: any(named: 'ledgerId')),
    ).thenAnswer((_) async => DateTime(2026, 6, 1));
    when(
      () => repo.latestExpenseDate(ledgerId: any(named: 'ledgerId')),
    ).thenAnswer((_) async => DateTime(2026, 7, 31));
    when(
      () => repo.getCategoriesByIds(any()),
    ).thenAnswer((_) async => const <int, Category>{});
    when(
      () => repo.getSharedSyntheticCategoriesForLedger(any()),
    ).thenAnswer((_) async => const <int, Category>{});
    when(
      () => repo.totalsByCategoryWithHierarchy(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => <_HierarchyRow>[]);
    when(
      () => repo.totalsByDay(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => <_DayPoint>[]);
    when(
      () => repo.totalsByMonth(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        year: any(named: 'year'),
      ),
    ).thenAnswer((_) async => <_MonthPoint>[]);
    when(
      () => repo.countByTypeInRange(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => 0);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    when(
      () => repo.getLedgerForeignCurrencies(any()),
    ).thenAnswer((_) async => const <String>{'USD'});
    when(
      () => repo.recomputeForeignTxForLedger(any()),
    ).thenAnswer((_) async => 2);
  });

  Widget buildApp({
    DateTime? earliest,
    DateTime? latest,
    DateTime? selectedMonth,
    String locale = 'zh',
    List<Override>? extraOverrides,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
        currentLedgerProvider.overrideWith(
          (ref) => Stream<Ledger?>.value(testLedger),
        ),
        currentMonthStartDayProvider.overrideWith((ref) => 1),
        selectedMonthProvider.overrideWithBuild(
          (ref, notifier) => selectedMonth ?? DateTime(2026, 7, 1),
        ),
        analyticsHasAnyExpenseProvider.overrideWith((ref) async => true),
        analyticsDataRangeProvider.overrideWith(
          (ref) async => (
            earliest: earliest ?? DateTime(2026, 6, 1),
            latest: latest ?? DateTime(2026, 7, 31),
          ),
        ),
        ...?extraOverrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(locale),
        home: const AnalyticsPage(),
      ),
    );
  }

  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// 通用「有数据」stub：日序列 + 分类 + 笔数。
  void stubMonthData({
    List<_DayPoint> days = const [],
    List<_HierarchyRow> cats = const [],
    int txCount = 5,
  }) {
    when(
      () => repo.totalsByDay(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => days);
    when(
      () => repo.totalsByCategoryWithHierarchy(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => cats);
    when(
      () => repo.countByTypeInRange(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => txCount);
  }

  testWidgets('月视图当前月：截断到今日、环比上月有对比值', (tester) async {
    final now = DateTime.now();
    stubMonthData(
      days: [
        (day: DateTime(now.year, now.month, 1), total: 100.0),
        (day: DateTime(now.year, now.month, 2), total: 200.0),
      ],
      cats: [
        (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 300.0),
      ],
    );
    when(() => repo.getCategoriesByIds(any())).thenAnswer(
      (_) async => {
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
      },
    );
    await tester.pumpWidget(
      buildApp(
        selectedMonth: DateTime(now.year, now.month, 1),
        earliest: DateTime(now.year, now.month, 1),
        latest: DateTime(now.year, now.month, 28),
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('环比上月'), findsOneWidget);
    expect(find.text('+0.0%'), findsOneWidget,
        reason: '当前月与上一月数据相同（stub 返回同一序列）时环比应为 0.0%');
    expect(find.text('总支出'), findsOneWidget);
    expect(find.text('回到本月'), findsNothing,
        reason: '当前月不应显示「回到本月」');
  });

  testWidgets('月视图非当前月：点击「回到本月」一键返回当前月', (tester) async {
    stubMonthData(
      days: [
        (day: DateTime(2026, 7, 1), total: 100.0),
      ],
      cats: [
        (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 100.0),
      ],
    );
    await tester.pumpWidget(
      buildApp(
        selectedMonth: DateTime(2026, 7, 1),
        earliest: DateTime(2026, 7, 1),
        latest: DateTime(2026, 7, 31),
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('回到本月'), findsOneWidget,
        reason: '非当前月应显示「回到本月」');
    await tester.tap(find.text('回到本月'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final now = DateTime.now();
    expect(
      find.textContaining('${now.month.toString().padLeft(2, '0')}月'),
      findsWidgets,
      reason: '点击后应切回当前月份账期',
    );
    expect(find.text('回到本月'), findsNothing);
  });

  testWidgets('年视图：当前年数据按月聚合、环比上年、子 Tab 标签', (tester) async {
    when(
      () => repo.totalsByMonth(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        year: any(named: 'year'),
      ),
    ).thenAnswer((invocation) async {
      final year = invocation.namedArguments[#year] as int;
      if (year == DateTime.now().year) {
        return [
          for (var m = 1; m <= 12; m++)
            (month: DateTime(year, m, 1), total: 100.0 * m),
        ];
      }
      return <_MonthPoint>[
        (month: DateTime(year, 1, 1), total: 50.0),
      ];
    });
    when(
      () => repo.totalsByCategoryWithHierarchy(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 100.0),
      ],
    );
    when(
      () => repo.countByTypeInRange(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => 12);

    await tester.pumpWidget(
      buildApp(
        earliest: DateTime(DateTime.now().year, 1, 1),
        latest: DateTime(DateTime.now().year, 12, 31),
      ),
    );
    await prime(tester);

    // 切换到年视图。
    await tester.tap(find.text('年'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final now = DateTime.now();
    expect(find.text('${now.year}年'), findsWidgets,
        reason: '年视图头部应显示「2026年」');
    expect(find.text('环比上年'), findsOneWidget);
    expect(find.textContaining('左右滑动列表切换年'), findsOneWidget,
        reason: '年视图横滑提示应使用「年」文案');
  });

  testWidgets('年视图非当年：点击过去年份子 Tab 后「回到今年」', (tester) async {
    when(
      () => repo.totalsByMonth(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        year: any(named: 'year'),
      ),
    ).thenAnswer(
      (_) async => <_MonthPoint>[
        (month: DateTime(2025, 1, 1), total: 10.0),
      ],
    );
    await tester.pumpWidget(
      buildApp(
        earliest: DateTime(2025, 1, 1),
        latest: DateTime(2025, 12, 31),
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('年'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // 点击 2025 年子 Tab。
    await tester.tap(find.text('2025年').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('回到今年'), findsOneWidget,
        reason: '非当年应显示「回到今年」');
    await tester.tap(find.text('回到今年'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('回到今年'), findsNothing);
  });

  testWidgets('周视图非本周：点击上周子 Tab 后「回到本周」', (tester) async {
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    when(
      () => repo.totalsByDay(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => <_DayPoint>[
        (day: lastMonday, total: 10.0),
        (day: thisMonday, total: 20.0),
      ],
    );
    when(
      () => repo.countByTypeInRange(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => 2);
    await tester.pumpWidget(
      buildApp(
        earliest: lastMonday,
        latest: thisMonday.add(const Duration(days: 6)),
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('周'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // 子 Tab 中应同时存在上周与本周边界；先点上周。
    final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsPage)));
    final lastWeekLabel = l10n.analyticsWeekN(
      weekNumber(lastMonday),
    );
    await tester.tap(find.text(lastWeekLabel).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('回到本周'), findsOneWidget,
        reason: '非本周应显示「回到本周」');
    await tester.tap(find.text('回到本周'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('回到本周'), findsNothing);
  });

  testWidgets('周期选择器：月视图点击头部拉起滚轮，取消/确认均不崩', (tester) async {
    stubMonthData(days: [(day: DateTime(2026, 7, 1), total: 10.0)]);
    await tester.pumpWidget(buildApp());
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // 点击头部账期 → ym 滚轮。
    final header = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains('07月'),
    );
    await tester.tap(header.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('选择账单月份'), findsOneWidget);

    // 不滚动直接确认 → 同月早退。
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 再次打开后点遮罩取消 → res==null 早退。
    await tester.tap(header.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(400, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AnalyticsPage), findsOneWidget);
  });

  testWidgets('年视图周期选择器：确认后保持选中年份', (tester) async {
    await tester.pumpWidget(
      buildApp(
        earliest: DateTime(DateTime.now().year, 1, 1),
        latest: DateTime(DateTime.now().year, 12, 31),
      ),
    );
    await prime(tester);
    await tester.tap(find.text('年'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final header = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains('年') && (w.data ?? '').length <= 6,
    );
    expect(header, findsWidgets);
    await tester.tap(header.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CupertinoPicker), findsWidgets);

    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AnalyticsPage), findsOneWidget);
  });

  testWidgets('周视图周期选择器：改选上周并确认 → 显示「回到本周」', (tester) async {
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    stubMonthData(
      days: [
        for (var i = 0; i < 7; i++)
          (day: thisMonday.add(Duration(days: i)), total: 10.0),
      ],
      txCount: 7,
    );
    await tester.pumpWidget(
      buildApp(
        earliest: thisMonday,
        latest: thisMonday.add(const Duration(days: 6)),
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('周'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // 点击头部拉起「年+周」双滚轮，周轮向上拖一格选中上周。
    final header = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains('第') && (w.data ?? '').contains('周'),
    );
    await tester.tap(header.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CupertinoPicker), findsNWidgets(2),
        reason: '周选择器应为「年+周」双滚轮');

    await tester.drag(find.byType(CupertinoPicker).at(1), const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('回到本周'), findsOneWidget,
        reason: '改选到上周后应显示「回到本周」');
  });

  testWidgets('内容区横滑：右滑切到上一账期、左滑切回', (tester) async {
    stubMonthData(
      days: [
        (day: DateTime(2026, 6, 1), total: 100.0),
        (day: DateTime(2026, 7, 1), total: 200.0),
      ],
      cats: [
        (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 300.0),
      ],
    );
    await tester.pumpWidget(
      buildApp(
        selectedMonth: DateTime(2026, 7, 1),
        earliest: DateTime(2026, 6, 1),
        latest: DateTime(2026, 7, 31),
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // 右滑（切上一账期）：07 → 06。
    await tester.fling(
      find.byType(ListView).last,
      const Offset(300, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.textContaining('06月'), findsWidgets,
        reason: '右滑应切到上一账期 06 月');

    // 左滑（切下一账期）：06 → 07。
    await tester.fling(
      find.byType(ListView).last,
      const Offset(-300, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.textContaining('07月'), findsWidgets,
        reason: '左滑应切回下一账期 07 月');
  });

  testWidgets('周视图点击分类图标：跳转分类详情页并生成周账期标签', (tester) async {
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    stubMonthData(
      days: [
        for (var i = 0; i < 7; i++)
          (day: thisMonday.add(Duration(days: i)), total: 10.0),
      ],
      cats: [
        (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 70.0),
      ],
      txCount: 7,
    );
    when(() => repo.getCategoriesByIds(any())).thenAnswer(
      (_) async => {
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
      },
    );
    await tester.pumpWidget(
      buildApp(
        earliest: thisMonday,
        latest: thisMonday.add(const Duration(days: 6)),
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('周'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final foodRow = find.descendant(
      of: find.byType(CategoryRankRow),
      matching: find.byType(CategoryIconWidget),
    );
    expect(foodRow, findsWidgets);
    await tester.tap(foodRow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CategoryDetailPage), findsOneWidget,
        reason: '周视图点击分类图标应进入分类详情页');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('年视图非当年：月序列完整渲染（不过滤）', (tester) async {
    when(
      () => repo.totalsByMonth(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        year: any(named: 'year'),
      ),
    ).thenAnswer((invocation) async {
      final year = invocation.namedArguments[#year] as int;
      if (year == 2025) {
        return [
          for (var m = 1; m <= 12; m++)
            (month: DateTime(2025, m, 1), total: 10.0 * m),
        ];
      }
      return <_MonthPoint>[];
    });
    when(
      () => repo.totalsByCategoryWithHierarchy(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => [
        (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 780.0),
      ],
    );
    when(
      () => repo.countByTypeInRange(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => 12);

    await tester.pumpWidget(
      buildApp(
        earliest: DateTime(2025, 1, 1),
        latest: DateTime(2025, 12, 31),
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('年'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('2025年').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('环比上年'), findsOneWidget);
    expect(find.text('回到今年'), findsOneWidget,
        reason: '2025 年为非当前年应显示「回到今年」');
  });

  testWidgets('点击分类排行行：跳转分类详情页并携带账期', (tester) async {
    stubMonthData(
      days: [(day: DateTime(2026, 7, 1), total: 100.0)],
      cats: [
        (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 100.0),
      ],
    );
    when(() => repo.getCategoriesByIds(any())).thenAnswer(
      (_) async => {
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
      },
    );
    await tester.pumpWidget(buildApp());
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // 分类排行在图表下方，先滚动到可视区让行构建出来。
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final foodRow = find.descendant(
      of: find.byType(CategoryRankRow),
      matching: find.byType(CategoryIconWidget),
    );
    expect(foodRow, findsWidgets, reason: '滚动后分类行应已构建');
    await tester.tap(foodRow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CategoryDetailPage), findsOneWidget,
        reason: '点击分类排行应进入分类详情页');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('分类层级：二级分类聚合到一级并展开明细', (tester) async {
    stubMonthData(
      days: [(day: DateTime(2026, 7, 1), total: 150.0)],
      cats: [
        (id: 1, name: '餐饮', icon: null, parentId: null, level: 1, total: 100.0),
        (id: 2, name: '火锅', icon: null, parentId: 1, level: 2, total: 50.0),
      ],
    );
    when(() => repo.getCategoriesByIds(any())).thenAnswer(
      (_) async => {
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
        2: Category(
          id: 2,
          name: '火锅',
          kind: 'expense',
          icon: 'flame',
          sortOrder: 1,
          parentId: 1,
          level: 2,
          syncId: null,
        ),
      },
    );
    await tester.pumpWidget(buildApp());
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // 滚动到分类排行区。
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.descendant(
      of: find.byType(CategoryRankRow),
      matching: find.text('餐饮'),
    ), findsWidgets);
    // 展开父分类后二级明细才可见。
    final rowTitle = find.descendant(
      of: find.byType(CategoryRankRow),
      matching: find.text('餐饮'),
    );
    await tester.tap(rowTitle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('火锅'), findsWidgets,
        reason: '二级分类应聚合到一级分类下并展示明细');
  });

  testWidgets('当前账期无交易：按 txCount==0 渲染空视图', (tester) async {
    stubMonthData(
      days: [(day: DateTime(2026, 7, 1), total: 0.0)],
      txCount: 0,
    );
    await tester.pumpWidget(buildApp());
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AnalyticsPage), findsOneWidget);
    expect(find.text('支出趋势'), findsOneWidget,
        reason: 'txCount==0 时仍应渲染完整空视图而非崩');
  });

  testWidgets('外币补折算：横幅 + 取消不折算 + 确认后折算并 toast', (tester) async {
    stubMonthData(days: [(day: DateTime(2026, 7, 1), total: 10.0)]);
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          ledgerUnconvertedForeignTxCountProvider.overrideWith((ref) async => 3),
        ],
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('检测到该账本有未折算的外币交易'), findsOneWidget);

    // 取消：不触发折算。
    await tester.tap(find.text('按当前汇率重算折算'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    verifyNever(() => repo.recomputeForeignTxForLedger(any()));

    // 确认：触发折算并弹 toast。
    await tester.tap(find.text('按当前汇率重算折算'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(() => repo.recomputeForeignTxForLedger(1)).called(1);
    expect(find.textContaining('已重算'), findsWidgets,
        reason: '折算成功应弹结果 toast');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('外币补折算失败：弹「操作失败」toast', (tester) async {
    stubMonthData(days: [(day: DateTime(2026, 7, 1), total: 10.0)]);
    when(
      () => repo.recomputeForeignTxForLedger(any()),
    ).thenThrow(StateError('recalc boom'));
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          ledgerUnconvertedForeignTxCountProvider.overrideWith((ref) async => 1),
        ],
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('按当前汇率重算折算'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('外币脚注：账本存在外币交易时显示已折算说明', (tester) async {
    stubMonthData(days: [(day: DateTime(2026, 7, 1), total: 10.0)]);
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          ledgerForeignTxCountProvider.overrideWith((ref) async => 1),
        ],
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('按'), findsWidgets);
    expect(find.byType(AnalyticsPage), findsOneWidget);
  });

}
