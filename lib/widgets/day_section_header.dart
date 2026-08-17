import 'package:flutter/material.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'format_money.dart';

/// 日期分组标题组件
/// 全局仅支出模式，只显示当日支出合计
class DaySectionHeader extends StatelessWidget {
  final String dateText; // yyyy-MM-dd
  final double expense;
  /// 账本本位币代码（ISO 4217），用于在日支出汇总前拼上正确的货币符号。
  /// 为 null 时回退到无符号纯数字（向前兼容）。
  final String? currencyCode;
  const DaySectionHeader({
    super.key,
    required this.dateText,
    required this.expense,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    String getWeekday(String yyyyMMdd) {
      try {
        final dt = DateTime.parse(yyyyMMdd);
        final l10n = AppLocalizations.of(context);
        switch (dt.weekday) {
          case DateTime.monday:
            return l10n.commonWeekdayMonday;
          case DateTime.tuesday:
            return l10n.commonWeekdayTuesday;
          case DateTime.wednesday:
            return l10n.commonWeekdayWednesday;
          case DateTime.thursday:
            return l10n.commonWeekdayThursday;
          case DateTime.friday:
            return l10n.commonWeekdayFriday;
          case DateTime.saturday:
            return l10n.commonWeekdaySaturday;
          case DateTime.sunday:
            return l10n.commonWeekdaySunday;
          default:
            return '';
        }
      } catch (_) {
        return '';
      }
    }

    // 支出小计统一走唯一来源 formatMoneyWithCurrency（符号紧贴金额）；
    // currencyCode 为 null 时退化为无符号纯数字（向前兼容）。
    String fmt(double v) =>
        v == 0 ? '' : formatMoneyWithCurrency(v, currencyCode: currencyCode);
    final grey = SpitoutTokens.textSecondary(context);
    final week = getWeekday(dateText);
    final l10n = AppLocalizations.of(context);
    // 天与天之间的视觉区隔由 header 自身的上下留白 + 次要文字颜色完成,
    // 不再绘制分割线,与列表条目间无分隔线的简洁样式保持一致。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // 不设背景色:与交易行一样透明,显示同一外层列表背景。否则暗黑下 header
          // 是 surface 深灰(#1C1C1E)、交易行是纯黑 scaffold 底,两者不协调。
          padding: const EdgeInsets.symmetric(
              horizontal: SpitoutDimens.p12, vertical: SpitoutDimens.listHeaderVertical),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(dateText,
                    style: SpitoutTextTokens.caption(
                      context,
                    ).copyWith(color: grey)),
                if (week.isNotEmpty) ...[
                  const SizedBox(width: SpitoutDimens.p8),
                  Text(week,
                      style: SpitoutTextTokens.caption(
                        context,
                      ).copyWith(color: grey)),
                ]
              ]),
              if (fmt(expense).isNotEmpty)
                Text('${l10n.homeExpense} ${fmt(expense)}',
                    style: SpitoutTextTokens.caption(
                      context,
                    ).copyWith(color: grey)),
            ],
          ),
        ),
      ],
    );
  }
}
