// FakeSpitoutCloudProvider — SyncEngine e2e 测试的 in-memory 替身。
//
// 本文件随 Adapter 包分发,作为该包**正式 testing 入口**的一部分
// (`lib/testing.dart` 统一导出,仿 `package:http/testing.dart` 模式)。
// 任何消费方(主仓或外部)通过
// `package:flutter_cloud_sync_spitout_cloud/testing.dart` 引用本 fake,
// 保证拿到本包即可独立跑测,无需依赖宿主工程的 test/ 目录。
//
// 设计:
//   - extends SpitoutCloudProvider 真类(默认构造无副作用,_auth/_storage
//     在 initialize() 调用后才被设)
//   - 覆盖 baseUrl / apiPrefix / auth / storage getter 返 fake 实例
//   - 覆盖 SyncEngine 实际用到的 ~20 个方法,内存模拟 server 状态
//   - 未实现的方法抛 UnimplementedError,测试碰到说明该补
//
// 用法:见新包内 `test/fake_provider_migration_test.dart`(c8 自包含迁移用例)
// 及主仓 `test/cloud/sync/sync_engine_e2e_test.dart`。
//
// Day 1 范围:pull / push / readLedgers / storage.list + basic auth getter,
// 足够覆盖核心 pull/apply 测试场景。其它方法(附件 / WS / profile / shared
// resources)留待 Day 2 按需补。

import 'dart:async';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show CloudAuthService, CloudFile, CloudStorageService, CloudUser;
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';

// =====================================================================
// FakeSpitoutCloudAuthService — extends 真类,覆盖 currentUserId/currentDeviceId
// =====================================================================

class FakeSpitoutCloudAuthService extends SpitoutCloudAuthService {
  FakeSpitoutCloudAuthService({
    String? userId = 'test-user-id',
    String? deviceId = 'test-device-id',
  })  : _userId = userId,
        _deviceId = deviceId,
        super(baseUrl: 'https://fake.test', apiPrefix: '/api/v1');

  String? _userId;
  String? _deviceId;

  // 覆盖 SpitoutCloudAuthService 自身的 getter(不在 CloudAuthService 接口
  // 内但 AppCursorStore 强 cast 后用到)
  @override
  String? get currentUserId => _userId;

  @override
  String? get currentDeviceId => _deviceId;

  // CloudAuthService 抽象接口实现 — fake 不真做认证
  @override
  Future<CloudUser?> get currentUser async =>
      _userId == null ? null : CloudUser(id: _userId!);

  /// 测试入口:模拟用户登录 / 登出
  void setLoggedIn({String? userId = 'test-user-id', String? deviceId = 'test-device-id'}) {
    _userId = userId;
    _deviceId = deviceId;
  }
}

// =====================================================================
// FakeSpitoutCloudStorageService — 内存模拟 storage(用于 fullPush JSON 等)
// =====================================================================

class FakeSpitoutCloudStorageService implements CloudStorageService {
  final Map<String, String> _files = {};
  final Map<String, Map<String, String>?> _metadata = {};

  /// 测试 helper:模拟 server 端账本列表(`storage.list(path: '')` 返回)
  final List<CloudFile> ledgerSnapshots = [];

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    _files[path] = data;
    _metadata[path] = metadata;
  }

  @override
  Future<String?> download({required String path}) async {
    return _files[path];
  }

  @override
  Future<void> delete({required String path}) async {
    _files.remove(path);
    _metadata.remove(path);
    ledgerSnapshots.removeWhere((f) => f.path == path);
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    // 测试关注的是"远端账本列表",由 [ledgerSnapshots] 控制
    return List.unmodifiable(ledgerSnapshots);
  }

  @override
  Future<bool> exists({required String path}) async {
    return _files.containsKey(path) ||
        ledgerSnapshots.any((f) => f.path == path);
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    if (!_files.containsKey(path) &&
        !ledgerSnapshots.any((f) => f.path == path)) {
      return null;
    }
    return CloudFile(name: path, path: path);
  }
}

// =====================================================================
// FakeSpitoutCloudProvider — 主入口
// =====================================================================

class FakeSpitoutCloudProvider extends SpitoutCloudProvider {
  FakeSpitoutCloudProvider({
    String? userId = 'test-user-id',
    String? deviceId = 'test-device-id',
  }) {
    _fakeAuth = FakeSpitoutCloudAuthService(
      userId: userId,
      deviceId: deviceId,
    );
    _fakeStorage = FakeSpitoutCloudStorageService();
  }

  late final FakeSpitoutCloudAuthService _fakeAuth;
  late final FakeSpitoutCloudStorageService _fakeStorage;

  /// In-memory server 状态:全部 sync_changes 流。
  /// 测试通过 [pushFakeChange] 往里塞;[pullChanges] 按 since 切片返回。
  final List<SpitoutCloudSyncChange> _serverChanges = [];

  /// 在线 ledger list(server 端 `/sync/ledgers` 返回)。
  /// 测试通过 [pushFakeLedger] 注入。
  final List<SpitoutCloudReadLedger> _serverLedgers = [];

  /// 历次 push 操作记录(用于断言"几次 push" / "推了哪些 change")
  final List<List<Map<String, dynamic>>> pushedBatches = [];

  /// 历次 pullChanges 调用记录(用于断言"几次 pull" / "since 序列")
  final List<({int? since, int limit, bool persistCursor})> pullCalls = [];

  /// 控制 pullChanges 是否抛错(测试错误恢复路径)
  Exception Function(int? since)? pullErrorInjector;

  /// 控制 storage.list 是否抛错
  Exception? storageListError;

  /// 控制 readLedgers 是否抛错(Surface 1「远端下线 → 全量清共享账本」测试用)。
  /// 每次调用 readLedgers 时执行,返回的异常被原样抛出。
  Exception Function()? readLedgersErrorInjector;

  /// 控制 deleteLedger 是否抛错(moveToLocal fail-closed 测试用):
  /// 云端删除失败时账本必须保持 cloud、syncId 不清空,不能"本地已断联、云端还在"。
  Exception Function()? deleteLedgerErrorInjector;

  /// writeCreateLedger 是否自动把新建账本登记进 [_serverLedgers]。
  ///
  /// 默认 false 保持既有 e2e 测试语义(server 账本列表完全由 [pushFakeLedger]
  /// 显式控制);moveToCloud 这类"推送后立刻 readLedgers 二次确认"的场景需要
  /// 模拟真实 server 行为(建完账本即出现在列表里),测试内置 true。
  bool autoRegisterWrittenLedgers = false;

  final StreamController<SpitoutCloudRealtimeEvent> _realtimeController =
      StreamController<SpitoutCloudRealtimeEvent>.broadcast();

  // ====== 覆盖 SpitoutCloudProvider getter ======

  @override
  String? get baseUrl => 'https://fake.test';

  @override
  String? get apiPrefix => '/api/v1';

  @override
  CloudAuthService get auth => _fakeAuth;

  @override
  CloudStorageService get storage => _StorageProxy(
        _fakeStorage,
        () => storageListError,
      );

  // ====== 覆盖 SyncEngine 用到的方法 ======

  @override
  Future<SpitoutCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
    bool persistCursor = true,
  }) async {
    pullCalls.add((since: since, limit: limit, persistCursor: persistCursor));
    final injector = pullErrorInjector;
    if (injector != null) {
      final err = injector(since);
      // ignore: only_throw_errors
      throw err;
    }
    final from = since ?? 0;
    final unread = _serverChanges.where((c) => c.changeId > from).toList();
    final slice = unread.take(limit).toList();
    return SpitoutCloudPullResult(
      changes: slice,
      serverCursor: slice.isEmpty ? from : slice.last.changeId,
      hasMore: unread.length > slice.length,
    );
  }

  @override
  Future<void> pushChanges({
    required List<Map<String, dynamic>> changes,
  }) async {
    pushedBatches.add(changes);
  }

  @override
  Future<List<SpitoutCloudReadLedger>> readLedgers() async {
    final injector = readLedgersErrorInjector;
    if (injector != null) {
      throw injector();
    }
    return List.unmodifiable(_serverLedgers);
  }

  @override
  Stream<SpitoutCloudRealtimeEvent> get realtimeEvents =>
      _realtimeController.stream;

  @override
  Future<void> startRealtime() async {
    // no-op:测试不真起 WS
  }

  // ====== createInvite(共享账本邀请码) ======
  // 与 leaveLedger/deleteLedger 同理:facade 真实现走 `_storage`,fake 的
  // `_storage` 为 null 不覆盖会抛 CloudConfigurationException。这里直接覆盖,
  // 内存模拟 server 行为并暴露调用记录 / 错误注入点供测试断言。

  /// 历次 createInvite 调用记录(测试断言「是否触达云端建邀请」用)。
  final List<({String ledgerId, String role, int expiresInHours})>
      createInviteCalls = [];

  /// 控制 createInvite 是否抛错(测试「push 成功但建邀请失败」等路径用)。
  /// 每次调用 createInvite 时执行,返回的异常被原样抛出。
  Exception Function()? createInviteErrorInjector;

  @override
  Future<SpitoutCloudInvite> createInvite({
    required String ledgerId,
    String role = 'editor',
    int expiresInHours = 24,
  }) async {
    createInviteCalls.add(
      (ledgerId: ledgerId, role: role, expiresInHours: expiresInHours),
    );
    final injector = createInviteErrorInjector;
    if (injector != null) {
      // ignore: only_throw_errors
      throw injector();
    }
    final now = DateTime.now().toUtc();
    return SpitoutCloudInvite(
      code: 'CODE${createInviteCalls.length}',
      formattedCode: 'CODE ${createInviteCalls.length}',
      targetRole: role,
      expiresAt: now.add(Duration(hours: expiresInHours)),
      createdAt: now,
      shareUrl: 'https://fake.test/i/${createInviteCalls.length}',
    );
  }

  // ====== leaveLedger / deleteLedger(共享账本退出 / 全局删除) ======
  // 注意:facade 真实现走 `_storage`(私有字段),而 fake 的 `_storage` 为 null,
  // 不覆盖会抛 CloudConfigurationException。这里直接覆盖,内存模拟 server 行为:
  // server 移除成员 / 级联删账本后不再返回该账本,故从 [_serverLedgers] 摘除。

  /// 历次 leaveLedger 调用记录(测试断言用)
  final List<String> leaveLedgerCalls = [];

  @override
  Future<void> leaveLedger({required String ledgerId}) async {
    leaveLedgerCalls.add(ledgerId);
    // 模拟 server 移除成员后不再返回该账本
    _serverLedgers.removeWhere((l) => l.ledgerId == ledgerId);
  }

  /// 历次 deleteLedger 调用记录(测试断言用)
  final List<String> deleteLedgerCalls = [];

  /// deleteLedger 执行期间的同步副作用钩子(测试注入用)。
  ///
  /// 在「记录调用后、错误注入/摘除前」被 await 执行,用于模拟「服务端删账本时
  /// 向 owner 自己广播 member_change.removed 回声」这一时刻——此时 moveToLocal
  /// 的忽略集合已登记、尚未进 finally,可在此触发 WS 事件验证回声被拦截。
  Future<void> Function()? deleteLedgerSideEffect;

  @override
  Future<void> deleteLedger({required String ledgerId}) async {
    deleteLedgerCalls.add(ledgerId);
    // 删云端期间的副作用(如模拟 WS removed 回声),在错误注入/摘除前执行。
    final sideEffect = deleteLedgerSideEffect;
    if (sideEffect != null) await sideEffect();
    // 先注入错误再摘除:模拟"server 侧删除失败,云端副本仍在"。
    // 调用方(moveToLocal)必须 fail-closed —— 不许翻 mode / 清 syncId。
    final injected = deleteLedgerErrorInjector;
    if (injected != null) throw injected();
    // 模拟 server 级联删除:server 不再返回该账本
    _serverLedgers.removeWhere((l) => l.ledgerId == ledgerId);
  }

  // ====== Testing helpers ======

  /// 模拟 server 推一条 sync_change(`change_id` 自增)。
  /// caller 通过 [WS 触发](调 [emitRealtimeEvent])或者让 client 主动 pull 拉到。
  SpitoutCloudSyncChange pushFakeChange({
    String entityType = 'transaction',
    required String entitySyncId,
    String ledgerId = '',
    String action = 'upsert',
    Map<String, dynamic>? payload,
    String updatedByDeviceId = 'remote-device',
  }) {
    final change = SpitoutCloudSyncChange(
      changeId: _serverChanges.length + 1,
      ledgerId: ledgerId,
      entityType: entityType,
      entitySyncId: entitySyncId,
      action: action,
      updatedByDeviceId: updatedByDeviceId,
      updatedAt: '2026-05-24T10:00:00Z',
      payload: payload,
    );
    _serverChanges.add(change);
    return change;
  }

  /// 模拟 server 端的账本列表(`/sync/ledgers` 返)。
  /// [monthStartDay] 不传模拟老 server 未返该字段(null 哨兵)。
  void pushFakeLedger({
    required String ledgerId,
    String ledgerName = 'Fake Ledger',
    String currency = 'CNY',
    String role = 'owner',
    bool isShared = false,
    int memberCount = 1,
    int? monthStartDay,
    DateTime? updatedAt,
  }) {
    _serverLedgers.add(SpitoutCloudReadLedger(
      ledgerId: ledgerId,
      ledgerName: ledgerName,
      currency: currency,
      role: role,
      isShared: isShared,
      memberCount: memberCount,
      monthStartDay: monthStartDay,
      updatedAt: updatedAt ?? DateTime.now(),
      transactionCount: 0,
      expenseTotal: 0,
      balance: 0,
    ));
  }

  /// 模拟 server 推 WS 事件
  void emitRealtimeEvent(SpitoutCloudRealtimeEvent event) {
    _realtimeController.add(event);
  }

  /// 添加 ledger snapshot(`storage.list(path: '')` 返回)— fullPush 决策用
  void pushFakeLedgerSnapshot({
    required String ledgerId,
  }) {
    _fakeStorage.ledgerSnapshots.add(CloudFile(
      name: ledgerId,
      path: ledgerId,
    ));
  }

  /// 清空所有 in-memory 状态
  void reset() {
    _serverChanges.clear();
    _serverLedgers.clear();
    pushedBatches.clear();
    pullCalls.clear();
    pullErrorInjector = null;
    storageListError = null;
    readLedgersErrorInjector = null;
    deleteLedgerErrorInjector = null;
    deleteLedgerSideEffect = null;
    autoRegisterWrittenLedgers = false;
    deleteLedgerCalls.clear();
    writeCreateLedgerCalls.clear();
    writeCreateLedgerGate = null;
    readLedgerStatsCalls = 0;
    ledgerStatsOverrides.clear();
    failingReadLedgerStats = false;
    createInviteCalls.clear();
    createInviteErrorInjector = null;
    _fakeStorage.ledgerSnapshots.clear();
  }

  // ====== fullPush 路径用 ======

  final List<SpitoutCloudWriteCommitMeta> writeCreateLedgerCalls = [];

  /// writeCreateLedger 的**阻塞闸门**(测试注入用)。
  ///
  /// 设为非 null 时,writeCreateLedger 会先 await 这个 completer 才继续——用于
  /// 模拟「fullPush 卡在 writeCreateLedger」的 in-flight 场景,好让测试在此期间
  /// 触发 moveToLocal 登记 abort 信号、验证 fullPush 被中止后不重建 S1。
  /// 测试完成后由测试自行 complete 放行(或不放行以模拟永不完成的 fullPush)。
  Completer<void>? writeCreateLedgerGate;

  @override
  Future<SpitoutCloudWriteCommitMeta> writeCreateLedger({
    String? ledgerId,
    required String ledgerName,
    String currency = 'CNY',
    String? idempotencyKey,
  }) async {
    // 阻塞闸门:模拟 fullPush 卡在建本网络调用,给测试制造 in-flight 窗口。
    final gate = writeCreateLedgerGate;
    if (gate != null) await gate.future;
    final meta = SpitoutCloudWriteCommitMeta(
      ledgerId: ledgerId ?? 'auto-$ledgerName',
      baseChangeId: 0,
      newChangeId: _serverChanges.length + 1,
      serverTimestamp: DateTime.now().toUtc(),
      idempotencyReplayed: false,
    );
    writeCreateLedgerCalls.add(meta);
    // 模拟真实 server:建本成功后该账本立刻出现在 readLedgers 列表里,
    // 让 moveToCloud 的"二次确认"能走通成功分支。
    if (autoRegisterWrittenLedgers &&
        !_serverLedgers.any((l) => l.ledgerId == meta.ledgerId)) {
      pushFakeLedger(
        ledgerId: meta.ledgerId,
        ledgerName: ledgerName,
        currency: currency,
      );
    }
    return meta;
  }

  @override
  Future<SpitoutCloudProfile> getMyProfile() async {
    // syncAccount() 会先 syncMyProfile()(头像/外观下拉),fake 需给空 profile,
    // 否则 UnimplementedError 会污染日志。空 profile → avatarUrl=null,
    // syncMyProfile 走 "server has no avatar, local is local-only, skip" 分支。
    final user = await auth.currentUser;
    return SpitoutCloudProfile(userId: user?.id ?? '');
  }

  /// readLedgerStats 调用次数(自愈节流 / 熔断场景断言用)。
  int readLedgerStatsCalls = 0;

  /// 测试可直接指定某账本的 stats 返回值(模拟 server 口径与本地
  /// 系统性偏差等场景);未指定时从 [_serverChanges] 推导"存活"实体计数。
  final Map<String, SpitoutCloudLedgerStats> ledgerStatsOverrides = {};

  /// 测试可让其 [readLedgerStats] 直接抛错,用于验证自愈的容错路径:
  /// stats 查询失败时,自愈应静默吞错、不崩溃、不误 heal、不误触熔断。
  bool failingReadLedgerStats = false;

  @override
  Future<SpitoutCloudLedgerStats> readLedgerStats({
    required String ledgerId,
  }) async {
    readLedgerStatsCalls++;
    if (failingReadLedgerStats) {
      throw Exception('injected readLedgerStats failure');
    }
    final override = ledgerStatsOverrides[ledgerId];
    if (override != null) return override;
    // 推导:对 _serverChanges 按 entitySyncId 依次应用 upsert/delete,
    // 得到各类实体的"存活"集合,与 server 端 stats 口径一致。
    final liveTxPerLedger = <String, Set<String>>{};
    final liveCategories = <String>{};
    for (final ch in _serverChanges) {
      if (ch.entityType == 'transaction') {
        final set = liveTxPerLedger.putIfAbsent(ch.ledgerId, () => {});
        if (ch.action == 'delete') {
          set.remove(ch.entitySyncId);
        } else {
          set.add(ch.entitySyncId);
        }
      } else if (ch.entityType == 'category') {
        if (ch.action == 'delete') {
          liveCategories.remove(ch.entitySyncId);
        } else {
          liveCategories.add(ch.entitySyncId);
        }
      }
    }
    final txCount = liveTxPerLedger[ledgerId]?.length ?? 0;
    final txTotal =
        liveTxPerLedger.values.fold<int>(0, (a, s) => a + s.length);
    return SpitoutCloudLedgerStats(
      transactionCount: txCount,
      transactionTotal: txTotal,
      categoryCount: liveCategories.length,
      categoryTotal: liveCategories.length,
    );
  }

  @override
  Future<SpitoutCloudSharedResources> fetchSharedResources({
    required String ledgerId,
  }) async {
    throw UnimplementedError('FakeProvider.fetchSharedResources');
  }
}

/// 让 storage.list 也能注入错误(因为 storage getter 本身返 fake,内部 list
/// 调用时检查注入错误)。
class _StorageProxy implements CloudStorageService {
  _StorageProxy(this._real, this._errorGetter);
  final FakeSpitoutCloudStorageService _real;
  final Exception? Function() _errorGetter;

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) =>
      _real.upload(path: path, data: data, metadata: metadata);

  @override
  Future<String?> download({required String path}) =>
      _real.download(path: path);

  @override
  Future<void> delete({required String path}) => _real.delete(path: path);

  @override
  Future<List<CloudFile>> list({required String path}) async {
    final err = _errorGetter();
    if (err != null) {
      // ignore: only_throw_errors
      throw err;
    }
    return _real.list(path: path);
  }

  @override
  Future<bool> exists({required String path}) => _real.exists(path: path);

  @override
  Future<CloudFile?> getMetadata({required String path}) =>
      _real.getMetadata(path: path);
}
