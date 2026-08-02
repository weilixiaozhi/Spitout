import 'package:flutter/material.dart';

import '../../data/models.dart' as db;
import '../../data/repositories/category_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/category_icon.dart';
import '../../theme/colors.dart';
import '../../theme/icons/app_icons.dart';
import '../../services/data/category_template_logic.dart';

/// 模板条目卡片（flat / hierarchical 两个模板页共用）
///
/// 右上角常驻复选框；已添加条目勾选 + 置灰，不可再点。
/// [compact] 为 true 时使用子分类紧凑样式（更小图标与字号）。
class TemplateItemTile extends StatelessWidget {
  final CategoryTemplateItem item;
  final bool selected;
  final VoidCallback onToggle;
  final bool compact;

  const TemplateItemTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onToggle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final added = item.alreadyAdded;
    // 已添加条目视觉上也保持勾选态（表达"已在分类表"）
    final checked = added || selected;
    final highlighted = selected && !added;

    return Opacity(
      // 已添加条目降透明度，直观表达"不可再操作"
      opacity: added ? 0.55 : 1,
      child: InkWell(
        onTap: added ? null : onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
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
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      resolveCategoryIcon(item.iconName),
                      size: compact ? 22 : 26,
                      color: SpitoutTokens.primary(context),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          color: SpitoutTokens.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 右上角常驻复选框
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                checked ? AppIcons.checkSquare : AppIcons.square,
                size: 16,
                color: added
                    ? SpitoutTokens.textDisabled(context)
                    : checked
                        ? SpitoutTokens.primary(context)
                        : SpitoutTokens.iconSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 模板页底部常驻操作栏
///
/// 左侧"本次已勾选 N 项"；右侧"全选/取消全选"文字链 + 添加按钮
/// （未勾选时添加按钮为禁用态）。
class TemplateBottomBar extends StatelessWidget {
  /// 本次勾选数（不含已添加条目）
  final int selectedCount;

  /// 是否已全选（决定文字链显示"全选"还是"取消全选"）
  final bool allSelected;

  /// 是否正在执行写入
  final bool isAdding;

  final VoidCallback onToggleSelectAll;
  final VoidCallback onAdd;

  const TemplateBottomBar({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.isAdding,
    required this.onToggleSelectAll,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canAdd = selectedCount > 0 && !isAdding;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: SpitoutTokens.surface(context),
        border: Border(
          top: BorderSide(color: SpitoutTokens.borderStrong(context)),
        ),
      ),
      child: Row(
        children: [
          // 左：本次已勾选计数
          Expanded(
            child: Text(
              l10n.categoryTemplateSelectedCount(selectedCount),
              style: TextStyle(
                fontSize: 13,
                color: SpitoutTokens.textSecondary(context),
              ),
            ),
          ),
          // 右：全选/取消全选文字链
          // 全选/取消全选文字链，纯动作无选中态，按原则补涟漪反馈
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onToggleSelectAll,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                allSelected
                    ? l10n.categoryTemplateDeselectAll
                    : l10n.categoryTemplateSelectAll,
                style: TextStyle(
                  fontSize: 13,
                  color: SpitoutTokens.textLink(context),
                ),
              ),
            ),
          ),
          ),
          const SizedBox(width: 8),
          // 右：添加按钮（未勾选时禁用）
          FilledButton(
            onPressed: canAdd ? onAdd : null,
            style: FilledButton.styleFrom(
              backgroundColor: SpitoutTokens.buttonPrimary(context),
              foregroundColor: SpitoutTokens.buttonPrimaryText(context),
            ),
            child: isAdding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.commonAdd),
          ),
        ],
      ),
    );
  }
}

/// 执行写入计划（flat / hierarchical 两个模板页共用）
///
/// 先建父（拿 db id），再建子（父 id 优先取新建父，其次解析已在表中的父：
/// syncId 命中优先、同名兜底——手动创建的父与模板 syncId 不同源时仍能挂接，
/// 避免误新建同名父触发 DuplicateNameException）。
/// sortOrder 策略：新父追加到现有最大一级 sortOrder 之后，避免与既有排序交错；
/// 子分类在"新父下从 0 起 / 已有父下追加到既有兄弟之后"。
///
/// 防御性去重：计划生成阶段已被 alreadyAdded 拦截的条目正常不会走到这里，
/// 但写入前仍按"同名已存在则复用/跳过"兜底，保证整个计划幂等可重入。
/// 返回实际写入的条目数（复用/跳过的条目不计入）。
Future<int> executeTemplateInsertPlan({
  required CategoryRepository repo,
  required TemplateInsertPlan plan,
  required List<db.Category> existingCategories,
}) async {
  final index = ExistingCategoryIndex([
    for (final c in existingCategories)
      (
        id: c.id,
        syncId: c.syncId,
        name: c.name,
        kind: c.kind,
        level: c.level,
        parentId: c.parentId,
      ),
  ]);

  var topSort = 0;
  for (final c in existingCategories) {
    if (c.level == 1 && c.sortOrder > topSort) topSort = c.sortOrder;
  }

  var inserted = 0;

  // 1. 先建一级分类（同名已存在 → 复用其 id，不重复创建）
  final resolvedIdBySyncId = <String, int>{};
  for (final p in plan.parentsToCreate) {
    final existingId = index.resolveLevel1Id(syncId: p.syncId, name: p.name);
    if (existingId != null) {
      resolvedIdBySyncId[p.syncId] = existingId;
      continue;
    }
    topSort += 1;
    final id = await repo.createCategory(
      name: p.name,
      kind: 'expense',
      icon: p.iconName,
      sortOrder: topSort,
      syncId: p.syncId,
    );
    resolvedIdBySyncId[p.syncId] = id;
    inserted++;
  }

  // 2. 再建二级分类
  final childSortByParentId = <int, int>{};
  for (final entry in plan.childrenToCreate) {
    final parentId = resolvedIdBySyncId[entry.parentSyncId] ??
        index.resolveLevel1Id(
            syncId: entry.parentSyncId, name: entry.parentName);
    // 父既未新建也不在表中（防御性跳过，理论上计划层补父后不会发生）
    if (parentId == null) continue;

    // 同父下已存在同名二级 → 跳过（正常路径已被 alreadyAdded 拦截，此处兜底）
    if (index.level2ExistsUnder(parentId: parentId, name: entry.child.name)) {
      continue;
    }

    // 同一父级下连续写入时，sortOrder 在已用最大值上递增
    var base = childSortByParentId[parentId];
    if (base == null) {
      var maxExisting = -1;
      for (final c in existingCategories) {
        if (c.parentId == parentId && c.sortOrder > maxExisting) {
          maxExisting = c.sortOrder;
        }
      }
      base = maxExisting;
    }
    final sort = base + 1;
    childSortByParentId[parentId] = sort;

    await repo.createSubCategory(
      parentId: parentId,
      name: entry.child.name,
      kind: 'expense',
      icon: entry.child.iconName,
      sortOrder: sort,
      syncId: entry.child.syncId,
    );
    inserted++;
  }

  return inserted;
}
