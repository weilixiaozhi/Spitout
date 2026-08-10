import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/providers/providers.dart';
import 'format_money.dart';

class AmountText extends ConsumerWidget {
  final double value;
  final bool signed; // 是否显示正负号
  final int decimals;
  final TextStyle? style;
  final bool showCurrency; // 是否显示币种符号(¥/$等),默认false
  final String? currencyCode; // 指定币种代码,null时自动获取当前账本币种

  /// 金额超宽时是否等比缩小字号以完整显示（而非省略号截断）。
  ///
  /// 默认 false（沿用省略号截断，保证行内紧凑）；置为 true 后金额永不
  /// 省略/换行，而是按比例缩小字号直至完整容纳，用于"金额必须完整可见"
  /// 的场景（如分摊统计页的汇总卡、分摊详情表、转账方案）。
  final bool scaleDown;

  const AmountText({
    super.key,
    required this.value,
    this.signed = true,
    this.decimals = 2,
    this.style,
    this.showCurrency = false,
    this.currencyCode,
    this.scaleDown = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String displayText;

    if (showCurrency) {
      final effectiveCurrencyCode = currencyCode ??
          ref.watch(currentLedgerProvider).asData?.value?.currency;
      // 带币种分支统一走唯一来源 formatMoneyWithCurrency，口径如下：
      // signed 时负值带 '-'、正值不带 '+'（即自然符号，对应函数 signed=false 行为）；
      // 非 signed 时恒按绝对值显示（不区分正负）。
      displayText = signed
          ? formatMoneyWithCurrency(value,
              currencyCode: effectiveCurrencyCode, decimals: decimals)
          : formatMoneyWithCurrency(value.abs(),
              currencyCode: effectiveCurrencyCode, decimals: decimals);
    } else {
      displayText =
          formatMoneyCompact(value, maxDecimals: decimals, signed: signed);
    }

    // 主数字保持中性色 textPrimary：支出着色由外部调用方自行
    // ref.watch(expenseColorSchemeProvider) 取配色方案后显式传入，
    // AmountText 本身不感知方案。
    final baseStyle = style ??
        Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: SpitoutTokens.textPrimary(context));

    final text = Text(
      displayText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: baseStyle,
    );

    if (!scaleDown) return text;

    // scaleDown 模式：FittedBox 会按文本固有宽度排版后再等比缩放，
    // 因此内部文本永远不会触发省略号/换行，超宽时只是字号变小，
    // 始终能完整看到全部金额数字。
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: text,
    );
  }
}
