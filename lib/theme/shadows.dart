import 'package:flutter/material.dart';

/// 阴影令牌
class SpitoutShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    )
  ];

  /// 中央记账 FAB 阴影：比卡片更重，让黑色按钮从悬浮栏上凸起。
  static List<BoxShadow> fab = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 8,
      offset: const Offset(0, 2),
    )
  ];
}
