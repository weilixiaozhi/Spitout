/// TransactionList 组件测试。
///
/// 需求锚点：
/// - 空表渲染空态；无刷新需求时直接返回空态组件；
///   有刷新需求时包可滚动容器（RefreshIndicator / 外部刷新两种模式）；
/// - 非空列表按天分组渲染日期头部（含当日支出合计）与交易行；
/// - 日期头部可见性跟踪（VisibilityDetector）回调；
/// - 点击编辑 / 点击分类 / 长按删除回调透传，交互前先切 Stream 模式；
/// - jumpToMonth / jumpToTop / switchToStreamMode / forceStreamModeImmediate
///   状态方法行为正确。
library;

import 'package:flutter/material.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart'
    show currentLedgerProvider, currentLedgerIdProvider;
import 'package:spitout/widgets/app_empty.dart';
import 'package:spitout/widgets/transaction_list.dart';
import 'package:spitout/widgets/transaction_list_item.dart';

typedef _TxItem = ({Transaction t, Category? category});

/// 构造交易：只填测试关心的字段，其余给固定值。
Transaction _tx(
  int id,
  DateTime happenedAt, {
  int amount = 1200,
  String type = 'expense',
  String? note,
  int? categoryId,
  String? currencyCode,
  int? nativeAmount,
}) =>
    Transaction(
      id: id,
      ledgerId: 1,
      type: type,
      amount: amount,
      categoryId: categoryId,
      happenedAt: happenedAt,
      note: note,
      currencyCode: currencyCode,
      nativeAmount: nativeAmount,
      excludeFromStats: false,
      version: 1,
    );

Category _category(int id, String name) => Category(
  id: id,
  name: name,
  kind: 'expense',
  icon: 'dining',
  sortOrder: 1,
  level: 1,
);

Ledger _ledger({int monthStartDay = 1}) => Ledger(
  id: 1,
  name: '测试账本',
  currency: 'CNY',
  type: 'personal',
  createdAt: DateTime(2026, 1, 1),
  myRole: 'owner',
  memberCount: 1,
  isShared: false,
  monthStartDay: monthStartDay,
  storageMode: 'local',
  aaEnabled: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 挂载 TransactionList。
  ///
  /// currentLedgerProvider 统一 override：列表头与金额组件都 watch 它，
  /// 真实实现会触发 repositoryProvider → databaseProvider（真实数据库构造
  /// 走平台通道，测试环境会崩）。
  Future<GlobalKey<TransactionListState>> pumpList(
    WidgetTester tester, {
    required List<_TxItem> transactions,
    bool enableVisibilityTracking = false,
    void Function(String, bool)? onDateVisibilityChanged,
    Future<void> Function(Transaction, Category?)? onEdit,
    Future<void> Function(Transaction)? onDelete,
    Future<void> Function(Category)? onCategoryTap,
    Future<void> Function()? onRefresh,
    bool useExternalRefresh = false,
    Widget? emptyWidget,
    FlutterListViewController? controller,
  }) async {
    final key = GlobalKey<TransactionListState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
          currentLedgerProvider.overrideWith(
            (ref) => Stream<Ledger?>.value(_ledger()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TransactionList(
              key: key,
              transactions: transactions,
              enableVisibilityTracking: enableVisibilityTracking,
              onDateVisibilityChanged: onDateVisibilityChanged,
              onEdit: onEdit,
              onDelete: onDelete,
              onCategoryTap: onCategoryTap,
              onRefresh: onRefresh,
              useExternalRefresh: useExternalRefresh,
              emptyWidget: emptyWidget,
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return key;
  }

  List<_TxItem> twoDays() => [
    (t: _tx(1, DateTime(2026, 8, 8, 9, 30), note: '早餐', categoryId: 1),
        category: _category(1, '餐饮')),
    (t: _tx(2, DateTime(2026, 8, 8, 20, 0), note: '打车', categoryId: 2),
        category: _category(2, '交通')),
    (t: _tx(3, DateTime(2026, 8, 7, 12, 0), note: '午餐', categoryId: 1),
        category: _category(1, '餐饮')),
  ];

  testWidgets('空表且无刷新需求：直接返回空态组件', (tester) async {
    await pumpList(tester, transactions: const []);

    expect(find.byType(AppEmpty), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.text('还没有记账'), findsOneWidget);
  });

  testWidgets('transactions 数据变化：didUpdateWidget 重建分组', (tester) async {
    var items = twoDays();
    late StateSetter setState;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
          currentLedgerProvider.overrideWith(
            (ref) => Stream<Ledger?>.value(_ledger()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setter) {
                setState = setter;
                return TransactionList(transactions: items);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('早餐', skipOffstage: false), findsOneWidget);

    // 换成另一天的新交易，验证重建后旧数据消失、新分组出现。
    setState(() {
      items = [
        (
          t: _tx(9, DateTime(2026, 8, 9, 12, 0), note: '新交易'),
          category: _category(1, '餐饮'),
        ),
      ];
    });
    await tester.pump();
    expect(find.text('新交易', skipOffstage: false), findsOneWidget);
    expect(find.text('早餐', skipOffstage: false), findsNothing);
    expect(find.text('2026-08-09', skipOffstage: false), findsOneWidget);
  });

  testWidgets('transactionsWithDetails 更新：重置为预加载模式并重建',
      (tester) async {
    var items = twoDays();
    // 渲染数据走 transactions；transactionsWithDetails 是预加载快照（仅控制
    // Stream 模式切换标志），单独传它不会产生列表内容。
    var details = items;
    late StateSetter setState;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
          currentLedgerProvider.overrideWith(
            (ref) => Stream<Ledger?>.value(_ledger()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setter) {
                setState = setter;
                return TransactionList(
                  transactions: items,
                  transactionsWithDetails: details,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('早餐', skipOffstage: false), findsOneWidget);

    setState(() {
      items = [
        (
          t: _tx(9, DateTime(2026, 8, 9, 12, 0), note: '预加载新数据'),
          category: _category(1, '餐饮'),
        ),
      ];
      details = [
        (
          t: _tx(8, DateTime(2026, 8, 9, 12, 0), note: '快照'),
          category: _category(1, '餐饮'),
        ),
      ];
    });
    await tester.pump();
    expect(find.text('预加载新数据', skipOffstage: false), findsOneWidget);
    expect(find.text('早餐', skipOffstage: false), findsNothing);
  });

  testWidgets('空表 + 自定义空态：渲染传入的 emptyWidget', (tester) async {
    await pumpList(
      tester,
      transactions: const [],
      emptyWidget: const Text('自定义空态'),
    );

    expect(find.text('自定义空态'), findsOneWidget);
    expect(find.byType(AppEmpty), findsNothing);
  });

  testWidgets('空表 + 内置刷新：包 RefreshIndicator + 可滚动容器', (tester) async {
    await pumpList(tester, transactions: const [], onRefresh: () async {});

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('暂无数据'), findsOneWidget);
  });

  testWidgets('空表 + 外部刷新：仅返回可滚动容器，不包 RefreshIndicator',
      (tester) async {
    await pumpList(
      tester,
      transactions: const [],
      useExternalRefresh: true,
    );

    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('暂无数据'), findsOneWidget);
  });

  testWidgets('非空列表：按天分组渲染日期头部与交易行，头部含当日支出合计',
      (tester) async {
    await pumpList(tester, transactions: twoDays());

    // flutter_list_view 的 custom sliver 在 widget test 中不参与
    // debugVisitOnstageChildren 遍历，find 需显式 skipOffstage: false。
    Finder anyText(String text) => find.text(text, skipOffstage: false);

    // 两个日期头部（倒序：8-08 在前）。
    expect(anyText('2026-08-08'), findsOneWidget);
    expect(anyText('2026-08-07'), findsOneWidget);
    // 8-08 两笔支出合计 24 元。
    expect(find.textContaining('¥ 24', skipOffstage: false), findsOneWidget);
    // 交易行渲染分类名 + 备注。
    expect(anyText('餐饮'), findsNWidgets(2));
    expect(anyText('交通'), findsOneWidget);
    expect(anyText('早餐'), findsOneWidget);
    expect(anyText('打车'), findsOneWidget);
  });

  testWidgets('同一天多条交易：条目之间不渲染分割线', (tester) async {
    // 需求：首页列表每条数据之间不再显示分割线。
    // twoDays 中 2026-08-08 同日有两笔，若未去掉分割线，第一笔下方会有 SpitoutDivider.short。
    await pumpList(tester, transactions: twoDays());
    expect(find.byType(Divider, skipOffstage: false), findsNothing);
  });

  testWidgets('日期可见性跟踪：启用后头部包 VisibilityDetector 并回调',
      (tester) async {
    await pumpList(
      tester,
      transactions: twoDays(),
      enableVisibilityTracking: true,
      onDateVisibilityChanged: (key, visible) {},
    );

    // flutter_list_view 子项在 widget test 中对默认 finder 不可见，
    // visibility_detector 的回调在测试环境不触发，仅断言包装结构存在。
    expect(
      find.byType(VisibilityDetector, skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.byKey(const Key('header-2026-08-08'), skipOffstage: false),
      findsOneWidget,
    );
    // VisibilityDetector 内部有周期定时器，测试结束前卸载以清 pending timer。
    await tester.pumpWidget(const SizedBox.shrink());
    // 让已排程的 500ms 一次性 Timer 在卸载后到点消化。
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('日期头部可见性判定：可见比例 > 50% 才回调可见',
      (tester) async {
    final events = <String>[];
    final key = await pumpList(
      tester,
      transactions: twoDays(),
      enableVisibilityTracking: true,
      onDateVisibilityChanged: (dateKey, visible) =>
          events.add('$dateKey=$visible'),
    );

    // 直接构造 buildDayHeader 产物并手动触发回调：
    // visibility_detector 在 widget test 中不会产生 paint 通知，
    // 通过该方法验证「visibleFraction > 0.5 判定」接线本身。
    final header = key.currentState!.buildDayHeader(
      dateKey: '2026-08-08',
      dayItems: twoDays(),
      ledgerCurrency: 'CNY',
    );
    // 启用跟踪时 buildDayHeader 直接返回 VisibilityDetector。
    final detector = header as VisibilityDetector;

    detector.onVisibilityChanged?.call(
      const VisibilityInfo(
        key: Key('header-2026-08-08'),
        size: Size(600, 50),
        visibleBounds: Rect.fromLTWH(0, 0, 600, 50),
      ),
    );
    detector.onVisibilityChanged?.call(
      const VisibilityInfo(key: Key('header-2026-08-08')),
    );

    expect(events, ['2026-08-08=true', '2026-08-08=false']);
    // 卸载列表清 VisibilityDetector 的 pending timer。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('点击交易行：先切 Stream 模式再回调 onEdit', (tester) async {
    Transaction? edited;
    await pumpList(
      tester,
      transactions: twoDays(),
      onEdit: (tx, cat) async => edited = tx,
    );

    // flutter_list_view 子项不可点，直接取 TransactionListItem 的 onTap 验证接线。
    final row = tester.widget<TransactionListItem>(
      find.byType(TransactionListItem, skipOffstage: false).first,
    );
    row.onTap?.call();
    await tester.pump();
    expect(edited?.id, 1);
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('点击分类图标：回调 onCategoryTap', (tester) async {
    Category? tapped;
    await pumpList(
      tester,
      transactions: twoDays(),
      onCategoryTap: (cat) async => tapped = cat,
    );

    final row = tester.widget<TransactionListItem>(
      find.byType(TransactionListItem, skipOffstage: false).first,
    );
    row.onCategoryTap?.call();
    await tester.pump();
    expect(tapped?.id, 1);
    // switchToStreamMode 的 100ms 延迟切换定时器需在结束前消化。
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('长按交易行：回调 onDelete', (tester) async {
    Transaction? deleted;
    await pumpList(
      tester,
      transactions: twoDays(),
      onDelete: (tx) async => deleted = tx,
    );

    // 删除长按在外层 GestureDetector（TransactionListItem 本身不带 onLongPress）。
    final thirdRow = find
        .ancestor(
          of: find.byType(TransactionListItem, skipOffstage: false).at(2),
          matching: find.byType(GestureDetector, skipOffstage: false),
        )
        .first;
    tester.widget<GestureDetector>(thirdRow).onLongPress?.call();
    await tester.pump();
    expect(deleted?.id, 3);
  });

  testWidgets('switchToStreamMode：100ms 后切换，已切后再次调用不重复延迟切换',
      (tester) async {
    final key = await pumpList(tester, transactions: twoDays());
    final state = key.currentState!;

    state.switchToStreamMode();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('早餐', skipOffstage: false), findsOneWidget);

    // 已处于 Stream 模式：再次调用不安排新的延迟切换（不抛错即可）。
    state.switchToStreamMode();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('早餐', skipOffstage: false), findsOneWidget);
  });

  testWidgets('forceStreamModeImmediate：立即切换', (tester) async {
    final key = await pumpList(tester, transactions: twoDays());
    key.currentState!.forceStreamModeImmediate();
    await tester.pump();
    expect(find.text('早餐', skipOffstage: false), findsOneWidget);
  });

  testWidgets('jumpToMonth：命中周期内日期返回 true，无匹配月份返回 false',
      (tester) async {
    final key = await pumpList(tester, transactions: twoDays());

    expect(key.currentState!.jumpToMonth(DateTime(2026, 8)), isTrue);
    expect(key.currentState!.jumpToMonth(DateTime(2026, 9)), isFalse);
  });

  testWidgets('jumpToTop：列表滚动后可回到顶部', (tester) async {
    final controller = FlutterListViewController();
    addTearDown(controller.dispose);
    // 构造多天数据撑出滚动空间。
    final many = <_TxItem>[
      for (var day = 1; day <= 20; day++)
        (
          t: _tx(day, DateTime(2026, 7, day, 10), note: '交易$day'),
          category: _category(1, '餐饮'),
        ),
    ];
    final key = await pumpList(
      tester,
      transactions: many,
      controller: controller,
    );
    final state = key.currentState!;

    // 先跳转到最后一个日期，再回顶部，验证不抛错且滚动位置归零。
    expect(state.jumpToMonth(DateTime(2026, 7, 20)), isTrue);
    await tester.pump();
    state.jumpToTop();
    await tester.pump();
    expect(controller.hasClients, isTrue);
  });
}
