// 分类模板库页面测试（flat / hierarchical 模板页 + 管理页入口）
//
// 验证内容：
//   1. 管理页：正常模式在标题下显示"一级模板/二级模板"两个独立按钮（非文字链），
//      删除模式隐藏；点击可 push 到对应模板页
//   2. flat 页：网格渲染模板条目；0 勾选时"添加"禁用；勾选/全选/取消全选联动底部计数
//   3. flat 页：已添加条目置灰不可再选——syncId 命中 / 手动创建同名（syncId 不同源）双通道
//   4. flat 页：添加流程 = 二次确认弹窗 → createCategory（确定性 syncId）→ 成功 toast
//   5. hierarchical 页：父行展开/收起子类；子类独立勾选不连带父（计数 1）；
//      勾选父复选框连带全选该父全部未添加子类
//   6. hierarchical 页：父已在表时子类单独勾选，写入走 createSubCategory 挂到已有父 id
//      ——syncId 命中 / 手动创建同名父（syncId 不同源，名称兜底解析）两种路径，
//      均不再新建父分类（2026-07-24 实机报错场景的回归测试）

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/category/category_manage_page.dart';
import 'package:spitout/pages/category/category_template_flat_page.dart';
import 'package:spitout/pages/category/category_template_hierarchical_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/services/data/seed_service.dart';

/// Mock 整个 BaseRepository，按需 stub 模板页用到的方法。
class _MockRepo extends Mock implements BaseRepository {}

typedef _CategoryWithCount = ({db.Category category, int transactionCount});

/// 确定性 syncId（与 seed / 模板页"已添加"判定同源）
String _sid(int level, String key) => SeedService.deterministicCategorySyncId(
    kind: 'expense', level: level, key: key);

db.Category _category({
  required int id,
  required String name,
  required int level,
  int? parentId,
  int sortOrder = 0,
  String? syncId,
}) {
  return db.Category(
    id: id,
    name: name,
    kind: 'expense',
    icon: 'utensils',
    sortOrder: sortOrder,
    parentId: parentId,
    level: level,
    syncId: syncId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    // 模板写入路径 stub：createCategory 返回新父 id 100，createSubCategory 返回 200
    when(() => repo.createCategory(
          name: any(named: 'name'),
          kind: any(named: 'kind'),
          icon: any(named: 'icon'),
          sortOrder: any(named: 'sortOrder'),
          syncId: any(named: 'syncId'),
        )).thenAnswer((_) async => 100);
    when(() => repo.createSubCategory(
          parentId: any(named: 'parentId'),
          name: any(named: 'name'),
          kind: any(named: 'kind'),
          icon: any(named: 'icon'),
          sortOrder: any(named: 'sortOrder'),
          syncId: any(named: 'syncId'),
        )).thenAnswer((_) async => 200);
  });

  /// 构建测试宿主。
  /// [home] 默认管理页（入口测试），可指定模板页（页面行为测试）。
  /// [cats] 模拟 categories 表现有内容（"已添加"判定数据源）。
  Widget buildApp({Widget? home, List<_CategoryWithCount> cats = const []}) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        // ledgerId=0：跳过写入后的 PostProcessor.sync 触发（同步非本测试关注点）
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 0),
        categoriesWithCountProvider.overrideWith(
          (ref) => Stream<List<_CategoryWithCount>>.value(cats),
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
        home: home ?? const CategoryManagePage(),
      ),
    );
  }

  /// 分步 pump：让 stream 首帧 + 页面加载完成
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  // ==================== 管理页入口 ====================

  group('管理页模板库入口', () {
    testWidgets('正常模式显示"一级模板/二级模板"按钮（非文字链）', (tester) async {
      await tester.pumpWidget(buildApp(cats: [
        (category: _category(id: 1, name: '餐饮', level: 1), transactionCount: 0),
      ]));
      await prime(tester);

      expect(find.text('一级模板'), findsOneWidget, reason: '标题下应有一级模板入口');
      expect(find.text('二级模板'), findsOneWidget, reason: '标题下应有二级模板入口');
      // 入口必须是独立按钮，不再是 GestureDetector 文字链。
      // 注意：OutlinedButton.icon 工厂创建的是私有子类 _OutlinedButtonWithIcon，
      // find.byType 是 runtimeType 精确匹配（不含子类），须用 bySubtype 判定。
      expect(
        find.ancestor(
          of: find.text('一级模板'),
          matching: find.bySubtype<OutlinedButton>(),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('二级模板'),
          matching: find.bySubtype<OutlinedButton>(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('点击"一级模板"push 到一级分类模板页', (tester) async {
      await tester.pumpWidget(buildApp(cats: [
        (category: _category(id: 1, name: '餐饮', level: 1), transactionCount: 0),
      ]));
      await prime(tester);

      await tester.tap(find.text('一级模板'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CategoryTemplateFlatPage), findsOneWidget);
      expect(find.text('一级分类模板'), findsOneWidget, reason: '应显示模板页标题');
    });

    testWidgets('点击"二级模板"push 到二级分类模板页', (tester) async {
      await tester.pumpWidget(buildApp(cats: [
        (category: _category(id: 1, name: '餐饮', level: 1), transactionCount: 0),
      ]));
      await prime(tester);

      await tester.tap(find.text('二级模板'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CategoryTemplateHierarchicalPage), findsOneWidget);
      expect(find.text('二级分类模板'), findsOneWidget, reason: '应显示模板页标题');
    });

    testWidgets('删除模式隐藏模板入口', (tester) async {
      await tester.pumpWidget(buildApp(cats: [
        (category: _category(id: 1, name: '餐饮', level: 1), transactionCount: 0),
      ]));
      await prime(tester);

      await tester.tap(find.text('删除分类'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('一级模板'), findsNothing, reason: '删除模式应隐藏一级模板入口');
      expect(find.text('二级模板'), findsNothing, reason: '删除模式应隐藏二级模板入口');
      expect(find.text('确认删除'), findsOneWidget, reason: '删除模式应显示确认删除');
    });
  });

  // ==================== flat 模板页 ====================

  group('flat 模板页', () {
    testWidgets('0 勾选时"添加"按钮禁用，勾选后启用', (tester) async {
      await tester.pumpWidget(buildApp(home: const CategoryTemplateFlatPage()));
      await prime(tester);

      // 0 勾选：计数为 0，添加按钮禁用（onPressed 为 null）
      expect(find.text('本次已勾选 0 项'), findsOneWidget);
      FilledButton addButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '添加'),
      );
      expect(addButton.onPressed, isNull, reason: '0 勾选时添加按钮应为禁用态');

      // 勾选"餐饮"（flat 清单首项，首屏可见）
      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('本次已勾选 1 项'), findsOneWidget);
      addButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '添加'),
      );
      expect(addButton.onPressed, isNotNull, reason: '有勾选时添加按钮应可用');
    });

    testWidgets('全选/取消全选联动底部计数', (tester) async {
      await tester.pumpWidget(buildApp(home: const CategoryTemplateFlatPage()));
      await prime(tester);

      // 全选：选中全部未添加条目（flat 共 45 个）
      await tester.tap(find.text('全选'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('本次已勾选 ${SeedService.flatExpenseCategoryKeys.length} 项'),
        findsOneWidget,
        reason: '全选应选中全部 ${SeedService.flatExpenseCategoryKeys.length} 个模板条目',
      );

      // 已全选状态再点 → 取消全选
      await tester.tap(find.text('取消全选'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('本次已勾选 0 项'), findsOneWidget);
    });

    testWidgets('已添加条目置灰不可再选（syncId 命中）', (tester) async {
      // categories 表已存在 dining（确定性 syncId 命中）→ 模板页显示"已添加"
      await tester.pumpWidget(buildApp(
        home: const CategoryTemplateFlatPage(),
        cats: [
          (
            category: _category(
                id: 1, name: '餐饮', level: 1, syncId: _sid(1, 'dining')),
            transactionCount: 0,
          ),
        ],
      ));
      await prime(tester);

      // 点击已添加的"餐饮"：不产生勾选
      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('本次已勾选 0 项'), findsOneWidget,
          reason: '已添加条目不可再勾选');

      // 全选只作用于未添加条目（45 - 1 = 44）
      await tester.tap(find.text('全选'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('本次已勾选 ${SeedService.flatExpenseCategoryKeys.length - 1} 项'),
        findsOneWidget,
        reason: '全选应排除已添加条目',
      );
    });

    testWidgets('手动创建的同名分类（syncId 不同源）同样置灰不可再选', (tester) async {
      // 用户手动创建过"餐饮"（随机 syncId）→ 名称通道兜底判定为已添加
      await tester.pumpWidget(buildApp(
        home: const CategoryTemplateFlatPage(),
        cats: [
          (
            category: _category(
                id: 1, name: '餐饮', level: 1, syncId: 'random-v4-sync-id'),
            transactionCount: 0,
          ),
        ],
      ));
      await prime(tester);

      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('本次已勾选 0 项'), findsOneWidget,
          reason: '手动创建的同名分类应置灰，不可再勾选');

      await tester.tap(find.text('全选'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('本次已勾选 ${SeedService.flatExpenseCategoryKeys.length - 1} 项'),
        findsOneWidget,
        reason: '全选应排除同名已添加条目',
      );
    });

    testWidgets('添加流程：二次确认 → createCategory(确定性 syncId) → 成功 toast',
        (tester) async {
      await tester.pumpWidget(buildApp(home: const CategoryTemplateFlatPage()));
      await prime(tester);

      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('添加'));
      await tester.pump(const Duration(milliseconds: 300));

      // 二次确认弹窗
      expect(find.text('确认添加'), findsOneWidget, reason: '应弹二次确认弹窗');
      expect(find.text('确定将勾选的 1 个分类加入分类表吗？'), findsOneWidget);

      await tester.tap(find.text('确定'));
      await tester.pump(const Duration(milliseconds: 300));

      // 写入验证：名称/图标/确定性 syncId，首个一级 sortOrder 为 1（空表 topSort=0 +1）
      verify(() => repo.createCategory(
            name: '餐饮',
            kind: 'expense',
            icon: 'utensils',
            sortOrder: 1,
            syncId: _sid(1, 'dining'),
          )).called(1);

      expect(find.text('已添加 1 个分类'), findsOneWidget, reason: '写入成功应 toast');
      // toast 2 秒后自动消失，pump 推进定时器避免 pending timer 告警
      await tester.pump(const Duration(seconds: 2));
      // 勾选被清空
      expect(find.text('本次已勾选 0 项'), findsOneWidget);
    });
  });

  // ==================== hierarchical 模板页 ====================

  group('hierarchical 模板页', () {
    testWidgets('默认收起子类，点父行展开', (tester) async {
      await tester.pumpWidget(
          buildApp(home: const CategoryTemplateHierarchicalPage()));
      await prime(tester);

      expect(find.text('餐饮'), findsOneWidget, reason: '父分类行应常驻');
      expect(find.text('早餐'), findsNothing, reason: '默认收起，子类不可见');

      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('早餐'), findsOneWidget, reason: '展开后应显示子类');
    });

    testWidgets('勾子类独立选中，不连带父（2026-07-24 修订）', (tester) async {
      await tester.pumpWidget(
          buildApp(home: const CategoryTemplateHierarchicalPage()));
      await prime(tester);

      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('早餐'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('本次已勾选 1 项'), findsOneWidget,
          reason: '子类应支持单独选中，不再连带勾选父类');
    });

    testWidgets('勾选父复选框连带全选该父全部未添加子类，再点取消', (tester) async {
      await tester.pumpWidget(
          buildApp(home: const CategoryTemplateHierarchicalPage()));
      await prime(tester);

      final childCount =
          SeedService.hierarchicalExpenseCategories['dining']!.length;
      final checkbox = find.byKey(
          const ValueKey('templateParentCheckbox_dining'));

      // 勾选父 → 父 + 全部子类
      await tester.tap(checkbox);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('本次已勾选 ${1 + childCount} 项'), findsOneWidget,
          reason: '勾选父应连带全选其全部 $childCount 个未添加子类');

      // 再点父 → 连带取消全部子类
      await tester.tap(checkbox);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('本次已勾选 0 项'), findsOneWidget,
          reason: '取消父应连带取消全部已勾子类');
    });

    testWidgets('父已在表时子类单独勾选，写入挂到已有父 id（syncId 命中）',
        (tester) async {
      // 父 dining 已在 categories 表（db id=42，确定性 syncId 命中）
      await tester.pumpWidget(buildApp(
        home: const CategoryTemplateHierarchicalPage(),
        cats: [
          (
            category: _category(
                id: 42, name: '餐饮', level: 1, syncId: _sid(1, 'dining')),
            transactionCount: 0,
          ),
        ],
      ));
      await prime(tester);

      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('早餐'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('本次已勾选 1 项'), findsOneWidget,
          reason: '父已在表时子类可单独勾选');

      await tester.tap(find.text('添加'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('确定将勾选的 1 个分类加入分类表吗？'), findsOneWidget);
      await tester.tap(find.text('确定'));
      await tester.pump(const Duration(milliseconds: 300));

      // 仅写子类：挂到已有父 id=42，父下无既有子分类 → sortOrder 从 0 起
      verify(() => repo.createSubCategory(
            parentId: 42,
            name: '早餐',
            kind: 'expense',
            icon: any(named: 'icon'),
            sortOrder: 0,
            syncId: _sid(2, 'dining_breakfast'),
          )).called(1);
      verifyNever(() => repo.createCategory(
            name: any(named: 'name'),
            kind: any(named: 'kind'),
            icon: any(named: 'icon'),
            sortOrder: any(named: 'sortOrder'),
            syncId: any(named: 'syncId'),
          ));

      expect(find.text('已添加 1 个分类'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('手动创建的同名父（syncId 不同源）：父置灰，勾子类写入挂到该父 id',
        (tester) async {
      // 实机报错场景回归：用户手动创建过"餐饮"父类（随机 syncId）时，
      // 名称通道须识别父已存在并置灰，子类写入按名称兜底解析挂到该父 id，
      // 避免误判父未添加、勾子类连带勾父而写入撞 DuplicateNameException。
      await tester.pumpWidget(buildApp(
        home: const CategoryTemplateHierarchicalPage(),
        cats: [
          (
            category: _category(
                id: 42, name: '餐饮', level: 1, syncId: 'random-v4-sync-id'),
            transactionCount: 0,
          ),
        ],
      ));
      await prime(tester);

      // 父复选框已置灰：onTap 为 null，不可勾选
      // （注意：不可直接 tap 该复选框——onTap 为 null 时点击会穿透到
      // 父行 InkWell 触发展开/收起，改为直接断言回调为空）
      final parentCheckbox = tester.widget<GestureDetector>(
        find.byKey(const ValueKey('templateParentCheckbox_dining')),
      );
      expect(parentCheckbox.onTap, isNull, reason: '同名父复选框应禁用不可勾选');
      expect(find.text('本次已勾选 0 项'), findsOneWidget);

      // 展开并单独勾选子类
      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('早餐'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('本次已勾选 1 项'), findsOneWidget);

      await tester.tap(find.text('添加'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('确定'));
      await tester.pump(const Duration(milliseconds: 300));

      // 子类挂到已有父 id=42（名称兜底解析），不再新建父 → 不撞重名
      verify(() => repo.createSubCategory(
            parentId: 42,
            name: '早餐',
            kind: 'expense',
            icon: any(named: 'icon'),
            sortOrder: 0,
            syncId: _sid(2, 'dining_breakfast'),
          )).called(1);
      verifyNever(() => repo.createCategory(
            name: any(named: 'name'),
            kind: any(named: 'kind'),
            icon: any(named: 'icon'),
            sortOrder: any(named: 'sortOrder'),
            syncId: any(named: 'syncId'),
          ));

      expect(find.text('已添加 1 个分类'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('父未添加时勾选子类，写入先建父再建子（计划层自动补父）',
        (tester) async {
      await tester.pumpWidget(
          buildApp(home: const CategoryTemplateHierarchicalPage()));
      await prime(tester);

      await tester.tap(find.text('餐饮'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('早餐'));
      await tester.pump(const Duration(milliseconds: 100));

      // 子类独立勾选，计数 1；确认弹窗按实际写入计划计数（父+子=2）
      expect(find.text('本次已勾选 1 项'), findsOneWidget);

      await tester.tap(find.text('添加'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('确定将勾选的 2 个分类加入分类表吗？'), findsOneWidget,
          reason: '父未在表时写入计划应自动补父，确认数为父+子');
      await tester.tap(find.text('确定'));
      await tester.pump(const Duration(milliseconds: 300));

      // 先建父（返回 id 100）再建子（parentId=100）
      verifyInOrder([
        () => repo.createCategory(
              name: '餐饮',
              kind: 'expense',
              icon: any(named: 'icon'),
              sortOrder: any(named: 'sortOrder'),
              syncId: _sid(1, 'dining'),
            ),
        () => repo.createSubCategory(
              parentId: 100,
              name: '早餐',
              kind: 'expense',
              icon: any(named: 'icon'),
              sortOrder: any(named: 'sortOrder'),
              syncId: _sid(2, 'dining_breakfast'),
            ),
      ]);

      expect(find.text('已添加 2 个分类'), findsOneWidget,
          reason: '父+子共写入 2 个分类');
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
