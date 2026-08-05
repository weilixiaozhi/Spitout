import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../data/repositories/support/shared_ledger_picker_filter.dart'
    show syntheticIdForSyncId;
import 'aa_fields_utils.dart';
import 'transaction_editor_sheet_entry.dart';

/// 交易编辑辅助（打开记账编辑 BottomSheet）。
///
/// 职责：拉起编辑器 sheet，属 UI 编排，位于 widgets/ 层；utils 层只保留
/// 纯函数工具。
class TransactionEditUtils {
  /// 打开交易编辑器（编辑模式）。
  static Future<void> editTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    Category? category,
  ) async {
    // 共享账本:Editor 视角下记的 tx,categoryId 为 null,
    // 真实引用在 categorySyncIdOverride。编辑时用 syntheticIdForSyncId 转成 picker
    // 列表里的 synthetic id,让 editor 反查时能命中"已选"。
    final int? initialCategoryId = transaction.categorySyncIdOverride != null
        ? syntheticIdForSyncId(transaction.categorySyncIdOverride!)
        : transaction.categoryId;

    if (!context.mounted) return;

    // 全局仅支出模式,交易 type 恒为 'expense',所有交易都使用同一编辑器。
    await showTransactionEditorSheet(
      context,
      initialKind: transaction.type, // 全局仅支出模式，值固定为 'expense'
      editingTransactionId: transaction.id,
      initialCategoryId: initialCategoryId,
      initialAmount: transaction.amount / 100,
      initialDate: transaction.happenedAt,
      initialNote: transaction.note,
      // 多币种:编辑外币交易时汇率行按隐含汇率回显
      initialCurrencyCode: transaction.currencyCode,
      initialNativeAmount: transaction.nativeAmount != null
          ? transaction.nativeAmount! / 100
          : null,
      // AA 分摊:编辑模式回填,JSON 列解析失败按 null 兜底(视为未配置)
      initialAaMode: transaction.aaMode,
      initialAaParticipants: parseAaParticipantIds(transaction.aaParticipants),
      initialAaSplits: parseAaSplits(transaction.aaSplits),
      initialPaidByUserId: transaction.paidByUserId,
    );
  }
}
