/// 记账键盘统一布局常量：行高 / 水平键距 / 行距的单一来源，
/// 避免各处维护导致改一处漏一处的静默失配。
class KeypadLayout {
  const KeypadLayout._();

  /// 相邻键位水平间距（px）。
  static const double gap = 8;

  /// 键盘相邻两行之间的纵向行距（px）。
  static const double rowGap = 10;

  /// 键盘单元行高下限（px）：保证按键可点按。
  static const double minU = 35;

  /// 键盘单元行高上限（px）：保持整体紧凑。
  static const double maxU = 45;

  /// 4 行键盘之间 3 个纵向行距合计（px）。
  static const double keypadGap = rowGap * 3;
}
