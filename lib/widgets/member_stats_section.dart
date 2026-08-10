// 成员支出模块 — 按支出人(paidByUserId)统计账本全部支出,
// 标题右侧展示账本总支出金额,下方按成员列出 支出 / 笔数 / 占比。
//
// 数据源为本地 memberExpenseStatsProvider(按 paidByUserId 聚合),
// 含真实成员 + 虚拟用户;paidByUserId 为空的交易不计入(无法归属支出人)。
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/colors.dart';
import 'format_money.dart';
import 'me_suffix.dart';
import 'person_avatar.dart';
import 'section_card.dart';

/// 成员支出模块
///
/// 自带模块标题（色条 + "成员支出"，右侧为账本总支出金额副标题），
/// 作为内容版块内嵌在编辑账本页中。卡片外边距与页面内 Material Card
/// 默认 margin(all: 4) 对齐。
///
/// 常驻显示:新建态/本地账本(无 ledgerId)时数据默认归 0,
/// 直接展示空态。
class MemberStatsSection extends ConsumerWidget {
  const MemberStatsSection({
    super.key,
    required this.ledgerId,
  });

  /// 本地账本 id(int);null = 新建态。
  ///
  /// 为 null 时不拉取统计,标题右侧不展示总支出金额,
  /// 内容区直接展示"暂无记账"空态。
  final int? ledgerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = ledgerId;
    // 新建态(无 ledgerId):不 watch 本地统计,直接归 0 空态。
    final statsAsync = id != null
        ? ref.watch(memberExpenseStatsProvider(id))
        : const AsyncValue<List<MemberExpenseStatItem>>.data([]);

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
    AsyncValue<List<MemberExpenseStatItem>> statsAsync,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    // 总支出带账本币种符号展示,与成员条目金额口径一致。
    final amount = _totalExpenseText(
        statsAsync.value, ref.watch(currentLedgerCurrencyProvider));
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
  String? _totalExpenseText(
      List<MemberExpenseStatItem>? stats, String currencyCode) {
    if (stats == null || stats.isEmpty) return null;
    final total =
        stats.fold<double>(0, (s, it) => s + it.expenseTotal);
    return formatMoneyWithCurrency(total, currencyCode: currencyCode);
  }

  /// 各成员支出条目列表。
  Widget _buildMemberList(
    BuildContext context,
    List<MemberExpenseStatItem> stats,
    AppLocalizations l10n,
  ) {
    if (stats.isEmpty) {
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
        stats.fold<double>(0, (s, it) => s + it.expenseTotal);
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          for (final s in stats) ...[
            _MemberStatTile(
              stat: s,
              totalExpense: totalExpense,
            ),
            if (s != stats.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _MemberStatTile extends ConsumerWidget {
  const _MemberStatTile({
    required this.stat,
    required this.totalExpense,
  });

  final MemberExpenseStatItem stat;
  final double totalExpense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayName = stat.displayName;
    final share = totalExpense > 0
        ? (stat.expenseTotal / totalExpense * 100).clamp(0, 100)
        : 0;
    return ListTile(
      leading: _StatsAvatar(stat: stat),
      // 标题行与成员管理模块一致:本人「(我)」后缀统一走共享 MeSuffix,
      // 字号/颜色/字重相同,保证两模块本人展示统一。
      title: Row(
        children: [
          Flexible(
            child: Text(displayName, overflow: TextOverflow.ellipsis),
          ),
          if (stat.isSelf) const MeSuffix(),
        ],
      ),
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
            // 成员支出金额:带账本币种符号,与标题总支出口径一致。
            formatMoneyWithCurrency(stat.expenseTotal,
                currencyCode: ref.watch(currentLedgerCurrencyProvider)),
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

/// 成员支出头像 — 本人优先用本地头像文件，真实成员用 server avatar_url，
/// 都没有或加载失败才回退 person 图标。
class _StatsAvatar extends ConsumerWidget {
  const _StatsAvatar({required this.stat});

  final MemberExpenseStatItem stat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 本人本地头像优先（离线可用、上传后即时生效）
    final localPath = stat.localAvatarPath;
    if (localPath != null && localPath.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(localPath),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const PersonAvatar(size: 40, iconSize: 18),
        ),
      );
    }

    final relativeUrl = stat.avatarUrl;
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return const PersonAvatar(size: 40, iconSize: 18);
    }
    final cloudAsync = ref.watch(spitoutCloudProviderInstance);
    final base = cloudAsync.value?.baseUrl;
    if (base == null || base.isEmpty) {
      return const PersonAvatar(size: 40, iconSize: 18);
    }
    final trimmedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final absoluteUrl =
        relativeUrl.startsWith('http') ? relativeUrl : '$trimmedBase$relativeUrl';
    return ClipOval(
      child: Image.network(
        absoluteUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) => progress == null
            ? child
            : const PersonAvatar(size: 40, iconSize: 18),
        errorBuilder: (_, _, _) =>
            const PersonAvatar(size: 40, iconSize: 18),
      ),
    );
  }
}
