import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_service_config.dart';

/// 云服务凭据存储抽象（可插拔）。
///
/// 用于存放 WebDAV / S3 等同步运行所必需的访问凭据。默认实现
/// [SharedPreferencesCredentialStorage] 仅为保持现有行为（明文 XML），
/// 生产环境可替换为基于 Android Keystore / iOS Keychain 的实现
/// （例如 flutter_secure_storage），替换后无需改动 [CloudServiceStore]。
abstract class CloudCredentialStorage {
  /// 读取指定后端类型的凭据 JSON。
  Future<String?> read(CloudBackendType type);

  /// 写入指定后端类型的凭据 JSON。
  Future<void> write(CloudBackendType type, String value);

  /// 删除指定后端类型的凭据。
  Future<void> delete(CloudBackendType type);
}

/// SharedPreferences 兜底实现（明文，属于文档化取舍）。
///
/// 设计意图：不引入额外依赖时先保持可运行；接入安全存储后
/// 通过 [CloudServiceStore] 构造函数注入替代实现即可完成升级。
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
