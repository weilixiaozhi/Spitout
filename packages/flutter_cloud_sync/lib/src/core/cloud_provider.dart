import 'auth_service.dart';
import 'storage_service.dart';

/// 云服务提供方抽象接口。
///
/// 每个云服务（Supabase、WebDAV、S3 等）实现本接口，
/// 以统一方式暴露认证与存储服务。
abstract class CloudProvider {
  /// 提供方唯一标识。
  ///
  /// 用于配置存储、日志等场景。
  /// 示例：'supabase'、'webdav'、's3'。
  String get providerId;

  /// 提供方展示名称。
  ///
  /// 用于 UI 展示。
  /// 示例：'Supabase'、'WebDAV'、'AWS S3'。
  String get providerName;

  /// 认证服务实例。
  CloudAuthService get auth;

  /// 存储服务实例。
  CloudStorageService get storage;

  /// 使用配置初始化提供方。
  ///
  /// [config] - 配置参数（提供方特有）。
  ///
  /// 不同提供方需要不同配置：
  /// - Supabase: {'url': String, 'anonKey': String, 'bucket': String?}
  /// - WebDAV: {'url': String, 'username': String, 'password': String, 'remotePath': String?}
  /// - S3: {'region': String, 'accessKey': String, 'secretKey': String, 'bucket': String}
  ///
  /// 配置无效时抛出 [CloudConfigurationException]。
  Future<void> initialize(Map<String, dynamic> config);

  /// 初始化前校验配置。
  ///
  /// 在 [initialize] 之前调用可避免运行时错误。
  ///
  /// 配置有效返回 true，否则返回 false。
  bool validateConfig(Map<String, dynamic> config);

  /// 释放资源。
  ///
  /// 关闭连接、清理缓存等；切换提供方或应用退出时应调用。
  Future<void> dispose();
}
