import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/core/logging/logger_service.dart';

/// 成员头像本地磁盘缓存（按 userId + 服务端版本号键控）。
///
/// 设计意图：
/// - 成员头像之前直接走 `Image.network`，断网/重启后会反复重拉；本类把头像
///   落盘到 `Documents/avatars/members/`，与本人头像缓存共用目录体系；
/// - 键 = sha1(userId) + version：版本变化即视为新头像，下一次读取自动重下
///   覆盖，无需额外的失效事件；
/// - 读取失败返回 null（UI 显示占位），写入失败记日志后 rethrow 交由上层
///   决定降级策略，避免缓存错误被静默吞掉。
class LocalMemberAvatarStorage {
  static const String _dirName = 'avatars/members';
  static const String _pathKeyPrefix = 'member_avatar_path_';
  static const String _versionKeyPrefix = 'member_avatar_version_';

  /// userId 不直接进文件名/prefs key：sha1 归一化，避免特殊字符破坏路径。
  static String _keyOf(String userId) =>
      sha1.convert(utf8.encode(userId)).toString();

  /// 读取与 [version] 一致的缓存头像路径；版本不一致或无缓存返回 null。
  Future<String?> getPath({
    required String userId,
    required int version,
  }) async {
    try {
      final key = _keyOf(userId);
      final prefs = await SharedPreferences.getInstance();
      final storedVersion = prefs.getInt('$_versionKeyPrefix$key');
      if (storedVersion != version) return null;
      final relativePath = prefs.getString('$_pathKeyPrefix$key');
      if (relativePath == null || relativePath.isEmpty) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final fullPath = p.join(appDir.path, relativePath);
      // 文件被外部删除时清除失效登记，避免 UI 拿过期路径渲染。
      if (!await File(fullPath).exists()) {
        await prefs.remove('$_pathKeyPrefix$key');
        await prefs.remove('$_versionKeyPrefix$key');
        return null;
      }
      return fullPath;
    } catch (e, st) {
      logger.warning('MemberAvatarCache', 'getPath 读取失败: $e', st);
      return null;
    }
  }

  /// 保存成员头像字节流并登记版本号，返回完整路径。
  Future<String> save({
    required String userId,
    required int version,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', '头像字节流不能为空');
    }
    try {
      final key = _keyOf(userId);
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDir.path, _dirName));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final fileName = '$key$extension';
      final target = File(p.join(dir.path, fileName));
      await target.writeAsBytes(bytes, flush: true);

      final prefs = await SharedPreferences.getInstance();
      // 存相对路径（同本人头像），避免 iOS 应用更新后 Documents UUID 变化失效。
      await prefs.setString('$_pathKeyPrefix$key', '$_dirName/$fileName');
      await prefs.setInt('$_versionKeyPrefix$key', version);
      return target.path;
    } catch (e, st) {
      logger.error('MemberAvatarCache', 'save 落盘失败: $e', st);
      rethrow;
    }
  }

  /// 清除某成员的缓存（服务端头像被删除/版本归零时调用），幂等。
  Future<void> remove(String userId) async {
    try {
      final key = _keyOf(userId);
      final prefs = await SharedPreferences.getInstance();
      final relativePath = prefs.getString('$_pathKeyPrefix$key');
      if (relativePath != null && relativePath.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File(p.join(appDir.path, relativePath));
        if (await file.exists()) {
          await file.delete();
        }
      }
      await prefs.remove('$_pathKeyPrefix$key');
      await prefs.remove('$_versionKeyPrefix$key');
    } catch (e, st) {
      logger.warning('MemberAvatarCache', 'remove 失败: $e', st);
    }
  }
}

/// 全局成员头像缓存单例（供 providers / widgets 引用）。
final LocalMemberAvatarStorage memberAvatarStorage = LocalMemberAvatarStorage();
