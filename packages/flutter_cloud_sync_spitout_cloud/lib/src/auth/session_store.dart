import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 会话凭证存储抽象(session JSON 落盘出口)。
///
/// 设计意图:access/refresh token 属于长期有效凭证,不能明文写入
/// SharedPreferences(root / 备份 / 取证可读)。本接口把「存哪 / 怎么加密」
/// 从认证流程中解耦出来,默认实现走系统安全存储(Keychain / Keystore),
/// 测试可注入内存实现,不依赖平台通道。
abstract class SpitoutCloudSessionStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

/// 基于 flutter_secure_storage 的默认实现:Android Keystore / iOS Keychain /
/// Windows DPAPI / macOS Keychain 保管 token。
class FlutterSecureStorageSessionStore implements SpitoutCloudSessionStore {
  FlutterSecureStorageSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // Android 侧启用 EncryptedSharedPreferences(API 23+ 生效,
              // 低版本自动回退 Keystore 方案),提升静态取证难度。
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}

/// SharedPreferences 明文实现:仅测试注入使用,生产路径不得选用。
///
/// 设计意图:单测环境没有平台安全存储通道,需要可注入的确定性实现;
/// 该实现不加密,注释明确标记风险,防止被误用于生产。
class SharedPreferencesSessionStore implements SpitoutCloudSessionStore {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
