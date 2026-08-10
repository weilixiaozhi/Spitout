/// 格式化工具函数
///
/// 包含各种数据格式化的工具函数
library;

import 'package:flutter/material.dart';
import 'package:spitout/l10n/app_localizations.dart';

/// 翻译账本名称
///
/// 如果账本名称是 "Default Ledger"，则返回国际化后的名称
/// 否则返回原始名称
String translateLedgerName(BuildContext context, String ledgerName) {
  final l10n = AppLocalizations.of(context);

  // 处理默认账本名称的多种形式
  if (ledgerName == 'Default Ledger' ||
      ledgerName == '默认账本' ||
      ledgerName == 'デフォルト家計簿' ||
      ledgerName == '기본 가계부' ||
      ledgerName == 'Standard-Kontenbuch' ||
      ledgerName == 'Livre par Défaut' ||
      ledgerName == 'Libro Predeterminado' ||
      ledgerName == '預設帳本') {
    return l10n.ledgersDefaultLedgerName;
  }

  return ledgerName;
}

/// 月份标签（不含年份）：首页与统计页共用同一出口，避免两处各写一套补零/语言分支逻辑。
///
/// 设计意图：英文用 `JAN..DEC` 三字母缩写（如 `JUL`），中文/韩文补零为
/// 两位数（如 `01月`），两处永远一致，且英文最终呈现为 `JUL · 2026` 这种样式。
String monthLabel(BuildContext context, int month) {
  // 英文统一用 JAN..DEC 三字母缩写：产品形态要求，与中文「月」、韩文「월」并列展示。
  if (Localizations.localeOf(context).languageCode == 'en') {
    const en = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return en[month - 1];
  }
  // 中文/韩文走 homeMonth 模板并补零为两位数（如 01月）
  return AppLocalizations.of(context).homeMonth(month.toString().padLeft(2, '0'));
}

/// 「月份 · 年份」账期标签：首页头部与统计页月视图共用同一出口。
///
/// 设计意图：统一口径为中文 `07月 · 2026年`、英文 `7M · 2026`，两处零差异。
String monthYearLabel(BuildContext context, int month, int year) {
  final l10n = AppLocalizations.of(context);
  return '${monthLabel(context, month)} · ${l10n.homeYear(year)}';
}
