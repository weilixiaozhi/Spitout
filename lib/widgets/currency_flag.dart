import 'package:flutter/material.dart';

import '../utils/currency/currencies.dart';

/// 全局统一的币种展示行，例：CNY (¥)。
///
/// LedgerCard、编辑账本主币种入口、汇率管理基准币种入口、记账详情货币行、
/// 记账触发器等所有「展示当前币种」的位置统一调用此函数，保证 ISO 代码 /
/// 符号的拼装口径一致。
///
/// 格式：ISO 代码 + 空格 + 半角括号包裹的币种符号。
/// 例：CNY (¥)。
///
/// - [textStyle] 文本样式，默认继承父级 DefaultTextStyle；
/// - [flexible] 为 true 时文本溢出以省略号收尾（需父级提供有界宽度，如 Expanded）；
///   为 false 时直接裁剪（clip），适配胶囊 / trailing 等自适应宽度场景。
Widget currencyFlagLabel(
  BuildContext context,
  String currencyCode, {
  TextStyle? textStyle,
  bool flexible = false,
}) {
  final code = currencyCode.toUpperCase();
  // 拼装「ISO + (符号)」两段，符号用半角括号包裹以与 ISO 区分。
  final label = '$code (${getCurrencySymbol(currencyCode)})';
  return Text(
    label,
    style: textStyle,
    maxLines: 1,
    overflow: flexible ? TextOverflow.ellipsis : TextOverflow.clip,
  );
}
