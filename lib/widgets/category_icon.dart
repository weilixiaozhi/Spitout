import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/theme/icons/category_icons.dart';

/// 获取分类的图标数据。**只读 `category.icon` 字段**,不按名字推导。
///
/// `Category.icon` 存的是 Lucide 图标名，经 [lucideIconLibrary] 注册表反解为
/// IconData；空值/未命中统一回退 [lucideFallback]。
///
/// [category] 分类对象
IconData getCategoryIconData({Category? category}) {
  return lucideIconLibrary[category?.icon] ?? lucideFallback;
}

/// 按 Lucide 图标名直接解析 [IconData]，未命中统一回退 [lucideFallback]。
///
/// 设计意图：把"字符串 → 字形"的映射收敛到 UI 层（本文件），让分类模板页等
/// 仅需展示单个图标名的场景也能复用同一套解析口径。`lucideIconLibrary[iconName]`
/// 对 null、空串、未知键均返回 null，一次 lookup 即天然完成"归一化 + 兜底"，
/// 无需单独维护兜底名字符串常量。
IconData resolveCategoryIcon(String? iconName) {
  return lucideIconLibrary[iconName] ?? lucideFallback;
}

/// 分类图标组件
/// 仅支持 Lucide 内置图标（单色可随主题着色），不支持自定义图片。
class CategoryIconWidget extends ConsumerWidget {
  final Category? category;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final bool showBackground;
  final bool circular; // 是否使用完全圆形（50%圆角），默认为微圆角（20%）

  const CategoryIconWidget({
    super.key,
    this.category,
    this.size = 24,
    this.color,
    this.backgroundColor,
    this.showBackground = false,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final iconColor = color ?? primaryColor;

    // 使用 Lucide 图标（IconData 用法与 Material 一致，color 直接着色）
    final iconData = getCategoryIconData(category: category);

    if (showBackground) {
      return Container(
        width: size * 1.5,
        height: size * 1.5,
        decoration: BoxDecoration(
          color: backgroundColor ?? iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(
              circular ? size * 0.75 : size * 0.375),
        ),
        child: Center(
          child: Icon(iconData, size: size, color: iconColor),
        ),
      );
    }

    return Icon(iconData, size: size, color: iconColor);
  }
}
