import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// 底部弹层统一头部拖拽条（36x4、三级色 30% 透明、下边距 8）。
///
/// 设计意图：币种/汇率选择 sheet 与日期选择 sheet 的头部必须保持一致，
/// 拖拽条抽成共享组件后两处天然同源，后续视觉调整只改这一处。
class SheetGrabHandle extends StatelessWidget {
  const SheetGrabHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SpitoutTokens.textTertiary(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
