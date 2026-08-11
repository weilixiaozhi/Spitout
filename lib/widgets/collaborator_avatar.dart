import 'package:flutter/material.dart';
import 'package:spitout/providers/providers.dart' show SpitoutCloudLedgerMember;
import 'package:spitout/l10n/app_localizations.dart';
import 'member_avatar.dart';
import 'person_avatar.dart';

/// 协作头像「单个槽位」：无头像、缓存加载中或失败统一回退 [PersonAvatar] 占位。
///
/// 头像经 [MemberAvatar] 走本地磁盘缓存，不再直连 `Image.network`，
/// 断网时也能显示已缓存过的成员头像。
class CollaboratorAvatarSlot extends StatelessWidget {
  final SpitoutCloudLedgerMember? member;
  final double radius;

  const CollaboratorAvatarSlot({
    super.key,
    required this.member,
    this.radius = 11,
  });

  @override
  Widget build(BuildContext context) {
    final m = member;
    if (m == null) {
      return PersonAvatar(size: radius * 2);
    }
    return MemberAvatar(
      userId: m.userId,
      version: m.avatarVersion,
      hasAvatar: m.avatarUrl != null && m.avatarUrl!.trim().isNotEmpty,
      size: radius * 2,
      iconSize: radius * 2 * 0.45,
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
  final double radius;
  final bool membersLoading;

  const CollaboratorAvatarGroup({
    super.key,
    required this.creator,
    required this.editor,
    required this.creatorUserId,
    required this.editorUserId,
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

    final creatorName =
        creator?.displayName ?? creator?.account ?? creatorUserId ?? '';
    final editorName =
        editor?.displayName ?? editor?.account ?? editorUserId ?? '';

    // 同一人 → 1 个头像
    if (samePerson) {
      return Tooltip(
        message: l10n.sharedTxCreatedAndEditedBy(creatorName),
        child: CollaboratorAvatarSlot(member: creator, radius: radius),
      );
    }

    // 两人 → 2 个重叠头像（编辑者左移叠放在创建者之上）
    final overlap = radius * 0.32;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: l10n.sharedTxCreatedBy(creatorName),
          child: CollaboratorAvatarSlot(member: creator, radius: radius),
        ),
        Transform.translate(
          offset: Offset(-overlap, 0),
          child: Tooltip(
            message: l10n.sharedTxEditedBy(editorName),
            child: CollaboratorAvatarSlot(member: editor, radius: radius),
          ),
        ),
      ],
    );
  }
}
