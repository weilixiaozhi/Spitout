/// SpitoutCloudAuthService 静默恢复凭据生命周期测试。
///
/// 覆盖 signOut() 必须清空 _recoveryAccount/_recoveryPassword,
/// 否则登出后 provider 重建触发 currentUser → _tryRecoveryLogin,
/// 会拿旧邮密自动 POST /auth/login 把云端账本"拉回来"——用户明明登出,
/// 下一轮 UI rebuild 又被静默登录,这就是"复活链"的根因。
///
/// 红测试路径:先显式登录建立 session → 注入恢复邮密(等价于云配置页保存)
/// → signOut → 调 currentUser:
///   - 修复前:recovery 未清 → POST /auth/login 自动重登 → currentUser 非 null(断言失败=红);
///   - 修复后:recovery 已清 → 直接返 null,不再发 /auth/login(断言通过=绿)。
///
/// 本测试随 Spitout Cloud provider 一并迁移至 adapter 包,
/// import 从核心包改为本包入口。
library;

import 'dart:convert';

import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 构造拦截全部请求的 MockClient,并按 path 记录请求日志。
///
/// 设计意图:用"请求日志计数"断言网络行为,而不是依赖内部私有字段,
/// 这样测试与实现细节解耦——只要 signOut 后 currentUser 不再发
/// /auth/login,就证明静默重登被切断。
MockClient _mockAuthClient(List<String> log) {
  return MockClient((request) async {
    final path = request.url.path;
    log.add('${request.method} $path');
    if (path.endsWith('/auth/login')) {
      // 返回有效 session:expires_in 给足,避免 currentUser 走 refresh 分支,
      // 让断言精确落在"recovery 是否再次触发 login"这一个行为上。
      return http.Response(
        jsonEncode({
          'user': {'id': 'user-1', 'account': 'a@b.com'},
          'access_token': 'access-token-1',
          'refresh_token': 'refresh-token-1',
          'expires_in': 3600,
          'device_id': 'device-1',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/auth/logout')) {
      return http.Response('{}', 200);
    }
    return http.Response('{"error":"not found"}', 404);
  });
}

/// 构造「所有请求都返回 401」的客户端,用于验证凭证连续被拒后的停用逻辑。
MockClient _mockRejectingClient(List<String> log) {
  return MockClient((request) async {
    log.add('${request.method} ${request.url.path}');
    return http.Response(
      jsonEncode({'detail': 'bad credentials'}),
      401,
      headers: {'content-type': 'application/json'},
    );
  });
}

int _loginCount(List<String> log) =>
    log.where((e) => e.endsWith('/auth/login')).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('signOut 清空静默恢复凭据', () {
    test('登出后 currentUser 不再触发 /auth/login 静默重登', () async {
      final log = <String>[];
      final auth = SpitoutCloudAuthService(
        baseUrl: 'https://cloud.example.com',
        apiPrefix: '/api/v1',
        httpClient: _mockAuthClient(log),
        // 单测没有平台安全存储通道,注入 SharedPreferences 实现配合
        // setMockInitialValues 完成确定性断言。
        sessionStore: SharedPreferencesSessionStore(),
      );

      // 1. 显式登录,建立本地 session
      await auth.signInWithAccount(account: 'a@b.com', password: 'pw');
      expect(_loginCount(log), 1, reason: '显式登录应恰好 1 次 /auth/login');

      // 2. 注入恢复邮密,模拟用户在云配置页保存过凭证
      auth.setRecoveryCredentials(account: 'a@b.com', password: 'pw');

      // 3. 用户主动登出
      await auth.signOut();

      // 4. 登出后任何一次鉴权探测都不应再触发静默恢复登录
      final loginBeforeProbe = _loginCount(log);
      final user = await auth.currentUser;
      final loginAfterProbe = _loginCount(log);

      expect(user, isNull, reason: 'signOut 后应保持未登录,而不是被恢复凭据自动登回');
      expect(loginAfterProbe, loginBeforeProbe,
          reason: 'signOut 后 recovery 凭据必须被清空,禁止静默重登(复活链)');
    });

    test('登出后再重新登录,恢复凭据可重新注入(不破坏正常登录流程)', () async {
      final log = <String>[];
      final auth = SpitoutCloudAuthService(
        baseUrl: 'https://cloud.example.com',
        apiPrefix: '/api/v1',
        httpClient: _mockAuthClient(log),
        sessionStore: SharedPreferencesSessionStore(),
      );

      await auth.signInWithAccount(account: 'a@b.com', password: 'pw');
      auth.setRecoveryCredentials(account: 'a@b.com', password: 'pw');
      await auth.signOut();

      // 重新注入(用户再次在配置页保存邮密)
      auth.setRecoveryCredentials(account: 'a@b.com', password: 'pw');

      // 下一次鉴权探测应能走恢复登录,证明清空逻辑没有破坏"注入→恢复"能力
      final before = _loginCount(log);
      final recovered = await auth.currentUser;
      expect(recovered, isNotNull, reason: '重新注入恢复凭据后应能正常静默恢复登录');
      expect(_loginCount(log), before + 1,
          reason: '重新注入后应重新允许 /auth/login 恢复请求');
    });
  });

  group('恢复凭证连续被拒后停用', () {
    test('连续 3 次 401 后不再触发静默登录(避免密码被改后无限重试)', () async {
      final log = <String>[];
      final auth = SpitoutCloudAuthService(
        baseUrl: 'https://cloud.example.com',
        apiPrefix: '/api/v1',
        httpClient: _mockRejectingClient(log),
        sessionStore: SharedPreferencesSessionStore(),
        // 测试环境不等待真实 30s 冷却,用零冷却连续触发失败。
        silentRecoveryCooldown: Duration.zero,
      );

      auth.setRecoveryCredentials(account: 'a@b.com', password: 'wrong-pw');

      // 前 3 次各打一次 /auth/login 并被拒。
      for (var i = 0; i < 3; i++) {
        expect(await auth.currentUser, isNull);
      }
      expect(_loginCount(log), 3);

      // 达到阈值后恢复凭证被清空,第 4 次探测不再发网络请求。
      final before = _loginCount(log);
      expect(await auth.currentUser, isNull);
      expect(_loginCount(log), before, reason: '连续被拒达到阈值后必须停用静默恢复');
    });
  });
}
