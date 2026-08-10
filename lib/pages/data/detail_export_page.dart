import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/widgets/widgets.dart';

/// 将「起始日 ~ 结束日」展开为导出时间范围（闭区间）。
///
/// 设计意图：滚轮日期选择器返回的粒度是「日」，而交易时间精确到秒，
/// 因此起始日取 00:00:00、结束日取 23:59:59，保证起止当日的交易
/// 完整落入导出范围。提取为顶层纯函数以便单元测试直接覆盖边界。
DateTimeRange buildDetailExportRange(DateTime startDay, DateTime endDay) {
  final start = DateTime(startDay.year, startDay.month, startDay.day);
  final end = DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59);
  return DateTimeRange(start: start, end: end);
}

/// 导出明细页（二级页面，由「明细导入导出」页进入）
///
/// 页面能力：
/// - 导出账本：下拉选择框，默认选中进入前的当前账本；
/// - 全选数据：默认勾选，作用范围为所选账本下的全部数据；
/// - 日期联动：勾选全选时日期范围组件置灰不可用，取消勾选后恢复；
/// - 日期范围：起止日期按「年-月-日」粒度选择（滚轮选择器）。
class DetailExportPage extends ConsumerStatefulWidget {
  /// 可注入的初始日期（默认：起始=今年1月1日，结束=今天）。
  /// 主要用于测试构造非法区间等场景，正常入口不传。
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const DetailExportPage({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  ConsumerState<DetailExportPage> createState() => _DetailExportPageState();
}

class _DetailExportPageState extends ConsumerState<DetailExportPage> {
  /// 导出账本：默认当前页面所在的数据账本
  late int _ledgerId;

  /// 全选数据：默认勾选；勾选时导出所选账本全部数据（dateRange = null）
  bool _selectAll = true;

  late DateTime _startDate;
  late DateTime _endDate;

  /// 导出中标记：防重复提交，同时禁用表单交互
  bool _exporting = false;

  /// 账本列表请求缓存在 state 中，避免 setState 触发重复查询
  late final Future<List<Ledger>> _ledgersFuture;
  /// 账本列表加载完成且为空:用于空态渲染与禁用导出,避免 Dropdown 断言。
  bool _ledgersEmpty = false;

  @override
  void initState() {
    super.initState();
    _ledgerId = ref.read(currentLedgerIdProvider);
    _ledgersFuture = ref.read(repositoryProvider).getAllLedgers();
    _ledgersFuture.then((ledgers) {
      if (!mounted) return;
      setState(() {
        _ledgersEmpty = ledgers.isEmpty;
        // 当前账本不在列表中(如已被删除)时回退到首个账本。
        if (ledgers.isNotEmpty && !ledgers.any((l) => l.id == _ledgerId)) {
          _ledgerId = ledgers.first.id;
        }
      });
    }).catchError((Object e, StackTrace st) {
      logger.error('DetailExportPage', '加载账本列表失败', e, st);
      if (mounted) {
        setState(() => _ledgersEmpty = true);
      }
    });
    final now = DateTime.now();
    _startDate =
        widget.initialStartDate ?? DateTime(now.year, 1, 1);
    _endDate =
        widget.initialEndDate ?? DateTime(now.year, now.month, now.day);
  }

  /// 区间是否非法：仅在非全选时参与校验（全选时日期组件不参与导出）
  bool get _rangeInvalid => !_selectAll && _startDate.isAfter(_endDate);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.detailImportExportExportTitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              children: [
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 导出账本：下拉选择框
                      _buildLedgerRow(context, l10n),
                      SpitoutTokens.cardDivider(context),
                      // 全选数据：勾选时导出所选账本全部数据
                      _buildSelectAllRow(context, l10n),
                      SpitoutTokens.cardDivider(context),
                      // 起止日期：全选勾选时置灰禁用
                      _buildDateRow(
                        context,
                        label: l10n.detailExportStartDate,
                        value: _startDate,
                        isStart: true,
                      ),
                      SpitoutTokens.cardDivider(context),
                      _buildDateRow(
                        context,
                        label: l10n.detailExportEndDate,
                        value: _endDate,
                        isStart: false,
                      ),
                      // 区间非法提示：开始日期晚于结束日期
                      if (_rangeInvalid) _buildInvalidHint(context, l10n),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // 底部导出按钮：非法区间或导出中时禁用
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
          child: FilledButton(
            onPressed: _exporting || _rangeInvalid || _ledgersEmpty
                ? null
                : _export,
            child: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.detailExportAction),
          ),
        ),
      ),
    );
  }

  /// 导出账本行：左侧标签 + 右侧下拉选择框。
  ///
  /// 数据源为本地全部账本（`repo.getAllLedgers()`），仅取 id/name，
  /// 不复用带统计信息的账本列表 provider，避免无谓的统计查询。
  Widget _buildLedgerRow(BuildContext context, AppLocalizations l10n) {
    return FutureBuilder<List<Ledger>>(
      future: _ledgersFuture,
      builder: (context, snapshot) {
        final ledgers = snapshot.data ?? const <Ledger>[];
        // 空账本:不渲染 DropdownButton(其 value 不在 items 会断言崩溃),
        // 改为空态提示,导出按钮同步禁用。
        if (snapshot.connectionState == ConnectionState.done &&
            ledgers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Text(
                  l10n.detailExportLedgerLabel,
                  style: TextStyle(
                    fontSize: 15,
                    color: SpitoutTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.ledgersEmpty,
                  style: TextStyle(
                    fontSize: 14,
                    color: SpitoutTokens.textTertiary(context),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            children: [
              Text(
                l10n.detailExportLedgerLabel,
                style: TextStyle(
                  fontSize: 15,
                  color: SpitoutTokens.textPrimary(context),
                ),
              ),
              const Spacer(),
              if (snapshot.connectionState != ConnectionState.done)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                DropdownButton<int>(
                  value: _ledgerId,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final ledger in ledgers)
                      DropdownMenuItem(
                        value: ledger.id,
                        child: Text(ledger.name),
                      ),
                  ],
                  onChanged: _exporting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _ledgerId = value);
                          }
                        },
                ),
            ],
          ),
        );
      },
    );
  }

  /// 全选数据行：复选框 + 标题 + 作用范围说明。
  Widget _buildSelectAllRow(BuildContext context, AppLocalizations l10n) {
    return CheckboxListTile(
      value: _selectAll,
      onChanged: _exporting
          ? null
          : (value) => setState(() => _selectAll = value ?? true),
      title: Text(
        l10n.detailExportSelectAllLabel,
        style: TextStyle(
          fontSize: 15,
          color: SpitoutTokens.textPrimary(context),
        ),
      ),
      subtitle: Text(
        l10n.detailExportSelectAllSubtitle,
        style: TextStyle(
          fontSize: 13,
          color: SpitoutTokens.textTertiary(context),
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
    );
  }

  /// 日期选择行：左侧标签 + 右侧「YYYY-MM-DD」+ chevron。
  ///
  /// 置灰口径与 `AppListTile` 一致（Opacity 0.5 + 禁止点击），
  /// 全选勾选时不可用，取消勾选后恢复。
  Widget _buildDateRow(
    BuildContext context, {
    required String label,
    required DateTime value,
    required bool isStart,
  }) {
    final enabled = !_selectAll && !_exporting;
    final ymd =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? () => _pickDate(isStart: isStart) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12.0,
            horizontal: 12.0,
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: SpitoutTokens.textPrimary(context),
                ),
              ),
              const Spacer(),
              Text(
                ymd,
                style: TextStyle(
                  fontSize: 15,
                  color: SpitoutTokens.textSecondary(context),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevronRight,
                size: 20,
                color: SpitoutTokens.iconTertiary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 区间非法提示行。
  Widget _buildInvalidHint(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
      child: Row(
        children: [
          Icon(
            AppIcons.error,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.detailExportDateInvalid,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 拉起年-月-日滚轮选择器，确认后更新起止日期。
  ///
  /// 仅非全选模式下可用;选择器返回 null(取消)时不改动日期。
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showWheelDatePicker(
      context,
      initial: isStart ? _startDate : _endDate,
      mode: WheelDatePickerMode.ymd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  /// 执行导出：全选时传 null 范围（服务层语义=全部数据），
  /// 否则将起止日期展开为闭区间后导出；结果以弹窗反馈。
  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);

    // Android 11+ 写公共 Download 需「所有文件访问」授权：导出前引导一次，
    // 未授权也不阻断，服务层会自动降级到应用专属目录。
    // 非 Android 平台无此授权流程，直接放行（保持原语义）。
    if (Platform.isAndroid && await ensureExportDirAccess(context, ref) == null) {
      return;
    }
    if (!mounted) return;

    setState(() => _exporting = true);
    try {
      final result = await exportDetailCsvFromUi(
        ref,
        ledgerId: _ledgerId,
        dateRange:
            _selectAll ? null : buildDetailExportRange(_startDate, _endDate),
        onProgress: (_) {},
      );
      if (!mounted) return;
      await AppDialog.info(
        context,
        title: l10n.exportSuccessTitle,
        // iOS 走应用文档目录,展示平台对应文案,不沿用 Android 专用提示。
        message: Platform.isAndroid
            ? l10n.exportSuccessMessageAndroid(result.displayPath)
            : l10n.exportSuccessMessageIos(result.displayPath),
      );
    } catch (e, st) {
      logger.error('DetailExportPage', '导出明细失败', e, st);
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: l10n.exportFailedTitle,
        message: l10n.commonOperationFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}
