// 配置导出服务测试。
//
// 覆盖两个安全/正确性契约：
//   1. 默认导出时密码/密钥脱敏为 ***，仅显式勾选“包含凭据”才写明文；
//   2. 手工 YAML 输出对特殊字符（引号、换行）正确转义，往返解析不失真。

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/services/export/config_export_service.dart';

class _MockRepo extends Mock implements LocalRepository {}

/// 测试用 Store：凭证走 SharedPreferences 明文 mock，避免依赖平台安全存储通道。
CloudServiceStore _testStore() =>
    CloudServiceStore(credentialStorage: SharedPreferencesCredentialStorage());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    when(() => repo.getAllCategories()).thenAnswer((_) async => <Category>[]);
    when(
      () => repo.getTopLevelCategories(any()),
    ).thenAnswer((_) async => <Category>[]);
    when(
      () => repo.getAllRecurringTransactions(),
    ).thenAnswer((_) async => <RecurringTransaction>[]);
  });

  test('默认导出密码/密钥脱敏，显式包含凭据时写明文', () async {
    SharedPreferences.setMockInitialValues({
      'cloud_supabase_cfg': encodeCloudConfig(
        const CloudServiceConfig(
          type: CloudBackendType.supabase,
          name: 'Supabase',
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
          supabaseAccount: 'a@b.c',
          supabasePassword: 'p@ss"word\nline2',
        ),
      ),
      'cloud_webdav_cfg': encodeCloudConfig(
        const CloudServiceConfig(
          type: CloudBackendType.webdav,
          name: 'WebDAV',
          webdavUrl: 'https://dav.example.com',
          webdavUsername: 'user',
          webdavPassword: 'dav-pass',
          webdavRemotePath: '/remote',
        ),
      ),
      'cloud_s3_cfg': encodeCloudConfig(
        const CloudServiceConfig(
          type: CloudBackendType.s3,
          name: 'S3',
          s3Endpoint: 'https://s3.example.com',
          s3Region: 'us-east-1',
          s3AccessKey: 'AK',
          s3SecretKey: 'secret-key',
          s3Bucket: 'bucket',
          s3UseSSL: true,
        ),
      ),
    });

    final masked = await ConfigExportService.exportToYaml(
      repository: repo,
      options: const ExportOptions(includeCredentials: false),
      store: _testStore(),
    );
    final maskedDoc = loadYaml(masked) as Map;
    // Supabase 登录密码按安全设计永不持久化（写入前剥离），
    // 因此导出既不能写明文、也没有历史值可脱敏为 ***，只能整键省略。
    expect((maskedDoc['supabase'] as Map).containsKey('password'), isFalse);
    expect((maskedDoc['webdav'] as Map)['password'], '***');
    expect((maskedDoc['s3'] as Map)['secret_key'], '***');

    final plain = await ConfigExportService.exportToYaml(
      repository: repo,
      options: const ExportOptions(includeCredentials: true),
      store: _testStore(),
    );
    final plainDoc = loadYaml(plain) as Map;
    expect((plainDoc['supabase'] as Map).containsKey('password'), isFalse);
    expect((plainDoc['webdav'] as Map)['password'], 'dav-pass');
    expect((plainDoc['s3'] as Map)['secret_key'], 'secret-key');
  });

  test('账本名含引号/换行时导出 YAML 仍可解析且值不失真', () async {
    // 本用例需要 SharedPreferences mock 才能调 exportToYaml;
    // 随机顺序下可能先于其它用例执行,必须自备初始值,不能依赖同文件前序用例。
    SharedPreferences.setMockInitialValues({});
    when(() => repo.getAllLedgers()).thenAnswer(
      (_) async => [
        Ledger(
          id: 1,
          name: '引号"账本\n新行',
          currency: 'CNY',
          type: 'personal',
          createdAt: DateTime(2026, 1, 1),
          myRole: 'owner',
          memberCount: 1,
          isShared: false,
          monthStartDay: 1,
          storageMode: 'local',
          aaEnabled: false,
        ),
      ],
    );

    final yaml = await ConfigExportService.exportToYaml(
      repository: repo,
      options: const ExportOptions(
        ledgers: true,
        categories: false,
        recurringTransactions: false,
        appSettings: false,
      ),
    );
    final doc = loadYaml(yaml) as Map;
    final items = (doc['ledgers'] as Map)['items'] as List;
    expect((items.single as Map)['name'], '引号"账本\n新行');
  });

  test('Spitout Cloud 登录态 token 与密码同级受凭据开关控制', () async {
    const cfg = SpitoutCloudConfig(
      baseUrl: 'https://cloud.example.com',
      account: 'a@b.c',
      password: 'pw',
      accessToken: 'at',
      refreshToken: 'rt',
      deviceId: 'dev-1',
    );
    final masked = cfg.toMap(includeCredentials: false);
    expect(masked['password'], '***');
    expect(masked['access_token'], '***');
    expect(masked['refresh_token'], '***');
    expect(masked['device_id'], '***');

    final plain = cfg.toMap(includeCredentials: true);
    expect(plain['password'], 'pw');
    expect(plain['access_token'], 'at');
    expect(plain['refresh_token'], 'rt');
    expect(plain['device_id'], 'dev-1');
  });

  test('导入脱敏文件时跳过 *** 占位符,未勾选凭据时不覆盖本机密码/密钥', () async {
    // 本机已有有效凭据。
    SharedPreferences.setMockInitialValues({
      'cloud_webdav_cfg': encodeCloudConfig(
        const CloudServiceConfig(
          type: CloudBackendType.webdav,
          name: 'WebDAV',
          webdavUrl: 'https://dav.example.com',
          webdavUsername: 'user',
          webdavPassword: 'current-pass',
          webdavRemotePath: '/remote',
        ),
      ),
      'cloud_s3_cfg': encodeCloudConfig(
        const CloudServiceConfig(
          type: CloudBackendType.s3,
          name: 'S3',
          s3Endpoint: 'https://s3.example.com',
          s3Region: 'us-east-1',
          s3AccessKey: 'AK',
          s3SecretKey: 'current-secret',
          s3Bucket: 'bucket',
        ),
      ),
    });

    // 导入一份脱敏导出的配置(密码/密钥为 ***,且未勾选包含凭据)。
    const maskedYaml = '''
webdav:
  url: "https://dav.example.com"
  username: "user"
  password: "***"
s3:
  endpoint: "https://s3.example.com"
  region: "us-east-1"
  access_key: "AK"
  secret_key: "***"
  bucket: "bucket"
''';
    await ConfigExportService.importFromYaml(
      maskedYaml,
      repository: repo,
      options: const ExportOptions(includeCredentials: false),
      store: _testStore(),
    );

    // 旧版 JSON 中的明文密码在读取时已迁入凭证存储，
    // 断言必须经 CloudServiceStore 读取，而不是直接解析被剥离后的配置 JSON。
    final testStore = _testStore();
    final webdavAfter = await testStore.loadWebdav();
    expect(webdavAfter!.webdavPassword, 'current-pass');
    final s3After = await testStore.loadS3();
    expect(s3After!.s3SecretKey, 'current-secret');

    // 同一份脱敏文件即使勾选包含凭据,占位符也不得覆盖本机值。
    await ConfigExportService.importFromYaml(
      maskedYaml,
      repository: repo,
      options: const ExportOptions(includeCredentials: true),
      store: _testStore(),
    );
    final webdavAfter2 = await testStore.loadWebdav();
    expect(webdavAfter2!.webdavPassword, 'current-pass');

    // 未勾选凭据时,即使 yaml 含明文密码也不导入,保留本机值。
    const plainYaml = '''
webdav:
  url: "https://dav.example.com"
  username: "user"
  password: "new-pass"
''';
    await ConfigExportService.importFromYaml(
      plainYaml,
      repository: repo,
      options: const ExportOptions(includeCredentials: false),
      store: _testStore(),
    );
    final webdavAfter3 = await testStore.loadWebdav();
    expect(webdavAfter3!.webdavPassword, 'current-pass');

    // 勾选包含凭据后,明文密码才会覆盖本机值。
    await ConfigExportService.importFromYaml(
      plainYaml,
      repository: repo,
      options: const ExportOptions(includeCredentials: true),
      store: _testStore(),
    );
    final webdavAfter4 = await testStore.loadWebdav();
    expect(webdavAfter4!.webdavPassword, 'new-pass');
  });
}
