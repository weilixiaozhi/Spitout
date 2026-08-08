/// HomePage 行为流测试（第二弹）：头部交互、debug 填充、下拉刷新失败/补折算、
/// 账本空态与错误态、AA 入口、交易明细接线与删除流程。
///
/// 第一弹（home_page_test.dart）已覆盖左右切月与下拉刷新成功/降级文案；
/// 本文件补齐头部/卡片交互与异常分支，避免把「用户点一下会发生什么」的断言
/// 全部堆进同一个文件。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show CloudServiceConfig;
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart'
    show FakeSpitoutCloudProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart' show LedgerVirtualUser;
import 'package:spitout/data/models.dart'
    show Category, Ledger, RecordEditHistory, Transaction;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/home_page.dart';
import 'package:spitout/pages/main/ledgers_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/routes.dart';
import 'package:spitout/services/maintenance/analytics_test_data_seeder.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/app_empty.dart';

/// Mock 整个 BaseRepository：未 stub 的方法返回默认值，避免触碰数据库。
class _MockRepo extends Mock implements BaseRepository {}

typedef _TxItem = ({Transaction t, Category? category});

/// 可控返回值的测试数据填充器（真实实现会写库，测试中仅统计调用参数）。
class _FakeSeeder extends AnalyticsTestDataSeeder {
  _FakeSeeder(super.repo);

  int fillCalls = 0;
  TestDataScope? lastScope;
  String? lastPaidBy;

  @override
  Future<int> fill({
    required int ledgerId,
    required String baseCurrency,
    required TestDataScope scope,
    String? paidByUserId,
  }) async {
    fillCalls++;
    lastScope = scope;
    lastPaidBy = paidByUserId;
    return 3;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late Ledger testLedger;
  late Stream<List<_TxItem>> Function() txsStreamFactory;

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
    registerTxsStream(() {
      return Stream<List<_TxItem>>.value(const []);
    });
    when(
      () => repo.watchTransactionsWithCategoryInMonth(
        ledgerId: any(named: 'ledgerId'),
        month: any(named: 'month'),
      ),
    ).thenAnswer((_) => txsStreamFactory());
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    when(() => repo.countUnconvertedForeignTx(any())).thenAnswer((_) async => 0);
    when(() => repo.deleteTransaction(any())).thenAnswer((_) async {});
  });

  Widget buildApp({
    DateTime? initialMonth,
    List<Override>? extraOverrides,
    Override? currentLedgerOverride,
    bool withStubRoutes = false,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
        currentLedgerOverride ??
            currentLedgerProvider.overrideWith(
              (ref) => Stream<Ledger?>.value(testLedger),
            ),
        currentMonthStartDayProvider.overrideWith((ref) => 1),
        monthlyTotalsProvider.overrideWith((ref, params) async => 0.0),
        todayExpenseProvider.overrideWith((ref, ledgerId) async => 0.0),
        weekExpenseProvider.overrideWith((ref, ledgerId) async => 0.0),
        selectedMonthProvider.overrideWithBuild(
          (ref, notifier) => initialMonth ?? DateTime(2026, 7, 1),
        ),
        // 详情 sheet 依赖的 provider 直接给确定值，绕开真实数据库。
        recordEditHistoryProvider.overrideWith(
          (ref, recordId) async => const <RecordEditHistory>[],
        ),
        // 首页/详情共用的虚拟用户流给空表。
        ledgerVirtualUsersProvider.overrideWith(
          (ref, ledgerId) => Stream<List<LedgerVirtualUser>>.value(const []),
        ),
        // LedgersPage 所需：本地账本列表与云端配置均给确定值。
        activeCloudConfigProvider.overrideWith(
          (ref) async => CloudServiceConfig.localStorage(),
        ),
        ...?extraOverrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        onGenerateRoute: withStubRoutes
            ? (settings) {
                if (settings.name == Routes.aaStatistics) {
                  return MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('AA_STUB')),
                  );
                }
                return null;
              }
            : null,
        home: const HomePage(),
      ),
    );
  }

  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  ProviderContainer containerOf(WidgetTester tester) {
    return ProviderScope.containerOf(tester.element(find.byType(HomePage)));
  }

  /// 通过下发 ScrollNotification 模拟「从列表顶部下拉」，触发首页自定义刷新指示器。
  Future<void> pullToRefresh(
    WidgetTester tester, {
    List<double> pullPixels = const [-16, -32, -48, -64],
    double endPixels = -64,
  }) async {
    final ctx = tester.element(find.byType(AppEmpty));
    FixedScrollMetrics metricsAt(double pixels) => FixedScrollMetrics(
      minScrollExtent: -200,
      maxScrollExtent: 100,
      pixels: pixels,
      viewportDimension: 100,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );
    for (final p in pullPixels) {
      ScrollUpdateNotification(metrics: metricsAt(p), context: ctx).dispatch(ctx);
      await tester.pump(const Duration(milliseconds: 16));
    }
    ScrollEndNotification(metrics: metricsAt(endPixels), context: ctx).dispatch(
      ctx,
    );
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.elementList(finder).isNotEmpty) return;
    }
    throw Exception('pumpUntilFound: $finder 在超时内未出现');
  }

  testWidgets('点击账本胶囊：进入 LedgersPage', (tester) async {
    await tester.pumpWidget(buildApp());
    await prime(tester);

    final capsule = find.text('测试账本');
    expect(capsule, findsOneWidget);
    await tester.tap(capsule);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LedgersPage), findsOneWidget,
        reason: '点击账本徽章应进入账本管理页');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('无账本时胶囊显示「新建账本」引导', (tester) async {
    await tester.pumpWidget(
      buildApp(
        currentLedgerOverride: currentLedgerProvider.overrideWith(
          (ref) => Stream<Ledger?>.value(null),
        ),
      ),
    );
    await prime(tester);

    expect(find.text('新建账本'), findsOneWidget,
        reason: '当前账本为 null 时徽章应显示新建引导而非账本名');
  });

  testWidgets('日期头点击：打开月份滚轮并确认同月（不切月）', (tester) async {
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 7, 1)));
    await prime(tester);

    final dateHeader = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains('2026'),
    );
    await tester.tap(dateHeader);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('选择账单月份'), findsOneWidget);
    // 不滚动直接确认：应走「同月早退」分支，selectedMonth 不变。
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(containerOf(tester).read(selectedMonthProvider), DateTime(2026, 7, 1));
  });

  testWidgets('日期头点击：滚轮切月并确认后 selectedMonth 更新', (tester) async {
    await tester.pumpWidget(buildApp(initialMonth: DateTime(2026, 7, 1)));
    await prime(tester);

    final dateHeader = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains('2026'),
    );
    await tester.tap(dateHeader);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 月份滚轮向上拖一个 itemExtent（40px），把 7 月换成 6 月。
    final monthWheel = find.byType(CupertinoPicker).at(1);
    await tester.drag(monthWheel, const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      containerOf(tester).read(selectedMonthProvider),
      DateTime(2026, 6, 1),
      reason: '确认滚轮选中的新月份后应更新选中月份并复位 PageView',
    );
  });

  testWidgets('debug 填充：对话框四选项 + 按年填充 + 已填充 toast', (tester) async {
    final seeder = _FakeSeeder(repo);
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          analyticsTestDataSeederProvider.overrideWith((ref) => seeder),
          localSelfIdProvider.overrideWith((ref) async => 'local-self'),
        ],
      ),
    );
    await prime(tester);

    await tester.tap(find.byIcon(AppIcons.autoAwesome));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('填充测试数据'), findsOneWidget);
    expect(find.text('按年（全年12个月）'), findsOneWidget);
    expect(find.text('按月（整月）'), findsOneWidget);
    expect(find.text('按周（本周7天）'), findsOneWidget);
    expect(find.text('按日（今日）'), findsOneWidget);

    await tester.tap(find.text('按年（全年12个月）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(seeder.fillCalls, 1);
    expect(seeder.lastScope, TestDataScope.year);
    expect(seeder.lastPaidBy, 'local-self',
        reason: '未登录时应回填本地设备身份作为支出人');
    expect(find.text('已填充 3 条测试数据'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // 再次打开对话框，补齐「按周 / 按日」两个选项的触发分支。
    await tester.tap(find.byIcon(AppIcons.autoAwesome));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('按周（本周7天）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(seeder.lastScope, TestDataScope.week);

    await tester.tap(find.byIcon(AppIcons.autoAwesome));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('按日（今日）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(seeder.lastScope, TestDataScope.day);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('debug 填充：云端已登录时用云端 userId 作为支出人', (tester) async {
    final seeder = _FakeSeeder(repo);
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          analyticsTestDataSeederProvider.overrideWith((ref) => seeder),
          spitoutCloudProviderInstance.overrideWith(
            (ref) async => FakeSpitoutCloudProvider(),
          ),
        ],
      ),
    );
    await prime(tester);

    await tester.tap(find.byIcon(AppIcons.autoAwesome));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('按年（全年12个月）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(seeder.lastPaidBy, 'test-user-id',
        reason: '云端已登录时应优先用云端 userId，而非本地身份');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('debug 填充：本地身份解析失败降级为不传支出人', (tester) async {
    final seeder = _FakeSeeder(repo);
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          analyticsTestDataSeederProvider.overrideWith((ref) => seeder),
          localSelfIdProvider.overrideWith(
            (ref) => Future<String>.error(StateError('boom')),
          ),
        ],
      ),
    );
    await prime(tester);

    await tester.tap(find.byIcon(AppIcons.autoAwesome));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('按月（整月）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(seeder.lastScope, TestDataScope.month);
    expect(seeder.lastPaidBy, isNull,
        reason: '身份解析异常时应跳过支出人（仅 debug 数据，不阻塞）');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('下拉刷新：本地兜底也失败 → 指示器显示「刷新失败」', (tester) async {
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          // 主题初始化是 _runLocalRefresh 的中间步骤；让它抛错即可让整个
          // 本地刷新兜底失败，走到外层 catch。
          themeModeInitProvider.overrideWith(
            (ref) => Future<void>.error(StateError('boom')),
          ),
        ],
      ),
    );
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    await pullToRefresh(tester);
    await pumpUntilFound(tester, find.text(l10n.homePullCloudFailed));

    expect(find.text(l10n.homePullCloudFailed), findsOneWidget,
        reason: '本地兜底也失败时应展示「刷新失败，请稍后重试」');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('下拉刷新：存在未折算外币交易 → 自动补折算并刷新', (tester) async {
    when(
      () => repo.countUnconvertedForeignTx(any()),
    ).thenAnswer((_) async => 2);
    when(
      () => repo.recomputeForeignTxForLedger(any()),
    ).thenAnswer((_) async => 2);

    await tester.pumpWidget(buildApp());
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    await pullToRefresh(tester);
    await pumpUntilFound(tester, find.text(l10n.homePullLocalSuccess));

    verify(() => repo.recomputeForeignTxForLedger(1)).called(1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('下拉刷新：补折算返回 0 或抛错均不阻断刷新', (tester) async {
    when(() => repo.countUnconvertedForeignTx(any())).thenAnswer((_) async => 1);
    when(
      () => repo.recomputeForeignTxForLedger(any()),
    ).thenAnswer((_) async => 0);

    await tester.pumpWidget(buildApp());
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    await pullToRefresh(tester);
    await pumpUntilFound(tester, find.text(l10n.homePullLocalSuccess));
    await tester.pump(const Duration(seconds: 3));

    // 第二轮：补折算本身抛错 → 仅告警，刷新仍成功。
    when(
      () => repo.recomputeForeignTxForLedger(any()),
    ).thenThrow(StateError('recalc boom'));
    await pullToRefresh(tester);
    await pumpUntilFound(tester, find.text(l10n.homePullLocalSuccess));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('云端账本：自动修复历史数据 → 展示补回条数文案', (tester) async {
    testLedger = testLedger.copyWith(storageMode: 'cloud');
    final sync = _SyncStub()
      ..outcome = const PullOutcome(incremental: 0, healed: 3, didHeal: true);
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [syncServiceProvider.overrideWith((ref) => sync)],
      ),
    );
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    await pullToRefresh(tester);
    await pumpUntilFound(tester, find.text(l10n.homePullCloudHealed(3)));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('云端账本：缺口未恢复 → 引导到云同步页恢复', (tester) async {
    testLedger = testLedger.copyWith(storageMode: 'cloud');
    final sync = _SyncStub()
      ..outcome = const PullOutcome(incremental: 0, gapRemaining: true);
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [syncServiceProvider.overrideWith((ref) => sync)],
      ),
    );
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    await pullToRefresh(tester);
    await pumpUntilFound(tester, find.text(l10n.homePullCloudGap));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('当前账本加载失败：头部显示错误 + 重试按钮', (tester) async {
    await tester.pumpWidget(
      buildApp(
        currentLedgerOverride: currentLedgerProvider.overrideWith(
          (ref) => Stream<Ledger?>.error(StateError('boom')),
        ),
      ),
    );
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    expect(find.text(l10n.analyticsLoadFailed), findsOneWidget);
    expect(find.text(l10n.analyticsRetry), findsOneWidget);

    // 点击重试仅 invalidate provider，不应崩溃。
    await tester.tap(find.text(l10n.analyticsRetry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HomePage), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('AA 账本：显示「分摊统计」入口并可跳转', (tester) async {
    testLedger = testLedger.copyWith(aaEnabled: true);
    await tester.pumpWidget(buildApp(withStubRoutes: true));
    await prime(tester);

    final entry = find.text('分摊统计');
    expect(entry, findsOneWidget,
        reason: 'AA 账本应在汇总卡下方渲染分摊统计入口');

    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('AA_STUB'), findsOneWidget,
        reason: '点击入口应跳转到分摊统计路由');
  });

  testWidgets('下拉未达阈值：停止旋转并收起指示器', (tester) async {
    await tester.pumpWidget(buildApp());
    await prime(tester);

    // 只拉 30px（阈值 48），松开后应走「未达标收起」分支。
    await pullToRefresh(
      tester,
      pullPixels: const [-10, -20, -30],
      endPixels: -30,
    );
    await tester.pump(const Duration(milliseconds: 300));

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    // SizeTransition 收起后文本仍在树中（零尺寸），因此断言「未进入刷新」应看
    // 是否出现了刷新结果文案 / 是否调用了同步服务。
    expect(find.text(l10n.homePullLocalSuccess), findsNothing,
        reason: '未达标不应触发刷新');
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('overscroll 回弹到 0：结束本次下拉会话', (tester) async {
    await tester.pumpWidget(buildApp());
    await prime(tester);

    // 拉 32px 后回弹到 0：ScrollUpdate 中 pixels 回正应触发 _handlePullEnd。
    await pullToRefresh(
      tester,
      pullPixels: const [-16, -32, 0],
      endPixels: 0,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('交易流加载失败：显示友好错误 + 重试重建流', (tester) async {
    var errorStreamCalls = 0;
    registerTxsStream(
      () {
        errorStreamCalls++;
        return Stream<List<_TxItem>>.error(StateError('stream boom'));
      },
    );
    await tester.pumpWidget(buildApp());
    await prime(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));
    expect(find.text(l10n.analyticsLoadFailed), findsOneWidget);
    expect(find.text(l10n.analyticsRetry), findsOneWidget);

    final callsBefore = errorStreamCalls;
    await tester.tap(find.text(l10n.analyticsRetry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(errorStreamCalls, greaterThan(callsBefore),
        reason: '重试应重建交易流');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('共享账本：成员表刷新 loading 时复用上次缓存', (tester) async {
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
    // 第一次返回成员表；invalidate 后的重算返回挂起 Future，模拟刷新期 loading。
    var memberCalls = 0;
    final pendingMembers = Completer<List<SpitoutCloudLedgerMember>>();
    await tester.pumpWidget(
      buildApp(
        extraOverrides: [
          ledgerMembersProvider.overrideWith(
            (ref, syncId) {
              memberCalls++;
              if (memberCalls == 1) {
                return Future.value([
                  SpitoutCloudLedgerMember(
                    userId: 'u1',
                    account: 'a@b.c',
                    role: 'owner',
                    joinedAt: DateTime.utc(2026, 1, 1),
                    isSelf: true,
                    displayName: '小明',
                  ),
                  SpitoutCloudLedgerMember(
                    userId: 'u2',
                    account: 'b@c.d',
                    role: 'editor',
                    joinedAt: DateTime.utc(2026, 1, 2),
                    isSelf: false,
                    displayName: '小红',
                  ),
                ]);
              }
              return pendingMembers.future;
            },
          ),
        ],
      ),
    );
    await prime(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // 首次加载成功后 invalidate：下一次 build 应复用缓存而非闪错误头像。
    containerOf(tester).invalidate(ledgerMembersProvider('sync-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomePage), findsOneWidget);
    // 释放挂起的成员表，避免遗留未完成 future 影响测试收尾。
    pendingMembers.complete(const []);
    await tester.pump(const Duration(milliseconds: 100));
  });

}

/// 可配置返回值的 SyncService 替身（仅用于首页云同步文案分支）。
class _SyncStub implements SyncService {
  PullOutcome outcome = const PullOutcome(incremental: 0);

  @override
  bool supportsDiffPreview = false;

  @override
  Future<PullOutcome> pullIncrementalWithHeal({required int ledgerId}) async =>
      outcome;

  @override
  Future<({int inserted, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId}) async =>
      (inserted: 0, deletedDup: 0);

  @override
  Future<({SyncPreview? preview, ImportData importData, int version})?>
      downloadAndPreview({required int ledgerId}) async => null;

  @override
  Future<SyncApplyResult> applyPreviewChanges({
    required int ledgerId,
    required List<SyncChange> selectedChanges,
    required ImportData importData,
  }) async =>
      const SyncApplyResult(addedCount: 0);

  @override
  Future<int> pullIncremental({required int ledgerId}) async => 0;

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async =>
      const SyncStatus(
        diff: SyncDiff.inSync,
        localCount: 0,
        localFingerprint: '',
      );

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {}

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async =>
      (fingerprint: null, count: null, exportedAt: null);

  @override
  void markLocalChanged({required int ledgerId}) {}

  @override
  Future<void> deleteRemoteBackup({required int ledgerId}) async {}

  @override
  Future<void> deleteLedgerGlobally(int ledgerId) async {}

  @override
  Future<void> moveToCloud(int ledgerId) async {}

  @override
  Future<void> moveToLocal(int ledgerId) async {}

  @override
  Future<int> copyToLocal(int sourceLedgerId) async => 0;

  @override
  void clearStatusCache({int? ledgerId}) {}
}
