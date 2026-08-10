import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/cloud/sync/transactions_sync_manager.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'sync_providers.dart';

/// App 启动同步收敛器：App 侧统一通过
/// `ref.read(appStartupSyncProvider).start()` 触发启动期同步。
///
/// 设计意图：
/// - listenManual 必须在 provider build 期间同步注册（Riverpod 约束），故放在构造函数
///   —— appStartupSyncProvider 常驻（非 autoDispose），App 生命周期内监听不失效。
/// - 冷启动 eager-await spitoutCloudProviderInstance：该 FutureProvider 若无人读取，
///   SpitoutCloudAuthService.initialize() 不会执行，session 无法从 SharedPreferences
///   恢复，故启动时显式等待其就绪。
/// - 5 秒幂等节流：启动期 microtask 与 listenManual 两路可能同时触发，
///   fullPush/push 内部 in-flight 单飞之外的第二层防御，避免 Phase 1 重复跑浪费 HTTP。
class AppStartupSync {
  AppStartupSync(this._ref) {
    // 持续监听 syncServiceProvider：即使第一次读到的是 LocalOnly（配置尚未加载）
    // 也能在 SyncEngine 实例就绪后再触发一次同步。
    // 注意用 `listen` 而非 `listenManual`：AppStartupSync 在 provider build 期间
    // 构造（appStartupSyncProvider 常驻非 autoDispose），此时 `Ref.listen` 是合法
    // 的；`listenManual` 只存在于 WidgetRef，`Ref` 上没有该方法。
    _ref.listen<SyncService>(
      syncServiceProvider,
      (prev, next) {
        if (prev is SyncEngine || next is! SyncEngine) return;
        _triggerInitialCloudSync(next);
      },
      fireImmediately: false,
    );
  }

  final Ref _ref;

  // _triggerInitialCloudSync 节流戳：5 秒内只跑第一次。
  DateTime? _lastInitialCloudSyncTriggeredAt;

  /// App 冷启动时调用一次，触发统一的启动同步。
  void start() {
    // 冷启动时先 eager-await spitoutCloudProviderInstance 一次，强制让这个
    // FutureProvider 真正跑起来。否则只是"被定义"但没人读，
    // SpitoutCloudAuthService.initialize() 永远不会跑，session 无法从
    // SharedPreferences 恢复，登录状态在冷启动时失效。后面的 listenManual
    // 再做后续响应式逻辑。
    Future.microtask(() async {
      try {
        await _ref.read(spitoutCloudProviderInstance.future);
      } catch (_) {
        // 非 Spitout Cloud 配置或初始化失败：忽略，让下面的 listenManual 兜住。
      }
    });

    // 启动同步走 microtask 而非 addPostFrameCallback：让 sync 在首屏渲染前
    // 抢占主线程，使 ticker bump 与首屏渲染叠加为单次加载，避免首屏渲染后
    // 再触发 cascade rebuild 造成的二次绘制感。
    Future.microtask(() async {
      try {
        final syncService = _ref.read(syncServiceProvider);
        if (syncService is TransactionsSyncManager) {
          // 快照型后端：刷新全部账本的远端同步状态 + 账本列表 UI tick。
          await syncService.refreshAllLedgersStatus();
          _ref.read(ledgerListRefreshProvider.notifier).tick();
        } else if (syncService is SyncEngine) {
          // 增量型后端：账户级首次同步（含 5 秒节流防重复）。
          _triggerInitialCloudSync(syncService);
        }
      } catch (e) {
        // 静默失败,不影响 App 启动
      }
    });
  }

  /// 账户级首次同步：统一走 [SyncAccountResult]，内部自带
  ///   Phase 1 — 用户级一次性(profile / storage.list / pull('') /
  ///             pushUserGlobalEntities,跨账本共享)
  ///   Phase 2 — 每个云端账本(fast-skip / fullPush / 增量 push + pull)
  /// 与云同步页下拉 refresh() 共用同一入口，决策逻辑只存在引擎一处。
  void _triggerInitialCloudSync(SyncEngine engine) {
    // 5 秒幂等节流:microtask + listenManual 在启动期可能两路都触发,这里挡掉
    // 第二次,phase 1 / phase 2 都只跑一次。
    final now = DateTime.now();
    final last = _lastInitialCloudSyncTriggeredAt;
    if (last != null && now.difference(last).inSeconds < 5) {
      logger.info('AppStart',
          '_triggerInitialCloudSync 5 秒内已触发过(${now.difference(last).inMilliseconds}ms 前),跳过');
      return;
    }
    _lastInitialCloudSyncTriggeredAt = now;

    Future(() async {
      try {
        final ledgers = await _ref.read(repositoryProvider).getAllLedgers();
        if (ledgers.isEmpty) {
          logger.info('AppStart', '本地无账本,跳过首次同步');
          return;
        }
        logger.info('AppStart',
            'Spitout Cloud 首次同步: 本地账本数=${ledgers.length}');

        final result = await engine.syncAccount();
        logger.info('AppStart',
            'Spitout Cloud 首次同步完成: synced=${ledgers.length - result.skipped} '
            'skipped=${result.skipped} pushed=${result.pushed} '
            'pulled=${result.pulled} 总耗时 ${result.elapsedMs}ms');
        _ref.read(syncStatusRefreshProvider.notifier).tick();
        _ref.read(ledgerListRefreshProvider.notifier).tick();
      } catch (e, st) {
        logger.error('AppStart', 'Spitout Cloud 首次同步异常', e, st);
      }
    });
  }
}

/// 启动同步收敛器的 provider 入口（非 autoDispose：App 生命周期内常驻监听）。
final appStartupSyncProvider = Provider<AppStartupSync>((ref) {
  return AppStartupSync(ref);
});
