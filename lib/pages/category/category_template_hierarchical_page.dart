import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart' as db;
import '../../l10n/app_localizations.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/post_processor.dart';
import '../../core/logging/logger_service.dart';
import '../../theme/colors.dart';
import '../../theme/icons/app_icons.dart';
import '../../services/data/category_template_logic.dart';
import '../../widgets/widgets.dart';
import 'category_template_widgets.dart';

/// 二级分类模板页（hierarchical 模板库）
///
/// 在 flat 模板页交互基础上增加：
/// - 点父分类展开/收起其子类（对齐记账页分类选择器交互）；
/// - 勾选约束：子类独立勾选不连带父（父未在表时写入计划自动补父）；
///   勾选父连带全选未添加子类，取消父连带取消全部已勾子类；
///   已在 categories 表的父/子条目（syncId 或同名命中）勾选置灰不可再选。
class CategoryTemplateHierarchicalPage extends ConsumerStatefulWidget {
  const CategoryTemplateHierarchicalPage({super.key});

  @override
  ConsumerState<CategoryTemplateHierarchicalPage> createState() =>
      _CategoryTemplateHierarchicalPageState();
}

class _CategoryTemplateHierarchicalPageState
    extends ConsumerState<CategoryTemplateHierarchicalPage> {
  /// 本次勾选的模板 key（含父 key 与子 key，不含已添加条目）
  Set<String> _selected = {};

  /// 当前展开子类的父分类 key（单展开，对齐记账页）
  String? _expandedKey;

  /// 是否正在执行写入
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catsAsync = ref.watch(categoriesWithCountProvider);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.categoryTemplateHierarchicalTitle,
            showBack: true,
          ),
          Expanded(
            child: catsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(l10n.categoryLoadFailed(e.toString()))),
              data: (cats) => _buildBody(context, l10n, cats),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建页面主体：父子组列表 + 底部操作栏
  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    List<({db.Category category, int transactionCount})> cats,
  ) {
    final existingIndex = ExistingCategoryIndex([
      for (final c in cats)
        (
          id: c.category.id,
          syncId: c.category.syncId,
          name: c.category.name,
          kind: c.category.kind,
          level: c.category.level,
          parentId: c.category.parentId,
        ),
    ]);
    final groups = buildHierarchicalTemplateGroups(l10n, existingIndex);
    // 扁平化全部条目（生成写入计划 / 统计可选数用）
    final allItems = [
      for (final g in groups) ...[g.parent, ...g.children],
    ];
    final selectableCount = allItems.where((it) => !it.alreadyAdded).length;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildGroup(context, groups[index]),
          ),
        ),
        TemplateBottomBar(
          selectedCount: _selected.length,
          allSelected:
              selectableCount > 0 && _selected.length == selectableCount,
          isAdding: _isAdding,
          onToggleSelectAll: () => setState(() {
            final all = computeHierarchicalSelectAll(groups);
            // 已全选 → 取消全选；否则全选（只含未添加条目，父随子自动连带）
            _selected = _selected.length == all.length ? {} : all;
          }),
          onAdd: () => _onAdd(l10n, allItems, cats),
        ),
      ],
    );
  }

  /// 单个父子组：父分类行 + 展开时的子分类网格
  Widget _buildGroup(BuildContext context, CategoryTemplateGroup group) {
    final parent = group.parent;
    final expanded = _expandedKey == parent.key;

    return Column(
      children: [
        _buildParentTile(context, group, expanded),
        // 展开态：父行下方内联子分类卡片（对齐记账页 _SubcategorySelectorCard 的层级观感）
        if (expanded) ...[
          const SizedBox(height: 8),
          _buildChildrenCard(context, group),
        ],
      ],
    );
  }

  /// 父分类行：图标 + 名称 + 展开箭头 + 常驻复选框
  Widget _buildParentTile(
    BuildContext context,
    CategoryTemplateGroup group,
    bool expanded,
  ) {
    final parent = group.parent;
    final added = parent.alreadyAdded;
    final checked = added || _selected.contains(parent.key);
    final highlighted = _selected.contains(parent.key) && !added;

    return Opacity(
      // 已添加父仅复选框置灰，整行保持可读（子类仍可单独勾选）
      opacity: added ? 0.75 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: highlighted
              ? SpitoutTokens.surfaceSelected(context)
              : SpitoutTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted
                ? SpitoutTokens.primary(context)
                : SpitoutTokens.borderStrong(context),
            width: highlighted ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // 点行主体：展开/收起子类（需求 9）
          onTap: () =>
              setState(() => _expandedKey = expanded ? null : parent.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  resolveCategoryIcon(parent.iconName),
                  size: 24,
                  color: SpitoutTokens.primary(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    parent.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SpitoutTokens.textPrimary(context),
                    ),
                  ),
                ),
                Icon(
                  expanded ? AppIcons.chevronUp : AppIcons.chevronDown,
                  size: 18,
                  color: SpitoutTokens.iconTertiary(context),
                ),
                const SizedBox(width: 8),
                // 常驻复选框（已添加 → 勾选置灰不可点）
                GestureDetector(
                  // key 供 widget 测试精准定位复选框（点父行其余区域是展开/收起）
                  key: ValueKey('templateParentCheckbox_${parent.key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: added ? null : () => _toggleParent(group),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      checked ? AppIcons.checkSquare : AppIcons.square,
                      size: 20,
                      color: added
                          ? SpitoutTokens.textDisabled(context)
                          : checked
                              ? SpitoutTokens.primary(context)
                              : SpitoutTokens.iconSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 展开的子分类网格卡片
  Widget _buildChildrenCard(BuildContext context, CategoryTemplateGroup group) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpitoutTokens.surface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          // 子分类格子按内容高度自适应（图标22+文字），4 列下收紧宽高比
          childAspectRatio: 1.15,
        ),
        itemCount: group.children.length,
        itemBuilder: (context, index) {
          final child = group.children[index];
          return TemplateItemTile(
            item: child,
            compact: true,
            selected: _selected.contains(child.key),
            onToggle: () => _toggleChild(group, child),
          );
        },
      ),
    );
  }

  /// 勾选/取消父分类（勾选父全选未添加子类，取消父连带取消全部已勾子类）
  void _toggleParent(CategoryTemplateGroup group) {
    setState(() {
      _selected = toggleHierarchicalSelection(
        _selected,
        parentKey: group.parent.key,
        allChildKeys: [for (final c in group.children) c.key],
        selectableChildKeys: [
          for (final c in group.children)
            if (!c.alreadyAdded) c.key,
        ],
      );
    });
  }

  /// 勾选/取消子分类（独立切换不连带父；父未在表时由写入计划兜底补父）
  void _toggleChild(CategoryTemplateGroup group, CategoryTemplateItem child) {
    if (child.alreadyAdded) return;
    setState(() {
      _selected = toggleHierarchicalSelection(
        _selected,
        parentKey: group.parent.key,
        childKey: child.key,
      );
    });
  }

  /// 点击"添加"：二次确认 → 写入 categories 表（父先子后）
  Future<void> _onAdd(
    AppLocalizations l10n,
    List<CategoryTemplateItem> allItems,
    List<({db.Category category, int transactionCount})> cats,
  ) async {
    final plan = buildInsertPlan(allItems: allItems, selectedKeys: _selected);
    if (plan.total == 0) return;

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.categoryTemplateConfirmTitle,
      message: l10n.categoryTemplateConfirmMessage(plan.total),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isAdding = true);
    try {
      final repo = ref.read(repositoryProvider);
      final added = await executeTemplateInsertPlan(
        repo: repo,
        plan: plan,
        existingCategories: [for (final c in cats) c.category],
      );
      logger.info('categoryTemplate', 'hierarchical 模板写入 $added 个分类');
      // 分类是 user-scoped 资源，ChangeTracker 记在 ledgerId=0；
      // 用当前账本触发一次 sync 即时推到服务端（与编辑页手动新增同策略）。
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      if (mounted) {
        showToast(context, l10n.categoryTemplateAddSuccess(added));
        // 清空本次勾选；新写入条目经 stream 自动变为"已添加"置灰态
        setState(() => _selected = {});
      }
    } catch (e, st) {
      // 常见冲突：同作用域存在同名自定义分类（DuplicateNameException）
      logger.error('categoryTemplate', 'hierarchical 模板写入失败', e, st);
      if (mounted) {
        showToast(context, l10n.categoryTemplateAddFailed(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }
}