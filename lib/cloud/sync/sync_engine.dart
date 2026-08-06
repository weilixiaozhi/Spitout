import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as d;
// 经门面获取 Spitout Cloud 与核心云同步类型（全 app 唯一入口，见 docs 架构决策）
import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/db.dart';
// 健康报告/计数对/账户结果类型定义于 data 层。
// import 供本库(含 part 文件 sync_engine_status.dart)使用;
// export 供 UI 层(spitout_cloud_sync_section)经 `import sync_engine.dart`
// 取用这些类型。show 白名单避免与上方 flutter_cloud_sync 包的
// SyncStatus 同名冲突。
import '../../data/models.dart' show SyncAccountResult, SyncCountPair, SyncHealthReport;
export '../../data/models.dart' show SyncAccountResult, SyncCountPair, SyncHealthReport;
import '../../data/models/ledger_kind.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/local/local_transaction_repository.dart'
    show deleteTransactionsWithEditHistories;
import '../../core/logging/logger_service.dart';
import '../../services/storage/avatar_storage.dart';
import 'sync_service.dart' as app;
import 'transactions_json.dart';
import 'change_tracker.dart';
import 'entity_serializer.dart';
import 'sync_events.dart';
export 'sync_events.dart';

// SyncEngine 按职责拆分到多个 part 文件,共享同一 library:
// - sync_engine_resolvers.dart:   跨设备 ID 解析(syncId ↔ 本地 int id)
// - sync_engine_status.dart:      健康检查 + 种子数据补登
// - sync_engine_realtime.dart:    WS 事件监听 + auto sync / pull 防抖调度
// - sync_engine_profile.dart:     profile + avatar 同步(appearance/displayName/currency/avatar)
// - sync_engine_apply.dart:       pull 路径远端变更 → 本地 Drift apply(6 种 entityType)
// - sync_engine_serialization.dart: push 路径本地实体 → server payload 序列化 + fullPush
// - sync_engine_pull.dart:        pull 路径错误恢复 — AppCursorStore + SyncErrorStore
//                                 (cursor 安全 + 失败 change 持久化暴露给 UI)
part 'sync_engine_resolvers.dart';
part 'sync_engine_status.dart';
part 'sync_engine_realtime.dart';
part 'sync_engine_profile.dart';
part 'sync_engine_apply.dart';
part 'sync_engine_serialization.dart';
part 'sync_engine_pull.dart';

const _uuid = Uuid();

/// 同步结果
class SyncResult {
  final int pushed;
  final int pulled;
  final int conflicts;
  final String? error;

  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.error,
  });

  bool get hasError => error != null;

  @override
  String toString() =>
      'SyncResult(pushed=$pushed, pulled=$pulled, conflicts=$conflicts${error != null ? ', error=$error' : ''})';
}

/// 同步状态
enum SyncEngineStatus { idle, pushing, pulling, syncing, error }

/// fullPush 被 moveToLocal 主动中止时抛出的**中性**信号异常。
///
/// 设计意图:moveToLocal 要删云端副本前,必须让「正在把本地数据推上云」的
/// fullPush 停手,否则会边删边推、留下孤儿 S1。命中 abort 时抛此异常而非普通
/// 错误,是为了让 fullPush 的 catch 能区分「被主动中止(正常终结)」与「真实
/// 推送失败(需 completeError 上报)」——前者 completer.complete() 视为正常
/// 完成,waitFullPushSettle 才不会误判为「删远端失败」而 fail-closed。
class FullPushAborted implements Exception {
  const FullPushAborted();
  @override
  String toString() => 'FullPushAborted: fullPush 被 moveToLocal 主动中止';
}

/// 核心同步编排器 — 实现 SyncService 接口
/// 负责 push 本地变更到服务端、pull 远程变更到本地
class SyncEngine implements app.SyncService {
  final SpitoutDatabase db;
  final SpitoutCloudSyncBackend provider;
  final ChangeTracker changeTracker;
  final BaseRepository repo;

  /// 增量型引擎不走「下载后 diff 预览」:同步由 SyncCoordinator 自动驱动,
  /// 快照型后端的预览能力不适用于本实现。
  @override
  bool get supportsDiffPreview => false;

  @override
  Future<({app.SyncPreview? preview, app.ImportData importData, int version})?>
      downloadAndPreview({required int ledgerId}) {
    throw UnsupportedError('SyncEngine 不支持下载前 diff 预览');
  }

  @override
  Future<app.SyncApplyResult> applyPreviewChanges({
    required int ledgerId,
    required List<app.SyncChange> selectedChanges,
    required app.ImportData importData,
  }) {
    throw UnsupportedError('SyncEngine 不支持下载前 diff 预览');
  }

  /// 状态缓存
  final Map<int, app.SyncStatus> _statusCache = {};
  bool _localChanged = false;

  /// WebSocket 实时监听
  StreamSubscription<SpitoutCloudRealtimeEvent>? _realtimeSubscription;
  Timer? _pullDebounce;

  /// 当前正在自动拉取的 ledgerId（防止重复触发）
  bool _autoPulling = false;

  /// 当前是否在执行 WS 重连触发的自动 sync（push+pull），防止 ws reconnect
  /// 和 connectivity 恢复几乎同时命中时重复 sync。
  bool _autoSyncing = false;
  Timer? _autoSyncDebounce;

  /// 对外广播事件总线 — UI 通过 Riverpod `syncEventStreamProvider` 订阅,
  /// SyncEngine 完全不知道 widget / ref 存在。
  ///
  /// **sync: true 关键**:默认 broadcast 是 async 模式,`_emit` 调 `add` 后
  /// listener 要延迟到下个 microtask 才跑。多次 `_emit` 会触发多次独立 microtask,
  /// Flutter 有机会在两次 listener 之间 schedule rebuild,导致 state 变更分散到
  /// 多帧。sync: true 让 add 同步调 listener,多次 emit 内的 state 变更在同一
  /// 同步代码段内 batch 成一帧 rebuild。
  final StreamController<SyncEvent> _eventsController =
      StreamController<SyncEvent>.broadcast(sync: true);

  /// 订阅 sync 事件。
  Stream<SyncEvent> get events => _eventsController.stream;

  /// 内部 helper:emit 新事件到 stream。
  void _emit(SyncEvent event) {
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  /// app 侧 cursor + pull 失败 change 持久化的 DAO。
  /// 详见 [AppCursorStore] / [SyncErrorStore](sync_engine_pull.dart)。
  late final AppCursorStore appCursor;
  late final SyncErrorStore pullErrors;

  /// pull 期间生效的 [LookupCache]。pull 入口 new + prime,pull 结束清 null。
  /// resolvers 路径(`sync_engine_resolvers.dart`)优先查它,消除 N+1 SELECT。
  /// 详见 [LookupCache](sync_engine_pull.dart)。
  LookupCache? activePullCache;

  /// push / fullPush 的 in-flight 单飞锁。**per-ledger** —— 不同 ledger
  /// 并发不互相阻塞,只阻塞同 ledger 的并发触发。
  ///
  /// app 启动期 `_triggerInitialCloudSync` 由 microtask + listenManual
  /// 双入口触发,加锁防止同设备并发 fullPush 导致服务端 sync_changes 表膨胀。
  ///
  /// `_pushInFlight` key 用 String(跟 [push] 入参一致),`_fullPushInFlight`
  /// 用 int(跟 [fullPush] 入参一致)。
  final Map<String, Completer<int>> _pushInFlight = {};
  final Map<int, Completer<void>> _fullPushInFlight = {};

  /// 等待指定账本正在进行的 fullPush 收敛(供 [moveToLocal] 在删云端前调用)。
  ///
  /// 设计意图:moveToLocal 登记 abort 信号后,in-flight 的 fullPush 会在下一个
  /// 网络调用检查点抛 [FullPushAborted] 并 completer.complete() 收敛;本方法
  /// 阻塞等到它真正 settle,再让 moveToLocal 去删远端,避免「边推边删」孤儿。
  ///
  /// **为什么吞掉所有错误**:fullPush 失败 = 云端数据未推全,而 moveToLocal
  /// 本来就要删掉云端副本,删一份半成品同样无害;若把 completeError 传出去,
  /// moveToLocal 会误判为「删远端失败」而 fail-closed。故此处一律视为已终结、
  /// 正常返回。无 in-flight(map 命中 null)时立即返回。
  ///
  /// **职责单一**:本方法不做超时,30s 超时由调用方(moveToLocal)外包
  /// `.timeout(...)` 实现;也不暴露 [_fullPushInFlight] map,仅暴露本方法。
  Future<void> waitFullPushSettle(int ledgerId) async {
    final inFlight = _fullPushInFlight[ledgerId];
    if (inFlight == null) return; // 无 fullPush 在跑,直接返回
    try {
      await inFlight.future;
    } catch (_) {
      // 吞掉所有错误(含 FullPushAborted / completeError 传播的真实失败):
      // 一律视为已终结,交给 moveToLocal 继续删远端。
    }
  }

  /// 恢复认领期间抑制硬删:reregisterRestoredLedgers 把本地账本重新认领到
  /// 新服务器/账号时,避免在认领完成前 bootstrap 的 GC 把"还没认领完"的共享账本
  /// 当"server 不返回"误清。同步置位、finally 复位(Dart 单 isolate,置位先于
  /// 任何 GC1 异步执行)。覆盖 ws_connected 抢跑等所有 syncLedgersFromServer 入口。
  bool _suppressLedgerGc = false;

  /// 「远端真宕机」阈值状态机 —— 服务于 syncLedgersFromServer 的兜底 GC。
  ///
  /// 设计意图:5xx / 网络错误可能只是瞬时抖动(部署重启 / 弱网),不能一次失败
  /// 就把本地共享账本全清掉(集体闪退再重拉体验极差)。只有在滑动窗口
  /// [_kRemoteDownWindow] 内连续失败 [_kRemoteDownThreshold] 次,才判定远端
  /// 真的下线,执行全量清。404/410(路由确死)与 401(登录态失效)不走此状态机,
  /// 由异常分类直接立即清。
  static const _kRemoteDownThreshold = 3;
  static const _kRemoteDownWindow = Duration(minutes: 10);
  int _remoteFetchFailCount = 0;
  DateTime? _remoteFetchFailStart;

  /// 记一次 readLedgers 网络类失败。窗口过期则重开窗口从 1 计。
  void _onRemoteFetchNetworkFailure() {
    final now = DateTime.now();
    if (_remoteFetchFailStart == null ||
        now.difference(_remoteFetchFailStart!) > _kRemoteDownWindow) {
      _remoteFetchFailStart = now;
      _remoteFetchFailCount = 0;
    }
    _remoteFetchFailCount++;
  }

  /// 是否已确认远端宕机(窗口内失败次数达到阈值)。
  bool _remoteDownConfirmed() => _remoteFetchFailCount >= _kRemoteDownThreshold;

  /// readLedgers 成功一次即重置计数,避免陈旧失败累积误判。
  void _resetRemoteFetchFailures() {
    _remoteFetchFailCount = 0;
    _remoteFetchFailStart = null;
  }

  /// reregisterRestoredLedgers 防重入:恢复页单次调用,但 WS 重连等可能并发触发
  /// 第二次;用本开关保证整个认领流程只跑一次。
  bool _reregistering = false;

  /// 「自己刚发起的删云端回声」临时忽略白名单(按 syncId 匹配)。
  ///
  /// 设计意图:moveToLocal 复用全局删 API 删自己的云端副本时,服务端会向 owner
  /// 自己(本机)也广播一份 member_change.removed;WS 回声到达后,
  /// _handleMemberChange 会调 _purgeLocalLedgerByExternalId 把本地账本整本删掉
  /// (个人云端账本移动到本地被误删的根因)。
  ///
  /// 本集合在 moveToLocal 删云端前登记该账本 syncId、结束后(finally)必清,
  /// _handleMemberChange 命中集合内 syncId 时直接跳过 purge。
  ///   - 只比对 syncId,不依赖任何时序假设;
  ///   - 只抑制「自己发起的 detach 回声」,不吞任何真实删除事件(集合外的
  ///     removed 照常 purge);
  ///   - finally 必清保证失败安全,不会残留误伤后续真实事件。
  final Set<String> _pendingMoveToLocalSyncIds = {};

  /// moveToLocal 的**推送中止信号**(按本地 int ledgerId 匹配)。
  ///
  /// 与上方 [_pendingMoveToLocalSyncIds] 的分工:
  ///   - [_pendingMoveToLocalSyncIds](按 syncId)拦的是「删云端后服务端回声给
  ///     owner 自己的 member_change.removed」——即 **WS 回声路径**,防本地被 purge;
  ///   - 本集合(按 int ledgerId)拦的是「把本地数据写上云的 fullPush / 增量
  ///     push」——即 **写 S1 推送路径**,防边删边推留孤儿。
  ///
  /// 之所以用**持久状态**(finally 才撤销)而非一次性标志:它必须能拦截
  /// moveToLocal 窗口内**任意时刻**新触发的 fullPush 与增量 push——包括
  /// waitFullPushSettle 检查到 null(无 in-flight)之后、deleteLedger 之前
  /// 这段窗口里由 auto sync 新启动的推送。这是它相对 storage_mode 闸门的本质
  /// 优势:storage_mode 一旦被 pull 翻回 cloud 就失效,而信号在 finally 前始终生效。
  final Set<int> _moveToLocalAbortRequests = {};

  /// user-global 实体(category/exchange_rate_override)推送的**全局**单飞锁。
  ///
  /// 当前为**逐账本串行**执行(syncAccount 内部 for 循环),本锁在此
  /// 是防御性设计。若未来支持多账本并发 push,每个 caller 各自读 user-global
  /// unpushed change → 都 push 一份 → server sync_changes 表里 user-global
  /// 实体按 ledger 数倍数膨胀(实测 4 账本用户的 category 出现 4x 膨胀)。
  ///
  /// 解法:所有 push 路径都先 `await pushUserGlobalEntities()`,**单飞**保证
  /// 全 session 只跑一次 user-global push,后续 caller 复用第一个的 future,
  /// 拿到的时候 ChangeTracker 已经 markPushed,再各自处理 ledger-scoped 部分。
  Completer<void>? _userGlobalPushInFlight;

  /// 上次清理已推送 local_changes 的时间（节流，至少间隔 1 小时）。
  DateTime? _lastPushedCleanupAt;

  /// fullPull 的 in-flight 单飞锁。**per-ledger**,跟 fullPush 同款。
  ///
  /// 防御性:用户连点"下载"按钮时,避免两次并发 fullPull 重复下载同一份 JSON
  /// snapshot + 重复 apply。apply 路径是 idempotent upsert(同 syncId 不会插
  /// 重复行),所以不会数据膨胀,但浪费带宽 + CPU。
  ///
  /// 跟 fullPush 不同:**不会**真的把多账本并发拉成 N 倍 —— fullPull 只在用户
  /// 点"下载"时触发,正常单次调用;这个锁是给"快速连点"等边界场景兜底。
  final Map<int, Completer<({int inserted, int deletedDup})>>
      _fullPullInFlight = {};

  /// legacy 数据补 ChangeTracker 记录的一次性 flag。
  ///
  /// migration 给老 category 回填了 syncId,但**没在 local_changes 表里登记
  /// 对应的 create change**。如果某用户一直没开过云同步,后面 fullPush 走
  /// ChangeTracker 驱动就拿不到这些 legacy 实体 → 数据丢失。
  ///
  /// 解法:每个 session 第一次跑 `pushUserGlobalEntities` 时扫一遍 DB,给
  /// `local_changes` 里没记录的 user-global 实体补一条 upsert change,后续
  /// 正常走 ChangeTracker 流程。flag 持久存在 SyncEngine 实例上(per-session),
  /// 实例重建时(冷启)再跑一次,代价是一次轻量 SELECT。
  bool _userGlobalLegacyBackfilled = false;

  /// 自愈:同一账本两次"健康验证"的最小间隔。详见 [_selfHealIfMissing]。
  static const Duration _selfHealThrottle = Duration(minutes: 5);

  /// 自愈:连续二次确认失败达到此次数后进入熔断。
  static const int _selfHealMaxFailures = 2;

  /// 自愈:熔断时长。期内自愈入口短路,由 UI 引导手动"从云端恢复"。
  static const Duration _selfHealBrokenDuration = Duration(minutes: 30);

  /// 上次"健康验证"时间(per-ledger,key 为 ledgerId 字符串)。
  ///
  /// 注意:验证本身(无论结果健康、缺数据、甚至 stats 拉取抛错)都会写
  /// 这个时间戳 —— pulled==0 是 99% 常态,若只在"确认缺数据"后才记,
  /// 健康设备每次首页下拉都会打一次 /stats,违背高频入口轻量原则;
  /// stats 抛错时的时间戳顺带构成天然失败退避。
  final Map<String, DateTime> _selfHealLastRun = {};

  /// 连续自愈失败计数(per-ledger)。成功消除差异即清零。
  final Map<String, int> _selfHealFailures = {};

  /// 熔断截止时间(per-ledger)。熔断期内 [_selfHealIfMissing] 直接短路。
  final Map<String, DateTime> _selfHealBrokenUntil = {};

  SyncEngine({
    required this.db,
    required this.provider,
    required this.changeTracker,
    required this.repo,
  }) {
    appCursor = AppCursorStore(provider);
    pullErrors = SyncErrorStore(db);
  }

  // ==================== SyncService 接口实现 ====================

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    logger.info('SyncEngine', '上传账本 ledger=$ledgerId');

    // 用户主动点"上传"永远只做增量：用 server 的 entity diff log 把本地未推
    // 送的 changes 推上去，绝不触发 fullPush。
    //
    // 原因：fullPush 会把本地当前 ledger 的 JSON 快照整体覆盖到 server 的
    // snapshot（path = ledger.syncId），一旦本地不是"完整权威版本"（比如
    // B 刚登录、bootstrap pull 还没跑完 / 跑了但漏了几条、多设备期间某条
    // 交易延迟到达），web 立刻就看到"剩几条"的残缺快照 —— 这是典型的
    // "覆盖丢数据"场景。
    //
    // 即使一次 fullPush 之后后续 pull 再回灌也不行：snapshot 是权威源，
    // sync_changes 只是 diff，web 端读的是 snapshot。
    //
    // 增量 push 只推 changeTracker 登记过的本地操作，不会把没 own 的数据
    // 误推回去，所以是安全的。本地没变更时直接返回，不需要 fallback。
    final pushed = await push(ledgerId.toString());
    logger.info('SyncEngine', '上传账本完成：增量推送 $pushed 条变更');

    _statusCache.remove(ledgerId);
    _localChanged = false;
  }

  @override
  Future<({int inserted, int deletedDup})> downloadAndRestoreToCurrentLedger(
      {required int ledgerId}) async {
    logger.info('SyncEngine', '下载并恢复账本 ledger=$ledgerId');

    // 先尝试增量拉取
    final pulled = await pull(ledgerId.toString());
    if (pulled > 0) {
      _statusCache.remove(ledgerId);
      return (inserted: pulled, deletedDup: 0);
    }

    // 增量拉取无数据(pulled == 0)有两种含义：
    //   a) 本地已是最新 —— 已同步过的设备,没有新变更,这是绝大多数情况；
    //   b) 新设备/空账本 —— 增量 cursor 拉不到历史数据,需要全量恢复。
    // 直接走全量恢复的话,已有数据的账本会拖慢同步并导致增量 cursor 无法推进。
    // 修复：只有本地该账本没有任何交易时才回退全量恢复,否则视为"已是最新"。
    final localTxCount = await (db.selectOnly(db.transactions)
          ..addColumns([db.transactions.id.count()])
          ..where(db.transactions.ledgerId.equals(ledgerId)))
        .map((row) => row.read(db.transactions.id.count()) ?? 0)
        .getSingle();
    if (localTxCount > 0) {
      logger.info('SyncEngine',
          '增量无新数据且本地已有 $localTxCount 条交易,视为已是最新,跳过全量恢复');
      return (inserted: 0, deletedDup: 0);
    }

    // 本地账本为空(新设备/空账本),执行全量恢复
    final result = await runFullPull(ledgerId: ledgerId);
    _statusCache.remove(ledgerId);
    return result;
  }

  @override
  Future<int> pullIncremental({required int ledgerId}) async {
    // 下拉刷新等高频入口专用：只做增量 pull(幂等),绝不回退全量恢复。
    // 全量恢复(runFullPull)保留给云同步页明确的"从云端恢复"操作,
    // 避免高频入口误触发整份快照重新导入。
    final pulled = await pull(ledgerId.toString());
    if (pulled > 0) {
      _statusCache.remove(ledgerId);
    }
    return pulled;
  }

  @override
  Future<app.PullOutcome> pullIncrementalWithHeal(
      {required int ledgerId}) async {
    // 保持"只 pull 不 push"的轻量语义 —— 与 pullIncremental 的区别仅在于
    // pulled==0 时多做一次受闸门/节流/熔断保护的自愈检查。
    final incremental = await pullIncremental(ledgerId: ledgerId);
    if (incremental > 0) {
      return app.PullOutcome(incremental: incremental);
    }
    // pulled==0 既可能是"已是最新"(常态),也可能是"本地游标越过云端历史
    // 变更"。_selfHealIfMissing 内部用 checkLedgerHealth 区分,且验证本身
    // 受节流保护(健康设备至多每 5 分钟一次 /stats),不破坏轻量原则。
    //
    // 闸门语义说明:本路径不 push,本地有未推送变更时闸门 unpushed==0
    // 必然不通过(未推送的 delete 会造成"云端多"的假象)→ 静默跳过。
    // 这是有意为之:本条路径的自愈依赖"本地状态已完整推送"这一前提,
    // 不满足时等下一次 sync() 推完后由后续触发点自愈。
    final heal = await _selfHealIfMissing(ledgerId.toString());
    if (heal.healed > 0) {
      _statusCache.remove(ledgerId);
    }
    return app.PullOutcome(
      incremental: incremental,
      healed: heal.healed,
      didHeal: heal.healed > 0,
      gapRemaining: heal.gapRemaining,
      circuitBroken: selfHealBroken(ledgerId.toString()),
    );
  }

  @override
  Future<app.SyncStatus> getStatus({required int ledgerId}) async {
    // 返回缓存（如果有且未标记变更）
    if (!_localChanged && _statusCache.containsKey(ledgerId)) {
      return _statusCache[ledgerId]!;
    }

    try {
      final user = await provider.auth.currentUser;
      if (user == null) {
        return const app.SyncStatus(
          diff: app.SyncDiff.notLoggedIn,
          localCount: 0,
          localFingerprint: '',
        );
      }

      // 账本行先读:纯本地账本(不上云)直接返回 localOnly,不发起任何远端
      // 探测 —— 否则本地账本的交易会被误判为"本地有数据、云端没有",
      // 在「我的」页与云同步配置里制造永远无法消除的同步差异。
      final ledgerRowStatus = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingleOrNull();
      // 纯本地账本(无 syncId、storage_mode=local)才判定为不上云:
      // 若本地行还带着 syncId,说明是异常中间态,仍按可同步账本处理。
      if (ledgerRowStatus != null &&
          ledgerRowStatus.isLocalLedger &&
          (ledgerRowStatus.syncId == null || ledgerRowStatus.syncId!.isEmpty)) {
        final localTxs = await (db.select(db.transactions)
              ..where((t) => t.ledgerId.equals(ledgerId)))
            .get();
        final status = app.SyncStatus(
          diff: app.SyncDiff.localOnly,
          localCount: localTxs.length,
          localFingerprint: 'local',
        );
        _statusCache[ledgerId] = status;
        _localChanged = false;
        return status;
      }

      // 本地交易数
      final localTxs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(ledgerId)))
          .get();
      final localCount = localTxs.length;

      // 检查是否有未推送的本地变更
      final unpushedCount =
          (await changeTracker.getUnpushedChangesForLedger(ledgerId)).length;

      // 检查云端是否有数据。path 用 ledger.syncId 跟 push 侧保持一致。
      final hasRemote = await provider.storage.exists(
        path: ledgerRowStatus?.syncId ?? ledgerId.toString(),
      );

      app.SyncDiff diff;
      if (!hasRemote && localCount == 0) {
        diff = app.SyncDiff.noRemote;
      } else if (!hasRemote) {
        diff = app.SyncDiff.localNewer; // 本地有数据，云端没有
      } else if (unpushedCount > 0) {
        diff = app.SyncDiff.localNewer;
      } else {
        diff = app.SyncDiff.inSync;
      }

      final status = app.SyncStatus(
        diff: diff,
        localCount: localCount,
        localFingerprint: unpushedCount > 0 ? 'has_changes' : 'synced',
      );
      _statusCache[ledgerId] = status;
      _localChanged = false;
      return status;
    } catch (e, st) {
      logger.error('SyncEngine', '获取同步状态失败', e, st);
      return app.SyncStatus(
        diff: app.SyncDiff.error,
        localCount: 0,
        localFingerprint: '',
        message: e.toString(),
      );
    }
  }

  @override
  void markLocalChanged({required int ledgerId}) {
    _localChanged = true;
    _statusCache.remove(ledgerId);
  }

  @override
  Future<void> deleteRemoteBackup({required int ledgerId}) async {
    // path 用 ledger.syncId，跟 push/upload 对齐。
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final path = ledgerRow?.syncId ?? ledgerId.toString();
    try {
      await provider.storage.delete(path: path);
    } catch (e) {
      // 忽略 404
      if (!e.toString().contains('404')) rethrow;
    }
    _statusCache.remove(ledgerId);
  }

  @override
  Future<void> deleteLedgerGlobally(int ledgerId) async {
    // 三步收敛:远端删 → 本地删 → 清 change。顺序不可调换 ——
    // syncId 必须在本地行删除之前回查,否则拿不到远端记录标识;
    // 清 change 必须在本地删之后,抹掉 deleteLedger 登记的残留变更,
    // 避免 SyncCoordinator 向已删除的 server 账本推 change。
    try {
      // Step 1: 回查 syncId 并删远端。syncId 为空说明该账本从未同步上云,
      // 远端无记录,直接跳过远端删除(不算错误)。
      final ledger = await repo.getLedgerById(ledgerId);
      final syncId = ledger?.syncId;
      if (syncId != null && syncId.isNotEmpty) {
        try {
          await provider.deleteLedger(ledgerId: syncId);
          logger.info('SyncEngine',
              'deleteLedgerGlobally: 远端账本已删除 syncId=$syncId');
        } catch (e) {
          // 404 说明远端已经不存在(可能其它设备已删),幂等放行;
          // 其它错误(网络/鉴权)必须中断 —— 若远端没删成而本地删了,
          // 下次 syncLedgersFromServer 会把账本 re-insert 回来造成幽灵账本。
          if (!e.toString().contains('404')) rethrow;
          logger.warning(
              'SyncEngine', 'deleteLedgerGlobally: 远端已不存在(404), 忽略');
        }
      }

      // Step 2: 删本地行(级联删交易;会向 local_changes 登记 delete change)。
      await repo.deleteLedger(ledgerId);

      // Step 3: 抹掉 Step 2 登记的残留 change —— server 侧已真删,
      // 这些 change 若被推送只会打到不存在的资源上。
      await repo.clearLocalChangesForLedger(ledgerId);

      _statusCache.remove(ledgerId);
      logger.info('SyncEngine', 'deleteLedgerGlobally($ledgerId) 完成');
    } catch (e, st) {
      logger.error('SyncEngine', '全局删除账本失败 ledgerId=$ledgerId', e, st);
      rethrow;
    }
  }

  // ---- 账本归属移动:本地 ↔ 云端 ----

  /// 把本地账本搬到云端。
  ///
  /// 秒级可见:先翻 storage_mode='cloud'(UI 立即生效),推送下沉到后台。
  ///   1. 复用旧 syncId(有则不重发,避免换 id 破坏已有云端关联);本地账本首次
  ///      上云则补发一个;
  ///   2. 翻 mode='cloud'(此刻用户即看到「云端」态);
  ///   3. [triggerAutoSync] 显式调度后台推送(2s 防抖 + 单飞合并)。
  ///
  /// **为什么用 triggerAutoSync 而非直接 sync()**:翻 mode 走 updateLedgerStorageMode
  /// 不写 local_changes,SyncCoordinator 不会自动触发,必须显式调度;且经防抖合并、
  /// 由统一调度链进入 syncAccount,符合「同步触发下沉」约束——UI 不直接触碰 sync()。
  ///
  /// 失败语义:补 syncId / 翻 mode 任一步失败 → 抛 [CloudSyncException](UI 报错,
  /// 账本保持 local);翻 cloud 成功后的后台推送失败 → 由 syncAccount Phase 2
  /// (!inRemote && !isSharedAsEditor 账本自动 fullPush)自愈,不阻塞用户。
  ///
  /// 中间态无害:即便「翻 cloud 成功但推送尚未完成」,本地 cloud + syncId 非 null
  /// 不会被 pull 收编(收编只认 sid==null && cloud),不产生数据丢失。
  /// 孤儿由 moveToLocal 端的 abort 信号 + waitFullPushSettle 闭环兜底。
  /// 共享账本不允许转云端(应使用 [copyToLocal])。
  @override
  Future<void> moveToCloud(int ledgerId) async {
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    if (ledger == null) throw CloudSyncException('账本不存在: $ledgerId');
    if (ledger.storageMode == 'cloud') return; // 已是云端,幂等
    if (ledger.isShared) {
      throw CloudSyncException('共享账本不可转为云端,请改用"复制到本地"');
    }
    try {
      // 1) 复用旧 syncId;本地账本原本为 null 则补发一个。
      final syncId = ledger.syncId ?? _uuid.v4();
      if (ledger.syncId == null) {
        await repo.updateLedgerSyncId(id: ledgerId, syncId: syncId);
      }
      // 2) 翻 mode='cloud'——秒级可见,UI 立即生效。
      await repo.updateLedgerStorageMode(id: ledgerId, storageMode: 'cloud');
      // 3) 登记 ledger:upsert 到 local_changes。
      // 必须在翻 mode 之后:changeTracker 第二层闸门只放行 storage_mode='cloud'
      // 的账本,本地账本(isLocalLedger)会被闸门挡住不写 local_changes。
      // 登记后即使 Phase 2 走了 fullPush(已推一遍),增量 push 会再推一次——
      // upsert 幂等,无副作用;但若 fullPush 因故未触发(如单飞被占),
      // 这条登记保证账本变更仍会被增量 push 推上去,不依赖 fullPush 兜底。
      await changeTracker.recordLedgerChange(
        entityType: 'ledger',
        entityId: ledgerId,
        entitySyncId: syncId,
        ledgerId: ledgerId,
        action: 'upsert',
      );
    } catch (e, st) {
      logger.error('SyncEngine', 'moveToCloud 翻 mode 失败,账本保持 local', e, st);
      throw CloudSyncException('转为云端失败:$e');
    }
    // 3) 后台推送:显式调度 auto sync(防抖 + 单飞),经统一链进入 syncAccount。
    triggerAutoSync(reason: 'move_to_cloud');
  }

  /// 把云端账本搬到本地。
  ///
  /// 主防线(信号驱动):
  ///   1. 登记 abort 信号([_moveToLocalAbortRequests]),从此刻起 fullPush 入口 +
  ///      三检查点 + 增量 push 都会被中止,杜绝「边删边推」写出 S1 孤儿;
  ///   2. [waitFullPushSettle] 等 in-flight 的 fullPush 收敛(30s 超时,超时则账本
  ///      保持 cloud 抛异常);
  ///   3. 删云端副本 S1,404/410 幂等放行(「云端无副本 = 已删」,对齐
  ///      deleteLedgerGlobally);其他错误抛异常、账本保持 cloud、syncId 全程未动;
  ///   4. 删成功后由 [_detachFromCloudWithFallback] 原子断联(翻 local + 清 syncId,
  ///      三级收敛)。
  /// 辅防线:syncAccount 的 fullPush 入口闸门(!force 时 isLocalLedger 跳过)拦迟到调用。
  ///
  /// **为什么删远端前不改 storage_mode**:syncLedgersFromServer 的 update 路径无条件
  /// 写 cloud,若先翻 local,一旦此间被 pull 翻回 cloud,storage_mode 闸门即失效,
  /// syncAccount 会对 cloud 账本反复触发新 fullPush。abort 信号是持久状态(finally
  /// 才撤销),能拦截整个 moveToLocal 窗口内任意时刻新触发的推送,故全程不动 mode、
  /// 直到删远端成功才由 detach 原子断联。
  ///
  /// 误删防护:删云端期间把该账本 syncId 登记进 [_pendingMoveToLocalSyncIds],拦截
  /// 服务端向 owner 自己广播的 member_change.removed 回声,避免本地账本被 purge。
  ///
  /// 终态约束:成功 → local + syncId=null;删失败 → 保持 cloud + syncId 保留;
  /// detach 失败 → 三级收敛保证账本留本地绝不被 purge。共享账本不允许(应用 copyToLocal)。
  @override
  Future<void> moveToLocal(int ledgerId) async {
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    if (ledger == null) throw CloudSyncException('账本不存在: $ledgerId');
    if (ledger.storageMode == 'local') return; // 已是本地,幂等
    if (ledger.isShared) {
      throw CloudSyncException('共享账本不可转为本地,请改用"复制到本地"');
    }
    final syncId = ledger.syncId;
    if (syncId == null || syncId.isEmpty) {
      // 无云端关联(理论上不会走到:cloud 账本必有 syncId),直接事务化断联。
      await repo.detachFromCloud(ledgerId);
      return;
    }

    // 登记两个信号(顺序:先 abort 再 waitSettle)。
    //   - _pendingMoveToLocalSyncIds:拦 WS removed 回声,防本地被 purge;
    //   - _moveToLocalAbortRequests:拦 fullPush / 增量 push 写 S1 路径。
    // 必须先登记 abort 再 waitFullPushSettle——信号是持久状态,能拦截
    // waitFullPushSettle 返回后(检查到无 in-flight)到 deleteLedger 之间由 auto sync
    // 新触发的 fullPush / push,堵住「检查之后才启动」的推送窗口。
    _pendingMoveToLocalSyncIds.add(syncId);
    _moveToLocalAbortRequests.add(ledgerId);
    try {
      // Step 1:等 in-flight fullPush 收敛(30s 超时)。超时说明 fullPush 卡死,
      // 无法确认云端处于什么状态,保守 fail-closed:账本保持 cloud、抛异常
      // (finally 会撤销信号,不残留)。
      try {
        await waitFullPushSettle(ledgerId)
            .timeout(const Duration(seconds: 30));
      } on TimeoutException catch (e, st) {
        logger.error(
            'SyncEngine', 'moveToLocal 等待 fullPush 收敛超时,账本保持 cloud', e, st);
        throw CloudSyncException('等待云端推送收敛超时,请稍后重试');
      }

      // Step 2:删云端副本 S1(网络调用,事务外)。404/410 幂等放行(其它设备已删
      // 或本就未推全 = 云端无副本);其他错误抛异常、账本保持 cloud、syncId 全程未动。
      try {
        await provider.deleteLedger(ledgerId: syncId);
      } catch (e, st) {
        final msg = e.toString();
        if (msg.contains('404') || msg.contains('410')) {
          logger.warning('SyncEngine',
              'moveToLocal 删云端副本命中 404/410(云端已无副本),幂等放行 syncId=$syncId', st);
        } else {
          logger.error(
              'SyncEngine', 'moveToLocal 删除云端副本失败,账本保持 cloud', e, st);
          throw CloudSyncException('删除云端副本失败:$e');
        }
      }

      // Step 3:云端已删(或确认不存在),本地事务化翻 local + 清 syncId。三级收敛,
      // 绝不裸调 repo.detachFromCloud——云端已删无法回退,detach 失败必须重试 →
      // 降级清 syncId → 记危险态,保证账本留本地不被 purge。
      await _detachFromCloudWithFallback(ledgerId, syncId);
    } finally {
      // 无论成功、抛异常、还是降级,都必清两个信号集合,避免误伤后续真实事件
      // 与阻塞后续正常推送。
      _pendingMoveToLocalSyncIds.remove(syncId);
      _moveToLocalAbortRequests.remove(ledgerId);
    }
  }

  /// detachFromCloud 的重试 + 降级封装(仅供 [moveToLocal] 在云端已删后调用)。
  ///
  /// 语境:此时云端副本**已删除**,无法回退到 cloud 态(重试删云端必 404),因此
  /// 唯一可接受的终态是「账本留本地」。本方法分三级收敛:
  ///   1. 事务化 detachFromCloud,失败按 SQLite busy/locked 瞬时锁短重试 2 次;
  ///   2. 仍失败 → 降级 best-effort,**优先级反转先清 syncId**:tombstone 按
  ///      syncId 匹配,先清 syncId 即可让 pull 命中 miss,消除整本 purge 的最高风险;
  ///   3. 降级两条 update 各自 try-catch,绝不 rethrow「保持云端」(会破坏幂等)。
  ///
  /// 终态语义:
  ///   - 成功 / B 态(syncId 已清)→ 数据完好,正常返回(UI 显示成功);
  ///   - A 态(两条降级全失败,syncId 仍在)→ 记「危险态」日志(下次 pull 可能
  ///     purge),但仍正常返回不抛异常——账本数据当前留在本地,若抛异常 UI 会引导
  ///     重试,而重试删云端必 404 死循环,反而破坏幂等、卡死用户。
  Future<void> _detachFromCloudWithFallback(int ledgerId, String syncId) async {
    // 1) 事务化断联 + 瞬时锁短重试(粒度对齐代码库既有 busy retry 先例)。
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await repo.detachFromCloud(ledgerId);
        return; // 成功:终态 local + syncId=null
      } catch (e, st) {
        if (attempt < maxAttempts) {
          logger.warning('SyncEngine',
              'moveToLocal detachFromCloud 第 $attempt 次失败,重试: $e', st);
          // 短间隔退避,兜 SQLite busy/locked 瞬时锁。
          await Future<void>.delayed(Duration(milliseconds: 50 * attempt));
          continue;
        }
        logger.error(
            'SyncEngine', 'moveToLocal detachFromCloud 重试耗尽,进入降级', e, st);
      }
    }

    // 2) 降级 best-effort:优先清 syncId(先消除被 tombstone 整本 purge 的最高风险)。
    var syncIdCleared = false;
    var modeFlipped = false;
    try {
      await repo.updateLedgerSyncId(id: ledgerId, syncId: null);
      syncIdCleared = true;
    } catch (e, st) {
      logger.error('SyncEngine', 'moveToLocal 降级清 syncId 失败', e, st);
    }
    try {
      await repo.updateLedgerStorageMode(id: ledgerId, storageMode: 'local');
      modeFlipped = true;
    } catch (e, st) {
      logger.error('SyncEngine', 'moveToLocal 降级翻 local 失败', e, st);
    }

    // 3) 终态分级处理。
    if (syncIdCleared) {
      // 已清 syncId:整本 purge 的最高风险已消除,数据完好。
      //   - 同时翻了 local → 完整成功态;
      //   - 仅清 syncId 未翻 local(B 态,cloud + syncId=null,云端已删的孤儿态)
      //     → 数据非阻塞,用户重试 moveToLocal 时 syncId 已空会直接置 local 自愈。
      if (!modeFlipped) {
        logger.warning('SyncEngine',
            'moveToLocal 降级:已清 syncId 但未翻 local(B 态),账本数据完好可重试自愈 ledgerId=$ledgerId');
      }
      return;
    }

    // A 态:两条降级全失败,syncId 仍在——危险态,下次 pull 可能按 tombstone 整本
    // purge(含降级后新数据、不可自愈)。记危险日志留痕;但仍正常返回不抛异常:
    // 账本数据当前留在本地,抛异常会让 UI 引导重试,而重试删云端必 404 死循环。
    logger.error(
        'SyncEngine',
        'moveToLocal 降级全失败(A 态危险):syncId 未清,下次 pull 可能整本 purge,'
            '请引导用户重试转本地 ledgerId=$ledgerId syncId=$syncId',
        StateError('detach fallback all failed'));
  }

  /// 复制云端/共享账本到本地。
  ///
  /// 保留云端副本不动;新建一个全新的本地账本(新 syncId、isShared=false、断联共享),
  /// 并拷贝全量交易与编辑历史。本地账本禁止复制(它本身就是本地)。
  /// 返回新建本地账本 id,供 UI 跳转。
  @override
  Future<int> copyToLocal(int sourceLedgerId) async {
    final src = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(sourceLedgerId)))
        .getSingleOrNull();
    if (src == null) throw CloudSyncException('源账本不存在: $sourceLedgerId');
    if (src.storageMode == 'local') {
      throw CloudSyncException('本地账本已是本地,无需复制');
    }
    // 新建本地账本(全新 syncId、isShared 默认 false、断联共享元数据)
    // aaEnabled 透传源账本:副本保持与源账本一致的 AA 分摊开关,
    // 避免"云端开 AA 分摊 → 复制到本地 → 开关悄悄关闭"的语义漂移。
    final newId = await repo.createLedger(
      name: '${src.name}(副本)',
      currency: src.currency,
      storageMode: 'local',
      aaEnabled: src.aaEnabled,
    );
    // 拷贝全量交易 + 编辑历史 + AA 分摊字段 + 虚拟用户(分类是全局表,无需拷贝)
    await repo.copyLedgerData(
      sourceLedgerId: sourceLedgerId,
      targetLedgerId: newId,
    );
    return newId;
  }

  @override
  void clearStatusCache({int? ledgerId}) {
    if (ledgerId != null) {
      _statusCache.remove(ledgerId);
    } else {
      _statusCache.clear();
    }
  }

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async {
    // 对于增量同步，fingerprint 概念不太适用
    // 返回基本信息即可
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final hasRemote = await provider.storage.exists(
      path: ledgerRow?.syncId ?? ledgerId.toString(),
    );
    if (!hasRemote) {
      return (fingerprint: null, count: null, exportedAt: null);
    }
    return (
      fingerprint: 'incremental',
      count: null,
      exportedAt: DateTime.now(),
    );
  }

  /// 释放资源
  void dispose() {
    stopListeningRealtime();
    _eventsController.close();
  }

  // ==================== 核心同步逻辑 ====================

  /// 枚举本地所有"云端账本"(storage_mode=='cloud' 且 syncId 非空)。
  ///
  /// 私有:枚举全部云端账本。
  ///
  /// 设计要点:refresh() 不依赖 currentLedgerIdProvider —— 本地账本选中时
  /// currentLedgerId 指向 local 账本,单本 sync() 会被 storage_mode 闸门
  /// 直接 return,云端账本同步不到。故统一由本方法枚举全部云端账本,供
  /// [syncAccount] / [SyncEngineHealthChecks.checkAccountHealth] 使用。
  ///
  /// 降为私有的原因:云端账本枚举是同步引擎的内部职责,外部(UI)不应直接
  /// 触碰 —— 一律通过 [syncAccount](同步) 或 checkAccountHealth(对账)
  /// 两个账户级入口间接获得,避免 UI 层绕开决策逻辑拼凑账本列表。
  ///
  /// 返回按 id 升序,保证跨刷新顺序稳定(健康检测以第一个为准)。
  Future<List<Ledger>> _queryCloudLedgers() async {
    final rows = await (db.select(db.ledgers)
          // 归属判定统一走 ledger_kind.dart 的 SQL 工厂(与 isCloudLedgerOf 同源)。
          ..where(cloudLedgerFilter)
          ..where((l) => l.syncId.isNotNull()))
        .get();
    // syncId 为空串(从未成功同步)的账本无法 push,同样不算云端账本
    return rows
        .where((l) => (l.syncId ?? '').isNotEmpty)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// 执行完整同步（先 push 后 pull）
  Future<SyncResult> sync({required String ledgerId}) async {
    logger.info('SyncEngine', '开始同步 ledger=$ledgerId');
    try {
      final ledgerIdInt = int.tryParse(ledgerId) ?? -1;
      int pushed = 0;

      // 决策：fullPush 还是增量 push
      //
      // 单 ledger 粒度:本账本的 syncId **不在** 远端 `/sync/ledgers` 列表
      // 里 → fullPush;在 → 增量 _push。
      //
      // 跟旧 `storage.exists(path: ledger.syncId)` 等价(后者内部就是 list +
      // path 比对),但显式 list 一次自己比对,避免后续 snapshot 概念退场后
      // 误判持续返 false。
      //
      // 边界:`ledger.syncId == null`(本地刚建账本还没 sync 过)→ 一定不在
      // 远端列表,触发 fullPush。fullPush 内部 `_ensureLedgerSyncId` 会先
      // 生成 UUID 写回,确保 `pathForSnapshot` 合法。
      final ledgerRow = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerIdInt)))
          .getSingleOrNull();

      // 闸门:纯本地账本(storage_mode == 'local' 且非共享)不参与被动同步,
      // 既不上推也不下拉,从源头杜绝本地数据被误传到云端。只有"账本已被删除
      // (ledgerRow==null)"才需要继续,把 delete change 推上去清掉云端
      // canonical state。注意:判定统一走 ledger_kind.dart 的 isLocalLedger
      // (显式 local + 非共享双条件),共享账本即使 storageMode 缺失也会被
      // isCloudLedger 命中,不会翻转成本地账本漏同步。
      if (ledgerRow != null && ledgerRow.isLocalLedger) {
        logger.info('SyncEngine',
            '账本 $ledgerId 为本地账本(storage_mode=${ledgerRow.storageMode}),跳过 sync');
        return SyncResult(pushed: 0, pulled: 0);
      }

      // 短路:本地账本已删除(deleteLedger 路径)。这种情况下:
      //   - hasRemote 检查没意义(syncId 已经丢,fallback 到 int id 对 UUID 账本
      //     会误判)
      //   - fullPush 会 getSingle 抛错(ledger 行不存在)
      //   - pull 也没意义(账本都没了拉啥)
      // 唯一要做的是把 deleteLedger 已登记到 local_changes 的 ledger_snapshot:
      // delete + transaction:delete 推到 server,清掉 canonical state,否则
      // remote ledgers 列表里还会显示这个被删的账本。
      if (ledgerRow == null) {
        final pushed = await push(ledgerId);
        logger.info(
            'SyncEngine', '账本 $ledgerId 已本地删除,push delete changes: $pushed 条');
        return SyncResult(pushed: pushed, pulled: 0);
      }

      // 共享账本:Editor 永不 fullPush(会把 Editor 本地状态覆盖 Owner 的)。
      final isSharedAsEditor =
          ledgerRow.isShared && ledgerRow.myRole != 'owner';

      bool shouldFullPush = false;
      if (!isSharedAsEditor) {
        try {
          final remoteLedgers = await provider.storage.list(path: '');
          // 用本账本的 syncId 跟远端列表比对(没 syncId 视为不在)。
          final mySyncId = ledgerRow.syncId;
          final remoteHasThisLedger = mySyncId != null &&
              mySyncId.isNotEmpty &&
              remoteLedgers.any((l) => l.path == mySyncId);
          shouldFullPush = !remoteHasThisLedger;
          logger.info('SyncEngine',
              '远端账本=${remoteLedgers.length}, 本账本(syncId=$mySyncId) 命中=$remoteHasThisLedger → fullPush=$shouldFullPush');
        } catch (e, st) {
          // list 失败保守走增量(fullPush 风险更大)。
          logger.warning('SyncEngine', '远端 ledger 列表查询失败,按已存在处理: $e', st);
        }
      }

      if (shouldFullPush) {
        // 远端没这个账本 → 首次绑定 / server 数据被清。
        // fullPush 推所有 entity + ledger 自身。

        // 关键:fullPush 前先确保 ledger.syncId 已生成(UUID 串)。否则会
        // fallback 到 `ledger.id.toString()` = 短数字串(如 "2"),触发
        // server 端 WriteLedgerCreateRequest 的 min_length=3 校验失败,并且
        // 跨设备时 server 上挂着的 external_id 也会变成本地 int id,后续多
        // 设备 sync 必然分裂。
        await _ensureLedgerSyncId(ledgerRow);

        final localTxCount = (await (db.select(db.transactions)
                  ..where((t) => t.ledgerId.equals(ledgerIdInt)))
                .get())
            .length;
        logger.info('SyncEngine', '远端无数据,本地 $localTxCount 条交易,触发 fullPush');

        await fullPush(ledgerId: ledgerIdInt);
        // fullPush 不处理 delete change(_pushAllEntities 只 upsert 当前实体)。
        // fullPush 已把非 delete change 都 markPushed,这里 _push 推剩余的
        // delete change,清掉 server canonical state。
        final extraPushed = await push(ledgerId);
        pushed = localTxCount + extraPushed;
      } else {
        pushed = await push(ledgerId);
        logger.info('SyncEngine', '增量推送: $pushed 条');
      }

      final pulled = await pull(ledgerId);

      // 增量拉取为空时自愈:本地可能缺云端数据(游标孤悬)。
      // pulled==0 既可能是"已是最新",也可能是"本地游标越过云端的变更"。
      // _selfHealIfMissing 内部以 checkLedgerHealth 区分(节流/闸门/熔断
      // 保护),覆盖 WS 重连 / 切账本 / 开屏 / 同步页按钮等所有走 sync()
      // 的入口。
      int effectivePulled = pulled;
      if (pulled == 0) {
        final heal = await _selfHealIfMissing(ledgerId);
        if (heal.healed > 0) effectivePulled = heal.healed;
      }

      // 顺手再拉一次 profile（多数场景 bootstrap 已经拉过，这里幂等兜底）。
      await syncMyProfile();

      final result = SyncResult(pushed: pushed, pulled: effectivePulled);
      // 【根因修复】同步完成后清掉本账本 getStatus 的 _statusCache,跟手动上传/
      // 下载路径(uploadToCloudFromCurrentLedger / downloadAndRestoreToCurrentLedger
      // 里的 _statusCache.remove)保持一致。否则 push 后 unpushedCount 已归零,但
      // 「我的」页 syncStatus 仍命中旧缓存(localNewer),用户必须手动去详情页下拉
      // 刷新(那条路径清了缓存)状态才更新 —— 这正是本 bug 的根因。
      if (ledgerIdInt > 0) {
        clearStatusCache(ledgerId: ledgerIdInt);
      }
      // 缓存清掉只是让下次 getStatus 会重算;还得有人触发 syncStatusProvider 去重读。
      // push 上传了本地变更时 emit PushCompleted,listener 收到后 bump
      // syncStatusRefresh → 重读 getStatus(缓存已清 → 重算为 inSync)。
      if (pushed > 0) {
        _emit(PushCompleted(ledgerId: ledgerId, pushed: pushed));
      }
      // 已推送行按 7 天保留期周期清理，防止 local_changes 无限膨胀。
      await _maybeCleanupPushedChanges();
      logger.info('SyncEngine', '同步完成: $result');
      return result;
    } catch (e, st) {
      logger.error('SyncEngine', '同步失败', e, st);
      _emit(SyncFailed(ledgerId: ledgerId, error: e.toString()));
      return SyncResult(error: e.toString());
    }
  }

  /// 周期性清理已推送 7 天以上的 local_changes（节流 1 小时）。
  Future<void> _maybeCleanupPushedChanges() async {
    final now = DateTime.now();
    if (_lastPushedCleanupAt != null &&
        now.difference(_lastPushedCleanupAt!) < const Duration(hours: 1)) {
      return;
    }
    _lastPushedCleanupAt = now;
    try {
      await changeTracker.cleanupPushedChanges();
    } catch (e, st) {
      logger.warning('SyncEngine', '清理已推送变更失败(忽略): $e', st);
    }
  }

  /// 账户级同步原语:应用冷启动(app.dart)与云同步页下拉(refresh)共用的
  /// 统一入口,"逐个账本怎么同步"的决策收敛在引擎内部。
  ///
  /// 内部流程:
  /// - Phase 1(用户级一次性,跨账本共享):syncMyProfile → storage.list →
  ///   pull('') → pushUserGlobalEntities;
  ///   (含一次 syncLedgersFromServer 账本清单对账:补建缺失账本、GC 清理
  ///   server 已不存在的残留共享账本,保证账户级计数口径与远端一致);
  /// - Phase 2(每个云端账本):复用同一次 storage.list 结果做 fullPush/增量
  ///   决策,无待推 + 已绑定(fast-skip)直接跳过;pull 是用户级全局流,
  ///   统一由收尾处的单次 pull('') 覆盖,不逐账本空探针。
  ///
  /// 为什么自实现决策循环而不是循环调 [sync]:
  /// - 保持"一次 list 复用全部账本"的请求优化;
  /// - 保留 fast-skip —— 循环 [sync] 会退化成每账本空 push/pull;
  /// - storage.list 失败时与 [sync] 一致保守走增量 push(fullPush 会覆盖
  ///   云端数据,list 失败时风险更大)。
  ///
  /// 返回 [SyncAccountResult] 供日志与测试断言,UI 不直接展示。
  Future<SyncAccountResult> syncAccount() async {
    final overallStart = DateTime.now();
    var totalPushed = 0;
    var totalPulled = 0;
    var skipped = 0;

    // ---------- Phase 1: 用户级一次性 ----------
    // a) profile / appearance / AI config / avatar。
    try {
      await syncMyProfile();
    } catch (e, st) {
      logger.warning('SyncEngine', 'syncAccount: syncMyProfile 失败', st);
    }

    // b) 远端账本列表(单次拉,所有账本用同一份决定 fullPush)。
    List<dynamic>? remoteLedgers;
    try {
      remoteLedgers = await provider.storage.list(path: '');
    } catch (e, st) {
      logger.warning('SyncEngine',
          'syncAccount: 拉远端账本列表失败,后续按"未绑定"保守增量处理', st);
    }
    final remoteSyncIds = remoteLedgers == null
        ? null
        : <String>{
            for (final r in remoteLedgers)
              if (r.path is String) r.path as String,
          };

    // b2) 账本清单对账:syncLedgersFromServer 按 /sync/ledgers 权威清单
    //     补建本地缺失的云端/共享账本,并 GC 清理 server 已不返回的残留
    //     共享账本。否则这些残留账本(及其带 syncId 的交易)会一直计入
    //     账户级 totalTx,造成「云端账本已同步完但面板仍报差异」的永久
    //     假阳性,且 syncAccount 永远不会推送它们、差异永远消不掉。
    //     单飞锁保证与 WS 重连等入口并发时只跑一次;失败不阻塞主同步。
    try {
      await syncLedgersFromServer();
    } catch (e, st) {
      logger.warning(
          'SyncEngine', 'syncAccount: syncLedgersFromServer 失败(继续同步): $e', st);
    }

    // c) 用户级 sync_changes 流(只拉一次,所有账本共享 cursor)。
    try {
      totalPulled += await pull('');
    } catch (e, st) {
      logger.error('SyncEngine', 'syncAccount: pull(用户级) 失败', e, st);
    }

    // d) 推 user-global change(category / tag)。
    //    即使 Phase 2 全部 fast-skip(无 ledger-scope 待推 + 已在远端),
    //    user-global 的新增/重命名也能推上去,不依赖 Phase 2 是否 skip。
    try {
      totalPushed += await pushUserGlobalEntities();
    } catch (e, st) {
      logger.error('SyncEngine', 'syncAccount: pushUserGlobalEntities 失败', e, st);
    }

    // ---------- Phase 2: 每个云端账本 ----------
    final ledgers = await _queryCloudLedgers();
    for (final ledger in ledgers) {
      final tag = '${ledger.name}(${ledger.id})';
      try {
        final unpushed =
            await changeTracker.getUnpushedChangesForLedger(ledger.id);
        final mySyncId = ledger.syncId;
        final hasSyncId = mySyncId != null && mySyncId.isNotEmpty;
        final inRemote = hasSyncId && remoteSyncIds?.contains(mySyncId) == true;

        // fast-skip:无待推送 + 已绑定 → 整账本跳过 push/pull。
        if (unpushed.isEmpty && inRemote) {
          skipped++;
          logger.info('SyncEngine', 'syncAccount: skip $tag (无待推送 + 已绑定)');
          continue;
        }

        // 共享账本 Editor:只 push 自己的 unpushed change,不 fullPush
        // (会覆盖 Owner 数据)。
        final isSharedAsEditor = ledger.isShared && ledger.myRole != 'owner';

        int pushedForLedger;
        if (remoteSyncIds == null && !isSharedAsEditor) {
          // storage.list 失败:保守走增量 push(fullPush 覆盖云端风险更大)。
          pushedForLedger = await push(ledger.id.toString());
        } else if (!inRemote && !isSharedAsEditor) {
          // 远端没这个账本 → 首次绑定 / server 数据被清 → fullPush。
          // fullPush 前先确保 syncId 是 UUID(否则 server 校验 min_length=3
          // 失败,且跨设备 external_id 会分裂)。
          await _ensureLedgerSyncId(ledger);
          final localTxCount = (await (db.select(db.transactions)
                    ..where((t) => t.ledgerId.equals(ledger.id)))
                  .get())
              .length;
          await fullPush(ledgerId: ledger.id);
          // fullPush 不处理 delete change,这里 _push 推剩余的 delete change,
          // 清掉 server canonical state。
          final extraPushed = await push(ledger.id.toString());
          pushedForLedger = localTxCount + extraPushed;
          logger.info('SyncEngine', 'syncAccount: $tag → fullPush 完成');
        } else {
          // 普通增量路径:只推本账本 unpushed change。
          pushedForLedger = await push(ledger.id.toString());
        }
        totalPushed += pushedForLedger;

        // 与 sync() 对齐:push 完成后清掉本账本的 getStatus 缓存,并广播
        // PushCompleted 供 UI 刷新。否则 auto sync(走 syncAccount)推完后,
        // 账本管理页的同步状态仍会命中 markLocalChanged 后的旧 localNewer 缓存
        // —— 数据已推送但图标一直红色。
        if (pushedForLedger > 0) {
          clearStatusCache(ledgerId: ledger.id);
          _emit(PushCompleted(
            ledgerId: ledger.id.toString(),
            pushed: pushedForLedger,
          ));
        }

      } catch (e, st) {
        logger.error('SyncEngine', 'syncAccount: $tag 同步异常', e, st);
      }
    }

    // 收尾:用户级 pull('')。
    // 为什么放在 Phase 2 之后、且仅在有实际推送时才跑:
    // - 本轮 push 成功后,server 端可能因其他设备写入而产生新的用户级变更
    //   (profile / user-global 类),若不在 syncAccount 末尾补一次用户级拉取,
    //   这些变更要等到下次同步才会落到本地;
    // - 用 totalPushed > 0 作为触发条件(已覆盖 userGlobalPushed || ledgerPushed
    //   两种有推送的情形),无推送时跳过,避免每次同步空跑一轮用户级 pull;
    // - 走既有 pull() 单飞锁(reuse / 排队),不会重复拉取旧数据。
    if (totalPushed > 0) {
      try {
        totalPulled += await pull('');
      } catch (e, st) {
        logger.error('SyncEngine', 'syncAccount: 收尾 pull(用户级) 失败', e, st);
      }
    }

    // 与实时 pull 对齐:有数据被拉取应用时,清空状态缓存并广播 PullCompleted,
    // 避免 syncAccount 内的 pull('') 不经 _schedulePull 而没有清缓存/刷新,
    // UI 一直显示旧同步状态。
    if (totalPulled > 0) {
      clearStatusCache();
      _emit(PullCompleted(ledgerId: '', applied: totalPulled));
    }

    // 周期清理已推送的旧变更（与 sync() 同节流）。
    await _maybeCleanupPushedChanges();

    final elapsedMs = DateTime.now().difference(overallStart).inMilliseconds;
    logger.info('SyncEngine',
        'syncAccount 完成: pushed=$totalPushed pulled=$totalPulled skipped=$skipped 耗时 ${elapsedMs}ms');
    return SyncAccountResult(
      pushed: totalPushed,
      pulled: totalPulled,
      skipped: skipped,
      elapsedMs: elapsedMs,
    );
  }

  /// fullPush 前确保 ledger.syncId 已生成。
  ///
  /// 没 syncId 时 `pathForSnapshot` 会 fallback 到 `ledger.id.toString()`(短
  /// 数字串如 "2"),走两个失败路径:
  /// - `writeCreateLedger` 的 `WriteLedgerCreateRequest.ledger_id` 校验 min_length=3
  /// - server 端 ledger.external_id 被写成 int id 字符串,跨设备时同一账本
  ///   external_id 会分裂(A 设备的 syncId=UUID,B 设备的 syncId=int)
  ///
  /// 这里在 fullPush 入口做最后兜底,生成 UUID 写回。
  Future<void> _ensureLedgerSyncId(Ledger ledger) async {
    if (ledger.syncId != null && ledger.syncId!.length >= 3) return;
    final newSyncId = _uuid.v4();
    await (db.update(db.ledgers)..where((l) => l.id.equals(ledger.id)))
        .write(LedgersCompanion(syncId: d.Value(newSyncId)));
    logger.info(
        'SyncEngine', 'fullPush 前补生成 ledger.syncId: ${ledger.id} → $newSyncId');
  }

  /// 首次登录 / app 启动时从 server 拉全部账本写本地 Drift。
  ///
  /// Server 的 ledger 不走 sync_change log（只有 tx/cat 走），
  /// 所以设备 B 首次登录时 `_pull` 拿不到 A 已有的账本。这个方法专门补这一
  /// 刀：走 `GET /sync/ledgers` 拿列表，按 `external_id` 对齐本地 `syncId`
  /// upsert 到 Drift。
  ///
  /// 新插入的 ledger 对应的 tx/category sync_changes 记录会被
  /// `replayAllChanges`（由调用方在必要时触发）从 cursor=0 重放应用，因为
  /// 此时设备全局 cursor 可能已经前移、普通 `_pull` 再也拉不回历史。
  ///
  /// 返回新增（非已存在）的账本数，调用方可据此决定要不要 bump 刷新信号。
  /// 并发互斥锁 — **static** 跨 SyncEngine 实例共享。
  /// 关键 bug:join page 拿 syncEngineProvider(family) 的 engine,WS listener
  /// 拿 cloudSyncServiceProvider 创建的 engine,两个不同 instance!instance-level
  /// 字段互不知道,各跑各的。改 static 后整个进程同一时间只有一个 fetch-then-write
  /// 在跑。
  static Completer<int>? _syncLedgersInFlight;

  Future<int> syncLedgersFromServer() async {
    final existing = _syncLedgersInFlight;
    if (existing != null) {
      logger.info('SyncEngine', 'syncLedgersFromServer 已在执行中,等待 in-flight 结果');
      return existing.future;
    }
    final completer = Completer<int>();
    _syncLedgersInFlight = completer;
    try {
      final n = await _syncLedgersFromServerLocked();
      completer.complete(n);
      return n;
    } catch (e, st) {
      // completer.future 仅供并发去重的第二个调用方等待;单调用场景下无人
      // 监听,必须先 ignore() 标记已处理,否则 completeError 会让这个 future
      // 变成 zone 级 unhandled async error(rethrow 已把错误交给当前调用方)。
      // _syncLedgersFromServerLocked 全捕获 return 0 永不抛,此路径
      // 从未触发;本次为让网络错误逃逸到 bootstrap 而引入 rethrow,才需要补。
      completer.future.ignore();
      completer.completeError(e, st);
      rethrow;
    } finally {
      _syncLedgersInFlight = null;
    }
  }

  Future<int> _syncLedgersFromServerLocked() async {
    logger.info('SyncEngine', 'syncLedgersFromServer start');
    // readLedgers 的异常分类必须放在下面的外层 try 之【前】:
    // 网络分支的 rethrow 需要逃出本方法到 syncLedgersFromServer 的 rethrow,
    // 让 bootstrap 记 lastSyncError / UI 展示。若放在外层 try 内,
    // 会先被外层 catch(return 0)吞掉,错误永远到不了 bootstrap。
    late final List<SpitoutCloudReadLedger> remote;
    try {
      remote = await provider.readLedgers();
      _resetRemoteFetchFailures(); // 成功一次即重置阈值计数
    } on CloudNotAuthenticatedException {
      // 登录态失效:远端等价于空集,本地 isShared 全是孤儿 → 全量清。
      // 非错误态(session 确认失效的正常状态变更),不 rethrow、UI 不报同步错误。
      logger.info('SyncEngine', 'readLedgers 未认证 → 全量清本地共享账本');
      if (!_suppressLedgerGc) await _gcAllLocalSharedLedgers();
      return 0;
    } on CloudConfigurationException {
      // 配置损坏 / storage 未就绪:云已失活 → 全量清,同上非错误态。
      logger.info('SyncEngine', 'readLedgers 配置失效 → 全量清本地共享账本');
      if (!_suppressLedgerGc) await _gcAllLocalSharedLedgers();
      return 0;
    } on CloudStorageException catch (e) {
      // 404/410:路由确死(远端资源不存在) → 等价空集,立即清、不报错。
      if (e.statusCode == 404 || e.statusCode == 410) {
        logger.info(
            'SyncEngine', 'readLedgers ${e.statusCode} → 全量清本地共享账本');
        if (!_suppressLedgerGc) await _gcAllLocalSharedLedgers();
        return 0;
      }
      // 5xx / 未知状态码:可能瞬时抖动,计入阈值;命中阈值才清;错误上抛。
      _onRemoteFetchNetworkFailure();
      if (_remoteDownConfirmed() && !_suppressLedgerGc) {
        await _gcAllLocalSharedLedgers();
      }
      rethrow;
    } catch (e) {
      // Socket / Timeout 等网络错误:同 5xx 走阈值判定,错误上抛给 bootstrap。
      _onRemoteFetchNetworkFailure();
      if (_remoteDownConfirmed() && !_suppressLedgerGc) {
        await _gcAllLocalSharedLedgers();
      }
      rethrow;
    }
    try {
      int upserted = 0;
      int inserted = 0;
      // 新设备登录场景:Editor 已是 server LedgerMember 但本地 ledgers 表为空。
      // 检测到 isShared && myRole != owner 的新 insert 时,记下 syncId,本轮
      // 结束后批量拉 /shared-resources 落 SharedLedger* 表。不放循环里直接
      // await 是因为 fetchAndStoreSharedResources 走 HTTP,放循环里会串行慢,
      // 也会让单个失败影响其它账本。
      final newSharedLedgerSyncIds = <String>[];

      // 一次性加载本地全部账本,循环内用内存索引匹配,避免对每条远端账本各发串行 SELECT。
      // 两条必须保留的语义:(a) ledgers.sync_id 无 UNIQUE 约束,历史 dup 行可能
      // 存在,故 syncId 索引用 List 而非 single;(b) byName 收编须带 syncId IS NULL +
      // storage_mode='cloud' + isShared 同类型,防止纯本地私密账本被同名云端账本收编(L1)。
      final allLedgers = await (db.select(db.ledgers)).get();
      final bySyncId = <String, List<Ledger>>{}; // syncId → 命中的本地账本列表(保留 dup)
      final nameFallbackMap = <String, Ledger>{}; // 收编候选:仅 syncId 为 NULL 且 storage_mode='cloud' 的行,按 "name|isShared" 索引
      final takenNames = <String>{}; // 所有已占用名(含既有账本 + 本轮 insert 的新名),供重名改名
      for (final l in allLedgers) {
        final sid = l.syncId;
        if (sid != null && sid.isNotEmpty) {
          bySyncId.putIfAbsent(sid, () => []).add(l);
        }
        // 半截云端账本收编候选判定(专用,不可替换)。
        // 为什么不能用统一的 isCloudLedgerOf / cloudLedgerFilter:
        // 完整归属判定含 `|| isShared`,但这里收编语义只认「storageMode 恰为
        // 'cloud' 且无 syncId」的半截账本 —— isShared 在此是 nameFallbackMap
        // 键(`${name}|${isShared}`)的独立维度,若套用统一判定引入 isShared,会把
        // 纯本地私密账本(storageMode=local 但 isShared 借位)误收编为同名云端账本(L1)。
        // 完整的「云端/本地账本归属」统一判定只在 ledger_kind.dart,改动须回该处。
        // storage_mode 为自由文本('cloud'/'local'/null),收编判定须显式写
        // `== 'cloud'`,不能复用云账本归属工厂(工厂语义含 `|| isShared`,见上)。
        if (sid == null && l.storageMode == 'cloud') {
          nameFallbackMap['${l.name}|${l.isShared}'] = l;
        }
        takenNames.add(l.name);
      }

      for (final r in remote) {
        final syncId = r.ledgerId;
        if (syncId.isEmpty) continue;
        // 内存匹配 bySyncId;列表保留 dup 语义:有则保第一行,GC 其余 dup 行。
        final existingList = bySyncId[syncId] ?? const <Ledger>[];
        if (existingList.isNotEmpty) {
          final existing = existingList.first;
          // update meta（name / currency / 共享账本字段 server 可能改过）
          await (db.update(db.ledgers)..where((l) => l.id.equals(existing.id)))
              .write(LedgersCompanion(
            name: d.Value(r.ledgerName),
            // 有 syncId 且 server 认它 = 云端账本。storage_mode 缺省为 'local'
            // 的数据在这里被就地修正,避免被本地闸门永久挡住同步。
            storageMode: const d.Value('cloud'),
            currency: d.Value(r.currency),
            myRole: d.Value(r.role),
            isShared: d.Value(r.isShared),
            memberCount: d.Value(r.memberCount),
            monthStartDay: r.monthStartDay != null
                ? d.Value(r.monthStartDay!.clamp(1, 28))
                : const d.Value.absent(),
            // aaEnabled:仅当 server 显式返回该字段(hasAaEnabled)时覆盖本地值;
            // 老 server 不返回 → absent,保留本地已开启的 AA 开关,避免静默关闭。
            aaEnabled: r.hasAaEnabled
                ? d.Value(r.aaEnabled)
                : const d.Value.absent(),
          ));
          // 删 dup 行(及其关联 tx/local_changes,虽然 dup 行还没有这些)
          if (existingList.length > 1) {
            final dupIds = existingList.skip(1).map((l) => l.id).toList();
            logger.warning('SyncEngine',
                '检测到 ledger.syncId=$syncId 重复 ${existingList.length} 行,清除 dup id=$dupIds');
            await (db.delete(db.transactions)
                  ..where((t) => t.ledgerId.isIn(dupIds)))
                .go();
            await (db.delete(db.localChanges)
                  ..where((c) => c.ledgerId.isIn(dupIds)))
                .go();
            await (db.delete(db.ledgers)..where((l) => l.id.isIn(dupIds))).go();
          }
          upserted++;
          continue;
        }
        // fallback:按 "name|isShared" 在 nameFallbackMap 取收编候选(仅 syncId 为 NULL 且
        // storage_mode='cloud' 的半截云端账本)。消费式 remove 防止重复收编;收编类型
        // (共享/个人)须与远端一致,避免纯本地私密账本被同名云端账本静默收编(L1)。
        final byName = nameFallbackMap.remove('${r.ledgerName}|${r.isShared}');
        if (byName != null) {
          await (db.update(db.ledgers)..where((l) => l.id.equals(byName.id)))
              .write(LedgersCompanion(
            syncId: d.Value(syncId),
            storageMode: const d.Value('cloud'),
            currency: d.Value(r.currency),
            myRole: d.Value(r.role),
            isShared: d.Value(r.isShared),
            memberCount: d.Value(r.memberCount),
            monthStartDay: r.monthStartDay != null
                ? d.Value(r.monthStartDay!.clamp(1, 28))
                : const d.Value.absent(),
            // 同 update 路径:hasAaEnabled=false 时 absent 保留本地值,
            // 防止老 server 把本地已开启的 AA 分摊静默关闭。
            aaEnabled: r.hasAaEnabled
                ? d.Value(r.aaEnabled)
                : const d.Value.absent(),
          ));
          upserted++;
          continue;
        }
        // 全新账本：insert。id 是本地 autoIncrement，跟 server 无关。
        //
        // 与既有账本(通常是同名的纯本地账本)重名时加「（云端）」后缀:两本同名
        // 账本一个上云一个不上云,列表里完全分不清,改名比让用户猜更安全。
        final displayName = await _resolveCloudLedgerName(r.ledgerName, takenNames);
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
              name: displayName,
              currency: d.Value(r.currency),
              syncId: d.Value(syncId),
              // 从 server 拉下来的账本天然属于云端,必须显式标记 —— 否则会落到
              // storage_mode 的默认值 'local',被三路闸门当成纯本地账本挡住,
              // 表现为「账本在列表里但永远不同步」。
              storageMode: const d.Value('cloud'),
              myRole: d.Value(r.role),
              isShared: d.Value(r.isShared),
              memberCount: d.Value(r.memberCount),
              monthStartDay: r.monthStartDay != null
                  ? d.Value(r.monthStartDay!.clamp(1, 28))
                  : const d.Value.absent(),
              // insert 路径(新账本):server 显式返回就用 server 值,
              // 老 server 不返回时用 false(新账本默认 AA 关闭,与既有客户端默认一致)。
              aaEnabled: d.Value(r.aaEnabled),
            ));
        inserted++;
        // 新设备登录:Editor 的共享账本需要拉 /shared-resources 才能在
        // picker / 详情页 / 洞察 等显示 Owner 的资源。fallback 给 byName
        // 收编路径不记(那是同 ledger 的 syncId 收编,不算新 ledger)。
        if (r.isShared && r.role != 'owner') {
          newSharedLedgerSyncIds.add(syncId);
        }
      }
      logger.info('SyncEngine',
          'syncLedgersFromServer done: total=${remote.length} upserted=$upserted inserted=$inserted');

      // GC 1:清掉本地 isShared=true 但 server 没返回的 ledger — Owner 删了
      // 共享账本,Editor 应该自动清(WS member_change.removed 是主路径,这是
      // 兜底,处理 WS 离线时没推到的情况)。

      // 恢复认领窗口:reregisterRestoredLedgers 把本地账本重新认领到当前
      // 服务器/账号期间,跳过本次 GC1 硬删(被踢/删账本的清理由 WS 事件主路径
      // 负责)。否则认领还没完成、远端集合里还没这些账本,会被误当"server 不
      // 返回"清掉。开关在 reregisterRestoredLedgers 内同步置位、finally 复位。
      if (_suppressLedgerGc) {
        logger.info('SyncEngine', 'GC1 被 _suppressLedgerGc 抑制,跳过共享账本硬删');
        return inserted;
      }

      final remoteSyncIdSet = remote.map((r) => r.ledgerId).toSet();
      final localShared = await (db.select(db.ledgers)
            ..where((l) => l.isShared.equals(true)))
          .get();
      for (final localLedger in localShared) {
        final sid = localLedger.syncId;
        if (sid == null || sid.isEmpty) continue;
        if (remoteSyncIdSet.contains(sid)) continue;
        // server 不返这个共享账本 = Owner 删了 / Editor 被踢 → 清本地
        logger.info('SyncEngine', 'GC: server 不返共享账本 syncId=$sid,清本地数据');
        // 单本 purge 失败不影响其余账本清理(1c:循环内隔离)
        try {
          await _purgeLocalLedgerByExternalId(sid);
        } catch (e, st) {
          logger.warning('SyncEngine', 'GC1 清账本 syncId=$sid 失败(继续): $e', st);
        }
      }

      // GC 2:清掉 SharedLedger* 表里 ledger.syncId 在新拉的 ledgers 表里找不
      // 到的孤儿行(测试残留 / 退出账本残留 / 老 invite 接受过又被 byName
      // fallback 改 syncId 时遗弃的旧 ledger_sync_id 行)
      await _gcOrphanSharedLedgerRows();

      // 新设备登录场景的二次拉取:本轮 insert 的共享账本(Editor 角色)逐个
      // 拉 /shared-resources 把 SharedLedger* 镜像表填上。每个独立 await
      // 单一错误不影响其它账本;成功后 bump tick 让 UI 立即生效。
      if (newSharedLedgerSyncIds.isNotEmpty) {
        logger.info('SyncEngine',
            '新 insert 的共享账本(Editor)$newSharedLedgerSyncIds — 拉 /shared-resources');
        for (final sid in newSharedLedgerSyncIds) {
          try {
            await fetchAndStoreSharedResources(sid);
          } catch (e, st) {
            logger.warning('SyncEngine',
                'fetchAndStoreSharedResources 失败 ledger=$sid: $e', st);
          }
        }
        // 通知 UI 刷新(picker / 详情页 watch sharedResourceRefreshProvider)
        // 这里只是拉了 SharedLedger* 镜像表,tx 没变,不该 emit PullCompleted
        // 触发 home 全刷,走 SharedResourceChanged 精确信号。
        _emit(const SharedResourceChanged(ledgerId: ''));
      }

      return inserted;
    } catch (e, st) {
      logger.warning('SyncEngine', 'syncLedgersFromServer failed: $e', st);
      return 0;
    }
  }

  /// 为「从云端新落地的账本」挑一个不与本地既有账本重名的显示名。
  ///
  /// 归属模型下同名冲突是常态:用户先在本地建了「日常」,又在另一台设备的云端
  /// 建了「日常」。两者不互相收编(见 byName fallback 的 storage_mode 约束),
  /// 因此必须靠改名让用户在列表里分得清哪本会同步。
  ///
  /// 命名序列:`日常（云端）` → `日常（云端2）` → `日常（云端3）` …
  /// 无冲突时原样返回,不做任何修饰。
  ///
  /// [takenNames] 为调用方传入的可变集合,初始为本地全部账本名,本轮每 insert
  /// 一个新账本都会把 displayName 加进去,确保后续远端账本的重名检测基于「实时」占用情况。
  Future<String> _resolveCloudLedgerName(String rawName, Set<String> takenNames) async {
    // 无冲突直接用原名,并把该名登记进占用集合,避免后续重复 insert 撞名。
    if (!takenNames.contains(rawName)) {
      takenNames.add(rawName);
      return rawName;
    }
    // 上限兜底:极端情况下(用户手工造了几十个同名账本)不做无限循环,
    // 兜到后缀带时间戳,保证一定能落地而不是卡死拉取流程。
    for (var i = 1; i <= 50; i++) {
      final candidate = i == 1 ? '$rawName（云端）' : '$rawName（云端$i）';
      if (!takenNames.contains(candidate)) {
        takenNames.add(candidate);
        return candidate;
      }
    }
    final fallback = '$rawName（云端${DateTime.now().millisecondsSinceEpoch}）';
    takenNames.add(fallback);
    return fallback;
  }

  /// Surface 1 兜底:把「远端废」(登录态失效 / 配置损坏 / 404 / 阈值确认宕机)
  /// 当成远端空集,全量清本地 isShared=true 账本。
  ///
  /// 调用统一原语 repo.purgeAllSharedLedgers()(WHERE isShared=true 批量闸门,
  /// 不做逐本 syncId 匹配,空 syncId 行不构成风险);随后 emit [LedgersPurged]
  /// 让 UI 层重指当前账本并刷新列表。失败不上抛——GC 是兜底动作,不应打断
  /// 主流程,下次触发会幂等重试。
  Future<void> _gcAllLocalSharedLedgers() async {
    try {
      await repo.purgeAllSharedLedgers();
      _emit(const LedgersPurged());
      logger.info('SyncEngine', '云端下线 → 已全量清本地共享账本并广播 LedgersPurged');
    } catch (e, st) {
      logger.warning('SyncEngine', '_gcAllLocalSharedLedgers 失败(忽略): $e', st);
    }
  }

  /// 备份恢复后重新认领本地账本到当前服务器/账号(Design Y)。
  ///
  /// 设计意图:本地备份恢复会把旧账本(含旧 syncId)写回本地 DB。若期间换了
  /// 服务器/账号,这些账本的 syncId 在远端不存在 → [fullPush] 的 writeCreateLedger
  /// 会在新命名空间新建一本(当前用户为 owner);若仍是同一账号,server 已有该
  /// syncId → writeCreateLedger 返回 409 被吞,storage.upload + _pushAllEntities
  /// 重新认领成功。全程保留旧 syncId,语义简洁且跨账号隔离(server 端按用户命名
  /// 空间隔离,同 syncId 在不同账号互不干扰)。
  ///
  /// 流程:对每一本账本先 [fullPush](全量上传数据),成功后乐观把本地 myRole 标
  /// 为 'owner'(恢复认领后本地即 owner)。两步写在同一个 try 内——若 fullPush 成功
  /// 但 myRole 写库失败(极端 disk full),该账本不会被标 owner,避免 Editor 守卫
  /// 后续锁死 fullPush 造成静默数据分裂;该本失败由 finally 复位开关后,下一次
  /// GC1 会因它的 syncId 不在远端集合而补清(failed 账本确实无法在 server 建立)。
  ///
  /// 开关:[_suppressLedgerGc] 在方法入口同步置 true、finally 复位,压住恢复期间
  /// 所有 GC1 硬删(含 WS 重连抢跑触发的 syncLedgersFromServer),避免误清尚未认领
  /// 完的账本;[_reregistering] 防重入,保证整个认领流程只跑一次。
  ///
  /// 选区:只遍历 `cloudLedgerFilter` 命中的云端形态账本,三条理由——
  ///   1. 消除无效遍历:纯本地账本本就会被 [fullPush] 的 storage_mode 闸门跳过,
  ///      进循环只是空转;
  ///   2. 切断 myRole 倒挂路径:闸门是**静默 return**(不抛错),循环体因此不会进
  ///      catch,仍会无条件把 myRole 写成 'owner'。对 `myRole='editor'` 的历史/
  ///      恢复数据构成「推送根本没发生却写成功标记」的静默改写。排除纯本地账本
  ///      即切断该路径;
  ///   3. 认领语义收敛:认领的对象天然只有云端形态账本。
  Future<void> reregisterRestoredLedgers() async {
    // 防重入:WS 重连等并发触发时只跑一次
    if (_reregistering) return;
    // 未登录(本地模式 / session 失效)不认领,跳过
    if (await provider.auth.currentUser == null) return;
    _reregistering = true;
    _suppressLedgerGc = true;
    try {
      // 遍历恢复后 DB 中的云端形态账本,逐本重新认领到当前服务器/账号。
      // 归属判定统一走 ledger_kind.dart 的 SQL 工厂(与 isCloudLedgerOf 同源)。
      final ledgers =
          await (db.select(db.ledgers)..where(cloudLedgerFilter)).get();
      for (final l in ledgers) {
        try {
          await fullPush(ledgerId: l.id);
          // fullPush 成功后才乐观标记本地为 owner(两步同 try,避免半成功分裂)
          await (db.update(db.ledgers)..where((l2) => l2.id.equals(l.id)))
              .write(LedgersCompanion(myRole: d.Value('owner')));
        } catch (e, st) {
          // 单本失败不阻断其余账本;failed 账本 syncId 不在远端集合,
          // 后续 GC1 会补清(它确实无法在 server 上建立)。
          logger.warning('SyncEngine',
              'reregisterRestoredLedgers 失败 ledger=${l.id}: $e', st);
        }
      }
    } finally {
      // 无论成功失败都复位开关,恢复普通 GC1 行为
      _suppressLedgerGc = false;
      _reregistering = false;
    }
  }

  /// 推送 user-global 实体(category / exchange_rate_override)的未推 change。
  ///
  /// **全局单飞**:并发调用复用第一个的 future。多账本场景下 Phase 2 并行的
  /// `_push(ledgerN)` / `fullPush(ledgerN)` 都先 await 这个方法,保证 user-global
  /// 实体每个 session 只推一次。
  ///
  /// 注意:**不要在 `_push` / `_pushAllEntities` 内部重复推 user-global**,
  /// 否则单飞失效。这俩内部应该只处理 ledger-scope change(transaction /
  /// ledger / ledger_snapshot)。
  Future<int> pushUserGlobalEntities() async {
    final inFlight = _userGlobalPushInFlight;
    if (inFlight != null) {
      logger.info('SyncEngine', 'pushUserGlobalEntities 已在执行,复用 in-flight');
      await inFlight.future;
      return 0; // 复用不计数,只是等
    }
    final completer = Completer<void>();
    completer.future.ignore();
    _userGlobalPushInFlight = completer;
    try {
      final n = await _doPushUserGlobalEntities();
      completer.complete();
      return n;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_userGlobalPushInFlight == completer) {
        _userGlobalPushInFlight = null;
      }
    }
  }

  Future<int> _doPushUserGlobalEntities() async {
    // Legacy backfill:migration 给老 user-global 实体填了 syncId 但没登记
    // local_changes,这里一次性补登记。每 SyncEngine 实例只跑一次。
    if (!_userGlobalLegacyBackfilled) {
      await _backfillLegacyUserGlobalChanges();
      _userGlobalLegacyBackfilled = true;
    }

    final globalChanges = await changeTracker.getUnpushedChangesForLedger(0);
    if (globalChanges.isEmpty) {
      logger.debug(
          'SyncEngine', 'pushUserGlobalEntities: 无未推 user-global change');
      return 0;
    }

    // change ↔ 序列化字典配对(后面按 entity_type 拆批时要凭 change.id 标记已推)。
    final mainChanges = <LocalChange>[];
    final mainSyncChanges = <Map<String, dynamic>>[];
    final overrideChanges = <LocalChange>[];
    final overrideSyncChanges = <Map<String, dynamic>>[];
    for (final change in globalChanges) {
      Map<String, dynamic> payload;
      if (change.action == 'delete') {
        payload = <String, dynamic>{};
      } else {
        // user-global 实体序列化不需要 ledger 上下文,ledgerId 传 0 占位
        // (_serializeEntityForPush 内部用它查 parent ledger.syncId,user-global
        // 实体不会用到 parentLedgerSyncId)。
        payload = await _serializeEntityForPush(
          entityType: change.entityType,
          entityId: change.entityId,
          ledgerId: 0,
        );
      }
      final syncChange = {
        'ledger_id': null,
        'scope': 'user',
        'entity_type': change.entityType,
        'entity_sync_id': change.entitySyncId,
        'action': change.action == 'delete' ? 'delete' : 'upsert',
        'payload': payload,
        'updated_at': change.createdAt.toUtc().toIso8601String(),
      };
      if (change.entityType == 'exchange_rate_override') {
        overrideChanges.add(change);
        overrideSyncChanges.add(syncChange);
      } else {
        mainChanges.add(change);
        mainSyncChanges.add(syncChange);
      }
    }

    var pushedCount = 0;
    // 主批(category):照常规推送 + 标记已推。
    if (mainSyncChanges.isNotEmpty) {
      await provider.pushChanges(changes: mainSyncChanges);
      await changeTracker.markPushed(mainChanges.map((c) => c.id).toList());
      pushedCount += mainChanges.length;
    }

    // exchange_rate_override 独立批:旧服务器白名单会拒绝该 entity_type,
    // 混在主批会整批失败、阻塞 category 同步。
    // 失败只 warning、不标记已推 → 留在 local_changes 下次重试。
    if (overrideSyncChanges.isNotEmpty) {
      try {
        await provider.pushChanges(changes: overrideSyncChanges);
        await changeTracker
            .markPushed(overrideChanges.map((c) => c.id).toList());
        pushedCount += overrideChanges.length;
      } catch (e, st) {
        logger.warning(
            'SyncEngine', 'override 批推送失败(server 可能未升级),跳过本轮不阻塞: $e', st);
      }
    }

    logger.info('SyncEngine',
        'pushUserGlobalEntities: 推送 ${mainChanges.length} 条主批 + ${overrideChanges.length} 条 override 批 user-global change');
    // 只计成功批次：override 批失败时不计入，避免 SyncAccountResult.pushed 虚高。
    return pushedCount;
  }

  /// 扫 categories,给 local_changes 里没登记过的 legacy 实体
  /// 补一条 upsert change。详见 [_userGlobalLegacyBackfilled] doc。
  ///
  /// 兼顾兜底两件事:
  /// 1. 实体 syncId 为 NULL(migration 没覆盖到的脏数据)→ 生成 v4 UUID 写回
  /// 2. 已有 syncId 但 local_changes 表里完全没记录该实体的 change → 补 upsert
  ///
  /// 同时覆盖 categories 与 exchange_rate_override 两类 user-global 实体。
  Future<void> _backfillLegacyUserGlobalChanges() async {
    // 预拉:local_changes 表里所有 user-global 实体 syncId,做 in-memory dedup,
    // 避免逐 entity SELECT。注意 local_changes 没有唯一约束,
    // recordUserGlobalChange 是纯 insert —— 不能依赖数据库拦住重复,
    // 这个 in-memory Set 是唯一的防重手段。
    final existingChanges = await (db.select(db.localChanges)
          ..where((c) => c.entityType.isIn(['category', 'exchange_rate_override'])))
        .get();
    final knownSyncIds = existingChanges.map((c) => c.entitySyncId).toSet();

    var backfilled = 0;

    // categories
    final categories = await db.select(db.categories).get();
    for (final c in categories) {
      var syncId = c.syncId;
      if (syncId == null) {
        syncId = _uuid.v4();
        await (db.update(db.categories)..where((row) => row.id.equals(c.id)))
            .write(CategoriesCompanion(syncId: d.Value(syncId)));
      }
      if (!knownSyncIds.contains(syncId)) {
        await changeTracker.recordUserGlobalChange(
          entityType: 'category',
          entityId: c.id,
          entitySyncId: syncId,
          action: 'upsert',
        );
        backfilled++;
      }
    }

    // exchange_rate_override:与 category 同属 user-global 实体,
    // 老版本若漏登记同样需要补(syncId null 时生成 UUID 写回)。
    final overrides = await db.select(db.exchangeRateOverrides).get();
    for (final o in overrides) {
      var syncId = o.syncId;
      if (syncId == null) {
        syncId = _uuid.v4();
        await (db.update(db.exchangeRateOverrides)
              ..where((row) => row.id.equals(o.id)))
            .write(ExchangeRateOverridesCompanion(syncId: d.Value(syncId)));
      }
      if (!knownSyncIds.contains(syncId)) {
        await changeTracker.recordUserGlobalChange(
          entityType: 'exchange_rate_override',
          entityId: o.id,
          entitySyncId: syncId,
          action: 'upsert',
        );
        backfilled++;
      }
    }

    // tags 表已删除,跳过标签 backfill。

    if (backfilled > 0) {
      logger.info('SyncEngine',
          'legacy backfill: 补登记 $backfilled 条 user-global ChangeTracker entry');
    } else {
      logger.debug('SyncEngine', 'legacy backfill: 无需补登记');
    }
  }

  /// 推送本地未同步的变更到服务端。
  ///
  /// **in-flight 单飞**:同 ledger 的并发调用复用第一个的 future,避免双触发
  /// 在 sync_changes 表里造成重复 row。不同 ledger 并发不互相阻塞。
  ///
  /// 注意:**只推 ledger-scope change**(transaction / ledger / ledger_snapshot)。
  /// user-global change(category)由 [pushUserGlobalEntities] 统一推
  /// (在 [_doPush] 开头调用),避免多账本场景下并行 push 重复推送 user-global。
  Future<int> push(String ledgerId) async {
    final inFlight = _pushInFlight[ledgerId];
    if (inFlight != null) {
      logger.info('SyncEngine', 'push(ledger=$ledgerId) 已在执行,复用 in-flight');
      return inFlight.future;
    }
    final completer = Completer<int>();
    completer.future.ignore(); // 防 unhandled async error
    _pushInFlight[ledgerId] = completer;
    try {
      final result = await _doPush(ledgerId);
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_pushInFlight[ledgerId] == completer) {
        _pushInFlight.remove(ledgerId);
      }
    }
  }

  Future<int> _doPush(String ledgerId) async {
    final ledgerIdInt = int.tryParse(ledgerId) ?? -1;

    // 1) 先推 user-global change(category)。
    //    全局单飞,Phase 2 多 ledger 并行场景下只跑一次,跨 ledger 不各推一份。
    final userGlobalPushed = await pushUserGlobalEntities();

    // 2) ledgerId="0" / "" 语义是"只推 user-global",上面一步已经做完。
    if (ledgerIdInt == 0) return userGlobalPushed;

    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerIdInt)))
        .getSingleOrNull();

    // 3) 再推这个 ledger 的 ledger-scope change(transaction / budget / ledger /
    //    ledger_snapshot)。ledger 删除路径:即使 ledger 行已没,ledger_snapshot:
    //    delete change 还在 local_changes 里,这里照常推。
    //
    // 关键:ledger 已被本地删除时不能直接 return 0。因为 deleteLedger 会先
    // 登记 ledger_snapshot:delete change 再 hard-delete ledger 行,这条 delete
    // change 的 ledger_id 字段就是这个本地 id。如果这里因 ledger==null 短路,
    // 这条 delete change 永远卡在本地不推,云端账本和它的快照永远删不掉,
    // remote ledgers list 还会继续显示。
    //
    // 策略:先按这个 ledgerIdInt 查未推送变更,有变更就继续推,没
    // 变更才安全 return。
    final ledgerChanges =
        await changeTracker.getUnpushedChangesForLedger(ledgerIdInt);
    // 仅这个 ledger 的 ledger-scope change。user-global 已在上面统一推走。
    final changes = ledgerChanges;
    if (changes.isEmpty) {
      if (ledger == null) {
        logger.warning('SyncEngine', 'push: 本地账本 $ledgerId 已删除且无待推送变更,跳过');
      } else {
        logger.debug('SyncEngine',
            'push: 无 ledger-scope 待推变更(user-global 已推 $userGlobalPushed 条)');
      }
      return userGlobalPushed;
    }
    // 当本地 ledger 行已删,从同批 changes 里捞 ledger_snapshot:delete 的
    // entity_sync_id(= 被删账本的 syncId / UUID),用它给所有相关 change 的
    // push payload 设置 ledger_id 字段。否则 fallback 到 ledgerId 字符串
    // (本地 int id),server 端会把它当成一个不存在的账本 → 整批 delete 静
    // 默失败,canonical state 不变,远端数据看着像没删。
    String? deletedLedgerSyncId;
    if (ledger == null) {
      for (final c in changes) {
        if (c.entityType == 'ledger_snapshot' && c.action == 'delete') {
          deletedLedgerSyncId = c.entitySyncId;
          break;
        }
      }
      logger.info(
          'SyncEngine',
          'push: 本地账本 $ledgerId 已删除,但还有 ${changes.length} 条未推送变更(应包含 ledger_snapshot:delete),'
              '从 snapshot change 拿到 ledgerSyncId=$deletedLedgerSyncId,继续 push');
    }

    // 构建服务端 push 格式：从 DB 读取最新数据序列化
    final syncChanges = <Map<String, dynamic>>[];

    for (final change in changes) {
      final isUserGlobal =
          ChangeTracker.userGlobalEntityTypes.contains(change.entityType);

      Map<String, dynamic> payload;

      if (change.action == 'delete') {
        payload = <String, dynamic>{};
      } else {
        // 从数据库读取最新实体并序列化。注意:正常流程到这里 ledger 一定非
        // null —— ledger==null 的唯一来源是 deleteLedger,而它只产生 delete
        // changes(已被 if 分支拦走)。这里用 ledgerIdInt 兜底防御,避免 NPE。
        payload = await _serializeEntityForPush(
          entityType: change.entityType,
          entityId: change.entityId,
          ledgerId: ledger?.id ?? ledgerIdInt,
        );
      }

      // user-global 协议:
      //   - scope='user' (category):ledger_id 发 null,server 按
      //     entity_type 强制按 user-scope 路由,不依附任何 ledger。
      //   - scope='ledger' (transaction/ledger/ledger_snapshot):
      //     ledger_id 用 ledger.syncId(跨设备唯一 external_id)。删账本路径
      //     从 ledger_snapshot:delete change 拉回 syncId,保证 server 认得。
      final String? pushLedgerId;
      final String pushScope;
      if (isUserGlobal) {
        pushLedgerId = null;
        pushScope = 'user';
      } else {
        pushLedgerId = ledger?.syncId ?? deletedLedgerSyncId ?? ledgerId;
        pushScope = 'ledger';
      }
      syncChanges.add({
        'ledger_id': pushLedgerId,
        'scope': pushScope,
        'entity_type': change.entityType,
        'entity_sync_id': change.entitySyncId,
        'action': change.action == 'delete' ? 'delete' : 'upsert',
        'payload': payload,
        'updated_at': change.createdAt.toUtc().toIso8601String(),
      });
    }

    // moveToLocal 中止检查(增量 push 路径,补强 1 最关键的一条):
    // 若该账本正处于 moveToLocal 窗口,静默跳过本轮 push——不抛异常、不 markPushed。
    // 为什么静默跳过而非抛异常:增量 push 没有 completer 可 complete,抛异常只会
    // 让上层同步链报错;跳过后 local_changes 保持未推送,moveToLocal 结束(finally
    // 撤销信号)后的正常同步会自然把它们补上。这一条堵住的真实缺口是:删远端 →
    // detach 之间的窗口里,auto sync 恰好触发增量 push,把积压的 local_changes 重新
    // 写成 S1 孤儿。
    if (_moveToLocalAbortRequests.contains(ledgerIdInt)) {
      logger.info('SyncEngine',
          'push: 账本 $ledgerIdInt 处于 moveToLocal 中止窗口,静默跳过本轮增量 push');
      return userGlobalPushed;
    }

    // 使用 pushChanges 直接推送个体变更
    await provider.pushChanges(changes: syncChanges);

    // 标记已推送
    await changeTracker.markPushed(changes.map((c) => c.id).toList());
    logger.info('SyncEngine',
        'push: 推送 ${changes.length} 条 ledger-scope 变更 + 本会话 user-global $userGlobalPushed 条');
    return changes.length + userGlobalPushed;
  }

  /// 拉取远程变更并应用到本地。
  ///
  /// 设计要点:
  /// 1. **cursor 安全**:cloud-sync 包 `pullChanges(persistCursor: false)`,
  ///    app 侧用 [appCursor] 管,**整页 apply 成功后**才推进
  /// 2. **失败隔离**:整页 apply 抛错 → rollback + 错误入 [pullErrors] 表 +
  ///    cursor 不推进 + 后续页不拉,UI 显示"同步暂停"
  /// 3. **busy retry**:SQLite busy/locked 单条 retry 2 次
  /// 4. **小颗粒度**:单页 limit 50,让 retry 范围 + UI 反馈更可控
  ///
  /// 传 [sinceOverride]=0 = 从头重放(等价 replayAllChanges)。
  ///
  /// **单飞锁**:多个 caller(bootstrap / WS push / ledger switch /
  /// connectivity restored / 用户下拉刷新)同时触发 pull 时,SQLite 排队 +
  /// main isolate 拥塞会让 apply 时间翻倍。这里用 [_pullInFlight] 互斥:
  /// - 分支 A(普通 pull,sinceOverride=null)碰到 in-flight 时**复用结果**
  ///   (节省一轮):因为普通 pull 的语义是「拉全量增量」,与正在跑的 in-flight
  ///   目标一致,结果可直接复用;
  /// - 分支 B(replay / since 不同,sinceOverride 非 null)语义独立(重放指定
  ///   cursor 而非当前),**不能**复用 in-flight,只能等其完成后再自己跑。
  Future<int> pull(String ledgerId, {int? sinceOverride}) async {
    // 1. in-flight 单飞
    final inFlight = _pullInFlight;
    if (inFlight != null) {
      if (sinceOverride == null && _pullInFlightSince == null) {
        // 分支 A:普通 pull 复用 in-flight 结果(语义一致,省一轮 apply)。
        logger.info('SyncEngine', 'pull 已在执行中,复用 in-flight 结果');
        return inFlight.future;
      }
      // 分支 B:replay / 不同 since → 等当前 pull 完成再独立跑(语义不可复用)。
      logger.info('SyncEngine',
          'pull(sinceOverride=$sinceOverride) 等待 in-flight pull 完成');
      try {
        await inFlight.future;
      } catch (_) {/* 忽略 in-flight 的错,自己单独跑 */}
    }

    final completer = Completer<int>();
    // 默认订阅 future 让出错时不抛 unhandled async error — 后续 caller
    // 复用 in-flight 时会自己 await,如果没人 await(单 caller 场景),
    // completer.completeError 触发的 Future 错误会被 zone 当成 unhandled。
    // 这里 ignore() 等于说"我已经知道这个错,通过 rethrow 抛给当前 caller 了"。
    completer.future.ignore();
    _pullInFlight = completer;
    _pullInFlightSince = sinceOverride;
    try {
      final n = await _doPull(ledgerId, sinceOverride);
      completer.complete(n);
      return n;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_pullInFlight == completer) {
        _pullInFlight = null;
        _pullInFlightSince = null;
      }
    }
  }

  /// pull 单飞锁。多个 caller 同时调 pull 时,只第一个真跑,后续复用 / 等待。
  Completer<int>? _pullInFlight;
  int? _pullInFlightSince;

  Future<int> _doPull(String ledgerId, int? sinceOverride) async {
    int? nextSince = sinceOverride ?? await appCursor.read();
    if (nextSince == 0 && sinceOverride == null) {
      await appCursor.migrateFromProviderCursor();
      nextSince = await appCursor.read();
    }

    // **Lazy prime**:先 HTTP 一次试探有没有数据。99% 场景(无变更)直接
    // return,跳过 LookupCache 全表 SELECT(transactions 10k+ 行的 prime
    // 每次都要 200-500ms 主线程时间)。多账本场景这里是大头 — 启动时 5 个
    // ledger 各跑一次 sync,空跑也要 prime 5 次,白白卡 1-2s。
    final probe = await provider.pullChanges(
      since: nextSince,
      limit: 500,
      persistCursor: false,
    );
    if (probe.changes.isEmpty) {
      logger.info(
          'SyncEngine', 'pull: since=$nextSince 无新变更,跳过 LookupCache prime');
      return 0;
    }

    // 有数据 → prime LookupCache,然后跑 loop(把已拉的第一页喂进去)
    final cache = LookupCache();
    await cache.prime(db);
    activePullCache = cache;

    try {
      return await _runPullLoop(ledgerId, nextSince, firstPage: probe);
    } finally {
      activePullCache = null;
    }
  }

  Future<int> _runPullLoop(
    String ledgerId,
    int? nextSince, {
    SpitoutCloudPullResult? firstPage,
  }) async {
    int totalApplied = 0;
    bool hasMore = true;
    int pageIndex = 0;
    final loopStart = DateTime.now();
    SpitoutCloudPullResult? reuseResult = firstPage;
    while (hasMore) {
      pageIndex++;
      final pageStart = DateTime.now();
      final SpitoutCloudPullResult result;
      if (reuseResult != null) {
        // 第一轮:复用 _doPull 的探针结果,不发一次 HTTP
        result = reuseResult;
        reuseResult = null;
        logger.info('SyncEngine',
            'pull #$pageIndex: since=$nextSince got ${result.changes.length} hasMore=${result.hasMore} (reused probe)');
      } else {
        result = await provider.pullChanges(
          since: nextSince,
          limit: 500,
          persistCursor: false, // cursor 由 appCursor 接管
        );
        final httpMs = DateTime.now().difference(pageStart).inMilliseconds;
        logger.info('SyncEngine',
            'pull #$pageIndex: since=$nextSince got ${result.changes.length} hasMore=${result.hasMore} (HTTP ${httpMs}ms)');
      }
      if (result.changes.isEmpty) break;

      final applyStart = DateTime.now();
      final outcome = await _applyPullPage(result.changes);
      final applyMs = DateTime.now().difference(applyStart).inMilliseconds;
      logger.info('SyncEngine',
          'pull #$pageIndex: applied ${outcome.applied}/${result.changes.length} (apply ${applyMs}ms, page total ${DateTime.now().difference(pageStart).inMilliseconds}ms)');
      totalApplied += outcome.applied;
      if (outcome.blocked) {
        logger.warning(
            'SyncEngine', 'pull 被错误阻塞 cursor 停在 $nextSince — UI 应显示同步异常');
        break;
      }

      // 整页成功:推进 cursor
      await appCursor.commit(result.serverCursor);
      nextSince = result.serverCursor;

      // 同 change_id 之前如果有未 resolved 错误(server 修了脏数据 + 推新
      // change → apply 通过)→ markResolved 让 UI 不显示
      for (final ch in result.changes) {
        await pullErrors.markResolved(ch.changeId);
      }

      hasMore = result.hasMore;
    }

    final totalMs = DateTime.now().difference(loopStart).inMilliseconds;
    if (totalApplied > 0 || pageIndex > 0) {
      logger.info('SyncEngine',
          'pull: 累计 apply $totalApplied 条 / $pageIndex 页 / 总耗时 ${totalMs}ms');
    }
    return totalApplied;
  }

  /// 单页 apply。整页事务 try/catch:
  /// - 不可恢复异常 → rollback + 错误入 [pullErrors] + return blocked
  /// - SQLite busy/locked → 单条 retry 2 次
  Future<_PullPageOutcome> _applyPullPage(
      List<SpitoutCloudSyncChange> changes) async {
    int applied = 0;
    int skipped = 0;
    SpitoutCloudSyncChange? failingChange;

    try {
      await db.transaction(() async {
        for (final ch in changes) {
          failingChange = ch;
          final ok = await _applyOneWithBusyRetry(ch);
          if (ok) {
            applied++;
          } else {
            skipped++;
          }
        }
      });
      if (skipped > 0) {
        logger.info('SyncEngine', 'pull: 应用 $applied / 跳过 $skipped (本页)');
      }
      return _PullPageOutcome(applied: applied, blocked: false);
    } catch (e, st) {
      // 整页 rollback 已自动完成(Drift transaction 抛错回滚)
      logger.error(
          'SyncEngine',
          '本页 apply 抛错 change_id=${failingChange?.changeId} '
              'type=${failingChange?.entityType}',
          e,
          st);
      final ch = failingChange;
      if (ch != null) {
        await pullErrors.record(change: ch, error: e, stackTrace: st);
      }
      return const _PullPageOutcome(applied: 0, blocked: true);
    }
  }

  /// 单条 apply 带 SQLite busy/locked retry。其它异常直接抛,让外层整页 rollback。
  ///
  /// 用 `e.toString()` 探测 SqliteException 类型,避免引入 sqlite3 包依赖
  /// (Drift 内部用,但这里直接 import 会触发 depend_on_referenced_packages)。
  Future<bool> _applyOneWithBusyRetry(SpitoutCloudSyncChange ch) async {
    var attempts = 0;
    while (true) {
      try {
        return await applyRemoteChange(ch);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final transient =
            (msg.contains('sqlite') || msg.contains('database')) &&
                (msg.contains('busy') || msg.contains('locked'));
        if (transient && attempts < 2) {
          attempts++;
          await Future.delayed(Duration(milliseconds: 50 * (1 << attempts)));
          continue;
        }
        rethrow;
      }
    }
  }

  /// 从 change_id=0 起把整段 sync_changes 重拉一遍并幂等应用。
  /// 用在"账本刚从 server 拉到本地、本地 tx 为空但 cursor 已经被推到顶"
  /// 的恢复场景。跟 S3/WebDAV 的 `_fullPull` 不同，这里走的还是 Spitout
  /// Cloud 的增量日志，只是把起点拨回 0，符合 Spitout Cloud 的同步模型。
  Future<int> replayAllChanges() async {
    logger.info('SyncEngine', 'replayAllChanges: 从 0 开始重拉 sync_changes');
    return pull('', sinceOverride: 0);
  }

  // ==================== 缺失数据自愈 ====================

  /// 自愈:增量 pull 返回 0 时,检测"云端有、本地缺"并恢复。
  ///
  /// 背景:增量 pull 以 appCursor(since)为起点,一旦本地数据丢失而 cursor
  /// 未回退(本地 cursor 领先于云端或本地库被清),change_id<=since 的变更
  /// 永远拉不回(pulled 恒为 0)。此时靠 checkLedgerHealth 比对云端计数,
  /// 命中闸门则先 [replayAllChanges] 整段幂等重放;重放后差异仍在再用
  /// [runFullPull] 快照兜底(stats 的 remote 计数本就来自最新快照,
  /// 所以它报出的差异快照里必然有)。
  ///
  /// 四重防护 —— 与旧"翻倍 bug"(pulled==0 && 本地空就无条件盲插快照、
  /// 导入无 syncId 去重)有本质区别:
  /// 1. **闸门**:仅 unpushed==0 && remoteOnly>0 才触发。unpushed>0 时
  ///    未推送的 delete 会造成"云端多"的假象(误触发会把用户刚删的数据
  ///    导回来),必须等 push 完成后才能判定。本方法自身不 push。
  /// 2. **节流**:验证本身(无论结果)按 _selfHealThrottle 节流,健康设备
  ///    至多每 5 分钟打一次 /stats;stats 抛错也写时间戳,构成失败退避。
  /// 3. **幂等**:replay apply 按 entity_sync_id upsert;快照导入有 syncId
  ///    去重防线。重复执行不会翻倍。
  /// 4. **熔断**:连续 _selfHealMaxFailures 次二次确认失败(差异消不掉,
  ///    典型原因:server stats 口径与本地 apply 存在系统性偏差)→ 熔断
  ///    _selfHealBrokenDuration,期内不自动重试,UI 引导手动恢复。
  ///
  /// 返回 (healed, gapRemaining):healed 为补回的变更条数(replay applied
  /// + 快照 inserted);gapRemaining 表示执行自愈后差异仍未消除。
  /// 未触发(节流/熔断/闸门不过/验证失败)时两者皆为 0/false。
  Future<({int healed, bool gapRemaining})> _selfHealIfMissing(
      String ledgerId) async {
    final ledgerIdInt = int.tryParse(ledgerId) ?? -1;
    if (ledgerIdInt <= 0) return (healed: 0, gapRemaining: false);

    // 熔断检查:期内直接短路,避免每次同步都重走"重放+快照+失败"全流程。
    final brokenUntil = _selfHealBrokenUntil[ledgerId];
    if (brokenUntil != null && DateTime.now().isBefore(brokenUntil)) {
      return (healed: 0, gapRemaining: false);
    }

    // 节流:验证本身也受节流保护 —— pulled==0 是常态,若只在"确认缺数据"
    // 后才记时间戳,健康设备每次高频入口空拉都打一次 /stats。
    final last = _selfHealLastRun[ledgerId];
    if (last != null &&
        DateTime.now().difference(last) < _selfHealThrottle) {
      return (healed: 0, gapRemaining: false);
    }
    // 时间戳前移到 checkLedgerHealth 之前:无论验证结果健康/缺数据/抛错,
    // 本周期内都不重复验证;抛错时顺带构成天然失败退避。
    _selfHealLastRun[ledgerId] = DateTime.now();

    try {
      // 自愈闸门必须走账本级检查:unpushed 按 per-ledger 口径统计,
      // 才能排除"该账本有未推送变更"导致的假阳性"云端多"。
      final health = await checkLedgerHealth(ledgerId: ledgerIdInt);
      // 闸门:本地有未推送变更时"云端多"可能是假象(未推送的 delete 等),
      // 静默跳过,等下一次 sync() push 完成后由后续触发点自愈。
      if (health.unpushedChanges != 0) return (healed: 0, gapRemaining: false);
      if (health.ledgerTx.remoteOnly <= 0) {
        return (healed: 0, gapRemaining: false); // 本地并不缺云端数据
      }

      logger.warning('SyncEngine',
          '检测到本地缺失云端数据(remoteOnly=${health.ledgerTx.remoteOnly}),触发自愈重放');

      // 第一段:整段重放增量日志(全用户全账本,顺带补齐其他账本同类空洞)。
      // apply 按 entity_sync_id upsert,幂等;重放后 cursor 推进到
      // serverCursor,恢复正常增量。
      var healed = await replayAllChanges();

      // 复查:差异消除即收敛,清失败计数。
      var recheck = await checkLedgerHealth(ledgerId: ledgerIdInt);
      if (recheck.ledgerTx.remoteOnly <= 0) {
        _selfHealFailures.remove(ledgerId);
        return (healed: healed, gapRemaining: false);
      }

      // 第二段:快照兜底。重放拉不回的场景:缺失 change 由本设备 push,
      // server 按 device_id 排除本设备变更,重放多少遍都拿不到,只有
      // 快照能救。导入按 syncId 幂等去重。
      logger.warning('SyncEngine',
          '重放后差异仍在(remoteOnly=${recheck.ledgerTx.remoteOnly}),快照兜底');
      final r = await runFullPull(ledgerId: ledgerIdInt);
      healed += r.inserted;

      // 二次确认:仍消不掉 → 累计失败,达阈值熔断,不自动重试。
      recheck = await checkLedgerHealth(ledgerId: ledgerIdInt);
      if (recheck.ledgerTx.remoteOnly <= 0) {
        _selfHealFailures.remove(ledgerId);
        return (healed: healed, gapRemaining: false);
      }

      final failures = (_selfHealFailures[ledgerId] ?? 0) + 1;
      _selfHealFailures[ledgerId] = failures;
      if (failures >= _selfHealMaxFailures) {
        _selfHealBrokenUntil[ledgerId] =
            DateTime.now().add(_selfHealBrokenDuration);
        logger.warning('SyncEngine',
            '自愈连续 $failures 次未能消除差异,熔断 ${_selfHealBrokenDuration.inMinutes} 分钟,请手动从云端恢复');
      }
      return (healed: healed, gapRemaining: true);
    } catch (e, st) {
      // 时间戳已写入,本周期内不重试(天然失败退避)。
      logger.warning('SyncEngine', '自愈检查失败: $e', st);
      return (healed: 0, gapRemaining: false);
    }
  }

  /// 自愈是否处于熔断期(供云同步页文案判断)。
  ///
  /// 跟 [SyncEngineHealthChecks.checkLedgerHealth] 同模式:SyncEngine 特有
  /// 概念,公开方法但不进 SyncService 接口,不污染快照型 / LocalOnly 后端
  /// 的抽象。同步页持有 SyncEngine 类型可直接调用。
  bool selfHealBroken(String ledgerId) {
    final until = _selfHealBrokenUntil[ledgerId];
    return until != null && DateTime.now().isBefore(until);
  }

  /// 任一云端账本是否处于自愈熔断期(账户级红字提示用)。
  ///
  /// 与 [selfHealBroken] 的差异:后者是 per-ledger 口径,调用方必须先拿到
  /// 一个具体 ledgerId;而云同步页的状态行是**账户级**语义 —— 只要有任何
  /// 一本云账本自动恢复失败就该报红,不该被"当前选中哪本"左右(选中 B 时
  /// A 的熔断同样要提示,选中本地账本时更不能整行哑掉)。
  ///
  /// 直接遍历熔断 Map 即可,零 I/O:该 Map 只会被云端账本写入 ——
  /// 自愈闸门在 checkLedgerHealth 就已挡掉无 syncId 的本地账本。
  ///
  /// 不加 hasDiff 之类的闸门:熔断本身已是"连续多次二次确认失败"的强证据,
  /// 再叠加账户级聚合口径的差异判断反而会把真实熔断掩盖掉。
  bool anySelfHealBroken() {
    final now = DateTime.now();
    return _selfHealBrokenUntil.values.any(now.isBefore);
  }

  /// 测试专用:直接把某账本标记为熔断,免去"构造连续自愈失败"的重型编排。
  void debugMarkSelfHealBroken(String ledgerId,
      {Duration duration = _selfHealBrokenDuration}) {
    _selfHealBrokenUntil[ledgerId] = DateTime.now().add(duration);
  }

  /// 测试专用:清除自愈节流时间戳(保留失败计数与熔断状态),
  /// 让下一次自愈检查立即执行而不受节流窗口阻挡。
  /// 生产代码不应调用(故以 debug 前缀标记,不加 meta 依赖注解)。
  void debugClearSelfHealThrottle() {
    _selfHealLastRun.clear();
  }

  /// 测试专用:完全重置自愈状态(节流 + 失败计数 + 熔断)。
  void debugResetSelfHealState() {
    _selfHealLastRun.clear();
    _selfHealFailures.clear();
    _selfHealBrokenUntil.clear();
  }

  /// 新设备全量拉取。
  ///
  /// **in-flight 单飞**:防御性,挡用户连点"下载"按钮时两次并发拉取。
  Future<({int inserted, int deletedDup})> runFullPull(
      {required int ledgerId}) async {
    final inFlight = _fullPullInFlight[ledgerId];
    if (inFlight != null) {
      logger.info(
          'SyncEngine', 'runFullPull(ledger=$ledgerId) 已在执行,复用 in-flight');
      return inFlight.future;
    }
    final completer = Completer<({int inserted, int deletedDup})>();
    completer.future.ignore();
    _fullPullInFlight[ledgerId] = completer;
    try {
      final result = await _doRunFullPull(ledgerId: ledgerId);
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_fullPullInFlight[ledgerId] == completer) {
        _fullPullInFlight.remove(ledgerId);
      }
    }
  }

  Future<({int inserted, int deletedDup})> _doRunFullPull(
      {required int ledgerId}) async {
    logger.info('SyncEngine', '开始全量拉取 ledger=$ledgerId');

    // path 对齐 fullPush 上传时用的 ledger.syncId。
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final path = ledgerRow?.syncId ?? ledgerId.toString();
    final data = await provider.storage.download(path: path);
    if (data == null) {
      logger.warning('SyncEngine', '全量拉取: 服务端无数据');
      return (inserted: 0, deletedDup: 0);
    }

    // 复用 importTransactionsJson;recordChanges:false 阻止反向回流:
    // 从云端拉下来的数据**不应该**再以 local_changes 形式推回去,否则 10k
    // 条 fullPull 会触发 SyncCoordinator 反向 sync,白白多一轮 10k push。
    final result = await importTransactionsJson(
      repo,
      ledgerId,
      data,
      recordChanges: false,
    );
    logger.info('SyncEngine', '全量拉取完成: inserted=${result.inserted}');

    return (inserted: result.inserted, deletedDup: 0);
  }
}

/// pull 单页处理结果。详见 [SyncEngine._applyPullPage]。
class _PullPageOutcome {
  const _PullPageOutcome({required this.applied, required this.blocked});

  /// 本页成功 apply 的条数。整页 rollback 时为 0。
  final int applied;

  /// 是否被错误阻塞(整页 rollback,cursor 不推进)。
  final bool blocked;
}
