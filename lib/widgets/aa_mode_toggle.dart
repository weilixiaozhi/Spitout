import 'package:flutter/material.dart';

import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';

/// 分摊方式三态切换按钮（人均 / 不分摊 / 指定分摊）。
///
/// 设计意图：记账编辑器头部与编辑分摊页共用同一按钮，保证两处切换体验统一；
/// 尺寸 80x24 / 圆角 radius4 / 字号 12，随全局 ×0.85 文字缩放同步缩小的规格。
class AaModeToggle extends StatelessWidget {
  /// 当前分摊方式文案（如「人均分摊」）。
  final String modeText;

  /// 单点循环切换回调。
  final VoidCallback onTap;

  /// 按钮本体的 key（供测试定位/外部区分）。
  final Key? toggleKey;

  const AaModeToggle({
    super.key,
    required this.modeText,
    required this.onTap,
    this.toggleKey,
  });

  @override
  Widget build(BuildContext context) {
    // 边框色:文字三级色 35% 透明度,亮暗模式下均清晰可见但不抢眼
    final borderColor = SpitoutTokens.textTertiary(
      context,
    ).withValues(alpha: 0.35);
    final arrowColor = SpitoutTokens.iconTertiary(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SpitoutDimens.radius4),
        child: Container(
          key: toggleKey,
          // 固定宽度 80:完整容纳最长文案「人均分摊」(4 字 @12px≈48px)
          // + 左右箭头(20px) + 内边距,不随当前方式文字长度变化
          width: 80,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p4),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(SpitoutDimens.radius4),
          ),
          child: Row(
            children: [
              Icon(AppIcons.chevronLeft, size: 10, color: arrowColor),
              Expanded(
                child: Text(
                  modeText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textTertiary(context)),
                ),
              ),
              Icon(AppIcons.chevronRight, size: 10, color: arrowColor),
            ],
          ),
        ),
      ),
    );
  }
}
