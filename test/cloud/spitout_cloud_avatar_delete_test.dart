/// SpitoutCloudStorageService.deleteMyAvatar 单元测试。
///
/// 覆盖「删除头像需连同服务端一起删」新增的 DELETE /profile/avatar 接口：
///   1. 请求方法 / 路径 / Authorization header 正确。
///   2. 服务端返回 2xx 时正常完成（204 No Content）。
///   3. 服务端返回非 2xx 时抛 CloudStorageException。
///
/// 测试手段：
///   - http.Client 用 package:http/testing.dart 的 MockClient 替换，
///     断言请求内容并返回构造的响应。
///   - session 通过 SharedPreferences mock 预置（access_token 未过期），
///     使 auth.requireAccessToken() 直接返回，不发 refresh 请求。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseUrl = 'https://example.com';
  const apiPrefix = '/api/v1';
  const accessToken = 'test_access_token';

  /// 预置一份未过期的 session，让 auth 层免 refresh 直接给出 token。
  void seedSession() {
    final digest = sha1.convert(utf8.encode('$baseUrl|$apiPrefix')).toString();
    SharedPreferences.setMockInitialValues({
      'spitout_cloud_session_$digest': jsonEncode({
        'userId': 'u1',
        'email': 'u1@example.com',
        'accessToken': accessToken,
        'refreshToken': 'refresh_token',
        'accessTokenExpiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'deviceId': 'device-1',
      }),
    });
  }

  Future<SpitoutCloudStorageService> buildStorage(http.Client client) async {
    final auth = SpitoutCloudAuthService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      // auth 侧不会被触达（token 未过期），给 MockClient 防止意外真实请求。
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      // 单测无平台安全存储通道,用 SharedPreferences mock 承载 session。
      sessionStore: SharedPreferencesSessionStore(),
    );
    await auth.initialize();
    return SpitoutCloudStorageService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      auth: auth,
      httpClient: client,
    );
  }

  group('deleteMyAvatar', () {
    test('发送 DELETE /profile/avatar 并带 Authorization header', () async {
      seedSession();
      http.Request? captured;
      final storage = await buildStorage(
        MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      await storage.deleteMyAvatar();

      expect(captured, isNotNull);
      expect(captured!.method, 'DELETE');
      expect(captured!.url.toString(), '$baseUrl$apiPrefix/profile/avatar');
      expect(captured!.headers['Authorization'], 'Bearer $accessToken');
    });

    test('服务端返回非 2xx 时抛 CloudStorageException', () async {
      seedSession();
      final storage = await buildStorage(
        MockClient((_) async => http.Response(
            jsonEncode({'detail': 'internal error'}), 500)),
      );

      expect(
        () => storage.deleteMyAvatar(),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });
}
