// 源链契约：check() 对私有仓库/网络异常必须「降级为 unknown」而非抛错，
// 且 releaseUrl 始终兜底到 releasePageBase，保证「前往 GitHub」按钮任何状态下可用。
//
// 测试栈：flutter_test + http/testing 的 MockClient 桩接 GitHub API，
// 配合 package_info_plus 的 setMockInitialValues 注入当前版本，无需真实网络/设备。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/services/update/app_update_service.dart';

const _repoSlug = 'GavinWong303/Spitout';

/// 把任意 Map 包成 JSON 响应（等价旧测试中 ResponseBody.fromString）。
http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 每个用例给一个干净的基线：固定的当前版本 + 重置全局 mock 状态。
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'spitout',
      packageName: 'com.example.spitout',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    resetGlobalTestState();
  });

  group('AppUpdateService.check 容错逻辑', () {
    test('公开仓库有新版本 → hasUpdate + 解析版本与 releaseUrl', () async {
      final client = MockClient((_) async => _json({
            'tag_name': 'v2.0.0',
            'html_url': 'https://github.com/$_repoSlug/releases/tag/v2.0.0',
          }));
      final info = await AppUpdateService.check(client: client);

      expect(info.status, UpdateStatus.hasUpdate);
      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, '2.0.0');
      expect(info.releaseUrl,
          'https://github.com/$_repoSlug/releases/tag/v2.0.0');
      expect(info.currentVersion, '1.0.0');
    });

    test('公开仓库已是最新 → latest', () async {
      final client = MockClient((_) async => _json({
            'tag_name': 'v1.0.0',
            'html_url': 'https://github.com/$_repoSlug/releases/tag/v1.0.0',
          }));
      final info = await AppUpdateService.check(client: client);

      expect(info.status, UpdateStatus.latest);
      expect(info.hasUpdate, isFalse);
      expect(info.latestVersion, '1.0.0');
    });

    test('当前版本高于远端 → latest（不误报更新）', () async {
      final client = MockClient((_) async => _json({
            'tag_name': 'v0.9.0',
            'html_url': 'https://github.com/$_repoSlug/releases/tag/v0.9.0',
          }));
      final info = await AppUpdateService.check(client: client);

      expect(info.status, UpdateStatus.latest);
      expect(info.hasUpdate, isFalse);
    });

    test('私有仓库匿名请求 401 → 降级 unknown，releaseUrl 兜底', () async {
      // 私有仓库用匿名 token 拉 latest 会返回 401，必须降级而非抛错。
      final client = MockClient((_) async => http.Response('', 401));
      final info = await AppUpdateService.check(client: client);

      expect(info.status, UpdateStatus.unknown);
      expect(info.hasUpdate, isFalse);
      expect(info.releaseUrl, AppUpdateInfo.releasePageBase);
    });

    test('GitHub API 限流 403 → 降级 unknown', () async {
      final client = MockClient((_) async => http.Response('', 403));
      final info = await AppUpdateService.check(client: client);

      expect(info.status, UpdateStatus.unknown);
      expect(info.releaseUrl, AppUpdateInfo.releasePageBase);
    });

    test('网络/解析异常 → 降级 unknown（绝不向上抛出）', () async {
      // MockClient 直接抛异常，模拟 DNS 失败 / 断网。
      final client = MockClient((_) => throw http.ClientException('down'));
      final info = await AppUpdateService.check(client: client);

      expect(info.status, UpdateStatus.unknown);
      expect(info.releaseUrl, AppUpdateInfo.releasePageBase);
    });

    test('release 缺 html_url → releaseUrl 兜底到 releasePageBase', () async {
      final client = MockClient((_) async => _json({
            'tag_name': 'v2.0.0',
            // 故意不返回 html_url
          }));
      final info = await AppUpdateService.check(client: client);

      expect(info.status, UpdateStatus.hasUpdate);
      expect(info.releaseUrl, AppUpdateInfo.releasePageBase);
    });

    test('响应无 tag_name → 视为最新，latestVersion 为空', () async {
      final client = MockClient((_) async => _json({'html_url': 'x'}));
      final info = await AppUpdateService.check(client: client);

      expect(info.status, UpdateStatus.latest);
      expect(info.latestVersion, isNull);
    });
  });
}
