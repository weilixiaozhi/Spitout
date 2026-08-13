import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/utils/category_utils.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/shadows.dart';
import 'recurring_transaction_edit_page.dart';
import 'package:spitout/theme/icons/app_icons.dart';

class RecurringTransactionPage extends ConsumerWidget {
  const RecurringTransactionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringTransactionsAsync = ref.watch(allRecurringTransactionsProvider);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).recurringTransactionTitle,
            showBack: true,
            actions: [
              // 统一使用圆圈加号图标（与分类管理新增入口一致）；
              // 右缘留白由 PrimaryHeader 默认 padding 提供，不叠加额外 padding
              HeaderIconAction(
                icon: AppIcons.addCircle,
                tooltip: AppLocalizations.of(context).recurringTransactionAdd,
                onPressed: () => _addRecurringTransaction(context, ref),
              ),
            ],
          ),
          Expanded(
            child: recurringTransactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                // 原始异常只进日志,页面展示统一友好文案 + 重试。
                logger.error(
                  'RecurringTransactionPage',
                  '周期账单列表加载失败',
                  error,
                  stack,
                );
                final l10n = AppLocalizations.of(context);
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.commonOperationFailed,
                        style: TextStyle(
                          color: SpitoutTokens.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(allRecurringTransactionsProvider),
                        icon: const Icon(AppIcons.refresh, size: 18),
                        label: Text(l10n.analyticsRetry),
                      ),
                    ],
                  ),
                );
              },
              data: (recurringTransactions) {
                if (recurringTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.repeat,
                          size: 64,
                          color: SpitoutTokens.textTertiary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).recurringTransactionEmpty,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: SpitoutTokens.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).recurringTransactionEmptyHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SpitoutTokens.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: recurringTransactions.length + 1, // +1 for usage guide card
                  itemBuilder: (context, index) {
                    // 第一个显示使用说明卡片
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UsageGuideCard(),
                      );
                    }
                    // 后续显示周期记账卡片
                    final recurring = recurringTransactions[index - 1];
                    return _RecurringTransactionCard(recurring: recurring);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addRecurringTransaction(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      appPageRoute<bool>(
        builder: (_) => const RecurringTransactionEditPage(),
      ),
    );
    // 如果返回 true，表示数据已更改，强制刷新列表
    if (result == true) {
      ref.invalidate(allRecurringTransactionsProvider);
    }
  }
}

class _RecurringTransactionCard extends ConsumerStatefulWidget {
  final RecurringTransaction recurring;

  const _RecurringTransactionCard({required this.recurring});

  @override
  ConsumerState<_RecurringTransactionCard> createState() =>
      _RecurringTransactionCardState();
}

class _RecurringTransactionCardState
    extends ConsumerState<_RecurringTransactionCard> {
  /// 开关切换进行中标记:防止连点与切换期间重复提交。
  bool _toggling = false;

  RecurringTransaction get recurring => widget.recurring;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SpitoutTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: SpitoutTokens.isDark(context)
            ? Border.all(
                color: recurring.enabled
                    ? primaryColor.withValues(alpha: 0.3)
                    : SpitoutTokens.border(context),
                width: 1,
              )
            : null,
        boxShadow: SpitoutTokens.isDark(context)
            ? null
            : SpitoutShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.of(context).push<bool>(
              appPageRoute<bool>(
                builder: (_) => RecurringTransactionEditPage(recurring: recurring),
              ),
            );
            // 如果返回 true，表示数据已更改，强制刷新列表
            if (result == true) {
              ref.invalidate(allRecurringTransactionsProvider);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 左侧：类型指示条（全局仅支出模式）
                Container(
                  width: 3,
                  height: 48,
                  decoration: BoxDecoration(
                    color: SpitoutTokens.error(context),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 12),
                // 中间：信息区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 第一行：分类名称
                      Builder(
                        builder: (context) {
                          // 分类名走 FutureProvider.family 缓存,避免每次
                          // build 都为卡片重新发起数据库查询。
                          final categoryId = recurring.categoryId;
                          final categoryName = categoryId == null
                              ? null
                              : ref
                                  .watch(categoryByIdProvider(categoryId))
                                  .value
                                  ?.name;
                          return Text(
                            CategoryUtils.getDisplayName(categoryName, context),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: SpitoutTokens.textPrimary(context),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      // 第二行：账本 + 频率 + 时间
                      Row(
                        children: [
                          // 账本
                          Builder(
                            builder: (context) {
                              final ledgerName = ref
                                  .watch(ledgerByIdProvider(recurring.ledgerId))
                                  .value
                                  ?.name ??
                                  '';
                              return Text(
                                ledgerName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SpitoutTokens.textTertiary(context),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '·',
                              style: TextStyle(
                                fontSize: 12,
                                color: SpitoutTokens.textTertiary(context),
                              ),
                            ),
                          ),
                          // 频率
                          Text(
                            _getFrequencyDescription(context),
                            style: TextStyle(
                              fontSize: 12,
                              color: SpitoutTokens.textTertiary(context),
                            ),
                          ),
                          // 下次生成时间（如果有）
                          if (recurring.lastGeneratedDate != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SpitoutTokens.textTertiary(context),
                                ),
                              ),
                            ),
                            Icon(
                              AppIcons.clock,
                              size: 11,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              DateFormat.Md().format(recurring.lastGeneratedDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // 备注（如果有）
                      if (recurring.note != null && recurring.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          recurring.note!,
                          style: TextStyle(
                            fontSize: 11,
                            color: SpitoutTokens.textSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 右侧：金额 + 开关
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 金额
                    AmountText(
                      value: recurring.type == 'expense'
                          ? -recurring.amount / 100
                          : recurring.amount / 100,
                      signed: true,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: recurring.type == 'expense'
                            ? SpitoutTokens.error(context)
                            : SpitoutTokens.success(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 开关
                    Transform.scale(
                      scale: 0.65,
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: recurring.enabled,
                        onChanged: _toggling
                            ? null
                            : (value) async {
                                await _toggle(value);
                              },
                        activeThumbColor: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 频率展示文案:间隔为 1 时用「每天/每周/…」,否则用「每 N 天/…」。
  String _getFrequencyDescription(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final frequency = RecurringFrequency.fromString(recurring.frequency);
    final interval = recurring.interval;

    if (interval == 1) {
      switch (frequency) {
        case RecurringFrequency.daily:
          return l10n.recurringTransactionDaily;
        case RecurringFrequency.weekly:
          return l10n.recurringTransactionWeekly;
        case RecurringFrequency.monthly:
          return l10n.recurringTransactionMonthly;
        case RecurringFrequency.yearly:
          return l10n.recurringTransactionYearly;
      }
    } else {
      switch (frequency) {
        case RecurringFrequency.daily:
          return l10n.recurringTransactionEveryNDays(interval);
        case RecurringFrequency.weekly:
          return l10n.recurringTransactionEveryNWeeks(interval);
        case RecurringFrequency.monthly:
          return l10n.recurringTransactionEveryNMonths(interval);
        case RecurringFrequency.yearly:
          return l10n.recurringTransactionEveryNYears(interval);
      }
    }
  }

  /// 切换周期账单开关。
  ///
  /// 写库成功后失效列表流并等待其刷新,替代原先的固定 100ms 延迟;
  /// 失败时保持原开关状态并 toast 提示,不静默。
  Future<void> _toggle(bool value) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final l10n = AppLocalizations.of(context);
    try {
      final repo = ref.read(repositoryProvider);
      await repo.toggleRecurringTransaction(recurring.id, value);
      logger.debug(
        'Recurring',
        '周期账单开关已切换 id=${recurring.id} enabled=$value',
      );
      // 失效后等待数据流首帧,确保列表刷新完成,再收尾。
      ref.invalidate(allRecurringTransactionsProvider);
      await ref.read(allRecurringTransactionsProvider.future);
    } catch (e, st) {
      logger.warning(
        'Recurring',
        '周期账单开关切换失败 id=${recurring.id} enabled=$value',
        '$e\n$st',
      );
      if (mounted) {
        showToast(context, l10n.commonOperationFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }
}

/// 使用说明卡片
class _UsageGuideCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.info,
            size: 20,
            color: primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.recurringTransactionUsageTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SpitoutTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.recurringTransactionUsageContent,
                  style: TextStyle(
                    fontSize: 13,
                    color: SpitoutTokens.textSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
