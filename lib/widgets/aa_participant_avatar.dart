import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/statistics/aa_statistics_providers.dart'
    show aaParticipantAvatarContextProvider;
import '../providers/ui/avatar_providers.dart' show avatarPathProvider;
import 'person_avatar.dart';

/// AA 参与人头像（本人本地头像 → 云端成员头像 → person 占位图标）。
///
/// 分摊统计页成员行、成员账单详情页头部与分摊明细共用，保证同一参与人在
/// 各处的头像样式完全一致（含加载中 / 加载失败回退），不散落各自的头像
/// 拼接逻辑。
class AaParticipantAvatar extends ConsumerWidget {
  /// 所属账本 id（用于查询参与人云端成员头像上下文）。
  final int ledgerId;

  /// 参与人标识（userId 或虚拟用户 syncId）。
  final String participantId;

  /// 是否本人；本人优先展示本地头像，其他参与人只走云端头像。
  final bool isSelf;

  /// 圆形直径。
  final double size;

  const AaParticipantAvatar({
    super.key,
    required this.ledgerId,
    required this.participantId,
    this.isSelf = false,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 本人本地头像（离线可用、上传后即时生效）；非本人不读取本地路径。
    final localPath = isSelf ? ref.watch(avatarPathProvider).value : null;
    if (localPath != null && localPath.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(localPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => PersonAvatar(size: size),
        ),
      );
    }

    // 真实成员云端头像：从参与人头像上下文取成员 + baseUrl 拼完整 URL。
    final ctx = ref.watch(aaParticipantAvatarContextProvider(ledgerId)).value;
    final rawUrl = ctx?.members[participantId]?.avatarUrl;
    if (rawUrl != null && rawUrl.trim().isNotEmpty) {
      final base = ctx?.baseUrl.trim() ?? '';
      // 绝对地址直用；相对地址拼 baseUrl（去掉尾部斜杠避免双斜杠）。
      String? resolved;
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        resolved = rawUrl;
      } else if (base.isNotEmpty) {
        final trimmedBase = base.endsWith('/')
            ? base.substring(0, base.length - 1)
            : base;
        resolved = '$trimmedBase$rawUrl';
      }
      if (resolved != null) {
        return ClipOval(
          child: Image.network(
            resolved,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // 加载中 / 失败统一回退 person 占位，避免闪空白。
            loadingBuilder: (ctx, child, progress) =>
                progress == null ? child : PersonAvatar(size: size),
            errorBuilder: (_, _, _) => PersonAvatar(size: size),
          ),
        );
      }
    }

    // 虚拟用户 / 未配置头像：与全项目无头像占位样式一致。
    return PersonAvatar(size: size, iconSize: size * 0.45);
  }
}
