import 'package:flutter/material.dart';

import 'package:spitout/utils/currency/currencies.dart';

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

/// 「符号 + 名称 (ISO)」布局中符号列的固定宽度。
///
/// 币种符号长短不一（如 ¥ 与 HK$ 宽度差异明显），若符号按内容自适应宽度，
/// 各行名称的起始位置会随符号宽度漂移，列表看起来参差不齐。
/// 固定列宽后，名称列在列表所有行中对齐到同一 x 位置。
/// 币种选择弹窗与欢迎页币种列表共用此宽度，保证两处 UI 口径一致。
const double kCurrencySymbolColumnWidth = 56;

/// 固定宽度的币种符号列（左对齐）。
///
/// 与 [kCurrencySymbolColumnWidth] 配套的统一实现，供币种选择弹窗、
/// 欢迎页币种列表等「符号 + 名称 (ISO)」布局复用，保证列宽与对齐口径一致。
/// 符号在列内左对齐；个别超宽符号（3 字符以上）裁剪而非挤压名称列，
/// 以牺牲符号完整性换取名称列的严格对齐。
Widget currencySymbolColumn(String currencyCode, {TextStyle? style}) {
  return SizedBox(
    width: kCurrencySymbolColumnWidth,
    child: Text(
      getCurrencySymbol(currencyCode),
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    ),
  );
}
