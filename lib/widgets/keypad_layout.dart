import 'keypad_constants.dart';

/// 记账页自定义键盘行高计算。
///
/// - 空间充足：键盘行高 = [maxU]，富余高度留给分类区；
/// - 空间不足（系统键盘拉起、极小屏）：键盘行高压向 [minU] 保底，
///   防止底部固定区（备注 + 金额栏 + 键盘）溢出；
/// - [minCategoryH] 是防溢出地板（约一行分类高度）。
double computeKeypadU({
  required double availableHeight,
  // —— 以下固定开销与 transaction_editor_sheet 的布局保持一致 ——
  // 分类区上方固定高度：拖拽条(16) + Header(~30) + 两条分隔线(各 1)
  double topFixed = 48,
  // 分类区下方、键盘之前的固定高度：容器内边距(10+20) + 备注行(35)
  // + 间距(5) + 金额栏(35) + 键盘前间距(10)
  double bottomFixedNoKeypad = 115,
  double minCategoryH = 96,
  // 键高范围由 KeypadLayout 常量统一维护（本次需求按键更大）：
  // 上限 45、下限 35，保证 clamp 上下界合法且按键仍可点按。
  double minU = KeypadLayout.minU,
  double maxU = KeypadLayout.maxU,
  // 4 行键盘之间 3 个 10px 纵向行距（统一来自 KeypadLayout.rowGap）。
  double keypadGap = KeypadLayout.keypadGap,
}) {
  // 键盘预算 = 可用高度 − 顶部/底部固定区 − 分类区最低可见高度；
  // 不足/超出由 clamp 封顶到 [4*minU+gap, 4*maxU+gap]
  final budget =
      availableHeight - topFixed - bottomFixedNoKeypad - minCategoryH;
  final keypadH = budget.clamp(4 * minU + keypadGap, 4 * maxU + keypadGap);
  // 键盘本体 = 4 行 + 3 个 10px 行距；反推单行 u
  return ((keypadH - keypadGap) / 4).clamp(minU, maxU);
}
