import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/repositories/category_repository.dart';
import '../l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import '../routes.dart';
import '../theme/colors.dart';
import 'category_grid_item.dart';
import '../theme/icons/app_icons.dart';

/// 分类网格区：一级分类 5 列网格 + 二级分类原地展开卡片 + 底部「编辑分类」入口。
///
/// - 父分类 5 列网格，圆形图标 40×40。
/// - **选中含子分类的父项时，其子分类区域必须自动展开**（不 toggle）。
///   从「早餐」切到「午餐」再切回「早餐」，早餐子分类必须重新自动展开。
/// - 选择无子分类的父分类时，当前子分类区域收起。
/// - 父分类本身就是可提交分类，不强制选择子分类。
/// - 子分类容器：圆角 20px、最大可视高度 200px、内部可滚动、隐藏滚动条。
/// - 底部「编辑分类」入口：Edit3 图标 + 文本。
///
/// 数据来源：
/// 分类树来自全局常驻缓存 [categoryPickerTreeProvider]（app 启动即预热），
/// sheet 打开首帧即同步渲染，无「空白 → 出现 → 自动选中再跳」的跳变；
/// provider 由 Drift 表监听驱动，数据变更自动重建，按键 setState 不重查 DB。
class CategoryGridSection extends ConsumerStatefulWidget {
  /// 分类类型，值固定为 'expense'（全局仅支出模式）
  final String kind;

  /// 初始选中分类 ID（编辑模式回显 / quickAdd 预选）
  final int? initialSelectedId;

  /// 分类选中回调，上报给父 sheet
  final ValueChanged<Category> onCategorySelected;

  const CategoryGridSection({
    super.key,
    required this.kind,
    required this.onCategorySelected,
    this.initialSelectedId,
  });

  @override
  ConsumerState<CategoryGridSection> createState() =>
      _CategoryGridSectionState();
}

class _CategoryGridSectionState extends ConsumerState<CategoryGridSection> {
  int? _expandedCategoryId; // 当前展开的一级分类 ID
  int? _selectedId; // 当前点击的分类（用于高亮）
  bool _initialized = false; // 初始选中/展开/滚动是否已执行（一次性）
  final Map<int, GlobalKey> _keys = {}; // 行首分类 ID → GlobalKey（滚动定位）

  @override
  void initState() {
    super.initState();
    // 编辑模式/预选：先高亮初始分类；展开父级与滚动定位依赖分类树数据，
    // 在首个数据帧的 _initOnce 中从树同步解析（不单独反查 DB）。
    _selectedId = widget.initialSelectedId;
  }

  /// 处理一级分类点击。
  ///
  /// 规则：
  /// - 含子分类：直接选中该父分类（父分类本身可提交），并**始终展开**其子分类区域。
  ///   重复点击同一含子分类父项时，子分类保持展开（不 toggle）。
  /// - 无子分类：直接选中，关闭已展开的子分类区域。
  void _onTopCategoryTap(Category topCat, List<Category> children) {
    final hasChildren = children.isNotEmpty;
    setState(() {
      _selectedId = topCat.id;
      // 含子分类 → 始终展开；无子分类 → 收起
      _expandedCategoryId = hasChildren ? topCat.id : null;
    });
    widget.onCategorySelected(topCat);
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(categoryPickerTreeProvider(widget.kind));
    return treeAsync.when(
      // 与旧 FutureBuilder 行为一致：加载中/出错不显示 loading，避免一闪。
      // 缓存已预热时首帧即走 data 分支，无空白期。
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tree) => _buildGrid(context, tree),
    );
  }

  /// 一级分类每行个数。行分组循环、网格列数、滚动定位共用此常量，保证三者一致。
  static const int _kColumns = 5;

  /// 用分类树数据构建网格（一级 5 列 + 展开的二级卡片 + 编辑入口）。
  Widget _buildGrid(BuildContext context, CategoryPickerTree tree) {
    final topLevelCategories = tree.topLevel;
    final subCategoriesMap = tree.children;

    if (topLevelCategories.isEmpty) {
      // 分类为空时，仅提示「暂无分类」无法引导用户进入分类管理，
      // 故在此追加一条文字链复用底部「编辑分类」入口跳转分类管理页，
      // 让用户能直接去新增分类，避免在记账页卡死。
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context).categoryEmpty),
            const SizedBox(height: 12),
            _buildEditCategoryEntry(context),
          ],
        ),
      );
    }

    _initOnce(tree);

    final displayItems = <Widget>[];

    // 按每 _kColumns 个一组显示一级分类
    for (int i = 0; i < topLevelCategories.length; i += _kColumns) {
      final endIndex = (i + _kColumns).clamp(0, topLevelCategories.length);
      final rowItems = topLevelCategories.sublist(i, endIndex);
      final firstCategoryInRow = rowItems.first;

      displayItems.add(
        Container(
          key: _keys.putIfAbsent(
              firstCategoryInRow.id, () => GlobalKey()),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _kColumns,
              // 父分类水平间距 8px
              crossAxisSpacing: 8,
              // 父分类垂直行距 12px
              mainAxisSpacing: 12,
              // 固定行高（图标40+间距6+文字约15，留 5px 余量），
              // 不用宽高比：窄屏下格子变窄会把行高压得比内容矮导致溢出。
              mainAxisExtent: 66,
            ),
            itemCount: rowItems.length,
            itemBuilder: (context, index) {
              final topCat = rowItems[index];
              final children = subCategoriesMap[topCat.id] ?? [];
              final hasChildren = children.isNotEmpty;

              return CategoryGridItem(
                category: topCat,
                selected: _selectedId == topCat.id,
                hasChildren: hasChildren,
                expanded: _expandedCategoryId == topCat.id,
                onTap: () => _onTopCategoryTap(topCat, children),
              );
            },
          ),
        ),
      );

      // 检查该行是否有展开的分类，有则插入二级分类卡片
      for (int j = 0; j < rowItems.length; j++) {
        final topCat = rowItems[j];
        final children = subCategoriesMap[topCat.id] ?? [];
        final hasChildren = children.isNotEmpty;

        if (_expandedCategoryId == topCat.id && hasChildren) {
          // 子分类卡片距离父分类行：8px
          displayItems.add(const SizedBox(height: 8));
          displayItems.add(
            _SubcategorySelectorCard(
              parentCategory: topCat,
              subCategories: children,
              selectedId: _selectedId,
              onSubCategoryTap: (cat) {
                setState(() => _selectedId = cat.id);
                widget.onCategorySelected(cat);
              },
            ),
          );
          break; // 每行只展开一个
        }
      }

      if (i + _kColumns < topLevelCategories.length) {
        // 父分类两行之间：12px
        displayItems.add(const SizedBox(height: 12));
      }
    }

    // 底部「编辑分类」入口（Edit3 图标 + 文本），入口上方留白 18px
    displayItems.add(const SizedBox(height: 18));
    displayItems.add(_buildEditCategoryEntry(context));
    displayItems.add(const SizedBox(height: 12));

    // 整个分类区独立滚动、隐藏滚动条
    return ScrollConfiguration(
      behavior: const _NoScrollbarBehavior(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        children: displayItems,
      ),
    );
  }

  /// 首帧数据到达时执行一次的初始化（一次性，由 [_initialized] 防重入）。
  ///
  /// - 编辑/预选：初始分类是二级 → 同步展开其父分类，并滚动到目标所在行；
  /// - 新建：默认选中第一个父分类（设计预期：打开记账页就有默认分类，
  ///   避免用户漏选分类导致提交被阻断）。
  void _initOnce(CategoryPickerTree tree) {
    if (_initialized) return;
    _initialized = true;

    final initialId = widget.initialSelectedId;
    if (initialId == null) {
      if (_selectedId == null && tree.topLevel.isNotEmpty) {
        // 默认选中第一个父分类：postFrame 回调父 sheet，避免 build 中副作用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final first = tree.topLevel.first;
          _onTopCategoryTap(first, tree.children[first.id] ?? []);
        });
      }
      return;
    }

    // 编辑/预选：从树同步解析父级（一级 → 仅高亮；二级 → 展开其父分类）。
    // 共享账本 synthetic id（负数）同样在树中，一条路径覆盖两种视角。
    int? parentId;
    if (!tree.topLevel.any((c) => c.id == initialId)) {
      for (final entry in tree.children.entries) {
        if (entry.value.any((c) => c.id == initialId)) {
          parentId = entry.key;
          break;
        }
      }
    }
    if (parentId != null) {
      // 首帧 build 进行中直接赋值字段（本帧即生效，无需 setState）
      _expandedCategoryId = parentId;
    }

    // 滚动定位：GlobalKey 挂在每行第一个分类上，先定位目标分类所在行的
    // 行首 id 再取 key（目标不在行首时直接 _keys[targetId] 会取到 null，
    // 导致无法滚动到目标）。
    final scrollTargetId = parentId ?? initialId;
    final rowFirstId = _rowFirstIdOf(tree.topLevel, scrollTargetId);
    if (rowFirstId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _keys[rowFirstId]?.currentContext;
        // ctx 来自 GlobalKey，需用 ctx.mounted 而非 State.mounted
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.0,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
  }

  /// 找 [targetId] 所在行（每 [_kColumns] 个一级分类一行）的行首分类 id；未命中返回 null。
  static int? _rowFirstIdOf(List<Category> topLevel, int targetId) {
    for (int i = 0; i < topLevel.length; i += _kColumns) {
      final endIndex = (i + _kColumns).clamp(0, topLevel.length);
      final row = topLevel.sublist(i, endIndex);
      if (row.any((c) => c.id == targetId)) return row.first.id;
    }
    return null;
  }

  /// 底部「编辑分类」入口：Edit3 图标 + 文本。
  /// 分类区底部显示 Edit3 图标 + 编辑分类 文本入口。
  ///
  /// 共享账本 Editor（非 owner）置灰：分类由 Owner 维护，Editor 在共享账本下
  /// 只能选用 Owner 的分类，入口禁用并换只读提示文案。角色取自
  /// [currentLedgerProvider] 状态入口，不直连 db。
  Widget _buildEditCategoryEntry(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context);
    final ledger = ref.watch(currentLedgerProvider).value;
    final isEditorInShared =
        ledger != null && ledger.isShared && ledger.myRole != 'owner';
    final entryColor =
        isEditorInShared ? SpitoutTokens.textDisabled(context) : primary;
    return Center(
      child: InkWell(
        // 本入口位于记账 sheet 内，用户是「临时离开建分类、回来继续记这笔账」：
        // 直接按路由名 pushNamed 跳分类管理页，不做任何栈复用/popUntil，
        // 否则会把 sheet 连带 pop，已填金额/备注丢失，且 sheet Future 以 null
        // 完成被当作「用户取消」。
        onTap: isEditorInShared
            ? null
            : () =>
                Navigator.of(context).pushNamed(Routes.categoryManage),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.edit,
                size: 18,
                color: entryColor,
              ),
              const SizedBox(width: 6),
              Text(
                isEditorInShared
                    ? l10n.txEditCategoryReadOnly
                    : l10n.txEditCategory,
                style: TextStyle(
                  color: entryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 隐藏滚动条的 ScrollBehavior（分类区独立滚动、无可见滚动条）。
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(context, child, details) => child;
}

/// 二级分类选择器卡片（展开时显示在对应一级分类行下方）。
///
/// - 容器圆角 20px。
/// - 最大可视高度 200px，内部可滚动、隐藏滚动条。
/// - 视觉上与一级分类拉开层级（更小图标 + 次级色）。
class _SubcategorySelectorCard extends ConsumerWidget {
  final Category parentCategory;
  final List<Category> subCategories;
  final int? selectedId;
  final ValueChanged<Category> onSubCategoryTap;

  const _SubcategorySelectorCard({
    required this.parentCategory,
    required this.subCategories,
    required this.selectedId,
    required this.onSubCategoryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = SpitoutTokens.isDark(context);

    return Container(
      decoration: BoxDecoration(
        // bg-secondary/70 容器
        color: SpitoutTokens.surfaceCategoryIconLight(context)
            .withValues(alpha: isDark ? 1.0 : 0.7),
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: SpitoutTokens.border(context))
            : null,
      ),
      // 子分类卡片上下内边距（horizontal:3/vertical:10）
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
      // 子分类卡片最大可视高度 200px，内部可滚动、隐藏滚动条。
      // 200px 可完整容纳两行子分类（图标+标题），避免标题被底部边缘裁切。
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ScrollConfiguration(
          behavior: const _NoScrollbarBehavior(),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              // 子分类与父分类对齐同为 5 列，列间距为 0（按钮按列宽居中排布）。
              crossAxisCount: 5,
              crossAxisSpacing: 0,
              // 行距 10
              mainAxisSpacing: 10,
              // 固定行高（图标36+间距6+文字约14，留 4px 余量），
              // 不用宽高比，避免窄屏格子被压矮溢出。
              mainAxisExtent: 60,
            ),
            itemCount: subCategories.length,
            itemBuilder: (context, index) {
              final subCat = subCategories[index];
              // 子分类格子比内容略高，用外层 Center 在格子内垂直居中，
              // 不依赖 tight 约束与内容高度常量，对系统字体缩放更鲁棒；
              // 父分类沿用各自网格，不受影响。
              return Center(
                child: CategoryGridItem(
                  category: subCat,
                  selected: selectedId == subCat.id,
                  isSubCategory: true,
                  onTap: () => onSubCategoryTap(subCat),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
