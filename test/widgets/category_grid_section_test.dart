/// 记账页分类网格（CategoryGridSection）测试。
///
/// 缓存化改造后的核心行为：
///   1. 分类树来自 categoryPickerTreeProvider，数据就绪即同步渲染
///      （无"空白 → 出现"的多帧跳变）；
///   2. 新建模式：首个数据帧后默认选中第一个一级分类并自动展开其子分类；
///   3. 点击一级分类：上报选中，含子分类的展开、无子分类的收起；
///   4. 编辑模式（initialSelectedId 为二级分类）：首帧即展开其父分类；
///   5. 空树：显示空态与「编辑分类」入口；
///   6. 共享账本 Editor：编辑入口置灰（只读文案、点击不跳转）；
///      Owner / 个人账本：入口保持可点并跳转分类管理页。
///
/// provider 用 override 直接注入内存树，与 db 的集成由
/// test/providers/category_picker_tree_provider_test.dart 覆盖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/category_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/category/category_picker_providers.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/core/router/routes.dart';
import 'package:spitout/widgets/category_grid_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构造测试分类（名称不含 '_'，避开 CategoryUtils 的 key 翻译路径，
  /// 保证显示名与传入名一致）。
  Category cat(int id, String name, {int? parentId, int level = 1}) {
    return Category(
      id: id,
      name: name,
      kind: 'expense',
      sortOrder: id,
      parentId: parentId,
      level: level,
      syncId: 'sync-$id',
    );
  }

  /// 两个一级分类（餐饮含一个二级"早餐"），用于多数用例。
  final tree = CategoryPickerTree(
    topLevel: [cat(1, '测试餐饮'), cat(2, '测试交通')],
    children: {
      1: [cat(11, '测试早餐', parentId: 1, level: 2)],
    },
  );

  /// 构造测试账本（只填角色/共享标记关心字段，其余给固定值）。
  Ledger ledger({required bool isShared, required String myRole}) => Ledger(
    id: 1,
    name: '测试账本',
    currency: 'CNY',
    type: 'normal',
    createdAt: DateTime.utc(2026, 1, 1),
    myRole: myRole,
    memberCount: 2,
    isShared: isShared,
    monthStartDay: 1,
    storageMode: 'cloud',
    aaEnabled: false,
  );

  /// 分类管理页路由标记：跳转成功即渲染该文本。
  Widget manageMarker(BuildContext context) =>
      const Scaffold(body: Text('MANAGE_MARKER'));

  /// 构建测试宿主：注入分类树 provider override + 本地化上下文。
  ///
  /// [ledger] 为当前账本 override（null 表示未加载到账本），
  /// 用于覆盖共享账本 Editor/Owner 两种角色下的「编辑分类」入口行为；
  /// 注册 Routes.categoryManage 命名的 marker 路由，验证入口点击是否跳转。
  Widget buildHarness({
    required CategoryPickerTree injected,
    required ValueChanged<Category> onCategorySelected,
    int? initialSelectedId,
    Ledger? ledger,
  }) {
    return ProviderScope(
      overrides: [
        categoryPickerTreeProvider(
          'expense',
        ).overrideWith((ref) => Stream.value(injected)),
        currentLedgerProvider.overrideWith(
          (ref) => Stream<Ledger?>.value(ledger),
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
        routes: {Routes.categoryManage: manageMarker},
        home: Scaffold(
          body: CategoryGridSection(
            kind: 'expense',
            initialSelectedId: initialSelectedId,
            onCategorySelected: onCategorySelected,
          ),
        ),
      ),
    );
  }

  testWidgets('数据就绪即渲染网格；新建模式默认选中第一个分类并展开其子分类', (tester) async {
    final selected = <Category>[];
    await tester.pumpWidget(
      buildHarness(injected: tree, onCategorySelected: selected.add),
    );
    // Stream.value 首个事件 + postFrame 默认选中，各需一帧
    await tester.pump();
    await tester.pump();

    expect(find.text('测试餐饮'), findsOneWidget);
    expect(find.text('测试交通'), findsOneWidget);
    // 默认选中第一个一级分类（含子分类 → 子分类卡片同帧展开）
    expect(selected.map((c) => c.id), [1]);
    expect(find.text('测试早餐'), findsOneWidget);
  });

  testWidgets('点击无子分类的一级分类：上报选中并收起子分类卡片', (tester) async {
    final selected = <Category>[];
    await tester.pumpWidget(
      buildHarness(injected: tree, onCategorySelected: selected.add),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('测试交通'));
    await tester.pump();

    expect(selected.last.id, 2);
    // 无子分类 → 展开区收起
    expect(find.text('测试早餐'), findsNothing);
  });

  testWidgets('编辑模式：初始二级分类首帧即展开其父分类', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        injected: tree,
        initialSelectedId: 11,
        onCategorySelected: (_) {},
      ),
    );
    await tester.pump();

    // 父分类子卡片展开，二级分类可见（无需再点父分类）
    expect(find.text('测试早餐'), findsOneWidget);
  });

  testWidgets('空树：显示空态与编辑分类入口', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        injected: CategoryPickerTree.empty,
        onCategorySelected: (_) {},
      ),
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.categoryEmpty), findsOneWidget);
    expect(find.text(l10n.txEditCategory), findsOneWidget);
  });

  testWidgets('共享账本 Editor：编辑入口置灰，文案只读提示，点击不跳转', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        injected: tree,
        onCategorySelected: (_) {},
        ledger: ledger(isShared: true, myRole: 'editor'),
      ),
    );
    await tester.pump();
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    // 文案切换为只读提示（「编辑分类」入口不出现）
    expect(find.text(l10n.txEditCategoryReadOnly), findsOneWidget);
    expect(find.text(l10n.txEditCategory), findsNothing);

    // 置灰态 onTap 为 null：点击不跳转分类管理页
    await tester.tap(find.text(l10n.txEditCategoryReadOnly));
    await tester.pumpAndSettle();
    expect(find.text('MANAGE_MARKER'), findsNothing);
  });

  testWidgets('共享账本 Owner：编辑入口保持可点，点击跳转分类管理页', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        injected: tree,
        onCategorySelected: (_) {},
        ledger: ledger(isShared: true, myRole: 'owner'),
      ),
    );
    await tester.pump();
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.txEditCategory), findsOneWidget);

    await tester.tap(find.text(l10n.txEditCategory));
    await tester.pumpAndSettle();
    expect(find.text('MANAGE_MARKER'), findsOneWidget);
  });

  testWidgets('个人账本：编辑入口保持可点，文案为编辑分类', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        injected: tree,
        onCategorySelected: (_) {},
        ledger: ledger(isShared: false, myRole: 'owner'),
      ),
    );
    await tester.pump();
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.txEditCategory), findsOneWidget);
    expect(find.text(l10n.txEditCategoryReadOnly), findsNothing);
  });
}
