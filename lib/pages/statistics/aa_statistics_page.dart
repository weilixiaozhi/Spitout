import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_service.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../routes.dart';
import '../../services/statistics/aa_member_detail_models.dart';
import '../../services/statistics/aa_statistics_service.dart';
import '../../theme/colors.dart';
import '../../theme/icons/app_icons.dart';
import '../../utils/category_utils.dart';
import '../../widgets/me_suffix.dart';
import '../../widgets/widgets.dart';

/// AA 分摊统计页。
///
/// 内容结构(自上而下):
/// 1. 汇总卡:分摊总额 + 分摊交易笔数;
/// 2. 分摊详情表:实付 / 应摊 / 差额(应收应付着色);
/// 3. 转账方案:贪心结算结果,已结清时展示零转账提示;
/// 4. 不计入分摊:aaMode=1(不分摊)的交易。
///
/// 数据源为 [aaStatisticsProvider]。账本 id 由进入入口经 [ledgerId] 传入
/// ("从哪里进入就是哪个账本"),缺省(如新建态)时按无账本渲染,各模块自带
/// 空数据兜底(金额为 0 / 无行),不设整页空态。
class AaStatisticsPage extends ConsumerWidget {
  const AaStatisticsPage({super.key, this.ledgerId});

  /// 账本 id：由进入入口传入（编辑态为当前编辑账本 id，新建态为 null）。
  /// null 时按无账本渲染，各模块展示空数据。
  final int? ledgerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 新建态无账本 id → 哨兵 0：getLedgerById(0) 返回空，汇总/清单均为空。
    final ledgerId = this.ledgerId ?? 0;
    final statisticsAsync = ref.watch(aaStatisticsProvider(ledgerId));
    final excludedAsync = ref.watch(_aaExcludedTxProvider(ledgerId));

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(title: l10n.aaStatisticsTitle, showBack: true),
          Expanded(
            child: statisticsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                // 原始异常只进日志,页面展示统一友好文案,避免泄露实现细节。
                logger.error(
                  'AaStatisticsPage',
                  'AA 分摊统计加载失败 ledger=$ledgerId',
                  e,
                  st,
                );
                return Center(
                  child: Text(
                    l10n.commonOperationFailed,
                    style: TextStyle(color: SpitoutTokens.error(context)),
                  ),
                );
              },
              data: (statistics) => _buildBody(
                context,
                ref,
                l10n,
                ledgerId,
                statistics,
                excludedAsync.value ?? const [],
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
    int ledgerId,
    AaLedgerStatistics statistics,
    List<({Transaction t, Category? category})> excluded,
  ) {
    // 只展示有实际分摊活动的参与人(全零成员无信息量)。
    final active = statistics.participants
        .where((p) => p.totalPaid > 0 || p.totalShouldPay > 0)
        .toList();
    // 仅有「不分摊」支出的参与人没有 AA 统计值，但成员账单详情页本质是
    // 「首页支出列表按成员筛选」，必须能从分摊详情表进入查看自己的全部支出，
    // 故把这类参与人补充进列表（AA 三列按其真实统计值 0 展示）。
    final activeIds = active.map((p) => p.participantId).toSet();
    for (final p in statistics.participants) {
      if (activeIds.contains(p.participantId)) continue;
      final hasNoSplitExpense = excluded.any(
        (it) => it.t.paidByUserId == p.participantId,
      );
      if (hasNoSplitExpense) active.add(p);
    }

    // 分摊总额 = 各参与人实付合计(每笔 AA 交易由支出人实付一次,恒等)。
    final totalAmount = active.fold(0.0, (sum, p) => sum + p.totalPaid);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverviewCard(context, l10n, totalAmount, active.length),
        const SizedBox(height: 20),
        _buildSectionTitle(context, l10n.aaStatisticsPerPerson),
        const SizedBox(height: 8),
        _buildPerPersonCard(context, ref, l10n, ledgerId, active),
        const SizedBox(height: 20),
        _buildSectionTitle(context, l10n.aaStatisticsTransferPlan),
        const SizedBox(height: 8),
        _buildTransferCard(context, ref, l10n, statistics.transfers),
        // 不计入分摊区块始终展示(数据为空时由卡片内部渲染空态)。
        const SizedBox(height: 20),
        _buildSectionTitle(context, l10n.aaStatisticsExcluded),
        const SizedBox(height: 8),
        _buildExcludedCard(context, ref, l10n, excluded),
      ],
    );
  }

  /// 汇总卡:分摊总额(大字号) + 参与人数。
  Widget _buildOverviewCard(
    BuildContext context,
    AppLocalizations l10n,
    double totalAmount,
    int participantCount,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Text(
            l10n.aaStatisticsTotalAmount,
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
            // 汇总金额必须完整可见：金额超大时等比缩小字号而非省略。
            scaleDown: true,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: SpitoutTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aaStatisticsParticipantCount(participantCount),
            style: TextStyle(
              fontSize: 12,
              color: SpitoutTokens.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 分摊详情表:每位成员一个可点击模块(头像 + 名称 + 「查看详情」徽章 +
  /// 实付 / 应摊 / 差额三列),点击模块进入该成员账单详情页。
  Widget _buildPerPersonCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int ledgerId,
    List<AaParticipantSummary> active,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < active.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: SpitoutTokens.divider(context)),
            _buildPerPersonRow(context, ref, l10n, ledgerId, active[i]),
          ],
        ],
      ),
    );
  }

  /// 分摊详情行:头像 + 名称 + 实付 / 应摊 / 差额三列,点击进入成员账单详情。
  Widget _buildPerPersonRow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int ledgerId,
    AaParticipantSummary p,
  ) {
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
        : '${net > 0 ? '+' : '-'}'
              '${formatMoneyWithCurrency(net.abs(), currencyCode: currencyCode)}';
    // 差额列标题:应收 / 应付;净额为零时退化为「差额」+ 占位符。
    final netHeader = net.abs() < 0.005
        ? l10n.aaStatisticsNet
        : (net > 0 ? l10n.aaStatisticsNetReceive : l10n.aaStatisticsNetPay);

    return InkWell(
      // 整个成员模块可点击,进入该成员账单详情页。
      onTap: () => _openMemberDetail(context, ledgerId, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 首行:头像 + 名称(本人带「(我)」后缀)+ 右侧「查看详情」徽章。
            Row(
              children: [
                AaParticipantAvatar(
                  ledgerId: ledgerId,
                  participantId: p.participantId,
                  isSelf: p.isSelf,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: p.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: SpitoutTokens.textPrimary(context),
                      ),
                      children: [if (p.isSelf) meSuffixSpan(context, l10n)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildViewDetailsPill(context, l10n),
              ],
            ),
            const SizedBox(height: 12),
            // 第二行:实付 / 应摊 / 差额(应收绿、应付红)三列居中。
            Row(
              children: [
                _buildMemberMetric(
                  context,
                  l10n.aaStatisticsPaid,
                  formatMoneyWithCurrency(
                    p.totalPaid,
                    currencyCode: currencyCode,
                  ),
                ),
                _buildMemberMetric(
                  context,
                  l10n.aaStatisticsShare,
                  formatMoneyWithCurrency(
                    p.totalShouldPay,
                    currencyCode: currencyCode,
                  ),
                ),
                _buildMemberMetric(context, netHeader, netLabel, netColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 成员模块的「查看详情」徽章：主题色浅底 + 主题色文字/箭头，
  /// 与模块标题色条同源，不引入设计稿的成员专属渐变配色。
  Widget _buildViewDetailsPill(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.aaStatisticsViewDetails,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: primary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(AppIcons.chevronRight, size: 12, color: primary),
        ],
      ),
    );
  }

  /// 成员模块三列指标：标签（次色小字）在上、数值（主色小号加粗）在下。
  ///
  /// 金额超宽时等比缩小字号而非省略/换行，保证金额完整可见。
  Widget _buildMemberMetric(
    BuildContext context,
    String label,
    String value, [
    Color? valueColor,
  ]) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: SpitoutTokens.textTertiary(context),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? SpitoutTokens.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 进入成员账单详情页：按路由跳转，页面间不互相 import。
  void _openMemberDetail(
    BuildContext context,
    int ledgerId,
    AaParticipantSummary p,
  ) {
    Navigator.of(context).pushNamed(
      Routes.aaMemberDetail,
      arguments: AaMemberDetailArgs(
        ledgerId: ledgerId,
        participantId: p.participantId,
        displayName: p.displayName,
        isSelf: p.isSelf,
      ),
    );
  }

  /// 转账方案卡:每行 from 付给 to + 金额;已结清展示零转账提示。
  ///
  /// 「付给」文案使用主题色(蓝色)以突出转账动作;转账金额采用中性色
  /// (与分摊详情表实付一致),不加粗,保持视觉克制。
  Widget _buildTransferCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<AaTransfer> transfers,
  ) {
    // 主题色(蓝色):用于「付给」文案,突出转账动作。
    final primaryColor = Theme.of(context).colorScheme.primary;
    // 中性色:与分摊详情表实付金额一致,转账金额保持克制不加粗。
    final amountColor = SpitoutTokens.textPrimary(context);
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: transfers.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.checkCircle,
                    size: 16,
                    color: SpitoutTokens.success(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.aaStatisticsNoTransfers,
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
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                // 本人参与人:名称后追加共享「(我)」后缀,
                                // 与分摊详情表口径一致。
                                child: transfers[i].fromIsSelf
                                    ? Text.rich(
                                        TextSpan(
                                          text: transfers[i].fromName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: SpitoutTokens.textPrimary(
                                              context,
                                            ),
                                          ),
                                          children: [
                                            meSuffixSpan(context, l10n),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : Text(
                                        transfers[i].fromName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: SpitoutTokens.textPrimary(
                                            context,
                                          ),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  l10n.aaStatisticsTransferSeparator,
                                  style: TextStyle(
                                    fontSize: 12,
                                    // 「付给」使用主题色(蓝色),突出转账动作。
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              Flexible(
                                // 本人参与人:名称后追加共享「(我)」后缀,
                                // 与分摊详情表口径一致。
                                child: transfers[i].toIsSelf
                                    ? Text.rich(
                                        TextSpan(
                                          text: transfers[i].toName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: SpitoutTokens.textPrimary(
                                              context,
                                            ),
                                          ),
                                          children: [
                                            meSuffixSpan(context, l10n),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : Text(
                                        transfers[i].toName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: SpitoutTokens.textPrimary(
                                            context,
                                          ),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AmountText(
                          value: transfers[i].amount,
                          signed: false,
                          showCurrency: true,
                          decimals: 2,
                          // 转账金额必须完整可见：金额超大时等比缩小字号而非省略。
                          scaleDown: true,
                          style: TextStyle(
                            fontSize: 14,
                            // 中性色,与分摊详情表实付一致,不加粗。
                            color: amountColor,
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

  /// 不计入分摊卡:aaMode=1(不分摊)的交易,完全照搬首页列表项布局
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
                  l10n.aaStatisticsExcludedEmpty,
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

  /// 单条不计入分摊行:复用 [TransactionListItem],布局与首页列表完全一致
  /// (icon + 分类名 + 时间/备注 + 金额)。
  Widget _buildExcludedRow(
    BuildContext context,
    WidgetRef ref,
    ({Transaction t, Category? category}) it,
  ) {
    final categoryName = CategoryUtils.getDisplayName(
      it.category?.name,
      context,
    );
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
      // 不计入分摊区块无需展示协作头像/选择模式/不计收支标签,
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

/// 不计入分摊的交易(aaMode=1)查询。
///
/// 统计页「不计入分摊」区块数据源;[aaStatisticsProvider] 只返回汇总结果,
/// 详单行需要交易本体 + 分类(用于 icon / 分类名展示,与首页列表完全一致),
/// 故在此单独查询带 category 的交易列表。
final _aaExcludedTxProvider = StreamProvider.autoDispose
    .family<List<({Transaction t, Category? category})>, int>((ref, ledgerId) {
      // 依赖统计 provider:交易变化重算汇总时,清单同步刷新。
      ref.watch(aaStatisticsProvider(ledgerId));
      final repo = ref.read(repositoryProvider);
      // 过滤下沉到数据层查询(aaMode=1),避免整库交易流在客户端过滤。
      return repo.watchExcludedAaTransactions(ledgerId);
    });
