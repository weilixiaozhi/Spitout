import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../services/statistics/aa_member_detail_models.dart';
import '../../services/statistics/aa_statistics_service.dart' show AaMode;
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/icons/app_icons.dart';
import '../../theme/typography.dart';
import '../../utils/category_utils.dart';
import '../../utils/currency/currencies.dart' show getCurrencySymbol;
import '../../widgets/me_suffix.dart';
import '../../widgets/widgets.dart';

/// 成员账单详情页（按支出人维度汇总）。
///
/// 内容结构（自上而下，严格参考设计稿）：
/// 1. 头部：返回 + 成员头像 + 成员名 / 账本名；
/// 2. 汇总卡（深色英雄卡）：账单汇总 - 总笔数 / 总金额 / 平均金额，
///    底部展示该成员应收（应付）金额；
/// 3. 分摊方式：AA分摊 / 指定金额 笔数双卡；
/// 4. 账单列表：按日期分组的账单卡片，每笔含分类 / 分摊方式徽标 / 备注 /
///    时间·付款人 / 本人应摊 / 账单总额，并展开分摊明细。
///
/// 数据源为 [aaMemberDetailProvider]：只展示该成员作为支出人的 AA 账单；
/// 虚拟用户 / 账本 owner / 协作者均可从分摊详情表进入查看，本人标记与
/// 汇总口径和分摊详情表完全一致。
class AaMemberDetailPage extends ConsumerWidget {
  const AaMemberDetailPage({super.key, required this.args});

  /// 路由入参（账本 id + 参与人标识 + 展示名 / 本人标记）。
  final AaMemberDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(
      aaMemberDetailProvider((
        ledgerId: args.ledgerId,
        participantId: args.participantId,
      )),
    );

    return Scaffold(
      body: Column(
        children: [
          // 数据未就绪时头部也能渲染成员名（名称已随路由参数传入）。
          _buildHeader(context, detailAsync.value?.ledgerName),
          Expanded(
            child: detailAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '${l10n.commonError}: $e',
                  style: TextStyle(color: SpitoutTokens.error(context)),
                ),
              ),
              data: (data) => data == null
                  ? _buildCenterEmpty(context, l10n)
                  : _buildBody(context, ref, l10n, data),
            ),
          ),
        ],
      ),
    );
  }

  /// 头部：返回 + 成员头像 + 成员名 + 账本名副标题。
  ///
  /// 设计稿头部含前导头像，而 [PrimaryHeader] 的标题区不支持前导头像，
  /// 故此处按 PrimaryHeader 同一规格（返回图标 20px / 热区 30×30 /
  /// 顶部留白 10 / 左右留白 14）自定义头部行，保证与全局头部视觉一致。
  Widget _buildHeader(BuildContext context, String? ledgerName) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 14, right: 14),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  AppIcons.back,
                  size: 20,
                  color: SpitoutTokens.iconPrimary(context),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              AaParticipantAvatar(
                ledgerId: args.ledgerId,
                participantId: args.participantId,
                isSelf: args.isSelf,
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      args.displayName,
                      style: SpitoutTextTokens.strongTitle(
                        context,
                      ).copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ledgerName != null && ledgerName.isNotEmpty)
                      Text(
                        ledgerName,
                        style: SpitoutTextTokens.label(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AaMemberDetailData data,
  ) {
    // 汇总/分摊方式均按账本本位币口径，与分摊详情表一致。
    final currencyCode = ref.watch(currentLedgerCurrencyProvider);
    final totalAmount = data.bills.fold<double>(
      0,
      (sum, b) => sum + b.totalAmount,
    );
    final avgAmount = data.bills.isEmpty
        ? 0.0
        : totalAmount / data.bills.length;
    final aaCount = data.bills.where((b) => b.mode == AaMode.perPerson).length;
    final customCount = data.bills.length - aaCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(
          context,
          l10n,
          data,
          totalAmount,
          avgAmount,
          currencyCode,
        ),
        const SizedBox(height: 20),
        _buildSplitMethod(context, l10n, aaCount, customCount),
        const SizedBox(height: 20),
        if (data.bills.isEmpty)
          _buildEmptyCard(context, l10n)
        else
          ..._buildBillGroups(context, l10n, data.bills, currencyCode),
      ],
    );
  }

  /// 汇总卡（深色英雄卡）：账单汇总 - 总笔数 / 总金额 / 平均金额，
  /// 底部展示该成员应收 / 应付金额（与分摊详情表净额口径一致）。
  Widget _buildSummaryCard(
    BuildContext context,
    AppLocalizations l10n,
    AaMemberDetailData data,
    double totalAmount,
    double avgAmount,
    String currencyCode,
  ) {
    // 深色卡上的文字统一用「反色文字 + 透明度」表达层级，
    // 强调数字用项目琥珀（warning）而非设计稿写死的 #amber-400。
    final heroText = SpitoutTokens.textOnPrimary(context);
    final heroSub = heroText.withValues(alpha: 0.5);
    final warn = SpitoutTokens.warning(context);
    final net = data.member.net;
    final netLabel = net.abs() < 0.005
        ? l10n.aaStatisticsSettled
        : (net > 0
              ? l10n.aaStatisticsNetReceiveAmount
              : l10n.aaStatisticsNetPayAmount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: SpitoutTokens.cardHero(context),
        borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.receipt, size: 14, color: heroSub),
              const SizedBox(width: 6),
              Text(
                l10n.aaStatisticsBillSummary,
                style: TextStyle(fontSize: 11, color: heroSub),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 总笔数：白字大号。
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.bills.length}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: heroText,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.aaStatisticsTotalCount,
                      style: TextStyle(fontSize: 11, color: heroSub),
                    ),
                  ],
                ),
              ),
              // 总金额 / 平均金额：币种符号 + 琥珀数字。
              Expanded(
                child: _buildHeroAmountColumn(
                  context,
                  totalAmount,
                  l10n.aaStatisticsTotal,
                  currencyCode,
                  warn,
                  heroSub,
                ),
              ),
              Expanded(
                child: _buildHeroAmountColumn(
                  context,
                  avgAmount,
                  l10n.aaStatisticsAverage,
                  currencyCode,
                  warn,
                  heroSub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: heroText.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(netLabel, style: TextStyle(fontSize: 12, color: heroSub)),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatMoneyWithCurrency(
                      net.abs(),
                      currencyCode: currencyCode,
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: warn,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 汇总卡金额列：币种符号（小号琥珀）在上、数字（大号琥珀）在下，
  /// 超宽时等比缩小字号保证金额完整可见。
  Widget _buildHeroAmountColumn(
    BuildContext context,
    double value,
    String label,
    String currencyCode,
    Color warn,
    Color sub,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          getCurrencySymbol(currencyCode.toUpperCase()),
          style: TextStyle(fontSize: 11, color: warn),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoneyCompact(value, maxDecimals: 2),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: warn,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: sub)),
      ],
    );
  }

  /// 分摊方式：AA分摊 / 指定金额 笔数双卡。
  ///
  /// 指定金额卡沿用设计稿的琥珀强调（浅底 + 琥珀边框/数字），
  /// 颜色统一走项目 warning token，不硬编码设计稿色值。
  Widget _buildSplitMethod(
    BuildContext context,
    AppLocalizations l10n,
    int aaCount,
    int customCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n.aaSplitMode,
            style: TextStyle(
              fontSize: 12,
              color: SpitoutTokens.textTertiary(context),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMethodCard(
                context,
                aaCount,
                l10n.aaStatisticsModePerPerson,
                accent: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMethodCard(
                context,
                customCount,
                l10n.aaStatisticsModeCustom,
                accent: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodCard(
    BuildContext context,
    int count,
    String label, {
    required bool accent,
  }) {
    final warn = SpitoutTokens.warning(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accent
            ? warn.withValues(alpha: 0.08)
            : SpitoutTokens.surface(context),
        borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
        border: Border.all(
          color: accent
              ? warn.withValues(alpha: 0.3)
              : SpitoutTokens.divider(context),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: accent ? warn : SpitoutTokens.textPrimary(context),
              height: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: accent ? warn : SpitoutTokens.textTertiary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 账单列表：按日期分组（日期标题复用全局 [DaySectionHeader]），
  /// 每组一张白色卡片，组内每笔账单为「主行 + 分摊明细」。
  List<Widget> _buildBillGroups(
    BuildContext context,
    AppLocalizations l10n,
    List<AaMemberBill> bills,
    String currencyCode,
  ) {
    final groups = <String, List<AaMemberBill>>{};
    for (final b in bills) {
      final key = _dateKey(b.tx.happenedAt);
      (groups[key] ??= []).add(b);
    }

    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      final dayTotal = entry.value.fold<double>(
        0,
        (sum, b) => sum + b.totalAmount,
      );
      widgets.add(
        DaySectionHeader(
          dateText: entry.key,
          expense: dayTotal,
          currencyCode: currencyCode,
        ),
      );
      widgets.add(
        SectionCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < entry.value.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: SpitoutTokens.divider(context)),
                _buildBillRow(context, l10n, entry.value[i], currencyCode),
              ],
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }

  /// 单笔账单：分类图标 + 分类名/分摊方式徽标 + 备注 + 时间·付款人 +
  /// 右侧本人应摊/账单总额，下方展开分摊明细。
  Widget _buildBillRow(
    BuildContext context,
    AppLocalizations l10n,
    AaMemberBill bill,
    String currencyCode,
  ) {
    final categoryName = CategoryUtils.getDisplayName(
      bill.category?.name,
      context,
    );
    final time = bill.tx.happenedAt;
    final timeText =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    // 单笔账单金额优先按交易原币种展示，与首页列表项口径一致；
    // 历史数据无币种时回退账本本位币。
    final txCurrency = bill.tx.currencyCode ?? currencyCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类图标：与首页列表项同规格（36×36 圆形次级底）。
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SpitoutTokens.surfaceSecondary(context),
                  shape: BoxShape.circle,
                ),
                child: CategoryIconWidget(category: bill.category, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            categoryName,
                            style: SpitoutTextTokens.title(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildSplitBadge(context, bill.mode, l10n),
                      ],
                    ),
                    if (bill.tx.note != null && bill.tx.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        bill.tx.note!,
                        style: TextStyle(
                          fontSize: 11,
                          color: SpitoutTokens.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '$timeText · ${l10n.aaStatisticsPayerPrefix}: '
                      '${bill.payerName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: SpitoutTokens.textTertiary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 右侧：本人应摊（支出红）+ 账单总额。
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                    value: -bill.myShare,
                    signed: true,
                    showCurrency: true,
                    decimals: 2,
                    currencyCode: txCurrency,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SpitoutTokens.error(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.aaStatisticsTxTotalPrefix} '
                    '${formatMoneyWithCurrency(bill.totalAmount, currencyCode: txCurrency)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: SpitoutTokens.textTertiary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
        // 分摊明细：浅色圆角容器，每行 头像 + 名称（本人带「(我)」）+ 金额。
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: SpitoutTokens.surfaceSecondary(context),
            borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.aaStatisticsSplitDetail,
                style: TextStyle(
                  fontSize: 10,
                  color: SpitoutTokens.textTertiary(context),
                ),
              ),
              const SizedBox(height: 6),
              for (final s in bill.splits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      AaParticipantAvatar(
                        ledgerId: args.ledgerId,
                        participantId: s.participantId,
                        isSelf: s.isSelf,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: s.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              color: SpitoutTokens.textSecondary(context),
                            ),
                            children: [
                              if (s.isSelf) meSuffixSpan(context, l10n),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatMoneyWithCurrency(
                              s.amount,
                              currencyCode: txCurrency,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: SpitoutTokens.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 分摊方式徽标：AA分摊（主题蓝）/ 指定金额（琥珀），
  /// 颜色走项目主题 token，不硬编码设计稿色值。
  Widget _buildSplitBadge(
    BuildContext context,
    AaMode mode,
    AppLocalizations l10n,
  ) {
    final isPerPerson = mode == AaMode.perPerson;
    final color = isPerPerson
        ? Theme.of(context).colorScheme.primary
        : SpitoutTokens.warning(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPerPerson
            ? l10n.aaStatisticsModePerPerson
            : l10n.aaStatisticsModeCustom,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, AppLocalizations l10n) {
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          l10n.aaStatisticsMemberTxEmpty,
          style: TextStyle(
            fontSize: 13,
            color: SpitoutTokens.textTertiary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterEmpty(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Text(
        l10n.aaStatisticsMemberTxEmpty,
        style: TextStyle(color: SpitoutTokens.textTertiary(context)),
      ),
    );
  }

  /// 日期分组 key（yyyy-MM-dd），与全局 [DaySectionHeader] 的日期格式一致。
  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
