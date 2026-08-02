/// S3 provider for flutter_cloud_sync
///
/// Supports all S3-compatible storage services:
/// - AWS S3
/// - Cloudflare R2
/// - Backblaze B2
/// - MinIO (self-hosted)
/// - Aliyun OSS
/// - Tencent COS
/// - Qiniu Kodo
///
/// ## Usage
///
/// ```dart
/// import 'package:flutter_cloud_sync_s3/flutter_cloud_sync_s3.dart';
///
/// final provider = S3Provider();
/// await provider.initialize({
///   'endpoint': '<account-id>.r2.cloudflarestorage.com',
///   'region': 'auto',
///   'accessKey': 'your-access-key',
///   'secretKey': 'your-secret-key',
///   'bucket': 'spitout-data',
///   'useSSL': true,
/// });
/// ```
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 'src/s3_provider.dart';

export 'src/s3_provider.dart';
export 'src/s3_exceptions.dart';

/// 把 S3 后端自注册到核心包的 [CloudProviderRegistry]。
///
/// 插件化约定：核心包不依赖本 adapter；由主工程 Composition Root（main.dart）
/// 调用本函数完成注册后，`createCloudServices` 才能分发到 S3。
/// 重复调用安全（后者覆盖前者）。
void registerS3Backend() {
  CloudProviderRegistry.register(CloudBackendType.s3, (config) async {
    // S3 初始化 - 不捕获异常，让错误向上传递以便调试
    final provider = S3Provider();
    await provider.initialize({
      'endpoint': config.s3Endpoint!,
      'region': config.s3Region ?? 'us-east-1',
      'accessKey': config.s3AccessKey!,
      'secretKey': config.s3SecretKey!,
      'bucket': config.s3Bucket!,
      'useSSL': config.s3UseSSL ?? true,
      'port': config.s3Port,
    });

    // Auth service 直接从 provider 获取
    return (provider: provider, auth: provider.auth);
  });
}
