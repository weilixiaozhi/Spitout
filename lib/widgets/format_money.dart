import 'package:intl/intl.dart';

import '../utils/currency/currencies.dart';

// 金额格式：最多保留 N 位小数，移除多余 0 和末尾小数点，添加千分位
String formatMoneyCompact(double v,
    {int maxDecimals = 2, bool signed = false}) {
  // 千分位分组 + 去尾零由 intl NumberFormat 原生完成（固定 en_US 分组符）。
  final pattern = maxDecimals > 0 ? '#,##0.${'#' * maxDecimals}' : '#,##0';
  final numberText = NumberFormat(pattern, 'en_US').format(v.abs());
  final sign = signed ? (v < 0 ? '-' : '+') : (v < 0 ? '-' : '');
  return '$sign$numberText';
}

/// 金额 + 币种符号的统一格式化（全局唯一来源）。
///
/// 设计意图：统一输出 `getCurrencySymbol + formatMoneyCompact` 的拼接，
/// 固定口径为「符号后带空格、负号在最前且负号也带空格」
/// （如 `- ¥ 72`，而非 `¥-72`），避免各展示点格式不一或漏写币种符号。
///
/// [value] 金额；数字部分恒按绝对值格式化，符号完全由外层控制，
/// 杜绝内层格式化自带负号与外层叠加成双负号（`--¥72`）。
/// [currencyCode] 币种代码（ISO 4217，大小写不敏感）；为 null/空时
/// 退化为无符号纯数字（兜底场景，如账本尚未加载）。
/// [decimals] 最大小数位（去尾零），与 [formatMoneyCompact] 一致。
/// [signed] true 时正数显式输出 `+`；false 时保留自然符号（负 `-`、正无）。
String formatMoneyWithCurrency(
  double value, {
  String? currencyCode,
  int decimals = 2,
  bool signed = false,
}) {
  final numberText = formatMoneyCompact(value.abs(), maxDecimals: decimals);
  final sign = value < 0 ? '-' : (signed ? '+' : '');
  if (currencyCode != null && currencyCode.isNotEmpty) {
    // 全局统一口径：币种符号与金额之间保留一个空格（¥ 72），负号也带空格
    // （- ¥ 72），让「符号 / 币种 / 数字」三段清晰分隔。数字恒按绝对值格式化，
    // 符号由外层 sign 控制，避免叠加成双负号。
    final symbol = getCurrencySymbol(currencyCode.toUpperCase());
    final signPart = sign.isNotEmpty ? '$sign ' : '';
    return '$signPart$symbol $numberText';
  }
  return '$sign$numberText';
}
