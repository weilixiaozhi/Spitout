import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/services/cloud/cloud_connection_tester.dart';
import 'package:spitout/services/import/data_import_service.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/sync/sync_state_providers.dart';

// 云用户 DTO 经 providers 层 barrel 转发给 UI，data 层不反向依赖 cloud 层。
export 'package:spitout/cloud/spitout_cloud.dart' show CloudUser;
// 连接测试服务经本文件暴露,页面只 import providers,不直接触碰 services/http。
export 'package:spitout/services/cloud/cloud_connection_tester.dart'
    show
        CloudConnectionTester,
        CloudConnectionTestResult,
        CloudConnectionTestError,
        CloudConnectionTestErrorType;

/// 云服务连接测试器 provider:页面读取后调用 [CloudConnectionTester.test],
/// 网络探测逻辑在 services 层,可复用、可单测。
final cloudConnectionTesterProvider = Provider<CloudConnectionTester>(
  (_) => CloudConnectionTester(),
);

// providers 层「叶子」模块：云客户端基础设施 provider。
//
// 本文件承载云客户端实例 / SyncEngine / ChangeTracker / Auth 等基础设施级
// provider，只依赖 sync_state_providers（配置叶子）与 database_providers
// （数据层装配），不 import 任何域 provider / 编排模块。
//
// 消费方无需感知本文件：sync_providers.dart 对其做了 re-export，
// providers.dart barrel 的可见符号保持不变。

/// ChangeTracker provider
final changeTrackerProvider = Provider<ChangeTracker>((ref) {
  final db = ref.watch(databaseProvider);
  return ChangeTracker(db);
});

/// SyncEngine provider（需要已认证的 SpitoutCloudSyncBackend）。
///
/// 全 app 唯一来源。`syncServiceProvider`、`shared_ledger_providers.dart`、
/// `join_shared_ledger_page.dart` 都通过这个 family 拿同一个 engine 实例
/// (family key=cloudProvider 命中相同缓存)。否则两个独立 engine 各跑各的
/// sync,同一 ledger 1 秒内可能 2-3 次 sync。
///
/// 生命周期（autoDispose）：
/// - 正常运行期由 `syncServiceProvider` watch 本 family，entry 常驻；
/// - 登录 / 切换账号 / 云失活时 `syncServiceProvider` 随配置重建、停止 watch
///   旧 key，Riverpod 立即 GC 旧 entry 并调用 `ref.onDispose` → engine.dispose()
///   （停 WS + 关事件流），避免旧引擎与 WebSocket 在容器销毁前无限累积。
/// - 各 UI 动作函数（shared_ledger / ledger_storage 等）只 `ref.read` 不持有，
///   但它们在云激活态下必然有 `syncServiceProvider` 这个常驻 watcher 保活，
///   不会被中途 dispose；测试经 overrideWith 注入桩引擎时无 onDispose，同样安全。
final syncEngineProvider = Provider.autoDispose
    .family<SyncEngine, SpitoutCloudSyncBackend>((ref, provider) {
      final db = ref.watch(databaseProvider);
      final tracker = ref.watch(changeTrackerProvider);
      final repo = ref.watch(repositoryProvider);
      final engine = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: tracker,
        repo: repo,
        dataImportPort: dataImportService,
      );
      ref.onDispose(() => engine.dispose());
      return engine;
    });

/// 同步引擎状态（区别于 sync_service.dart 中的 SyncStatus）
final syncEngineStatusProvider =
    NotifierProvider<SimpleStateNotifier<SyncEngineStatus>, SyncEngineStatus>(
      () => SimpleStateNotifier((ref) => SyncEngineStatus.idle),
    );

/// 未推送变更数量
final unpushedChangeCountProvider = FutureProvider<int>((ref) async {
  final tracker = ref.watch(changeTrackerProvider);
  return tracker.getUnpushedCount();
});

/// 云认证服务：按当前激活配置构造，本地模式 / 初始化失败一律降级
/// NoopAuthService，调用方无需判空。
///
/// 设计意图：Spitout Cloud 分支复用
/// [spitoutCloudProviderInstance] 已构造好的 provider 里的 auth，
/// 而不是新建独立实例。这样 SyncEngine、2FA 行、本区块账号行都拿到「同一个」
/// SpitoutCloudAuthService 实例（含同一个 _authStateController +
/// setRecoveryCredentials 注入的邮密），登录 / 登出事件才能驱动 UI 即时刷新 ——
/// 若各用独立 auth 实例则各发各的事件，UI 收不到登录态变化。
/// 其它后端仍各自 createCloudServices。
final authServiceProvider = FutureProvider<CloudAuthService>((ref) async {
  final activeAsync = ref.watch(activeCloudConfigProvider);
  if (!activeAsync.hasValue) {
    return NoopAuthService();
  }

  final config = activeAsync.value!;
  if (!config.valid || config.type == CloudBackendType.local) {
    return NoopAuthService();
  }

  if (config.type == CloudBackendType.spitoutCloud) {
    // 统一实例：直接取已初始化 provider 的 auth（已含静默恢复凭证）。
    final providerAsync = ref.watch(spitoutCloudProviderInstance);
    if (providerAsync.hasValue && providerAsync.value != null) {
      try {
        // provider.auth getter 在 _auth 未初始化时会抛 CloudConfigurationException，
        // 用 try/catch 兜底降级为 Noop，防止未来改动引入回归（非 null provider 时不会抛）。
        return providerAsync.value!.auth;
      } catch (e, st) {
        logger.warning('CloudSync', '读取 SpitoutCloudProvider.auth 失败: $e', st);
      }
    }
    return NoopAuthService();
  }

  try {
    final services = await createCloudServices(config);
    if (services.auth != null) {
      return services.auth!;
    }
  } catch (e) {
    // 初始化失败，返回 NoopAuthService
  }

  return NoopAuthService();
});

/// 当前登录用户流：Spitout Cloud 登录 / 登出 / session 静默恢复后自动推送新值，
/// 驱动账号行、2FA 行、同步状态面板即时刷新（无需退出重进）。
///
/// 为什么不直接 watch [CloudAuthService.authStateChanges]：它是广播流，订阅时
/// 不补发当前态（initialize() 期间的 _emitCurrentUser() 事件已丢失），已登录重进
/// 页面会卡 AsyncLoading。所以先以 [CloudAuthService.currentUser] 快照作首屏种子，
/// 再跟随后续实时事件（见 [_seedThenFollow]）。
///
/// 非 Spitout Cloud / 未初始化 / 降级为 Noop 时，单发一个 null 让 UI 直接呈现
/// 「未登录」态（登录按钮），避免空流导致 StreamProvider 永远停在 loading。
final cloudCurrentUserProvider = StreamProvider<CloudUser?>((ref) {
  final authAsync = ref.watch(authServiceProvider);
  // auth 尚未就绪：保持 loading（authServiceProvider 解析后会自动重跑本 provider）。
  if (!authAsync.hasValue) return const Stream<CloudUser?>.empty();
  final auth = authAsync.value!;
  if (auth is NoopAuthService) {
    // 无有效 auth：单发 null，UI 直接走未登录分支。
    return Stream<CloudUser?>.value(null);
  }
  return _seedThenFollow(auth);
});

/// 先补发当前登录态快照作为首屏种子，再跟随后续登录 / 登出事件。
Stream<CloudUser?> _seedThenFollow(CloudAuthService auth) async* {
  yield await auth.currentUser; // 首屏种子：已登录态重进页面 / provider 重建时立即正确
  yield* auth.authStateChanges; // 后续实时事件：登录 / 登出 / token 静默恢复
}

/// 已初始化的 SpitoutCloudSyncBackend 实例
/// 用于 SyncEngine 和其他需要直接访问 Spitout Cloud API 的场景
///
/// 保持非 autoDispose：它不是 family，单槽位重建不会累积旧实例；且大量 UI
/// 组件 watch 它，autoDispose 反而会造成频繁重建。旧云客户端的释放由
/// [syncEngineProvider]（以实例为 key 的 autoDispose family）负责——旧 entry
/// 被 GC 时即释放该实例引用。
final spitoutCloudProviderInstance = FutureProvider<SpitoutCloudSyncBackend?>((
  ref,
) async {
  // 云失活闸门:云失活流程进行中(invalidate 旧值窗口)即使 active 仍持旧
  // Spitout 配置,也必须直接降级 null —— 绝不重建云客户端。否则
  // setRecoveryCredentials + currentUser 会用旧邮密静默重登,
  // 把已登出的账号拉回来(复活链)。
  if (ref.watch(cloudDeactivationInProgressProvider)) return null;

  final configAsync = ref.watch(activeCloudConfigProvider);
  if (!configAsync.hasValue) return null;

  final config = configAsync.value!;
  if (!config.valid || config.type != CloudBackendType.spitoutCloud) {
    return null;
  }

  try {
    // 经可覆盖工厂获取服务实例:运行时为真实 createCloudServices,
    // 测试经 cloudServicesFactoryProvider.overrideWith 注入桩,无需触网即可
    // 断言"闸门开启期间工厂不被调用"。
    final services = await ref.read(cloudServicesFactoryProvider)(config);
    if (services.provider is! SpitoutCloudSyncBackend) return null;
    final provider = services.provider as SpitoutCloudSyncBackend;

    final account = config.spitoutCloudAccount;

    // 密码不持久化（见 CloudServiceStore），因此只注入账号用于日志兜底；
    // session 失效后由用户手动重新登录，避免明文密码落盘。
    if (services.auth is SpitoutCloudAuthService) {
      (services.auth as SpitoutCloudAuthService).setRecoveryCredentials(
        account: account,
      );
    }

    // 构造之后也触发一次 currentUser，让 initialize() 没恢复出 session 的
    // 场景立刻按未登录处理，减少用户第一次操作时的卡顿感。
    // currentUser 内部已经自带 _tryRecoveryLogin（密码为空时直接跳过）。
    if (services.auth != null) {
      try {
        final user = await services.auth!.currentUser;
        if (user != null) {
          logger.info(
            'CloudSync',
            'Spitout Cloud session ready: ${user.account}',
          );
        } else if (account != null && account.isNotEmpty) {
          logger.info('CloudSync', 'Spitout Cloud 未登录,等首次 API 触发恢复');
        }
      } catch (e, st) {
        logger.warning('CloudSync', 'Spitout Cloud 初始 currentUser 失败: $e', st);
      }
    }
    return provider;
  } catch (e, st) {
    logger.error('CloudSync', 'SpitoutCloudProvider 初始化失败', e, st);
  }
  return null;
});

/// 可覆盖的云服务工厂（测试桩唯一入口）。
///
/// 默认委托给包级顶层函数 [createCloudServices]；页面里的 Spitout 登录块通过
/// 本 provider 拿到「配置 → (provider, auth)」的服务实例，而测试可经 `overrideWith`
/// 注入桩函数（例如返回带 `signInWithAccount` 断言的 Fake auth），从而不触网地验证
/// 「保存并切换时登录」与「暂不切换时不登录」两个分支。运行时永远走真实实现。
///
/// 之所以不直接暴露 [createCloudServices]（它是顶层函数无法被 Riverpod override），
/// 而是包成 Provider 持有工厂函数，是为了让 Widget 测试能无侵入地替换实现。
final cloudServicesFactoryProvider =
    Provider<
      Future<({CloudProvider? provider, CloudAuthService? auth})> Function(
        CloudServiceConfig,
      )
    >(
      (ref) =>
          (config) => createCloudServices(config),
    );
