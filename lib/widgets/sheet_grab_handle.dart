import 'package:flutter/material.dart';

import 'package:spitout/theme/colors.dart';

/// 底部弹层统一头部拖拽条（36x4 圆角条、muted 色调、距顶 8px）。
///
/// 所有 BottomSheet（AppSheet / 币种汇率选择 / 日期选择 / 记账编辑器）共用本组件，
/// 颜色走 [SpitoutTokens.grabHandleColor] 主题 token，视觉调整只改这一处；
/// 不用 Material 自带 showDragHandle，以统一 shadcn/ui 视觉。
class SheetGrabHandle extends StatelessWidget {
  const SheetGrabHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: SpitoutTokens.grabHandleColor(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
