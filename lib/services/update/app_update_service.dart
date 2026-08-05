import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/models/app_update_info.dart';

/// 应用内「检查更新」服务。
///
/// 通过 GitHub Releases 公开 API 获取最新发布版本，与当前安装版本比较，
/// 判断是否有新版本可下载。无需鉴权（匿名限流 60 次/小时/IP，足以支撑手动点击检查）。
///
/// 设计意图：本地 APK 分发没有应用商店的自动更新通道，因此自建一个轻量检测入口，
/// 引导用户前往 Release 页手动下载安装。
class AppUpdateService {
  /// GitHub 仓库标识（owner/repo），用于拼装 Releases API 与下载页地址。
  static const String repoSlug = 'weilixiaozhi/Spitout';

  /// 检查是否有新版本。
  ///
  /// - 取当前安装的 [PackageInfo.version]（即 versionName，如 "1.0.0"）。
  /// - 请求 latest release，解析 [tagName]（如 "v1.0.1"）去 "v" 后比较。
  /// - **不向上抛异常**：非 200（如私有仓库匿名请求 401 / 限流 403）、
  ///   网络抖动或解析失败，都降级为 [UpdateStatus.unknown]，由调用方弹窗引导
  ///   用户前往 GitHub（浏览器带登录态，私有仓库亦可访问），避免甩出硬错误。
  /// - [AppUpdateInfo.releaseUrl] 始终兜底到 [AppUpdateInfo.releasePageBase]，
  ///   保证「前往 GitHub」按钮在任何状态下都可用。
  /// [client] 为可选注入的 HTTP 客户端，仅用于单元测试桩接网络；
  /// 生产调用传 `null` 即使用默认 [http.Client]。
  static Future<AppUpdateInfo> check({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    final pkg = await PackageInfo.fromPlatform();
    final current = pkg.version;

    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$repoSlug/releases/latest',
      );
      final resp = await httpClient.get(
        uri,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      // 非 200 不抛错：私有仓库匿名请求会返回 401，限流会返回 403，
      // 这两种都应降级为 unknown，统一引导去 GitHub，而非报错。
      if (resp.statusCode != 200) {
        return AppUpdateInfo(
          status: UpdateStatus.unknown,
          currentVersion: current,
          releaseUrl: AppUpdateInfo.releasePageBase,
        );
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String? ?? '').replaceAll(
        RegExp(r'^v'),
        '',
      );
      // html_url 缺失时回退到 release 列表页，保证下载入口始终可用。
      final htmlUrl = data['html_url'] as String? ?? AppUpdateInfo.releasePageBase;

      final hasUpdate = tag.isNotEmpty && _isNewer(tag, current);
      return AppUpdateInfo(
        status: hasUpdate ? UpdateStatus.hasUpdate : UpdateStatus.latest,
        latestVersion: tag.isNotEmpty ? tag : null,
        releaseUrl: htmlUrl,
        currentVersion: current,
      );
    } catch (e) {
      // 任何网络/解析异常都降级为 unknown，统一引导去 GitHub，不报硬错误。
      return AppUpdateInfo(
        status: UpdateStatus.unknown,
        currentVersion: current,
        releaseUrl: AppUpdateInfo.releasePageBase,
      );
    }
  }

  /// 简单的语义化版本比较：返回 [latest] 是否严格大于 [current]。
  ///
  /// 只比较前三个数字段（主.次.修订），缺省段按 0 处理。
  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final lv = l.length > i ? l[i] : 0;
      final cv = c.length > i ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}

/// 注：UpdateStatus / AppUpdateInfo / releasePageBase 定义于
// data/models/app_update_info.dart（依赖方向 services → data）。
// 本文件不 re-export 任何类型（共识④：不建第二个出口），
// 调用方需经 data/models.dart 门面获取类型。
