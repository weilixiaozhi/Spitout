import 'package:flutter/material.dart';

import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// 未设置头像时的统一占位头像 —— 虚拟用户同等 person 图标。
///
/// 样式与虚拟用户行头像保持一致：surfaceSecondary 圆形底 + person 图标，
/// 避免各处无头像时各显其态（昵称首字母 / 品牌图标等）造成视觉不统一。
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.size, double? iconSize})
      : iconSize = iconSize ?? size * 0.45;

  /// 圆形直径。
  final double size;

  /// person 图标大小，默认取直径的 45%（与虚拟用户行头像比例一致）。
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SpitoutTokens.surfaceSecondary(context),
        shape: BoxShape.circle,
      ),
      child: Icon(
        AppIcons.person,
        size: iconSize,
        color: SpitoutTokens.iconSecondary(context),
      ),
    );
  }
}
