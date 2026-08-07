/// 记账键盘统一布局常量：键距 / 行距 / 圆角 / 行高关系的单一来源，
/// 避免各处维护导致改一处漏一处的静默失配。
class KeypadLayout {
  const KeypadLayout._();

  /// 相邻键位水平间距（px）。
  static const double gap = 2;

  /// 键盘相邻两行之间的纵向行距（px）。
  static const double rowGap = 2;

  /// 按键圆角（px）。
  static const double keyRadius = 5;

  /// 备注行比其余 5 行（金额栏 + 3 行数字 + 底部行）矮的高度（px）。
  static const double noteRowDelta = 5;

  /// 6 行键盘容器（备注 + 金额栏 + 数字网格 + 底部行）的单行高度。
  ///
  /// 容器高度 = 备注行(单行-5) + 5 个 2px 行距 + 其余 5 行(每行单行高)，
  /// 反推单行高：其余 5 行均分、备注行永远矮 [noteRowDelta]。
  static double rowHeight(double containerHeight) =>
      (containerHeight - 5 * rowGap + noteRowDelta) / 6;
}
