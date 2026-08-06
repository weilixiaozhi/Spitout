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
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spitout/cloud/sync/sync_events.dart' show PushCompleted;
import 'package:spitout/cloud/spitout_cloud.dart' show CloudStorageException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import 'text_state_switch.dart';
import 'me_suffix.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart'
    show spitoutCloudProviderInstance, syncEventStreamProvider;
import 'package:spitout/providers/ui/theme_providers.dart' show displayNameProvider;
import 'package:spitout/providers/ui/avatar_providers.dart';
import 'package:spitout/providers/statistics/aa_statistics_providers.dart'
    show
        ledgerVirtualUsersProvider,
        createVirtualUser,
        renameVirtualUser,
        deleteVirtualUser;
import '../data/models.dart' show LedgerVirtualUser;
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'app_dialog.dart';
import 'person_avatar.dart';
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
    required this.showInviteEntry,
    this.onInviteWithoutSyncId,
  });

  /// Server external_id(本地 syncId);null/空 = 新建态或本地账本。
  ///
  /// 为空时本模块展示"所有者(我)"作为唯一成员;[showInviteEntry] 控制
  /// 是否展示"邀请新成员"入口(本地账本不展示,新建态展示自动保存流程)。
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

  /// 是否展示"邀请新成员"入口。
  ///
  /// - 新建态:展示(点击自动保存账本拿 syncId 后进入正式邀请);
  /// - 云端账本(有 syncId):展示;
  /// - 本地账本(已存在、storageMode=local):不展示(本地账本不支持协作邀请,
  ///   点击会因同步层不会创建 syncId 而陷入永久 loading)。
  final bool showInviteEntry;

  /// 无 syncId 时点击"邀请新成员"的回调:由父组件自动保存/同步拿 syncId,
  /// 期间本模块展示 loading,不拦截;成功后随 syncId 更新自动进入正式邀请。
  final Future<void> Function()? onInviteWithoutSyncId;

  @override
  ConsumerState<MemberManagementSection> createState() =>
      _MemberManagementSectionState();
}

class _MemberManagementSectionState
    extends ConsumerState<MemberManagementSection> {
  // 邀请码有效期选项:1d / 3d / 7d
  static const _expiryOptions = <int>[24, 72, 168];

  /// 邀请模块本地状态 — 有效期 / 已生成的邀请码 / 生成中 / 错误信息 / 展开态。
  int _expiresInHours = 24;
  SpitoutCloudInvite? _generated;
  bool _busy = false;
  String? _error;
  /// 邀请模块是否展开:用于切换收起/展开箭头(收起朝右、展开朝下)。
  bool _inviteExpanded = false;

  /// 新建态下推导的当前用户信息(异步加载,用于展示"所有者(我)")。
  String? _ownerDisplayName;
  String? _ownerAccount;

  /// 无 syncId 时点击邀请入口,父组件正在保存/同步拿 syncId 的等待态。
  bool _inviteBusy = false;

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
        // CloudUser 仅有 id/account,显示名以本地 displayNameProvider 为准;
        // 兜底回退到 account,account 也没有时由渲染层兜底"我"。
        final localName = ref.read(displayNameProvider);
        _ownerDisplayName =
            localName.trim().isNotEmpty ? localName : me?.account;
        _ownerAccount = me?.account;
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
  ///
  /// 分享视图只展示"创建响应"生成的邀请,该响应按新协议必带 shareUrl;
  /// 列表响应只含掩码、不会进入此路径。仍做空值守卫：后端协议若变化返回
  /// null，降级为「邀请暂不可用」提示，不在 UI 层空断言崩溃。
  Future<void> _share(SpitoutCloudInvite invite, AppLocalizations l10n) async {
    final url = invite.shareUrl;
    if (url == null || url.isEmpty) {
      if (mounted) showToast(context, l10n.sharedInviteUnavailable);
      return;
    }
    final message = l10n.sharedInviteShareText(
      widget.ledgerName,
      invite.formattedCode,
      url,
    );
    await SharePlus.instance.share(ShareParams(text: message));
  }

  /// 复制邀请码；后端返回缺失时降级为友好提示，不做非空断言。
  void _copyInviteCode(SpitoutCloudInvite invite, AppLocalizations l10n) {
    final code = invite.code;
    if (code == null || code.isEmpty) {
      if (mounted) showToast(context, l10n.sharedInviteUnavailable);
      return;
    }
    _copy(code, l10n);
  }

  /// 复制邀请短链；后端返回缺失时降级为友好提示，不做非空断言。
  void _copyInviteLink(SpitoutCloudInvite invite, AppLocalizations l10n) {
    final url = invite.shareUrl;
    if (url == null || url.isEmpty) {
      if (mounted) showToast(context, l10n.sharedInviteUnavailable);
      return;
    }
    _copy(url, l10n);
  }

  /// 把移除成员失败映射为本地化提示，避免把内部异常文本（URL / 堆栈）直接
  /// 展示给用户：网络类 → 网络文案；权限类 → 权限文案；其余 → 通用失败文案。
  String _removeMemberFailureMessage(Object e, AppLocalizations l10n) {
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') ||
        s.contains('timeoutexception') ||
        s.contains('clientexception') ||
        s.contains('network') ||
        s.contains('连接') ||
        s.contains('网络')) {
      return l10n.authErrorNetworkIssue;
    }
    if (s.contains('403') ||
        s.contains('denied') ||
        s.contains('permission') ||
        s.contains('forbidden') ||
        s.contains('无权') ||
        s.contains('权限')) {
      return l10n.cloudErrorAccessDenied;
    }
    return l10n.sharedMembersRemoveFailed;
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
                .value ??
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
        // 标题行(色条 + "成员管理" + AA 分摊开关 + "添加虚拟用户"文字链)
        _buildHeader(context, l10n),
        const SizedBox(height: 8),
        _buildCardContent(context, l10n),
      ],
    );
  }

  /// 模块标题行:左侧色条 + "成员管理",右侧 AA 分摊开关(内部带状态文案),
  /// AA 开启后追加"添加虚拟用户"文字链。
  ///
  /// 标题行使用固定高度 44:开关(25)、色条与按钮高度各不相同,
  /// 固定高度 + 垂直居中可以保证标题行不随内容变化上下跳动;
  /// 开关状态在父组件持有,跟随开关立即显示/隐藏虚拟用户列表与
  /// "添加虚拟用户"入口。
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: primary,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        // 固定标题行高度:让开关/色条/按钮垂直居中,防止模块上下移动
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
            Text(l10n.sharedMembersPageTitle, style: titleStyle),
            const SizedBox(width: 12),
            // AA 分摊开关:状态文案内嵌在开关内部(开启/关闭文案不同),
            // 尺寸 100x30,宽度可容纳状态文案,高度与标题行紧凑对齐
            TextStateSwitch(
              width: 100,
              height: 30,
              value: widget.aaEnabled,
              // 协作者只读:禁用开关(onChanged=null 灰化)
              onChanged: widget.isReadOnly
                  ? null
                  : (v) => widget.onAaChanged(v),
              onLabel: l10n.aaSwitchOnLabel,
              offLabel: l10n.aaSwitchOffLabel,
            ),
            const Spacer(),
            if (widget.aaEnabled && !widget.isReadOnly)
              TextButton.icon(
                onPressed: _addVirtualUser,
                icon: const Icon(AppIcons.personAdd, size: 14),
                label: Text(l10n.aaAddVirtualUser,
                    style: Theme.of(context).textTheme.labelSmall),
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
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
      final event = next.value;
      if (event is PushCompleted &&
          event.ledgerId == widget.ledgerExternalId) {
        ref.invalidate(ledgerMembersProvider(widget.ledgerExternalId!));
      }
    });

    return membersAsync.when(
      loading: () => _buildLoadingMemberCard(context, l10n),
      // 错误分类:
      //  - 404(云端账本刚 moveToCloud,首次 push 未完成,listMembers 抛
      //    "Ledger not found"):属暂时性状态,PushCompleted 事件会自动
      //    invalidate 重拉,展示加载骨架 + 提示文案,不报错。
      //  - 其余真实错误(网络/权限/5xx 等):展示错误卡片 + 重试按钮,
      //    避免永久 loading 让用户得不到反馈。
      error: (e, _) {
        if (e is CloudStorageException && e.statusCode == 404) {
          return _buildLoadingMemberCard(context, l10n);
        }
        return _buildErrorCard(context, l10n, error: e);
      },
      data: (members) => _buildContent(context, members, l10n),
    );
  }

  /// 加载态:展示骨架行(头像 + 文本占位条)+ AA 开关区域占位。
  ///
  /// 显式渲染骨架而非空成员列表,让加载态可见;404 error 路径(云端账本
  /// 尚未就绪)也复用此骨架,顶部加一行提示文案,让用户知道是"等云端创建中"
  /// 而非"加载卡死"。
  Widget _buildLoadingMemberCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // 云端账本尚未就绪提示(404 场景下让用户知道在等云端创建)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.sharedMembersLoadingHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 骨架行:头像占位 + 标题占位条
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: placeholderColor,
            ),
            title: _SkeletonBar(
                width: 120, height: 12, color: placeholderColor),
          ),
        ],
      ),
    );
  }

  /// 真实错误态:展示错误文案 + 重试按钮,点击重试 invalidate provider 重拉。
  ///
  /// 不再无条件转 loading:网络失败/权限错误等永久 loading 会让用户得不到
  /// 任何反馈,违反错误处理原则。此处展示具体错误 + 重试入口,
  /// 让用户主动决策是否重试。
  Widget _buildErrorCard(
    BuildContext context,
    AppLocalizations l10n, {
    required Object error,
  }) {
    final theme = Theme.of(context);
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(AppIcons.error,
                size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.sharedMembersLoadFailed,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(
                  ledgerMembersProvider(widget.ledgerExternalId!)),
              child: Text(l10n.sharedMembersRetry),
            ),
          ],
        ),
      ),
    );
  }

  /// 无 syncId 模式(新建态/本地账本)的成员卡片内容。
  ///
  /// 成员列表只展示"所有者(我)"一行,邀请新成员入口禁用并提示
  /// "请先保存账本"(邀请码生成需要云端账本已存在)。
  /// AA 开关 + 虚拟用户列表正常工作(新建态虚拟用户内存暂存)。
  Widget _buildNoSyncIdContent(BuildContext context, AppLocalizations l10n) {
    return _buildContent(context, const <SpitoutCloudLedgerMember>[], l10n);
  }

  /// 成员列表 + 虚拟用户列表 + (Owner)邀请模块。
  ///
  /// 布局:SectionCard 内按顺序排列——
  /// 1. 真实成员行(所有者 / 协作者)
  /// 2. 虚拟用户行(可改名 / 可删除,AA 开启时显示)
  /// 3. 邀请新成员模块(仅 Owner 且 [showInviteEntry] 为 true 时显示)
  ///
  /// AA 分摊开关已移至模块标题行(_buildHeader),不再占用卡片内空间。
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

          // —— 邀请新成员模块(仅 Owner 且允许展示时显示) ——
          // 本地账本(已存在、storageMode=local)不支持协作邀请,
          // [showInviteEntry] 为 false 时不渲染入口,避免点击后永久 loading。
          if (amOwner && widget.showInviteEntry) ...[
            if (effectiveMembers.isNotEmpty) const Divider(height: 1),
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
  /// 从 [_ownerDisplayName]/[_ownerAccount] 推导;仅在确有显示名时设置
  /// displayName,否则留空交给 _MemberTile 统一处理占位:
  /// - 有 account:标题回退到 account,保证可读性;
/// - 无 account:标题展示「未设置昵称」占位,头像位展示 person 图标,
///   不再回退"你",避免头像/昵称/括号三处重复展示。
  List<SpitoutCloudLedgerMember> _buildOwnerAsMember() {
    final hasName = _ownerDisplayName?.isNotEmpty == true;
    final account = _ownerAccount ?? '';
    return [
      SpitoutCloudLedgerMember(
        userId: '',
        account: account,
        displayName: hasName ? _ownerDisplayName : null,
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
        ? (ref.watch(ledgerVirtualUsersProvider(widget.ledgerId!)).value ??
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

  /// 新建态/本地账本(无 syncId)的邀请入口占位行。
  ///
  /// 邀请码生成依赖云端账本 ID,无 syncId 时无法直接生成,因此点击不拦截:
  /// 由父组件自动保存账本 + 触发同步上云,等待云端账本创建完成拿到 syncId
  /// 后本模块自动切换为正式邀请表单;等待期间展示 loading。
  Widget _buildSaveFirstInviteTile(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
    final busy = _inviteBusy;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(AppIcons.personAdd, size: 18, color: primary),
      title: Text(
        l10n.sharedMembersInviteCta,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              AppIcons.chevronRight,
              size: 16,
              color: SpitoutTokens.iconTertiary(context),
            ),
      onTap: busy ? null : () => _handleInviteWithoutSyncId(context),
    );
  }

  /// 无 syncId 时点击邀请入口:调父组件完成「保存/同步拿 syncId」,
  /// 期间展示 loading;成功后父组件更新 syncId,本模块自动重建为正式邀请表单。
  Future<void> _handleInviteWithoutSyncId(BuildContext context) async {
    // async gap 前一次性取好 l10n,避免 await 后用 context 取导致 lint 告警。
    final l10n = AppLocalizations.of(context);
    final onInvite = widget.onInviteWithoutSyncId;
    if (onInvite == null) {
      // 防御性兜底:父组件未注入回调时提示先保存账本。
      showToast(context, l10n.sharedMembersSaveFirst);
      return;
    }
    setState(() => _inviteBusy = true);
    try {
      await onInvite();
    } catch (e) {
      if (context.mounted) {
        showToast(context, l10n.sharedMembersInviteSyncFailed);
      }
    } finally {
      // setState 属于 State,用 State 的 mounted 守卫。
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  /// 内嵌邀请模块 — 默认收起只显示标题(personAdd + 「邀请新成员」),
  /// 点击标题展开内容,按状态切换:未生成时展示表单,已生成时展示邀请码分享视图。
  ///
  /// 箭头规则统一:收起时朝右(chevronRight)、展开时朝下(chevronDown),
  /// 替代 ExpansionTile 默认的「下/上」翻转,消除多指向歧义。
  Widget _buildInviteSection(BuildContext context, AppLocalizations l10n) {
    final primary = Theme.of(context).colorScheme.primary;
    return Theme(
      // 去掉 ExpansionTile 默认的上下分割线,贴合 SectionCard 风格
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: _inviteExpanded,
        onExpansionChanged: (v) => setState(() => _inviteExpanded = v),
        tilePadding: EdgeInsets.zero,
        childrenPadding:
            const EdgeInsets.only(top: 16, bottom: 4, left: 16, right: 16),
        leading: Icon(AppIcons.personAdd, size: 18, color: primary),
        title: Text(
          l10n.sharedMembersInviteCta,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        // 收起朝右、展开朝下,指向明确
        trailing: Icon(
          _inviteExpanded ? AppIcons.chevronDown : AppIcons.chevronRight,
          size: 18,
          color: SpitoutTokens.iconTertiary(context),
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
  ///
  /// 仅由创建响应生成并展示（列表接口不返回明文 code / shareUrl）。
  /// 对两个可空字段做空值守卫：后端协议变化时降级为友好提示，不空断言崩溃。
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
        // server 缺 / 坏 expires_at 时隐藏有效期行,不伪造时间展示。
        if (invite.expiresAt != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.sharedInviteExpiresAt(
                invite.expiresAt!.toLocal().toString().split('.').first,
              ),
              style: TextStyle(
                  color: SpitoutTokens.textTertiary(context), fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(AppIcons.copy),
                label: Text(l10n.sharedInviteCopyCode),
                onPressed: () => _copyInviteCode(invite, l10n),
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
          onPressed: () => _copyInviteLink(invite, l10n),
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
            target.displayName ?? target.account)),
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
      if (context.mounted) {
        showToast(context, _removeMemberFailureMessage(e, l10n));
      }
    }
  }
}

/// 单个真实成员行:头像 + 名称 + (自己) + 移除按钮 + 角色标签。
///
/// 只展示一行标题(昵称优先、无昵称回退账号),不再展示账号副标题,
/// 避免与昵称重复占用行高;账号/用户名可从其他入口获取。
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
    // 标题优先用昵称;昵称为空时回退到账号,保证每一行都能看到可读名称。
    final hasDisplayName = member.displayName?.isNotEmpty == true;
    final hasAccount = member.account.isNotEmpty;
    final displayName = hasDisplayName
        ? member.displayName!
        : hasAccount
            ? member.account
            : l10n.mineSlogan;
    final isOwner = member.role == 'owner';
    return ListTile(
      dense: true,
      leading: _MemberAvatar(member: member),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 本人「(我)」后缀统一走共享 MeSuffix,保证各模块样式一致。
          if (member.isSelf) const MeSuffix(),
        ],
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
              // 统一删除 icon 颜色为语义错误色,与虚拟用户删除 icon 一致
              style: IconButton.styleFrom(
                foregroundColor: SpitoutTokens.error(context),
              ),
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

/// 加载骨架占位条 — 用于 [_buildLoadingMemberCard] 中成员行的标题占位。
/// 简单的灰色圆角条,不引入 shimmer 依赖,避免过度设计。
class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// 成员头像 — 本人优先用本地头像文件，其他成员用 server avatar_url 拼 baseUrl；
/// 都没有或加载失败才回退 person 图标。
class _MemberAvatar extends ConsumerWidget {
  const _MemberAvatar({required this.member});

  final SpitoutCloudLedgerMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 本人头像优先走本地文件（离线可用、上传后即时生效），
    // 与「我的页」头像同一数据源。
    if (member.isSelf) {
      final avatarAsync = ref.watch(avatarPathProvider);
      final localPath = avatarAsync.asData?.value;
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
    }

    final relativeUrl = member.avatarUrl;
    if (relativeUrl == null || relativeUrl.isEmpty) {
      // 未配置头像:统一展示虚拟用户同等 person 图标,不再用昵称首字母,
      // 保证所有未设置头像的占位样式全局一致。
      return const PersonAvatar(size: 40, iconSize: 18);
    }
    final cloudAsync = ref.watch(spitoutCloudProviderInstance);
    final cloud = cloudAsync.value;
    final base = cloud?.baseUrl;
    if (base == null || base.isEmpty) {
      return const PersonAvatar(size: 40, iconSize: 18);
    }
    final trimmedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final absoluteUrl =
        relativeUrl.startsWith('http') ? relativeUrl : '$trimmedBase$relativeUrl';
    // 用 Image.network + 圆形裁切：加载中/失败才显示 person 图标，
    // 避免 CircleAvatar 的 child 常驻叠加在头像图片上方。
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

/// 单个虚拟用户行:头像(person 图标)+ 可编辑名称 + 移除 icon。
///
/// 复用协作者移除逻辑(personRemove icon);名称行内编辑,不弹窗。
class _VirtualUserTile extends StatefulWidget {
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
  State<_VirtualUserTile> createState() => _VirtualUserTileState();
}

class _VirtualUserTileState extends State<_VirtualUserTile> {
  /// 行内编辑控制器：由 State 持有并在 dispose 释放。
  ///
  /// 修复点：原先在 build 中每次新建 controller（无 dispose），父组件任何
  /// setState 都会重建并丢掉正在输入但未失焦的内容；改为 State 持有后，
  /// 滚动 / 刷新 / 无关重建都不会打断输入，也不会累积未释放的 controller。
  late final TextEditingController _controller;

  /// 是否已触发重命名回调（防止失焦 + 提交重复触发）；文本再次变化后复位。
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    if (_committed) return;
    _committed = true;
    final newText = _controller.text.trim();
    if (newText.isNotEmpty && newText != widget.name) {
      widget.onRename(newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 自行布局而非用 ListTile:TextField 需限定宽度到「虚拟用户1」左右,
    // ListTile 的 title 会 Expanded 铺满,色块过宽与全局编辑框视觉不一致。
    // 左内边距取 12 与全局 ListTileTheme contentPadding 一致,
    // 保证真实成员行(ListTile)与虚拟用户行(自定义 Row)的头像左缘对齐。
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Container(
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
          const SizedBox(width: 12),
          // 固定宽度,仅容纳短昵称(如「虚拟用户1」),避免色块过宽。
          SizedBox(
            width: 140,
            child: TextField(
              controller: _controller,
              readOnly: widget.isReadOnly,
              // 文本变化后允许再次提交（否则首次提交后 _committed 恒为 true）。
              onChanged: (_) => _committed = false,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.aaVirtualUserNameHint,
                hintStyle: TextStyle(
                  color: SpitoutTokens.textTertiary(context),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                // 与全局编辑框一致的色块样式(filled 背景 + 无描边圆角)
                filled: true,
                fillColor: SpitoutTokens.surfaceInput(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: SpitoutTokens.textPrimary(context),
              ),
              // 失焦时提交重命名(避免每次按键都写库)。
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
                _commit();
              },
              onSubmitted: (_) => _commit(),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(AppIcons.personRemove, size: 20),
            tooltip: l10n.commonDelete,
            onPressed: widget.isReadOnly ? null : widget.onDelete,
            style: IconButton.styleFrom(
              foregroundColor: SpitoutTokens.error(context),
            ),
          ),
        ],
      ),
    );
  }
}
