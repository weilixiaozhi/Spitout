import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logging/logger_service.dart';
import '../data/models.dart';
import '../data/repositories/support/shared_ledger_picker_filter.dart'
    show syntheticIdForSyncId;
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
      initialAmount: transaction.amount,
      initialDate: transaction.happenedAt,
      initialNote: transaction.note,
      // 多币种:编辑外币交易时汇率行按隐含汇率回显
      initialCurrencyCode: transaction.currencyCode,
      initialNativeAmount: transaction.nativeAmount,
      // AA 分摊:编辑模式回填,JSON 列解析失败按 null 兜底(视为未配置)
      initialAaMode: transaction.aaMode,
      initialAaParticipants: _parseIdList(transaction.aaParticipants),
      initialAaSplits: _parseSplits(transaction.aaSplits),
      initialPaidByUserId: transaction.paidByUserId,
    );
  }

  /// 解析 aaParticipants(JSON 数组字符串)为参与人标识列表;
  /// 空 / 解析失败返回 null(全部成员运行时展开)。
  static List<String>? _parseIdList(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return (jsonDecode(json) as List).map((e) => e.toString()).toList();
    } catch (e, st) {
      logger.warning('TransactionEditUtils', '解析 aaParticipants 失败', '$e\n$st');
      return null;
    }
  }

  /// 解析 aaSplits(JSON 对象字符串)为 参与人标识 → 金额字符串 映射;
  /// 空 / 解析失败返回 null。
  static Map<String, String>? _parseSplits(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final obj = jsonDecode(json) as Map<String, dynamic>;
      return {for (final e in obj.entries) e.key: e.value.toString()};
    } catch (e, st) {
      logger.warning('TransactionEditUtils', '解析 aaSplits 失败', '$e\n$st');
      return null;
    }
  }
}
