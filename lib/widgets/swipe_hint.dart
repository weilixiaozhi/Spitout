import 'package:flutter/material.dart';

import 'package:spitout/theme/colors.dart';

/// 左右滑动切换提示横幅（首页明细 / 统计页共用）。
///
/// 设计意图：首页与统计页都有「横向滑动列表切换月份/周期」的引导，
/// 两处共享同一套图标、字号与颜色配置，样式完全一致。这里抽成统一组件，
/// 保证「左图标 + 右 10px 次要色文字」在所有页面表现完全一致。
///
/// 约定：
/// - 统一使用手势图标（更贴合「滑动」语义）；
/// - 文字固定 10px，并使用 [SpitoutTokens.textTertiary] 次要色弱化存在感，仅作轻引导；
/// - 左右默认内边距 8，与统计页内边距一致，调用方也可按需覆盖。
class SwipeHint extends StatelessWidget {
  const SwipeHint({
    super.key,
    required this.icon,
    required this.text,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 8, 0),
  });

  /// 左侧图标（统一使用手势图标）。
  final IconData icon;

  /// 右侧提示文案（已本地化，含月份或 周/月/年 周期信息）。
  final String text;

  /// 外边距，默认左右 8、上下 0。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // 左图标 + 右 10px 次要色文字：次要色弱化，避免与正文争夺注意力。
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(icon, size: 14, color: SpitoutTokens.textTertiary(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: SpitoutTokens.textTertiary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
