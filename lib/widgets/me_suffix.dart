import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/colors.dart';

/// 「(我)」后缀的共享渲染单元,统一成员管理/成员支出/AA 记账页支出人/
/// 交易详情等所有展示本人位置的「(我)」字号、字重、颜色与间距。
///
/// 设计意图:统一「(我)」的字号、颜色与间距。凡需展示「(我)」的位置
/// 统一使用本组件(或 [meSuffixSpan]),保证 UI 规范全局一致。
class MeSuffix extends StatelessWidget {
  const MeSuffix({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 间距统一由后缀文本自带的前导空格提供（「 (我)」），与 meSuffixSpan
    // 口径完全一致；不叠加 SizedBox，避免 4px + 1 空格的双重间距。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ' (${l10n.aaMe})',
          style: TextStyle(
            color: SpitoutTokens.textTertiary(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// 构建「(我)」后缀的 [TextSpan],供 `Text.rich` 等需要部分文本不同样式的
/// 场景使用(如信息行右对齐值、历史行操作者),样式与 [MeSuffix] 完全一致。
TextSpan meSuffixSpan(BuildContext context, AppLocalizations l10n) {
  return TextSpan(
    text: ' (${l10n.aaMe})',
    style: TextStyle(
      color: SpitoutTokens.textTertiary(context),
      fontSize: 12,
    ),
  );
}

/// 从纯展示名剥离末尾的「(我)」后缀(仅无昵称兜底「未设置昵称(我)」时存在)。
///
/// 本人「(我)」标记统一由 UI 层渲染,数据层只保留纯名字,避免各模块
/// 各自拼接导致字号/颜色/空格格式不一致。
String stripMeSuffix(String name, AppLocalizations l10n) {
  final suffix = '(${l10n.aaMe})';
  return name.endsWith(suffix)
      ? name.substring(0, name.length - suffix.length)
      : name;
}
