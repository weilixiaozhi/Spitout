import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../services/statistics/aa_member_detail_models.dart';
import '../../services/statistics/aa_statistics_service.dart' show AaMode;
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/icons/app_icons.dart';
import '../../theme/shadows.dart';
import '../../theme/typography.dart';
import '../../utils/category_utils.dart';
import '../../utils/currency/currencies.dart' show getCurrencySymbol;
import '../../widgets/me_suffix.dart';
import '../../widgets/widgets.dart';

/// 分摊方式卡片的强调等级：普通（AA）、琥珀（指定金额）、弱化（不分摊）。
enum _MethodAccent { normal, warning, muted }

/// 成员账单详情页（按支出人维度汇总）。
///
/// 内容结构（自上而下，严格参考设计稿）：
/// 1. 头部：返回 + 成员头像 + 成员名 / 账本名；
/// 2. 汇总卡（深色英雄卡）：账单汇总 - 总笔数 / 总金额 / 平均金额，
///    底部展示该成员应收（应付）金额；
/// 3. 分摊方式：AA分摊 / 指定金额 / 不分摊 笔数三卡；
/// 4. 账单列表：按日期分组的账单卡片，每笔含分类 / 分摊方式徽标 / 备注 /
///    时间·付款人 / 本人支出 / 账单总额；AA 账单展开分摊明细，
///    不分摊账单无分摊明细。
///
/// 数据源为 [aaMemberDetailProvider]：展示该成员作为支出人的全部支出明细
/// （含不分摊，即首页列表按成员筛选）；虚拟用户 / 账本 owner / 协作者均可
/// 从分摊详情表进入查看，本人标记与汇总口径和分摊详情表完全一致。
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
              error: (e, st) {
                // 原始异常只进日志,页面展示统一友好文案,避免泄露实现细节。
                logger.error(
                  'AaMemberDetailPage',
                  '成员账单详情加载失败 participant=${args.participantId}',
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
    // 汇总/分摊方式/单笔账单均按账本本位币口径，与分摊详情表一致。
    final currencyCode = ref.watch(currentLedgerCurrencyProvider);
    final totalAmount = data.bills.fold<double>(
      0,
      (sum, b) => sum + b.totalAmount,
    );
    final avgAmount = data.bills.isEmpty
        ? 0.0
        : totalAmount / data.bills.length;
    final aaCount = data.bills.where((b) => b.mode == AaMode.perPerson).length;
    final customCount = data.bills.where((b) => b.mode == AaMode.custom).length;
    final noSplitCount = data.bills
        .where((b) => b.mode == AaMode.noSplit)
        .length;
    // 账单列表扁平化索引:日期标题 + 单笔账单行,交给 ListView.builder 懒加载,
    // 避免几百笔账单时每次 build 都创建整棵 Widget 树。
    final entries = data.bills.isEmpty
        ? const <Object>[]
        : _flattenBillEntries(data.bills);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2 + (data.bills.isEmpty ? 1 : entries.length),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummaryCard(
            context,
            l10n,
            data,
            totalAmount,
            avgAmount,
            currencyCode,
          );
        }
        if (index == 1) {
          // 汇总卡与分摊方式卡之间保持 20 间距,与改动前视觉一致。
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: _buildSplitMethod(
              context,
              l10n,
              aaCount,
              customCount,
              noSplitCount,
            ),
          );
        }
        if (data.bills.isEmpty) {
          return _buildEmptyCard(context, l10n);
        }
        final entry = entries[index - 2];
        if (entry is _BillDateHeader) {
          return DaySectionHeader(
            dateText: entry.dateKey,
            expense: entry.dayTotal,
            currencyCode: currencyCode,
          );
        }
        if (entry is _BillRowEntry) {
          return _buildBillRowItem(context, l10n, entry, currencyCode);
        }
        return const SizedBox.shrink();
      },
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

  /// 分摊方式：AA分摊 / 指定金额 / 不分摊 笔数三卡。
  ///
  /// 指定金额卡沿用设计稿的琥珀强调（浅底 + 琥珀边框/数字），
  /// 不分摊卡用弱化中性色（不参与分摊），颜色统一走项目 token。
  Widget _buildSplitMethod(
    BuildContext context,
    AppLocalizations l10n,
    int aaCount,
    int customCount,
    int noSplitCount,
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
                _MethodAccent.normal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMethodCard(
                context,
                customCount,
                l10n.aaStatisticsModeCustom,
                _MethodAccent.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMethodCard(
                context,
                noSplitCount,
                l10n.aaModeNoSplit,
                _MethodAccent.muted,
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
    String label,
    _MethodAccent accent,
  ) {
    final warn = SpitoutTokens.warning(context);
    final (bg, border, number, text) = switch (accent) {
      _MethodAccent.normal => (
        SpitoutTokens.surface(context),
        SpitoutTokens.divider(context),
        SpitoutTokens.textPrimary(context),
        SpitoutTokens.textTertiary(context),
      ),
      _MethodAccent.warning => (
        warn.withValues(alpha: 0.08),
        warn.withValues(alpha: 0.3),
        warn,
        warn,
      ),
      _MethodAccent.muted => (
        SpitoutTokens.surfaceSecondary(context),
        SpitoutTokens.divider(context),
        SpitoutTokens.textSecondary(context),
        SpitoutTokens.textTertiary(context),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: number,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 把账单列表展平为「日期标题 + 单笔账单」的索引序列。
  ///
  /// 设计意图:ListView.builder 需要扁平的 item 序列才能按需构建;
  /// 每行记录是否组首/组尾,由 [_buildBillRowItem] 据此绘制连续卡片
  /// 的圆角、内部分割线与组尾间距。
  List<Object> _flattenBillEntries(List<AaMemberBill> bills) {
    final groups = <String, List<AaMemberBill>>{};
    for (final b in bills) {
      final key = _dateKey(b.tx.happenedAt);
      (groups[key] ??= []).add(b);
    }

    final entries = <Object>[];
    for (final entry in groups.entries) {
      final dayTotal = entry.value.fold<double>(
        0,
        (sum, b) => sum + b.totalAmount,
      );
      entries.add(_BillDateHeader(entry.key, dayTotal));
      final dayBills = entry.value;
      for (var i = 0; i < dayBills.length; i++) {
        entries.add(
          _BillRowEntry(
            bill: dayBills[i],
            isFirstInGroup: i == 0,
            isLastInGroup: i == dayBills.length - 1,
          ),
        );
      }
    }
    return entries;
  }

  /// 单笔账单行容器:组首行负责卡片顶部圆角与阴影,组尾行负责底部圆角
  /// 与组间距,中间行仅提供表面底色 + 上分割线,整体视觉等同原来的一张
  /// SectionCard,但每一行可被 ListView.builder 独立懒加载。
  Widget _buildBillRowItem(
    BuildContext context,
    AppLocalizations l10n,
    _BillRowEntry entry,
    String currencyCode,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: entry.isLastInGroup ? 16 : 0),
      decoration: BoxDecoration(
        color: SpitoutTokens.surface(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            entry.isFirstInGroup ? SpitoutDimens.radius12 : 0,
          ),
          bottom: Radius.circular(
            entry.isLastInGroup ? SpitoutDimens.radius12 : 0,
          ),
        ),
        // 整组卡片阴影由组首/组尾行承载(中间行表面覆盖组首下缘),
        // 视觉上仍是一张卡片的外围阴影。
        boxShadow: SpitoutTokens.isDark(context)
            ? null
            : (entry.isFirstInGroup || entry.isLastInGroup)
                ? SpitoutShadows.card
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!entry.isFirstInGroup)
            Divider(height: 1, color: SpitoutTokens.divider(context)),
          _buildBillRow(context, l10n, entry.bill, currencyCode),
        ],
      ),
    );
  }

  /// 单笔账单：分类图标 + 分类名/分摊方式徽标 + 备注 + 时间·付款人 +
  /// 右侧本人支出/账单总额；AA 账单下方展开分摊明细，不分摊无明细。
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
    // 单笔账单金额为账本本位币口径(与汇总卡/分摊详情表一致),
    // 避免多币种账本下原币金额与汇总口径混用。

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
              // 右侧：本人支出（AA 为应摊额，不分摊为全额）+ 账单总额。
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                    value: -bill.myShare,
                    signed: true,
                    showCurrency: true,
                    decimals: 2,
                    currencyCode: currencyCode,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SpitoutTokens.error(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.aaStatisticsTxTotalPrefix} '
                    '${formatMoneyWithCurrency(bill.totalAmount, currencyCode: currencyCode)}',
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
        // 分摊明细：仅 AA 账单渲染；不分摊账单无分摊明细。
        if (bill.splits.isNotEmpty)
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
                                currencyCode: currencyCode,
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

  /// 分摊方式徽标：AA分摊（主题蓝）/ 指定金额（琥珀）/ 不分摊（中性灰），
  /// 颜色走项目主题 token，不硬编码设计稿色值。
  Widget _buildSplitBadge(
    BuildContext context,
    AaMode mode,
    AppLocalizations l10n,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final warn = SpitoutTokens.warning(context);
    final (color, bg) = switch (mode) {
      AaMode.perPerson => (primary, primary.withValues(alpha: 0.08)),
      AaMode.custom => (warn, warn.withValues(alpha: 0.08)),
      AaMode.noSplit => (
        SpitoutTokens.textSecondary(context),
        SpitoutTokens.surfaceSecondary(context),
      ),
    };
    final label = switch (mode) {
      AaMode.perPerson => l10n.aaStatisticsModePerPerson,
      AaMode.custom => l10n.aaStatisticsModeCustom,
      AaMode.noSplit => l10n.aaModeNoSplit,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
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

/// 账单列表扁平化条目:日期分组标题(日期 + 当日支出合计)。
class _BillDateHeader {
  final String dateKey;
  final double dayTotal;

  const _BillDateHeader(this.dateKey, this.dayTotal);
}

/// 账单列表扁平化条目:单笔账单行。
///
/// [isFirstInGroup]/[isLastInGroup] 用于渲染组卡片的首尾圆角、分割线与
/// 组尾间距,保证懒加载拆分后视觉与原来的整张卡片一致。
class _BillRowEntry {
  final AaMemberBill bill;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const _BillRowEntry({
    required this.bill,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });
}
