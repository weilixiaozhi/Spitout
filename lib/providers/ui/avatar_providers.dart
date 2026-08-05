import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';

import '../../services/storage/avatar_picker.dart';
import '../../services/storage/avatar_storage.dart';

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
