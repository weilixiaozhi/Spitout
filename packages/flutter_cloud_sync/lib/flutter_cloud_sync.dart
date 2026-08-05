/// Flutter Cloud Sync
///
/// 模块化云同步框架，支持可插拔后端提供方。
///
/// ## 特性
///
/// - 🔌 可插拔架构 - 自由选择云提供方（Supabase、WebDAV、S3 等）
/// - 🔄 自动同步 - 自动检测并同步本地 / 云端变更
/// - 🎯 业务无关 - 通过序列化接口适配任意数据模型
/// - 🔐 认证 - 内置认证服务抽象
/// - 📦 类型安全 - 泛型设计，全类型安全
/// - 🎭 状态管理 - 面向 Riverpod 集成设计
/// - 📝 完备日志 - 可接入现有日志框架
///
/// ## 快速开始
///
/// ```dart
/// import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
///
/// // 1. 定义数据序列化器
/// class MyDataSerializer implements DataSerializer<int> {
///   @override
///   Future<String> serialize(int ledgerId) async {
///     final data = await db.getData(ledgerId);
///     return jsonEncode(data);
///   }
///
///   @override
///   Future<int> deserialize(String data) async {
///     final json = jsonDecode(data);
///     return json['ledgerId'] as int;
///   }
///
///   @override
///   String fingerprint(String data) {
///     return sha256.convert(utf8.encode(data)).toString();
///   }
/// }
///
/// // 2. 初始化云提供方
/// final provider = SupabaseProvider(); // 来自 flutter_cloud_sync_supabase
/// await provider.initialize({
///   'url': 'https://your-project.supabase.co',
///   'anonKey': 'your-anon-key',
/// });
///
/// // 3. 创建同步管理器
/// final syncManager = CloudSyncManager<int>(
///   provider: provider,
///   serializer: MyDataSerializer(),
///   logger: CloudSyncLogger(onLog: (level, message) {
///     print('[$level] $message');
///   }),
/// );
///
/// // 4. 使用
/// await syncManager.upload(ledgerId: 123, path: 'ledgers/123.json');
/// final status = await syncManager.getStatus(ledgerId: 123, path: 'ledgers/123.json');
/// ```
///
/// ## 可用提供方
///
/// 按需安装所需提供方：
///
/// - `flutter_cloud_sync_supabase` - Supabase 后端
/// - `flutter_cloud_sync_webdav` - WebDAV 后端
/// - `flutter_cloud_sync_s3` - AWS S3 后端
/// - `flutter_cloud_sync_spitout_cloud` - Spitout Cloud 后端
///
library;

// Core interfaces
export 'src/core/auth_service.dart';
export 'src/core/cloud_provider.dart';
export 'src/core/data_serializer.dart';
export 'src/core/database_service.dart';
export 'src/core/exceptions.dart';
export 'src/core/realtime_service.dart';

// 只暴露存储接口契约，内部 Noop 实现类不对外导出
export 'src/core/storage_service.dart' show CloudStorageService, CloudFile;
export 'src/core/sync_status.dart';

// Configuration
export 'src/config/cloud_service_config.dart';
export 'src/config/cloud_credential_storage.dart';
export 'src/config/cloud_service_store.dart';
export 'src/config/cloud_provider_registry.dart';
export 'src/config/provider_factory.dart';

// Utilities
export 'src/utils/logger.dart';
export 'src/utils/path_helper.dart';

// Manager
export 'src/manager/cloud_sync_manager.dart';
