import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../cloud/sync/sync_diff_service.dart';
import '../../theme/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/amount_text.dart';

/// 同步预览弹窗
///
/// 展示新增/修改/删除的变更列表，支持分项勾选
/// 返回用户选中的 `List<SyncChange>` 或 null（取消）
Future<List<SyncChange>?> showSyncPreviewDialog(
  BuildContext context, {
  required SyncPreview preview,
  required Color primaryColor,
}) {
  return showDialog<List<SyncChange>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SyncPreviewDialog(
      preview: preview,
      primaryColor: primaryColor,
    ),
  );
}

class _SyncPreviewDialog extends StatefulWidget {
  final SyncPreview preview;
  final Color primaryColor;

  const _SyncPreviewDialog({
    required this.preview,
    required this.primaryColor,
  });

  @override
  State<_SyncPreviewDialog> createState() => _SyncPreviewDialogState();
}

class _SyncPreviewDialogState extends State<_SyncPreviewDialog> {
  late final List<SyncChange> _changes;

  /// 弹窗内的勾选状态副本:key 为 SyncChange 对象(默认按身份比较),
  /// 不直接改写 preview.changes 里共享的 selected 字段,避免影响调用方数据。
  late final Map<SyncChange, bool> _selected;

  @override
  void initState() {
    super.initState();
    _changes = widget.preview.changes;
    _selected = {for (final c in _changes) c: c.selected};
  }

  int get selectedCount => _changes.where((c) => _selected[c] ?? true).length;
  bool get allSelected => _changes.every((c) => _selected[c] ?? true);

  void _toggleAll() {
    setState(() {
      final newValue = !allSelected;
      for (final c in _changes) {
        _selected[c] = newValue;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final addedChanges =
        _changes.where((c) => c.type == SyncChangeType.added).toList();
    final modifiedChanges =
        _changes.where((c) => c.type == SyncChangeType.modified).toList();
    final deletedChanges =
        _changes.where((c) => c.type == SyncChangeType.deleted).toList();

    return AlertDialog(
      backgroundColor: SpitoutTokens.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l10n.syncPreviewTitle,
        style: TextStyle(
          color: SpitoutTokens.textPrimary(context),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 汇总行
            _buildSummaryRow(context, addedChanges.length,
                modifiedChanges.length, deletedChanges.length),
            const SizedBox(height: 8),
            // 全选/取消全选
            InkWell(
              onTap: _toggleAll,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: allSelected,
                      onChanged: (_) => _toggleAll(),
                      activeColor: widget.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    allSelected
                        ? l10n.syncPreviewDeselectAll
                        : l10n.syncPreviewSelectAll,
                    style: TextStyle(
                      color: SpitoutTokens.textSecondary(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: SpitoutTokens.divider(context), height: 1),
            const SizedBox(height: 4),
            // 变更列表
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (addedChanges.isNotEmpty) ...[
                      _buildSectionHeader(
                          context, l10n.syncPreviewAdded, Colors.green),
                      ...addedChanges.map((c) => _buildChangeItem(context, c)),
                    ],
                    if (modifiedChanges.isNotEmpty) ...[
                      _buildSectionHeader(
                          context, l10n.syncPreviewModified, Colors.blue),
                      ...modifiedChanges
                          .map((c) => _buildChangeItem(context, c)),
                    ],
                    if (deletedChanges.isNotEmpty) ...[
                      _buildSectionHeader(
                          context, l10n.syncPreviewDeleted, Colors.red),
                      ...deletedChanges
                          .map((c) => _buildChangeItem(context, c)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            l10n.commonCancel,
            style: TextStyle(color: SpitoutTokens.textSecondary(context)),
          ),
        ),
        FilledButton(
          onPressed: selectedCount > 0
              ? () {
                  final selected = _changes
                      .where((c) => _selected[c] ?? true)
                      .toList();
                  Navigator.pop(context, selected);
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: widget.primaryColor,
          ),
          child: Text(l10n.syncPreviewApply(selectedCount)),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
      BuildContext context, int added, int modified, int deleted) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      children: [
        if (added > 0)
          _buildBadge(context, l10n.syncPreviewAddedCount(added), Colors.green),
        if (modified > 0)
          _buildBadge(
              context, l10n.syncPreviewModifiedCount(modified), Colors.blue),
        if (deleted > 0)
          _buildBadge(
              context, l10n.syncPreviewDeletedCount(deleted), Colors.red),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: SpitoutTokens.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeItem(BuildContext context, SyncChange change) {
    final dateFormat = DateFormat('MM-dd');
    String? summary;
    String? detail;
    double? amountValue;
    String? currencyCode;

    switch (change.type) {
      case SyncChangeType.added:
        final tx = change.cloudTransaction;
        if (tx != null) {
          summary =
              '${dateFormat.format(tx.happenedAt)} ${tx.categoryName ?? tx.type}';
          if (tx.note != null && tx.note!.isNotEmpty) {
            summary += ' ${tx.note}';
          }
          amountValue = tx.amount.toDouble();
          currencyCode = tx.currencyCode;
        }
        break;
      case SyncChangeType.modified:
        final tx = change.cloudTransaction;
        if (tx != null) {
          summary =
              '${dateFormat.format(tx.happenedAt)} ${tx.categoryName ?? tx.type}';
          if (tx.note != null && tx.note!.isNotEmpty) {
            summary += ' ${tx.note}';
          }
          amountValue = tx.amount.toDouble();
          currencyCode = tx.currencyCode;
          if (change.diffDetails.isNotEmpty) {
            detail = change.diffDetails.join(', ');
          }
        }
        break;
      case SyncChangeType.deleted:
        final tx = change.localTransaction;
        if (tx != null) {
          summary = '${dateFormat.format(tx.happenedAt)} ${tx.type}';
          if (tx.note != null && tx.note!.isNotEmpty) {
            summary += ' ${tx.note}';
          }
          // 本地金额单位为分,展示时统一换算为元。
          amountValue = tx.amount / 100.0;
          currencyCode = tx.currencyCode;
        }
        break;
    }

    // 数据异常(两侧交易均缺失)时兜底展示类型名,不让解包崩溃。
    final title = summary ?? change.type.name;

    return InkWell(
      onTap: () {
        setState(() {
          _selected[change] = !(_selected[change] ?? true);
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _selected[change] ?? true,
                onChanged: (v) {
                  setState(() {
                    _selected[change] = v ?? false;
                  });
                },
                activeColor: widget.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: SpitoutTokens.textPrimary(context),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      style: TextStyle(
                        color: SpitoutTokens.textTertiary(context),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (amountValue != null) ...[
              const SizedBox(width: 8),
              // 金额按交易自身币种展示:非本位币交易显示原币种符号,
              // 未携带币种时回退到当前账本本位币(AmountText 内置兜底)。
              AmountText(
                value: -amountValue,
                signed: true,
                showCurrency: true,
                currencyCode: currencyCode,
                decimals: 2,
                style: TextStyle(
                  color: SpitoutTokens.textPrimary(context),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
