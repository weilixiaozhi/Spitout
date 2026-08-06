/// SpitoutCloudAuthService refresh 生命周期单元测试。
///
/// 覆盖「云服务总是断连」修复(P0)的核心行为分流：
///   1. refresh 遇瞬时故障(5xx/429/网络异常)时保留本地 session，
///      不广播 null(不触发误登出连锁)。
///   2. refresh 被 server 明确拒绝(401/403)时才清理 session 并广播登出。
///   3. refresh 成功时旋转 token 并更新 session。
///   4. hasUsableAccessToken 正确反映 access_token 可用性(P2 依赖)。
///
/// 测试手段：
///   - http.Client 用 package:http/testing.dart 的 MockClient 替换。
///   - session 通过 SharedPreferences mock 预置(access_token 未过期，
///     initialize 不触发 refresh，由测试主动调 tryRefreshSession)。
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
  const refreshToken = 'test_refresh_token';

  final sessionKey =
      'spitout_cloud_session_${sha1.convert(utf8.encode('$baseUrl|$apiPrefix'))}';

  /// 预置一份未过期的 session。initialize() 读到后不会触发 refresh，
  /// 由各测试主动调用 tryRefreshSession() 控制时序。
  void seedSession() {
    SharedPreferences.setMockInitialValues({
      sessionKey: jsonEncode({
        'userId': 'u1',
        'account': 'u1@example.com',
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessTokenExpiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'deviceId': 'device-1',
      }),
    });
  }

  /// 构建已 initialize 的 auth 服务，refresh 请求由 [client] 应答。
  Future<SpitoutCloudAuthService> buildAuth(http.Client client) async {
    final auth = SpitoutCloudAuthService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      httpClient: client,
      // 单测无平台安全存储通道,用 SharedPreferences mock 承载 session。
      sessionStore: SharedPreferencesSessionStore(),
    );
    await auth.initialize();
    return auth;
  }

  group('tryRefreshSession - 瞬时故障保留 session', () {
    for (final statusCode in [500, 429, 503]) {
      test('server 返回 $statusCode 时返回 false 且保留 session', () async {
        seedSession();
        final auth = await buildAuth(
          MockClient((_) async =>
              http.Response(jsonEncode({'detail': 'transient'}), statusCode)),
        );
        // 收集 authStateChanges，验证不广播 null(误登出连锁)。
        final events = <CloudUser?>[];
        final sub = auth.authStateChanges.listen(events.add);

        final refreshed = await auth.tryRefreshSession();
        // 等广播流微任务排空后再断言。
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(refreshed, isFalse);
        // 关键断言:session 未被清理 —— 内存与持久化都保留。
        expect(auth.currentDeviceId, 'device-1');
        expect(auth.currentUserId, 'u1');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(sessionKey), isNotNull);
        // 关键断言:没有 null 事件,UI 不会被误判为登出。
        expect(events.where((e) => e == null), isEmpty);

        await sub.cancel();
      });
    }

    test('网络异常(ClientException)时同样保留 session', () async {
      seedSession();
      final auth = await buildAuth(
        MockClient((_) async => throw http.ClientException('network down')),
      );

      final refreshed = await auth.tryRefreshSession();

      expect(refreshed, isFalse);
      expect(auth.currentDeviceId, 'device-1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(sessionKey), isNotNull);
    });
  });

  group('tryRefreshSession - 凭证彻底失效才清 session', () {
    for (final statusCode in [401, 403]) {
      test('server 返回 $statusCode 时清理 session 并广播登出', () async {
        seedSession();
        final auth = await buildAuth(
          MockClient((_) async => http.Response(
              jsonEncode({'detail': 'token revoked'}), statusCode)),
        );
        final events = <CloudUser?>[];
        final sub = auth.authStateChanges.listen(events.add);

        final refreshed = await auth.tryRefreshSession();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(refreshed, isFalse);
        // 凭证已被 server revoke,session 必须清干净。
        expect(auth.currentDeviceId, isNull);
        expect(auth.currentUserId, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(sessionKey), isNull);
        // 此时才应广播 null,通知 UI 进入登录态。
        expect(events, contains(isNull));

        await sub.cancel();
      });
    }
  });

  group('tryRefreshSession - 成功路径', () {
    test('200 时旋转 token 并更新 session', () async {
      seedSession();
      http.Request? captured;
      final auth = await buildAuth(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'user': {'id': 'u1', 'account': 'u1@example.com'},
              'access_token': 'new_access_token',
              'refresh_token': 'new_refresh_token',
              'expires_in': 3600,
              'device_id': 'device-1',
            }),
            200,
          );
        }),
      );

      final refreshed = await auth.tryRefreshSession();

      expect(refreshed, isTrue);
      expect(captured, isNotNull);
      expect(captured!.url.path, endsWith('/auth/refresh'));
      // 请求必须携带老的 refresh_token(rotating token 机制)。
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['refresh_token'], refreshToken);
      // 新 token 已入库(未过期)。
      expect(auth.hasUsableAccessToken, isTrue);
    });
  });

  group('hasUsableAccessToken', () {
    test('session 有效且未过期时为 true', () async {
      seedSession();
      final auth = await buildAuth(
        MockClient((_) async => http.Response('{}', 200)),
      );
      expect(auth.hasUsableAccessToken, isTrue);
    });

    test('401 清理 session 后为 false', () async {
      seedSession();
      final auth = await buildAuth(
        MockClient((_) async =>
            http.Response(jsonEncode({'detail': 'revoked'}), 401)),
      );
      await auth.tryRefreshSession();
      expect(auth.hasUsableAccessToken, isFalse);
    });

    test('无 session 时为 false', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = await buildAuth(
        MockClient((_) async => http.Response('{}', 200)),
      );
      expect(auth.hasUsableAccessToken, isFalse);
    });
  });
}
