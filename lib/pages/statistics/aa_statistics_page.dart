import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/core/router/routes.dart';
import 'package:spitout/services/statistics/aa_member_detail_models.dart';
import 'package:spitout/services/statistics/aa_statistics_service.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/utils/category_utils.dart';
import 'package:spitout/widgets/me_suffix.dart';
import 'package:spitout/widgets/widgets.dart';

/// AA 分摊统计页。
///
/// 内容结构(自上而下):
/// 1. 汇总卡:分摊总额 + 分摊交易笔数;
/// 2. 分摊详情表:实付 / 应摊 / 差额(应收应付着色);
/// 3. 转账方案:贪心结算结果,已结清时展示零转账提示;
/// 4. 不分摊:aaMode=1 的交易。
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
    final excludedAsync = ref.watch(_aaNoSplitTxProvider(ledgerId));

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
              // 依赖数据变更信号触发的后台重算必须保留旧数据继续展示，
              // 否则云同步/其它设备写入本地库时整页反复转圈。
              skipLoadingOnReload: true,
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
    // 总付口径：直接复用成员支出统计（账本编辑页「成员支出」同源，含不分摊），
    // 按参与人 id 建映射，保证分摊详情表与账本管理的成员汇总金额一致。
    final memberStats =
        ref.watch(memberExpenseStatsProvider(ledgerId)).value ??
        const <MemberExpenseStatItem>[];
    final totalPaidAllOf = <String, double>{
      for (final s in memberStats) s.participantId: s.expenseTotal,
    };
    // 首页同款协作头像成员表：共享账本与首页同源 ledgerMembersProvider
    // （同一套磁盘缓存）；本地账本为空映射 → 不渲染头像。
    final avatarCtx =
        ref.watch(aaParticipantAvatarContextProvider(ledgerId)).value;
    final memberMap = avatarCtx?.members ?? const {};
    final isShared = memberMap.isNotEmpty;

    // 只展示有实际分摊活动的参与人(全零成员无信息量)。
    final active = statistics.participants
        .where((p) => p.totalPaid > 0 || p.totalShouldPay > 0)
        .toList();
    // 仅有「不分摊」支出的参与人没有 AA 统计值，但成员账单详情页本质是
    // 「首页支出列表按成员筛选」，必须能从分摊详情表进入查看自己的全部支出，
    // 故把这类参与人补充进列表（总付展示成员支出，其余列按其真实统计值 0 展示）。
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
      padding: const EdgeInsets.all(SpitoutDimens.p16),
      children: [
        _buildOverviewCard(context, l10n, totalAmount, active.length),
        const SizedBox(height: SpitoutDimens.p16),
        _buildSectionTitle(context, l10n.aaStatisticsPerPerson),
        const SizedBox(height: SpitoutDimens.p8),
        _buildPerPersonCard(
          context,
          ref,
          l10n,
          ledgerId,
          active,
          totalPaidAllOf,
        ),
        const SizedBox(height: SpitoutDimens.p16),
        _buildSectionTitle(context, l10n.aaStatisticsTransferPlan),
        const SizedBox(height: SpitoutDimens.p8),
        _buildTransferCard(context, ref, l10n, statistics.transfers),
        // 不分摊区块始终展示(数据为空时由卡片内部渲染空态)。
        const SizedBox(height: SpitoutDimens.p16),
        _buildSectionTitle(context, l10n.aaStatisticsExcluded),
        const SizedBox(height: SpitoutDimens.p8),
        _buildExcludedCard(
          context,
          ref,
          l10n,
          excluded,
          memberMap,
          isShared,
        ),
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
      padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p16, horizontal: SpitoutDimens.p16),
      child: Column(
        children: [
          Text(
            l10n.aaStatisticsTotalAmount,
            style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
          ),
          const SizedBox(height: SpitoutDimens.p8),
          AmountText(
            value: totalAmount,
            signed: false,
            showCurrency: true,
            // 汇总金额必须完整可见：金额超大时等比缩小字号而非省略。
            scaleDown: true,
            style: SpitoutTextTokens.display2(context).copyWith(color: SpitoutTokens.textPrimary(context)),
          ),
          const SizedBox(height: SpitoutDimens.p8),
          Text(
            l10n.aaStatisticsParticipantCount(participantCount),
            style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textTertiary(context)),
          ),
        ],
      ),
    );
  }

  /// 分摊详情表:每位成员一个可点击模块(头像 + 名称 + 「查看详情」徽章 +
  /// 总付 / 分摊实付 / 应摊 / 差额四列),点击模块进入该成员账单详情页。
  Widget _buildPerPersonCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int ledgerId,
    List<AaParticipantSummary> active,
    Map<String, double> totalPaidAllOf,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < active.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: SpitoutTokens.divider(context)),
            _buildPerPersonRow(
              context,
              ref,
              l10n,
              ledgerId,
              active[i],
              totalPaidAllOf,
            ),
          ],
        ],
      ),
    );
  }

  /// 分摊详情行:头像 + 名称 + 总付 / 分摊实付 / 应摊 / 差额四列,
  /// 点击进入成员账单详情。
  Widget _buildPerPersonRow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int ledgerId,
    AaParticipantSummary p,
    Map<String, double> totalPaidAllOf,
  ) {
    // 总付/分摊实付/应摊/差额统一带账本币种符号,与汇总卡口径一致。
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
        padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16, vertical: SpitoutDimens.p12),
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
                  size: SpitoutDimens.icon28,
                ),
                const SizedBox(width: SpitoutDimens.p8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: p.displayName,
                      style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textPrimary(context)),
                      children: [if (p.isSelf) meSuffixSpan(context, l10n)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SpitoutDimens.p8),
                _buildViewDetailsPill(context, l10n),
              ],
            ),
            const SizedBox(height: SpitoutDimens.p12),
            // 第二行:总付 / 分摊实付 / 应摊 / 差额(应收绿、应付红)四列居中。
            Row(
              children: [
                _buildMemberMetric(
                  context,
                  l10n.aaStatisticsPaidAll,
                  formatMoneyWithCurrency(
                    totalPaidAllOf[p.participantId] ?? 0,
                    currencyCode: currencyCode,
                  ),
                ),
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
  /// 与模块标题色条同源，不引入成员专属渐变配色。
  Widget _buildViewDetailsPill(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SpitoutDimens.p8, vertical: SpitoutDimens.p4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.aaStatisticsViewDetails,
            style: SpitoutTextTokens.caption(context).copyWith(color: primary),
          ),
          const SizedBox(width: SpitoutDimens.p4),
          Icon(AppIcons.chevronRight, size: SpitoutDimens.icon12, color: primary),
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
            style: SpitoutTextTokens.caption(context).copyWith(color: SpitoutTokens.textTertiary(context)),
          ),
          const SizedBox(height: SpitoutDimens.p4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: SpitoutTextTokens.label(context).copyWith(fontWeight: FontWeight.w600, color: valueColor ?? SpitoutTokens.textPrimary(context)),
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
  /// 「付给」文案使用主题色(蓝色)以突出转账动作,字号与两侧用户名一致;
  /// 转账金额采用中性色
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
      padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16, vertical: SpitoutDimens.p8),
      child: transfers.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.checkCircle,
                    size: SpitoutDimens.icon16,
                    color: SpitoutTokens.success(context),
                  ),
                  const SizedBox(width: SpitoutDimens.p8),
                  Text(
                    l10n.aaStatisticsNoTransfers,
                    style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
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
                    padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p12),
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
                                          style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textPrimary(
                                              context,
                                            )),
                                          children: [
                                            meSuffixSpan(context, l10n),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : Text(
                                        transfers[i].fromName,
                                        style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textPrimary(
                                            context,
                                          )),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpitoutDimens.p4,
                                ),
                                child: Text(
                                  l10n.aaStatisticsTransferSeparator,
                                  style: SpitoutTextTokens.body(context).copyWith(// 「付给」使用主题色(蓝色),突出转账动作。
                                    color: primaryColor),
                                ),
                              ),
                              Flexible(
                                // 本人参与人:名称后追加共享「(我)」后缀,
                                // 与分摊详情表口径一致。
                                child: transfers[i].toIsSelf
                                    ? Text.rich(
                                        TextSpan(
                                          text: transfers[i].toName,
                                          style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textPrimary(
                                              context,
                                            )),
                                          children: [
                                            meSuffixSpan(context, l10n),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : Text(
                                        transfers[i].toName,
                                        style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textPrimary(
                                            context,
                                          )),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: SpitoutDimens.p12),
                        AmountText(
                          value: transfers[i].amount,
                          signed: false,
                          showCurrency: true,
                          // 转账金额必须完整可见：金额超大时等比缩小字号而非省略。
                          scaleDown: true,
                          style: SpitoutTextTokens.body(context).copyWith(// 中性色,与分摊详情表实付一致,不加粗。
                            color: amountColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// 不分摊卡:aaMode=1 的交易,完全照搬首页列表布局(日期表头 + 列表项)
  Widget _buildExcludedCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<({Transaction t, Category? category})> excluded,
    Map<String, SpitoutCloudLedgerMember> memberMap,
    bool isShared,
  ) {
    if (excluded.isEmpty) {
      return SectionCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p12),
          child: Center(
            child: Text(
              l10n.aaStatisticsExcludedEmpty,
              style: SpitoutTextTokens.label(context).copyWith(
                color: SpitoutTokens.textTertiary(context),
              ),
            ),
          ),
        ),
      );
    }

    // 与首页 TransactionList 同口径按天分组（倒序），组内保持时间倒序。
    final groups = <String, List<({Transaction t, Category? category})>>{};
    for (final it in excluded) {
      final dt = it.t.happenedAt.toLocal();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
      (groups[key] ??= []).add(it);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final currencyCode = ref.watch(currentLedgerCurrencyProvider);

    return SectionCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final key in sortedKeys) ...[
            _buildDayHeader(context, key, groups[key]!, currencyCode),
            for (final it in groups[key]!)
              _buildExcludedRow(context, it, memberMap, isShared),
          ],
        ],
      ),
    );
  }

  /// 日期分组表头:与首页一致,展示日期与当日支出合计。
  Widget _buildDayHeader(
    BuildContext context,
    String dateKey,
    List<({Transaction t, Category? category})> items,
    String currencyCode,
  ) {
    // 与首页一致:仅统计支出交易,按折本位币累加当日合计。
    var dayExpense = 0;
    for (final it in items) {
      if (it.t.type == 'expense') {
        dayExpense += it.t.nativeAmount ?? it.t.amount;
      }
    }
    return DaySectionHeader(
      dateText: dateKey,
      expense: dayExpense / 100,
      currencyCode: currencyCode,
    );
  }

  /// 单条不分摊行:复用 [TransactionListItem],传参与首页列表完全一致
  /// (icon + 分类名 + 备注 + 协作头像 + 时间 + 金额 + 不计收支标签)。
  Widget _buildExcludedRow(
    BuildContext context,
    ({Transaction t, Category? category}) it,
    Map<String, SpitoutCloudLedgerMember> memberMap,
    bool isShared,
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
      // 与首页完全一致:共享账本渲染协作头像(同源缓存)、展示不计收支标签。
      collaboratorMap: memberMap,
      creatorUserId: it.t.createdByUserId,
      editorUserId: it.t.lastEditedByUserId,
      isShared: isShared,
      excludeFromStats: it.t.excludeFromStats,
    );
  }

  /// 模块标题:与账本编辑页版块标题同风格(主题色小条 + 加粗标题)。
  Widget _buildSectionTitle(BuildContext context, String text) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(SpitoutDimens.radius4),
            ),
          ),
          const SizedBox(width: SpitoutDimens.p8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 不分摊的交易(aaMode=1)查询。
///
/// 统计页「不分摊」区块数据源;[aaStatisticsProvider] 只返回汇总结果,
/// 详单行需要交易本体 + 分类(用于 icon / 分类名展示,与首页列表完全一致),
/// 故在此单独查询带 category 的交易列表。
final _aaNoSplitTxProvider = StreamProvider.autoDispose
    .family<List<({Transaction t, Category? category})>, int>((ref, ledgerId) {
      // 依赖统计 provider:交易变化重算汇总时,清单同步刷新。
      ref.watch(aaStatisticsProvider(ledgerId));
      final repo = ref.read(repositoryProvider);
      // 过滤下沉到数据层查询(aaMode=1),避免整库交易流在客户端过滤。
      return repo.watchExcludedAaTransactions(ledgerId);
    });
