import 'dart:typed_data';

/// 头像能力端口（纯契约，零实现依赖）。
///
/// 设计意图：
/// - 端口放 `core/storage/`（基础设施契约层），所有上层
///   （services / providers / cloud）都可引用而不违反依赖方向：
///   `core` 是最底层，`data / services / providers / cloud` 单向依赖它。
/// - 拆成两个端口以解耦两类能力：
///   - [AvatarStoragePort]：纯本地存储 —— 路径登记 / 远端版本号 /
///     字节与文件落盘，**不感知 UI 选取**（不 import image_picker）；
///     实现见 `services/storage/avatar_storage.dart`。
///   - [AvatarPickerPort]：系统相册选取（ImagePicker）编排，
///     落盘通过注入的 [AvatarStoragePort] 完成，实现见
///     `services/storage/avatar_picker.dart`。
/// - 各层经实现文件中的单例（avatarStorage / avatarPicker）调用，
///   端口保证「面向契约编程」：测试可注入 mock、未来可替换实现。

/// 头像存储端口（纯存储：路径/版本号/字节落盘）。
abstract class AvatarStoragePort {
  /// 扩展名白名单：仅允许字母/数字，长度 1-10，可带或不带前导点。
  static final RegExp safeExtensionPattern =
      RegExp(r'^\.?[A-Za-z0-9]{1,10}$');

  static bool isValidExtension(String extension) =>
      safeExtensionPattern.hasMatch(extension);

  /// 获取用户头像完整路径；未设置或文件已不存在返回 null。
  Future<String?> getAvatarPath();

  /// 从字节流保存头像（云端下载后落盘）。
  ///
  /// [extension] 指定扩展名（默认 .jpg），仅允许字母/数字（可带或不带
  /// 前导点，如 jpg / .jpg）。空字节或非法扩展名抛 [ArgumentError]，
  /// IO 失败抛异常；成功时返回非 null 的新头像完整路径。
  Future<String?> saveAvatarFromBytes(
    Uint8List bytes, {
    String extension = '.jpg',
  });

  /// 从已选取的源文件复制落盘（ImagePicker 选取后使用）。
  ///
  /// 返回新头像完整路径。源文件不存在/复制失败抛异常，源扩展名不符合
  /// 白名单时抛 [ArgumentError]。
  Future<String?> saveAvatarFromFile(String sourcePath);

  /// 取上一次同步下来的远端头像版本号（未同步过返回 0）。
  Future<int> getStoredRemoteVersion();

  /// 更新本地缓存的远端头像版本号。
  Future<void> setStoredRemoteVersion(int version);

  /// 清掉本地缓存的远端版本号（登出时用，避免换账号复用上次的版本号跳过下载）。
  Future<void> clearStoredRemoteVersion();

  /// 删除本地头像文件与登记（含远端版本号）。
  Future<void> deleteAvatar();
}

/// 头像选取端口（系统相册选取 + 落盘编排）。
abstract class AvatarPickerPort {
  /// 从系统相册选择图片并落盘为新头像。
  ///
  /// 返回新头像完整路径；用户取消选择返回 null。
  Future<String?> pickAndSaveAvatar();
}
