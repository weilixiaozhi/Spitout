// 周期账单列表页（RecurringTransactionPage）组件测试。
//
// 需求锚点（以页面行为为准，而非实现抄写）：
//   1. 空列表展示「暂无周期账单 + 点击右上角 + 按钮添加」引导；
//   2. 非空列表首项为使用说明卡片，随后逐条渲染周期账单卡片；
//   3. 卡片展示分类名 / 账本名 / 频率描述 / 金额 / 备注 / 最后生成日期；
//   4. 频率描述口径：interval=1 用「每天/每周/每月/每年」，interval>1 用「每 N 天/周/个月/年」；
//   5. 开关切换调用 repository.toggleRecurringTransaction 并刷新列表；
//   6. 切换失败保持原开关状态并 toast 提示，不抛出异常；
//   7. 加载失败展示统一失败文案 + 重试，重试后恢复列表；
//   8. 点击卡片进入编辑页（携带当前周期账单），右上角 + 进入新建页。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/transaction/recurring_transaction_edit_page.dart';
import 'package:spitout/pages/transaction/recurring_transaction_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// Mock 整个 LocalRepository：未 stub 的方法返回默认值，不抛异常。
class _MockRepo extends Mock implements LocalRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late db.Category testCategory;
  late db.Ledger testLedger;

  /// 构造测试账本：仅填页面渲染所需字段，其余取固定值。
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

  /// 构造测试分类：name 使用自定义名（非 key），避免走 key 翻译分支干扰断言。
  db.Category buildCategory() => db.Category(
        id: 1,
        name: '餐饮',
        kind: 'expense',
        icon: 'utensils',
        sortOrder: 0,
        parentId: null,
        level: 1,
      );

  /// 构造周期账单模板。
  db.RecurringTransaction buildRecurring({
    int id = 1,
    int amount = 5000,
    String frequency = 'monthly',
    int interval = 1,
    int? dayOfMonth = 15,
    String? note = '房租',
    DateTime? lastGeneratedDate,
    bool enabled = true,
  }) {
    return db.RecurringTransaction(
      id: id,
      ledgerId: 1,
      type: 'expense',
      amount: amount,
      categoryId: 1,
      note: note,
      frequency: frequency,
      interval: interval,
      dayOfMonth: dayOfMonth,
      startDate: DateTime(2026, 1, 1),
      lastGeneratedDate: lastGeneratedDate,
      enabled: enabled,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  /// 注入 mock repo 并构建页面宿主。
  ///
  /// 设计意图：列表页唯一的数据来源是 allRecurringTransactionsProvider
  /// （StreamProvider.autoDispose），卡片内分类/账本名走 family 缓存查询；
  /// 全部 override 为 mock 返回值，规避真实数据库初始化成本与不确定性。
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
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
        home: const RecurringTransactionPage(),
      ),
    );
  }

  /// 注册列表流：每次调用返回全新 stream，供 invalidate 后重复订阅。
  void registerStream(List<db.RecurringTransaction> items) {
    when(() => repo.watchAllRecurringTransactions())
        .thenAnswer((_) => Stream.value(items));
  }

  /// 注册卡片展示所需的分类/账本缓存查询。
  void registerLookups() {
    when(() => repo.getCategoryById(1)).thenAnswer((_) async => testCategory);
    when(() => repo.getLedgerById(1)).thenAnswer((_) async => testLedger);
  }

  setUp(() {
    repo = _MockRepo();
    testCategory = buildCategory();
    testLedger = buildLedger();
    registerLookups();
  });

  testWidgets('空列表展示空态引导：暂无周期账单 + 添加提示', (tester) async {
    registerStream(const []);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionPage)),
    );
    expect(find.text(l10n.recurringTransactionEmpty), findsOneWidget);
    expect(find.text(l10n.recurringTransactionEmptyHint), findsOneWidget);
    // 空态下不应渲染使用说明卡片（其只存在于非空列表分支）。
    expect(find.text(l10n.recurringTransactionUsageTitle), findsNothing);
  });

  testWidgets('非空列表：使用说明卡片 + 分类/账本/频率/金额/备注逐项展示', (tester) async {
    registerStream([
      buildRecurring(
        lastGeneratedDate: DateTime(2026, 8, 15),
      ),
    ]);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionPage)),
    );
    // 使用说明卡片
    expect(find.text(l10n.recurringTransactionUsageTitle), findsOneWidget);
    expect(
      find.text(l10n.recurringTransactionUsageContent),
      findsOneWidget,
    );
    // 卡片信息区：分类名 / 账本名 / 频率 / 金额（支出为负）/ 备注
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('测试账本'), findsOneWidget);
    expect(find.text('每月'), findsOneWidget);
    expect(find.text('-50'), findsOneWidget);
    expect(find.text('房租'), findsOneWidget);
    // 最后生成日期（8/15）随卡片展示
    expect(find.text('8/15'), findsOneWidget);
  });

  testWidgets('频率描述口径：interval=1 与 interval>1 文案区分', (tester) async {
    registerStream([
      buildRecurring(id: 1, frequency: 'daily', interval: 1),
      buildRecurring(id: 2, frequency: 'weekly', interval: 1),
      buildRecurring(id: 3, frequency: 'monthly', interval: 1),
      buildRecurring(id: 4, frequency: 'yearly', interval: 1),
      buildRecurring(id: 5, frequency: 'daily', interval: 2),
      buildRecurring(id: 6, frequency: 'weekly', interval: 2),
      buildRecurring(id: 7, frequency: 'monthly', interval: 2),
      buildRecurring(id: 8, frequency: 'yearly', interval: 2),
    ]);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionPage)),
    );
    // ListView.builder 懒构建：逐项滚动到可视区再断言，避免视口外未构建。
    final scrollable = find.byType(Scrollable).first;
    for (final label in [
      '每天',
      '每周',
      '每月',
      '每年',
      '每 2 天',
      '每 2 周',
      '每 2 个月',
      '每 2 年',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 80,
          scrollable: scrollable);
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(l10n.recurringTransactionEveryNDays(2)), findsOneWidget);
  });

  testWidgets('开关切换：调用 toggleRecurringTransaction 并重新订阅列表流', (tester) async {
    var streamCalls = 0;
    when(() => repo.watchAllRecurringTransactions()).thenAnswer((_) {
      streamCalls++;
      return Stream.value([buildRecurring()]);
    });
    when(() => repo.toggleRecurringTransaction(any(), any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(streamCalls, 1, reason: '首次渲染应订阅一次列表流');

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    verify(
      () => repo.toggleRecurringTransaction(1, false),
    ).called(1);
    // invalidate 后应重新发起订阅（回到数据流），而非停留在旧快照。
    expect(streamCalls, greaterThan(1));
  });

  testWidgets('开关切换失败：保持原状态并 toast 提示，不向上抛异常', (tester) async {
    registerStream([buildRecurring()]);
    when(() => repo.toggleRecurringTransaction(any(), any()))
        .thenThrow(Exception('db down'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionPage)),
    );
    expect(find.text(l10n.commonOperationFailed), findsOneWidget);
    // 开关视觉状态仍为启用，说明失败未提交本地状态。
    expect(tester.widget<Switch>(switchFinder).value, isTrue);
    expect(tester.takeException(), isNull);
    // 推进 toast 自动消失定时器，避免测试结束时残留 pending timer。
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('加载失败展示统一文案 + 重试，点击重试后恢复列表', (tester) async {
    when(() => repo.watchAllRecurringTransactions())
        .thenThrow(Exception('load failed'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionPage)),
    );
    expect(find.text(l10n.commonOperationFailed), findsOneWidget);
    final retryFinder = find.text(l10n.analyticsRetry);
    expect(retryFinder, findsOneWidget);

    // 重试：invalidate 后重新走 provider，改 stub 为成功数据。
    registerStream([buildRecurring()]);
    await tester.tap(retryFinder);
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text(l10n.commonOperationFailed), findsNothing);
  });

  testWidgets('点击卡片进入编辑页且携带当前周期账单', (tester) async {
    registerStream([buildRecurring()]);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(find.byType(RecurringTransactionEditPage), findsOneWidget);
    // 编辑页应预填当前模板金额（50.00）。
    expect(find.text('50.00'), findsOneWidget);
  });

  testWidgets('右上角 + 进入新建周期账单页', (tester) async {
    registerStream(const []);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.addCircle));
    await tester.pumpAndSettle();

    expect(find.byType(RecurringTransactionEditPage), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecurringTransactionEditPage)),
    );
    expect(find.text(l10n.recurringTransactionAdd), findsWidgets);
  });
}
