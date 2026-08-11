import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';

import 'package:spitout/services/storage/avatar_picker.dart';
import 'package:spitout/core/storage/avatar_storage.dart';
import 'package:spitout/core/storage/member_avatar_storage.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';

/// 头像刷新触发器
final avatarRefreshProvider =
    NotifierProvider<TickStateNotifier, int>(() => TickStateNotifier((ref) => 0));

/// 用户头像路径
final avatarPathProvider = FutureProvider<String?>((ref) async {
  ref.watch(avatarRefreshProvider);
  return avatarStorage.getAvatarPath();
});

/// 从系统相册选择并保存头像（动作函数）。
///
/// 设计意图：把 `avatarPicker.pickAndSaveAvatar` 的调用收敛到 providers 层，
/// widgets 层不直接 import services/storage/*，保持
/// `pages/widgets → providers → services → data` 单向依赖。
Future<String?> pickAndSaveAvatarFromUi(WidgetRef ref) =>
    avatarPicker.pickAndSaveAvatar();

/// 成员头像缓存请求键：userId + 服务端版本号 + 是否有头像 URL。
typedef MemberAvatarKey = ({String userId, int version, bool hasAvatar});

/// 成员头像本地路径 provider（按 userId + 版本键控）。
///
/// 命中本地缓存（版本一致）直接返回；未命中且成员有头像时经
/// `downloadMyAvatar` 拉取并落盘；无头像/下载失败返回 null，UI 显示占位。
/// 版本号参与 key，服务端头像更新后自动重下，无需额外失效事件。
final memberAvatarPathProvider =
    FutureProvider.family<String?, MemberAvatarKey>((ref, key) async {
      final cached = await memberAvatarStorage.getPath(
        userId: key.userId,
        version: key.version,
      );
      if (cached != null) return cached;

      if (!key.hasAvatar) {
        // 服务端已无头像：顺手清掉本地残留缓存，避免下次又被旧文件命中。
        await memberAvatarStorage.remove(key.userId);
        return null;
      }

      try {
        final cloud = await ref.read(spitoutCloudProviderInstance.future);
        if (cloud == null) return null;
        final bytes = await cloud.downloadMyAvatar(
          userId: key.userId,
          version: key.version > 0 ? key.version : null,
        );
        if (bytes.isEmpty) return null;
        return await memberAvatarStorage.save(
          userId: key.userId,
          version: key.version,
          bytes: bytes,
        );
      } catch (e, st) {
        logger.warning(
          'AvatarCache',
          '成员头像下载失败 userId=${key.userId}: $e',
          st,
        );
        return null;
      }
    });

/// 删除本地头像（动作函数）。
///
/// 注意：只负责清理本地缓存文件，不触达云端；「先删云端再删本地」的顺序
/// 编排仍由 UI 层负责（防止服务端头像被周期 pull 回灌）。
Future<void> deleteAvatarFromUi(WidgetRef ref) => avatarStorage.deleteAvatar();

/// 记录服务端头像版本号到本地（动作函数）。
///
/// 上传成功后调用，避免下一次 bootstrap 再次下载自己刚传的头像。
Future<void> setStoredAvatarRemoteVersion(WidgetRef ref, int version) =>
    avatarStorage.setStoredRemoteVersion(version);
