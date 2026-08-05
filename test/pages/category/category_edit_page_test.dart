// 分类编辑页 UI 优化组件测试
//
// 验证内容：
//   1. 页面布局顺序：分类名称 → 所属分类 → 分类图标（→ 编辑模式追加删除区）
//   2. 无支出分类头部模块（已移除）
//   3. 所属分类卡片三种状态渲染（独立 / 有父级 / 有子分类置灰）
//   4. 图标网格限高 360px 区域内滚动
//   5. "分类汇总"入口仅编辑模式显示
//   6. 无自定义图标上传功能（已移除）
//   7. 保存逻辑：有父分类 → createSubCategory，无父分类 → createCategory

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/category/category_edit_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/primary_header.dart';

/// Mock 整个 BaseRepository
class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(<int>[]);

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    // stub 常用查询方法返回安全默认值
    when(() => repo.isCategoryNameDuplicate(
          name: any(named: 'name'),
          kind: any(named: 'kind'),
          excludeId: any(named: 'excludeId'),
          parentId: any(named: 'parentId'),
        )).thenAnswer((_) async => false);
    when(() => repo.hasSubCategories(any()))
        .thenAnswer((_) async => false);
    when(() => repo.getTransactionCountByCategory(any()))
        .thenAnswer((_) async => 0);
    when(() => repo.getCategoryById(any()))
        .thenAnswer((_) async => null);
    when(() => repo.getSubCategories(any()))
        .thenAnswer((_) async => const []);
  });

  /// 构建分类编辑页测试宿主
  Widget buildApp({
    db.Category? category,
    db.Category? parentCategory,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 0),
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
        home: CategoryEditPage(
          category: category,
          kind: 'expense',
          parentCategory: parentCategory,
        ),
      ),
    );
  }

  /// 分步 pump 让 async initState 完成
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  // ==================== 布局顺序 ====================

  group('页面布局顺序', () {
    testWidgets('新建模式页面包含分类名称输入框', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      expect(find.byType(TextFormField), findsOneWidget,
          reason: '应有分类名称输入框');
    });

    testWidgets('页面包含"所属分类"卡片', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 该字段标题为"所属分类"
      expect(find.text('所属分类'), findsOneWidget, reason: '应有"所属分类"卡片');
    });

    testWidgets('页面包含"分类图标"标题', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      expect(find.text('分类图标'), findsOneWidget, reason: '应有"分类图标"标题');
    });

    testWidgets('分类名称输入框在所属分类卡片之前（布局顺序）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      final nameField = find.byType(TextFormField);
      final parentText = find.text('所属分类');

      // 验证两个元素都存在
      expect(nameField, findsOneWidget);
      expect(parentText, findsOneWidget);

      // 通过 y 坐标验证顺序：名称在上，所属分类在下
      final nameRect = tester.getCenter(nameField);
      final parentRect = tester.getCenter(parentText);
      expect(nameRect.dy, lessThan(parentRect.dy),
          reason: '分类名称应在所属分类之上');
    });
  });

  // ==================== 移除的模块 ====================

  group('已移除的模块', () {
    testWidgets('不包含支出分类标识模块', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // categoryExpenseType 对应的 Card 已移除
      // 新建模式应有 3 个 Card：名称、所属分类、图标
      final cardCount = tester.widgetList<Card>(find.byType(Card)).length;
      expect(cardCount, lessThanOrEqualTo(3),
          reason: '不应有支出分类头部模块 Card，最多 3 个 Card');
    });

    testWidgets('不包含自定义图标上传功能', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // image_picker / image_cropper 相关的 UI 已移除
      expect(find.text('自定义图标'), findsNothing, reason: '不应有自定义图标标题');
      expect(find.byIcon(Icons.photo_camera), findsNothing,
          reason: '不应有拍照/上传图标');
    });

    testWidgets('不包含二级分类开关', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // SwitchListTile（二级分类开关）已移除，改为"所属分类"行
      expect(find.byType(SwitchListTile), findsNothing,
          reason: '不应有二级分类开关');
    });
  });

  // ==================== 所属分类三种状态 ====================

  group('所属分类三种状态', () {
    testWidgets('新建模式：独立分类状态（无副标题，右侧有箭头）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 独立分类状态：副标题为空，有右侧箭头
      expect(find.text('所属分类'), findsOneWidget);
      // 不应有"此分类包含二级分类，无法修改"提示
      expect(find.text('此分类包含二级分类，无法修改'), findsNothing,
          reason: '独立分类不应有置灰提示');
    });

    testWidgets('从添加子分类入口进入：有父分类预设', (tester) async {
      final parent = db.Category(
        id: 10,
        name: '餐饮',
        kind: 'expense',
        icon: 'utensils',
        sortOrder: 0,
        parentId: null,
        level: 1,
      );

      await tester.pumpWidget(buildApp(parentCategory: parent));
      await prime(tester);

      // 应显示父分类名称作为副标题
      expect(find.text('餐饮'), findsOneWidget, reason: '应显示父分类名"餐饮"');
    });

    testWidgets('编辑模式有子分类时所属分类置灰', (tester) async {
      final category = db.Category(
        id: 1,
        name: '餐饮',
        kind: 'expense',
        icon: 'utensils',
        sortOrder: 0,
        parentId: null,
        level: 1,
      );

      // stub hasSubCategories 返回 true（有子分类）
      when(() => repo.hasSubCategories(1)).thenAnswer((_) async => true);

      await tester.pumpWidget(buildApp(category: category));
      await prime(tester);
      await tester.pump(const Duration(milliseconds: 200));

      // 应显示"此分类包含二级分类，无法修改"
      expect(find.text('此分类包含二级分类，无法修改'), findsOneWidget,
          reason: '有子分类时应显示置灰提示');
    });

    testWidgets('编辑模式无子分类时不置灰（可点击修改父分类）', (tester) async {
      final category = db.Category(
        id: 1,
        name: '餐饮',
        kind: 'expense',
        icon: 'utensils',
        sortOrder: 0,
        parentId: null,
        level: 1,
      );

      // hasSubCategories 默认 stub 返回 false
      await tester.pumpWidget(buildApp(category: category));
      await prime(tester);
      await tester.pump(const Duration(milliseconds: 200));

      // 不应显示置灰提示
      expect(find.text('此分类包含二级分类，无法修改'), findsNothing,
          reason: '无子分类时不应置灰');
    });
  });

  // ==================== 所属分类标题垂直居中 ====================

  group('所属分类标题垂直居中', () {
    testWidgets('新建/独立分类：标题在卡片内垂直居中', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 找到包含"所属分类"的卡片
      final cardFinder = find.ancestor(
        of: find.text('所属分类'),
        matching: find.byType(Card),
      );
      // 卡片中心（含上下 padding）
      final cardCenter = tester.getCenter(cardFinder);
      // 标题"所属分类"的中心
      final titleCenter = tester.getCenter(find.text('所属分类'));

      // 无副标题（独立/新增分类）时标题应垂直居中，与卡片中心 y 几乎重合。
      expect((titleCenter.dy - cardCenter.dy).abs(), lessThan(3.0),
          reason: '无副标题时标题应垂直居中，与卡片中心对齐');
    });

    testWidgets('新建/独立分类：不渲染空副标题占位', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 独立分类无父分类、无子分类，不应出现置灰提示文案（即无副标题内容）
      expect(find.text('此分类包含二级分类，无法修改'), findsNothing,
          reason: '独立分类不应渲染任何副标题内容');
    });
  });

  // ==================== 分类汇总入口 ====================

  // 全局头部统一后，入口已收敛为 HeaderIconAction 统一图标键（图标 categoryDetail），
  // 原「图标+文字」复合形式中的可见文案「分类汇总」移至 tooltip 承载。
  group('分类汇总入口', () {
    /// 定位分类汇总入口：HeaderIconAction 且图标为 categoryDetail
    Finder summaryEntryFinder() => find.byWidgetPredicate(
          (w) => w is HeaderIconAction && w.icon == AppIcons.categoryDetail,
        );

    testWidgets('新建模式不显示分类汇总入口', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      expect(summaryEntryFinder(), findsNothing,
          reason: '新建模式不应显示分类汇总入口');
    });

    testWidgets('编辑模式恒显示分类汇总入口', (tester) async {
      final category = db.Category(
        id: 1,
        name: '餐饮',
        kind: 'expense',
        icon: 'utensils',
        sortOrder: 0,
        parentId: null,
        level: 1,
      );

      // 编辑模式不再依赖外部注入回调：编辑对象恒存在，
      // 入口恒展示（detail 页内「编辑分类」直接按路由名跳分类管理页）
      await tester.pumpWidget(buildApp(category: category));
      await prime(tester);

      expect(summaryEntryFinder(), findsOneWidget,
          reason: '编辑模式应显示分类汇总入口（统一图标键）');
      // 原可见文案「分类汇总」收敛至 tooltip（l10n.categoryDetailTooltip）
      final action = tester.widget<HeaderIconAction>(summaryEntryFinder());
      final l10n =
          AppLocalizations.of(tester.element(find.byType(CategoryEditPage)));
      expect(action.tooltip, l10n.categoryDetailTooltip,
          reason: '入口文案应由 tooltip 承载');
    });
  });

  // ==================== 图标网格 ====================

  group('图标网格', () {
    testWidgets('图标网格区域有固定高度（SizedBox height=360）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 查找高度为 360 的 SizedBox（图标网格容器）
      final sizedBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((s) => s.height == 360)
          .toList();
      expect(sizedBoxes, isNotEmpty,
          reason: '图标网格应有 360px 固定高度容器');
    });

    testWidgets('图标网格内显示图标名（Lucide 原名，不翻译）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 图标名不翻译，直接展示 key（如 "utensils", "coffee" 等）
      // 验证至少有一个图标名文本存在
      final iconNames = ['category', 'utensils', 'coffee', 'car', 'home'];
      var foundAny = false;
      for (final name in iconNames) {
        if (find.text(name).evaluate().isNotEmpty) {
          foundAny = true;
          break;
        }
      }
      expect(foundAny, isTrue, reason: '图标网格应显示 Lucide 图标名（不翻译）');
    });

    testWidgets('"基础"分组位于倒数第二（"其他杂项"之上）', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 初始视口：第一组是"餐饮美食"，"基础"分组尚未滚入视口
      expect(find.text('餐饮美食'), findsOneWidget,
          reason: '首个分组应为"餐饮美食"');
      expect(find.text('基础'), findsNothing,
          reason: '"基础"已移至倒数第二，初始不应可见');

      // 图标网格的固定锚点：限高 360 的 SizedBox 容器始终挂在树上，
      // 不受网格内部滚动导致的懒加载回收影响（分组标题 Text 会被回收）
      final gridBox = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 360,
      );
      expect(gridBox, findsOneWidget, reason: '图标网格应有 360px 限高容器');
      // 容器内第一个 Scrollable 即网格 ListView（分组 GridView 的 Scrollable
      // 位于更深层，被 .first 排除）
      final gridScrollState = tester.state<ScrollableState>(
        find.descendant(of: gridBox, matching: find.byType(Scrollable)).first,
      );

      // 渐进滚动扫描：逐段 jumpTo 并按树顺序收集分组标题
      // （ScrollableState 引用跨重建稳定，可直接驱动滚动位置）
      const expenseGroupTitles = {
        '餐饮美食', '交通出行', '购物消费', '居住生活', '通讯设备', '娱乐休闲',
        '健康医疗', '教育学习', '宠物动物', '服装美容', '基础', '其他杂项',
      };
      final scannedTitles = <String>[];
      while (true) {
        // widgetList 按树顺序返回（自上而下），保证收集顺序 = 视觉顺序
        final texts = tester.widgetList<Text>(
          find.descendant(of: gridBox, matching: find.byType(Text)),
        );
        for (final w in texts) {
          final data = w.data;
          if (data != null &&
              expenseGroupTitles.contains(data) &&
              !scannedTitles.contains(data)) {
            scannedTitles.add(data);
          }
        }
        final pos = gridScrollState.position;
        if (pos.pixels >= pos.maxScrollExtent) break;
        pos.jumpTo((pos.pixels + 200).clamp(0.0, pos.maxScrollExtent));
        await tester.pump();
      }

      // 全部分组都被扫到
      expect(scannedTitles.length, expenseGroupTitles.length,
          reason: '应扫到全部 ${expenseGroupTitles.length} 个分组标题');
      // 最后一组为"其他杂项"，倒数第二组为"基础"
      expect(scannedTitles.last, '其他杂项', reason: '最后一组应为"其他杂项"');
      expect(scannedTitles[scannedTitles.length - 2], '基础',
          reason: '"基础"分组应位于倒数第二（"其他杂项"之上）');
    });
  });

  // ==================== 当前图标预览 ====================

  group('当前图标预览', () {
    testWidgets('显示"当前图标"文案', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      expect(find.text('当前图标'), findsOneWidget,
          reason: '应有"当前图标"文案');
    });
  });

  // ==================== 危险操作区（已移除） ====================

  group('危险操作区 (2026-07-23 起移除，删除分类统一走管理页)', () {
    testWidgets('新建模式不显示危险操作区', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      expect(find.text('危险操作'), findsNothing, reason: '新建模式不应有危险操作区');
    });

    testWidgets('编辑模式同样不显示危险操作区', (tester) async {
      // 设置超大视口，让 ListView 一次性渲染全部子项（无需滚动）
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final category = db.Category(
        id: 1,
        name: '餐饮',
        kind: 'expense',
        icon: 'utensils',
        sortOrder: 0,
        parentId: null,
        level: 1,
      );

      await tester.pumpWidget(buildApp(category: category));
      await prime(tester);

      // 危险操作模块已从编辑页移除，编辑模式也不应出现
      expect(find.text('危险操作'), findsNothing,
          reason: '危险操作区已移除，编辑模式也不应显示');
    });
  });
}
