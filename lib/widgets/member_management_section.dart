// 成员管理模块 — 列出账本成员,Owner 可踢人,并在成员列表下方内嵌邀请码生成模块
// (生成 6 位邀请码 + 复制 / 分享短链,仅 Owner 可见)。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show SpitoutCloudInvite, SpitoutCloudLedgerMember;
import 'package:spitout/cloud/sync/sync_events.dart' show PushCompleted;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart'
    show spitoutCloudProviderInstance, syncEventStreamProvider;
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'section_card.dart';
import 'toast.dart';

/// 成员管理模块
///
/// 作为内容版块内嵌在编辑账本页中:成员列表 + (Owner)邀请模块。
/// 卡片外边距与页面内 Material Card 默认 margin(all: 4) 对齐。
class MemberManagementSection extends ConsumerStatefulWidget {
  const MemberManagementSection({
    super.key,
    required this.ledgerExternalId,
    required this.ledgerName,
  });

  /// Server external_id(本地 syncId)。
  final String ledgerExternalId;

  /// 账本名称,用于分享邀请时的文案拼接。
  final String ledgerName;

  @override
  ConsumerState<MemberManagementSection> createState() =>
      _MemberManagementSectionState();
}

class _MemberManagementSectionState
    extends ConsumerState<MemberManagementSection> {
  // 邀请码有效期选项:1d / 3d / 7d
  static const _expiryOptions = <int>[24, 72, 168];

  /// 邀请模块本地状态 — 有效期 / 已生成的邀请码 / 生成中 / 错误信息。
  int _expiresInHours = 24;
  SpitoutCloudInvite? _generated;
  bool _busy = false;
  String? _error;

  /// 调用云端生成邀请码,结果 / 错误内联展示在邀请模块中。
  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await createInviteAndRefresh(
        ref,
        ledgerId: widget.ledgerExternalId,
        role: 'editor',
        expiresInHours: _expiresInHours,
      );
      if (!mounted) return;
      setState(() => _generated = invite);
    } catch (e) {
      if (!mounted) return;
      // 防线 A(发邀请前分类上云)失败:展示本地化友好提示;
      // 其余错误(云端未配置、createInvite 失败等)保留原始文本便于定位。
      setState(() => _error = e is CategorySyncBeforeInviteException
          ? AppLocalizations.of(context).categorySyncFailedBeforeInvite
          : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 复制文本到剪贴板并弹 toast 反馈。
  Future<void> _copy(String value, AppLocalizations l10n) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showToast(context, l10n.commonCopied);
  }

  /// 调起系统分享,携带账本名 + 邀请码 + 短链。
  Future<void> _share(SpitoutCloudInvite invite, AppLocalizations l10n) async {
    final message = l10n.sharedInviteShareText(
      widget.ledgerName,
      invite.formattedCode,
      invite.shareUrl,
    );
    await SharePlus.instance.share(ShareParams(text: message));
  }

  /// 小时数转本地化有效期标签(<24h 显示小时,否则显示天数)。
  String _expiryLabel(int hours, AppLocalizations l10n) {
    if (hours < 24) return l10n.sharedInviteExpiryHours(hours);
    final days = hours ~/ 24;
    return l10n.sharedInviteExpiryDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final membersAsync =
        ref.watch(ledgerMembersProvider(widget.ledgerExternalId));

    // 云端账本刚创建时本地已生成 syncId,但账本数据要等首次 push 完成后
    // 才真正存在于 server。在此期间 listMembers 会抛 "Ledger not found",
    // 因此监听同步事件:该账本 push 完成时自动重拉成员列表,成员区从
    // 「等待同步」提示自动恢复到正常列表,无需用户手动刷新。
    ref.listen(syncEventStreamProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event is PushCompleted &&
          event.ledgerId == widget.ledgerExternalId) {
        ref.invalidate(ledgerMembersProvider(widget.ledgerExternalId));
      }
    });

    // 模块内嵌在页面滚动视图中,加载 / 错误态只需占位展示,不撑满全屏。
    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        // 首次同步未完成时 server 尚无该账本,listMembers 抛 Ledger not found,
        // 此时展示友好提示而非原始 CloudSyncException 红字,避免误导用户
        // 以为是权限 / 配置问题;其余错误仍保留原始文本便于定位。
        final syncPending = e.toString().contains('Ledger not found');
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            syncPending
                ? l10n.sharedMembersSyncPending
                : '${l10n.commonError}: $e',
            textAlign: TextAlign.center,
          ),
        );
      },
      data: (members) => _buildContent(context, members, l10n),
    );
  }

  /// 成员列表 + (Owner)内嵌邀请模块。
  Widget _buildContent(
    BuildContext context,
    List<SpitoutCloudLedgerMember> members,
    AppLocalizations l10n,
  ) {
    final me = members.where((m) => m.isSelf).firstOrNull;
    final amOwner = me?.role == 'owner';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              for (final m in members) ...[
                _MemberTile(
                  member: m,
                  amOwner: amOwner,
                  onRemove: amOwner && !m.isSelf
                      ? () => _confirmRemove(context, m, l10n)
                      : null,
                ),
                if (m != members.last) const Divider(height: 1),
              ],
            ],
          ),
        ),
        // 仅 Owner 可见的内嵌邀请模块,与成员列表保持 16px 间距
        if (amOwner) ...[
          const SizedBox(height: 16),
          _buildInviteSection(context, l10n),
        ],
      ],
    );
  }

  /// 内嵌邀请模块 — 默认收起只显示标题(personAdd + 「邀请新成员」),
  /// 点击标题展开内容,按状态切换:未生成时展示表单,已生成时展示邀请码分享视图。
  Widget _buildInviteSection(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Theme(
        // 去掉 ExpansionTile 默认的上下分割线,贴合 SectionCard 风格
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 16, bottom: 4),
          leading: Icon(AppIcons.personAdd, size: 18, color: primary),
          title: Text(
            l10n.sharedMembersInviteCta,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          children: [
            if (_generated == null)
              _buildInviteForm(l10n)
            else
              _buildShareView(_generated!, l10n),
          ],
        ),
      ),
    );
  }

  /// 邀请表单 — 角色(固定 editor)+ 有效期选择 + 生成按钮。
  Widget _buildInviteForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.sharedInviteFormRole,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.sharedRoleEditor),
              selected: true,
              onSelected: (_) {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.sharedInviteFormExpiry,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final h in _expiryOptions)
              ChoiceChip(
                label: Text(_expiryLabel(h, l10n)),
                selected: _expiresInHours == h,
                onSelected: _busy
                    ? null
                    : (sel) {
                        if (sel) setState(() => _expiresInHours = h);
                      },
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _generate,
          icon: const Icon(AppIcons.qrCode),
          label: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.sharedInviteGenerate),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.sharedInviteWarning,
          style: TextStyle(
            color: SpitoutTokens.textTertiary(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 邀请码分享视图 — 大号邀请码 + 有效期 + 复制 / 分享 / 复制链接操作。
  Widget _buildShareView(SpitoutCloudInvite invite, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SelectableText(
            invite.formattedCode,
            style: const TextStyle(
              fontSize: 36,
              letterSpacing: 6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            l10n.sharedInviteExpiresAt(
              invite.expiresAt.toLocal().toString().split('.').first,
            ),
            style: TextStyle(
                color: SpitoutTokens.textTertiary(context), fontSize: 12),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(AppIcons.copy),
                label: Text(l10n.sharedInviteCopyCode),
                onPressed: () => _copy(invite.code, l10n),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(AppIcons.share),
                label: Text(l10n.sharedInviteShareLink),
                onPressed: () => _share(invite, l10n),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(AppIcons.link),
          label: Text(l10n.sharedInviteCopyLink),
          onPressed: () => _copy(invite.shareUrl, l10n),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.sharedInviteInstruction,
          style: TextStyle(color: SpitoutTokens.textSecondary(context)),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _generated = null;
              _error = null;
            });
          },
          child: Text(l10n.sharedInviteGenerateAnother),
        ),
      ],
    );
  }

  /// 二次确认后移除协作者(云端 DELETE /members)。
  Future<void> _confirmRemove(
    BuildContext context,
    SpitoutCloudLedgerMember target,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.sharedMembersRemoveTitle),
        content: Text(l10n.sharedMembersRemoveConfirm(
            target.displayName ?? target.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await removeMemberAndRefresh(
        ref,
        ledgerId: widget.ledgerExternalId,
        userId: target.userId,
      );
      if (context.mounted) showToast(context, l10n.sharedMembersRemoved);
    } catch (e) {
      if (context.mounted) showToast(context, e.toString());
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.amOwner,
    this.onRemove,
  });

  final SpitoutCloudLedgerMember member;
  final bool amOwner;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayName = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : member.email.split('@').first;
    final isOwner = member.role == 'owner';
    return ListTile(
      leading: _MemberAvatar(member: member, displayName: displayName),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (member.isSelf) ...[
            const SizedBox(width: 4),
            Text(
              ' (${l10n.sharedMembersYou})',
              style: TextStyle(
                color: SpitoutTokens.textTertiary(context),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        member.email,
        style:
            TextStyle(color: SpitoutTokens.textSecondary(context), fontSize: 12),
      ),
      // 移除按钮放在角色标签左侧,而非右侧:这样 Owner 行(无按钮)与
      // Editor 行(有按钮)的角色标签都能贴最右对齐,两行标签右缘一致,
      // 视觉上「所有者 / 编辑者」保持固定对齐。
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (amOwner && !member.isSelf && !isOwner)
            IconButton(
              icon: const Icon(AppIcons.personRemove, size: 20),
              tooltip: l10n.sharedMembersRemoveCta,
              onPressed: onRemove,
            ),
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(isOwner ? l10n.sharedRoleOwner : l10n.sharedRoleEditor),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

/// 共享账本成员头像 — server avatar_url 拼上 cloudProvider.baseUrl 用 NetworkImage,
/// 缺失 / 加载失败 fallback 到首字母 CircleAvatar。
class _MemberAvatar extends ConsumerWidget {
  const _MemberAvatar({required this.member, required this.displayName});

  final SpitoutCloudLedgerMember member;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final relativeUrl = member.avatarUrl;
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
      onBackgroundImageError: (_, __) {/* fallback child 显示 */},
      child: Text(letter),
    );
  }
}
