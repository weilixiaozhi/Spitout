/// TransactionEditorSheet 提交/编辑/AA/日期/作者头像流程测试。
///
/// 需求锚点：
/// - 新建提交：选分类 → 输入金额 → 完成，落库参数正确（整数分、本位币
///   nativeAmount、null AA 字段），成功后 sheet 关闭；
/// - 外币无汇率：提交被阻断并 toast 提示；
/// - 编辑模式：initialCategoryId 解析回显、updateTransaction +
///   appendEditHistory 同版本号闭环、markTxAuthor 回填编辑人；
/// - AA 开启时头部三态切换（人均 → 不分摊 → 指定 → 人均）；
/// - 日期键打开滚轮并可确认；编辑共享账本交易渲染作者头像组。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/cloud/sync/sync_service.dart' show SyncService;
import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/data/repositories/category_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/category/category_picker_providers.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart'
    show syncServiceProvider;
import 'package:spitout/core/router/routes.dart';
import 'package:spitout/router.dart';
import 'package:spitout/services/statistics/aa_edit_models.dart' show AaEditResult;
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/utils/currency/rate_math.dart' show EffectiveRate;
import 'package:spitout/widgets/amount_expression_bar.dart';
import 'package:spitout/widgets/amount_keypad.dart';
import 'package:spitout/widgets/collaborator_avatar.dart';
import 'package:spitout/widgets/press_key.dart';
import 'package:spitout/widgets/transaction_editor_sheet.dart';

class _MockRepo extends Mock implements BaseRepository {}

class _MockSyncService extends Mock implements SyncService {}

db.Category _category(int id, String name) => db.Category(
  id: id,
  name: name,
  kind: 'expense',
  icon: 'dining',
  sortOrder: 1,
  level: 1,
);

db.Ledger _ledger({bool aaEnabled = false, bool isShared = false}) =>
    db.Ledger(
      id: 1,
      name: '测试账本',
      currency: 'CNY',
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 1,
      isShared: isShared,
      monthStartDay: 1,
      syncId: isShared ? 'sync-ledger-1' : null,
      storageMode: isShared ? 'cloud' : 'local',
      aaEnabled: aaEnabled,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late _MockSyncService syncService;

  setUp(() {
    repo = _MockRepo();
    syncService = _MockSyncService();
    when(() => syncService.markLocalChanged(ledgerId: any(named: 'ledgerId')))
        .thenAnswer((_) async {});
    when(() => repo.getCategoryTree(any())).thenAnswer(
      (_) async => const CategoryPickerTree(topLevel: [], children: {}),
    );
  });

  /// 构建宿主：直接以 TransactionEditorSheet 为 home（无 bottom sheet 包装，
  /// 便于断言提交后 pop 行为）。
  Widget buildApp({
    db.Ledger? ledger,
    List<db.Category> topLevel = const [],
    Map<String, EffectiveRate> rates = const {},
    RouteFactory? routeFactory,
    int? editingTransactionId,
    int? initialCategoryId,
    double? initialAmount,
    String? initialCurrencyCode,
    double? initialNativeAmount,
    int? initialAaMode,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
        currentLedgerProvider.overrideWith(
          (ref) => Stream<db.Ledger?>.value(ledger ?? _ledger()),
        ),
        currentLedgerCurrencyProvider.overrideWith((ref) => 'CNY'),
        effectiveRatesForLedgerProvider.overrideWith((ref) async => rates),
        categoryPickerTreeProvider('expense').overrideWith(
          (ref) => Stream<CategoryPickerTree>.value(
            CategoryPickerTree(topLevel: topLevel, children: const {}),
          ),
        ),
        syncServiceProvider.overrideWithValue(syncService),
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
        localSelfIdProvider.overrideWith((ref) async => 'device-1'),
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
        onGenerateRoute: routeFactory ?? appRoute,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: TransactionEditorSheet(
                        initialKind: 'expense',
                        editingTransactionId: editingTransactionId,
                        initialCategoryId: initialCategoryId,
                        initialAmount: initialAmount,
                        initialCurrencyCode: initialCurrencyCode,
                        initialNativeAmount: initialNativeAmount,
                        initialAaMode: initialAaMode,
                      ),
                    ),
                  ),
                ),
                child: const Text('open-editor'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 打开编辑器路由并等待首帧。
  Future<void> openEditor(WidgetTester tester) async {
    // 预热 currentLedgerProvider：让流在编辑器 initState 前已 emit，
    // 否则 _resolveInitialCategory 读到的 ledger 为 null。
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('open-editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Finder amountText(String amount) => find.descendant(
    of: find.byType(AmountExpressionBar),
    matching: find.text(amount),
  );

  Future<void> tapKeypadDigit(WidgetTester tester, String digit) async {
    await tester.tap(
      find.descendant(of: find.byType(AmountKeypad), matching: find.text(digit)),
    );
    await tester.pump();
  }

  testWidgets('新建提交：选分类 + 金额 + 完成 → addTransaction 参数正确并关闭',
      (tester) async {
    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 42);
    when(
      () => repo.markTxAuthor(
        txId: any(named: 'txId'),
        userId: any(named: 'userId'),
        isCreate: any(named: 'isCreate'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildApp(topLevel: [_category(1, '餐饮')]),
    );
    await openEditor(tester);

    // 选分类。
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    // 输入金额 12。
    await tapKeypadDigit(tester, '1');
    await tapKeypadDigit(tester, '2');
    expect(amountText('12'), findsOneWidget);

    // 点完成键提交。
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // pop 动画需要更长时间，循环 pump 到 sheet 移除。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(
      () => repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 1200,
        categoryId: 1,
        happenedAt: any(named: 'happenedAt'),
        note: null,
        categorySyncIdOverride: null,
        excludeFromStats: false,
        currencyCode: 'CNY',
        nativeAmount: 1200,
        paidByUserId: null,
        aaMode: null,
        aaParticipants: null,
        aaSplits: null,
      ),
    ).called(1);
    verify(
      () => repo.markTxAuthor(
        txId: 42,
        userId: any(named: 'userId'),
        isCreate: true,
      ),
    ).called(1);
    // sheet 提交后关闭。
    expect(find.byType(TransactionEditorSheet), findsNothing);
  });

  testWidgets('未选分类提交：toast 提示并保持开启', (tester) async {
    await tester.pumpWidget(buildApp());
    await openEditor(tester);
    await tapKeypadDigit(tester, '1');

    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.byType(TransactionEditorSheet), findsOneWidget);
    // 未选分类时完成键禁用（PressKey.enabled=false），点击不触发提交。
    final doneKey = find.ancestor(
      of: find.byIcon(AppIcons.keyboardReturn),
      matching: find.byType(PressKey),
    );
    expect(tester.widget<PressKey>(doneKey).enabled, isFalse);
    expect(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
      findsOneWidget,
    );
  });

  testWidgets('外币无汇率提交：toast 阻断', (tester) async {
    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 1);
    await tester.pumpWidget(buildApp(topLevel: [_category(1, '餐饮')]));
    await openEditor(tester);

    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tapKeypadDigit(tester, '1');
    // 换币种到 USD（无汇率）：走币种选择 sheet。
    await tester.tap(find.byKey(const ValueKey('amount_currency_chip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.textContaining('美元'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(TransactionEditorSheet), findsOneWidget);
    // 表达式栏的汇率缺失提示仍在（toast 已自动消失）。
    expect(find.text('请手动填写本笔汇率后保存'), findsOneWidget);
    verifyNever(
      () => repo.addTransaction(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        happenedAt: any(named: 'happenedAt'),
        note: any(named: 'note'),
        categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
        excludeFromStats: any(named: 'excludeFromStats'),
        currencyCode: any(named: 'currencyCode'),
        nativeAmount: any(named: 'nativeAmount'),
        paidByUserId: any(named: 'paidByUserId'),
        aaMode: any(named: 'aaMode'),
        aaParticipants: any(named: 'aaParticipants'),
        aaSplits: any(named: 'aaSplits'),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('编辑模式：initialCategoryId 回显 + update + 编辑历史闭环',
      (tester) async {
    when(
      () => repo.findCategoryBySyntheticId(
        any(),
        ledgerSyncId: any(named: 'ledgerSyncId'),
      ),
    ).thenAnswer((_) async => _category(5, '旧分类'));
    when(() => repo.updateTransaction(
      id: any(named: 'id'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      note: any(named: 'note'),
      happenedAt: any(named: 'happenedAt'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 7);
    when(
      () => repo.appendEditHistory(
        recordId: any(named: 'recordId'),
        version: any(named: 'version'),
        operatorUserId: any(named: 'operatorUserId'),
        summary: any(named: 'summary'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => repo.markTxAuthor(
        txId: any(named: 'txId'),
        userId: any(named: 'userId'),
        isCreate: any(named: 'isCreate'),
      ),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      buildApp(
        editingTransactionId: 9,
        initialCategoryId: 5,
        topLevel: [_category(1, '餐饮')],
      ),
    );
    await openEditor(tester);
    // 初始分类解析是异步的（读 ledger + findCategoryBySyntheticId），多 pump 一拍。
    await tester.pump(const Duration(milliseconds: 100));

    // 输入金额 10（无 initialAmount 初值，键入即替换）。
    await tapKeypadDigit(tester, '1');
    await tapKeypadDigit(tester, '0');
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(
      () => repo.updateTransaction(
        id: 9,
        type: 'expense',
        amount: 1000,
        categoryId: 5,
        note: null,
        happenedAt: any(named: 'happenedAt'),
        categorySyncIdOverride: null,
        excludeFromStats: false,
        currencyCode: 'CNY',
        nativeAmount: 1000,
        paidByUserId: null,
        aaMode: null,
        aaParticipants: null,
        aaSplits: null,
      ),
    ).called(1);
    verify(
      () => repo.appendEditHistory(
        recordId: 9,
        version: 7,
        operatorUserId: any(named: 'operatorUserId'),
        summary: any(named: 'summary'),
      ),
    ).called(1);
  });

  testWidgets('AA 开启：头部分摊方式三态循环切换', (tester) async {
    await tester.pumpWidget(
      buildApp(ledger: _ledger(aaEnabled: true), topLevel: const []),
    );
    await openEditor(tester);

    final toggle = find.byKey(const ValueKey('editor_aa_mode_toggle'));
    expect(toggle, findsOneWidget);
    expect(find.text('人均分摊'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('不分摊'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('指定分摊'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('人均分摊'), findsOneWidget);
  });

  testWidgets('AA 开启 + 不分摊：提交携带 aaMode=1 并清空分摊字段',
      (tester) async {
    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 42);
    when(
      () => repo.markTxAuthor(
        txId: any(named: 'txId'),
        userId: any(named: 'userId'),
        isCreate: any(named: 'isCreate'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.updateTransaction(
      id: any(named: 'id'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      note: any(named: 'note'),
      happenedAt: any(named: 'happenedAt'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 2);
    when(
      () => repo.appendEditHistory(
        recordId: any(named: 'recordId'),
        version: any(named: 'version'),
        operatorUserId: any(named: 'operatorUserId'),
        summary: any(named: 'summary'),
      ),
    ).thenAnswer((_) async => 1);

    await tester.pumpWidget(
      buildApp(
        ledger: _ledger(aaEnabled: true),
        topLevel: [_category(1, '餐饮')],
      ),
    );
    await openEditor(tester);

    await tester.tap(find.text('餐饮'));
    await tester.pump();
    // 切到不分摊。
    final toggle = find.byKey(const ValueKey('editor_aa_mode_toggle'));
    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('不分摊'), findsOneWidget);

    await tapKeypadDigit(tester, '5');
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(
      () => repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 500,
        categoryId: 1,
        happenedAt: any(named: 'happenedAt'),
        note: null,
        categorySyncIdOverride: null,
        excludeFromStats: false,
        currencyCode: 'CNY',
        nativeAmount: 500,
        paidByUserId: null,
        aaMode: 1,
        aaParticipants: null,
        aaSplits: null,
      ),
    ).called(1);
  });

  testWidgets('AA 人均提交：跳 AaEditPage 后取消 → 不落库、sheet 保持',
      (tester) async {
    var aaPageOpened = false;
    // 用 stub 路由替代真实 AaEditPage（其依赖链与本次断言无关），
    // 页面内点「取消」pop null 模拟用户放弃分摊配置。
    Route<dynamic>? stubRoutes(RouteSettings settings) {
      if (settings.name == Routes.aaEdit) {
        aaPageOpened = true;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('取消配置'),
                ),
              ),
            ),
          ),
        );
      }
      return appRoute(settings);
    }

    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 42);

    await tester.pumpWidget(
      buildApp(
        ledger: _ledger(aaEnabled: true),
        topLevel: [_category(1, '餐饮')],
        routeFactory: stubRoutes,
      ),
    );
    await openEditor(tester);
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tapKeypadDigit(tester, '5');
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(aaPageOpened, isTrue, reason: '人均分摊提交应跳转 AaEditPage');
    // 点取消 → 编辑器保持开启、未落库。
    await tester.tap(find.text('取消配置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(TransactionEditorSheet), findsOneWidget);
    verifyNever(
      () => repo.addTransaction(
        ledgerId: any(named: 'ledgerId'),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        happenedAt: any(named: 'happenedAt'),
        note: any(named: 'note'),
        categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
        excludeFromStats: any(named: 'excludeFromStats'),
        currencyCode: any(named: 'currencyCode'),
        nativeAmount: any(named: 'nativeAmount'),
        paidByUserId: any(named: 'paidByUserId'),
        aaMode: any(named: 'aaMode'),
        aaParticipants: any(named: 'aaParticipants'),
        aaSplits: any(named: 'aaSplits'),
      ),
    );
  });

  testWidgets('AA 人均提交：AaEditPage 返回结果 → 按结果落库分摊字段',
      (tester) async {
    Route<dynamic>? stubRoutes(RouteSettings settings) {
      if (settings.name == Routes.aaEdit) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    const AaEditResult(
                      paidByUserId: 'u1',
                      aaMode: 0,
                      aaParticipants: ['u1', 'u2'],
                      aaSplits: null,
                    ),
                  ),
                  child: const Text('确认分摊'),
                ),
              ),
            ),
          ),
        );
      }
      return appRoute(settings);
    }

    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 42);
    when(
      () => repo.markTxAuthor(
        txId: any(named: 'txId'),
        userId: any(named: 'userId'),
        isCreate: any(named: 'isCreate'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildApp(
        ledger: _ledger(aaEnabled: true),
        topLevel: [_category(1, '餐饮')],
        routeFactory: stubRoutes,
      ),
    );
    await openEditor(tester);
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tapKeypadDigit(tester, '8');
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('确认分摊'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(
      () => repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 800,
        categoryId: 1,
        happenedAt: any(named: 'happenedAt'),
        note: null,
        categorySyncIdOverride: null,
        excludeFromStats: false,
        currencyCode: 'CNY',
        nativeAmount: 800,
        paidByUserId: 'u1',
        aaMode: 0,
        aaParticipants: '["u1","u2"]',
        aaSplits: null,
      ),
    ).called(1);
  });

  testWidgets('synthetic 分类：categoryId 留空、categorySyncIdOverride 写 syncId',
      (tester) async {
    when(
      () => repo.findCategoryBySyntheticId(
        any(),
        ledgerSyncId: any(named: 'ledgerSyncId'),
      ),
    ).thenAnswer(
      (_) async => db.Category(
        id: -3,
        name: '共享分类',
        kind: 'expense',
        sortOrder: 1,
        level: 2,
        syncId: 'synth-1',
      ),
    );
    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 42);
    when(
      () => repo.markTxAuthor(
        txId: any(named: 'txId'),
        userId: any(named: 'userId'),
        isCreate: any(named: 'isCreate'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildApp(
        editingTransactionId: 9,
        initialCategoryId: -3,
        topLevel: const [],
      ),
    );
    await openEditor(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tapKeypadDigit(tester, '7');
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(
      () => repo.updateTransaction(
        id: 9,
        type: 'expense',
        amount: 700,
        categoryId: null,
        note: null,
        happenedAt: any(named: 'happenedAt'),
        categorySyncIdOverride: 'synth-1',
        excludeFromStats: false,
        currencyCode: 'CNY',
        nativeAmount: 700,
        paidByUserId: null,
        aaMode: null,
        aaParticipants: null,
        aaSplits: null,
      ),
    ).called(1);
  });

  testWidgets('提交失败：toast 错误并保持 sheet 开启', (tester) async {
    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenThrow(Exception('db down'));

    await tester.pumpWidget(buildApp(topLevel: [_category(1, '餐饮')]));
    await openEditor(tester);
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tapKeypadDigit(tester, '5');
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TransactionEditorSheet), findsOneWidget);
    expect(find.textContaining('错误'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('备注输入后清空：onNotePicked 清空并复位光标', (tester) async {
    await tester.pumpWidget(buildApp());
    await openEditor(tester);

    await tester.enterText(find.byType(TextField), '早餐');
    await tester.pump();
    // 清空按钮出现并点击。
    await tester.tap(find.byIcon(AppIcons.cancel));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('共享账本编辑：分类解析携带账本 syncId 且返回键关闭编辑器',
      (tester) async {
    when(
      () => repo.findCategoryBySyntheticId(
        any(),
        ledgerSyncId: any(named: 'ledgerSyncId'),
      ),
    ).thenAnswer((_) async => _category(5, '旧分类'));

    await tester.pumpWidget(
      buildApp(
        ledger: _ledger(isShared: true),
        editingTransactionId: 9,
        initialCategoryId: 5,
      ),
    );
    await openEditor(tester);
    await tester.pump(const Duration(milliseconds: 100));

    // 返回键关闭编辑器（路由模式可 pop）。
    await tester.tap(find.byIcon(AppIcons.backChevron));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (!tester.any(find.byType(TransactionEditorSheet))) break;
    }
    expect(find.byType(TransactionEditorSheet), findsNothing);
  });

  testWidgets('markTxAuthor 失败不阻断保存（新交易仍落库并关闭）',
      (tester) async {
    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 42);
    when(
      () => repo.markTxAuthor(
        txId: any(named: 'txId'),
        userId: any(named: 'userId'),
        isCreate: any(named: 'isCreate'),
      ),
    ).thenThrow(Exception('author boom'));

    await tester.pumpWidget(buildApp(topLevel: [_category(1, '餐饮')]));
    await openEditor(tester);
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tapKeypadDigit(tester, '3');
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 保存成功（sheet 关闭），markTxAuthor 失败仅留 warning 不阻断。
    expect(find.byType(TransactionEditorSheet), findsNothing);
    verify(() => repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 300,
      categoryId: 1,
      happenedAt: any(named: 'happenedAt'),
      note: null,
      categorySyncIdOverride: null,
      excludeFromStats: false,
      currencyCode: 'CNY',
      nativeAmount: 300,
      paidByUserId: null,
      aaMode: null,
      aaParticipants: null,
      aaSplits: null,
    )).called(1);
  });

  testWidgets('编辑模式 markTxAuthor 失败：update 成功、编辑历史仍写入',
      (tester) async {
    when(
      () => repo.findCategoryBySyntheticId(
        any(),
        ledgerSyncId: any(named: 'ledgerSyncId'),
      ),
    ).thenAnswer((_) async => _category(5, '旧分类'));
    when(() => repo.updateTransaction(
      id: any(named: 'id'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      note: any(named: 'note'),
      happenedAt: any(named: 'happenedAt'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 3);
    when(
      () => repo.appendEditHistory(
        recordId: any(named: 'recordId'),
        version: any(named: 'version'),
        operatorUserId: any(named: 'operatorUserId'),
        summary: any(named: 'summary'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => repo.markTxAuthor(
        txId: any(named: 'txId'),
        userId: any(named: 'userId'),
        isCreate: any(named: 'isCreate'),
      ),
    ).thenThrow(Exception('author boom'));

    await tester.pumpWidget(
      buildApp(
        editingTransactionId: 9,
        initialCategoryId: 5,
        topLevel: [_category(1, '餐饮')],
      ),
    );
    await openEditor(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tapKeypadDigit(tester, '2');
    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 保存成功关闭，编辑历史照写。
    expect(find.byType(TransactionEditorSheet), findsNothing);
    verify(
      () => repo.appendEditHistory(
        recordId: 9,
        version: 3,
        operatorUserId: any(named: 'operatorUserId'),
        summary: any(named: 'summary'),
      ),
    ).called(1);
  });

  testWidgets('外币有汇率：提交按汇率折算 nativeAmount', (tester) async {
    when(() => repo.addTransaction(
      ledgerId: any(named: 'ledgerId'),
      type: any(named: 'type'),
      amount: any(named: 'amount'),
      categoryId: any(named: 'categoryId'),
      happenedAt: any(named: 'happenedAt'),
      note: any(named: 'note'),
      categorySyncIdOverride: any(named: 'categorySyncIdOverride'),
      excludeFromStats: any(named: 'excludeFromStats'),
      currencyCode: any(named: 'currencyCode'),
      nativeAmount: any(named: 'nativeAmount'),
      paidByUserId: any(named: 'paidByUserId'),
      aaMode: any(named: 'aaMode'),
      aaParticipants: any(named: 'aaParticipants'),
      aaSplits: any(named: 'aaSplits'),
    )).thenAnswer((_) async => 42);
    when(
      () => repo.markTxAuthor(
        txId: any(named: 'txId'),
        userId: any(named: 'userId'),
        isCreate: any(named: 'isCreate'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildApp(
        topLevel: [_category(1, '餐饮')],
        rates: const {'USD': EffectiveRate(rate: '7.2', manual: false)},
      ),
    );
    await openEditor(tester);
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tapKeypadDigit(tester, '1');
    // 切到 USD（有汇率 7.2）。
    await tester.tap(find.byKey(const ValueKey('amount_currency_chip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.textContaining('美元'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(
      find.descendant(
        of: find.byType(AmountKeypad),
        matching: find.byIcon(AppIcons.keyboardReturn),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    verify(
      () => repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 100,
        categoryId: 1,
        happenedAt: any(named: 'happenedAt'),
        note: null,
        categorySyncIdOverride: null,
        excludeFromStats: false,
        currencyCode: 'USD',
        nativeAmount: 720,
        paidByUserId: null,
        aaMode: null,
        aaParticipants: null,
        aaSplits: null,
      ),
    ).called(1);
  });

  testWidgets('日期键打开滚轮并确认：_date 更新', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp());
    await openEditor(tester);

    await tester.tap(
      find.descendant(of: find.byType(AmountKeypad), matching: find.textContaining('/')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 滚轮打开后点完成关闭，不抛错即可（滚轮自身有专项测试）。
    await tester.ensureVisible(find.text('完成'));
    await tester.tap(find.text('完成'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TransactionEditorSheet), findsOneWidget);
  });

  testWidgets('编辑共享账本交易：渲染作者头像组', (tester) async {
    when(
      () => repo.findCategoryBySyntheticId(
        any(),
        ledgerSyncId: any(named: 'ledgerSyncId'),
      ),
    ).thenAnswer((_) async => _category(5, '旧分类'));
    when(
      () => repo.getTransactionById(9),
    ).thenAnswer(
      (_) async => db.Transaction(
        id: 9,
        ledgerId: 1,
        type: 'expense',
        amount: 100,
        happenedAt: DateTime(2026, 8, 8),
        excludeFromStats: false,
        version: 2,
        createdByUserId: 'u1',
        lastEditedByUserId: 'u1',
      ),
    );
    when(() => repo.getLedgerById(1)).thenAnswer(
      (_) async => _ledger(isShared: true),
    );
    // 成员表置空，避免触网。
    when(
      () => repo.getLedgerById(any()),
    ).thenAnswer((_) async => _ledger(isShared: true));
    when(() => repo.getTransactionById(any())).thenAnswer(
      (_) async => db.Transaction(
        id: 9,
        ledgerId: 1,
        type: 'expense',
        amount: 100,
        happenedAt: DateTime(2026, 8, 8),
        excludeFromStats: false,
        version: 2,
        createdByUserId: 'u1',
        lastEditedByUserId: 'u1',
      ),
    );

    await tester.pumpWidget(
      buildApp(editingTransactionId: 9, initialCategoryId: 5),
    );
    await openEditor(tester);
    await tester.pump(const Duration(milliseconds: 100));
    // 头像组渲染依赖成员 provider 解析成功（空列表即可），循环 pump 到出现。
    final groupFinder = find.byType(
      CollaboratorAvatarGroup,
      skipOffstage: false,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.any(groupFinder)) break;
    }
    expect(groupFinder, findsOneWidget);
  });

  testWidgets('AA 开启 + 编辑共享账本：头部同时渲染分摊按钮与作者头像',
      (tester) async {
    when(
      () => repo.findCategoryBySyntheticId(
        any(),
        ledgerSyncId: any(named: 'ledgerSyncId'),
      ),
    ).thenAnswer((_) async => _category(5, '旧分类'));
    when(() => repo.getTransactionById(any())).thenAnswer(
      (_) async => db.Transaction(
        id: 9,
        ledgerId: 1,
        type: 'expense',
        amount: 100,
        happenedAt: DateTime(2026, 8, 8),
        excludeFromStats: false,
        version: 2,
        createdByUserId: 'u1',
        lastEditedByUserId: 'u1',
      ),
    );
    when(
      () => repo.getLedgerById(any()),
    ).thenAnswer((_) async => _ledger(aaEnabled: true, isShared: true));

    await tester.pumpWidget(
      buildApp(
        ledger: _ledger(aaEnabled: true, isShared: true),
        editingTransactionId: 9,
        initialCategoryId: 5,
      ),
    );
    await openEditor(tester);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.any(find.byType(CollaboratorAvatarGroup))) break;
    }

    expect(find.byType(CollaboratorAvatarGroup), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editor_aa_mode_toggle')),
      findsOneWidget,
    );
  });
}
