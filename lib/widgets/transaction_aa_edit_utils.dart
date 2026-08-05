import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/logger_service.dart';
import '../data/models.dart';
import '../data/repositories/support/shared_ledger_picker_filter.dart'
    show syntheticIdForSyncId;
import '../l10n/app_localizations.dart';
import '../routes.dart';
import '../services/statistics/aa_edit_models.dart';
import '../services/statistics/aa_statistics_service.dart' show AaMode;
import '../utils/category_utils.dart';
import 'toast.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/providers/core/post_processor.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart'
    show markTxEditedFromUi, currentOperatorUserIdFromUi;

/// 从详情页直接编辑分摊的工具(绕过编辑记账器)。
///
/// 设计意图:开启分摊的账本,详情页常驻「编辑分摊」按钮,
/// 用户无需进入编辑记账器即可调整分摊方式/参与人/金额。
/// 流程:
/// 1. 用交易当前分摊态构造 [AaEditPageArgs],push [Routes.aaEdit];
/// 2. 拿到 [AaEditResult] 后,仅更新 AA 相关字段(amount 等保持原值);
/// 3. 触发同步、失效相关缓存。
///
/// 不分摊的交易也允许进入,默认选中不分摊,在 [AaEditPage] 内可切到其他方式。
class TransactionAaEditUtils {
  /// 打开分摊编辑页并落库结果。取消则不落库、不弹错误。
  static Future<void> editTransactionAa(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    Category? category,
  ) async {
    final ledgerId = ref.read(currentLedgerIdProvider);
    final ledger = ref.read(currentLedgerProvider).asData?.value;
    if (ledger == null) {
      logger.warning('TransactionAaEditUtils', '账本未就绪,无法编辑分摊', null);
      return;
    }

    // 分类显示名(供 AaEditPage 主体卡只读展示)。
    // 共享账本 synthetic category 名字直接用 c.name,本地账本用 displayName。
    final categoryName = category != null
        ? CategoryUtils.getDisplayName(category.name, context)
        : AppLocalizations.of(context).homeDetailCategory;

    // 当前分摊态作为初值;不分摊也允许进入(默认选中不分摊,可切换)。
    final mode = AaMode.fromDb(transaction.aaMode);

    if (!context.mounted) return;

    final result = await Navigator.of(context).pushNamed(
      Routes.aaEdit,
      arguments: AaEditPageArgs(
        ledgerId: ledgerId,
        amount: transaction.amount,
        currencyCode: transaction.currencyCode,
        categoryName: categoryName,
        categoryIconName: category?.icon,
        date: transaction.happenedAt,
        mode: mode,
        paidByUserId: transaction.paidByUserId,
        participantIds: _parseIdList(transaction.aaParticipants),
        splits: _parseSplits(transaction.aaSplits),
      ),
    ) as AaEditResult?;

    if (result == null) return; // 用户取消
    if (!context.mounted) return;

    // 落库:仅更新 AA 字段,其他字段(amount/category/note 等)保持原值。
    // updateTransaction 的 aa* 参数 null = 不更新,故切换「指定 → 不分摊」时
    // 需显式传空串清空旧 aaParticipants/aaSplits。
    // 支出人(paidByUserId)属全局交易语义(非 AA 专属):未手选回传 null 不更新
    // 保持原值,手选后恒写手选值,不受分摊方式切换影响。
    final repo = ref.read(repositoryProvider);
    final newVersion = await repo.updateTransaction(
      id: transaction.id,
      type: transaction.type,
      amount: transaction.amount,
      categoryId: transaction.categoryId ??
          (transaction.categorySyncIdOverride != null
              ? syntheticIdForSyncId(transaction.categorySyncIdOverride!)
              : null),
      note: transaction.note,
      happenedAt: transaction.happenedAt,
      categorySyncIdOverride: transaction.categorySyncIdOverride,
      excludeFromStats: transaction.excludeFromStats,
      currencyCode: transaction.currencyCode,
      nativeAmount: transaction.nativeAmount,
      paidByUserId: result.paidByUserId,
      aaMode: result.aaMode,
      aaParticipants: result.aaParticipants == null
          ? ''
          : jsonEncode(result.aaParticipants),
      aaSplits: result.aaSplits != null
          ? jsonEncode(result.aaSplits)
          : '',
    );

    // 共享账本:本地 lastEditedByUserId 立即回填。
    await markTxEditedFromUi(ref, transaction.id);

    // 编辑历史闭环:追加一条同版本号快照,详情页编辑记录区块可见。
    final operatorUserId = await currentOperatorUserIdFromUi(ref);
    // 跨异步间隙后使用 l10n,需取 context.mounted 兜底;这里已通过前面校验,
    // 但严格满足 lint:在 await 后用 l10n 提取前重新读 mounted。
    final l10n = context.mounted ? AppLocalizations.of(context) : null;
    final summary =
        '${category?.name ?? l10n?.homeDetailCategory ?? ''}'
        ' · ${transaction.amount.toStringAsFixed(2)} · '
        '${transaction.happenedAt.year}-${transaction.happenedAt.month.toString().padLeft(2, '0')}-'
        '${transaction.happenedAt.day.toString().padLeft(2, '0')} '
        '${transaction.happenedAt.hour.toString().padLeft(2, '0')}:'
        '${transaction.happenedAt.minute.toString().padLeft(2, '0')}';
    await repo.appendEditHistory(
      recordId: transaction.id,
      version: newVersion,
      operatorUserId: operatorUserId,
      summary: summary,
    );
    ref.invalidate(recordEditHistoryProvider(transaction.id));

    // 同步与统计刷新(与编辑记账器提交后保持一致)。
    PostProcessor.sync(ref, ledgerId: ledgerId);
    ref.invalidate(countsForLedgerProvider(ledgerId));
    ref.read(statsRefreshProvider.notifier).tick();

    if (context.mounted) {
      showToast(context, AppLocalizations.of(context).commonSave);
    }
  }

  /// 解析 aaParticipants(JSON 数组字符串)为参与人标识列表;
  /// 空 / 解析失败返回 null(全部成员运行时展开)。
  static List<String>? _parseIdList(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return (jsonDecode(json) as List).map((e) => e.toString()).toList();
    } catch (e, st) {
      logger.warning('TransactionAaEditUtils', '解析 aaParticipants 失败', '$e\n$st');
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
      logger.warning('TransactionAaEditUtils', '解析 aaSplits 失败', '$e\n$st');
      return null;
    }
  }
}
