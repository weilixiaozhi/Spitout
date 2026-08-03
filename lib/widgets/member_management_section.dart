// 成员管理模块 — 列出账本成员(真实成员 + 虚拟用户),
// 并内嵌 AA 分摊开关、添加虚拟用户文字链、邀请新成员模块。
//
// 设计意图:
// - 无论新建/编辑、本地/云端,本模块常驻显示。
//   新建态或本地账本(无 syncId)时,成员列表展示"所有者(我)",
//   邀请新成员入口禁用并提示"请先保存账本"。
// - AA 分摊开关作为本模块内部一个 SwitchListTile,跟随开关立即显示内容
//   (虚拟用户列表 + 添加入口),不依赖保存按钮。
// - 虚拟用户并入成员列表:编辑态直接写库,新建态在父组件内存暂存
//   (保存账本拿到 ledgerId 后批量落库),避免"保存→返回→重新进入→配置"的长路径。
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
import 'package:spitout/providers/ui/theme_providers.dart' show displayNameProvider;
import 'package:spitout/providers/settlement/settlement_providers.dart'
    show
        ledgerVirtualUsersProvider,
        createVirtualUser,
        renameVirtualUser,
        deleteVirtualUser;
import '../data/db.dart' show LedgerVirtualUser;
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'app_dialog.dart';
import 'section_card.dart';
import 'toast.dart';

/// 新建态下内存暂存的虚拟用户(保存账本拿到 ledgerId 后批量落库)。
///
/// 仅有 [name] 字段:新建态没有 ledgerId,无法直接写库,故在 UI 层暂存;
/// 用户点击保存后,父组件遍历此列表调用 [createVirtualUser] 批量创建。
class PendingVirtualUser {
  PendingVirtualUser({required this.name});

  /// 虚拟用户昵称。
  String name;
}

/// 成员管理模块
///
/// 作为内容版块内嵌在编辑账本页中:
/// - 标题行(色条 + "成员管理",AA 开启时右侧显示"添加虚拟用户"文字链)
/// - 成员卡片(真实成员 + 虚拟用户列表 + AA 开关 + 邀请新成员模块)
///
/// 卡片外边距与页面内 Material Card 默认 margin(all: 4) 对齐。
class MemberManagementSection extends ConsumerStatefulWidget {
  const MemberManagementSection({
    super.key,
    required this.ledgerExternalId,
    required this.ledgerName,
    required this.ledgerId,
    required this.aaEnabled,
    required this.onAaChanged,
    required this.isReadOnly,
    required this.pendingVirtualUsers,
    required this.onPendingVirtualUsersChanged,
  });

  /// Server external_id(本地 syncId);null/空 = 新建态或本地账本。
  ///
  /// 为空时本模块展示"所有者(我)"作为唯一成员,邀请新成员入口禁用。
  final String? ledgerExternalId;

  /// 账本名称,用于分享邀请时的文案拼接。
  final String ledgerName;

  /// 本地账本 id(int);null = 新建态。
  ///
  /// 编辑态直接用此 id 拉取/写库虚拟用户;新建态虚拟用户在父组件内存暂存。
  final int? ledgerId;

  /// AA 分摊开关当前状态(父组件持有,跨页面一致)。
  final bool aaEnabled;

  /// AA 分摊开关变化回调(父组件更新状态,保存时一并落库)。
  final ValueChanged<bool> onAaChanged;

  /// 协作者只读判断:只读时禁用所有写操作(开关、踢人、虚拟用户增删改)。
  final bool isReadOnly;

  /// 新建态下内存暂存的虚拟用户列表(仅 ledgerId 为 null 时使用)。
  final List<PendingVirtualUser> pendingVirtualUsers;

  /// 新建态虚拟用户列表变化回调(增删改时通知父组件同步内存状态)。
  final ValueChanged<List<PendingVirtualUser>> onPendingVirtualUsersChanged;

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

  /// 新建态下推导的当前用户信息(异步加载,用于展示"所有者(我)")。
  String? _ownerDisplayName;
  String? _ownerEmail;

  @override
  void initState() {
    super.initState();
    // 仅在无 syncId(新建态/本地账本)时加载当前用户信息作为所有者展示。
    if (widget.ledgerExternalId == null || widget.ledgerExternalId!.isEmpty) {
      _loadCurrentUserInfo();
    }
  }

  /// 加载当前登录用户信息,作为新建态/本地账本的所有者展示。
  ///
  /// 新建态没有 syncId,无法从云端拉成员列表,但账本创建者必然是当前用户,
  /// 故从 auth 推导用户信息展示"所有者(我)"行,保证模块始终有数据。
  Future<void> _loadCurrentUserInfo() async {
    try {
      final cloud = await ref.read(spitoutCloudProviderInstance.future);
      final me = await cloud?.auth.currentUser;
      if (!mounted) return;
      setState(() {
        // CloudUser 仅有 id/email,显示名以本地 displayNameProvider 为准;
        // 兜底回退到 email,email 也没有时由渲染层兜底"我"。
        final localName = ref.read(displayNameProvider);
        _ownerDisplayName =
            localName.trim().isNotEmpty ? localName : me?.email;
        _ownerEmail = me?.email;
      });
    } catch (e) {
      // 推导失败不影响 UI,所有者行仍会展示兜底文本"我"。
    }
  }

  /// 是否为无 syncId 模式(新建态/本地账本)。
  bool get _isNoSyncIdMode =>
      widget.ledgerExternalId == null || widget.ledgerExternalId!.isEmpty;

  /// 是否为新建态(无 ledgerId,虚拟用户在内存暂存)。
  bool get _isCreatingMode => widget.ledgerId == null;

  /// 调用云端生成邀请码,结果 / 错误内联展示在邀请模块中。
  Future<void> _generate() async {
    final syncId = widget.ledgerExternalId;
    if (syncId == null || syncId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await createInviteAndRefresh(
        ref,
        ledgerId: syncId,
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

  /// 添加虚拟用户:自动分配默认名"虚拟用户1/虚拟用户2/..."。
  ///
  /// 编辑态(有 ledgerId):直接写库,Stream 自动刷新列表。
  /// 新建态(无 ledgerId):在父组件内存暂存列表追加,保存时批量落库。
  Future<void> _addVirtualUser() async {
    final l10n = AppLocalizations.of(context);
    // 默认名编号:取现有虚拟用户数 + 1,避免重名。
    final existingCount = _isCreatingMode
        ? widget.pendingVirtualUsers.length
        : (ref.read(ledgerVirtualUsersProvider(widget.ledgerId!))
                .valueOrNull ??
            const <LedgerVirtualUser>[])
            .length;
    final defaultName = l10n.aaVirtualUserDefaultName(existingCount + 1);

    if (_isCreatingMode) {
      // 新建态:内存暂存,保存时批量落库。
      final updated = [...widget.pendingVirtualUsers, PendingVirtualUser(name: defaultName)];
      widget.onPendingVirtualUsersChanged(updated);
    } else {
      // 编辑态:直接写库。
      try {
        await createVirtualUser(
          ref,
          ledgerId: widget.ledgerId!,
          name: defaultName,
        );
      } catch (e) {
        if (mounted) showToast(context, '${l10n.commonFailed}: $e');
      }
    }
  }

  /// 重命名虚拟用户(编辑态直接写库,新建态改内存列表)。
  Future<void> _renameVirtualUser({
    int? existingId,
    required int pendingIndex,
    required String newName,
  }) async {
    final l10n = AppLocalizations.of(context);
    final name = newName.trim();
    if (name.isEmpty) return;
    if (existingId != null) {
      try {
        await renameVirtualUser(ref, id: existingId, name: name);
      } catch (e) {
        if (mounted) showToast(context, '${l10n.commonFailed}: $e');
      }
    } else {
      // 新建态:改内存暂存列表。
      final updated = [...widget.pendingVirtualUsers];
      if (pendingIndex >= 0 && pendingIndex < updated.length) {
        updated[pendingIndex] = PendingVirtualUser(name: name);
        widget.onPendingVirtualUsersChanged(updated);
      }
    }
  }

  /// 删除虚拟用户(编辑态直接写库,新建态从内存列表移除)。
  ///
  /// 编辑态名下有账(被交易 aaParticipants 引用)不可删,
  /// 子仓抛 [StateError],此处 catch 后 toast 提示。
  Future<void> _deleteVirtualUser({
    int? existingId,
    required int pendingIndex,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (existingId != null) {
      final confirmed = await AppDialog.confirm<bool>(
        context,
        title: l10n.commonDelete,
        message: l10n.aaVirtualUserDeleteConfirm(''),
      );
      if (confirmed != true || !mounted) return;
      try {
        await deleteVirtualUser(ref, existingId);
      } on StateError {
        if (mounted) showToast(context, l10n.aaVirtualUserInUse);
      } catch (e) {
        if (mounted) showToast(context, '${l10n.commonFailed}: $e');
      }
    } else {
      // 新建态:从内存暂存列表移除。
      final updated = [...widget.pendingVirtualUsers];
      if (pendingIndex >= 0 && pendingIndex < updated.length) {
        updated.removeAt(pendingIndex);
        widget.onPendingVirtualUsersChanged(updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行(色条 + "成员管理",AA 开启时右侧显示"添加虚拟用户"文字链)
        _buildHeader(context, l10n),
        const SizedBox(height: 8),
        _buildCardContent(context, l10n),
      ],
    );
  }

  /// 模块标题行:左侧色条 + "成员管理",AA 开启时右侧显示"添加虚拟用户"文字链。
  ///
  /// 文字链跟随 AA 开关立即显示/隐藏,点击直接添加默认名"虚拟用户N",
  /// 无需先保存账本(新建态虚拟用户在父组件内存暂存,保存时批量落库)。
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
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
            l10n.sharedMembersPageTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
          ),
          const Spacer(),
          if (widget.aaEnabled && !widget.isReadOnly)
            TextButton.icon(
              onPressed: _addVirtualUser,
              icon: const Icon(AppIcons.personAdd, size: 16),
              label: Text(l10n.aaAddVirtualUser),
              style: TextButton.styleFrom(
                foregroundColor: primary,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  /// 成员卡片内容:无 syncId 模式展示"所有者(我)";有 syncId 模式拉云端成员。
  Widget _buildCardContent(BuildContext context, AppLocalizations l10n) {
    // 无 syncId 模式:成员列表只展示"所有者(我)",不走云端拉取。
    if (_isNoSyncIdMode) {
      return _buildNoSyncIdContent(context, l10n);
    }

    // 有 syncId 模式:从云端拉取成员列表,监听同步事件自动重拉。
    final membersAsync =
        ref.watch(ledgerMembersProvider(widget.ledgerExternalId!));

    // 云端账本刚创建时本地已生成 syncId,但账本数据要等首次 push 完成后
    // 才真正存在于 server。在此期间 listMembers 会抛 "Ledger not found",
    // 因此监听同步事件:该账本 push 完成时自动重拉成员列表,成员区从
    // 加载态自动恢复到正常列表,无需用户手动刷新。
    ref.listen(syncEventStreamProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event is PushCompleted &&
          event.ledgerId == widget.ledgerExternalId) {
        ref.invalidate(ledgerMembersProvider(widget.ledgerExternalId!));
      }
    });

    return membersAsync.when(
      loading: () => _buildLoadingMemberCard(context, l10n, members: const []),
      error: (e, _) => _buildNoSyncIdContent(context, l10n),
      data: (members) => _buildContent(context, members, l10n),
    );
  }

  /// 加载态:展示骨架"所有者(我)"行 + AA 开关 + 邀请入口占位。
  Widget _buildLoadingMemberCard(
    BuildContext context,
    AppLocalizations l10n, {
    required List<SpitoutCloudLedgerMember> members,
  }) {
    return _buildContent(context, members, l10n);
  }

  /// 无 syncId 模式(新建态/本地账本)的成员卡片内容。
  ///
  /// 成员列表只展示"所有者(我)"一行,邀请新成员入口禁用并提示
  /// "请先保存账本"(邀请码生成需要云端账本已存在)。
  /// AA 开关 + 虚拟用户列表正常工作(新建态虚拟用户内存暂存)。
  Widget _buildNoSyncIdContent(BuildContext context, AppLocalizations l10n) {
    return _buildContent(context, const <SpitoutCloudLedgerMember>[], l10n);
  }

  /// 成员列表 + 虚拟用户列表 + AA 开关 + (Owner)邀请模块。
  ///
  /// 布局:SectionCard 内按顺序排列——
  /// 1. 真实成员行(所有者 / 协作者)
  /// 2. 虚拟用户行(可改名 / 可删除,AA 开启时显示)
  /// 3. AA 分摊开关(SwitchListTile)
  /// 4. 邀请新成员模块(仅 Owner 且有 syncId 时显示)
  Widget _buildContent(
    BuildContext context,
    List<SpitoutCloudLedgerMember> members,
    AppLocalizations l10n,
  ) {
    final me = members.where((m) => m.isSelf).firstOrNull;
    final amOwner = me?.role == 'owner' || _isNoSyncIdMode;

    // 新建态/本地账本:从推导的用户信息构造"所有者(我)"行。
    final effectiveMembers = _isNoSyncIdMode && members.isEmpty
        ? _buildOwnerAsMember()
        : members;

    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // —— 真实成员行 ——
          for (final m in effectiveMembers) ...[
            _MemberTile(
              member: m,
              amOwner: amOwner,
              onRemove: amOwner && !m.isSelf
                  ? () => _confirmRemove(context, m, l10n)
                  : null,
            ),
            if (m != effectiveMembers.last) const Divider(height: 1),
          ],

          // —— 虚拟用户行(AA 开启时显示) ——
          if (widget.aaEnabled) ..._buildVirtualUserRows(context, l10n, effectiveMembers),

          // —— AA 分摊开关 ——
          if (effectiveMembers.isNotEmpty) const Divider(height: 1),
          _buildAaSwitch(context, l10n),

          // —— 邀请新成员模块(仅 Owner 常驻显示) ——
          if (amOwner) ...[
            const Divider(height: 1),
            if (_isNoSyncIdMode)
              _buildSaveFirstInviteTile(context, l10n)
            else
              _buildInviteSection(context, l10n),
          ],
        ],
      ),
    );
  }

  /// 新建态/本地账本:构造"所有者(我)"行作为唯一成员。
  ///
  /// 从 [_ownerDisplayName]/[_ownerEmail] 推导;加载中或失败时兜底"我"。
  List<SpitoutCloudLedgerMember> _buildOwnerAsMember() {
    final name = _ownerDisplayName?.isNotEmpty == true
        ? _ownerDisplayName!
        : (_ownerEmail ?? AppLocalizations.of(context).sharedMembersYou);
    return [
      SpitoutCloudLedgerMember(
        userId: '',
        email: _ownerEmail ?? '',
        displayName: name,
        role: 'owner',
        joinedAt: DateTime.now().toUtc(),
        isSelf: true,
      ),
    ];
  }

  /// 虚拟用户行列表(AA 开启时在真实成员行下方展示)。
  ///
  /// 编辑态从 [ledgerVirtualUsersProvider] 拉取;新建态从父组件内存暂存列表拉取。
  /// 每行:头像(person 图标)+ 可编辑名称 + 移除 icon(复用协作者移除逻辑)。
  List<Widget> _buildVirtualUserRows(
    BuildContext context,
    AppLocalizations l10n,
    List<SpitoutCloudLedgerMember> realMembers,
  ) {
    final rows = <Widget>[];

    // 编辑态:从 Stream 拉取已落库虚拟用户。
    final List<LedgerVirtualUser> existingUsers = !_isCreatingMode
        ? (ref.watch(ledgerVirtualUsersProvider(widget.ledgerId!)).valueOrNull ??
            const <LedgerVirtualUser>[])
        : const <LedgerVirtualUser>[];

    // 首个虚拟用户行前加分隔线(与真实成员行分隔)。
    bool needsLeadingDivider = realMembers.isNotEmpty;

    // —— 已落库虚拟用户行(编辑态) ——
    for (var i = 0; i < existingUsers.length; i++) {
      if (needsLeadingDivider || i > 0) {
        rows.add(const Divider(height: 1));
      }
      needsLeadingDivider = false;
      rows.add(_VirtualUserTile(
        name: existingUsers[i].name,
        isReadOnly: widget.isReadOnly,
        onRename: (newName) => _renameVirtualUser(
          existingId: existingUsers[i].id,
          pendingIndex: -1,
          newName: newName,
        ),
        onDelete: () => _deleteVirtualUser(
          existingId: existingUsers[i].id,
          pendingIndex: -1,
        ),
      ));
    }

    // —— 内存暂存虚拟用户行(新建态) ——
    final pending = widget.pendingVirtualUsers;
    for (var i = 0; i < pending.length; i++) {
      if (needsLeadingDivider || i > 0) {
        rows.add(const Divider(height: 1));
      }
      needsLeadingDivider = false;
      rows.add(_VirtualUserTile(
        name: pending[i].name,
        isReadOnly: widget.isReadOnly,
        onRename: (newName) => _renameVirtualUser(
          existingId: null,
          pendingIndex: i,
          newName: newName,
        ),
        onDelete: () => _deleteVirtualUser(
          existingId: null,
          pendingIndex: i,
        ),
      ));
    }

    return rows;
  }

  /// AA 分摊开关行(SwitchListTile)。
  ///
  /// 作为成员管理模块内部的一个开关,跟随开关立即显示/隐藏虚拟用户列表,
  /// 不依赖保存按钮(开关状态在父组件持有,保存时一并落库)。
  Widget _buildAaSwitch(BuildContext context, AppLocalizations l10n) {
    final readOnlyColor =
        widget.isReadOnly ? Theme.of(context).disabledColor : null;
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        l10n.ledgerAaEnabled,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: readOnlyColor),
      ),
      subtitle: Text(
        l10n.ledgerAaEnabledHint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: SpitoutTokens.textTertiary(context),
            ),
      ),
      value: widget.aaEnabled,
      // 协作者只读:禁用开关(onChanged=null 灰化)
      onChanged: widget.isReadOnly
          ? null
          : (v) => widget.onAaChanged(v),
    );
  }

  /// 新建态/本地账本(无 syncId)的邀请入口占位行。
  ///
  /// 邀请码生成依赖云端账本 ID,新建态账本未保存、本地账本未上云,
  /// 无法真正生成邀请码,因此常驻显示入口但点击时提示先保存账本。
  Widget _buildSaveFirstInviteTile(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(AppIcons.personAdd, size: 18, color: primary),
      title: Text(
        l10n.sharedMembersInviteCta,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      trailing: Icon(
        AppIcons.chevronRight,
        size: 16,
        color: SpitoutTokens.iconTertiary(context),
      ),
      onTap: () => showToast(context, l10n.sharedMembersSaveFirst),
    );
  }

  /// 内嵌邀请模块 — 默认收起只显示标题(personAdd + 「邀请新成员」),
  /// 点击标题展开内容,按状态切换:未生成时展示表单,已生成时展示邀请码分享视图。
  Widget _buildInviteSection(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
    return Theme(
      // 去掉 ExpansionTile 默认的上下分割线,贴合 SectionCard 风格
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 16, bottom: 4, left: 16, right: 16),
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
        ledgerId: widget.ledgerExternalId!,
        userId: target.userId,
      );
      if (context.mounted) showToast(context, l10n.sharedMembersRemoved);
    } catch (e) {
      if (context.mounted) showToast(context, e.toString());
    }
  }
}

/// 单个真实成员行:头像 + 名称 + (自己) + 移除按钮 + 角色标签。
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
    // 成员未设昵称时展示完整邮箱,便于识别账号身份
    final displayName = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : member.email;
    final isOwner = member.role == 'owner';
    // 邮箱为空时(新建态推导的 owner)不展示 subtitle。
    final hasEmail = member.email.isNotEmpty;
    return ListTile(
      dense: true,
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
      subtitle: hasEmail
          ? Text(
              member.email,
              style: TextStyle(
                  color: SpitoutTokens.textSecondary(context), fontSize: 12),
            )
          : null,
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

/// 单个虚拟用户行:头像(person 图标)+ 可编辑名称 + 移除 icon。
///
/// 复用协作者移除逻辑(personRemove icon);名称行内编辑,不弹窗。
class _VirtualUserTile extends StatelessWidget {
  const _VirtualUserTile({
    required this.name,
    required this.isReadOnly,
    required this.onRename,
    required this.onDelete,
  });

  /// 当前虚拟用户名称。
  final String name;

  /// 协作者只读:禁用名称编辑和删除。
  final bool isReadOnly;

  /// 重命名回调(行内编辑完成时触发)。
  final ValueChanged<String> onRename;

  /// 删除回调。
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 行内编辑控制器:初始值为当前名称,失焦或回车时触发重命名。
    final controller = TextEditingController(text: name);
    // 标记是否已触发回调,避免失焦时重复触发(失焦 + dispose 两次)。
    var committed = false;
    void commit() {
      if (committed) return;
      committed = true;
      final newText = controller.text.trim();
      if (newText.isNotEmpty && newText != name) {
        onRename(newText);
      }
    }

    return ListTile(
      dense: true,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: SpitoutTokens.surfaceSecondary(context),
          shape: BoxShape.circle,
        ),
        child: Icon(
          AppIcons.person,
          size: 18,
          color: SpitoutTokens.iconSecondary(context),
        ),
      ),
      title: TextField(
        controller: controller,
        readOnly: isReadOnly,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: l10n.aaVirtualUserNameHint,
        ),
        style: TextStyle(
          fontSize: 15,
          color: SpitoutTokens.textPrimary(context),
        ),
        // 失焦时提交重命名(避免每次按键都写库)。
        onTapOutside: (_) {
          FocusScope.of(context).unfocus();
          commit();
        },
        onSubmitted: (_) => commit(),
      ),
      trailing: IconButton(
        icon: const Icon(AppIcons.personRemove, size: 20),
        tooltip: l10n.commonDelete,
        onPressed: isReadOnly ? null : onDelete,
        style: IconButton.styleFrom(
          foregroundColor: SpitoutTokens.error(context),
        ),
      ),
    );
  }
}
