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
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/services/export/config_export_service.dart';

class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    when(() => repo.getAllCategories()).thenAnswer((_) async => <Category>[]);
    when(() => repo.getTopLevelCategories(any()))
        .thenAnswer((_) async => <Category>[]);
    when(() => repo.getAllRecurringTransactions())
        .thenAnswer((_) async => <RecurringTransaction>[]);
  });

  test('默认导出密码/密钥脱敏，显式包含凭据时写明文', () async {
    SharedPreferences.setMockInitialValues({
      'cloud_supabase_cfg': encodeCloudConfig(
        const CloudServiceConfig(
          type: CloudBackendType.supabase,
          name: 'Supabase',
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
          supabaseEmail: 'a@b.c',
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
    );
    final maskedDoc = loadYaml(masked) as Map;
    expect((maskedDoc['supabase'] as Map)['password'], '***');
    expect((maskedDoc['webdav'] as Map)['password'], '***');
    expect((maskedDoc['s3'] as Map)['secret_key'], '***');

    final plain = await ConfigExportService.exportToYaml(
      repository: repo,
      options: const ExportOptions(includeCredentials: true),
    );
    final plainDoc = loadYaml(plain) as Map;
    expect(
      (plainDoc['supabase'] as Map)['password'],
      'p@ss"word\nline2',
      reason: '显式勾选后应写回原始密码（含引号/换行）',
    );
    expect((plainDoc['webdav'] as Map)['password'], 'dav-pass');
    expect((plainDoc['s3'] as Map)['secret_key'], 'secret-key');
  });

  test('账本名含引号/换行时导出 YAML 仍可解析且值不失真', () async {
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
}
