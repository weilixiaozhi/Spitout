import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_service_config.dart';

/// 云服务凭证存储抽象（可插拔）。
///
/// 用于存放 WebDAV / S3 等同步运行所必需的访问凭证。默认实现
/// [FlutterSecureCredentialStorage] 走系统安全存储（Android Keystore /
/// iOS Keychain / Windows DPAPI / macOS Keychain）；
/// [SharedPreferencesCredentialStorage] 仅保留给测试注入与旧版明文数据读取，
/// 生产路径不得选用。
abstract class CloudCredentialStorage {
  /// 读取指定后端类型的凭证 JSON。
  Future<String?> read(CloudBackendType type);

  /// 写入指定后端类型的凭证 JSON。
  Future<void> write(CloudBackendType type, String value);

  /// 删除指定后端类型的凭证。
  Future<void> delete(CloudBackendType type);
}

/// 基于 flutter_secure_storage 的默认安全存储实现。
///
/// 设计意图：WebDAV / S3 密钥属于长期有效凭证，不能明文写入
/// SharedPreferences（Android 侧为明文 XML，且可能随系统备份带走）。
/// Android 侧启用 EncryptedSharedPreferences（API 23+ 生效，低版本自动
/// 回退 Keystore 方案），其余平台由插件映射到系统安全存储。
class FlutterSecureCredentialStorage implements CloudCredentialStorage {
  static const _keyPrefix = 'cloud_credential_';

  final FlutterSecureStorage _storage;

  FlutterSecureCredentialStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static String _key(CloudBackendType type) => '$_keyPrefix${type.name}';

  @override
  Future<String?> read(CloudBackendType type) => _storage.read(key: _key(type));

  @override
  Future<void> write(CloudBackendType type, String value) =>
      _storage.write(key: _key(type), value: value);

  @override
  Future<void> delete(CloudBackendType type) =>
      _storage.delete(key: _key(type));
}

/// SharedPreferences 明文实现（仅测试注入与旧版存量读取）。
///
/// 设计意图：单测环境没有平台安全存储通道，需要可注入的确定性实现；
/// 该实现不加密，注释明确标记风险，防止被误用于生产。
class SharedPreferencesCredentialStorage implements CloudCredentialStorage {
  static const _keyPrefix = 'cloud_credential_';

  static String _key(CloudBackendType type) => '$_keyPrefix${type.name}';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read(CloudBackendType type) async {
    final sp = await _prefs;
    return sp.getString(_key(type));
  }

  @override
  Future<void> write(CloudBackendType type, String value) async {
    final sp = await _prefs;
    await sp.setString(_key(type), value);
  }

  @override
  Future<void> delete(CloudBackendType type) async {
    final sp = await _prefs;
    await sp.remove(_key(type));
  }
}
