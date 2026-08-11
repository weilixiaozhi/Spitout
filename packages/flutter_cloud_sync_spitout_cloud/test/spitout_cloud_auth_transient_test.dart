/// SpitoutCloudAuthService 在“token 过期 + 网络抖动”窗口的语义测试。
///
/// 需求锚点（大众 app 行为）：
/// - `currentUser` 只回答“本地有没有 session”：session 还在就返回用户，
///   不因 token 过期/断网而变成“未登录”；
/// - `requireAccessToken` 必须区分“瞬时刷新失败（session 保留）”与
///   “凭证确认失效（session 被清）”：前者抛可重试错误，后者才抛未认证。
library;

import 'dart:convert';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录返回 `expires_in=0`（token 立即过期），refresh 一律抛网络异常，
/// 用于模拟“access token 刚好过期时发生网络抖动”。
MockClient _expiredTokenOfflineClient(List<String> log) {
  return MockClient((request) async {
    final path = request.url.path;
    log.add('${request.method} $path');
    if (path.endsWith('/auth/login')) {
      return http.Response(
        jsonEncode({
          'user': {'id': 'user-1', 'account': 'a@b.com'},
          'access_token': 'access-token-expired',
          'refresh_token': 'refresh-token-1',
          'expires_in': 0,
          'device_id': 'device-1',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/auth/refresh')) {
      throw http.ClientException('network down');
    }
    return http.Response('{"error":"not found"}', 404);
  });
}

/// 登录返回有效 token；`/read/ledgers` 返回 401；refresh 抛网络异常。
/// 覆盖 storage 层 `_authedRequest` 的 401 重试分支。
MockClient _storage401RefreshOfflineClient(List<String> log) {
  return MockClient((request) async {
    final path = request.url.path;
    log.add('${request.method} $path');
    if (path.endsWith('/auth/login')) {
      return http.Response(
        jsonEncode({
          'user': {'id': 'user-1', 'account': 'a@b.com'},
          'access_token': 'access-token-valid',
          'refresh_token': 'refresh-token-1',
          'expires_in': 3600,
          'device_id': 'device-1',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/auth/refresh')) {
      throw http.ClientException('network down');
    }
    if (path.endsWith('/read/ledgers')) {
      return http.Response(
        jsonEncode({'detail': 'access token expired'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"error":"not found"}', 404);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('过期 + 断网（瞬时失败）', () {
    test('currentUser 仍返回本地 session 用户，不显示未登录', () async {
      final log = <String>[];
      final auth = SpitoutCloudAuthService(
        baseUrl: 'https://cloud.example.com',
        apiPrefix: '/api/v1',
        httpClient: _expiredTokenOfflineClient(log),
        sessionStore: SharedPreferencesSessionStore(),
      );
      await auth.signInWithAccount(account: 'a@b.com', password: 'pw');

      final user = await auth.currentUser;

      expect(user, isNotNull, reason: 'session 还在，断网/过期不应被当成登出');
      expect(user!.id, 'user-1');
      expect(
        log.where((e) => e.endsWith('/auth/refresh')).length,
        1,
        reason: '应尝试过一次 refresh，而不是跳过直接判未登录',
      );
    });

    test('requireAccessToken 抛可重试错误，不抛未认证，且 session 保留', () async {
      final log = <String>[];
      final auth = SpitoutCloudAuthService(
        baseUrl: 'https://cloud.example.com',
        apiPrefix: '/api/v1',
        httpClient: _expiredTokenOfflineClient(log),
        sessionStore: SharedPreferencesSessionStore(),
      );
      await auth.signInWithAccount(account: 'a@b.com', password: 'pw');

      await expectLater(
        auth.requireAccessToken(),
        throwsA(isA<CloudStorageException>()),
        reason: '刷新瞬时失败但 session 保留时应抛可重试错误，而非未认证',
      );

      // session 未被清：下一次 currentUser 仍应返回用户。
      expect(await auth.currentUser, isNotNull,
          reason: '瞬时失败后本地 session 必须保留');
    });

    test('storage 401 且刷新瞬时失败：抛可重试错误并保留 session', () async {
      final log = <String>[];
      final client = _storage401RefreshOfflineClient(log);
      final auth = SpitoutCloudAuthService(
        baseUrl: 'https://cloud.example.com',
        apiPrefix: '/api/v1',
        httpClient: client,
        sessionStore: SharedPreferencesSessionStore(),
      );
      await auth.signInWithAccount(account: 'a@b.com', password: 'pw');

      final storage = SpitoutCloudStorageService(
        baseUrl: 'https://cloud.example.com',
        apiPrefix: '/api/v1',
        auth: auth,
        httpClient: client,
      );

      await expectLater(
        storage.readLedgers(),
        throwsA(isA<CloudStorageException>()),
        reason: '401 后刷新瞬时失败应抛可重试错误，而非未认证',
      );
      expect(await auth.currentUser, isNotNull,
          reason: '瞬时失败后本地 session 必须保留');
    });
  });
}
