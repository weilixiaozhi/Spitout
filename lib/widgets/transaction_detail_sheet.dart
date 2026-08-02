import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudLedgerMember;
import 'package:spitout/providers/statistics/record_history_providers.dart';
import 'package:spitout/providers/providers.dart' show currentLedgerProvider, expenseColorSchemeProvider;
import '../theme/colors.dart';
import 'category_icon.dart';
import 'currency_flag.dart';
import 'app_sheet.dart';
import 'format_money.dart';
import 'amount_text.dart';

/// 记录详情 Bottom Sheet(对应设计稿"记录详情 Bottom Sheet")。
///
/// 列表项点击 → 打开本 Sheet(展示详情) → 点"编辑记账"进入编辑器。
/// 详情 Sheet 让用户先看再改,并集中展示协作成员与编辑历史(共享账本场景)。
///
/// [memberDisplayMap] 由调用方从 ledgerMembersProvider 构建(userId→SpitoutCloudLedgerMember),
/// 用于协作成员区块与编辑历史的操作者展示。
Future<void> showTransactionDetailSheet({
  required BuildContext context,
  required Transaction transaction,
  required Category? category,
  required Map<String, SpitoutCloudLedgerMember> memberDisplayMap,
  required Future<void> Function() onEdit,
  required Future<void> Function() onDelete,
}) {
  return showAppSheet<void>(
    context: context,
    child: _TransactionDetailBody(
      transaction: transaction,
      category: category,
      memberDisplayMap: memberDisplayMap,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _TransactionDetailBody extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Map<String, SpitoutCloudLedgerMember> memberDisplayMap;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  const _TransactionDetailBody({
    required this.transaction,
    required this.category,
    required this.memberDisplayMap,
    required this.onEdit,
    required this.onDelete,
  });

  String _displayName(String? userId) {
    if (userId == null || userId.isEmpty) return '';
    // 成员表类型为 SpitoutCloudLedgerMember,这里取真实 displayName
    return memberDisplayMap[userId]?.displayName ?? userId;
  }

  String _fmt(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = transaction;
    final historyAsync = ref.watch(recordEditHistoryProvider(t.id));
    final categoryName = category?.name ?? l10n.homeDetailCategory;

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 头部:分类图标 + 分类名 + 备注
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SpitoutTokens.surfaceSecondary(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CategoryIconWidget(category: category, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(categoryName,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: SpitoutTokens.textPrimary(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (t.note != null && t.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(t.note!,
                            style: TextStyle(
                                fontSize: 13,
                                color: SpitoutTokens.textSecondary(context)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Divider(),
          // 2. 信息区
          _InfoRow(
              label: l10n.homeDetailDate, value: _fmt(t.happenedAt)),
          _InfoRow(
            label: l10n.homeDetailAmount,
            value: formatMoneyCompact(t.amount),
            // 主金额:显示交易原币种 + 原金额(与列表项一致)。
            // 设计意图:记账时的币种和金额不受账本主币种变更影响,
            // currencyCode 为 null(历史数据)时 AmountText 自动回退到账本币种符号。
            valueWidget: AmountText(
              value: (t.type == 'expense' ? -1 : 1) * t.amount,
              signed: true,
              showCurrency: true,
              currencyCode: t.currencyCode,
              decimals: 2,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ref.watch(expenseColorSchemeProvider) == 'green' ? SpitoutTokens.success(context) : SpitoutTokens.error(context),
              ),
            ),
          ),
          if (t.currencyCode != null && t.currencyCode!.isNotEmpty)
            _InfoRow(
                label: l10n.homeDetailCurrency,
                value: t.currencyCode!,
                // 全局统一「ISO + (符号)」展示；右对齐与其他信息行一致
                valueWidget: Align(
                  alignment: Alignment.centerRight,
                  child: currencyFlagLabel(
                    context,
                    t.currencyCode!,
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: SpitoutTokens.textPrimary(context),
                    ),
                  ),
                )),
          if (t.nativeAmount != null && t.nativeAmount != t.amount)
            _InfoRow(
                label: l10n.homeDetailNativeAmount,
                // ≈ 折算金额：符号+金额统一走唯一来源 formatMoneyWithCurrency
                value: '≈ ${formatMoneyWithCurrency(t.nativeAmount!, currencyCode: ref.watch(currentLedgerProvider).asData?.value?.currency ?? 'CNY')}'),
          // 3. 协作成员(共享账本才显示:有 createdBy/lastEditedBy 时)
          if (t.createdByUserId != null || t.lastEditedByUserId != null) ...[
            _Divider(),
            _SectionLabel(text: l10n.homeDetailMembers),
            if (t.createdByUserId != null)
              _MemberRow(
                  label: l10n.homeDetailCreator,
                  name: _displayName(t.createdByUserId)),
            if (t.lastEditedByUserId != null)
              _MemberRow(
                  label: l10n.homeDetailLastEditor,
                  name: _displayName(t.lastEditedByUserId),
                  subtext: t.lastEditedAt != null ? _fmt(t.lastEditedAt!) : null),
          ],
          // 4. 编辑记录(仅供查看)
          _Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              _SectionLabel(text: l10n.homeDetailEditHistory, dense: true),
              const SizedBox(width: 6),
              Text(l10n.homeDetailEditHistoryHint,
                  style: TextStyle(
                      fontSize: 11,
                      color: SpitoutTokens.textTertiary(context))),
            ]),
          ),
          historyAsync.when(
            data: (h) => h.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.homeDetailNoHistory,
                        style: TextStyle(
                            fontSize: 13,
                            color: SpitoutTokens.textTertiary(context))))
                : Column(
                    children: [for (final e in h) _HistoryRow(e, _displayName)]),
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)))),
            error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.homeDetailNoHistory,
                    style: TextStyle(
                        fontSize: 13,
                        color: SpitoutTokens.textTertiary(context)))),
          ),
          const SizedBox(height: 16),
          // 5. 底部:删除 + 编辑按钮
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onDelete();
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: SpitoutTokens.error(context),
                    side: BorderSide(
                        color: SpitoutTokens.error(context).withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(l10n.commonDelete),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onEdit();
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(l10n.homeDetailEditButton),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: SpitoutTokens.divider(context));
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool dense;
  const _SectionLabel({required this.text, this.dense = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 0 : 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SpitoutTokens.textSecondary(context))),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  // 自定义值组件(如带币种符号与负号的金额);优先于 [value] 渲染。
  final Widget? valueWidget;
  const _InfoRow(
      {required this.label, required this.value, this.valueWidget});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color: SpitoutTokens.textSecondary(context))),
            Flexible(
              child: valueWidget ??
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: SpitoutTokens.textPrimary(context)),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class _MemberRow extends StatelessWidget {
  final String label;
  final String name;
  final String? subtext;
  const _MemberRow({required this.label, required this.name, this.subtext});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: SpitoutTokens.textSecondary(context))),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SpitoutTokens.textPrimary(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtext != null)
                    Text(subtext!,
                        style: TextStyle(
                            fontSize: 11,
                            color: SpitoutTokens.textTertiary(context))),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 编辑历史行:vN 标签 + 摘要 + 操作者 · 时间。
class _HistoryRow extends StatelessWidget {
  final RecordEditHistory h;
  final String Function(String?) displayNameOf;
  const _HistoryRow(this.h, this.displayNameOf);

  @override
  Widget build(BuildContext context) {
    final operator = displayNameOf(h.operatorUserId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 版本号标签 vN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('v${h.version}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary)),
          ),
          const SizedBox(width: 8),
          // 摘要 + 操作者·时间
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.summary,
                    style: TextStyle(
                        fontSize: 13,
                        color: SpitoutTokens.textPrimary(context)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (operator.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('$operator · ${_fmtDate(h.createdAt)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: SpitoutTokens.textTertiary(context))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
