import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../utils/currency/currencies.dart';
import '../theme/icons/app_icons.dart';

/// 金额栏行：[币种触发器] [金额 / 算式 / 预览结果] [删除键]。
///
/// - 币种触发器：仅展示币种名称，不显示币种符号与 ISO 代码及下拉箭头。
/// - 金额区：横向滚动 + 自动显示末尾输入（whitespace-nowrap + scroll-smooth）。
///   - waiting/calculated：仅显示最终结果；空值显示 `0`。
///   - operating：表达式 + 灰色预览结果（`算式 = 预览`）。
/// - 删除键：Delete 图标 + 「长按清空」文本；轻触删最后一位，长按 560ms 清空。
/// - 折算预览（仅外币 + waiting/calculated 状态）：`≈ ¥xx.xx CNY`。
///   计算中（operating）不显示外币换算。
///
/// 宽度对齐规则（与下方 4×4 键盘列宽一致，键盘 colWidth = (总宽 - 3×8) / 4）：
/// - 币种框宽度 = 1 列（对齐数字 1 键）；
/// - 金额区宽度 = 2 列 + 中间 8px 间距（对齐数字 2+3 键）；
/// - 删除键宽度 = 1 列（对齐乘号键）。
class AmountExpressionBar extends ConsumerStatefulWidget {
  /// 交易币种（大写 ISO）
  final String txCurrency;

  /// 账本本位币（用于判断是否外币 + 折算目标）
  final String ledgerBase;

  /// 当前输入字符串（如 "88.55" 或 "88+12"）
  final String amountStr;

  /// 运算累加值（operating 状态下显示在表达式左侧）
  final double acc;

  /// 当前运算符（null = waiting/calculated）
  final String? op;

  /// 运算符显示字形（减号用真减号 −）
  final String Function(String op) opGlyph;

  /// 运算模式下的实时总额（= acc op amountStr）
  final double equalsTotal;

  /// 计算器状态机：waiting / operating / calculated
  final String calcState;

  /// 折算预览文本（如 "≈ 86.40 CNY"）；null 表示本位币或无汇率
  final String? conversionPreview;

  /// 是否正在拉取汇率（显示「≈ …」）
  final bool rateFetching;

  /// 是否汇率缺失（可点击手填）
  final bool rateMissing;

  /// 汇率缺失提示文案
  final String rateMissingHint;

  final VoidCallback onPickCurrency;
  final VoidCallback onEditRate;
  final VoidCallback onClearAmount; // 长按清空回调
  final VoidCallback onDeleteOne; // 轻触删一位回调

  const AmountExpressionBar({
    super.key,
    required this.txCurrency,
    required this.ledgerBase,
    required this.amountStr,
    required this.acc,
    required this.op,
    required this.opGlyph,
    required this.equalsTotal,
    required this.calcState,
    required this.conversionPreview,
    required this.rateFetching,
    required this.rateMissing,
    required this.rateMissingHint,
    required this.onPickCurrency,
    required this.onEditRate,
    required this.onClearAmount,
    required this.onDeleteOne,
  });

  @override
  ConsumerState<AmountExpressionBar> createState() =>
      _AmountExpressionBarState();
}

class _AmountExpressionBarState extends ConsumerState<AmountExpressionBar> {
  // 金额区横向滚动控制器：用于自动滚动到末尾
  final ScrollController _amountScrollCtrl = ScrollController();

  @override
  void dispose() {
    _amountScrollCtrl.dispose();
    super.dispose();
  }

  /// 金额变化后自动滚动到末尾（自动显示末尾输入）
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_amountScrollCtrl.hasClients) {
        _amountScrollCtrl.jumpTo(_amountScrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(AmountExpressionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 金额字符串或预览结果变化时滚动到末尾
    if (oldWidget.amountStr != widget.amountStr ||
        oldWidget.equalsTotal != widget.equalsTotal) {
      _scrollToEnd();
    }
  }

  /// 去除金额字符串末尾多余的 0 与小数点（用于显示）
  String _trimTrailing(String s) {
    if (!s.contains('.')) return s;
    final r = s
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return r.isEmpty ? '0' : r;
  }

  /// 币种触发器：仅展示币种名称，不显示币种符号与 ISO 代码。
  ///
  /// 设计意图：记账页输入区空间紧张，符号与 ISO 在账本/汇率等入口已充分展示，
  /// 此处只保留币种名称以压缩宽度，与数字键 1 列宽对齐；名称偏长时由
  /// FittedBox 等比缩小兜底，保证不溢出窄列框。
  Widget _buildCurrencyChip(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onPickCurrency,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: SpitoutTokens.surfaceKeySecondary(context),
          borderRadius: BorderRadius.circular(12),
        ),
        // 窄列宽下名称可能略超宽：FittedBox 等比缩小兜底，保证不溢出
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              getCurrencyName(widget.txCurrency, context),
              maxLines: 1,
              style: text.bodyMedium?.copyWith(
                color: SpitoutTokens.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 金额显示区：横向滚动 + 自动滚动到末尾。
  /// overflow-x-auto + whitespace-nowrap + scroll-smooth
  Widget _buildAmountArea(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final isInCalcMode = widget.calcState == 'operating';
    final display = widget.amountStr.isEmpty ? '0' : widget.amountStr;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: SpitoutTokens.surfaceKeySecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        controller: _amountScrollCtrl,
        scrollDirection: Axis.horizontal,
        reverse: true, // reverse: true 让滚动锚定在右侧，新输入自动显现
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isInCalcMode) ...[
              // 累加值
              Text(
                _trimTrailing(widget.acc.abs().toStringAsFixed(2)),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: SpitoutTokens.textSecondary(context),
                ),
              ),
              // 运算符
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  widget.op != null ? widget.opGlyph(widget.op!) : '',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
              // 当前输入值
              Text(
                display,
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SpitoutTokens.textPrimary(context),
                ),
              ),
              // 预览结果（灰色）
              if (widget.equalsTotal != 0) ...[
                const SizedBox(width: 6),
                Text(
                  '= ${_trimTrailing(widget.equalsTotal.abs().toStringAsFixed(2))}',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: SpitoutTokens.textTertiary(context),
                  ),
                ),
              ],
            ] else
              // waiting / calculated：仅最终结果
              Text(
                display,
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SpitoutTokens.textPrimary(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 删除键：Delete 图标 + 「长按清空」文本。
  /// 轻触删最后一位，长按 560ms 清空完整表达式和金额。
  Widget _buildDeleteKey(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      // 轻触：删一位
      onTap: () {
        SystemSound.play(SystemSoundType.click);
        widget.onDeleteOne();
      },
      // 长按 560ms：清空
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onClearAmount();
      },
      onLongPressStart: (_) => HapticFeedback.selectionClick(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: SpitoutTokens.surfaceKeySecondary(context),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.backspace,
                size: 16, color: SpitoutTokens.textSecondary(context)),
            const SizedBox(height: 2),
            Text(
              l10n.txDeleteLongPress,
              style: TextStyle(
                fontSize: 8,
                height: 1,
                color: SpitoutTokens.textTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 折算预览行（仅外币 + waiting/calculated 状态）。
  /// 计算中（operating）不显示外币换算。
  Widget? _buildConversionRow(BuildContext context) {
    final isForeign = widget.txCurrency != widget.ledgerBase;
    if (!isForeign) return null;
    // operating 状态不显示折算预览
    if (widget.calcState == 'operating') return null;

    final text = Theme.of(context).textTheme;
    final display = widget.conversionPreview ??
        (widget.rateFetching ? '≈ … ${widget.ledgerBase}' : widget.rateMissingHint);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          InkWell(
            onTap: widget.rateMissing ? widget.onEditRate : null,
            child: Text(
              display,
              style: text.bodySmall?.copyWith(
                color: widget.rateMissing
                    ? Theme.of(context).colorScheme.error
                    : SpitoutTokens.textTertiary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 水平方向不设 padding，由外层 Padding 统一控制左右对齐
    return LayoutBuilder(
      builder: (ctx, c) {
        // 与 AmountKeypad 的列宽公式保持一致：(总宽 - 3 个 8px 间距) / 4。
        // 三区块按 1 / 2+8 / 1 列分配，宽度恰好铺满整行并与键盘键位一一对齐：
        //   币种框 ↔ 数字 1；金额区 ↔ 数字 2+3（含中间间距）；删除键 ↔ 乘号。
        final colWidth = (c.maxWidth - 3 * 8) / 4;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // [币种] [金额] [删除] 三列布局
            Row(
              children: [
                SizedBox(
                  width: colWidth,
                  child: _buildCurrencyChip(context),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: colWidth * 2 + 8,
                  child: _buildAmountArea(context),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: colWidth,
                  child: _buildDeleteKey(context),
                ),
              ],
            ),
            // 折算预览（仅外币 + 非计算中）
            if (_buildConversionRow(context) != null)
              _buildConversionRow(context)!,
          ],
        );
      },
    );
  }
}
