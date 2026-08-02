import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/colors.dart';
import '../utils/category_utils.dart';
import 'category_icon.dart';
import '../theme/icons/app_icons.dart';

/// 单个分类项（图标 + 名称）。
///
/// - 父分类：图标 40×40 圆形；
///   选中 = 主色实心填充 + 白色前景；未选中 = `bg-secondary` + `text-secondary-foreground`。
/// - 含子分类的父项：右下角叠加「…」标识（与图标分开，不重叠）。
/// - 子分类：图标略小（36×36），选中态视觉与父分类一致。
///
/// 选中态为「主色实心 + 白色前景」，符合 shadcn/ui 选中态规范。
class CategoryGridItem extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final bool selected;
  final bool isSubCategory;
  final bool hasChildren;
  final bool expanded;

  const CategoryGridItem({
    super.key,
    required this.category,
    required this.onTap,
    this.selected = false,
    this.isSubCategory = false,
    this.hasChildren = false,
    this.expanded = false,
  });

  /// 构建图标（统一走 CategoryIconWidget，圆形容器）
  Widget _buildIcon(
    BuildContext context,
    double size,
    Color iconColor,
    Color bgColor,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: CategoryIconWidget(
        category: category,
        // 字形大小：父 20 / 子 18
        size: isSubCategory ? 18 : 20,
        color: iconColor,
        circular: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 父分类 40×40，子分类 36×36（视觉上拉开层级）
    final iconSize = isSubCategory ? 36.0 : 40.0;
    final fontSize = isSubCategory ? 11.0 : 12.0;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // 选中态：主色实心填充 + 白色前景
    // 未选中：secondary 背景 + secondary 前景。
    // 子分类图标不能用 surfaceCategoryIconLight——子分类卡片容器背景就是
    // 这个色，同色会让圆形彻底隐形；使用 surface（亮白/深色面）与卡片拉开对比。
    final iconBg = selected
        ? primaryColor
        : (isSubCategory
            ? SpitoutTokens.surface(context)
            : SpitoutTokens.surfaceCategoryIcon(context));
    final iconColor = selected ? Colors.white : SpitoutTokens.iconCategory(context);
    final labelColor = selected
        ? primaryColor
        : (isSubCategory
            ? SpitoutTokens.textSecondary(context)
            : SpitoutTokens.textPrimary(context));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildIcon(context, iconSize, iconColor, iconBg),
              // 有子分类时在图标右下角叠加「…」标识
              // 含子分类的父项叠加 … 标识（位于右下角，避免与左/上边缘视觉拥挤）
              if (hasChildren && !isSubCategory)
                Positioned(
                  right: -4,
                  bottom: -2,
                  child: Container(
                    // 角标 16px，避免在 40px 主图标上占比过大
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: selected
                          ? primaryColor
                          : SpitoutTokens.surfaceCategoryIcon(context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SpitoutTokens.surface(context),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        AppIcons.moreHorizontal,
                        size: 11,
                        color: selected
                            ? Colors.white
                            : SpitoutTokens.iconCategory(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CategoryUtils.getDisplayName(category.name, context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: fontSize,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: labelColor,
                ),
          ),
        ],
      ),
    );
  }
}
