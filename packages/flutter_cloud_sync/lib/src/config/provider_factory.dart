import '../core/auth_service.dart';
import '../core/cloud_provider.dart';
import 'cloud_provider_registry.dart';
import 'cloud_service_config.dart';

/// 根据 CloudServiceConfig 创建对应的 CloudProvider 和 CloudAuthService
///
/// 返回 (CloudProvider, CloudAuthService) 元组
///
/// 支持:
/// - Spitout Cloud / Supabase / WebDAV / S3: 由各自 adapter 包经
///   [CloudProviderRegistry] 自注册（主工程在 main.dart 调用 adapter 包的
///   `register*Backend()`）。核心包不再 import 任何 adapter，依赖方向
///   单向化：adapter → 核心。
///
/// 未注册的 adapter 后端会抛 [StateError]，提示在 Composition Root 完成注册。
Future<({CloudProvider? provider, CloudAuthService? auth})> createCloudServices(
  CloudServiceConfig config,
) async {
  if (!config.valid) {
    return (provider: null, auth: null);
  }

  switch (config.type) {
    case CloudBackendType.local:
      return (provider: null, auth: null);

    // adapter 后端（含 Spitout Cloud）：统一走注册表分发，构建逻辑
    // （配置键映射）内聚在各自 adapter 包的 register*Backend() 中，
    // 核心包不感知具体实现。
    case CloudBackendType.spitoutCloud:
    case CloudBackendType.supabase:
    case CloudBackendType.webdav:
    case CloudBackendType.s3:
      final builder = CloudProviderRegistry.builderFor(config.type);
      if (builder == null) {
        throw StateError(
          'CloudBackendType.${config.type.name} 的 adapter 尚未注册。'
          '请在应用入口（main.dart）调用对应 adapter 包的 register*Backend() '
          '完成注册后再使用云同步功能。',
        );
      }
      return builder(config);
  }
}
