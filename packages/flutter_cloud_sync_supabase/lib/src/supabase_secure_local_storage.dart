import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 基于系统安全存储的 Supabase 会话持久化。
///
/// 设计意图：Supabase 的 access / refresh token 属于长期有效凭证，
/// 默认 SharedPreferences 持久化在 Android 侧是明文 XML，且可能随系统
/// 备份带走。本实现把会话 JSON 交给 flutter_secure_storage
/// （Android Keystore / iOS Keychain / Windows DPAPI），
/// 并保持 SDK 的 LocalStorage 契约不变。
class SecureSupabaseLocalStorage extends LocalStorage {
  SecureSupabaseLocalStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _sessionKey = 'supabase_auth_session';

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    final value = await _storage.read(key: _sessionKey);
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);
}

/// 基于系统安全存储的 PKCE code verifier 存储。
///
/// 设计意图：PKCE verifier 虽为一次性短时效值，但同样属于认证材料；
/// 与会话存储统一走安全通道，避免任何认证数据落入明文持久化。
class SecureSupabaseGotrueAsyncStorage extends GotrueAsyncStorage {
  SecureSupabaseGotrueAsyncStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) => _storage.read(key: key);

  @override
  Future<void> removeItem({required String key}) => _storage.delete(key: key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}
