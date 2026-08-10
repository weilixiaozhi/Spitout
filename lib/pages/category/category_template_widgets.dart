import 'package:flutter/material.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/widgets/category_icon.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/providers/providers.dart';

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
