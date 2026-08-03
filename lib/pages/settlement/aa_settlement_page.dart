import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../services/settlement/aa_settlement_service.dart';
import '../../theme/colors.dart';
import '../../theme/icons/app_icons.dart';
import '../../utils/category_utils.dart';
import '../../widgets/widgets.dart';

/// AA 分摊统计页。
///
/// 内容结构(自上而下):
/// 1. 汇总卡:分摊总额 + 分摊交易笔数;
/// 2. 分摊详情表:实付 / 应摊 / 差额(应收应付着色);
/// 3. 转账方案:贪心结算结果,已结清时展示零转账提示;
/// 4. 不计入详单:aaMode=1(不分摊)的交易。
///
/// 数据源为 [aaSettlementProvider]。账本 id 由进入入口经 [ledgerId] 传入
/// ("从哪里进入就是哪个账本"),缺省(如新建态)时按无账本渲染,各模块自带
/// 空数据兜底(金额为 0 / 无行),不设整页空态。
class AaSettlementPage extends ConsumerWidget {
  const AaSettlementPage({super.key, this.ledgerId});

  /// 账本 id：由进入入口传入（编辑态为当前编辑账本 id，新建态为 null）。
  /// null 时按无账本渲染，各模块展示空数据。
  final int? ledgerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 新建态无账本 id → 哨兵 0：getLedgerById(0) 返回空，汇总/清单均为空。
    final ledgerId = this.ledgerId ?? 0;
    final settlementAsync = ref.watch(aaSettlementProvider(ledgerId));
    final excludedAsync = ref.watch(_aaExcludedTxProvider(ledgerId));

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.aaSettlementTitle,
            showBack: true,
          ),
          Expanded(
            child: settlementAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '$e',
                  style: TextStyle(color: SpitoutTokens.error(context)),
                ),
              ),
              data: (settlement) => _buildBody(
                context,
                ref,
                l10n,
                settlement,
                excludedAsync.valueOrNull ?? const [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AaLedgerSettlement settlement,
    List<({Transaction t, Category? category})> excluded,
  ) {
    // 只展示有实际分摊活动的参与人(全零成员无信息量)。
    final active = settlement.participants
        .where((p) => p.totalPaid > 0 || p.totalShouldPay > 0)
        .toList();

    // 分摊总额 = 各参与人实付合计(每笔 AA 交易由支出人实付一次,恒等)。
    final totalAmount =
        active.fold(0.0, (sum, p) => sum + p.totalPaid);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverviewCard(context, l10n, totalAmount, active.length),
        const SizedBox(height: 20),
        _buildSectionTitle(context, l10n.aaSettlementPerPerson),
        const SizedBox(height: 8),
        _buildPerPersonCard(context, ref, l10n, active),
        const SizedBox(height: 20),
        _buildSectionTitle(context, l10n.aaSettlementTransferPlan),
        const SizedBox(height: 8),
        _buildTransferCard(context, ref, l10n, settlement.transfers),
        // 不计入详单区块始终展示(数据为空时由卡片内部渲染空态)。
        const SizedBox(height: 20),
        _buildSectionTitle(context, l10n.aaSettlementExcluded),
        const SizedBox(height: 8),
        _buildExcludedCard(context, ref, l10n, excluded),
      ],
    );
  }

  /// 汇总卡:分摊总额(大字号) + 参与人数。
  Widget _buildOverviewCard(BuildContext context, AppLocalizations l10n,
      double totalAmount, int participantCount) {
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Text(
            l10n.aaSettlementTotalAmount,
            style: TextStyle(
              fontSize: 13,
              color: SpitoutTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          AmountText(
            value: totalAmount,
            signed: false,
            showCurrency: true,
            decimals: 2,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: SpitoutTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aaSettlementParticipantCount(participantCount),
            style: TextStyle(
              fontSize: 12,
              color: SpitoutTokens.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 分摊详情表:成员 / 实付 / 应摊 / 差额(应收绿、应付红)。
  Widget _buildPerPersonCard(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, List<AaParticipantSummary> active) {
    final headerStyle = TextStyle(
      fontSize: 12,
      color: SpitoutTokens.textTertiary(context),
    );
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 表头
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('', style: headerStyle)),
                Expanded(
                  flex: 3,
                  child: Text(l10n.aaSettlementPaid,
                      style: headerStyle, textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 3,
                  child: Text(l10n.aaSettlementShare,
                      style: headerStyle, textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 3,
                  child: Text(l10n.aaSettlementNet,
                      style: headerStyle, textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: SpitoutTokens.divider(context)),
          for (var i = 0; i < active.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: SpitoutTokens.divider(context)),
            _buildPerPersonRow(context, ref, l10n, active[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPerPersonRow(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, AaParticipantSummary p) {
    // 实付/应摊/差额统一带账本币种符号,与汇总卡口径一致。
    final currencyCode = ref.watch(currentLedgerCurrencyProvider);
    final net = p.net;
    final netColor = net.abs() < 0.005
        ? SpitoutTokens.textTertiary(context)
        : (net > 0
            ? SpitoutTokens.success(context)
            : SpitoutTokens.error(context));
    final netLabel = net.abs() < 0.005
        ? '—'
        : '${net > 0 ? l10n.aaSettlementNetReceive : l10n.aaSettlementNetPay} '
            '${formatMoneyWithCurrency(net.abs(), currencyCode: currencyCode)}';
    final valueStyle = TextStyle(
      fontSize: 13,
      color: SpitoutTokens.textPrimary(context),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              p.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SpitoutTokens.textPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
                formatMoneyWithCurrency(p.totalPaid,
                    currencyCode: currencyCode),
                style: valueStyle,
                textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(
                formatMoneyWithCurrency(p.totalShouldPay,
                    currencyCode: currencyCode),
                style: valueStyle,
                textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(
              netLabel,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: netColor),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 转账方案卡:每行 "A 付给 B" + 金额;已结清展示零转账提示。
  Widget _buildTransferCard(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, List<AaTransfer> transfers) {
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: transfers.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.checkCircle,
                      size: 16, color: SpitoutTokens.success(context)),
                  const SizedBox(width: 8),
                  Text(
                    l10n.aaSettlementNoTransfers,
                    style: TextStyle(
                      fontSize: 13,
                      color: SpitoutTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < transfers.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: SpitoutTokens.divider(context)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(AppIcons.currencyExchange,
                            size: 16,
                            color: SpitoutTokens.iconSecondary(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.aaSettlementTransferPayTo(
                                transfers[i].fromName, transfers[i].toName),
                            style: TextStyle(
                              fontSize: 14,
                              color: SpitoutTokens.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AmountText(
                          value: transfers[i].amount,
                          signed: false,
                          showCurrency: true,
                          decimals: 2,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// 不计入详单卡:aaMode=1(不分摊)的交易,完全照搬首页列表项布局
  /// (icon + 分类名 + 时间/备注 + 金额),保证两处视觉一致。
  ///
  /// 数据为空时展示空态提示,保证区块默认可见(需求要求)。
  Widget _buildExcludedCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<({Transaction t, Category? category})> excluded,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: excluded.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  l10n.aaSettlementExcludedEmpty,
                  style: TextStyle(
                    fontSize: 13,
                    color: SpitoutTokens.textTertiary(context),
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < excluded.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: SpitoutTokens.divider(context)),
                  _buildExcludedRow(context, ref, excluded[i]),
                ],
              ],
            ),
    );
  }

  /// 单条不计入详单行:复用 [TransactionListItem],布局与首页列表完全一致
  /// (icon + 分类名 + 时间/备注 + 金额)。
  Widget _buildExcludedRow(
    BuildContext context,
    WidgetRef ref,
    ({Transaction t, Category? category}) it,
  ) {
    final categoryName =
        CategoryUtils.getDisplayName(it.category?.name, context);
    return TransactionListItem(
      icon: getCategoryIconData(category: it.category),
      category: it.category,
      title: it.t.note ?? '',
      categoryName: categoryName,
      amount: it.t.amount,
      currencyCode: it.t.currencyCode,
      nativeAmount: it.t.nativeAmount,
      isExpense: it.t.type == 'expense',
      happenedAt: it.t.happenedAt,
      lastEditedAt: it.t.lastEditedAt,
      // 不计入详单区块无需展示协作头像/选择模式/不计收支标签,
      // 保持与首页列表一致的简洁双行布局。
      isShared: false,
    );
  }

  /// 模块标题:与账本编辑页版块标题同风格(主题色小条 + 加粗标题)。
  Widget _buildSectionTitle(BuildContext context, String text) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

/// 不计入详单的交易(aaMode=1)查询。
///
/// 统计页「不计入详单」区块数据源;[aaSettlementProvider] 只返回汇总结果,
/// 详单行需要交易本体 + 分类(用于 icon / 分类名展示,与首页列表完全一致),
/// 故在此单独查询带 category 的交易列表。
final _aaExcludedTxProvider =
    StreamProvider.autoDispose.family<List<({Transaction t, Category? category})>, int>(
        (ref, ledgerId) {
  // 依赖统计 provider:交易变化重算汇总时,清单同步刷新。
  ref.watch(aaSettlementProvider(ledgerId));
  final repo = ref.read(repositoryProvider);
  // 复用首页列表同款带 category 的交易流,客户端过滤 aaMode=1。
  return repo.transactionsWithCategoryAll(ledgerId: ledgerId).map(
      (all) => all.where((it) => it.t.aaMode == 1).toList());
});
