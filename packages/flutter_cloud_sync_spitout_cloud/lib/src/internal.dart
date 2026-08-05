import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show CloudSyncLogger;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 默认日志出口:仅 debug 构建输出,release 不产生任何日志噪音。
///
/// 设计意图:业务侧可注入自定义 [CloudSyncLogger] 接入统一日志系统;
/// 未注入时用本默认实现,避免 release 包残留 debugPrint 输出。
final CloudSyncLogger defaultCloudLogger = CloudSyncLogger(
  onLog: (level, message) {
    if (kDebugMode) {
      debugPrint('[SpitoutCloud] $message');
    }
  },
);

String? trimOrNull(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String firstNonEmpty(List<String?> values, {required String fallback}) {
  for (final value in values) {
    final normalized = trimOrNull(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return fallback;
}

String joinNonEmpty(List<String?> values) {
  return values
      .map(trimOrNull)
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .join(' ')
      .trim();
}

/// 带默认建连超时(10s)的 http.Client 工厂。
///
/// 为什么不用裸 `http.Client()`:其内部 `HttpClient.connectionTimeout` 为 null,
/// 在坏网络(TCP 重传黑洞)下建连可 hang 127s+ 甚至永久,是登录/记账卡死的根因。
http.Client defaultHttpClient() =>
    IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 10));

/// 统一的"带超时发请求"出口 —— 所有 HTTP 出口都必须走这里,
/// `grep sendWithTimeout` 即可审计是否有遗漏出口。
///
/// 双层超时设计:
/// - [sendTimeout]:覆盖建连 + 发请求体 + 读响应头(`client.send`);
/// - [bodyTimeout]:覆盖读响应体(`Response.fromStream`)。
/// 超时抛 dart:async 的 [TimeoutException],上层 catch 已能区分
/// 瞬时网络故障与认证失败,不引入自定义异常类型。
Future<http.Response> sendWithTimeout(
  http.Client client,
  http.BaseRequest request, {
  Duration sendTimeout = const Duration(seconds: 15),
  Duration bodyTimeout = const Duration(seconds: 30),
}) async {
  final streamed = await client.send(request).timeout(sendTimeout);
  return http.Response.fromStream(streamed).timeout(bodyTimeout);
}

/// 登录 / refresh 被 server 明确拒绝(401/403)时抛出的内部异常。
///
/// 设计意图:401/403 意味着 refresh token / 邮密已失效(revoke / 过期 /
/// 密码被改),凭证「彻底失效」,此时清 session 并停用自动恢复是正确的。
/// 与之相对,网络抖动 / 429 限流 / 5xx 属于「瞬时故障」,refresh token 本身
/// 仍然有效,绝不能清 session(清了会引发 add(null) 连锁误登出 + WS 重连
/// 拿不到 token → UI 显示 "User not authenticated" 断连)。
/// 仅在本包内部用于认证流程分流,不对外暴露。
class CredentialsRejectedException implements Exception {
  CredentialsRejectedException(this.message);

  final String message;

  @override
  String toString() => 'CredentialsRejectedException: $message';
}

String normalizeApiPrefix(String raw) {
  var prefix = raw.trim();
  if (prefix.isEmpty) {
    return '/api/v1';
  }
  if (!prefix.startsWith('/')) {
    prefix = '/$prefix';
  }
  if (prefix.endsWith('/')) {
    prefix = prefix.substring(0, prefix.length - 1);
  }
  return prefix;
}

Map<String, dynamic> decodeJsonObject(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid JSON response');
  }
  return decoded;
}

/// 从错误响应中提取用户可读信息:优先取 JSON `detail`,缺失时附 body 截断,
/// 便于排查服务端 5xx / 网关错误。
String extractErrorMessage(http.Response response) {
  try {
    final payload = decodeJsonObject(response.body);
    final detail = payload['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
  } catch (_) {}
  final body = response.body.trim();
  if (body.isNotEmpty) {
    final preview = body.length > 200 ? '${body.substring(0, 200)}…' : body;
    return 'HTTP ${response.statusCode}: $preview';
  }
  return 'HTTP ${response.statusCode}';
}

/// 除 localhost / 私网测试地址外,禁止 http 明文传输凭证。
///
/// 返回 false 表示该 URI 不允许用 http;https 与 wss 恒为 true。
bool isHttpTransportAllowed(Uri uri) {
  if (uri.scheme != 'http') return true;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host.endsWith('.local')) {
    return true;
  }
  return _isPrivateIpv4(host);
}

bool _isPrivateIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final nums = parts.map(int.tryParse).toList();
  if (nums.any((n) => n == null || n < 0 || n > 255)) return false;
  final a = nums[0]!;
  final b = nums[1]!;
  // RFC1918 私网段 + 链路本地地址,作为内网测试白名单。
  return a == 10 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 169 && b == 254);
}

/// URL 路径段编码:防止 id/code 含 `/`、`?`、`#` 等字符时破坏路由。
String encodePathSegment(String value) => Uri.encodeComponent(value);

/// 严格解析必填字符串字段:缺失 / 非字符串 / 空白串一律抛 [FormatException],
/// 避免空串进入同步逻辑后被当成合法标识符。
String requireNonEmptyString(
  Map<String, dynamic> json,
  String key,
  String model,
) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('$model: field "$key" is missing or empty');
}

/// 严格解析必填整数字段:缺失 / 非数字一律抛 [FormatException]。
int requireInt(Map<String, dynamic> json, String key, String model) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('$model: field "$key" is missing or not a number');
}
