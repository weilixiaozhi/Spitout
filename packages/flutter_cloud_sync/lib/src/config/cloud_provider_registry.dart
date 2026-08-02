import '../core/auth_service.dart';
import '../core/cloud_provider.dart';
import 'cloud_service_config.dart';

/// 云服务构建结果：provider + auth 元组（与 createCloudServices 返回类型一致）
typedef CloudServices = ({CloudProvider? provider, CloudAuthService? auth});

/// adapter 后端构建器签名：按 [CloudServiceConfig] 创建并初始化对应后端的
/// [CloudProvider] 与 [CloudAuthService]。
typedef CloudServicesBuilder = Future<CloudServices> Function(
  CloudServiceConfig config,
);

/// 云后端注册表（插件化核心）。
///
/// 设计意图：核心包只定义抽象接口与本注册表，**不依赖任何 adapter 包**；
/// 各 adapter 包（supabase / webdav / s3 …）在自己的库入口暴露
/// `register*Backend()` 顶层函数，由主工程 Composition Root（main.dart）
/// 显式调用完成自注册。由此彻底拆除「核心 ↔ adapter」的包级循环依赖，
/// 依赖方向变为 adapter → 核心 ← 主工程，单向无环。
class CloudProviderRegistry {
  CloudProviderRegistry._();

  static final Map<CloudBackendType, CloudServicesBuilder> _builders = {};

  /// 注册 [type] 后端的构建器。重复注册时后者覆盖前者（测试可借此替换 mock）。
  static void register(CloudBackendType type, CloudServicesBuilder builder) {
    _builders[type] = builder;
  }

  /// 注销 [type] 后端的构建器（主要供测试清理用）。
  static void unregister(CloudBackendType type) {
    _builders.remove(type);
  }

  /// 查询 [type] 后端是否已注册。
  static bool isRegistered(CloudBackendType type) =>
      _builders.containsKey(type);

  /// 取 [type] 后端的构建器；未注册时返回 null。
  static CloudServicesBuilder? builderFor(CloudBackendType type) =>
      _builders[type];
}
