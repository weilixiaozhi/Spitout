/// CloudServiceStore.clearConfig 单元测试。
///
/// 覆盖:
/// - 各云端后端配置可被清除,清除后 loadXxx 返回 null;
/// - 清除当前激活后端后 loadActive() 自动回退本地存储;
/// - clearConfig(local) 为 no-op,不影响激活状态。
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 内存凭证存储：模拟生产安全存储，用于验证「旧版明文键迁移 + 明文键清理」。
class _MemoryCredentialStorage implements CloudCredentialStorage {
  final Map<CloudBackendType, String> _data = {};

  @override
  Future<String?> read(CloudBackendType type) async => _data[type];

  @override
  Future<void> write(CloudBackendType type, String value) async =>
      _data[type] = value;

  @override
  Future<void> delete(CloudBackendType type) async => _data.remove(type);

  String? peek(CloudBackendType type) => _data[type];
}

CloudServiceConfig _webdavCfg() => const CloudServiceConfig(
      type: CloudBackendType.webdav,
      name: 'WebDAV',
      webdavUrl: 'https://dav.example.com',
      webdavUsername: 'u',
      webdavPassword: 'p',
    );

CloudServiceConfig _supabaseCfg() => const CloudServiceConfig(
      type: CloudBackendType.supabase,
      name: 'Supabase',
      supabaseUrl: 'https://xxx.supabase.co',
      supabaseAnonKey: 'anon-key',
    );

CloudServiceConfig _s3Cfg() => const CloudServiceConfig(
      type: CloudBackendType.s3,
      name: 'S3',
      s3Endpoint: 's3.example.com',
      s3AccessKey: 'ak',
      s3SecretKey: 'sk',
      s3Bucket: 'bucket',
    );

CloudServiceConfig _spitoutCloudCfg() => const CloudServiceConfig(
      type: CloudBackendType.spitoutCloud,
      name: 'Spitout Cloud',
      spitoutCloudBaseUrl: 'https://cloud.example.com',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('clearConfig', () {
    test('清除 WebDAV 配置后 loadWebdav 返回 null', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      await store.saveOnly(_webdavCfg());
      expect(await store.loadWebdav(), isNotNull);

      await store.clearConfig(CloudBackendType.webdav);
      expect(await store.loadWebdav(), isNull);
    });

    test('清除 Supabase 配置后 loadSupabase 返回 null', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      await store.saveOnly(_supabaseCfg());
      expect(await store.loadSupabase(), isNotNull);

      await store.clearConfig(CloudBackendType.supabase);
      expect(await store.loadSupabase(), isNull);
    });

    test('清除 S3 配置后 loadS3 返回 null', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      await store.saveOnly(_s3Cfg());
      expect(await store.loadS3(), isNotNull);

      await store.clearConfig(CloudBackendType.s3);
      expect(await store.loadS3(), isNull);
    });

    test('清除 SpitoutCloud 配置后 loadSpitoutCloud 返回 null', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      await store.saveOnly(_spitoutCloudCfg());
      expect(await store.loadSpitoutCloud(), isNotNull);

      await store.clearConfig(CloudBackendType.spitoutCloud);
      expect(await store.loadSpitoutCloud(), isNull);
    });

    test('清除激活中的后端后 loadActive 自动回退本地存储', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      // saveAndActivate 同时写入配置并激活
      await store.saveAndActivate(_webdavCfg());
      expect((await store.loadActive()).type, CloudBackendType.webdav);

      await store.clearConfig(CloudBackendType.webdav);
      // 配置 key 缺失 → 回退 local
      final active = await store.loadActive();
      expect(active.type, CloudBackendType.local);
    });

    test('clearConfig(local) 为 no-op', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      await store.saveAndActivate(_webdavCfg());

      // 不应抛出,也不影响其他配置与激活状态
      await store.clearConfig(CloudBackendType.local);
      expect(await store.loadWebdav(), isNotNull);
      expect((await store.loadActive()).type, CloudBackendType.webdav);
    });

    test('清除一个后端不影响其他后端配置', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      await store.saveOnly(_webdavCfg());
      await store.saveOnly(_s3Cfg());

      await store.clearConfig(CloudBackendType.webdav);
      expect(await store.loadWebdav(), isNull);
      expect(await store.loadS3(), isNotNull);
    });
  });

  group('saveImported 凭据合并与剥离', () {
    test('脱敏占位符不会覆盖本机 WebDAV 密码', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      await store.saveOnly(_webdavCfg()); // 本机密码 'p'

      final masked = CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: 'WebDAV',
        webdavUrl: 'https://dav.example.com',
        webdavUsername: 'u',
        webdavPassword: '***',
      );
      // 即使显式勾选「包含凭据」，占位符也必须被忽略。
      await store.saveImported(masked, includeCredentials: true);

      expect((await store.loadWebdav())!.webdavPassword, 'p');
    });

    test('显式携带真实凭据的导入覆盖 WebDAV 密码', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      await store.saveOnly(_webdavCfg());

      final incoming = CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: 'WebDAV',
        webdavUrl: 'https://dav.example.com',
        webdavUsername: 'u',
        webdavPassword: 'new-password',
      );
      await store.saveImported(incoming, includeCredentials: true);

      expect((await store.loadWebdav())!.webdavPassword, 'new-password');
    });

    test('Supabase 登录密码导入后仍被剥离且不落盘', () async {
      final store = CloudServiceStore(
        credentialStorage: SharedPreferencesCredentialStorage(),
      );
      final incoming = CloudServiceConfig(
        type: CloudBackendType.supabase,
        name: 'Supabase',
        supabaseUrl: 'https://xxx.supabase.co',
        supabaseAnonKey: 'anon-key',
        supabaseEmail: 'a@b.com',
        supabasePassword: 'super-secret',
      );
      await store.saveImported(incoming, includeCredentials: true);

      final loaded = await store.loadSupabase();
      expect(loaded, isNotNull);
      expect(loaded!.supabasePassword, isNull);
      expect(loaded.supabaseEmail, 'a@b.com');

      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('cloud_supabase_cfg')!;
      expect(raw, isNot(contains('super-secret')));
    });
  });

  group('旧版明文凭证迁移与清理', () {
    test('读取时自动把 cloud_credential_* 明文搬进安全存储并删除明文键', () async {
      SharedPreferences.setMockInitialValues({
        'cloud_webdav_cfg': jsonEncode({
          'type': 'webdav',
          'name': 'WebDAV',
          'webdavUrl': 'https://dav.example.com',
          'webdavUsername': 'u',
        }),
        'cloud_credential_webdav': jsonEncode({
          'webdavPassword': 'legacy-pw',
        }),
      });

      final secure = _MemoryCredentialStorage();
      final store = CloudServiceStore(credentialStorage: secure);
      final loaded = await store.loadWebdav();

      // 旧明文凭据被合并回配置，业务无感知。
      expect(loaded, isNotNull);
      expect(loaded!.webdavPassword, 'legacy-pw');
      // 明文键已被删除，凭据只存在于（模拟的）安全存储中。
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('cloud_credential_webdav'), isNull);
      expect(secure.peek(CloudBackendType.webdav), isNotNull);
    });

    test('saveOnly 写入后不残留旧版明文凭证键', () async {
      SharedPreferences.setMockInitialValues({
        'cloud_credential_webdav': jsonEncode({
          'webdavPassword': 'stale',
        }),
      });

      final secure = _MemoryCredentialStorage();
      final store = CloudServiceStore(credentialStorage: secure);
      await store.saveOnly(_webdavCfg());

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('cloud_credential_webdav'), isNull);
      expect(secure.peek(CloudBackendType.webdav), isNotNull);
      expect((await store.loadWebdav())!.webdavPassword, 'p');
    });
  });
}
