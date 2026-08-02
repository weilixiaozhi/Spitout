// 成员支出模块 — 按成员统计账本全部支出,
// 标题右侧展示账本总支出金额,下方按成员列出 支出 / 笔数 / 占比。
import 'package:flutter/material.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show SpitoutCloudMemberStats, SpitoutCloudMemberStatItem;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart'
    show spitoutCloudProviderInstance;
import 'package:spitout/providers/ui/theme_providers.dart'
    show expenseColorSchemeProvider;
import '../theme/colors.dart';
import 'format_money.dart';
import 'section_card.dart';

/// 成员支出模块
///
/// 自带模块标题（色条 + "成员支出"，右侧为账本总支出金额副标题），
/// 作为内容版块内嵌在编辑账本页中。卡片外边距与页面内 Material Card
/// 默认 margin(all: 4) 对齐。
class MemberStatsSection extends ConsumerWidget {
  const MemberStatsSection({
    super.key,
    required this.ledgerExternalId,
  });

  /// Server external_id(本地 syncId)。
  final String ledgerExternalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(
      memberStatsProvider(MemberStatsKey(ledgerId: ledgerExternalId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTitle(context, ref, l10n, statsAsync),
        const SizedBox(height: 8),
        // 模块内嵌在页面滚动视图中,加载 / 错误态只需占位展示,不撑满全屏。
        statsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child:
                Text('${l10n.commonError}: $e', textAlign: TextAlign.center),
          ),
          data: (stats) => _buildMemberList(context, stats, l10n),
        ),
      ],
    );
  }

  /// 模块标题行：左侧色条 + "成员支出"，右侧账本总支出金额右对齐副标题。
  Widget _buildTitle(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<SpitoutCloudMemberStats?> statsAsync,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final amount = _totalExpenseText(statsAsync.valueOrNull);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.sharedMembersStatsTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
          ),
          const Spacer(),
          if (amount != null)
            // 右边缘与成员条目金额对齐：卡片 margin(4) + 卡片 padding(12) + ListTile contentPadding(12) = 28,
            // 减去标题行自身 padding(4) 后需补 24
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Text(
                amount,
                // 与成员条目金额统一：12 号字 + 主题色（红/绿，跟随支出语义）
                style: TextStyle(
                  color: ref.watch(expenseColorSchemeProvider) == 'green'
                      ? SpitoutTokens.success(context)
                      : SpitoutTokens.error(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 账本总支出金额文本；统计无数据时返回 null。
  String? _totalExpenseText(SpitoutCloudMemberStats? stats) {
    if (stats == null || stats.items.isEmpty) return null;
    final total =
        stats.items.fold<double>(0, (s, it) => s + it.expenseTotal);
    return formatMoneyWithCurrency(total, currencyCode: stats.ledgerCurrency);
  }

  /// 各成员支出条目列表。
  Widget _buildMemberList(
    BuildContext context,
    SpitoutCloudMemberStats? stats,
    AppLocalizations l10n,
  ) {
    if (stats == null || stats.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          l10n.sharedMembersStatsEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: SpitoutTokens.textTertiary(context)),
        ),
      );
    }
    final totalExpense =
        stats.items.fold<double>(0, (s, it) => s + it.expenseTotal);
    final currency = stats.ledgerCurrency;
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          for (final s in stats.items) ...[
            _MemberStatTile(
              stat: s,
              currency: currency,
              totalExpense: totalExpense,
            ),
            if (s != stats.items.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _MemberStatTile extends ConsumerWidget {
  const _MemberStatTile({
    required this.stat,
    required this.currency,
    required this.totalExpense,
  });

  final SpitoutCloudMemberStatItem stat;
  final String currency;
  final double totalExpense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayName = stat.displayName?.isNotEmpty == true
        ? stat.displayName!
        : (stat.email?.split('@').first ?? stat.userId.substring(0, 6));
    final share = totalExpense > 0
        ? (stat.expenseTotal / totalExpense * 100).clamp(0, 100)
        : 0;
    return ListTile(
      leading: _StatsAvatar(stat: stat, displayName: displayName),
      title: Text(displayName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        l10n.sharedMembersStatsTxCount(stat.txCount),
        style: TextStyle(
          color: SpitoutTokens.textTertiary(context),
          fontSize: 11,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (totalExpense > 0) ...[
            Text(
              '${share.toStringAsFixed(0)}%',
              style: TextStyle(
                color: SpitoutTokens.textTertiary(context),
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            formatMoneyWithCurrency(stat.expenseTotal,
                currencyCode: currency),
            style: TextStyle(
              color: ref.watch(expenseColorSchemeProvider) == 'green'
                  ? SpitoutTokens.success(context)
                  : SpitoutTokens.error(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsAvatar extends ConsumerWidget {
  const _StatsAvatar({required this.stat, required this.displayName});

  final SpitoutCloudMemberStatItem stat;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final relativeUrl = stat.avatarUrl;
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return CircleAvatar(child: Text(letter));
    }
    final cloudAsync = ref.watch(spitoutCloudProviderInstance);
    final cloud = cloudAsync.valueOrNull;
    final base = cloud?.baseUrl;
    if (base == null || base.isEmpty) {
      return CircleAvatar(child: Text(letter));
    }
    final absoluteUrl =
        relativeUrl.startsWith('http') ? relativeUrl : '$base$relativeUrl';
    return CircleAvatar(
      backgroundImage: NetworkImage(absoluteUrl),
      onBackgroundImageError: (_, __) {},
      child: Text(letter),
    );
  }
}
