import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// [SpitoutCloudStorageService.removeMember] / [deleteLedger] 的 REST 层单元测试。
///
/// 设计意图：本次修复在 REST 层做了两处关键改动：
///   1) [removeMember] 在 server 返回 404 时「幂等吞掉」——覆盖「list 完到
///      remove 之间成员已被踢出」的竞态，避免退出共享账本时报错；
///   2) [deleteLedger]（Owner 全局删除）走 `/write/ledgers/{id}`。
///
/// 测试用 [MockClient] 模拟 server 响应，并用一个返回固定 token 的本地
/// fake auth 绕过真实登录（真实 [requireAccessToken] 无 session 会抛未认证）。
void main() {
  /// 返回固定 token 的 fake auth，避免触发真实登录网络调用。
  SpitoutCloudAuthService buildAuth() => _TestAuthService();

  SpitoutCloudStorageService buildStorage(http.Client client) =>
      SpitoutCloudStorageService(
        baseUrl: 'https://fake.test',
        apiPrefix: '/api/v1',
        auth: buildAuth(),
        httpClient: client,
      );

  group('SpitoutCloudStorageService.removeMember', () {
    test('server 返回 404 → 幂等吞掉,不抛异常（竞态保护）', () async {
      final storage = buildStorage(
        MockClient((_) async => http.Response('', 404)),
      );
      // 不抛即通过 —— 这正是退出共享账本时"已被踢"场景不该报错的依据。
      await storage.removeMember(ledgerId: 'L1', userId: 'M1');
    });

    test('server 返回 204 → 正常完成', () async {
      final storage = buildStorage(
        MockClient((_) async => http.Response('', 204)),
      );
      await storage.removeMember(ledgerId: 'L1', userId: 'M1');
    });

    test('server 返回 500 → 抛出 CloudStorageException', () async {
      final storage = buildStorage(
        MockClient((_) async =>
            http.Response('{"detail":"boom"}', 500)),
      );
      expect(
        () => storage.removeMember(ledgerId: 'L1', userId: 'M1'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });

  group('SpitoutCloudStorageService.deleteLedger', () {
    test('DELETE /write/ledgers/{id} 返回 204 → 成功', () async {
      final storage = buildStorage(
        MockClient((_) async => http.Response('', 204)),
      );
      // 不抛即通过
      await storage.deleteLedger(ledgerId: 'L1');
    });

    test('server 返回 500 → 抛出 CloudStorageException', () async {
      final storage = buildStorage(
        MockClient((_) async =>
            http.Response('{"detail":"boom"}', 500)),
      );
      expect(
        () => storage.deleteLedger(ledgerId: 'L1'),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });
}

/// 返回固定 token 的本地 fake auth —— 仅用于绕过真实登录网络调用。
class _TestAuthService extends SpitoutCloudAuthService {
  _TestAuthService()
      : super(baseUrl: 'https://fake.test', apiPrefix: '/api/v1');

  @override
  Future<String> requireAccessToken() async => 'test-token';

  @override
  String? get currentDeviceId => 'test-device-id';
}
