// 汇率管理页（ExchangeRatePage）组件测试。
//
// 需求锚点（以页面行为为准）：
//   1. 首次加载（无缓存）展示弱化 loading；加载失败展示错误文案 + 重试，重试后恢复；
//   2. 数据态展示说明卡 / 当前账本标注 / 主币种行 / 币种管理入口（含可见数）/ 免责声明；
//   3. 汇率行三态：未获取（—）、自动（自动 · 日期 更新 + 换算）、手动（手动 + 恢复自动）；
//   4. 编辑弹窗：预填、非法输入拦截、保存调 setOverride、手动行可恢复自动、取消不落库；
//   5. 行内「恢复自动」直接 removeOverride；
//   6. 刷新成功/失败 toast；无账本时点主币种 toast 引导先建账本；
//   7. 有账本时点主币种 → 弹选择 sheet → 选中后走统一切换流程（updateLedger + toast）；
//   8. 币种管理入口跳转 CurrencyManagePage。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/cloud/sync/sync_service.dart'
    show LocalOnlySyncService;
import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/currency/currency_manage_page.dart';
import 'package:spitout/pages/currency/exchange_rate_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/services/currency/exchange_rate_service.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// Mock 整个 BaseRepository：未 stub 的方法返回默认值，不抛异常。
class _MockRepo extends Mock implements BaseRepository {}

/// 假汇率服务：固定返回 CNY base 的几个币种，不打网络。
class _FakeRateService implements ExchangeRateService {
  bool shouldThrow = false;
  int fetchCount = 0;

  @override
  Future<RateFetchResult> fetch(String base) async {
    fetchCount++;
    if (shouldThrow) throw Exception('network down');
    return const RateFetchResult(
      rateDate: '2026-07-12',
      source: 'fake',
      ratesBaseToQuote: {'USD': '0.139', 'JPY': '20.5'},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late _FakeRateService rateService;
  late db.Ledger testLedger;

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

  db.ExchangeRate autoRate({
    required String quote,
    required String rate,
    String rateDate = '2026-07-10',
  }) {
    return db.ExchangeRate(
      baseCurrency: 'CNY',
      quoteCurrency: quote,
      rateDate: rateDate,
      rate: rate,
      source: 'fake',
      fetchedAt: DateTime.utc(2026, 7, 10),
    );
  }

  db.ExchangeRateOverride manualOverride({
    required String quote,
    required String rate,
  }) {
    return db.ExchangeRateOverride(
      id: 1,
      baseCurrency: 'CNY',
      quoteCurrency: quote,
      rate: rate,
      updatedAt: DateTime(2026, 7, 10),
    );
  }

  /// 注册默认汇率数据：USD=自动、JPY=手动、EUR=缺失。
  void registerDefaultRates() {
    when(() => repo.getLatestAutoRates('CNY')).thenAnswer(
      (_) async => [
        autoRate(quote: 'USD', rate: '7.24'),
      ],
    );
    when(() => repo.getOverrides('CNY'))
        .thenAnswer((_) async => [manualOverride(quote: 'JPY', rate: '0.048')]);
  }

  /// 构建页面宿主：注入 mock repo + 固定当前账本/币种/可见集合。
  ///
  /// 设计意图：页面依赖 currentLedgerProvider（账本标注与主币种切换）、
  /// effectiveRatesForLedgerProvider（汇率数据）与 visibleCurrenciesProvider；
  /// 统一 override 为确定性数据，避免真实数据库初始化成本。
  Widget buildApp({db.Ledger? ledger, bool noLedger = false}) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        exchangeRateServiceProvider.overrideWithValue(rateService),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
        currentLedgerProvider.overrideWith(
          (ref) => Stream<db.Ledger?>.value(noLedger ? null : ledger),
        ),
        currentLedgerCurrencyProvider.overrideWith((ref) => 'CNY'),
        visibleCurrenciesProvider.overrideWithBuild(
          (ref, notifier) => {'CNY', 'USD', 'JPY', 'EUR'},
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
        home: const ExchangeRatePage(),
      ),
    );
  }

  setUp(() {
    repo = _MockRepo();
    rateService = _FakeRateService();
    testLedger = buildLedger();
    // 页面进入即触发一次刷新：无账本时直接跳过，避免多余网络/DB 调用。
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <db.Ledger>[]);
    registerDefaultRates();
  });

  testWidgets('首次加载展示弱化 loading，加载完成后进入数据态', (tester) async {
    final completer = Completer<List<db.ExchangeRate>>();
    when(() => repo.getLatestAutoRates('CNY'))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete([autoRate(quote: 'USD', rate: '7.24')]);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('汇率管理'), findsOneWidget);
  });

  testWidgets('加载失败展示错误 + 重试，重试成功恢复数据态', (tester) async {
    var failFirst = true;
    when(() => repo.getLatestAutoRates('CNY')).thenAnswer((_) async {
      if (failFirst) throw Exception('db down');
      return [autoRate(quote: 'USD', rate: '7.24')];
    });
    // 重试需走完 refresh 主流程（非空账本 + 未过期跳过拉取）才能 bump tick 触发重算。
    when(() => repo.getAllLedgers()).thenAnswer((_) async => [testLedger]);
    when(() => repo.getLastFetchedAt(any()))
        .thenAnswer((_) async => DateTime.now().toUtc());
    when(
      () => repo.upsertAutoRates(
        base: any(named: 'base'),
        rateDate: any(named: 'rateDate'),
        rates: any(named: 'rates'),
        source: any(named: 'source'),
        fetchedAt: any(named: 'fetchedAt'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExchangeRatePage)),
    );
    expect(find.text(l10n.analyticsLoadFailed), findsOneWidget);

    failFirst = false;
    await tester.tap(find.text(l10n.analyticsRetry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.analyticsLoadFailed), findsNothing);
    expect(find.text('1 USD = 7.24 CNY'), findsOneWidget);
    // 重试成功会弹「汇率已更新」toast，推进自动消失定时器。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('数据态：说明卡/账本标注/主币种行/币种管理入口/免责声明', (tester) async {
    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExchangeRatePage)),
    );
    expect(find.text(l10n.exchangeRateInfoTitle), findsOneWidget);
    expect(find.text(l10n.exchangeRateInfoMessage), findsOneWidget);
    expect(find.text(l10n.exchangeRateCurrentLedger('测试账本')), findsOneWidget);
    expect(find.text(l10n.ledgerBaseCurrencyLabel), findsOneWidget);
    expect(find.text(l10n.currencyManageEntry), findsOneWidget);
    expect(find.text(l10n.currencyManageCount(4)), findsOneWidget);
    // 免责声明在列表底部，懒构建需先滚动到可视区。
    await tester.scrollUntilVisible(
      find.text(l10n.rateDisclaimer),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.rateDisclaimer), findsOneWidget);
  });

  testWidgets('汇率行三态：自动换算 / 手动+恢复自动 / 未获取', (tester) async {
    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExchangeRatePage)),
    );
    // USD：自动 + 换算
    expect(find.text('${l10n.rateSourceAuto} · ${l10n.rateUpdatedAt('2026-07-10')}'),
        findsOneWidget);
    expect(find.text('1 USD = 7.24 CNY'), findsOneWidget);
    // JPY：手动 + 恢复自动
    expect(find.text(l10n.rateSourceManual), findsOneWidget);
    expect(find.text(l10n.rateResetToAuto), findsOneWidget);
    expect(find.text('1 JPY = 0.048 CNY'), findsOneWidget);
    // EUR：未获取（占位符）
    expect(find.text(l10n.rateNotFetched), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('编辑弹窗：非法输入拦截，合法保存调 setOverride', (tester) async {
    when(
      () => repo.setOverride(
        base: any(named: 'base'),
        quote: any(named: 'quote'),
        rate: any(named: 'rate'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();
    // 行序按 kCurrencyCodes：JPY(0)/EUR(1)/USD(2)，USD 编辑入口取 .at(2)。
    // USD 行在列表底部，先滚动到可见再点，避免点击落点被裁切。
    final usdEdit = find.text('编辑').at(2);
    await tester.ensureVisible(usdEdit);
    await tester.pumpAndSettle();
    await tester.tap(usdEdit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExchangeRatePage)),
    );
    expect(find.text(l10n.rateEditTitle), findsOneWidget);
    final input = find.byType(TextField);
    expect(tester.widget<TextField>(input).controller!.text, '7.24000',
        reason: '自动汇率按 6 位有效数字预填');

    // 非法输入：0 → 拦截并 toast，弹窗不关
    await tester.enterText(input, '0');
    await tester.pump();
    await tester.tap(find.text(l10n.commonSave));
    await tester.pump();
    expect(find.text(l10n.rateInvalidInput), findsOneWidget);
    expect(find.text(l10n.rateEditTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 合法输入 → setOverride + 关闭
    await tester.enterText(input, '7.5');
    await tester.pump();
    await tester.tap(find.text(l10n.commonSave));
    await tester.pumpAndSettle();

    verify(
      () => repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.5'),
    ).called(1);
    expect(find.text(l10n.rateEditTitle), findsNothing);
  });

  testWidgets('编辑弹窗：手动行可恢复自动，取消不落库', (tester) async {
    when(
      () => repo.removeOverride(
        base: any(named: 'base'),
        quote: any(named: 'quote'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExchangeRatePage)),
    );

    // 打开 JPY 手动行的编辑弹窗（第二行编辑入口）
    await tester.tap(find.text('编辑').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // 弹窗内按钮在树中位于行内链接之后，取 .last。
    await tester.tap(find.text(l10n.rateResetToAuto).last);
    await tester.pumpAndSettle();
    verify(
      () => repo.removeOverride(base: 'CNY', quote: 'JPY'),
    ).called(1);

    // 再开一个弹窗点取消 → 无落库
    // 重新打开 JPY 行弹窗并取消
    await tester.tap(find.text('编辑').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.text(l10n.rateEditTitle), findsNothing);
  });

  testWidgets('行内「恢复自动」直接 removeOverride', (tester) async {
    when(
      () => repo.removeOverride(
        base: any(named: 'base'),
        quote: any(named: 'quote'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();

    // 页面内「恢复自动」有两个：行内链接 + 弹窗按钮；此处只出现行内链接。
    await tester.tap(find.text('恢复自动').first);
    await tester.pumpAndSettle();
    verify(
      () => repo.removeOverride(base: 'CNY', quote: 'JPY'),
    ).called(1);
  });

  testWidgets('刷新成功与失败分别 toast', (tester) async {
    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExchangeRatePage)),
    );

    // 成功：当前无账本 base 集合为空 → refresh 返回 true
    await tester.tap(find.byIcon(AppIcons.refresh));
    await tester.pump();
    expect(find.text(l10n.rateRefreshSuccess), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 失败：有账本且强制拉取时服务抛错 → refresh 返回 false
    when(() => repo.getAllLedgers()).thenAnswer((_) async => [testLedger]);
    when(() => repo.getLastFetchedAt(any()))
        .thenAnswer((_) async => DateTime.now().toUtc());
    when(
      () => repo.upsertAutoRates(
        base: any(named: 'base'),
        rateDate: any(named: 'rateDate'),
        rates: any(named: 'rates'),
        source: any(named: 'source'),
        fetchedAt: any(named: 'fetchedAt'),
      ),
    ).thenAnswer((_) async {});
    rateService.shouldThrow = true;

    await tester.tap(find.byIcon(AppIcons.refresh));
    await tester.pump();
    expect(find.text(l10n.rateRefreshFailed), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('无账本时点主币种：toast 引导先创建账本', (tester) async {
    await tester.pumpWidget(buildApp(ledger: testLedger, noLedger: true));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExchangeRatePage)),
    );
    await tester.tap(find.text(l10n.ledgerBaseCurrencyLabel));
    await tester.pump();
    expect(find.text(l10n.homeBaseCurrencyNeedLedger), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('有账本时切换主币种：弹 sheet 选中 USD 走统一切换流程', (tester) async {
    when(() => repo.getLedgerById(1)).thenAnswer((_) async => testLedger);
    when(
      () => repo.getLedgerStats(ledgerId: any(named: 'ledgerId')),
    ).thenAnswer((_) async => (expenseTotal: 0.0, transactionCount: 0));
    when(
      () => repo.updateLedger(
        id: any(named: 'id'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.getLedgerForeignCurrencies(any()))
        .thenAnswer((_) async => <String>{});
    when(
      () => repo.recalcNativeAmountsForLedger(
        any(),
        any(),
        recordChanges: any(named: 'recordChanges'),
      ),
    ).thenAnswer((_) async => 0);

    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExchangeRatePage)),
    );

    await tester.tap(find.text(l10n.ledgerBaseCurrencyLabel));
    await tester.pumpAndSettle();
    expect(find.text('人民币 (CNY)'), findsOneWidget, reason: '选择 sheet 已弹出');

    await tester.tap(find.text('美元 (USD)'));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateLedger(id: 1, currency: 'USD'),
    ).called(1);
    expect(
      find.text(l10n.homeBaseCurrencySwitched('美元 (USD)')),
      findsOneWidget,
      reason: '切换完成应 toast 提示',
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('币种管理入口跳转 CurrencyManagePage', (tester) async {
    await tester.pumpWidget(buildApp(ledger: testLedger));
    await tester.pumpAndSettle();

    await tester.tap(find.text('币种管理'));
    await tester.pumpAndSettle();

    expect(find.byType(CurrencyManagePage), findsOneWidget);
  });
}
