import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// 数据清理页面 — 展示扫到的孤儿数据,用户勾选后批量或单条删。
class OrphanCleanupPage extends ConsumerStatefulWidget {
  const OrphanCleanupPage({super.key});

  @override
  ConsumerState<OrphanCleanupPage> createState() => _OrphanCleanupPageState();
}

class _OrphanCleanupPageState extends ConsumerState<OrphanCleanupPage> {
  /// 已勾选 record 的 uniqueKey 集合。每次重扫不清空(新结果里没有的会自然
  /// 被过滤,新增的默认 unchecked)。
  final Set<String> _selected = <String>{};
  bool _cleaning = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reportAsync = ref.watch(orphanScanReportProvider);
    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.maintenanceOrphanCleanupTitle,
            subtitle: l10n.maintenanceOrphanCleanupSubtitle,
            showBack: true,
            actions: [
              // 仅 debug build 显示:塞各类孤儿数据用于联调
              if (kDebugMode)
                HeaderIconAction(
                  icon: AppIcons.bugReport,
                  tooltip: 'Seed orphan data (debug)',
                  onPressed: _cleaning ? null : _seedDebugOrphans,
                ),
              HeaderIconAction(
                icon: AppIcons.refresh,
                tooltip: l10n.maintenanceOrphanRescan,
                onPressed: _cleaning
                    ? null
                    : () => ref.invalidate(orphanScanReportProvider),
              ),
            ],
          ),
          Expanded(
            child: reportAsync.when(
              skipLoadingOnReload: true,
              data: (report) => _buildBody(context, ref, l10n, report),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, st) {
                logger.error('OrphanCleanup', '扫描孤儿数据失败', err, st);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(SpitoutDimens.p20),
                    child: Text(
                      l10n.commonOperationFailed,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          if (reportAsync.hasValue)
            _buildBottomBar(context, l10n, reportAsync.requireValue),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, OrphanScanReport report) {
    if (report.totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpitoutDimens.p32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.checkCircle,
                  size: 64.0,
                  color: SpitoutTokens.textTertiary(context)),
              SizedBox(height: SpitoutDimens.p16),
              Text(l10n.maintenanceOrphanEmpty,
                  style: TextStyle(
                      color: SpitoutTokens.textSecondary(context))),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: SpitoutDimens.p12,
        vertical: SpitoutDimens.p8,
      ),
      children: [
        _buildSummary(context, l10n, report),
        SizedBox(height: SpitoutDimens.p8),
        if (report.dbOrphans.isNotEmpty)
          _buildGroup(context, l10n, l10n.maintenanceOrphanGroupDb,
              report.dbOrphans),
        if (report.syncOrphans.isNotEmpty)
          _buildGroup(context, l10n, l10n.maintenanceOrphanGroupSync,
              report.syncOrphans),
      ],
    );
  }

  Widget _buildSummary(
      BuildContext context, AppLocalizations l10n, OrphanScanReport report) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SpitoutDimens.p16,
          vertical: SpitoutDimens.p12,
        ),
        child: Row(
          children: [
            Icon(AppIcons.warning,
                color: SpitoutTokens.warning(context),
                size: SpitoutDimens.icon22),
            SizedBox(width: SpitoutDimens.p12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.maintenanceOrphanSummary(report.totalCount),
                    style: SpitoutTextTokens.body(context).copyWith(fontWeight: FontWeight.w600, color: SpitoutTokens.textPrimary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, AppLocalizations l10n,
      String groupTitle, List<OrphanRecord> records) {
    // 分离 txMissingLedger 与其他记录,便于按已删账本分亚组展示
    final nonTxMissing =
        records.where((r) => r.type != OrphanType.txMissingLedger).toList();
    final txMissing =
        records.where((r) => r.type == OrphanType.txMissingLedger).toList();

    final allSelected = records.every((r) => _selected.contains(r.uniqueKey));
    return Padding(
      padding: const EdgeInsets.only(bottom: SpitoutDimens.p12),
      child: SectionCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 组头:标题 + 数量 + 全选按钮
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpitoutDimens.p16,
                vertical: SpitoutDimens.p8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$groupTitle (${records.length})',
                      style: SpitoutTextTokens.label(context).copyWith(fontWeight: FontWeight.w600, color: SpitoutTokens.textPrimary(context)),
                    ),
                  ),
                  TextButton(
                    onPressed: _cleaning
                        ? null
                        : () => _toggleGroupSelected(records, !allSelected),
                    child: Text(allSelected
                        ? l10n.maintenanceOrphanDeselectAll
                        : l10n.maintenanceOrphanSelectAll),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 非 txMissingLedger 记录（正常单条展示）
            ...nonTxMissing.map((r) => _buildRecordTile(context, l10n, r)),
            // txMissingLedger 按已删账本 ID 亚组展示
            if (txMissing.isNotEmpty && nonTxMissing.isNotEmpty)
              const Divider(height: 1),
            if (txMissing.isNotEmpty)
              ..._buildTxMissingLedgerSubGroups(context, l10n, txMissing),
          ],
        ),
      ),
    );
  }

  /// 将 txMissingLedger 记录按已删账本 ID 分组,每组有独立的全选头。
  /// 这样用户可以按"已删账本"维度批量选中,一次性迁移到新账本。
  List<Widget> _buildTxMissingLedgerSubGroups(
      BuildContext context, AppLocalizations l10n, List<OrphanRecord> records) {
    final primary = Theme.of(context).colorScheme.primary;

    // 按已删账本 ID 分组
    final grouped = <int, List<OrphanRecord>>{};
    for (final r in records) {
      final lid = r.extra?['ledgerId'] as int? ?? 0;
      grouped.putIfAbsent(lid, () => []).add(r);
    }

    final widgets = <Widget>[];
    final sortedKeys = grouped.keys.toList()..sort();
    for (final ledgerId in sortedKeys) {
      final groupRecords = grouped[ledgerId]!;
      final allSelected =
          groupRecords.every((r) => _selected.contains(r.uniqueKey));

      // 亚组头：已删账本 #X (N笔) + 全选
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16, vertical: SpitoutDimens.p4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.maintenanceOrphanDeletedLedgerGroup(
                      ledgerId, groupRecords.length),
                  style: SpitoutTextTokens.label(context).copyWith(fontWeight: FontWeight.w600, color: SpitoutTokens.textSecondary(context)),
                ),
              ),
              GestureDetector(
                onTap: _cleaning
                    ? null
                    : () =>
                        _toggleGroupSelected(groupRecords, !allSelected),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        allSelected
                            ? AppIcons.checkSquare
                            : AppIcons.square,
                        size: SpitoutDimens.icon16,
                        color: allSelected
                            ? primary
                            : SpitoutTokens.textTertiary(context)),
                    const SizedBox(width: SpitoutDimens.p4),
                    Text(l10n.maintenanceOrphanSelectAll,
                        style: SpitoutTextTokens.caption(context).copyWith(color: SpitoutTokens.textSecondary(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      widgets.add(const Divider(height: 1, indent: 16));
      for (final r in groupRecords) {
        widgets.add(_buildRecordTile(context, l10n, r));
      }
    }
    return widgets;
  }

  Widget _buildRecordTile(
      BuildContext context, AppLocalizations l10n, OrphanRecord r) {
    final checked = _selected.contains(r.uniqueKey);
    final isTxMissingLedger = r.type == OrphanType.txMissingLedger;

    // txMissingLedger: 自定义行布局,增加"移至其他账本"操作按钮
    if (isTxMissingLedger) {
      return InkWell(
        onTap: _cleaning
            ? null
            : () {
                setState(() {
                  if (checked) {
                    _selected.remove(r.uniqueKey);
                  } else {
                    _selected.add(r.uniqueKey);
                  }
                });
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p12, vertical: SpitoutDimens.p4),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: _cleaning
                    ? null
                    : (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(r.uniqueKey);
                          } else {
                            _selected.remove(r.uniqueKey);
                          }
                        });
                      },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title,
                        style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textPrimary(context))),
                    Text(r.subtitle,
                        style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context))),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.maintenanceOrphanMoveSingle,
                    icon: const Icon(AppIcons.driveFileMove, size: SpitoutDimens.icon20),
                    onPressed:
                        _cleaning ? null : () => _moveOneToLedger(r),
                  ),
                  IconButton(
                    tooltip: l10n.maintenanceOrphanDeleteOne,
                    icon: const Icon(AppIcons.delete, size: SpitoutDimens.icon20),
                    onPressed: _cleaning ? null : () => _cleanOne(r),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 其他类型:沿用 CheckboxListTile
    return CheckboxListTile(
      value: checked,
      onChanged: _cleaning
          ? null
          : (v) {
              setState(() {
                if (v == true) {
                  _selected.add(r.uniqueKey);
                } else {
                  _selected.remove(r.uniqueKey);
                }
              });
            },
      title: Text(r.title,
          style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textPrimary(context))),
      subtitle: Text(r.subtitle,
          style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context))),
      secondary: IconButton(
        tooltip: l10n.maintenanceOrphanDeleteOne,
        icon: const Icon(AppIcons.delete),
        onPressed: _cleaning ? null : () => _cleanOne(r),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  Widget _buildBottomBar(
      BuildContext context, AppLocalizations l10n, OrphanScanReport report) {
    if (report.totalCount == 0) return const SizedBox.shrink();
    final selectedRecords = report.all
        .where((r) => _selected.contains(r.uniqueKey))
        .toList();
    final selectedCount = selectedRecords.length;
    // 当选中的记录中包含 txMissingLedger 类型时,显示"移动到账本"按钮
    final hasTxMissingLedgerSelected =
        selectedRecords.any((r) => r.type == OrphanType.txMissingLedger);
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpitoutDimens.p16,
          vertical: SpitoutDimens.p8,
        ),
        decoration: BoxDecoration(
          color: SpitoutTokens.surface(context),
          border: Border(
              top: BorderSide(color: SpitoutTokens.divider(context))),
        ),
        child: Row(
          children: [
            Text(
              l10n.maintenanceOrphanSelectedHint(selectedCount),
              style: TextStyle(color: SpitoutTokens.textSecondary(context)),
            ),
            const Spacer(),
            // 移动到账本按钮:仅当选中有 txMissingLedger 记录时显示
            if (hasTxMissingLedgerSelected)
              TextButton.icon(
                onPressed:
                    _cleaning ? null : () => _moveSelectedToLedger(report),
                icon: const Icon(AppIcons.driveFileMove, size: SpitoutDimens.icon16),
                label: Text(l10n.maintenanceOrphanMoveToLedger),
              ),
            TextButton(
              onPressed: _cleaning
                  ? null
                  : () => _toggleAll(report, selectedCount == 0),
              child: Text(selectedCount == 0
                  ? l10n.maintenanceOrphanSelectAll
                  : l10n.maintenanceOrphanDeselectAll),
            ),
            const SizedBox(width: SpitoutDimens.p8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              onPressed: (_cleaning || selectedCount == 0)
                  ? null
                  : () => _cleanSelected(report),
              icon: _cleaning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(AppIcons.clearAll,
                      color: Colors.white),
              label: Text(l10n.maintenanceOrphanCleanSelected,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleGroupSelected(List<OrphanRecord> records, bool select) {
    setState(() {
      for (final r in records) {
        if (select) {
          _selected.add(r.uniqueKey);
        } else {
          _selected.remove(r.uniqueKey);
        }
      }
    });
  }

  void _toggleAll(OrphanScanReport report, bool select) {
    setState(() {
      if (select) {
        for (final r in report.all) {
          _selected.add(r.uniqueKey);
        }
      } else {
        _selected.clear();
      }
    });
  }

  /// 单条迁移:打开账本选择器 → 将一条无账本交易移至目标账本 → 重扫
  Future<void> _moveOneToLedger(OrphanRecord r) async {
    final l10n = AppLocalizations.of(context);
    final txId = r.localId;
    if (txId == null) return;

    // 打开账本选择器,让用户选择迁移目标
    final targetId = await showLedgerSelector(context);
    if (targetId == null) return; // 用户取消

    final cleaner = ref.read(orphanCleanerProvider);
    try {
      await cleaner.moveTxToLedger(txId, targetId);
      if (!mounted) return;
      showToast(context, l10n.maintenanceOrphanMoveToLedgerSuccess(1));
      // 从选中列表中移除,刷新扫描结果
      setState(() => _selected.remove(r.uniqueKey));
      ref.invalidate(orphanScanReportProvider);
    } catch (e, st) {
      logger.error('OrphanCleanup', '单条迁移失败', e, st);
      if (!mounted) return;
      showToast(context, l10n.commonOperationFailed);
    }
  }

  /// 批量迁移:将选中的无账本交易全部移至目标账本
  Future<void> _moveSelectedToLedger(OrphanScanReport report) async {
    final l10n = AppLocalizations.of(context);
    // 仅筛选 txMissingLedger 类型,其他类型的数据不受影响
    final txMissing = report.all
        .where((r) =>
            _selected.contains(r.uniqueKey) &&
            r.type == OrphanType.txMissingLedger &&
            r.localId != null)
        .toList();
    if (txMissing.isEmpty) return;

    final targetId = await showLedgerSelector(context);
    if (targetId == null) return;

    final txIds = txMissing.map((r) => r.localId!).toList();
    final cleaner = ref.read(orphanCleanerProvider);
    setState(() => _cleaning = true);
    try {
      final count = await cleaner.batchMoveTxToLedger(txIds, targetId);
      if (!mounted) return;
      showToast(context, l10n.maintenanceOrphanMoveToLedgerSuccess(count));
      // 移除已迁移记录的勾选
      for (final r in txMissing) {
        _selected.remove(r.uniqueKey);
      }
      ref.invalidate(orphanScanReportProvider);
    } catch (e, st) {
      logger.error('OrphanCleanup', '批量迁移失败', e, st);
      if (!mounted) return;
      showToast(context, l10n.commonOperationFailed);
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  /// 清理单条孤儿记录(带二次确认)。
  Future<void> _cleanOne(OrphanRecord r) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirm(
      title: l10n.maintenanceOrphanConfirmTitle,
      message: l10n.maintenanceOrphanConfirmDeleteOne(r.title),
    );
    if (!confirmed) return;
    await _runClean([r], l10n);
  }

  /// 清理所有已勾选记录(带二次确认)。
  Future<void> _cleanSelected(OrphanScanReport report) async {
    final l10n = AppLocalizations.of(context);
    final selected = report.all
        .where((r) => _selected.contains(r.uniqueKey))
        .toList();
    if (selected.isEmpty) return;
    final confirmed = await _showConfirm(
      title: l10n.maintenanceOrphanConfirmTitle,
      message: l10n.maintenanceOrphanConfirmDeleteBatch(selected.length),
    );
    if (!confirmed) return;
    await _runClean(selected, l10n);
  }

  /// 执行清理:调用 cleaner 后按成功/失败刷新勾选与扫描结果。
  ///
  /// 异常(如 DB 损坏)不冒泡:提示用户后停留本页,便于重试。
  Future<void> _runClean(
      List<OrphanRecord> records, AppLocalizations l10n) async {
    setState(() => _cleaning = true);
    try {
      final cleaner = ref.read(orphanCleanerProvider);
      final result = await cleaner.clean(records);
      // 清掉已成功 record 的勾选(失败的保留勾选,便于用户重试 / 复查)
      final failedKeys = result.failures.map((f) => f.record.uniqueKey).toSet();
      for (final r in records) {
        if (!failedKeys.contains(r.uniqueKey)) _selected.remove(r.uniqueKey);
      }
      if (!mounted) return;
      if (result.hasFailure) {
        showToast(
            context,
            l10n.maintenanceOrphanCleanPartial(
                result.successCount, result.failures.length));
      } else {
        showToast(
            context, l10n.maintenanceOrphanCleanSuccess(result.successCount));
      }
      ref.invalidate(orphanScanReportProvider);
    } catch (e, st) {
      logger.error('OrphanCleanup', '清理孤儿数据失败', e, st);
      if (mounted) {
        showToast(context, l10n.commonOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  Future<bool> _showConfirm(
      {required String title, required String message}) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// debug 按钮:塞 ≥10 项孤儿到本地 DB / 磁盘,然后重扫。
  Future<void> _seedDebugOrphans() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _cleaning = true);
    try {
      final report = await seedDebugOrphans(ref);
      if (!mounted) return;
      showToast(context, '已塞入测试孤儿数据\n$report');
      ref.invalidate(orphanScanReportProvider);
    } catch (e, st) {
      logger.error('OrphanCleanup', '塞入测试孤儿数据失败', e, st);
      if (mounted) {
        showToast(context, l10n.commonOperationFailed);
      }
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

}
