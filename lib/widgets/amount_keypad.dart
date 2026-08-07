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
/// - 水平键距 8px、行距 10px（统一来自 KeypadLayout.gap / rowGap）；
/// - 普通键 bg-secondary、圆角 12px；主按钮 bg-primary。
///
/// 布局：
/// ```
/// [1][2][3][×]
/// [4][5][6][÷]
/// [7][8][9][−]
///      ...    [+]    → 运算符长条 4 热区均分 3 行高度
/// [日期][0][.][=/Enter]
/// ```
///
/// 尺寸自适应：
/// - 行高不写死，由父 sheet 按可用高度算出 [u] 后下传。
/// - 所有行高、字号均从 [u] 派生，保证小屏等比缩小、大屏不溢出。
/// - 文字缩放跟随全局（main.dart 统一 ×0.85 缩小）并在 [0.85, 1.0] 封顶，
///   防止系统大字撑爆按钮。
class AmountKeypad extends StatelessWidget {
  /// 键盘单元行高（由父 sheet 按屏幕可用高度算好后下传）。
  ///
  /// 设计意图：keypad 自身处于 mainAxisSize.min 容器内，LayoutBuilder 拿到的
  /// 纵向约束是 infinity，无法自行测算可用高度；故由 sheet 层算出 u 后传入。
  /// 所有行高、字号均从 u 派生，保证小屏等比缩小、大屏不溢出。
  /// 取值范围 clamp[35,45]：空间充足维持 45，紧张时压到 35（仍保证可点）。
  final double u;

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
  final ValueChanged<String> onApplyOp; // 4 个独立运算符之一：× ÷ − +
  final VoidCallback onApplyEquals; // operating → calculated
  final VoidCallback onPickDate;
  final VoidCallback onSubmit; // waiting/calculated → 提交

  /// 滑出取消时回滚最近一次按下提交（由父面板提供）。
  final VoidCallback? onRollback;

  const AmountKeypad({
    super.key,
    required this.u,
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
    required VoidCallback onDown,
  }) {
    return PressKey(
      scale: 0.96,
      onDown: onDown,
      onCancel: onRollback,
      backgroundColor: SpitoutTokens.surfaceKeySecondary(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          label,
          style: text.titleMedium?.copyWith(
            color: SpitoutTokens.textPrimary(context),
            // 字号从 u 派生：u=45→16.2、u=35→12.6，按键缩小时字号同步缩小
            fontSize: u * 0.36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 运算符长条内的单个热区（× ÷ − + 之一）。
  ///
  /// 设计意图：视觉上 4 个运算符合并为一条纵向长条，仅内部均分热区，
  /// 因此此处不自带 Material/圆角（由外层长条统一提供），只保留
  /// 点击热区、按压态与激活态高亮。
  Widget _opZone(
    BuildContext context,
    TextTheme text,
    String op, {
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
            color: isActive
                ? primary
                : SpitoutTokens.textPrimary(context),
            // 运算符字号与数字键保持一致，同样从 u 派生
            fontSize: u * 0.36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 运算符长条：× ÷ − + 四热区均分整条高度，热区间无分隔线。
  Widget _opBar(BuildContext context, TextTheme text, String? activeOp) {
    // 热区定义：自上而下 × ÷ − +
    const ops = ['×', '÷', '-', '+'];
    return Material(
      color: SpitoutTokens.surfaceKeySecondary(context),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final op in ops)
            Expanded(
              child: _opZone(
                context,
                text,
                op,
                onDown: () => onApplyOp(op),
                isActive: activeOp == op,
              ),
            ),
        ],
      ),
    );
  }

  /// 日期键：按下即打开日期滚轮（弹层，无需回滚）。
  Widget _dateKey(BuildContext context, TextTheme text) {
    return PressKey(
      scale: 0.96,
      onDown: onPickDate,
      backgroundColor: SpitoutTokens.surfaceKeySecondary(context),
      borderRadius: BorderRadius.circular(12),
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
                        // 双行日期字号从 u 派生：当前 u∈[35,45] 时 u*0.18
                        // 为 6.3~8.1px，下限 7px 保证可读且能塞进最小键高；
                        // 上限 9px 防止 u 增大后溢出。
                        fontSize: (u * 0.18).clamp(7.0, 9.0)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtTime(date),
                    style: text.labelSmall?.copyWith(
                        color: SpitoutTokens.textSecondary(context),
                        fontWeight: FontWeight.w500,
                        fontSize: (u * 0.18).clamp(7.0, 9.0)),
                  ),
                ],
              )
            : Text(
                _fmtDate(date),
                style: text.labelMedium?.copyWith(
                    color: SpitoutTokens.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: (u * 0.20).clamp(9.0, 12.0)),
              ),
      ),
    );
  }

  /// 完成 / 等号键：三态切换
  /// - waiting / calculated：显示 Enter（回车）图标，松手提交（防误触）。
  /// - operating：显示 `=`，按下瞬间计算并进入 calculated，滑出取消回滚。
  Widget _doneKey(BuildContext context, TextTheme text) {
    final primary = Theme.of(context).colorScheme.primary;
    final isInCalcMode = calcState == 'operating';
    // operating 状态下始终可用；其他状态受 isDoneEnabled 控制
    final enabled = isInCalcMode || isDoneEnabled;
    final l10n = AppLocalizations.of(context);

    return PressKey(
      enabled: enabled,
      scale: 0.94,
      onDown: isInCalcMode ? onApplyEquals : null,
      onCancel: isInCalcMode ? onRollback : null,
      onUp: isInCalcMode ? null : onSubmit,
      backgroundColor: enabled
          ? primary
          : SpitoutTokens.surfaceDisabled(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        child: isSubmitting
            ? SizedBox(
                // loading 尺寸从 u 派生：u=45→16.2、u=35→12.6
                width: u * 0.36,
                height: u * 0.36,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : isInCalcMode
                ? Text(
                    '=',
                    style: TextStyle(
                      color: Colors.white,
                      // 等号比数字略大：u=45→19.4、u=35→15.1
                      fontSize: u * 0.43,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Icon(
                    AppIcons.keyboardReturn,
                    // 回车图标与等号同尺寸，从 u 派生
                    size: u * 0.43,
                    color: enabled
                        ? Colors.white
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
    // 上限 1.0 防止系统大字撑爆按键——fontSize 已从 u 派生（u≤45），
    // 45×0.36×1.0≈16.2px 落在 45px 按键内富余。
    final ts = MediaQuery.textScalerOf(context);
    final capped = TextScaler.linear(ts.scale(1.0).clamp(0.85, 1.0));

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: capped),
      child: LayoutBuilder(
        builder: (ctx, c) {
          // 4 列等宽（间隙统一来自 KeypadLayout.gap）
          final colWidth = (c.maxWidth - 3 * KeypadLayout.gap) / 4;
          return Column(
            children: [
              // 第一部分：3 行数字 + 4 个运算符键（运算符列 4 键均分 3 行高度）
              // ValueKey 便于测试定位行高，验证 u 参数化生成
              SizedBox(
                key: const ValueKey('keypad_num_grid'),
                height: 3 * u + 2 * KeypadLayout.rowGap, // 3 行数字键高度（每行 u + 行距 10）
                child: Row(
                  children: [
                    // 左侧 3×3 数字网格
                    SizedBox(
                      width: colWidth * 3 + 2 * KeypadLayout.gap,
                      child: Column(
                        children: [
                          SizedBox(
                            height: u,
                            child: Row(
                              children: [
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '1',
                                        onDown: () => onAppend('1'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '2',
                                        onDown: () => onAppend('2'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '3',
                                        onDown: () => onAppend('3'))),
                              ],
                            ),
                          ),
                          const SizedBox(height: KeypadLayout.rowGap),
                          SizedBox(
                            height: u,
                            child: Row(
                              children: [
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '4',
                                        onDown: () => onAppend('4'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '5',
                                        onDown: () => onAppend('5'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '6',
                                        onDown: () => onAppend('6'))),
                              ],
                            ),
                          ),
                          const SizedBox(height: KeypadLayout.rowGap),
                          SizedBox(
                            height: u,
                            child: Row(
                              children: [
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '7',
                                        onDown: () => onAppend('7'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '8',
                                        onDown: () => onAppend('8'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '9',
                                        onDown: () => onAppend('9'))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KeypadLayout.gap),
                    // 右侧运算符长条：× ÷ − + 四热区均分 3 行高度
                    SizedBox(
                      width: colWidth,
                      child: _opBar(context, text, activeOp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KeypadLayout.rowGap),
              // 第二部分：底部行 [日期][0][.][=/Enter]
              SizedBox(
                key: const ValueKey('keypad_bottom_row'),
                height: u,
                child: Row(
                  children: [
                    SizedBox(width: colWidth, child: _dateKey(context, text)),
                    const SizedBox(width: KeypadLayout.gap),
                    SizedBox(
                        width: colWidth,
                        child: _numKey(context, text, '0',
                            onDown: () => onAppend('0'))),
                    const SizedBox(width: KeypadLayout.gap),
                    SizedBox(
                        width: colWidth,
                        child: _numKey(context, text, '.',
                            onDown: () => onAppend('.'))),
                    const SizedBox(width: KeypadLayout.gap),
                    SizedBox(width: colWidth, child: _doneKey(context, text)),
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
