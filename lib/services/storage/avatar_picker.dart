import 'package:image_picker/image_picker.dart';

import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/core/storage/avatar_storage.dart';

/// 头像选取实现（ImagePicker 选图 + 落盘编排）。
///
/// 设计意图：
/// - 只负责系统相册交互：拿到 XFile 后把落盘交给注入的
///   [LocalAvatarStorage]（默认挂载 [avatarStorage]），保持存储与 UI 交互解耦。
/// - 依赖方向：services/storage/avatar_picker → core/storage/avatar_storage
///   （同一层内部依赖，合法）。
/// - 错误处理：选取/落盘全程 try-catch，记录详细日志后 rethrow，
///   由上层（providers → UI）决定如何提示用户。
class SystemAvatarPicker {
  /// [storage] 可注入 mock，测试或未来替换存储实现时使用。
  SystemAvatarPicker({LocalAvatarStorage? storage})
      : _storage = storage ?? avatarStorage;

  final LocalAvatarStorage _storage;

  Future<String?> pickAndSaveAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      // 用户取消选择：非错误，返回 null 由 UI 静默处理。
      if (image == null) return null;

      // 落盘编排（删旧 + 复制 + 登记路径）统一走存储。
      return await _storage.saveAvatarFromFile(image.path);
    } catch (e, st) {
      logger.error('AvatarPicker', '选取/保存头像失败: $e', e, st);
      rethrow;
    }
  }
}

/// 全局头像选取单例（默认挂载 [avatarStorage]）。
final SystemAvatarPicker avatarPicker = SystemAvatarPicker();
