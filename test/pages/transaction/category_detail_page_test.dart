/// 分类汇总页（CategoryDetailPage）组件测试。
///
///   1. 汇总卡片「总金额 / 平均金额」带当前账本本位币符号（CNY → ¥）；
///   2. 分类分组标题的支出小计带币种符号；
///   3. 日期分组标题的支出小计带币种符号（与主页 transaction_list 口径一致）；
///   4. 仅统计当前账本，交易行不渲染账本标签。
///
/// 测试基建与 home_page_test 一致：mocktail 仿 LocalRepository + ProviderScope
/// override；数据流均为立即发射的 Stream.value，分步 pump 替代 pumpAndSettle。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/transaction/category_detail_page.dart';
import 'package:spitout/providers/core/database_providers.dart';

/// Mock 整个 LocalRepository：仅 stub 本页用到的两个 watch 方法，
/// 其余方法不会被调用（删除/编辑等回调在测试中不触发）。
class _MockRepo extends Mock implements LocalRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late db.Ledger testLedger;
  late db.Category catFood; // 一级分类
  late db.Category catTakeout; // 二级分类（parentId = catFood.id）
  late db.Transaction txFood; // 属于一级分类，金额 10
  late db.Transaction txTakeout; // 属于二级分类，金额 20

  setUp(() {
    repo = _MockRepo();
    testLedger = db.Ledger(
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
    catFood = const db.Category(
      id: 10,
      name: '餐饮',
      kind: 'expense',
      sortOrder: 0,
      level: 1,
    );
    catTakeout = const db.Category(
      id: 101,
      name: '外卖',
      kind: 'expense',
      sortOrder: 1,
      parentId: 10,
      level: 2,
    );
    txFood = db.Transaction(
      id: 1,
      ledgerId: 1,
      type: 'expense',
      amount: 1000,
      categoryId: 10,
      happenedAt: DateTime(2026, 7, 20, 12),
      note: '午餐',
      currencyCode: 'CNY',
      nativeAmount: 1000,
      excludeFromStats: false,
      version: 1,
    );
    txTakeout = db.Transaction(
      id: 2,
      ledgerId: 1,
      type: 'expense',
      amount: 2000,
      categoryId: 101,
      happenedAt: DateTime(2026, 7, 20, 18),
      note: '晚餐',
      currencyCode: 'CNY',
      nativeAmount: 2000,
      excludeFromStats: false,
      version: 1,
    );

    // 每次调用返回全新 stream，避免单订阅流被二次 listen 抛异常。
    when(
      () => repo.watchTransactionsByCategory(
        any(),
        ledgerId: any(named: 'ledgerId'),
        includeSubCategories: any(named: 'includeSubCategories'),
      ),
    ).thenAnswer(
      (_) => Stream<List<db.Transaction>>.value([txFood, txTakeout]),
    );
    when(
      () => repo.watchCategoryWithSubs(any()),
    ).thenAnswer((_) => Stream<List<db.Category>>.value([catFood, catTakeout]));
  });

  /// 构建带 overrides 的测试宿主：固定当前账本（CNY）与 mock 仓库。
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
        currentLedgerProvider.overrideWith(
          (ref) => Stream<db.Ledger?>.value(testLedger),
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
        home: CategoryDetailPage(categoryId: 10, categoryName: '餐饮'),
      ),
    );
  }

  /// 分步 pump：让 stream 首值发射 + 首帧渲染完成。
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('汇总卡片：总金额与平均金额带币种符号', (tester) async {
    await tester.pumpWidget(buildApp());
    await prime(tester);

    // 总金额 10 + 20 = 30 → ¥ 30；平均 30 / 2 = 15 → ¥ 15。
    expect(find.text('¥ 30'), findsOneWidget, reason: '汇总卡总金额应带币种符号');
    expect(find.text('¥ 15'), findsOneWidget, reason: '汇总卡平均金额应带币种符号');
  });

  testWidgets('分类分组标题与日期分组标题：支出小计均带币种符号', (tester) async {
    await tester.pumpWidget(buildApp());
    await prime(tester);

    // 一级分类组：组标题「支出 ¥ 10」+ 组内日期标题「支出 ¥ 10」。
    expect(
      find.text('支出 ¥ 10'),
      findsNWidgets(2),
      reason: '一级分类组标题与日期标题的支出小计都应带币种符号',
    );
    // 二级分类组：组标题「支出 ¥ 20」+ 组内日期标题「支出 ¥ 20」。
    expect(
      find.text('支出 ¥ 20'),
      findsNWidgets(2),
      reason: '二级分类组标题与日期标题的支出小计都应带币种符号',
    );
  });

  testWidgets('仅统计当前账本：交易行不渲染账本标签，二级分类显示全名', (tester) async {
    await tester.pumpWidget(buildApp());
    await prime(tester);

    // 跨账本模式已下线：页面任何位置都不应出现账本名标签。
    expect(find.text('测试账本'), findsNothing, reason: '仅统计当前账本，交易行不应渲染账本标签');

    // 二级分类组标题与交易行均显示「父 / 子」全名。
    expect(
      find.text('餐饮 / 外卖'),
      findsNWidgets(2),
      reason: '二级分类应在组标题与交易行显示「父 / 子」全名',
    );

    // 交易行金额带原币种符号（支出为负号 + 符号后带空格）。
    expect(find.text('- ¥ 10'), findsOneWidget, reason: '一级分类交易行金额渲染');
    expect(find.text('- ¥ 20'), findsOneWidget, reason: '二级分类交易行金额渲染');
  });
}
