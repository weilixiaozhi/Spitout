import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_service.dart';
import '../../core/storage/avatar_ports.dart';

/// 头像本地存储实现（纯存储，不感知 UI 选取）。
///
/// 设计意图：
/// - 只负责路径登记（SharedPreferences 存相对路径，规避 iOS 应用更新后
///   UUID 变化）、远端版本号管理、字节/文件落盘到 Documents/avatars/ 目录。
/// - 不 import image_picker —— 选取职责归 avatar_picker.dart，
///   本类只做「拿到内容后怎么放」的纯存储编排。
/// - 实现 `core/storage/avatar_ports.dart` 的 [AvatarStoragePort]，
///   供 providers / cloud 层面向契约调用（测试可注入 mock）。
/// - 错误处理：文件 IO 全程 try-catch；`getAvatarPath` 读取失败返回 null
///   （UI 语义「无头像」），写入/删除失败记录日志后 rethrow 交由上层处理。
class LocalAvatarStorage implements AvatarStoragePort {
  static const String _avatarPathKey = 'user_avatar_path';
  // 服务端的 avatar_version —— sync 时拿来和新拉到的 version 对比，
  // 相同就跳过下载。
  static const String _avatarRemoteVersionKey = 'user_avatar_remote_version';
  /// 文档目录下的头像子目录名。
  static const String _avatarDirName = 'avatars';

  @override
  Future<String?> getAvatarPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final relativePath = prefs.getString(_avatarPathKey);
      if (relativePath == null) return null;

      // 存储的是相对路径，读取时动态拼接 Documents 目录，
      // 这样即使 iOS 应用更新后 UUID 变化，头像也不会丢失。
      final appDir = await getApplicationDocumentsDirectory();
      final fullPath = p.join(appDir.path, relativePath);

      // 文件已被外部删除：清理失效登记，避免 UI 拿着过期路径渲染。
      if (!await File(fullPath).exists()) {
        await prefs.remove(_avatarPathKey);
        return null;
      }

      return fullPath;
    } catch (e, st) {
      logger.warning('AvatarStorage', 'getAvatarPath 读取失败: $e', st);
      return null;
    }
  }

  @override
  Future<String?> saveAvatarFromBytes(
    Uint8List bytes, {
    String extension = '.jpg',
  }) async {
    if (bytes.isEmpty) return null;
    try {
      // 先删旧头像，避免同目录多份文件堆积
      await _deleteOldAvatar();
      final newPath = await _writeAvatarFile((dirPath, fileName) async {
        final ext = extension.startsWith('.') ? extension : '.$extension';
        final target = File(p.join(dirPath, '$fileName$ext'));
        await target.writeAsBytes(bytes, flush: true);
        return target.path;
      });
      return newPath;
    } catch (e, st) {
      logger.error('AvatarStorage', 'saveAvatarFromBytes 落盘失败: $e', e, st);
      rethrow;
    }
  }

  @override
  Future<String?> saveAvatarFromFile(String sourcePath) async {
    try {
      await _deleteOldAvatar();
      final newPath = await _writeAvatarFile((dirPath, fileName) async {
        // 沿用源文件扩展名，保证头像后缀与实际内容一致
        final ext = p.extension(sourcePath);
        final target = File(p.join(dirPath, '$fileName$ext'));
        await File(sourcePath).copy(target.path);
        return target.path;
      });
      return newPath;
    } catch (e, st) {
      logger.error('AvatarStorage', 'saveAvatarFromFile 落盘失败: $e', e, st);
      rethrow;
    }
  }

  @override
  Future<int> getStoredRemoteVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_avatarRemoteVersionKey) ?? 0;
  }

  @override
  Future<void> setStoredRemoteVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_avatarRemoteVersionKey, version);
  }

  @override
  Future<void> clearStoredRemoteVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarRemoteVersionKey);
  }

  @override
  Future<void> deleteAvatar() async {
    await _deleteOldAvatar();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarPathKey);
    await prefs.remove(_avatarRemoteVersionKey);
  }

  /// 统一落盘编排：确保目录存在 → 回调写入 → 登记相对路径。
  ///
  /// [writer] 接收完整目录路径与时间戳文件名，负责生成新文件
  /// （使用时间戳避免图片缓存问题），返回新文件完整路径。
  Future<String> _writeAvatarFile(
    Future<String> Function(String dirPath, String fileName) writer,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory(p.join(appDir.path, _avatarDirName));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }

    // 使用时间戳避免图片缓存问题（同名文件会被 UI 层缓存命中）
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'avatar_$timestamp';
    final newPath = await writer(avatarDir.path, fileName);

    // 保存相对路径（避免 iOS 更新后 UUID 变化导致路径失效）。
    // 注意：必须手动用正斜杠拼接（不能 p.join）——Windows 下 p.join 会产出
    // 反斜杠，破坏「跨平台统一正斜杠」的既有存储格式（旧数据与测试均依赖）。
    final relativePath = '$_avatarDirName/${p.basename(newPath)}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, relativePath);
    return newPath;
  }

  /// 删除旧头像文件（内部幂等清理，失败不阻断主流程）。
  Future<void> _deleteOldAvatar() async {
    try {
      final avatarPath = await getAvatarPath();
      if (avatarPath != null) {
        final file = File(avatarPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e, st) {
      logger.warning('AvatarStorage', '清理旧头像失败: $e', st);
    }
  }
}

/// 全局头像存储单例（供 providers / cloud 层引用）。
final LocalAvatarStorage avatarStorage = LocalAvatarStorage();
