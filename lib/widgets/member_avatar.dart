import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/providers/ui/avatar_providers.dart'
    show memberAvatarPathProvider;
import 'person_avatar.dart';

/// 成员头像（按 userId + 版本本地缓存，离线可显示）。
///
/// 设计意图：成员头像不再直连 `Image.network`，改为磁盘缓存优先；缓存未命中
/// 时由 [memberAvatarPathProvider] 后台下载，加载中/失败统一回退
/// [PersonAvatar] 占位，避免断网时每次重建都闪占位或反复重拉。
class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({
    super.key,
    required this.userId,
    required this.version,
    required this.hasAvatar,
    required this.size,
    this.iconSize,
  });

  /// 成员 userId；为空/虚拟用户时直接占位。
  final String? userId;

  /// 服务端头像版本号（0 = 未知，仍按 URL 存在尝试下载）。
  final int version;

  /// 服务端是否返回了头像 URL。
  final bool hasAvatar;

  /// 圆形直径。
  final double size;

  /// person 占位图标大小，默认取直径 45%。
  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      return PersonAvatar(size: size, iconSize: iconSize);
    }

    final path = ref
        .watch(
          memberAvatarPathProvider((
            userId: uid,
            version: version,
            hasAvatar: hasAvatar,
          )),
        )
        .value;
    if (path == null || path.isEmpty) {
      return PersonAvatar(size: size, iconSize: iconSize);
    }

    return ClipOval(
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            PersonAvatar(size: size, iconSize: iconSize),
      ),
    );
  }
}
