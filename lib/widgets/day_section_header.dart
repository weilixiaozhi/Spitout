import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../l10n/app_localizations.dart';
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
    // 在日期 header 之前画一条弱分割线,把"天"之间的明细视觉隔开。
    // 用 outlineVariant 颜色而非固定透明度,深浅色模式下对比度都稳定。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // 不设背景色:与交易行一样透明,显示同一外层列表背景。否则暗黑下 header
          // 是 surface 深灰(#1C1C1E)、交易行是纯黑 scaffold 底,两者不协调。
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: SpitoutDimens.listHeaderVertical),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(dateText,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: grey, fontSize: 12)),
                if (week.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(week,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: grey, fontSize: 12)),
                ]
              ]),
              if (fmt(expense).isNotEmpty)
                Text('${l10n.homeExpense} ${fmt(expense)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
