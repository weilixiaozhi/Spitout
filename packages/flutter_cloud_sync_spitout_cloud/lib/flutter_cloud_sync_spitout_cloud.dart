/// Spitout Cloud provider for [flutter_cloud_sync].
///
/// 独立 Adapter 包：从核心包 `flutter_cloud_sync` 迁移出的
/// Spitout Cloud 私有协议实现，经 `CloudProviderRegistry` 自注册。
///
/// 依赖方向：本包 → 核心包（单向），核心包不反向依赖本包。
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'src/spitout_cloud_provider.dart' as impl;

export 'src/spitout_cloud_provider.dart';

/// 把 Spitout Cloud 后端自注册到核心包的 [CloudProviderRegistry]。
///
/// 插件化约定：核心包不依赖本 adapter；由主工程 Composition Root（main.dart）
/// 调用本函数完成注册后，`createCloudServices` 才能分发到 Spitout Cloud。
/// 重复调用安全（后者覆盖前者）。
/// 把 Spitout Cloud 后端自注册到核心包的 [CloudProviderRegistry]。
///
/// [sessionStore] 仅在测试 / 特殊宿主需要覆盖默认安全存储时传入;
/// 不传则生产路径默认使用系统安全存储(Keychain / Keystore)。
void registerSpitoutCloudBackend(
    {impl.SpitoutCloudSessionStore? sessionStore}) {
  CloudProviderRegistry.register(CloudBackendType.spitoutCloud, (config) async {
    // 创建并初始化 Spitout Cloud provider
    final provider = impl.SpitoutCloudProvider();
    await provider.initialize({
      'baseUrl': config.spitoutCloudBaseUrl!,
      'apiPrefix': config.spitoutCloudApiPrefix ?? '/api/v1',
      if (sessionStore != null) 'sessionStore': sessionStore,
    });

    // Auth service 直接从 provider 获取
    return (provider: provider, auth: provider.auth);
  });
}
