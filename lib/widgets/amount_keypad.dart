import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'keypad_constants.dart';
import 'press_key.dart';

/// 数字键盘区：数字 / 小数点 / 运算符长条 / 日期 / 完成（等号）。
///
/// - 数字、小数点、运算符在按下瞬间提交（PressKey.onDown），滑出取消时通过
///   [onRollback] 回滚最近一次提交，做到与系统键盘一样的"按下即反馈"；
/// - 完成键（提交/等号）：等号按下即算，提交松手触发，避免误触直接关页；
/// - 触觉反馈由父级金额面板统一触发，本组件不再重复触发；
/// - 水平键距 2px、行距 2px、按键圆角 5px（统一来自 KeypadLayout）；
/// - 数字/运算符为白色色块（keyDigit），日期/完成等为深灰块（keyOther）。
///
/// 布局：
/// ```
/// [1][2][3][+]
/// [4][5][6][-]
/// [7][8][9][×]
///      ...    [÷]   → 运算符长条 4 热区均分 3 行高度
/// [日期][0][.][=/Enter]
/// ```
///
/// 尺寸自适应：
/// - 行高不写死：键盘容器在 sheet 中以 Expanded 撑满剩余空间，本组件
///   从自身约束反推单行高 h（(高 - 3×2px 行距) / 4），行高、字号均从 h 派生；
/// - 文字缩放跟随全局（main.dart 统一 ×0.85 缩小）并在 [0.85, 1.0] 封顶，
///   防止系统大字撑爆按钮。
class AmountKeypad extends StatelessWidget {
  /// 当前日期（日期键显示）
  final DateTime date;

  /// 是否显示时间（决定日期键是单行日期还是日期 + 时间双行）。
  final bool showTime;

  /// 计算器状态机：waiting / operating / calculated
  final String calcState;

  /// 当前运算符（null = waiting/calculated；operating 状态下高亮对应运算符键）
  final String? op;

  /// 完成按钮是否可用（waiting/calculated 状态下：金额 > 0 且分类已选）
  final bool isDoneEnabled;

  /// 是否正在提交（显示 loading）
  final bool isSubmitting;

  /// 运算符显示字形
  final String Function(String op) opGlyph;

  final ValueChanged<String> onAppend;
  final ValueChanged<String> onApplyOp; // 4 个独立运算符之一：+ - × ÷
  final VoidCallback onApplyEquals; // operating → calculated
  final VoidCallback onPickDate;
  final VoidCallback onSubmit; // waiting/calculated → 提交

  /// 滑出取消时回滚最近一次按下提交（由父面板提供）。
  final VoidCallback? onRollback;

  const AmountKeypad({
    super.key,
    required this.date,
    required this.showTime,
    required this.calcState,
    required this.op,
    required this.isDoneEnabled,
    required this.isSubmitting,
    required this.opGlyph,
    required this.onAppend,
    required this.onApplyOp,
    required this.onApplyEquals,
    required this.onPickDate,
    required this.onSubmit,
    this.onRollback,
  });

  String _fmtDate(DateTime d) => '${d.year}/${d.month}/${d.day}';
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// 数字 / 小数点键：按下瞬间提交，滑出取消回滚。
  Widget _numKey(
    BuildContext context,
    TextTheme text,
    String label, {
    required double h,
    required VoidCallback onDown,
  }) {
    return PressKey(
      scale: 0.96,
      onDown: onDown,
      onCancel: onRollback,
      backgroundColor: SpitoutTokens.keyDigit(context),
      borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          label,
          style: text.titleMedium?.copyWith(
            color: SpitoutTokens.textPrimary(context),
            // 字号从 h 派生：h=60→21.6、h=36→13，行高缩小时字号同步缩小
            fontSize: h * 0.36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 运算符长条内的单个热区（+ - × ÷ 之一）。
  ///
  /// 设计意图：视觉上 4 个运算符合并为一条纵向长条，仅内部均分热区，
  /// 因此此处不自带 Material/圆角（由外层长条统一提供），只保留
  /// 点击热区、按压态与激活态高亮。
  Widget _opZone(
    BuildContext context,
    TextTheme text,
    String op, {
    required double h,
    required VoidCallback onDown,
    required bool isActive, // 当前激活的运算符（高亮）
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return PressKey(
      scale: 1.0, // 长条热区不做缩放，避免整条跳动
      onDown: onDown,
      onCancel: onRollback,
      backgroundColor: isActive ? primary.withValues(alpha: 0.15) : null,
      child: Container(
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Text(
          opGlyph(op),
          style: text.titleMedium?.copyWith(
            color: isActive ? primary : SpitoutTokens.textPrimary(context),
            // 运算符字号与数字键保持一致，同样从 h 派生
            fontSize: h * 0.36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 运算符长条：+ - × ÷ 四热区均分整条高度，热区间无分隔线。
  Widget _opBar(
    BuildContext context,
    TextTheme text,
    String? activeOp, {
    required double h,
  }) {
    // 热区定义：自上而下 + - × ÷
    const ops = ['+', '-', '×', '÷'];
    return Material(
      key: const ValueKey('keypad_op_bar'),
      color: SpitoutTokens.keyDigit(context),
      borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final op in ops)
            Expanded(
              child: _opZone(
                context,
                text,
                op,
                h: h,
                onDown: () => onApplyOp(op),
                isActive: activeOp == op,
              ),
            ),
        ],
      ),
    );
  }

  /// 日期键：按下即打开日期滚轮（弹层，无需回滚）。
  Widget _dateKey(BuildContext context, TextTheme text, {required double h}) {
    return PressKey(
      scale: 0.96,
      onDown: onPickDate,
      backgroundColor: SpitoutTokens.keyOther(context),
      borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: showTime
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmtDate(date),
                    style: text.labelSmall?.copyWith(
                      color: SpitoutTokens.textPrimary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: (h * 0.18).clamp(7.0, 14.0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtTime(date),
                    style: text.labelSmall?.copyWith(
                      color: SpitoutTokens.textSecondary(context),
                      fontWeight: FontWeight.w500,
                      fontSize: (h * 0.18).clamp(7.0, 14.0),
                    ),
                  ),
                ],
              )
            : Text(
                _fmtDate(date),
                style: text.labelMedium?.copyWith(
                  color: SpitoutTokens.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: (h * 0.20).clamp(9.0, 18.0),
                ),
              ),
      ),
    );
  }

  /// 完成 / 等号键：三态切换
  /// - waiting / calculated：显示 Enter（回车）图标，松手提交（防误触）。
  /// - operating：显示 `=`，按下瞬间计算并进入 calculated，滑出取消回滚。
  Widget _doneKey(BuildContext context, TextTheme text, {required double h}) {
    final isInCalcMode = calcState == 'operating';
    // operating 状态下始终可用；其他状态受 isDoneEnabled 控制
    final enabled = isInCalcMode || isDoneEnabled;
    final l10n = AppLocalizations.of(context);
    // 深灰块（keyOther）上不用白色图标，亮色用主文字色保证对比度，
    // 暗色用白/浅色文字。
    final iconColor = SpitoutTokens.isDark(context)
        ? Colors.white
        : SpitoutTokens.textPrimary(context);

    return PressKey(
      enabled: enabled,
      scale: 0.94,
      onDown: isInCalcMode ? onApplyEquals : null,
      onCancel: isInCalcMode ? onRollback : null,
      onUp: isInCalcMode ? null : onSubmit,
      backgroundColor: enabled
          ? SpitoutTokens.keyOther(context)
          : SpitoutTokens.surfaceDisabled(context),
      borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
      child: Container(
        alignment: Alignment.center,
        child: isSubmitting
            ? SizedBox(
                width: h * 0.36,
                height: h * 0.36,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            : isInCalcMode
            ? Text(
                '=',
                style: TextStyle(
                  color: iconColor,
                  fontSize: h * 0.43,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Icon(
                AppIcons.keyboardReturn,
                size: h * 0.43,
                color: enabled
                    ? iconColor
                    : SpitoutTokens.textTertiary(context),
                semanticLabel: l10n.commonFinish,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isInCalcMode = calcState == 'operating';
    // 当前激活的运算符（用于高亮）；waiting/calculated 状态无激活
    final activeOp = isInCalcMode ? op : null;

    // 文字缩放跟随全局（main.dart 已统一 ×0.85 缩小）并在 [0.85, 1.0] 封顶：
    // 下限 0.85 承接全局缩小（不能抬回 1.0，否则键盘文字与全局不一致）；
    // 上限 1.0 防止系统大字撑爆按键——fontSize 已从 h 派生。
    final ts = MediaQuery.textScalerOf(context);
    final capped = TextScaler.linear(ts.scale(1.0).clamp(0.85, 1.0));

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: capped),
      child: LayoutBuilder(
        builder: (ctx, c) {
          // 4 行（3 行数字网格 + 1 行底部）之间 3 个 2px 行距反推单行高
          final h = (c.maxHeight - 3 * KeypadLayout.rowGap) / 4;
          // 4 列等宽（间隙统一来自 KeypadLayout.gap）
          final colWidth = (c.maxWidth - 3 * KeypadLayout.gap) / 4;
          return Column(
            children: [
              // 第一部分：3 行数字 + 4 个运算符键（运算符列 4 键均分 3 行高度）
              // ValueKey 便于测试定位行高
              SizedBox(
                key: const ValueKey('keypad_num_grid'),
                height: 3 * h + 2 * KeypadLayout.rowGap,
                child: Row(
                  children: [
                    // 左侧 3×3 数字网格：三行 Expanded 均分 + 2px 行距
                    SizedBox(
                      width: colWidth * 3 + 2 * KeypadLayout.gap,
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '1',
                                    h: h,
                                    onDown: () => onAppend('1'),
                                  ),
                                ),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '2',
                                    h: h,
                                    onDown: () => onAppend('2'),
                                  ),
                                ),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '3',
                                    h: h,
                                    onDown: () => onAppend('3'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: KeypadLayout.rowGap),
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '4',
                                    h: h,
                                    onDown: () => onAppend('4'),
                                  ),
                                ),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '5',
                                    h: h,
                                    onDown: () => onAppend('5'),
                                  ),
                                ),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '6',
                                    h: h,
                                    onDown: () => onAppend('6'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: KeypadLayout.rowGap),
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '7',
                                    h: h,
                                    onDown: () => onAppend('7'),
                                  ),
                                ),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '8',
                                    h: h,
                                    onDown: () => onAppend('8'),
                                  ),
                                ),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                  width: colWidth,
                                  child: _numKey(
                                    context,
                                    text,
                                    '9',
                                    h: h,
                                    onDown: () => onAppend('9'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KeypadLayout.gap),
                    // 右侧运算符长条：+ - × ÷ 四热区均分 3 行高度
                    SizedBox(
                      width: colWidth,
                      child: _opBar(context, text, activeOp, h: h),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KeypadLayout.rowGap),
              // 第二部分：底部行 [日期][0][.][=/Enter]
              SizedBox(
                key: const ValueKey('keypad_bottom_row'),
                height: h,
                child: Row(
                  children: [
                    SizedBox(
                      width: colWidth,
                      child: _dateKey(context, text, h: h),
                    ),
                    const SizedBox(width: KeypadLayout.gap),
                    SizedBox(
                      width: colWidth,
                      child: _numKey(
                        context,
                        text,
                        '0',
                        h: h,
                        onDown: () => onAppend('0'),
                      ),
                    ),
                    const SizedBox(width: KeypadLayout.gap),
                    SizedBox(
                      width: colWidth,
                      child: _numKey(
                        context,
                        text,
                        '.',
                        h: h,
                        onDown: () => onAppend('.'),
                      ),
                    ),
                    const SizedBox(width: KeypadLayout.gap),
                    SizedBox(
                      width: colWidth,
                      child: _doneKey(context, text, h: h),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
