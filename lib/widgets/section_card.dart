import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../theme/shadows.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin; // 新增 margin 参数

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SpitoutDimens.p12),
    this.margin = const EdgeInsets.symmetric(horizontal: SpitoutDimens.p12), // 默认值
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SpitoutTokens.isDark(context);
    final borderWidth = SpitoutTokens.cardOuterBorderWidth(context);
    final borderColor = SpitoutTokens.cardOuterBorderColor(context);

    return Container(
      margin: margin, // 使用传入的 margin
      decoration: BoxDecoration(
        color: SpitoutTokens.surface(context), // ⭐ 使用 Token
        borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
        border: borderWidth > 0
            ? Border.all(
                color: borderColor, // ⭐ 使用卡片边框 Token
                width: borderWidth,
              )
            : null,
        boxShadow: isDark ? null : SpitoutShadows.card,  // ⭐ 暗黑模式：无阴影，亮色模式：有阴影
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
