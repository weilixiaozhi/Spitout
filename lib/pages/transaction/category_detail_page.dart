import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/data/models.dart' as db;
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/theme/colors.dart';
import 'package:intl/intl.dart';
import 'package:spitout/providers/core/post_processor.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/utils/category_utils.dart';
import 'package:spitout/theme/icons/app_icons.dart';

enum SortType { timeAsc, timeDesc, amountAsc, amountDesc }

// ============================================================
// 分类汇总列表的展示项模型（用于 ListView.builder 统一渲染）
// ============================================================

/// 日期分组标题行：展示日期 + 当日支出小计
class _DateHeaderItem {
  final String dateKey;
  final double expense;
  _DateHeaderItem(this.dateKey, this.expense);
}

/// 交易行
class _TransactionDisplayItem {
  final db.Transaction transaction;
  final db.Category category;
  _TransactionDisplayItem(this.transaction, this.category);
}

class CategoryDetailPage extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;
  final DateTime? startDate; // 周期开始时间（可选）
  final DateTime? endDate;   // 周期结束时间（可选）
  final String? periodLabel; // 周期标签（如"2024年11月"）

  const CategoryDetailPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.startDate,
    this.endDate,
    this.periodLabel,
  });

  @override
  ConsumerState<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends ConsumerState<CategoryDetailPage> {
  /// 删除进行中标记:防止详情 sheet 与行内删除入口连点重复执行。
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    // 仅统计当前账本：不做跨账本汇总（账本标签显示异常，
    // 且多币种 nativeAmount 直接求和后挂单一币种符号的语义不严谨）。
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final transactionsAsync = ref.watch(_categoryTransactionsWithSortProvider((categoryId: widget.categoryId, ledgerId: ledgerId)));
    final currentSortType = ref.watch(_categorySortTypeProvider(widget.categoryId));

    // 分类 Map：key=categoryId，value=Category 对象，用于每笔交易按实际分类显示 icon/名称
    final categoryMapAsync = ref.watch(_categorySubsMapProvider(widget.categoryId));

    // 如果有周期限制，需要筛选交易数据
    final filteredTransactionsAsync = transactionsAsync.when(
      loading: () => const AsyncValue<List<db.Transaction>>.loading(),
      error: (error, stack) => AsyncValue<List<db.Transaction>>.error(error, stack),
      data: (transactions) {
        if (widget.startDate != null && widget.endDate != null) {
          final filtered = transactions.where((t) {
            // 区间为 [startDate, endDate):包含起始日,排除结束日的下一天。
            return t.happenedAt.isAtSameMomentAs(widget.startDate!) ||
                   (t.happenedAt.isAfter(widget.startDate!) &&
                    t.happenedAt.isBefore(widget.endDate!));
          }).toList();
          return AsyncValue.data(filtered);
        }
        return AsyncValue.data(transactions);
      },
    );

    // 基于筛选后的数据计算汇总
    final summaryAsync = filteredTransactionsAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
      data: (transactions) {
        final totalCount = transactions.length;
        // 整数分累加,避免 double 尾差;展示前再转"元"。
        final totalAmountCents = transactions.fold<int>(
            0, (sum, t) => sum + (t.nativeAmount ?? t.amount));
        final totalAmount = totalAmountCents / 100;
        final averageAmount =
            totalCount > 0 ? (totalAmountCents / totalCount) / 100 : 0.0;
        return AsyncValue.data((
          totalCount: totalCount,
          totalAmount: totalAmount,
          averageAmount: averageAmount,
        ));
      },
    );

    // 构建 categoryMap 快照，供列表渲染使用
    final categoryMap = categoryMapAsync.value ?? <int, db.Category>{};

    // 共享账本成员表(userId→成员),详情 sheet 用于协作成员 / AA 支出人展示名
    final ledger = ref.watch(currentLedgerProvider).asData?.value;
    var memberMap = const <String, SpitoutCloudLedgerMember>{};
    final syncId = ledger?.syncId;
    if (ledger != null && ledger.isShared && syncId != null && syncId.isNotEmpty) {
      final members = ref.watch(ledgerMembersProvider(syncId)).asData?.value;
      if (members != null) {
        memberMap = {for (final m in members) m.userId: m};
      }
    }
    // 本地账本无成员表:取本地昵称供详情页兜底展示(纯本地,不依赖云端登录态)
    final localOwnerName =
        (ledger?.isShared ?? false) ? null : ref.read(displayNameProvider);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).categoryDetailSummaryTitle,
            showBack: true,
          ),
          Expanded(
            child: Column(
              children: [
                // 汇总信息卡片
                summaryAsync.when(
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) {
                    // 原始异常只进日志,页面展示统一友好文案。
                    logger.error(
                      'CategoryDetailPage',
                      '分类汇总加载失败 category=${widget.categoryId}',
                      error,
                      stack,
                    );
                    return Container(
                      height: 120,
                      margin: const EdgeInsets.all(SpitoutDimens.p16),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).categoryDetailLoadFailed,
                        ),
                      ),
                    );
                  },
                  data: (summary) => _buildSummaryCard(summary),
                ),
                // 排序控件
                _buildSortControls(currentSortType),
                // 交易记录列表
                Expanded(
                  child: filteredTransactionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) {
                      logger.error(
                        'CategoryDetailPage',
                        '分类交易加载失败 category=${widget.categoryId}',
                        error,
                        stack,
                      );
                      return _buildLoadError(
                        () => ref.invalidate(
                          _categoryTransactionsWithSortProvider((
                            categoryId: widget.categoryId,
                            ledgerId: ledgerId,
                          )),
                        ),
                      );
                    },
                    data: (transactions) {
                      // 分类映射未就绪:交易先到也不能静默跳过分类组,
                      // 先展示加载态,避免整组交易消失。
                      if (categoryMapAsync.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      // 分类映射加载失败:展示错误 + 重试,不静默当「无交易」。
                      if (categoryMapAsync.hasError) {
                        return _buildLoadError(
                          () => ref.invalidate(
                            _categorySubsMapProvider(widget.categoryId),
                          ),
                        );
                      }
                      return _buildTransactionsList(
                        transactions,
                        currentSortType,
                        categoryMap,
                        memberMap,
                        localOwnerName,
                        ledger?.aaEnabled ?? false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard(({int totalCount, double totalAmount, double averageAmount}) summary) {
    return Container(
      margin: const EdgeInsets.all(SpitoutDimens.p16),
      child: SectionCard(
        child: Padding(
          padding: const EdgeInsets.all(SpitoutDimens.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.barChart,
                    color: Theme.of(context).colorScheme.primary,
                    size: SpitoutDimens.icon20,
                  ),
                  const SizedBox(width: SpitoutDimens.p8),
                  Expanded(
                    child: Text(
                      widget.periodLabel != null
                          ? '${CategoryUtils.getDisplayName(widget.categoryName, context)} · ${widget.periodLabel}'
                          : CategoryUtils.getDisplayName(widget.categoryName, context),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpitoutDimens.p16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: AppLocalizations.of(context).categoryDetailTotalCount,
                      value: AppLocalizations.of(context).categoryMigrationTransactionLabel(summary.totalCount),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: AppLocalizations.of(context).categoryDetailTotalAmount,
                      value: summary.totalAmount,
                      isAmount: true,
                      color: ref.watch(expenseColorSchemeProvider) == 'green' ? SpitoutTokens.success(context) : SpitoutTokens.error(context),
                    ),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: AppLocalizations.of(context).categoryDetailAverageAmount,
                      value: summary.averageAmount,
                      isAmount: true,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortControls(SortType currentSortType) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16, vertical: SpitoutDimens.p8),
      child: Row(
        children: [
          Icon(
            AppIcons.sort,
            size: SpitoutDimens.icon16,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: SpitoutDimens.p8),
          Text(
            AppLocalizations.of(context).categoryDetailSortTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(width: SpitoutDimens.p12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SortButton(
                    label: AppLocalizations.of(context).categoryDetailSortTimeDesc,
                    isSelected: currentSortType == SortType.timeDesc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).set(SortType.timeDesc),
                  ),
                  const SizedBox(width: SpitoutDimens.p8),
                  _SortButton(
                    label: AppLocalizations.of(context).categoryDetailSortTimeAsc,
                    isSelected: currentSortType == SortType.timeAsc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).set(SortType.timeAsc),
                  ),
                  const SizedBox(width: SpitoutDimens.p8),
                  _SortButton(
                    label: AppLocalizations.of(context).categoryDetailSortAmountDesc,
                    isSelected: currentSortType == SortType.amountDesc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).set(SortType.amountDesc),
                  ),
                  const SizedBox(width: SpitoutDimens.p8),
                  _SortButton(
                    label: AppLocalizations.of(context).categoryDetailSortAmountAsc,
                    isSelected: currentSortType == SortType.amountAsc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).set(SortType.amountAsc),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 核心改动：按分类分组 → 分类内按日期分组 → 每笔交易用实际分类 icon/名称
  // ============================================================

  /// 删除交易:写库 → 后台同步 → 刷新账本笔数与全局统计。
  /// 详情 sheet 与行内删除入口共用同一逻辑。
  Future<void> _deleteTransaction(db.Transaction transaction) async {
    if (_deleting) return;
    _deleting = true;
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    final l10n = AppLocalizations.of(context);

    try {
      await repo.deleteTransaction(transaction.id);

      // 刷新：账本笔数与全局统计
      ref.invalidate(countsForLedgerProvider(ledgerId));

      // 同步失败单独记录:删除已成功,不应误报为「删除失败」,
      // 数据会由后续自动同步机制补推。
      try {
        await PostProcessor.sync(ref, ledgerId: ledgerId);
      } catch (e, st) {
        logger.warning(
          'CategoryDetailPage',
          '删除成功但同步失败 tx=${transaction.id}',
          '$e\n$st',
        );
      }
    } catch (e, st) {
      logger.error(
        'CategoryDetailPage',
        '删除交易失败 tx=${transaction.id}',
        e,
        st,
      );
      if (mounted) {
        showToast(context, l10n.categoryDetailDeleteFailed);
      }
    } finally {
      _deleting = false;
    }
  }

  /// 列表加载失败占位:友好文案 + 重试按钮。
  Widget _buildLoadError(VoidCallback onRetry) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.categoryDetailLoadFailed,
            style: TextStyle(color: SpitoutTokens.textSecondary(context)),
          ),
          const SizedBox(height: SpitoutDimens.p8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh, size: SpitoutDimens.icon16),
            label: Text(l10n.analyticsRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    List<db.Transaction> transactions,
    SortType currentSortType,
    Map<int, db.Category> categoryMap,
    Map<String, SpitoutCloudLedgerMember> memberMap,
    String? localOwnerName,
    bool aaEnabled,
  ) {
    if (transactions.isEmpty) {
      return AppEmpty(
        text: AppLocalizations.of(context).categoryDetailNoTransactions,
        subtext: AppLocalizations.of(context).categoryDetailNoTransactionsSubtext,
      );
    }

    final isAmountSort = currentSortType == SortType.amountDesc ||
        currentSortType == SortType.amountAsc;

    // 父分类与各子分类的交易平铺在同一个列表里，仅按日期分组；
    // 每行按交易自身 categoryId 渲染真实分类名与 icon。
    final dateOrder = <String>[];
    final dateGroups = <String, List<db.Transaction>>{};
    for (final tx in transactions) {
      final dk = DateFormat('yyyy-MM-dd').format(tx.happenedAt.toLocal());
      if (!dateGroups.containsKey(dk)) {
        dateGroups[dk] = [];
        dateOrder.add(dk);
      }
      dateGroups[dk]!.add(tx);
    }
    // 时间排序按日期键排；金额排序保持 provider 已排好的金额顺序，只切日期标题。
    if (!isAmountSort) {
      dateOrder.sort(currentSortType == SortType.timeDesc
          ? (a, b) => b.compareTo(a)
          : (a, b) => a.compareTo(b));
    }

    final items = <Object>[]; // [_DateHeaderItem | _TransactionDisplayItem]
    for (final dk in dateOrder) {
      final dayTxns = dateGroups[dk]!;
      final dayExpense = dayTxns
          .where((t) => t.type == 'expense')
          .fold<int>(0, (sum, t) => sum + (t.nativeAmount ?? t.amount));
      items.add(_DateHeaderItem(dk, dayExpense / 100));
      for (final tx in dayTxns) {
        final cat = _getCategoryForTransaction(tx, categoryMap);
        if (cat == null) continue;
        items.add(_TransactionDisplayItem(tx, cat));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _DateHeaderItem) {
          return DaySectionHeader(
            dateText: item.dateKey,
            expense: item.expense,
            // 日期小计带当前账本本位币符号（与主页 transaction_list 口径一致）
            currencyCode: ref.watch(currentLedgerCurrencyProvider),
          );
        } else if (item is _TransactionDisplayItem) {
          final transaction = item.transaction;
          final cat = item.category;
          return TransactionListItem(
            icon: getCategoryIconData(category: cat),
            category: cat,
            title: transaction.note ?? '',
            // 平铺列表每行显示该交易自身的分类名。
            categoryName: CategoryUtils.getDisplayName(cat.name, context),
            amount: transaction.amount,
            currencyCode: transaction.currencyCode,
            nativeAmount: transaction.nativeAmount,
            isExpense: transaction.type == 'expense',
            happenedAt: transaction.happenedAt,
            onTap: () async {
              // 点击行 → 详情 sheet(AA 支出人/分摊明细 + 常驻「编辑记账」按钮),
              // 与首页交易列表的「先看再改」交互口径一致。
              await showTransactionDetailSheet(
                context: context,
                transaction: transaction,
                category: cat,
                memberDisplayMap: memberMap,
                // 本地账本无成员表:传本地昵称供详情页兜底展示(纯本地,不依赖云端登录态)
                localOwnerDisplayName: localOwnerName,
                // 账本是否开启分摊决定底部按钮态(单/双)与右上角删除 icon 布局
                aaEnabled: aaEnabled,
                onEdit: () => TransactionEditUtils.editTransaction(
                  context,
                  ref,
                  transaction,
                  cat,
                ),
                // 编辑分摊入口:仅开启分摊时使用,跳 AaEditPage 直接落库 AA 字段
                onEditAa: () => TransactionAaEditUtils.editTransactionAa(
                  context,
                  ref,
                  transaction,
                  cat,
                ),
                onDelete: () => _deleteTransaction(transaction),
              );
            },
            onDelete: () => _deleteTransaction(transaction),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// 根据交易的 [tx.categoryId] 查找其实际所属的分类对象。
  ///
  /// 设计意图：分类汇总页同时展示一级 + 二级分类的交易，每笔交易应使用
  /// 其真实分类的 icon 与名称；查不到时回退到当前一级分类。
  db.Category? _getCategoryForTransaction(
    db.Transaction tx,
    Map<int, db.Category> categoryMap,
  ) {
    final catId = tx.categoryId;
    if (catId != null && categoryMap.containsKey(catId)) {
      return categoryMap[catId];
    }
    // 回退：查不到（如 tx 无分类或 shared ledger synthetic）时用一级分类
    return categoryMap[widget.categoryId];
  }

}

class _SummaryItem extends ConsumerWidget {
  final String label;
  final dynamic value; // 可以是 String 或 double
  final Color color;
  final bool isAmount; // 是否为金额类型

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget valueWidget;
    if (isAmount && value is double) {
      // 金额类型,使用 AmountText；showCurrency 显示当前账本本位币符号
      // （总金额/平均金额基于 nativeAmount 汇总，口径即本位币）。
      valueWidget = AmountText(
        value: value as double,
        signed: false,
        showCurrency: true,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      // 其他类型,直接显示字符串
      valueWidget = Text(
        value.toString(),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      children: [
        valueWidget,
        const SizedBox(height: SpitoutDimens.p4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

// ===== 响应式Provider设计 =====

/// 监听分类及其所有子分类，构建 categoryId → Category 映射。
///
/// 用于 CategoryDetailPage 内每笔交易按 [transaction.categoryId] 查找
/// 其实际所属分类，展示正确的 icon 与名称。
final _categorySubsMapProvider =
    StreamProvider.family<Map<int, db.Category>, int>((ref, categoryId) {
  final repo = ref.watch(repositoryProvider);
  // 正数 id 走本地分类查询；负数（shared ledger synthetic）走 SharedLedgerCategories
  // 镜像，返回 synthetic 一级 + 全部二级分类，供列表回退渲染。
  return repo.watchCategoryWithSubs(categoryId).map((categories) {
    return {for (final c in categories) c.id: c};
  });
});

// 基础数据流：监听分类下交易变化（仅当前账本）
// includeSubCategories: true —— 一级分类汇总需包含其所有二级分类的交易，
// 确保「一级分类无直接交易但二级分类有交易」时汇总金额不为 0。
final _categoryTransactionsStreamProvider = StreamProvider.family<List<db.Transaction>, ({int categoryId, int ledgerId})>((ref, params) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTransactionsByCategory(
    params.categoryId,
    ledgerId: params.ledgerId,
    includeSubCategories: true,
  );
});

// 排序状态管理
final _categorySortTypeProvider =
    NotifierProvider.family<SimpleStateNotifier<SortType>, SortType, int>(
  (categoryId) => SimpleStateNotifier((ref) => SortType.timeDesc),
);

// 派生数据：排序后的交易列表（自动响应排序状态变化）
final _categoryTransactionsWithSortProvider = Provider.family<AsyncValue<List<db.Transaction>>, ({int categoryId, int ledgerId})>((ref, params) {
  final transactionsAsync = ref.watch(_categoryTransactionsStreamProvider(params));
  final sortType = ref.watch(_categorySortTypeProvider(params.categoryId));

  return transactionsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (transactions) {
      final sorted = List<db.Transaction>.from(transactions);

      switch (sortType) {
        case SortType.timeAsc:
          sorted.sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
          break;
        case SortType.timeDesc:
          sorted.sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
          break;
        case SortType.amountAsc:
          // 金额排序与列表展示/小计口径一致:按折本位币金额排。
          sorted.sort(
            (a, b) =>
                (a.nativeAmount ?? a.amount).compareTo(
                  b.nativeAmount ?? b.amount,
                ),
          );
          break;
        case SortType.amountDesc:
          sorted.sort(
            (a, b) =>
                (b.nativeAmount ?? b.amount).compareTo(
                  a.nativeAmount ?? a.amount,
                ),
          );
          break;
      }

      return AsyncValue.data(sorted);
    },
  );
});

class _SortButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p12, vertical: SpitoutDimens.p4),
        decoration: BoxDecoration(
          color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(SpitoutDimens.radius16),
          border: Border.all(
            color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected
              ? SpitoutTokens.textOnPrimary(context)
              : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w400 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
