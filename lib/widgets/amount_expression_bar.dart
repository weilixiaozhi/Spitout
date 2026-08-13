import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'currency_flag.dart';
import 'keypad_constants.dart';
import 'press_key.dart';

/// 金额栏行：[币种触发器] [金额 / 算式 / 预览结果] [删除键]。
///
/// - 币种触发器：全局统一展示「ISO + (符号)」（如 CNY (¥)），与账本卡片、
///   记账详情等所有币种展示点共用 currencyFlagLabel 口径。
/// - 金额区：横向滚动 + 自动显示末尾输入（whitespace-nowrap + scroll-smooth）。
///   - waiting/calculated：仅显示最终结果；空值显示 `0`。
///   - operating：表达式 + 灰色预览结果（`算式 = 预览`）。
///   - 折算预览（外币时三态都显示）：金额区第二行、固定右对齐、不随金额
///     滚动；字号随行高自适应收缩，短屏也永远显示，且不破坏 6 行等高。
/// - 删除键：Delete 图标 + 「长按清空」文本；轻触删最后一位，长按 560ms 清空。
///
/// 宽度对齐规则（与下方 4×4 键盘列宽一致，键盘 colWidth = (总宽 - 3×2) / 4）：
/// - 币种框宽度 = 1 列（对齐数字 1 键）；
/// - 金额区宽度 = 2 列 + 中间 [KeypadLayout.gap] 间距（对齐数字 2+3 键）；
/// - 删除键宽度 = 1 列（对齐运算符键）。
///
/// 行高：由父级键盘容器按剩余空间算好后以 SizedBox 提供，本组件行内
/// 三个区块横向 stretch 填满整行，不写死绝对像素。
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
  /// 滑出取消时回滚最近一次按下提交（由父面板提供）。
  final VoidCallback? onRollback;

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
    this.onRollback,
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

  /// 金额变化后自动滚动到末尾（自动显示末尾输入）。
  ///
  /// 金额区是 `reverse: true` 的横向滚动视图（锚定右侧），offset 0 即内容
  /// 末端；不要跳 `maxScrollExtent`——reverse 模式下那对应内容起点，会把
  /// 视图滚回开头，导致超宽金额/算式停在开头而不是最新输入/`=` 预览。
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_amountScrollCtrl.hasClients) {
        _amountScrollCtrl.jumpTo(0);
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

  /// 币种触发器：展示全局统一的「ISO + (符号)」（如 CNY (¥)）。
  ///
  /// 设计意图：与首页卡片账本徽章、记账详情等所有币种展示点共用
  /// currencyFlagLabel 全局口径；窄框内由 FittedBox 等比缩小兜底。
  Widget _buildCurrencyChip(BuildContext context, double rowH) {
    final text = Theme.of(context).textTheme;
    // 与数字键字号统一从行高 h 派生（h*0.36），字重同为 w600
    final fontSize = (rowH * 0.36).clamp(12.0, 20.0).toDouble();
    return InkWell(
      borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
      onTap: widget.onPickCurrency,
      child: Container(
        key: const ValueKey('amount_currency_chip'),
        padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p4),
        decoration: BoxDecoration(
          color: SpitoutTokens.keyDigit(context),
          borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
        ),
        // 符号与 ISO 拼装后宽度可能超过 1 列：FittedBox 等比缩小兜底，保证不溢出
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: currencyFlagLabel(
              context,
              widget.txCurrency,
              textStyle: text.bodyMedium?.copyWith(
                color: SpitoutTokens.textPrimary(context),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 金额显示区：两行结构，行总高仍等于父级行高 h。
  /// - 上行：金额/算式，横向滚动 + 自动滚动到末尾；
  /// - 下行：外币折算预览，固定右对齐、不随金额滚动；
  /// - 三态（等待/计算中/已计算）都显示；字号随 h 自适应收缩，
  ///   短屏/小 h 下预览永远保留，只是字变小。
  Widget _buildAmountArea(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final isInCalcMode = widget.calcState == 'operating';
    final display = widget.amountStr.isEmpty ? '0' : widget.amountStr;
    final isForeign = widget.txCurrency != widget.ledgerBase;
    final preview =
        widget.conversionPreview ??
        (widget.rateFetching
            ? '≈ … ${widget.ledgerBase}'
            : widget.rateMissingHint);

    return LayoutBuilder(
      builder: (ctx, c) {
        final h = c.maxHeight;
        // 两行都随行高收缩：h≈45 → 金额 21 / 预览 10；h≈25 → 金额 12 / 预览 8
        final mainSize = (h * 0.46).clamp(12.0, 21.0).toDouble();
        final previewSize = (h * 0.22).clamp(8.0, 12.0).toDouble();
        return Container(
          key: const ValueKey('amount_area'),
          padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p12, vertical: SpitoutDimens.p4),
          decoration: BoxDecoration(
            color: SpitoutTokens.keyDigit(context),
            borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 上行：金额 / 算式（横向滚动，自动滚动到末尾）
              Expanded(
                child: SingleChildScrollView(
                  controller: _amountScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  reverse: true, // 锚定右侧，新输入自动显现
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isInCalcMode) ...[
                        // 累加值
                        Text(
                          _trimTrailing(widget.acc.abs().toStringAsFixed(2)),
                          style: text.titleMedium?.copyWith(color: SpitoutTokens.textSecondary(context),
                            fontSize: mainSize,
                            height: 1.0),
                        ),
                        // 运算符
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p4),
                          child: Text(
                            widget.op != null ? widget.opGlyph(widget.op!) : '',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: primary,
                              fontSize: mainSize,
                              height: 1.0,
                            ),
                          ),
                        ),
                        // 当前输入值
                        Text(
                          display,
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: SpitoutTokens.textPrimary(context),
                            fontSize: mainSize,
                            height: 1.0,
                          ),
                        ),
                        // 预览结果（灰色）
                        if (widget.equalsTotal != 0) ...[
                          const SizedBox(width: SpitoutDimens.p4),
                          Text(
                            '= ${_trimTrailing(widget.equalsTotal.abs().toStringAsFixed(2))}',
                            style: text.titleMedium?.copyWith(color: SpitoutTokens.textTertiary(context),
                              fontSize: mainSize,
                              height: 1.0),
                          ),
                        ],
                      ] else
                        // waiting / calculated：仅最终结果
                        Text(
                          display,
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: SpitoutTokens.textPrimary(context),
                            fontSize: mainSize,
                            height: 1.0,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 下行：外币折算预览（外币时三态都显示，短屏也不隐藏）
              if (isForeign) ...[
                const SizedBox(height: SpitoutDimens.p4),
                GestureDetector(
                  onTap: widget.rateMissing ? widget.onEditRate : null,
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: widget.rateMissing
                          ? Theme.of(context).colorScheme.error
                          : SpitoutTokens.textTertiary(context),
                      fontSize: previewSize,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 删除键：Delete 图标 + 「长按清空」文本。
  /// 按下瞬间删最后一位（滑出取消回滚），长按 560ms 清空完整表达式和金额。
  Widget _buildDeleteKey(BuildContext context, double rowH) {
    final l10n = AppLocalizations.of(context);
    // 图标 / 文字字号随行高 h 派生，保持与其他键位比例一致
    final iconSize = (rowH * 0.34).clamp(12.0, 16.0).toDouble();
    final labelSize = (rowH * 0.17).clamp(6.0, 8.0).toDouble();
    return PressKey(
      scale: 1.0,
      // 按下瞬间删一位，滑出取消回滚
      onDown: widget.onDeleteOne,
      onCancel: widget.onRollback,
      // 长按 560ms：清空（触觉由面板统一触发）
      onLongPress: widget.onClearAmount,
      // 与数字键同底色:全局键盘仅确认键异色
      backgroundColor: SpitoutTokens.keyDigit(context),
      borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
      child: Container(
        key: const ValueKey('amount_delete_key'),
        padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p8),
        // 短屏行高变小（如 25px）时整组等比缩小，避免溢出
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppIcons.backspace,
                size: iconSize,
                color: SpitoutTokens.textSecondary(context),
              ),
              const SizedBox(height: SpitoutDimens.p4),
              Text(
                l10n.txDeleteLongPress,
                style: TextStyle(
                  fontSize: labelSize,
                  height: 1,
                  color: SpitoutTokens.textTertiary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 水平方向不设 padding，由外层 Padding 统一控制左右对齐
    return LayoutBuilder(
      builder: (ctx, c) {
        // 与 AmountKeypad 的列宽公式保持一致：(总宽 - 3 个键间距) / 4，
        // 键间距统一来自 KeypadLayout.gap。
        // 三区块按 1 / 2 列+[KeypadLayout.gap] / 1 列分配，宽度恰好铺满整行并与键盘键位一一对齐：
        //   币种框 ↔ 数字 1；金额区 ↔ 数字 2+3（含中间间距）；删除键 ↔ 运算符键。
        final colWidth = (c.maxWidth - 3 * KeypadLayout.gap) / 4;
        // 行高 h：金额栏是 6 行键盘中的 1 行，高度由父级 SizedBox 提供
        final rowH = c.maxHeight;
        return Row(
          // 行高由父级 SizedBox 提供，横向 stretch 让三个区块统一填满整行
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: colWidth, child: _buildCurrencyChip(context, rowH)),
            const SizedBox(width: KeypadLayout.gap),
            SizedBox(
              width: colWidth * 2 + KeypadLayout.gap,
              child: _buildAmountArea(context),
            ),
            const SizedBox(width: KeypadLayout.gap),
            SizedBox(width: colWidth, child: _buildDeleteKey(context, rowH)),
          ],
        );
      },
    );
  }
}
