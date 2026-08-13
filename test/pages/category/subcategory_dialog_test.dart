// 子分类弹窗 UI 优化测试
//
// 验证内容：
//   1. 正常模式：标题旁"编辑父分类"文字链 + 底部"添加子分类/删除子分类"文字链
//   2. 删除模式切换：点击"删除子分类"进入删除模式，卡片显示复选框
//   3. 0 选中时"确认删除"禁用，≥1 选中时启用
//   4. 删除模式底部两个单选项（删数据 / 迁移后删除），默认选中项 0
//   5. 策略 0：确认弹窗展示待删列表，确认后先删交易再删分类
//   6. 策略 1：迁移目标 sheet 排除选中项，确定后先迁移再删除

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/category/category_manage_page.dart';
import 'package:spitout/providers/core/database_providers.dart';

/// Mock 整个 LocalRepository，按需 stub 弹窗用到的方法。
class _MockRepo extends Mock implements LocalRepository {}

typedef _CategoryWithCount = ({db.Category category, int transactionCount});

db.Category _category({
  required int id,
  required String name,
  required int level,
  int? parentId,
  int sortOrder = 0,
}) {
  return db.Category(
    id: id,
    name: name,
    kind: 'expense',
    icon: 'utensils',
    sortOrder: sortOrder,
    parentId: parentId,
    level: level,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // mocktail 需要注册 fallback 值用于 List 等泛型参数匹配
  registerFallbackValue(<int>[]);

  late _MockRepo repo;
  late List<_CategoryWithCount> testCategories;
  late List<db.Category> shoppingSubs;

  /// 构造测试分类数据：
  /// - 餐饮(1)、交通(2)：普通一级分类，可作为迁移目标
  /// - 购物(3)：含两个子分类 服装(4, 2笔)、鞋帽(5, 1笔)
  setUp(() {
    resetGlobalTestState();
    repo = _MockRepo();
    final dining = _category(id: 1, name: '餐饮', level: 1);
    final transport = _category(id: 2, name: '交通', level: 1, sortOrder: 1);
    final shopping = _category(id: 3, name: '购物', level: 1, sortOrder: 2);
    final clothing = _category(id: 4, name: '服装', level: 2, parentId: 3);
    final shoes = _category(
      id: 5,
      name: '鞋帽',
      level: 2,
      parentId: 3,
      sortOrder: 1,
    );

    testCategories = [
      (category: dining, transactionCount: 5),
      (category: transport, transactionCount: 3),
      (category: shopping, transactionCount: 3),
      (category: clothing, transactionCount: 2),
      (category: shoes, transactionCount: 1),
    ];
    shoppingSubs = [clothing, shoes];

    // 弹窗加载子分类列表
    when(() => repo.getSubCategories(3)).thenAnswer((_) async => shoppingSubs);
    // 删除/迁移相关方法 stub
    when(
      () => repo.deleteTransactionsByCategoryIds(any()),
    ).thenAnswer((_) async => 0);
    when(() => repo.deleteCategoriesByIds(any())).thenAnswer((_) async {});
    when(
      () => repo.migrateCategoryTransactions(
        fromCategoryId: any(named: 'fromCategoryId'),
        toCategoryId: any(named: 'toCategoryId'),
      ),
    ).thenAnswer(
      (_) async => (migratedTransactions: 0, migratedSubCategories: 0),
    );
  });

  /// 构建测试宿主，注入 mock repo 和预设分类数据
  ///
  /// [categories] 可选：覆盖默认的 [testCategories]，用于构造不同规模的子分类
  /// 场景（如"大量子分类触发限高滚动"测试）。不传则使用 setUp 中预设的数据。
  Widget buildApp({List<_CategoryWithCount>? categories}) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 0),
        categoriesWithCountProvider.overrideWith(
          (ref) => Stream<List<_CategoryWithCount>>.value(
            categories ?? testCategories,
          ),
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
        home: const CategoryManagePage(),
      ),
    );
  }

  /// 分步 pump：让 stream 首帧 + async 加载完成
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// 打开子分类弹窗：点击含子分类的"购物"卡片并等待弹窗动画与数据加载
  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('购物'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 进入删除模式
  Future<void> enterDeleteMode(WidgetTester tester) async {
    await tester.tap(find.text('删除子分类'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  // ==================== 正常模式 UI ====================

  group('正常模式 UI', () {
    testWidgets('标题旁显示"编辑父分类"文字链', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);

      expect(find.text('编辑父分类'), findsOneWidget, reason: '父分类标题旁应有"编辑父分类"文字链');
    });

    testWidgets('底部显示"添加子分类"和"删除子分类"文字链', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);

      expect(find.text('添加子分类'), findsOneWidget, reason: '底部应有"添加子分类"文字链');
      expect(find.text('删除子分类'), findsOneWidget, reason: '底部应有"删除子分类"文字链');
    });

    testWidgets('网格展示子分类且不再有添加/编辑操作卡片', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);

      expect(find.text('服装'), findsOneWidget, reason: '应显示子分类"服装"');
      expect(find.text('鞋帽'), findsOneWidget, reason: '应显示子分类"鞋帽"');
      // 网格内无"添加"/"编辑"操作卡片（精确匹配不到独立文案）
      expect(find.text('添加'), findsNothing, reason: '不应再有"添加"操作卡片');
      expect(find.text('编辑'), findsNothing, reason: '不应再有"编辑"操作卡片');
    });
  });

  // ==================== 删除模式切换 ====================

  group('删除模式切换', () {
    testWidgets('点击"删除子分类"进入删除模式，显示"确认删除"和两个单选项', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      expect(find.text('确认删除'), findsOneWidget, reason: '应显示"确认删除"');
      expect(find.text('删除子分类'), findsNothing, reason: '删除模式不应再显示"删除子分类"');
      // 两个单选项
      expect(
        find.text('删除分类和分类下的所有数据'),
        findsOneWidget,
        reason: '应有"删除全部数据"选项',
      );
      expect(
        find.text('删除分类并迁移分类下的所有数据到其他分类'),
        findsOneWidget,
        reason: '应有"迁移后删除"选项',
      );
    });

    testWidgets('删除模式隐藏"编辑父分类"和"添加子分类"', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      expect(find.text('编辑父分类'), findsNothing, reason: '删除模式应隐藏"编辑父分类"');
      expect(find.text('添加子分类'), findsNothing, reason: '删除模式应隐藏"添加子分类"');
    });

    testWidgets('0 选中时"确认删除"不可点击（不弹确认弹窗）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      await tester.tap(find.text('确认删除'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('删除选中的分类'),
        findsNothing,
        reason: '0 选中时点击"确认删除"不应弹出确认弹窗',
      );
    });

    testWidgets('选中一个子分类后显示勾选，再次点击取消选中', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      // 未选中时无勾选图标
      expect(find.byIcon(Icons.check), findsNothing);

      // 选中
      await tester.tap(find.text('服装'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.check), findsOneWidget, reason: '选中后应显示勾选图标');

      // 取消选中
      await tester.tap(find.text('服装'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.check), findsNothing, reason: '再次点击应取消选中');
    });
  });

  // ==================== 策略 0：删除分类和分类下的所有数据 ====================

  group('策略 0 删除确认弹窗', () {
    testWidgets('点击"确认删除"弹出确认弹窗，展示标题/副标题/待删列表', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      // 选中 服装
      await tester.tap(find.text('服装'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('确认删除'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('删除选中的分类'), findsOneWidget, reason: '确认弹窗标题应为"删除选中的分类"');
      expect(
        find.text('确定要删除 1 个选中分类并且清空分类下的数据吗？此操作无法撤销。'),
        findsOneWidget,
        reason: '副标题应包含选中数量与不可撤销提示',
      );
      // 列表行：服装 + 2笔（卡片上也有，故用 findsWidgets 验证至少出现）
      expect(find.text('服装'), findsWidgets, reason: '列表应展示待删除子分类');
    });

    testWidgets('确认后先删交易再删分类，并退出删除模式', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      await tester.tap(find.text('服装'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证调用顺序：先删交易 → 再删分类（mocktail 对 List 参数做深比较）
      verifyInOrder([
        () => repo.deleteTransactionsByCategoryIds([4]),
        () => repo.deleteCategoriesByIds([4]),
      ]);

      // 成功 toast（2 秒后自动消失，pump 推进定时器避免 pending timer）
      expect(find.text('已删除 1 个分类'), findsOneWidget, reason: '删除成功应 toast 提示');
      await tester.pump(const Duration(seconds: 2));

      // 退出删除模式，回到正常模式
      expect(find.text('删除子分类'), findsOneWidget, reason: '删除完成后应回到正常模式');
    });

    testWidgets('取消确认弹窗不执行删除', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      await tester.tap(find.text('服装'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('确认删除'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('取消'));
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(() => repo.deleteTransactionsByCategoryIds(any()));
      verifyNever(() => repo.deleteCategoriesByIds(any()));
    });
  });

  // ==================== 策略 1：迁移数据到其他分类后删除 ====================

  group('策略 1 迁移目标选择', () {
    testWidgets('选择迁移策略后点"确认删除"弹出迁移目标 sheet，排除选中项', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      // 切换到迁移策略
      await tester.tap(find.text('删除分类并迁移分类下的所有数据到其他分类'));
      await tester.pump(const Duration(milliseconds: 100));
      // 选中 服装
      await tester.tap(find.text('服装'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('确认删除'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('选择数据迁移到的分类'),
        findsOneWidget,
        reason: '应弹出迁移目标选择 sheet',
      );
      expect(
        find.text('确定（迁移分类数据并删除分类）'),
        findsOneWidget,
        reason: 'sheet 应有迁移确定按钮',
      );
      // sheet 中的候选 chip：餐饮/交通/鞋帽 各出现 2 次（页面/弹窗 + sheet），
      // 服装仅 1 次（弹窗卡片），未出现在 sheet 候选中
      expect(
        find.text('餐饮'),
        findsNWidgets(2),
        reason: 'sheet 候选应包含"餐饮"（页面网格 + sheet chip）',
      );
      expect(
        find.text('服装'),
        findsOneWidget,
        reason: '"服装"被排除，sheet 候选中不应出现（仅弹窗卡片 1 处）',
      );
      expect(find.text('鞋帽'), findsNWidgets(2), reason: '未被选中的"鞋帽"可作为迁移目标');
    });

    testWidgets('选定目标后先迁移数据再删除分类', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      await enterDeleteMode(tester);

      await tester.tap(find.text('删除分类并迁移分类下的所有数据到其他分类'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('服装'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('确认删除'));
      // 等待 sheet 动画完全结束，避免按钮仍在屏幕外滑入途中
      await tester.pumpAndSettle();

      // 在 sheet 中选择"餐饮"（最后一个匹配为 sheet chip）
      await tester.tap(find.text('餐饮').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('确定（迁移分类数据并删除分类）'));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证调用顺序：先迁移 → 再删除
      verifyInOrder([
        () => repo.migrateCategoryTransactions(
          fromCategoryId: 4,
          toCategoryId: 1,
        ),
        () => repo.deleteCategoriesByIds([4]),
      ]);
      // 迁移策略不删除交易
      verifyNever(() => repo.deleteTransactionsByCategoryIds(any()));

      expect(
        find.text('已删除 1 个分类'),
        findsOneWidget,
        reason: '迁移删除成功应 toast 提示',
      );
      await tester.pump(const Duration(seconds: 2));
    });
  });

  // ==================== 文字链字号与点击热区 ====================

  group('文字链字号与点击热区', () {
    /// 验证文字链字号 ≥ 13 且被 Padding 包裹以扩大点击热区（垂直 padding ≥ 12）。
    ///
    /// 设计意图：文字链须 ≥13px 且带 vertical padding 扩大点击热区，
    /// 保证"看得清且点得到"。
    void expectTappableTextLink(WidgetTester tester, String label) {
      final textFinder = find.text(label);
      expect(textFinder, findsOneWidget, reason: '应存在文字链"$label"');

      // 字号验证：≥ 13（过小看不清）
      final text = tester.widget<Text>(textFinder);
      expect(
        text.style?.fontSize,
        greaterThanOrEqualTo(13),
        reason: '"$label"字号应 ≥ 13（过小看不清）',
      );

      // 点击热区验证：最近的 Padding 祖先应有垂直 padding ≥ 12 扩大点击热区
      final paddingFinder = find.ancestor(
        of: textFinder,
        matching: find.byType(Padding),
      );
      final padding = tester.widget<Padding>(paddingFinder.first);
      final resolved = padding.padding.resolve(TextDirection.ltr);
      expect(
        resolved.vertical,
        greaterThanOrEqualTo(12),
        reason: '"$label"应有垂直 padding ≥ 12 扩大点击热区',
      );
    }

    testWidgets('"编辑父分类"字号 ≥ 13 且有足够点击热区', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      expectTappableTextLink(tester, '编辑父分类');
    });

    testWidgets('"添加子分类"字号 ≥ 13 且有足够点击热区', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      expectTappableTextLink(tester, '添加子分类');
    });

    testWidgets('"删除子分类"字号 ≥ 13 且有足够点击热区', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);
      expectTappableTextLink(tester, '删除子分类');
    });
  });

  // ==================== 弹窗高度自适应 ====================

  group('弹窗高度自适应 (shrinkWrap: 少则收紧 / 多则限高滚动)', () {
    /// 设计意图：弹窗网格用 ConstrainedBox(maxHeight: 屏高×0.5) 作为上限，
    /// 配合 ReorderableGridView 的 shrinkWrap: true 实现：
    ///   - 子分类少 → 网格收紧到实际内容高度，弹窗随数量自适应（不撑满半屏留白）
    ///   - 子分类多 → 网格受 maxHeight 限制，超出部分滚动查看
    /// 测试默认视口 800×600，故 maxHeight = 600×0.5 = 300。
    /// 网格 4 列、crossAxisSpacing/mainAxisSpacing=10、childAspectRatio=1，
    /// 弹窗内容宽 368 → 单元格宽高约 84.5：
    ///   - 2 个子分类 = 1 行 ≈ 84.5（< 300，应收紧不滚动）
    ///   - 16 个子分类 = 4 行 ≈ 368（> 300，应限高到 300 且可滚动）

    /// 查找弹窗内 ReorderableGridView 内部的 Scrollable（GridView 产生）。
    /// 注意：管理页本身也有 Scrollable，故用 descendant 限定到网格内部。
    Finder gridScrollable(WidgetTester tester) {
      return find.descendant(
        of: find.byType(ReorderableGridView),
        matching: find.byType(Scrollable),
      );
    }

    testWidgets('子分类少时网格自适应收紧，不撑满 maxHeight', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);
      await openDialog(tester);

      // 默认 2 个子分类（1 行），网格高度应远小于 maxHeight(300)
      final gridRect = tester.getRect(find.byType(ReorderableGridView));
      expect(
        gridRect.height,
        lessThan(300),
        reason: '子分类仅 2 个时网格应自适应收紧到 1 行高度，不撑满半屏',
      );

      // 内容未超出限高，不应可滚动
      final scrollable = tester.state<ScrollableState>(gridScrollable(tester));
      expect(
        scrollable.position.maxScrollExtent,
        equals(0.0),
        reason: '子分类不超出限高时网格不应可滚动',
      );
    });

    testWidgets('子分类多时网格受 maxHeight 限制并支持滚动', (tester) async {
      // 构造 16 个子分类（4 行，超出 maxHeight=300），应限高滚动
      final manySubs = <db.Category>[];
      final manyCats = <_CategoryWithCount>[
        (
          category: _category(id: 3, name: '购物', level: 1, sortOrder: 2),
          transactionCount: 3,
        ),
      ];
      for (int i = 0; i < 16; i++) {
        final sub = _category(
          id: 100 + i,
          name: '子分类$i',
          level: 2,
          parentId: 3,
          sortOrder: i,
        );
        manySubs.add(sub);
        manyCats.add((category: sub, transactionCount: 0));
      }
      // 覆盖 setUp 中的 stub，返回 16 个子分类
      when(() => repo.getSubCategories(3)).thenAnswer((_) async => manySubs);

      await tester.pumpWidget(buildApp(categories: manyCats));
      await prime(tester);
      await openDialog(tester);

      // 网格高度应被 maxHeight(300) 限制，不撑破弹窗
      final gridRect = tester.getRect(find.byType(ReorderableGridView));
      expect(
        gridRect.height,
        lessThanOrEqualTo(300.0),
        reason: '子分类超出 maxHeight 时网格应限高到 maxHeight，不撑破弹窗',
      );

      // 内容超出限高，应可滚动查看被截断的子分类
      final scrollable = tester.state<ScrollableState>(gridScrollable(tester));
      expect(
        scrollable.position.maxScrollExtent,
        greaterThan(0.0),
        reason: '子分类过多超出限高时，网格应可滚动查看',
      );
    });
  });
}
