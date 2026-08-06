import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'keypad_constants.dart';

/// 数字键盘区：数字 / 小数点 / 运算符长条 / 日期 / 完成（等号）。
///
/// - 运算符 × ÷ − + 合并为一条纵向长条，内部均分 4 个热区（分隔线区隔）。
/// - 主按钮三态：
///   - waiting / calculated：显示 Enter 图标，点击提交。
///   - operating：显示 `=`，点击先算后进入 calculated。
/// - 键间距统一 8px。
/// - 普通键 bg-secondary、圆角 12px；主按钮 bg-primary。
///
/// 布局：
/// ```
/// [1][2][3][×]
/// [4][5][6][÷]
/// [7][8][9][−]
///      ...    [+]   ← 运算符长条 4 热区均分 3 行高度
/// [日期][0][.][=/Enter]
/// ```
///
/// 尺寸自适应：
/// - 行高不写死，由父 sheet 按可用高度算定 [u] 后下传。
/// - 所有行高、字号均从 [u] 派生，保证小屏等比缩小、大屏不溢出。
/// - 文字缩放跟随全局（main.dart 统一 ×0.85 缩小）并在 [0.85, 1.0] 封顶，
///   防止系统大字体撑爆按键。
class AmountKeypad extends StatelessWidget {
  /// 键盘单元行高（由父 sheet 按屏幕可用高度算好下传）。
  ///
  /// 设计意图：keypad 自身处于 mainAxisSize.min 容器内，LayoutBuilder 拿到的
  /// 纵向约束是 infinity，无法自行测算可用高度；故由 sheet 层算定 u 后传入。
  /// 所有行高、字号均从 u 派生，保证小屏等比缩小、大屏不溢出。
  /// 取值范围 clamp[30,35]：空间充足维持 35，紧张时压到 30（仍保证可点）。
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
  final ValueChanged<String> onApplyOp; // 4 个独立运算符之一：+ - × ÷
  final VoidCallback onApplyEquals; // operating → calculated
  final VoidCallback onPickDate;
  final VoidCallback onSubmit; // waiting/calculated → 提交

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
  });

  String _fmtDate(DateTime d) => '${d.year}/${d.month}/${d.day}';
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// 数字 / 小数点键
  Widget _numKey(
    BuildContext context,
    TextTheme text,
    String label, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: SpitoutTokens.surfaceKeySecondary(context),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          SystemSound.play(SystemSoundType.click);
          onTap();
        },
        child: Container(
          alignment: Alignment.center,
          child: Text(
            label,
            style: text.titleMedium?.copyWith(
              color: SpitoutTokens.textPrimary(context),
              // 字号从 u 派生：u=35→12.6、u=30→10.8，按键缩小时字号同步缩小
              fontSize: u * 0.36,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// 运算符长条内的单个热区（× ÷ − + 之一）。
  ///
  /// 设计意图：视觉上 4 个运算符合并为一条纵向长条，仅内部均分热区，
  /// 因此此处不自带 Material/圆角（由外层长条统一提供），只保留
  /// 点击热区与激活态高亮。
  Widget _opZone(
    BuildContext context,
    TextTheme text,
    String op, {
    required VoidCallback onTap,
    required bool isActive, // 当前激活的运算符（高亮）
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.click);
        onTap();
      },
      child: Container(
        alignment: Alignment.center,
        // 激活态仅高亮当前热区，保持长条整体感
        color: isActive ? primary.withValues(alpha: 0.15) : null,
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
                onTap: () => onApplyOp(op),
                isActive: activeOp == op,
              ),
            ),
        ],
      ),
    );
  }

  /// 日期键：点开 5 列日期滚轮；显示日期 + 时间
  Widget _dateKey(BuildContext context, TextTheme text) {
    return Material(
      color: SpitoutTokens.surfaceKeySecondary(context),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          SystemSound.play(SystemSoundType.click);
          onPickDate();
        },
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
                          // 双行日期字号从 u 派生：当前 u∈[30,35] 时 u*0.18
                          // 仅 5.4~6.3px，下限 7px 保证可读且能塞进最小键高；
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
      ),
    );
  }

  /// 完成 / 等号键：三态切换
  /// - waiting / calculated：显示 Enter（回车）图标，点击提交。
  /// - operating：显示 `=`，点击先算后进入 calculated。
  Widget _doneKey(BuildContext context, TextTheme text) {
    final primary = Theme.of(context).colorScheme.primary;
    final isInCalcMode = calcState == 'operating';
    // operating 状态下，= 始终可用；其他状态受 isDoneEnabled 控制
    final enabled = isInCalcMode || isDoneEnabled;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: enabled
          ? primary
          : SpitoutTokens.surfaceDisabled(context),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                SystemSound.play(SystemSoundType.click);
                if (isInCalcMode) {
                  onApplyEquals();
                } else {
                  onSubmit();
                }
              }
            : null,
        child: Container(
          alignment: Alignment.center,
            child: isSubmitting
              ? SizedBox(
                  // loading 尺寸从 u 派生：u=35→12.6、u=30→10.8
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
                        // 等号比数字略大：u=35→15.1、u=30→12.9
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
    // 上限 1.0 防止系统大字体撑爆按键——fontSize 已从 u 派生（u≤35），
    // 35×0.36×1.0≈12.6px 落在 35px 按键内富余。
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
              // ValueKey 便于测试定位行高，验证 u 参数化生效
              SizedBox(
                key: const ValueKey('keypad_num_grid'),
                height: 3 * u + 2 * KeypadLayout.gap, // 3 行数字键高度（每行 u + gap 8）
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
                                        onTap: () => onAppend('1'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '2',
                                        onTap: () => onAppend('2'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '3',
                                        onTap: () => onAppend('3'))),
                              ],
                            ),
                          ),
                          const SizedBox(height: KeypadLayout.gap),
                          SizedBox(
                            height: u,
                            child: Row(
                              children: [
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '4',
                                        onTap: () => onAppend('4'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '5',
                                        onTap: () => onAppend('5'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '6',
                                        onTap: () => onAppend('6'))),
                              ],
                            ),
                          ),
                          const SizedBox(height: KeypadLayout.gap),
                          SizedBox(
                            height: u,
                            child: Row(
                              children: [
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '7',
                                        onTap: () => onAppend('7'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '8',
                                        onTap: () => onAppend('8'))),
                                const SizedBox(width: KeypadLayout.gap),
                                SizedBox(
                                    width: colWidth,
                                    child: _numKey(context, text, '9',
                                        onTap: () => onAppend('9'))),
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
              const SizedBox(height: KeypadLayout.gap),
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
                            onTap: () => onAppend('0'))),
                    const SizedBox(width: KeypadLayout.gap),
                    SizedBox(
                        width: colWidth,
                        child: _numKey(context, text, '.',
                            onTap: () => onAppend('.'))),
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
