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
import '../theme/icons/app_icons.dart';
import 'format_money.dart';
import 'section_card.dart';

/// 成员支出模块
///
/// 自带模块标题（色条 + "成员支出"，右侧为账本总支出金额副标题），
/// 作为内容版块内嵌在编辑账本页中。卡片外边距与页面内 Material Card
/// 默认 margin(all: 4) 对齐。
///
/// 常驻显示:新建态/本地账本(无 syncId)时数据默认归 0,
/// 直接展示空态,不跟随云端。
class MemberStatsSection extends ConsumerWidget {
  const MemberStatsSection({
    super.key,
    required this.ledgerExternalId,
    required this.aaEnabled,
    required this.onOpenSettlement,
  });

  /// Server external_id(本地 syncId);null/空 = 新建态或本地账本。
  ///
  /// 为空时不拉取云端统计,标题右侧不展示总支出金额,
  /// 内容区直接展示"暂无记账"空态(数据默认归 0)。
  final String? ledgerExternalId;

  /// AA 分摊开关当前状态;开启时在标题下方显示分摊结算入口。
  ///
  /// 入口跟随开关立即显示/隐藏,不依赖保存按钮。
  final bool aaEnabled;

  /// 分摊结算入口点击回调(由父组件判断是否可跳转:仅编辑态当前账本可跳,
  /// 否则提示先保存账本)。
  final VoidCallback onOpenSettlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final syncId = ledgerExternalId;
    // 无 syncId(新建态/本地账本):不 watch 云端统计,直接归 0 空态。
    final statsAsync = (syncId != null && syncId.isNotEmpty)
        ? ref.watch(memberStatsProvider(MemberStatsKey(ledgerId: syncId)))
        : const AsyncValue<SpitoutCloudMemberStats?>.data(null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTitle(context, ref, l10n, statsAsync),
        // 分摊结算入口:跟随 AA 开关立即显示(开启就显示),无需保存。
        // 样式与"加入共享账本"入口一致(全宽 OutlinedButton)。
        if (aaEnabled) ...[
          const SizedBox(height: 8),
          _buildSettlementEntry(context, l10n),
        ],
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

  /// 分摊结算入口(成员支出标题下方,AA 开关开启时显示)。
  Widget _buildSettlementEntry(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton.icon(
        icon: const Icon(AppIcons.pieChart, size: 18),
        label: Text(l10n.ledgerAaSettlementEntry),
        onPressed: onOpenSettlement,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 40.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
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
    // 成员未设昵称时优先展示完整邮箱,邮箱缺失才回退 id 前缀
    final displayName = stat.displayName?.isNotEmpty == true
        ? stat.displayName!
        : (stat.email?.isNotEmpty == true
            ? stat.email!
            : stat.userId.substring(0, 6));
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
