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
}
