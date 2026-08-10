import 'package:flutter/material.dart';
import 'package:spitout/providers/providers.dart' show SpitoutCloudLedgerMember;
import 'package:spitout/l10n/app_localizations.dart';
import 'person_avatar.dart';

/// 协作头像「单个槽位」：无头像、加载中或加载失败统一回退 [PersonAvatar] 占位。
///
/// URL 拼接去掉 baseUrl 尾部多余斜杠避免双斜杠。
class CollaboratorAvatarSlot extends StatelessWidget {
  final SpitoutCloudLedgerMember? member;
  final String baseUrl;
  final double radius;

  const CollaboratorAvatarSlot({
    super.key,
    required this.member,
    required this.baseUrl,
    this.radius = 11,
  });

  /// 解析成员真实头像完整 URL：相对路径拼 baseUrl（去掉尾部斜杠），
  /// 已含 http(s) 的绝对路径直用。
  String? get _resolvedUrl {
    final raw = member?.avatarUrl;
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = baseUrl.trim();
    if (base.isEmpty) return null;
    final trimmedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmedBase$raw';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedUrl;
    final scheme = Theme.of(context).colorScheme;
    // 圆形底色用不透明主色 primary，不透明避免重叠时透出下层。
    final bg = scheme.primary;

    // 无头像:直接展示虚拟用户同等 person 图标,不用昵称首字母兜底,
    // 保证所有未设置头像的占位样式全局一致。
    if (resolved == null) {
      return PersonAvatar(size: radius * 2);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      // 有头像时用 ClipOval 显式裁圆;加载中 / 加载失败回退到 person 图标。
      child: ClipOval(
        child: Image.network(
          resolved,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // 加载中先显示 person 图标，网络慢时不闪空白
          loadingBuilder: (ctx, child, progress) =>
              progress == null ? child : PersonAvatar(size: radius * 2),
          // 加载失败兜底 person 图标
          errorBuilder: (ctx, error, stack) =>
              PersonAvatar(size: radius * 2),
        ),
      ),
    );
  }
}

/// 协作头像「组」：展示创建人 / 编辑人，最多两个重叠头像。
///
/// - 两者 userId 都为空 → 不展示。
/// - 同一人 → 1 个头像 + Tooltip「X 创建并编辑」。
/// - 不同人 → 2 个重叠头像（编辑人左移叠放在创建人之上）+ 分别 Tooltip。
class CollaboratorAvatarGroup extends StatelessWidget {
  final SpitoutCloudLedgerMember? creator;
  final SpitoutCloudLedgerMember? editor;
  final String? creatorUserId;
  final String? editorUserId;
    final String baseUrl;
    final double radius;
    final bool membersLoading;

    const CollaboratorAvatarGroup({
      super.key,
      required this.creator,
      required this.editor,
      required this.creatorUserId,
      required this.editorUserId,
      required this.baseUrl,
      this.radius = 11,
      this.membersLoading = false,
    });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 成员表尚未加载:统一显示 PersonAvatar 占位(数量与最终一致),
    // 数据到位后再切换真实头像。
    if (membersLoading) {
      if (creatorUserId == null && editorUserId == null) {
        return const SizedBox.shrink();
      }
      final samePerson = creatorUserId == editorUserId;
      final overlap = radius * 0.32;
      final placeholder = CollaboratorAvatarSlot(
        member: null,
        baseUrl: baseUrl,
        radius: radius,
      );
      if (!samePerson) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            placeholder,
            Transform.translate(
              offset: Offset(-overlap, 0),
              child: placeholder,
            ),
          ],
        );
      }
      return placeholder;
    }

    // 两者 userId 都为空（如历史数据无协作字段）→ 不展示
    if (creatorUserId == null && editorUserId == null) {
      return const SizedBox.shrink();
    }

    final samePerson = creatorUserId == editorUserId;

    final creatorName = creator?.displayName ?? creator?.account ?? creatorUserId ?? '';
    final editorName = editor?.displayName ?? editor?.account ?? editorUserId ?? '';

    // 同一人 → 1 个头像
    if (samePerson) {
      return Tooltip(
        message: l10n.sharedTxCreatedAndEditedBy(creatorName),
        child: CollaboratorAvatarSlot(
          member: creator,
          baseUrl: baseUrl,
          radius: radius,
        ),
      );
    }

    // 两人 → 2 个重叠头像（编辑者左移叠放在创建者之上）
    final overlap = radius * 0.32;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: l10n.sharedTxCreatedBy(creatorName),
          child: CollaboratorAvatarSlot(
            member: creator,
            baseUrl: baseUrl,
            radius: radius,
          ),
        ),
        Transform.translate(
          offset: Offset(-overlap, 0),
          child: Tooltip(
            message: l10n.sharedTxEditedBy(editorName),
            child: CollaboratorAvatarSlot(
              member: editor,
              baseUrl: baseUrl,
              radius: radius,
            ),
          ),
        ),
      ],
    );
  }
}
