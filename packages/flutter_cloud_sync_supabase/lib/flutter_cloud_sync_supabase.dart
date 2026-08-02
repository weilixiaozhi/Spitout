/// Supabase provider for flutter_cloud_sync.
///
/// This library provides Supabase integration for the flutter_cloud_sync package,
/// enabling cloud synchronization using Supabase's storage and authentication services.
///
/// To use this library:
///
/// ```dart
/// import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';
///
/// final provider = SupabaseProvider();
/// await provider.initialize({
///   'url': 'https://your-project.supabase.co',
///   'anonKey': 'your-anon-key',
///   'bucket': 'user-data', // optional, defaults to 'storage'
/// });
/// ```
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 'src/supabase_provider.dart';

export 'src/supabase_provider.dart';
export 'src/supabase_auth_service.dart';
export 'src/supabase_storage_service.dart';
export 'src/supabase_database_service.dart';
export 'src/supabase_realtime_service.dart';

/// 把 Supabase 后端自注册到核心包的 [CloudProviderRegistry]。
///
/// 插件化约定：核心包不依赖本 adapter；由主工程 Composition Root（main.dart）
/// 调用本函数完成注册后，`createCloudServices` 才能分发到 Supabase。
/// 重复调用安全（后者覆盖前者）。
void registerSupabaseBackend() {
  CloudProviderRegistry.register(CloudBackendType.supabase, (config) async {
    // 创建并初始化 Supabase provider
    // 包内会处理重复初始化的问题
    final provider = SupabaseProvider();
    await provider.initialize({
      'url': config.supabaseUrl!,
      'anonKey': config.supabaseAnonKey!,
      'bucket': config.supabaseBucket ?? 'spitout-backups', // 兼容老配置，提供默认值
      'pathPrefix': null, // 使用默认的 users/{userId}/ 结构，基础包支持但业务层不配置
    });

    // Auth service 直接从 provider 获取
    return (provider: provider, auth: provider.auth);
  });
}
