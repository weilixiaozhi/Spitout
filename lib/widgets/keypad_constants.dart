/// 记账键盘统一布局常量。
///
/// 行高 / 间隙原先在 keypad_layout.dart 与 amount_keypad.dart 各自维护，
/// 收紧为单一来源，避免改一处漏一处的静默失配。
class KeypadLayout {
  const KeypadLayout._();

  /// 相邻键位水平 / 纵向间距（px）。
  static const double gap = 8;

  /// 键盘单元行高下限（px）：保证按键可点按。
  static const double minU = 30;

  /// 键盘单元行高上限（px）：保持整体紧凑。
  static const double maxU = 35;

  /// 4 行键盘之间 3 个纵向间距合计（px）。
  static const double keypadGap = gap * 3;
}
