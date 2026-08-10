import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:spitout/cloud/spitout_cloud.dart'
    show CloudBackendType, CloudServiceConfig, createCloudServices;

import 'package:spitout/core/logging/logger_service.dart';

/// 连接测试失败原因类型。
///
/// UI 层按类型映射本地化文案,服务层不持有 BuildContext / l10n。
enum CloudConnectionTestErrorType {
  /// 鉴权失败(通用):Supabase 401/403 表示 anon key 无效。
  authFailed,

  /// 凭据错误(WebDAV 401)。
  authFailedCredentials,

  /// 403 无权限。
  accessDenied,

  /// 服务端不是 WebDAV(缺少 DAV/Allow 响应头)。
  webdavNotSupported,

  /// 路径不存在(404)。
  pathNotFound,

  /// 服务端返回未知状态码。
  serverStatus,

  /// 网络层失败(超时/连接失败)。
  network,

  /// 后端 provider 初始化失败(配置不合法等)。
  initFailed,

  /// 其他未知错误。
  unknown,
}

/// 连接测试失败详情:类型 + 可选附加信息(状态码/路径/原始消息)。
class CloudConnectionTestError {
  final CloudConnectionTestErrorType type;
  final int? statusCode;
  final String? path;
  final String? rawMessage;

  const CloudConnectionTestError({
    required this.type,
    this.statusCode,
    this.path,
    this.rawMessage,
  });
}

/// 连接测试结果:success 为 true 时 error 为空。
class CloudConnectionTestResult {
  final bool success;
  final CloudConnectionTestError? error;

  const CloudConnectionTestResult.success() : success = true, error = null;

  const CloudConnectionTestResult.failure(this.error) : success = false;
}

/// 云服务连接测试器。
///
/// 把各后端探测逻辑(http 请求、OPTIONS、S3 ListObjects)从页面下沉到
/// services 层:页面只负责展示结果,测试逻辑可复用、可单测。
class CloudConnectionTester {
  static const _timeout = Duration(seconds: 10);

  /// 可注入的 http 客户端：默认使用全局客户端，测试中可替换为 MockClient，
  /// 使各后端探测分支无需真实网络即可覆盖。
  final http.Client _client;

  CloudConnectionTester({http.Client? client}) : _client = client ?? http.Client();

  /// 测试指定配置的连通性。
  ///
  /// 返回结构化结果,不抛业务异常;网络/服务端错误统一收敛为
  /// [CloudConnectionTestResult.failure],避免页面层 catch 原始异常。
  Future<CloudConnectionTestResult> test(CloudServiceConfig config) async {
    if (config.type == CloudBackendType.local) {
      return const CloudConnectionTestResult.success();
    }
    try {
      switch (config.type) {
        case CloudBackendType.local:
          return const CloudConnectionTestResult.success();

        case CloudBackendType.supabase:
          return await _testSupabase(config);

        case CloudBackendType.webdav:
          return await _testWebdav(config);

        case CloudBackendType.spitoutCloud:
          return await _testSpitoutCloud(config);

        case CloudBackendType.s3:
          return await _testS3(config);
      }
    } on http.ClientException catch (e) {
      return CloudConnectionTestResult.failure(
        CloudConnectionTestError(type: CloudConnectionTestErrorType.network, rawMessage: e.message),
      );
    } catch (e) {
      // 超时等非 HTTP 异常统一按网络失败处理。
      return CloudConnectionTestResult.failure(
        CloudConnectionTestError(
          type: CloudConnectionTestErrorType.network,
          rawMessage: e.toString(),
        ),
      );
    }
  }

  /// Supabase 连接测试:查询不存在的表验证 URL 和 anon key。
  ///
  /// 200/404/406 表示连接正常且 key 有效,401/403 表示 key 无效。
  Future<CloudConnectionTestResult> _testSupabase(
    CloudServiceConfig config,
  ) async {
    final testUrl = Uri.parse(
      '${config.supabaseUrl}/rest/v1/_spitout_health_check?select=id&limit=1',
    );
    final response = await _client
        .get(
          testUrl,
          headers: {
            'apikey': config.supabaseAnonKey!,
            'Authorization': 'Bearer ${config.supabaseAnonKey}',
          },
        )
        .timeout(_timeout);

    if (response.statusCode == 200 ||
        response.statusCode == 404 ||
        response.statusCode == 406) {
      return const CloudConnectionTestResult.success();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return CloudConnectionTestResult.failure(
        const CloudConnectionTestError(type: CloudConnectionTestErrorType.authFailed),
      );
    }
    return CloudConnectionTestResult.failure(
      CloudConnectionTestError(
        type: CloudConnectionTestErrorType.serverStatus,
        statusCode: response.statusCode,
      ),
    );
  }

  /// WebDAV 连接测试:发送 OPTIONS 请求并检查 DAV/Allow 响应头。
  Future<CloudConnectionTestResult> _testWebdav(
    CloudServiceConfig config,
  ) async {
    final testUrl = Uri.parse(config.webdavUrl!);
    final credentials = base64Encode(
      utf8.encode('${config.webdavUsername}:${config.webdavPassword}'),
    );

    final request = http.Request('OPTIONS', testUrl);
    request.headers['Authorization'] = 'Basic $credentials';
    final streamedResponse = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 204) {
      if (response.headers['dav'] != null ||
          response.headers.containsKey('allow')) {
        return const CloudConnectionTestResult.success();
      }
      return CloudConnectionTestResult.failure(
        const CloudConnectionTestError(
          type: CloudConnectionTestErrorType.webdavNotSupported,
        ),
      );
    }
    if (response.statusCode == 401) {
      return CloudConnectionTestResult.failure(
        const CloudConnectionTestError(
          type: CloudConnectionTestErrorType.authFailedCredentials,
        ),
      );
    }
    if (response.statusCode == 403) {
      return CloudConnectionTestResult.failure(
        const CloudConnectionTestError(
          type: CloudConnectionTestErrorType.accessDenied,
        ),
      );
    }
    if (response.statusCode == 404) {
      return CloudConnectionTestResult.failure(
        CloudConnectionTestError(
          type: CloudConnectionTestErrorType.pathNotFound,
          path: testUrl.path,
        ),
      );
    }
    return CloudConnectionTestResult.failure(
      CloudConnectionTestError(
        type: CloudConnectionTestErrorType.serverStatus,
        statusCode: response.statusCode,
      ),
    );
  }

  /// Spitout Cloud 连接测试:初始化服务并尝试列出根目录文件。
  Future<CloudConnectionTestResult> _testSpitoutCloud(
    CloudServiceConfig config,
  ) async {
    try {
      final services = await createCloudServices(config);
      if (services.provider == null) {
        return CloudConnectionTestResult.failure(
          CloudConnectionTestError(
            type: CloudConnectionTestErrorType.initFailed,
            rawMessage: 'Spitout Cloud provider 初始化失败',
          ),
        );
      }
      await services.provider!.storage.list(path: '');
      return const CloudConnectionTestResult.success();
    } catch (e) {
      return CloudConnectionTestResult.failure(
        CloudConnectionTestError(
          type: CloudConnectionTestErrorType.initFailed,
          rawMessage: _stripExceptionPrefix(e.toString()),
        ),
      );
    }
  }

  /// S3 连接测试:初始化服务并尝试列出 bucket 对象(ListObjects)。
  Future<CloudConnectionTestResult> _testS3(
    CloudServiceConfig config,
  ) async {
    // 确保 endpoint 不含协议前缀,与配置保存时的清洗逻辑保持一致。
    final cleanedConfig = CloudServiceConfig(
      type: config.type,
      name: config.name,
      s3Endpoint: config.s3Endpoint?.replaceFirst(RegExp(r'^https?://'), ''),
      s3Region: config.s3Region,
      s3AccessKey: config.s3AccessKey,
      s3SecretKey: config.s3SecretKey,
      s3Bucket: config.s3Bucket,
      s3UseSSL: config.s3UseSSL,
      s3Port: config.s3Port,
    );
    try {
      final services = await createCloudServices(cleanedConfig);
      if (services.provider == null) {
        return CloudConnectionTestResult.failure(
          CloudConnectionTestError(
            type: CloudConnectionTestErrorType.initFailed,
            rawMessage: 'S3 provider 初始化失败',
          ),
        );
      }
      // 实际调用 S3 API 验证凭据与连接;endpoint/bucket 只进 debug 日志。
      logger.debug(
        'CloudConnectionTester',
        'S3 开始测试列出文件 endpoint=${cleanedConfig.s3Endpoint} '
            'bucket=${cleanedConfig.s3Bucket}',
      );
      await services.provider!.storage.list(path: '');
      return const CloudConnectionTestResult.success();
    } catch (e) {
      final message = _stripExceptionPrefix(e.toString());
      return CloudConnectionTestResult.failure(
        CloudConnectionTestError(
          type: CloudConnectionTestErrorType.initFailed,
          rawMessage: message,
        ),
      );
    }
  }

  /// 去掉 Dart 异常字符串里无信息的 `Exception: ` 前缀,只保留业务信息。
  String _stripExceptionPrefix(String raw) {
    var message = raw;
    if (message.contains('CloudConfigurationException:')) {
      message = message.replaceFirst('CloudConfigurationException: ', '');
    } else if (message.contains('Exception:')) {
      message = message.replaceFirst('Exception: ', '');
    }
    return message;
  }
}
