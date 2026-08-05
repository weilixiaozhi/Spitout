import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';

// 同步域「叶子」provider：云服务配置 + 各类刷新 tick。
//
// 本文件不 import 任何其他 providers 子文件（特别是 database_providers.dart），
// 处于 providers 层依赖链最底端；database_providers.dart / sync_providers.dart
// 均单向依赖本文件。
// 消费方无需感知本文件：sync_providers.dart 对其做了 re-export，
// providers.dart barrel 的可见符号保持不变。

// ====== 云服务配置 ======

final cloudServiceStoreProvider = Provider<CloudServiceStore>(
  (_) => CloudServiceStore(
    // 注入 app 日志：配置解析 / 迁移失败必须可见，避免静默回退本地存储。
    logger: CloudSyncLogger(
      onLog: (level, message) {
        // 按名称映射到 app 日志级别，避免与 app 自身 LogLevel 枚举命名冲突。
        switch (level.name) {
          case 'debug':
            logger.debug('CloudStore', message);
            break;
          case 'info':
            logger.info('CloudStore', message);
            break;
          case 'warning':
            logger.warning('CloudStore', message);
            break;
          case 'error':
            logger.error('CloudStore', message);
            break;
        }
      },
    ),
  ),
);

// 当前激活配置（Future，因需读 SharedPreferences）
final activeCloudConfigProvider = FutureProvider<CloudServiceConfig>((
  ref,
) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadActive();
});

/// 云失活流程闸门（P0-b）。
///
/// 删除激活的云配置时,`_deleteConfig` 会 invalidate [activeCloudConfigProvider],
/// 而 Riverpod 的 invalidate 存在"旧值窗口":下游 rebuild 完成前,
/// [spitoutCloudProviderInstance] / [syncServiceProvider] 仍可能读到旧 Spitout
/// 配置并重建云客户端,触发 setRecoveryCredentials + currentUser 的静默重登,
/// 把刚登出的账号拉回来。
///
/// 因此失活流程必须先置 true(关闸)再 invalidate,下游在读 active 之前
/// 先查本闸门,true 直接降级 null / LocalOnly;purge 全部完成后置 false(开闸),
/// 下游因 watch 本闸门自动重建并按"已回退本地"的新配置装配。
final cloudDeactivationInProgressProvider =
    NotifierProvider<SimpleStateNotifier<bool>, bool>(
      () => SimpleStateNotifier((ref) => false),
    );

// Supabase配置(不管是否激活)
final supabaseConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadSupabase();
});

// Spitout Cloud 配置(不管是否激活)
final spitoutCloudConfigProvider = FutureProvider<CloudServiceConfig?>((
  ref,
) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadSpitoutCloud();
});

// WebDAV配置(不管是否激活)
final webdavConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadWebdav();
});

// S3配置(不管是否激活)
final s3ConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadS3();
});

// ====== 同步状态刷新 tick ======

/// 同步代数计数器：每次 pull 把远端变更写入本地 Drift 之后 +1。
/// 派生 Provider（首页交易列表/统计/账户等）watch 这个值，即可在增量同步
/// 完成后重新运行，UI 不读到旧缓存。
///
/// 为什么不直接 `ref.invalidate(watchTransactionsProvider)`：Supabase Realtime
/// 通道绑在同一个 stream provider 上，invalidate 会把通道拆掉再建，反而更慢；
/// 用一个独立 bump 计数器是最便宜的信号。
final syncGenerationProvider = NotifierProvider<TickStateNotifier, int>(
  () => TickStateNotifier((ref) => 0),
);

/// 最近一次同步错误信息（供 UI 状态栏展示）。
/// PostProcessor / SyncEngine 的 catch 分支把错误写到这里，避免 silent swallow。
final lastSyncErrorProvider =
    NotifierProvider<SimpleStateNotifier<String?>, String?>(
      () => SimpleStateNotifier((ref) => null),
    );

// 用于触发设置页同步状态的刷新（每次 +1 即可触发 FutureBuilder 重新获取）
final syncStatusRefreshProvider = NotifierProvider<TickStateNotifier, int>(
  () => TickStateNotifier((ref) => 0),
);

/// 按账本触发同步状态刷新（用于远端增量拉取后的局部刷新）
final syncStatusRefreshByLedgerProvider =
    NotifierProvider.family<TickStateNotifier, int, int>(
      (ledgerId) => TickStateNotifier((ref) => 0),
    );

/// 按账本触发页面数据刷新（减少全局刷新带来的闪烁）
final ledgerDataRefreshByLedgerProvider =
    NotifierProvider.family<TickStateNotifier, int, int>(
      (ledgerId) => TickStateNotifier((ref) => 0),
    );

/// 按账本记录"远端变更应用中"状态，用于页面局部防闪渲染
final remoteApplyInProgressByLedgerProvider =
    NotifierProvider.family<SimpleStateNotifier<bool>, bool, int>(
      (ledgerId) => SimpleStateNotifier((ref) => false),
    );
