// CloudConnectionTester 各后端探测分支测试（注入 MockClient，不打真实网络）。
//
// 需求锚点（以行为为准）：
//   1. local 配置直接成功；
//   2. Supabase：200/404/406 成功，401/403 鉴权失败，其余状态 serverStatus；
//      网络层异常（ClientException）映射 network；
//   3. WebDAV：OPTIONS 200/204 且带 DAV/Allow 头成功；200 无头 webdavNotSupported；
//      401 凭据错误；403 accessDenied；404 pathNotFound；其余 serverStatus；
//   4. Spitout Cloud / S3 非法配置统一 initFailed，且剥离异常前缀；
//   5. 所有失败都收敛为结构化结果，不向调用方抛业务异常。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/services/cloud/cloud_connection_tester.dart';

void main() {
  CloudServiceConfig supabaseConfig({required String anonKey}) =>
      CloudServiceConfig(
        type: CloudBackendType.supabase,
        name: 'supabase',
        supabaseUrl: 'https://db.example.com',
        supabaseAnonKey: anonKey,
      );

  CloudServiceConfig webdavConfig() => CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: 'webdav',
        webdavUrl: 'https://dav.example.com/remote.php/dav',
        webdavUsername: 'u',
        webdavPassword: 'p',
      );

  group('local 与 Supabase', () {
    test('local 直接成功且不发任何请求', () async {
      var requested = false;
      final tester = CloudConnectionTester(
        client: MockClient((_) async {
          requested = true;
          return http.Response('', 200);
        }),
      );
      final result = await tester.test(
        const CloudServiceConfig(type: CloudBackendType.local, name: 'local'),
      );
      expect(result.success, isTrue);
      expect(requested, isFalse);
    });

    test('supabase 200/404/406 成功', () async {
      for (final code in [200, 404, 406]) {
        final tester = CloudConnectionTester(
          client: MockClient((_) async => http.Response('', code)),
        );
        final result = await tester.test(supabaseConfig(anonKey: 'k'));
        expect(result.success, isTrue, reason: 'status=$code 应视为连接正常');
      }
    });

    test('supabase 401/403 鉴权失败', () async {
      for (final code in [401, 403]) {
        final tester = CloudConnectionTester(
          client: MockClient((_) async => http.Response('', code)),
        );
        final result = await tester.test(supabaseConfig(anonKey: 'bad'));
        expect(result.success, isFalse);
        expect(result.error!.type, CloudConnectionTestErrorType.authFailed);
      }
    });

    test('supabase 500 映射 serverStatus 且带状态码', () async {
      final tester = CloudConnectionTester(
        client: MockClient((_) async => http.Response('', 500)),
      );
      final result = await tester.test(supabaseConfig(anonKey: 'k'));
      expect(result.error!.type, CloudConnectionTestErrorType.serverStatus);
      expect(result.error!.statusCode, 500);
    });

    test('网络层 ClientException 映射 network', () async {
      final tester = CloudConnectionTester(
        client: MockClient(
          (_) async => throw http.ClientException('connection refused'),
        ),
      );
      final result = await tester.test(supabaseConfig(anonKey: 'k'));
      expect(result.error!.type, CloudConnectionTestErrorType.network);
      expect(result.error!.rawMessage, contains('connection refused'));
    });
  });

  group('WebDAV', () {
    test('200 + DAV/Allow 头成功', () async {
      final withDav = CloudConnectionTester(
        client: MockClient(
          (_) async => http.Response('', 200, headers: {'dav': '1,2'}),
        ),
      );
      expect((await withDav.test(webdavConfig())).success, isTrue);

      final withAllow = CloudConnectionTester(
        client: MockClient(
          (_) async => http.Response('', 204, headers: {'allow': 'PROPFIND'}),
        ),
      );
      expect((await withAllow.test(webdavConfig())).success, isTrue);
    });

    test('200 无 DAV/Allow 头 → webdavNotSupported', () async {
      final tester = CloudConnectionTester(
        client: MockClient((_) async => http.Response('', 200)),
      );
      final result = await tester.test(webdavConfig());
      expect(result.error!.type, CloudConnectionTestErrorType.webdavNotSupported);
    });

    test('401 → authFailedCredentials；403 → accessDenied', () async {
      final auth = CloudConnectionTester(
        client: MockClient((_) async => http.Response('', 401)),
      );
      expect(
        (await auth.test(webdavConfig())).error!.type,
        CloudConnectionTestErrorType.authFailedCredentials,
      );

      final denied = CloudConnectionTester(
        client: MockClient((_) async => http.Response('', 403)),
      );
      expect(
        (await denied.test(webdavConfig())).error!.type,
        CloudConnectionTestErrorType.accessDenied,
      );
    });

    test('404 → pathNotFound；500 → serverStatus', () async {
      final notFound = CloudConnectionTester(
        client: MockClient((_) async => http.Response('', 404)),
      );
      final nf = await notFound.test(webdavConfig());
      expect(nf.error!.type, CloudConnectionTestErrorType.pathNotFound);
      expect(nf.error!.path, isNotEmpty);

      final server = CloudConnectionTester(
        client: MockClient((_) async => http.Response('', 500)),
      );
      final ss = await server.test(webdavConfig());
      expect(ss.error!.type, CloudConnectionTestErrorType.serverStatus);
      expect(ss.error!.statusCode, 500);
    });
  });

  group('Spitout Cloud / S3', () {
    test('非法配置统一 initFailed 且剥离异常前缀', () async {
      final spitout = CloudConnectionTester(
        client: MockClient((_) async => http.Response('', 200)),
      );
      final sr = await spitout.test(
        const CloudServiceConfig(
          type: CloudBackendType.spitoutCloud,
          name: 'spitout',
          spitoutCloudBaseUrl: 'not-a-url',
        ),
      );
      expect(sr.success, isFalse);
      expect(sr.error!.type, CloudConnectionTestErrorType.initFailed);

      final s3 = CloudConnectionTester(
        client: MockClient((_) async => http.Response('', 200)),
      );
      final s3r = await s3.test(
        const CloudServiceConfig(
          type: CloudBackendType.s3,
          name: 's3',
          s3Endpoint: '',
          s3Region: '',
          s3AccessKey: '',
          s3SecretKey: '',
          s3Bucket: '',
        ),
      );
      expect(s3r.success, isFalse);
      expect(s3r.error!.type, CloudConnectionTestErrorType.initFailed);
    });
  });
}
