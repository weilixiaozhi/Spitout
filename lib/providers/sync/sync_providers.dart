import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/cloud/spitout_cloud.dart';
import '../../cloud/sync/sync_service.dart';
import '../../cloud/sync/sync_coordinator.dart';
import '../../cloud/sync/sync_engine.dart';
import '../../cloud/sync/transactions_sync_manager.dart';
import '../../cloud/sync/snapshot_sync_coordinator.dart';
import '../../core/logging/logger_service.dart';
import '../../services/storage/avatar_storage.dart';
import '../../services/backup/local_backup_service.dart';
import 'package:spitout/providers/ui/theme_providers.dart';
import 'package:spitout/providers/statistics/calendar_providers.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/ui/avatar_providers.dart';
import 'package:spitout/providers/statistics/statistics_providers.dart';
import 'package:spitout/providers/sync/sync_state_providers.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/sync/ledger_list_providers.dart';
import 'package:spitout/providers/core/refresh_ticks.dart';

// 叶子 provider 统一定义在独立叶子模块：sync_state_providers.dart（云配置 +
// 同步 tick）、refresh_ticks.dart（跨域刷新 tick + 首屏缓存）、
// cloud_client_providers.dart（云客户端 / SyncEngine 基础设施）、
// ledger_list_providers.dart（账本列表）。这里 re-export 保持
// providers.dart barrel 的可见符号不变，消费方无感。
export 'package:spitout/providers/sync/sync_state_providers.dart';
export 'package:spitout/providers/core/refresh_ticks.dart';
export 'package:spitout/providers/sync/cloud_client_providers.dart';
export 'package:spitout/providers/sync/ledger_list_providers.dart';
// 账本归属操作（本地 ↔ Spitout Cloud 的移动 / 复制），账本管理页直接消费。
export 'package:spitout/providers/sync/ledger_storage_providers.dart';

/// SyncEngine 对外广播事件流。
///
/// SyncEngine 完成各阶段操作后向 events stream emit [SyncEvent],
/// UI caller 通过订阅本 provider 获取同步事件并触发对应的刷新逻辑。
///
/// 不是 SyncEngine 模式时返空 stream,订阅者拿不到事件即可。
final StreamProvider<SyncEvent> syncEventStreamProvider =
    StreamProvider<SyncEvent>((ref) {
  final svc = ref.watch(syncServiceProvider);
  if (svc is! SyncEngine) {
    return const Stream<SyncEvent>.empty();
  }
  return svc.events;
});

// 同步状态（根据 ledgerId 与刷新 tick 缓存），避免因 UI 重建重复拉取
final syncStatusProvider =
    FutureProvider.family<SyncStatus, int>((ref, ledgerId) async {
  final sync = ref.watch(syncServiceProvider);
  // 依赖 tick，使得手动刷新时重新获取；否则保持缓存
  ref.watch(syncStatusRefreshProvider);
  ref.watch(syncStatusRefreshByLedgerProvider(ledgerId));

  final status = await sync.getStatus(ledgerId: ledgerId);

  // 写入最近一次成功值，供 UI 在刷新期间显示旧值，避免闪烁
  ref.read(lastSyncStatusProvider(ledgerId).notifier).state = status;
  return status;
});

// 最近一次同步状态缓存（按 ledgerId）
final lastSyncStatusProvider =
    StateProvider.family<SyncStatus?, int>((ref, ledgerId) => null);

// 自动同步开关：值与设置
final autoSyncValueProvider = FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool('auto_sync') ?? false;
});

class AutoSyncSetter {
  AutoSyncSetter(this._ref);
  final Ref _ref;
  Future<void> set(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', v);
    // 使缓存失效，触发读取最新值
    _ref.invalidate(autoSyncValueProvider);
  }
}

final autoSyncSetterProvider = Provider<AutoSyncSetter>((ref) {
  return AutoSyncSetter(ref);
});

// ====== SyncEngine 装配（providers 层编排）======
//
// Riverpod 装配代码属于 providers 层；cloud/ 层只保留 SyncEngine /
// ChangeTracker 等纯类。

// 基础设施级 provider（changeTrackerProvider / syncEngineProvider /
// syncEngineStatusProvider / unpushedChangeCountProvider / authServiceProvider /
// spitoutCloudProviderInstance）定义于叶子模块 cloud_client_providers.dart；
// 各域 provider 只需 import 叶子拿云客户端，不必 import 本编排文件
// （本文件 re-export 它们，消费方无感）。

// 防重入锁：避免 Provider 重建导致多个自动同步并发执行
bool _autoSyncInProgress = false;

final syncServiceProvider = Provider<SyncService>((ref) {
  // LocalOnly 模式也要支持「删除账本」(deleteLedgerGlobally 的纯本地分支)。
  // 传惰性解析器而非 watch(repositoryProvider):删除是极低频操作,
  // 不应让 syncServiceProvider 的每次构建都实例化数据库仓库
  // (widget 测试中还会触发 LoggerService 定时器导致 pending timer)。
  LocalOnlySyncService buildLocalOnly() =>
      LocalOnlySyncService(repoResolver: () => ref.read(repositoryProvider));

  // P0-b 闸门:云失活流程进行中(invalidate 旧值窗口)即使 active 仍持旧
  // Spitout 配置,也必须立即降级本地 —— 不得重建 SyncEngine / 重连 WS,
  // 否则静默重登会把已登出的账号拉回来。
  if (ref.watch(cloudDeactivationInProgressProvider)) return buildLocalOnly();

  final activeAsync = ref.watch(activeCloudConfigProvider);
  if (!activeAsync.hasValue) return buildLocalOnly();

  final config = activeAsync.value!;
  if (!config.valid || config.type == CloudBackendType.local) {
    return buildLocalOnly();
  }

  // Spitout Cloud → SyncEngine（增量同步）
  if (config.type == CloudBackendType.spitoutCloud) {
    final providerAsync = ref.watch(spitoutCloudProviderInstance);
    if (!providerAsync.hasValue || providerAsync.value == null) {
      // Provider 尚未初始化，返回 LocalOnly 等待
      return buildLocalOnly();
    }
    final cloudProvider = providerAsync.value!;
    final db = ref.watch(databaseProvider);
    // SyncEngine 改走 family 缓存唯一实例 — 跟 shared_ledger_providers.dart
    // / join_shared_ledger_page.dart 共享同一 engine。否则两个独立 engine
    // 各跑各的 sync(同一 ledger 1 秒内 2-3 次)。disposal 归 family,这里
    // 不 ref.onDispose(engine.dispose())。
    final engine = ref.watch(syncEngineProvider(cloudProvider));

    // 订阅 SyncEvent stream,把同步事件 dispatch 到对应的 provider bump / invalidate。
    //
    // SyncEngine 完全不知道 Riverpod / widget 存在,只往 events stream 写;
    // 本 listener 把事件 dispatch 到对应的 provider bump / invalidate。
    //
    // 直接订阅 `engine.events` 而不是走 [syncEventStreamProvider] —— 否则会跟
    // syncServiceProvider 形成循环依赖(syncEventStreamProvider 需要 watch
    // syncServiceProvider 拿 engine,syncServiceProvider 又 listen
    // syncEventStreamProvider,运行时 Riverpod 抛 CircularDependencyError)。
    // syncEventStreamProvider 仍然存在,留给 UI/测试直接订阅 SyncEvent 用,
    // 跟本 listener 互不冲突。
    //
    // 事件处理逻辑:
    //   - PullCompleted:每次 auto-pull 都 fire(含空 pull),用于刷新各域 tick;
    //     `sharedResourceRefreshProvider` 故意不在这里 bump 避免 home 全局刷新,
    //     它走单独的 SharedResourceChanged event。
    //   - SharedResourceChanged:Owner 共享资源(分类/账户/标签)变了,Editor 端
    //     SharedLedger* 镜像表已更新,UI 应重建。
    //   - AvatarChanged:只在真下载新头像时 fire,不是每次 pull 都触发,避免
    //     冷启动头像闪一下。
    //   - ProfileFieldApplied:server 下来的 appearance/displayName
    //     回写本地 Riverpod state + SharedPreferences。
    final eventSub = engine.events.listen((event) {
      switch (event) {
        case PullCompleted(:final applied):
          // pulled=0 是大量"空 sync"场景的常态:WS 重连、connectivity 恢复、
          // 自我推送回声被过滤掉、profile_change 触发的 pull、新设备首次绑定
          // 后又被触发的 sync 等等。这些场景下没有任何实质数据变化,如果照样
          // bump 一堆 refresh tick → home/统计/预算/StreamBuilder 全部 cascade
          // rebuild,体感就是"莫名其妙首页全量刷一次"。
          //
          // 真有数据被 apply 时(applied > 0)才走完整刷新链。
          if (applied == 0) break;
          // 同步 bump — PullCompleted 事件触发各域刷新。配合
          // SyncEngine 的 broadcast(sync: true),listener 收到 emit 后立即同步
          // 执行 state 变更,Flutter framework 把所有 markNeedsBuild 合并到当前
          // 帧的同一次 rebuild,不会跨帧 cascade。
          ref.read(syncStatusRefreshProvider.notifier).state++;
          ref.read(ledgerListRefreshProvider.notifier).state++;
          // currentLedgerProvider 已是 StreamProvider(Drift watch 自动推送),
          // 此 invalidate 仅作防御性重订阅(如流曾进入 error 态),正常路径冗余无害。
          ref.invalidate(currentLedgerProvider);
          ref.read(syncGenerationProvider.notifier).state++;
          ref.read(statsRefreshProvider.notifier).state++;
          ref.read(calendarRefreshProvider.notifier).state++;
          // 切到 Stream 模式 — 否则 Drift 已更新但 TransactionList 仍用
          // Splash 阶段 cache 住的 accountName。不清 cachedTransactionsProvider:
          // 切到 stream 模式后 cache 不被读取,留旧值给到 stream 推送之前
          // 平滑过渡。
          ref.read(homeSwitchToStreamProvider.notifier).state++;
        case PushCompleted(:final pushed):
          // 本地变更已上传到 server:同步状态从「本地有更新」→「已同步」。
          // 只 bump syncStatusRefresh —— 「我的」页和账本卡片的同步状态都走
          // syncStatusProvider 单独获取(见 ledger_card 注释),它 watch
          // syncStatusRefresh 即会重算。push 不改本地展示数据,不需要账本列表
          // /统计等全域 cascade。
          if (pushed > 0) {
            ref.read(syncStatusRefreshProvider.notifier).state++;
          }
        case LedgersPurged():
          // 云端下线已全量清共享账本:当前账本可能刚被删,重指第一个。
          // listener 是 sync:true 广播的同步回调,不能 await;用 catchError
          // 兜底 fire-and-forget,避免 selectFirstLedger 内部异常冒泡打断
          // 后续 invalidate。
          selectFirstLedger(ref.read).catchError((Object e, StackTrace st) {
            logger.error('SyncProvider', 'LedgersPurged 重指账本失败: $e', e, st);
          });
          ref.invalidate(localLedgersProvider);
          ref.read(ledgerListRefreshProvider.notifier).state++;
          ref.invalidate(currentLedgerProvider);
          ref.read(cachedTransactionsProvider.notifier).state = null;
        case SharedResourceChanged():
          ref.read(sharedResourceRefreshProvider.notifier).state++;
        case AvatarChanged():
          ref.read(avatarRefreshProvider.notifier).state++;
        case ProfileFieldApplied(:final field, :final value):
          switch (field) {
            case ProfileField.appearance:
              _applyAppearanceFromServer(ref, value as Map<String, dynamic>);
            case ProfileField.displayName:
              _applyDisplayNameFromServer(ref, value as String);
          }
      }
    });

    // auto sync 是账户级(syncAccount),不依赖当前 ledgerId,故不注入
    // ledgerIdResolver;切账本兜底触发在下方 ref.listen 中处理。
    engine.startListeningRealtime();

    // 共享账本兜底:切账本时(尤其是切回共享账本时)触发一次 sync。
    // 用户报告"切到自己账本再切回来 WS 不同步" — 实际可能 WS 还在但
    // pull 漏了或某次 ws 推送漏了。这里 ref.listen 切账本就主动同步,
    // 跟 _scheduleAutoSync 的 2 秒防抖叠加可以兜住绝大多数边界。
    ref.listen<int>(currentLedgerIdProvider, (prev, next) {
      if (prev == next || next <= 0) return;
      logger.info('SyncProvider',
          'ledger switched $prev → $next, schedule auto sync as fallback');
      engine.triggerAutoSync(reason: 'ledger_switched');
    });

    // 反应式同步触发器:监听 local_changes 表,任何 mutation 写进未推送
    // 行都会自动调度 sync。把"是否触发同步"的责任完全转移到"是否记录
    // 变更"——后者是数据层的天然职责。详见 sync_coordinator.dart 的注释。
    final coordinator = SyncCoordinator(db: db, engine: engine);
    coordinator.start();

    // 监听网络连接状态：从"无网"恢复时触发一次 sync 把离线累积的
    // local_changes 推出去。SyncEngine 内部有 2 秒防抖，WS 重连和 connectivity
    // 恢复几乎同时命中时最终只会触发 1 次 sync。
    Timer? connectivityDebounce;
    final connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online) {
        logger.info('SyncProvider', 'connectivity 变为离线, 不触发 sync');
        return;
      }
      // 这里也加一层防抖：WiFi ↔ 移动网络快速切换时 OS 会连打多条事件。
      connectivityDebounce?.cancel();
      connectivityDebounce = Timer(const Duration(milliseconds: 500), () {
        logger.info('SyncProvider', 'connectivity 恢复, 触发 auto sync');
        engine.triggerAutoSync(reason: 'connectivity_restored');
      });
    });

    // 当 Provider 被销毁时停止监听。engine.dispose 归 syncEngineProvider
    // (family),这里只清本 provider 自己持有的资源。
    ref.onDispose(() {
      eventSub.cancel();
      connectivityDebounce?.cancel();
      connectivitySubscription.cancel();
      coordinator.dispose();
    });

    // Profile（含头像）同步和 ledger 同步解耦：新设备首次登录时，用户可能还
    // 没有任何 ledger，`engine.sync(ledgerId)` 会被短路，头像同步无法随
    // sync() 触发。这里直接 fire-and-forget 拉一次 profile，pull 完成后调
    // 一次 reconcileProfileToServer,把"server 上缺而本地有"的字段补推上去
    // (appearance / displayName) —— 长期使用本地模式的用户本地早就有配置,
    // server 却是空的。
    Future(() async {
      // avatar bump 走 AvatarChanged 事件,不用 changed 兜底
      // (changed=true 包含 appearance/displayName 等任意字段被 apply,
      // 不只是头像,会引发头像组件无谓重渲)。
      await engine.syncMyProfile();
      await reconcileProfileToServer(
        cloudProviderFuture: ref.read(spitoutCloudProviderInstance.future),
        currentDisplayName: ref.read(displayNameProvider),
        currentExpenseColorScheme: ref.read(expenseColorSchemeProvider),
      );
    });

    // Bootstrap 串行：必须等 `syncLedgersFromServer` 完成（把 A 的账本 2/3/…
    // 插入到 B 本地 ledgers 表）之后，再触发 `engine.syncAccount()` 的 pull。
    // 否则 pull 到的 tx change 里的 ledger_id 在 B 本地还找不到对应的 ledger
    // 行，就会被 fallback 成错位的 int id，导致"A 的账本 2 历史交易拉到 B 后
    // 挂到错位或不存在的账本"。
    //
    // syncAccount() 是账户级原语 —— 内部枚举全部云端账本逐个 fullPush/增量/
    // fast-skip，同时完成 Phase1 用户级数据(profile / storage.list / pull('') /
    // pushUserGlobalEntities)，有无本地当前账本都能跑通，故以 syncAccount() 作为
    // 单一 bootstrap；_autoSyncInProgress 防重入锁杜绝 Provider 重建时多个 bootstrap 并发执行。
    if (!_autoSyncInProgress) {
      _autoSyncInProgress = true;
      Future(() async {
        try {
          // Step 1: 先拉账本列表，保证所有 A 的账本已经在 B 本地落库
          int newLedgerCount = 0;
          try {
            newLedgerCount = await engine.syncLedgersFromServer();
            if (newLedgerCount > 0) {
              ref.read(ledgerListRefreshProvider.notifier).state++;
              logger.info(
                  'SyncProvider', '从 server 拉回 $newLedgerCount 个新账本');
            }
          } catch (e, st) {
            logger.warning(
                'SyncProvider', 'syncLedgersFromServer 失败: $e', st);
            // 承接 SyncEngine 网络分支逃逸的 rethrow(5xx/Socket/Timeout):
            // 写入 lastSyncErrorProvider 让 UI 可见同步失败,而非静默吞掉。
            ref.read(lastSyncErrorProvider.notifier).state = e.toString();
          }

          // Step 1.5: 如果有新账本插进来，要从 cursor=0 把 sync_changes 重放
          // 一遍。否则 B 设备的全局 cursor 可能已被 pull 推到顶，增量
          // `_pull` 再也拿不回这些账本的历史 tx/category/account。
          // Spitout Cloud 的 apply 是按 entity_sync_id upsert 幂等的，重放
          // 安全。
          if (newLedgerCount > 0) {
            try {
              final replayed = await engine.replayAllChanges();
              logger.info(
                  'SyncProvider', '重放 sync_changes 应用 $replayed 条历史变更');
            } catch (e, st) {
              logger.warning(
                  'SyncProvider', 'replayAllChanges 失败: $e', st);
            }
          }

          // Step 2: 账本就绪后再跑账户级全量同步。syncAccount() 内部枚举全部
          // 云端账本并逐个同步，单账本失败已内部兜底不中断其余账本；配合
          // Step 1 的 ledger 落库，pull 到的每条 tx change 都能正确映射。
          logger.info('SyncProvider', '开始账户级自动同步');
          final result = await engine.syncAccount();
          logger.info('SyncProvider',
              '自动同步成功: pushed=${result.pushed}, pulled=${result.pulled}, '
              'skipped=${result.skipped}, elapsedMs=${result.elapsedMs}');
          ref.read(syncStatusRefreshProvider.notifier).state++;
          ref.read(ledgerListRefreshProvider.notifier).state++;
          ref.read(syncGenerationProvider.notifier).state++;
          ref.read(statsRefreshProvider.notifier).state++;
          ref.read(calendarRefreshProvider.notifier).state++;
          ref.read(homeSwitchToStreamProvider.notifier).state++;
          ref.read(cachedTransactionsProvider.notifier).state = null;
          // 不无条件 bump avatarRefreshProvider — AvatarChanged 事件
          // 只在真下载头像时触发,避免每次 bootstrap 闪一次头像。
          ref.read(lastSyncErrorProvider.notifier).state = null;
        } catch (e, st) {
          logger.error('SyncProvider', '自动同步异常', e, st);
          ref.read(lastSyncErrorProvider.notifier).state = e.toString();
        } finally {
          _autoSyncInProgress = false;
        }
      });
    }

    return engine;
  }

  // 其他 provider → TransactionsSyncManager（快照同步）
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(repositoryProvider);
  final sync = TransactionsSyncManager(config: config, db: db, repo: repo);

  // 快照型后端响应式触发:监听 snapshot_dirty_ledgers,新建账本时自动触发
  // 首快照上传(规则4)。与 Spitout Cloud 分支的 SyncCoordinator 对称,
  // 但面向整本快照重传范式。
  final snapshotCoordinator =
      SnapshotSyncCoordinator(db: db, syncService: sync);
  snapshotCoordinator.start();

  // auto_sync 开关从关闭→开启时主动补扫:开关关闭期间建的账本脏信号已写入
  // 但未上传(coordinator 受闸门阻拦),watch 不会因开关变化重发,需外部触发
  // 消费。从 false→true 的边沿才触发,避免开启态下的无谓重扫。
  ref.listen<AsyncValue<bool>>(autoSyncValueProvider, (prev, next) {
    final wasOn = prev?.valueOrNull ?? false;
    final isOn = next.valueOrNull ?? false;
    if (!wasOn && isOn) {
      logger.info('SyncProvider', 'auto_sync 开启, 触发快照脏信号补扫');
      snapshotCoordinator.scanNow();
    }
  });

  ref.onDispose(snapshotCoordinator.dispose);

  return sync;
});

/// Spitout Cloud 服务端版本号。Mine 页面 / 云同步页都能直接用;失败就
/// null,UI 自己隐藏。非 Spitout Cloud 模式直接 null。
///
/// **自动刷新**:依赖 [syncStatusRefreshProvider],每次同步完成会 bump 这个
/// ticker,版本号 provider 重新跑 fetchServerVersion。这样 server 升级后用户
/// 不需要重登/手动到云配置页点确认,下一次同步触发后版本号就更新了。
///
/// /version 是个轻量 endpoint,跟着每次 sync 多发一次 HTTP 请求开销可忽略。
final spitoutCloudServerVersionProvider =
    FutureProvider<String?>((ref) async {
  // server 升级后用户在 app 内做任何会触发同步的操作(加交易 / 切账本 / 进
  // Mine 页面 bump refresh 等)都能让版本号刷新。
  ref.watch(syncStatusRefreshProvider);

  final cloud = await ref.watch(spitoutCloudProviderInstance.future);
  if (cloud == null) return null;
  try {
    final v = await cloud.fetchServerVersion();
    return v.version.isEmpty ? null : v.version;
  } catch (_) {
    return null;
  }
});

/// 双向对齐 profile:server 上缺失但本地有的字段,把本地推上去。
/// 解决"用户一直在用 A,但支配配色 / 外观 / 昵称早就设好了,server 从未收到过"
/// 这个"初次开启跨设备同步时对端啥都没有"的坑。
///
/// 运行时机:
///   1. Bootstrap 完成 syncMyProfile 之后 —— 首次开启云同步,自动推上去
///   2. 云同步页下拉深度检测时 —— 用户手动触发,也做一次对账
///
/// 规则:只推 server 为空但本地非默认的字段。不强制覆盖 —— 如果双方都有值,
/// 以 server 为权威(syncMyProfile 里的 apply 已经把 server 值落到本地了)。
///
/// 参数 [read] 接受 Ref.read 或 WidgetRef.read(两者签名相同,共用实现),
/// 这样 bootstrap FutureProvider 和 UI 下拉刷新都能调。
Future<void> reconcileProfileToServer({
  required Future<SpitoutCloudProvider?> cloudProviderFuture,
  required String currentDisplayName,
  required String currentExpenseColorScheme,
}) async {
  try {
    final cloud = await cloudProviderFuture;
    if (cloud == null) return;
    final profile = await cloud.getMyProfile();

    // appearance
    if (profile.appearance == null || profile.appearance!.isEmpty) {
      try {
        final appearance = <String, dynamic>{
          'expense_color_scheme': currentExpenseColorScheme,
        };
        await cloud.updateMyProfileAppearance(appearance: appearance);
        logger.info('CloudSync', 'reconcile: pushed appearance=$appearance');
      } catch (e, st) {
        logger.warning('CloudSync', 'reconcile appearance 推送失败: $e', st);
      }
    }

    // display_name：server 没有但本地已设 → 补推(首次绑定 cloud 时本地昵称
    // 不会因 value 未变而触发 listener push，靠这里兜底)。
    if ((profile.displayName == null || profile.displayName!.isEmpty) &&
        currentDisplayName.trim().isNotEmpty) {
      try {
        await cloud.updateMyProfileDisplayName(
            displayName: currentDisplayName.trim());
        logger.info('CloudSync',
            'reconcile: pushed display_name=${currentDisplayName.trim()}');
      } catch (e, st) {
        logger.warning('CloudSync', 'reconcile display_name 推送失败: $e', st);
      }
    }

    // avatar —— 首次上传:本地已有头像文件但 server 上为空时上传。
    // 规则:server 没 avatarUrl 且本地存在 avatar 文件 → 上传。避免覆盖 server
    // 更新的头像(server 有就跳过,以 server 为权威)。
    if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
      try {
        final localPath = await avatarStorage.getAvatarPath();
        if (localPath != null && await File(localPath).exists()) {
          final bytes = await File(localPath).readAsBytes();
          if (bytes.isNotEmpty) {
            final fileName = localPath.split('/').last;
            final mimeType = fileName.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg';
            final result = await cloud.uploadMyAvatar(
              bytes: bytes,
              fileName: fileName,
              mimeType: mimeType,
            );
            await avatarStorage.setStoredRemoteVersion(result.avatarVersion);
            logger.info('CloudSync',
                'reconcile: pushed avatar server_version=${result.avatarVersion}');
          }
        }
      } catch (e, st) {
        logger.warning('CloudSync', 'reconcile avatar 推送失败: $e', st);
      }
    }
  } catch (e, st) {
    logger.warning('CloudSync', 'reconcileProfileToServer 失败: $e', st);
  }
}

// ==================== /profile/me 拉下来的值回写本地的工具函数 ====================
//
// 下面两个函数都由 SyncEngine 的 ProfileFieldApplied 事件触发:先比对当前值,
// 不同才写。写 Riverpod state 会触发 theme_providers 里的 ref.listen,该
// listener 会推送回 server — "写了相同值不触发推送" 的保证由 Riverpod 自己给,
// StateProvider 收到相同值不会 notify。所以只要正确跳过"相同值",就不会产生
// echo 循环。

void _applyDisplayNameFromServer(Ref ref, String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return; // v1 不下空,避免清空对端本地昵称
  final current = ref.read(displayNameProvider);
  if (current == trimmed) return; // 相同值不写,StateProvider 不 notify → 无 echo
  ref.read(displayNameProvider.notifier).state = trimmed;
  logger.info('profile_sync', 'applied display_name from server: $trimmed');
}

void _applyAppearanceFromServer(Ref ref, Map<String, dynamic> appearance) {
  // 支出颜色方案：仅接受 'green' / 'red'（其它值视为未知，打 warning 忽略），
  // 避免云端脏数据把本地方案改成无效态。
  final expenseColorScheme = appearance['expense_color_scheme'] as String?;
  if (expenseColorScheme != null &&
      (expenseColorScheme == 'red' || expenseColorScheme == 'green')) {
    final current = ref.read(expenseColorSchemeProvider);
    if (current != expenseColorScheme) {
      ref.read(expenseColorSchemeProvider.notifier).state = expenseColorScheme;
    }
  } else if (expenseColorScheme != null) {
    logger.warning('profile_sync',
        'ignored unknown expense_color_scheme=$expenseColorScheme');
  }
  logger.info('profile_sync', 'applied appearance from server: $appearance');
}

// ====== 自动本地备份 ======

/// 自动本地备份开关值（默认 true：零干预兜底，符合"数据不丢"首要目标）。
/// 与 autoSync 同机制（SharedPreferences + invalidate 刷新），key 见
/// [LocalBackupService.prefsKeyAutoBackup]。
final autoBackupValueProvider = FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool(LocalBackupService.prefsKeyAutoBackup) ?? true;
});

/// 自动本地备份开关写入器：写 SharedPreferences 后 invalidate 值缓存
class AutoBackupSetter {
  AutoBackupSetter(this._ref);
  final Ref _ref;
  Future<void> set(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LocalBackupService.prefsKeyAutoBackup, v);
    _ref.invalidate(autoBackupValueProvider);
  }
}

final autoBackupSetterProvider = Provider<AutoBackupSetter>((ref) {
  return AutoBackupSetter(ref);
});

/// 备份服务实例（默认构造 = 生产路径；测试可 override 注入临时目录）
final localBackupServiceProvider = Provider<LocalBackupService>((ref) {
  return LocalBackupService();
});

/// 自动本地备份统一触发入口（冷启动 initState + resumed 双挂点共用）。
///
/// 参数为 `read` 函数签名而非具体 Ref 类型：WidgetRef 与 Ref 的 `read` 签名
/// 一致但互不兼容（WidgetRef 不实现 Ref），传 tear-off（`ref.read`）即可同时
/// 支持 ConsumerWidget 与 Provider 两种调用场景，避免三套重载。
///
/// 内部完成：开关检查 → 按天去重（last_backup_date 持久化，跨进程重启仍成立）
/// → 调服务备份 → 成功才写日期（失败则下次触发自动重试；服务内 in-flight
/// 锁防并发）。任何失败仅记日志绝不外抛——备份不能阻断记账主流程。
Future<void> autoBackupOnLaunch(
  T Function<T>(ProviderListenable<T> listenable) read,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(LocalBackupService.prefsKeyAutoBackup) ?? true;
    if (!enabled) return;
    final today = LocalBackupService.todayString();
    if (prefs.getString(LocalBackupService.prefsKeyLastBackupDate) == today) {
      return;
    }
    final db = read(databaseProvider);
    await read(localBackupServiceProvider).createBackup(db: db);
    await prefs.setString(LocalBackupService.prefsKeyLastBackupDate, today);
    logger.info('LocalBackup', '自动本地备份完成');
  } catch (e, st) {
    logger.error('LocalBackup', '自动本地备份失败', e, st);
  }
}

/// 备份恢复统一编排：执行恢复 → 热重建 → 归属体检 → 回退当前账本。
///
/// 为什么需要这一层:整库文件级恢复是**原子覆盖 sqlite**,直接绕过所有归属
/// 闸门,备份里 `storageMode='cloud'` 的账本会原封不动复活。此时设备若处于
/// 未登录状态,这些账本就是「孤儿云端账本」——能记账,但转本地入口强依赖登录
/// 态,用户被永久卡在云分区。因此恢复后必须按登录态做一次归属体检。
///
/// 双分支**互斥**(绝不串行都跑):
///   - 已登录 → [SyncEngine.reregisterRestoredLedgers] 认领。
///     **严禁在此分支前预调 normalizeOrphanCloudLedgers**:认领靠旧 syncId 命中
///     server 409 走幂等重认领,syncId 一旦被清空,同账号恢复会退化成"新建一本",
///     云端出现重复账本。
///   - 未登录 → [LedgerRepository.normalizeOrphanCloudLedgers] 归一化兜底。
///
/// 时序铁律:`cloud` / `engine` / `repository` **必须在 invalidate 之后读取**,
/// 否则拿到的是绑定旧库(已被覆盖的文件)的陈旧实例。
///
/// 失败态守卫:`status != success` 时立即原样返回,不做任何 invalidate /
/// 归一化 / 认领——服务层保证失败路径当前库未被改动,此时动库反而会破坏现场。
///
/// [read] / [invalidate] 传 `ref.read` / `ref.invalidate` 的 tear-off，
/// WidgetRef 与 Ref 均可（同 [autoBackupOnLaunch] 的既有模式）。
/// 返回恢复结果原样透传，UI 只据此做 toast 分支。
Future<RestoreResult> restoreBackupAndReconcile({
  required T Function<T>(ProviderListenable<T> listenable) read,
  required void Function(ProviderOrFamily provider) invalidate,
  required File backupFile,
}) async {
  final result = await read(localBackupServiceProvider)
      .restoreFromBackup(db: read(databaseProvider), backupFile: backupFile);

  // 失败态:库未被覆盖,直接把结果交回 UI,不触碰任何状态。
  if (result.status != RestoreStatus.success) return result;

  // 热重建:文件已是新库,invalidate 级联重建所有数据 provider。
  // 即使热重建异常也不影响数据——重启后新库文件已就位。
  invalidate(databaseProvider);

  // 归属体检。失败仅记日志,不影响"恢复成功"提示:数据已经落盘,
  // 归属修复失败最多是用户下次进云同步页再修一次,不该让他以为恢复失败了。
  try {
    final cloud = await read(spitoutCloudProviderInstance.future);
    if (cloud != null) {
      // syncEngineProvider 是 family,需传入当前 cloud provider 才能拿到
      // 与 WS listener 共享的唯一 engine 实例。
      await read(syncEngineProvider(cloud)).reregisterRestoredLedgers();
    } else {
      final counts = await read(repositoryProvider).normalizeOrphanCloudLedgers();
      if (counts.personal > 0 || counts.shared > 0) {
        logger.info('LocalBackup',
            '未登录恢复兜底:归一化孤儿云端账本 个人=${counts.personal} 共享=${counts.shared}');
      }
    }
  } catch (e, st) {
    logger.error('LocalBackup', '恢复后账本归属体检失败(不影响恢复结果)', e, st);
  }

  // 校验当前选中账本在新库是否仍有效,无效则回退新库首个账本并写回 prefs。
  // 否则若备份账本 id 与 prefs 不符,currentLedgerIdProvider 仍指向旧 id、
  // currentLedgerProvider 查不到 → 首页误判空状态,只能靠重启触发
  // currentLedgerPersistProvider 的启动解析回退。
  await selectFirstLedger(read);

  return result;
}

// 账本列表相关 provider（ledgerListRefreshProvider / uploadingLedgerIdsProvider /
// localLedgersProvider）定义于 refresh_ticks.dart 与 ledger_list_providers.dart，
// 本文件 re-export 保持消费方无感。

