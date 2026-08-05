/// 首页（HomePage）组件测试。
///
/// 测试框架：flutter_test + flutter_riverpod + mocktail
///
/// 重点验证：左右滑切月的「日期错乱」bug 修复。
/// 修复前 _onPageScrollSettled 未防重入，jumpToPage 派发的 ScrollEndNotification
/// 会在 page 仍为 0/2 的瞬间重复触发切月，导致 selectedMonth 被连续偏移成
/// 离谱年份（1723 / -3127）。本测试通过模拟 fling + 多帧 pump，断言切月只发生一次。
///
/// 注意：相邻页 _MonthSkeleton 含 PulseSkeleton 持续动画，pumpAndSettle 会永久
/// 超时，故全部用分步 pump(Duration) 代替 pumpAndSettle，让物理模拟与 jumpToPage
/// 有足够帧数完成，又不被持续动画卡住。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/home_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/statistics/statistics_providers.dart';
// ledgerMembersProvider 用于构造共享账本成员列表的 override（回归 const {} 崩溃）。
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import 'package:spitout/providers/ui/ui_state_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/cloud/sync/sync_service.dart'
    show SyncService, LocalOnlySyncService, PullOutcome;
import 'package:spitout/providers/sync/sync_providers.dart'
    show syncServiceProvider;
import 'package:spitout/widgets/app_empty.dart';
import 'package:spitout/widgets/format_money.dart';
import 'package:spitout/widgets/primary_header.dart';

/// Mock 整个 BaseRepository：未 stub 的方法返回默认值（null/0/false），不抛异常。
/// 测试仅 stub HomePage 真正调用的 transactionsWithCategoryAll，其余 provider
/// 通过 ProviderScope.override 绕开，避免触碰 repository。
class _MockRepo extends Mock implements BaseRepository {}

/// Mock SyncService：用于注入云端同步成功/失败，验证下拉刷新结果文案走指示器而非 toast。
class _MockSyncService extends Mock implements SyncService {}

/// 轮询 pump 直到给定 Finder 命中（默认最多 ~5s 虚拟时间），用于消除异步刷新完成的时序抖动。
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (tester.elementList(finder).isNotEmpty) return;
  }
  throw Exception('pumpUntilFound: $finder 在超时内未出现');
}

typedef _TxItem = ({Transaction t, Category? category});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  // 非共享、自然月起始日的本地账本，避免触发 ledgerMembersProvider。
  late Ledger testLedger;
  // 交易流工厂：每次 _MonthPage 重建（切月后 key 变化）都会重新调用
  // repo.transactionsWithCategoryAll，必须返回全新 stream，否则单订阅流二次
  // listen 会抛「Stream has already been listened to」。
  late Stream<List<_TxItem>> Function() txsStreamFactory;

  /// 注册交易流工厂，便于各用例按需替换（如空列表 / 不发射的流）。
  void registerTxsStream(Stream<List<_TxItem>> Function() factory) {
    txsStreamFactory = factory;
  }

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
    // 默认每次返回发射空列表的新 stream：snapshot.hasData=true 且 monthItems
    // 为空 → AppEmpty（无持续动画，不阻塞 pump）。
    registerTxsStream(() => Stream<List<_TxItem>>.value(const []));
    when(
      () => repo.watchTransactionsWithCategoryInMonth(
        ledgerId: any(named: 'ledgerId'),
        month: any(named: 'month'),
      ),
    ).thenAnswer((_) => txsStreamFactory());
    // 下拉刷新会走 _runLocalRefresh:先由 currency_providers 读全部账本汇总本位币,
    // 再查未折算外币交易数决定是否补折算。二者未 stub 时 mocktail 返回 null,
    // 而返回类型是 Future<...>,await 处会抛类型错误并被 catch 成非致命告警,
    // 污染日志且让刷新路径无法干净走完。
    //
    // getAllLedgers 返回空列表:本位币集合为空 → 汇率刷新走「跳过拉取」分支,
    // 避免用例触发真实汇率 API 请求(本测试不覆盖汇率拉取)。
    // countUnconvertedForeignTx 返回 0:无未折算外币交易 → 不进补折算分支。
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    when(
      () => repo.countUnconvertedForeignTx(any()),
    ).thenAnswer((_) async => 0);
  });

  /// 构建带 overrides 的测试宿主，selectedMonth 初始值可定制。
  /// [extraOverrides] 用于注入额外 provider override（如共享账本成员列表）。
  /// [currentLedgerOverride] 可替换默认的 currentLedgerProvider override
  /// （例如用 StreamController 驱动，便于在测试中再发一次账本对象触发 rebuild）。
  Widget buildApp({
    DateTime? initialMonth,
    List<Override>? extraOverrides,
    Override? currentLedgerOverride,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
        currentLedgerOverride ??
            currentLedgerProvider.overrideWith(
              (ref) => Stream<Ledger?>.value(testLedger),
            ),
        // 自然月起始日，避免 periodForLabel 跨月带来的过滤复杂度。
        currentMonthStartDayProvider.overrideWith((ref) => 1),
        // 统计类 provider 直接给固定值，绕开 repo 调用。
        monthlyTotalsProvider.overrideWith((ref, params) async => 0.0),
        todayExpenseProvider.overrideWith((ref, ledgerId) async => 0.0),
        weekExpenseProvider.overrideWith((ref, ledgerId) async => 0.0),
        // 切月测试需要可控的初始月份（不依赖 DateTime.now）。
        selectedMonthProvider.overrideWithBuild(
          (ref, notifier) => initialMonth ?? DateTime(2026, 7, 1),
        ),
        ...?extraOverrides,
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
        home: const HomePage(),
      ),
    );
  }

  /// 取得当前 ProviderContainer，用于读写 selectedMonthProvider 断言切月结果。
  ProviderContainer containerOf(WidgetTester tester) {
    return ProviderScope.containerOf(tester.element(find.byType(HomePage)));
  }

  /// 分步 pump：让初始 async provider / stream 完成首帧渲染。
  /// 不用 pumpAndSettle —— 相邻页骨架屏的 PulseSkeleton 是持续动画会永久超时。
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// fling 后分步 pump：给物理模拟 + ScrollEndNotification + _onPageScrollSettled
  /// + jumpToPage + 下一帧解锁留足帧数。pumpAndSettle 会因相邻页 PulseSkeleton
  /// 持续动画永久超时，故用固定时长分步 pump。
  Future<void> settleSwipe(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('首页正常渲染：PageView 与日期头存在', (tester) async {
    await tester.pumpWidget(buildApp());
    await prime(tester);

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(AppIcons.chevronDown), findsWidgets);
  });

  testWidgets('手指向左滑切下月：selectedMonth 仅加 1，不会被重复偏移到离谱年份（bug1 回归）', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 7, 1)));
    await prime(tester);

    expect(
      containerOf(tester).read(selectedMonthProvider),
      DateTime(2026, 7, 1),
    );

    // 手指向左 fling > 80% 屏宽：内容左移、pixels 增大、frac>=0.8 → page 2（下月）。
    // fling 带惯性，比 drag 更易越过 80% 阈值触发翻页。
    await tester.fling(find.byType(PageView), const Offset(-700, 0), 4000);
    await settleSwipe(tester);
    // 额外 pump 几帧，确认防重入锁解锁后不会再次误切月。
    await tester.pump(const Duration(milliseconds: 200));

    final after = containerOf(tester).read(selectedMonthProvider);
    // 核心断言：只切一个月到 2026-08，而不是被连续偏移到离谱年份。
    expect(after, DateTime(2026, 8, 1), reason: '滑动一次应仅切一个月，修复前会因重入循环偏移到离谱年份');
  });

  testWidgets('手指向右滑切上月：selectedMonth 减 1', (tester) async {
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 7, 1)));
    await prime(tester);

    // 手指向右 fling > 80% 屏宽：内容右移、pixels 减小、frac<=-0.8 → page 0（上月）。
    await tester.fling(find.byType(PageView), const Offset(700, 0), 4000);
    await settleSwipe(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      containerOf(tester).read(selectedMonthProvider),
      DateTime(2026, 6, 1),
    );
  });

  testWidgets('拖动未达 80% 阈值回弹：selectedMonth 不变（不误切月）', (tester) async {
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 7, 1)));
    await prime(tester);

    // 极慢拖动 200px（< 80% 屏宽 640），松手 velocity≈100px/s 极小，
    // ClampingScrollPhysics 摩擦减速的惯性增量不足以越过 80% 阈值，
    // 惯性结束后 page 仍≈1（中页），_onPageScrollSettled 不切月。
    // 注：PageView 的 _ForceImplicitScrollPhysics 会使 _HighThresholdPagePhysics
    // 的 createBallisticSimulation 失效，松手后走 ClampingScrollPhysics 摩擦减速，
    // 故需用极慢拖动确保惯性不越界。
    await tester.timedDrag(
      find.byType(PageView),
      const Offset(-200, 0),
      const Duration(milliseconds: 2000),
    );
    await settleSwipe(tester);

    expect(
      containerOf(tester).read(selectedMonthProvider),
      DateTime(2026, 7, 1),
      reason: '未达阈值应回弹中页，不切月',
    );
  });

  testWidgets('连续向左滑两次：selectedMonth 递增两次，每次仅加 1（防重入 + 串行切月）', (tester) async {
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 7, 1)));
    await prime(tester);

    // 第一次 → 2026-08。
    await tester.fling(find.byType(PageView), const Offset(-700, 0), 4000);
    await settleSwipe(tester);
    expect(
      containerOf(tester).read(selectedMonthProvider),
      DateTime(2026, 8, 1),
    );

    // 第二次 → 2026-09。
    await tester.fling(find.byType(PageView), const Offset(-700, 0), 4000);
    await settleSwipe(tester);
    expect(
      containerOf(tester).read(selectedMonthProvider),
      DateTime(2026, 9, 1),
    );
  });

  testWidgets('回到当月按钮：点击后 selectedMonth 回到当前自然月（bug3 回归）', (tester) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 1, 1)));
    await prime(tester);

    final ctx = tester.element(find.byType(HomePage));
    final l10n = AppLocalizations.of(ctx);
    final backToCurrentFinder = find.text(l10n.homeBackToCurrentMonth);
    expect(backToCurrentFinder, findsOneWidget, reason: '非当月时应展示「回到当月」按钮');

    await tester.tap(backToCurrentFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      containerOf(tester).read(selectedMonthProvider),
      currentMonth,
      reason: '点击回到当月后 selectedMonth 应等于当前自然月',
    );
  });

  testWidgets('空数据状态：stream 发射空列表时显示空状态占位（AppEmpty）', (tester) async {
    registerTxsStream(() => Stream<List<_TxItem>>.value(const []));
    await tester.pumpWidget(buildApp());
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    expect(find.text(l10n.homeNoRecords), findsOneWidget);
  });

  testWidgets('MonthPickerSheet 初始定位与 selectedMonth 一致（bug2 回归）', (
    tester,
  ) async {
    // 选中月为正常值 2026-07，点开 picker 后滚轮应定位到 2026 / 07，
    // 不应出现 clamp 到 2000 的错位（错位只在 selectedMonth.year<2000 时发生）。
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 7, 1)));
    await prime(tester);

    // 定位日期头：含 '2026' 的 Text 即 _DateHeader 文本。
    final dateHeaderFinder = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains('2026'),
    );
    expect(dateHeaderFinder, findsOneWidget);

    await tester.tap(dateHeaderFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 月份选择器弹出后，CupertinoPicker 渲染可见项，选中项位于中央。
    // 月份项由 formatter 渲染为纯数字（7 月 → "7"，非 "07"），与真实组件一致。
    expect(find.text('2026'), findsWidgets);
    expect(
      find.text('7'),
      findsWidgets,
      reason: 'ym 滚轮应渲染选中月 7 月；错位（year<2000 时 clamp 到 2000）会导致月份项不对',
    );
    // 日期头回显应同步为「07月 · 2026年」，进一步确认选中月定位到 July 2026。
    // 注意：homeMonth/homeYear 组合成单个 Text 控件，需断言完整串而非片段。
    expect(
      find.text('07月 · 2026年'),
      findsWidgets,
      reason: '日期头应回显选中月 07 月，验证 picker 初始定位与 selectedMonth 一致',
    );
  });

  testWidgets('selectedMonth 不会出现负数/远古年份（bug4 极端值回归）', (tester) async {
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 7, 1)));
    await prime(tester);

    // 连续多次向左 fling（切下月），验证年份始终合理（不会出现 -3127 / 1723 等）。
    for (var i = 0; i < 5; i++) {
      await tester.fling(find.byType(PageView), const Offset(-700, 0), 4000);
      await settleSwipe(tester);
    }
    final after = containerOf(tester).read(selectedMonthProvider);
    // 5 次向左滑应到 2026-12，年份必须 > 2000 且为正。
    expect(after, DateTime(2026, 12, 1));
    expect(after.year, greaterThan(2000), reason: '滑动切月不应产生远古/负数年份');
  });

  // ==================== 汇总卡今日/本周行（切月高度固定） ====================

  group('汇总卡今日/本周行（卡片高度固定）', () {
    testWidgets('非当月：今日/本周行常驻不隐藏，金额以 "-" 占位', (tester) async {
      // 取去年同月，保证无论真实当前月为何都稳定命中"非当月"分支
      final now = DateTime.now();
      final nonCurrent = DateTime(now.year - 1, now.month, 1);
      await tester.pumpWidget(buildApp(initialMonth: nonCurrent));
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      // 重构后今日/本周行由 Row(标签 + 金额 + 分隔符)组成,不再是一个拼接字符串。
      // 非当月金额位以 '-' 占位:今日/本周各一个 '-',中间用 '·'/'|' 分隔。
      expect(
        find.text(l10n.homeTodayExpense),
        findsOneWidget,
        reason: '非当月今日标签常驻',
      );
      expect(
        find.text(l10n.homeWeekExpense),
        findsOneWidget,
        reason: '非当月本周标签常驻',
      );
      expect(
        find.text('-'),
        findsNWidgets(2),
        reason: '非当月今日/本周金额以 "-" 占位,保证切页卡片高度固定',
      );
      expect(find.text('·'), findsNWidgets(2));
      expect(find.text('|'), findsOneWidget);
    });

    testWidgets('当月：今日/本周行显示真实金额（0 直接显示 0，无 + 号）', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        buildApp(initialMonth: DateTime(now.year, now.month, 1)),
      );
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      // provider 固定 0.0 → 金额由 AmountText 渲染,与卡片主金额同源(均走
      // formatMoneyWithCurrency),避免脆断。下面分别断言标签与金额位。
      final zero = formatMoneyWithCurrency(
        0.0,
        currencyCode: testLedger.currency,
      );
      expect(
        find.text(l10n.homeTodayExpense),
        findsOneWidget,
        reason: '当月今日标签常驻',
      );
      expect(
        find.text(l10n.homeWeekExpense),
        findsOneWidget,
        reason: '当月本周标签常驻',
      );
      // 金额位渲染 zero(主金额 + 今日 + 本周 共 3 处),证明复用 AmountText 而非拼接字符串。
      expect(
        find.text(zero),
        findsWidgets,
        reason: '当月今日/本周显示真实金额（测试 provider 固定 0.0）',
      );
      // 当月不应出现非当月占位符 '-'。
      expect(find.text('-'), findsNothing, reason: '当月金额应为真实数值,不出现 "-" 占位');
    });
  });

  // ==================== 首页头部布局（Figma 53:6 回归） ====================
  // 验证头部按 UI 稿重排：首行「日期 + 刷新」同行、日历入口已迁至底部导航栏
  // （首页头部不再渲染日历本按钮）、轻扫提示移到汇总卡下方并左缩进 16、账本徽章
  // 以 tab 挂在卡片右缘。防止后续提交误改回旧布局。
  // 旧布局。Padding 值用 byWidgetPredicate + ancestor 限定作用域，避免依赖
  // 私有组件类型，断言稳定且可读。
  group('首页头部布局（Figma 53:6）', () {
    testWidgets('首页首行由 PrimaryHeader 渲染且使用全局默认留白（上/下 10、左/右 14）', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 首行已收敛到全局统一头部组件：留白规范（上/下 10、左/右 14）由组件默认值承载，
      // 页面侧不再手写 SafeArea/Padding 首行，防止后续提交回退到手写头部。
      final headerFinder = find.byType(PrimaryHeader);
      expect(headerFinder, findsOneWidget, reason: '首页首行应由 PrimaryHeader 渲染');
      final header = tester.widget<PrimaryHeader>(headerFinder);
      expect(
        header.padding,
        const EdgeInsets.only(top: 10, left: 14, right: 14, bottom: 0),
        reason: '首行留白应使用 PrimaryHeader 全局默认（上 10、下 0、左/右 14）',
      );
      expect(
        header.onTitleTap,
        isNotNull,
        reason: '月份标题应可点击拉起日期滚轮（onTitleTap 接线）',
      );
    });

    testWidgets('月份标题在 PrimaryHeader 内渲染（单行「月·年」格式）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 标题文本形如 "07月 · 2026年"，应作为 PrimaryHeader 的 title 渲染。
      final dateTextFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('2026'),
      );
      expect(dateTextFinder, findsOneWidget);
      expect(
        find.ancestor(of: dateTextFinder, matching: find.byType(PrimaryHeader)),
        findsOneWidget,
        reason: '月份标题应渲染在 PrimaryHeader 内（原 _DateHeader 已收敛）',
      );
    });

    testWidgets('首页头部不再渲染日历本按钮（入口已迁至底部导航栏）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      // 日历入口已统一收敛到底部导航栏，首页头部首行右侧不应再出现「日历本」按钮。
      expect(
        find.text(l10n.calendarTitle),
        findsNothing,
        reason: '首页头部不应再出现日历本按钮（入口已迁至底部导航栏）',
      );

      // 日期头仍正常渲染在首行，保证头部主体未被误删。
      final dateTextFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('2026'),
      );
      expect(dateTextFinder, findsOneWidget, reason: '日期头应仍正常渲染');
    });

    testWidgets('轻扫提示行位于日期头与汇总卡之间，左缘距 14', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        buildApp(initialMonth: DateTime(now.year, now.month, 1)),
      );
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      final hintFinder = find.text(l10n.homeSwitchMonthHint);
      final cardTitleFinder = find.text(l10n.homeMonthExpense);
      expect(hintFinder, findsOneWidget);
      expect(cardTitleFinder, findsOneWidget);

      // UI稿：轻扫提示上移到「日期组件(首行)与汇总卡之间」，填充原空隙，
      // 因此其纵向位置应在汇总卡（本月支出）标题之上。
      expect(
        tester.getCenter(hintFinder).dy,
        lessThan(tester.getCenter(cardTitleFinder).dy),
        reason: '轻扫提示应位于日期头与汇总卡之间（在汇总卡上方）',
      );

      // UI稿：提示行左缘距左 14，与 PrimaryHeader 日期标题左边缘对齐（见 home_page.dart
      // 中 SwipeHint 的 padding: EdgeInsets.only(left: 14, bottom: 8)），下方留 8 接卡片。
      expect(
        find.ancestor(
          of: hintFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Padding &&
                w.padding == const EdgeInsets.only(left: 14, bottom: 8),
          ),
        ),
        findsOneWidget,
        reason: '轻扫提示行 Padding 应为 left:14, bottom:8（对齐日期标题）',
      );
    });

    testWidgets('汇总卡内边距为 all(20)，账本徽章以 tab 挂在卡片右缘', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        buildApp(initialMonth: DateTime(now.year, now.month, 1)),
      );
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      final cardTitleFinder = find.text(l10n.homeMonthExpense);

      // 汇总卡内容内边距四边 20（限定在标题文本的祖先链上断言）。
      expect(
        find.ancestor(
          of: cardTitleFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding == const EdgeInsets.all(20),
          ),
        ),
        findsOneWidget,
        reason: '汇总卡内边距应为 all(20)',
      );

      // 账本徽章 tab：账本名位于右半屏（贴卡片右缘），且与标题行纵向齐平。
      final badgeFinder = find.text(testLedger.name);
      expect(badgeFinder, findsOneWidget);
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        tester.getCenter(badgeFinder).dx,
        greaterThan(screenWidth / 2),
        reason: '账本徽章应贴在卡片右缘（右半屏）',
      );
      final dyDiff =
          (tester.getCenter(badgeFinder).dy -
                  tester.getCenter(cardTitleFinder).dy)
              .abs();
      expect(dyDiff, lessThan(16), reason: '账本徽章应与标题行纵向齐平');
    });

    testWidgets('非当月：「回到当月」位于日期组件右侧、与日期头同行', (tester) async {
      final now = DateTime.now();
      final nonCurrent = DateTime(now.year - 1, now.month, 1);
      await tester.pumpWidget(buildApp(initialMonth: nonCurrent));
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      final backFinder = find.text(l10n.homeBackToCurrentMonth);
      // 日期头文本形如 "01月 · 2025年"，用年份+"年"定位首行日期组件。
      final dateFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('${nonCurrent.year}年'),
      );
      expect(backFinder, findsOneWidget, reason: '非当月时应展示「回到当月」按钮');
      expect(dateFinder, findsWidgets, reason: '日期头应正常渲染');
      // 「回到当月」与日期头同处首行，纵向大致对齐（行高 40，放宽到 12 容差）。
      expect(
        (tester.getCenter(backFinder).dy -
                tester.getCenter(dateFinder.first).dy)
            .abs(),
        lessThan(12),
        reason: '回到当月应与日期头位于同一行',
      );
      // 且位于日期组件右侧
      expect(
        tester.getCenter(backFinder).dx,
        greaterThan(tester.getCenter(dateFinder.first).dx),
      );
    });
  });

  // ==================== 共享账本灰屏回归（交易流缓存） ====================
  testWidgets('共享账本：账本信息变化触发 _MonthPage rebuild 时不重建交易流（灰屏回归）', (tester) async {
    // 共享账本：isShared=true 且有 syncId，模拟多人协作账本。
    testLedger = Ledger(
      id: 1,
      name: '测试共享账本',
      currency: 'CNY',
      type: 'shared',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 2,
      isShared: true,
      monthStartDay: 1,
      syncId: 'sync-1',
      storageMode: 'cloud',
      aaEnabled: false,
    );

    // 用 StreamController 驱动 currentLedgerProvider，便于在测试中再发一次
    // 「不同」的账本对象，触发 _MonthPage rebuild（模拟「账本信息被其他端编辑后同步」）。
    final ledgerCtrl = StreamController<Ledger?>.broadcast();

    // 追踪交易流工厂被调用的次数：bug 根因是每次 build 都重建流，
    // 导致 StreamBuilder 重新订阅、首帧 snapshot.data 短暂为 null → 渲染
    // _MonthSkeleton（灰色长方块）。修复后流应被缓存到 _MonthPageState，
    // 仅在 initState / 切月切账本时创建一次。
    var txStreamCallCount = 0;
    when(
      () => repo.watchTransactionsWithCategoryInMonth(
        ledgerId: any(named: 'ledgerId'),
        month: any(named: 'month'),
      ),
    ).thenAnswer((_) {
      txStreamCallCount++;
      return Stream<List<_TxItem>>.value(const []);
    });

    await tester.pumpWidget(
      buildApp(
        currentLedgerOverride: currentLedgerProvider.overrideWith(
          (ref) => ledgerCtrl.stream,
        ),
      ),
    );
    await prime(tester);

    // 首帧渲染后，交易流应至少被创建一次（initState 或首次 build）。
    final countAfterPrime = txStreamCallCount;
    expect(
      countAfterPrime,
      greaterThanOrEqualTo(1),
      reason: '进入首页后交易流应至少被创建一次',
    );

    // 再发一个「不同」账本对象（字段变化确保 AsyncValue 变化、_MonthPage 真正 rebuild）。
    // 修复前：rebuild 会重新执行 widget.getStream() → 交易流被再次创建；
    // 修复后：_txStream 缓存引用不变 → 不重建。
    ledgerCtrl.add(testLedger.copyWith(memberCount: 9));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // 核心断言：账本信息变化导致的 rebuild 不应再次创建交易流。
    expect(
      txStreamCallCount,
      countAfterPrime,
      reason:
          'currentLedgerProvider 变化触发 _MonthPage rebuild 时不应重建交易流'
          '（getStream 只在 initState / 切月切账本时调用一次）。'
          '修复前每次 build 都新建流，StreamBuilder 重新订阅会短暂返回 null，'
          '首页渲染出灰色骨架屏。',
    );

    await ledgerCtrl.close();
  });

  // ==================== 共享账本带成员主页渲染（const {} 崩溃回归） ====================
  testWidgets('共享账本带成员时首页渲染不崩溃（const {} 不可变 Map 写入崩溃回归）', (tester) async {
    // 复现场景：共享账本(isShared=true + syncId)且有真实成员列表。
    // 修复前 _MonthPage.build 用 const {} 作 fold 种子 → 回调 m[mem.userId]=...
    // 写入不可变 Map → 抛 UnsupportedError。该分支仅在「成员列表非空」时执行，
    // 故此前「共享账本 + 有成员」进入首页即崩。这里 override ledgerMembersProvider
    // 返回非空成员，覆盖崩溃路径；交易流为空（无数据骨架屏）不影响 fold 执行。
    testLedger = Ledger(
      id: 1,
      name: '测试共享账本',
      currency: 'CNY',
      type: 'shared',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 2,
      isShared: true,
      monthStartDay: 1,
      syncId: 'sync-1',
      storageMode: 'cloud',
      aaEnabled: false,
    );

    final members = <SpitoutCloudLedgerMember>[
      SpitoutCloudLedgerMember(
        userId: 'user-001',
        email: 'alice@example.com',
        role: 'owner',
        joinedAt: DateTime(2024, 1, 1),
        isSelf: true,
        displayName: '小明',
      ),
      SpitoutCloudLedgerMember(
        userId: 'user-002',
        email: 'bob@example.com',
        role: 'editor',
        joinedAt: DateTime(2024, 1, 2),
        isSelf: false,
        displayName: '小红',
      ),
    ];

    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          // 关键：返回「非空」成员列表，触发原本会崩溃的 fold 写入路径。
          ledgerMembersProvider.overrideWith(
            (ref, ledgerId) => Future.value(members),
          ),
        ],
      ),
    );
    await prime(tester);
    // 多 pump 几帧，确保 ledgerMembersProvider 的 Future 数据到达并完成 rebuild。
    await tester.pump(const Duration(milliseconds: 100));

    // 若 const {} 问题复现，ledgerMembersProvider 数据到达后的 rebuild 会在
    // fold 写入时抛 UnsupportedError，pump 会直接失败。此断言即回归信号。
    expect(find.byType(HomePage), findsOneWidget);
  });

  // ==================== 下拉刷新：结果在指示器内展示（不再弹 toast） ====================
  /// 通过下发 [ScrollNotification] 模拟"从顶部下拉"手势触发下拉刷新，
  /// 避免依赖真实可滚动内容的手势识别（测试账本数据为空、无内部滚动视图）。
  ///
  /// 设计意图：HomePage 的下拉手势处理读取的是 [ScrollNotification.metrics.pixels]
  /// (列表顶部 overscroll，负值表示向下拉)，而非 dragDetails。因此这里直接构造
  /// 递减(更负)的 pixels 来模拟下拉，累计越过 _kRefreshThreshold(48px) 触发刷新。
  Future<void> pullToRefresh(WidgetTester tester) async {
    // 从内部空状态占位(AppEmpty)派发：它是 PageView 内部更深层的组件，
    // 因此冒泡到首页 NotificationListener 时 depth>0，命中"内部列表下拉"分支；
    // 若直接对 PageView 派发，depth==0 会被当成 PageView 自身横向滚动而忽略。
    final ctx = tester.element(find.byType(AppEmpty));
    // 固定滚动指标：仅用于构造合法的 ScrollNotification。
    FixedScrollMetrics metricsAt(double pixels) => FixedScrollMetrics(
      minScrollExtent: -200,
      maxScrollExtent: 100,
      pixels: pixels,
      viewportDimension: 100,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );
    // 分步下发：pixels 递减(更负) → 累计下拉偏移越过 48px 阈值。
    for (var i = 1; i <= 4; i++) {
      // 手动向子树派发 ScrollNotification，使其冒泡到 HomePage 的 NotificationListener
      // （tester 无 dispatchNotification API，改用 Notification.dispatch(element)）。
      ScrollUpdateNotification(
        metrics: metricsAt(-16.0 * i),
        context: ctx,
      ).dispatch(ctx);
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 松手 → 触发 _handlePullEnd → 偏移达标 → 进入 _onRefresh。
    ScrollEndNotification(metrics: metricsAt(-64), context: ctx).dispatch(ctx);
    await tester.pump(const Duration(milliseconds: 16));
  }

  group('首页下拉刷新：结果文案在指示器内展示，不再弹 toast（需求回归）', () {
    testWidgets('纯本地账本：刷新成功 → 指示器显示"已刷新本地账本数据与配置"且全局仅一处（无 toast）', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          extraOverrides: [
            // LocalOnly 同步器：pullIncrementalWithHeal 抛 UnsupportedError → 走纯本地刷新。
            syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
          ],
        ),
      );
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      // 触发下拉刷新。
      await pullToRefresh(tester);
      // 等待结果文案出现（消除时序抖动；文案出现即代表刷新完成）。
      final resultFinder = find.text(l10n.homePullLocalSuccess);
      await pumpUntilFound(tester, resultFinder);

      // 核心断言：结果文案出现在指示器内，且全局仅出现一次 → 证明没有额外的 toast 弹窗。
      expect(
        resultFinder,
        findsOneWidget,
        reason: '刷新成功文案应仅在指示器内出现一次；若出现两次则说明仍弹了 toast',
      );
      // 刷新完成后"正在同步"常驻文案应已被结果文案替换（同一 Text 控件，二选一）。
      expect(
        find.text(l10n.homeSyncing),
        findsNothing,
        reason: '刷新完成后指示器应切换为结果文案，不再显示"正在同步"',
      );
      // 冲刷日志 2s 写入计时器与本功能 1s 收起计时器，避免 FakeAsync 报挂起定时器。
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('云端账本：同步成功 → 指示器显示"已同步云端账本数据"且无 toast', (tester) async {
      final mock = _MockSyncService();
      when(
        () => mock.pullIncrementalWithHeal(ledgerId: any(named: 'ledgerId')),
      ).thenAnswer((_) async => const PullOutcome(incremental: 1));
      await tester.pumpWidget(
        buildApp(
          extraOverrides: [syncServiceProvider.overrideWith((ref) => mock)],
        ),
      );
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      await pullToRefresh(tester);
      final resultFinder = find.text(l10n.homePullCloudSuccess);
      await pumpUntilFound(tester, resultFinder);

      expect(
        resultFinder,
        findsOneWidget,
        reason: '云端同步成功文案应仅在指示器内出现一次（无 toast）',
      );
      // 验证确实走了云端同步路径（而非降级本地）。
      verify(() => mock.pullIncrementalWithHeal(ledgerId: 1)).called(1);
      // 冲刷计时器。
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('云端账本：同步失败但本地已刷新 → 指示器显示降级文案且无 toast', (tester) async {
      final mock = _MockSyncService();
      when(
        () => mock.pullIncrementalWithHeal(ledgerId: any(named: 'ledgerId')),
      ).thenThrow(Exception('network error'));
      await tester.pumpWidget(
        buildApp(
          extraOverrides: [syncServiceProvider.overrideWith((ref) => mock)],
        ),
      );
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      await pullToRefresh(tester);
      // 云端抛非 UnsupportedError → isCloud=true, cloudOk=false → 降级本地刷新成功
      // → 结果文案为 homePullCloudFailedButLocalOk。
      final resultFinder = find.text(l10n.homePullCloudFailedButLocalOk);
      await pumpUntilFound(tester, resultFinder);
      expect(
        resultFinder,
        findsOneWidget,
        reason: '云端失败但本地已刷新时，应显示降级文案且无 toast',
      );
      // 冲刷计时器。
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('结果文案停留约 1 秒后指示器收起（不再立即收起）', (tester) async {
      await tester.pumpWidget(
        buildApp(
          extraOverrides: [
            syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
          ],
        ),
      );
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      await pullToRefresh(tester);
      final resultFinder = find.text(l10n.homePullLocalSuccess);
      await pumpUntilFound(tester, resultFinder);

      // 结果展示阶段：指示器应处于全高（SizeTransition.sizeFactor≈1，未收起）。
      // 用刷新 icon 定位指示器（文案归零后 resultFinder 会失效，icon 稳定）。
      final visibleIndicator = tester.widget<SizeTransition>(
        find
            .ancestor(
              of: find.byIcon(AppIcons.refresh),
              matching: find.byType(SizeTransition),
            )
            .first,
      );
      expect(
        visibleIndicator.sizeFactor.value,
        closeTo(1.0, 0.1),
        reason: '结果展示期间指示器应保持全高（sizeFactor≈1，未立即收起）',
      );

      // 超过 1 秒后：延时收起计时器触发，指示器平滑收起（sizeFactor≈0）。
      // 轮询等待收起，容忍动画/计时器时序抖动（最多 ~3s 虚拟时间）。
      SizeTransition? collapsedIndicator;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final ind = tester.widget<SizeTransition>(
          find
              .ancestor(
                of: find.byIcon(AppIcons.refresh),
                matching: find.byType(SizeTransition),
              )
              .first,
        );
        if (ind.sizeFactor.value < 0.1) {
          collapsedIndicator = ind;
          break;
        }
      }
      expect(
        collapsedIndicator,
        isNotNull,
        reason: '结果停留 1 秒后指示器应平滑收起（sizeFactor≈0）；若不为 null 说明收起计时器未触发',
      );
      expect(
        collapsedIndicator!.sizeFactor.value,
        closeTo(0.0, 0.1),
        reason: '结果停留 1 秒后指示器应平滑收起（sizeFactor≈0）',
      );
      // 冲刷日志 2s 计时器，避免 FakeAsync 报挂起定时器。
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('收起完成后结果文案归零：下次下拉即从"正在同步"开始，不残留上次结果', (tester) async {
      final mock = _MockSyncService();
      when(
        () => mock.pullIncrementalWithHeal(ledgerId: any(named: 'ledgerId')),
      ).thenAnswer((_) async => const PullOutcome(incremental: 1));
      await tester.pumpWidget(
        buildApp(
          extraOverrides: [syncServiceProvider.overrideWith((ref) => mock)],
        ),
      );
      await prime(tester);

      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
      // 第一次刷新：云端成功 → 结果文案为 homePullCloudSuccess。
      await pullToRefresh(tester);
      await pumpUntilFound(tester, find.text(l10n.homePullCloudSuccess));

      // 刷新期间指示器应显示结果文案（非"正在同步"）。
      expect(
        find.text(l10n.homeSyncing),
        findsNothing,
        reason: '刷新结果展示阶段应显示结果文案，而非"正在同步"',
      );

      // 等待结果停留 1 秒 + 收起动画完成 + 文案归零。轮询等待 homeSyncing 出现
      // （归零后指示器文案回到"正在同步"），避免固定时长对 collapse 动画时序敏感。
      await pumpUntilFound(tester, find.text(l10n.homeSyncing));

      // 核心断言（归零状态）：收起动画完成后 _syncResultText 已重置为 null，
      // 指示器内文案回到"正在同步账本数据"（homeSyncing）——这正是下次下拉拖拽
      // 阶段会直接显示的内容；同时不应再残留上次的 homePullCloudSuccess。
      // 指示器始终常驻于组件树中，故可在静止态直接断言该归零状态。
      expect(
        find.text(l10n.homeSyncing),
        findsOneWidget,
        reason: '结果文案归零后，指示器应回到"正在同步"，确保下次下拉直接显示而非残留上次结果',
      );
      expect(
        find.text(l10n.homePullCloudSuccess),
        findsNothing,
        reason: '归零后不应再残留上次的云端同步成功文案',
      );
      // 冲刷计时器。
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
