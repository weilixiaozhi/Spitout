/// SnapshotSyncCoordinator 单元测试。
///
/// 验证快照型后端响应式触发的核心逻辑:
///   1. 启动扫描(app 重启后残留 dirty 补传);
///   2. watch 触发(写入 dirty 后自动上传);
///   3. auto_sync 闸门(关闭时不上传、不清信号);
///   4. auto_sync 关闭→开启补扫(scanNow);
///   5. 上传失败保留 dirty 待重试;
///   6. UPSERT 语义(同账本重复标记只留一行)。
///
/// auto_sync 闸门通过可注入的 [SnapshotSyncCoordinator.autoSyncEnabled]
/// 参数控制,避免 SharedPreferences 静态单例跨测试缓存导致中途切换不生效。
library;

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/snapshot_sync_coordinator.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';

/// 可控的 SyncService 替身:记录 uploadCurrentLedger 调用,可控成功/失败。
///
/// 继承 [LocalOnlySyncService] 以省去实现全部接口,仅 override
/// uploadCurrentLedger(本测试唯一调用的方法)。
class _FakeSyncService extends LocalOnlySyncService {
  final List<int> uploadedLedgerIds = [];

  /// 设为 true 时 uploadCurrentLedger 抛异常(模拟上传失败)。
  bool shouldFail = false;

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    uploadedLedgerIds.add(ledgerId);
    if (shouldFail) {
      throw Exception('mock upload failure for ledger $ledgerId');
    }
  }
}

void main() {
  late SpitoutDatabase db;
  late _FakeSyncService sync;

  /// auto_sync 状态:测试中可动态切换,供 coordinator 注入读取。
  bool autoSyncOn = true;

  setUp(() {
    // LoggerService 初始化时会注册 MethodChannel(native bridge),必须先
    // 确保 Flutter binding 就绪,否则 setMethodCallHandler 抛断言错误。
    TestWidgetsFlutterBinding.ensureInitialized();
    // mock SharedPreferences:LoggerService._loadLogs 内部会调
    // SharedPreferences.getInstance() 落盘日志,未 mock 会抛
    // MissingPluginException 异步冒泡导致测试失败。
    SharedPreferences.setMockInitialValues({});
    autoSyncOn = true;
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    sync = _FakeSyncService();
  });

  tearDown(() async {
    await db.close();
  });

  /// 构造 coordinator 并启动(auto_sync 读取注入受控开关)。
  SnapshotSyncCoordinator buildCoordinator() {
    final c = SnapshotSyncCoordinator(
      db: db,
      syncService: sync,
      autoSyncEnabled: () async => autoSyncOn,
    );
    c.start();
    addTearDown(c.dispose);
    return c;
  }

  /// 写入脏信号(INSERT OR IGNORE)。
  Future<void> markDirty(int ledgerId) async {
    await db.into(db.snapshotDirtyLedgers).insert(
          SnapshotDirtyLedgersCompanion.insert(ledgerId: d.Value(ledgerId)),
          mode: d.InsertMode.insertOrIgnore,
        );
  }

  /// 读取当前所有脏账本 id。
  Future<List<int>> dirtyIds() async =>
      (await db.select(db.snapshotDirtyLedgers).get())
          .map((r) => r.ledgerId)
          .toList();

  /// 等待 debounce(500ms) + 上传异步链完成。
  Future<void> waitUpload() =>
      Future.delayed(const Duration(milliseconds: 900));

  test('启动扫描: 残留 dirty 行被上传并清除', () async {
    await markDirty(1);
    await markDirty(2);
    buildCoordinator();
    await waitUpload();
    expect(sync.uploadedLedgerIds, containsAll([1, 2]),
        reason: '残留 dirty 行应被逐本上传');
    expect(await dirtyIds(), isEmpty, reason: '上传成功后脏信号应被清除');
  });

  test('watch 触发: 写入 dirty 后自动上传并清除', () async {
    buildCoordinator();
    // 等 watch 订阅建立(首帧 emit 当前空表)
    await Future.delayed(const Duration(milliseconds: 200));
    await markDirty(5); // 写入触发 watch
    await waitUpload();
    expect(sync.uploadedLedgerIds, contains(5),
        reason: '写入 dirty 后应自动触发上传');
    expect(await dirtyIds(), isEmpty, reason: '上传成功后脏信号应被清除');
  });

  test('auto_sync 关闭: 不上传, 保留 dirty', () async {
    autoSyncOn = false;
    await markDirty(7);
    buildCoordinator();
    await waitUpload();
    expect(sync.uploadedLedgerIds, isEmpty, reason: 'auto_sync 关闭不应上传');
    expect(await dirtyIds(), contains(7), reason: 'dirty 信号应保留待重试');
  });

  test('auto_sync 关闭→开启: scanNow 补扫上传', () async {
    autoSyncOn = false;
    await markDirty(9);
    final coordinator = buildCoordinator();
    await waitUpload();
    expect(sync.uploadedLedgerIds, isEmpty, reason: '关闭期间不上传');
    // 用户开启 auto_sync 并触发补扫(模拟 syncServiceProvider 的 ref.listen 边沿)
    autoSyncOn = true;
    await coordinator.scanNow();
    await waitUpload();
    expect(sync.uploadedLedgerIds, contains(9), reason: '开启后补扫应上传残留 dirty');
    expect(await dirtyIds(), isEmpty, reason: '补扫成功后应清除 dirty');
  });

  test('上传失败: 保留 dirty 不清除, 下次重试成功后清除', () async {
    sync.shouldFail = true;
    await markDirty(11);
    final coordinator = buildCoordinator();
    await waitUpload();
    expect(sync.uploadedLedgerIds, contains(11), reason: '失败也应尝试上传');
    expect(await dirtyIds(), contains(11), reason: '失败时 dirty 信号应保留');
    // 恢复成功, 重试
    sync.shouldFail = false;
    sync.uploadedLedgerIds.clear();
    await coordinator.scanNow();
    await waitUpload();
    expect(sync.uploadedLedgerIds, contains(11), reason: '重试应再次上传');
    expect(await dirtyIds(), isEmpty, reason: '重试成功后应清除 dirty');
  });

  test('UPSERT 语义: 同账本重复标记只留一行', () async {
    await markDirty(13);
    await markDirty(13);
    await markDirty(13);
    expect(await dirtyIds(), [13], reason: '同账本多次标记只留一行');
  });

  test('多账本: 单本失败不影响其它账本上传', () async {
    // ledger 21 上传失败,ledger 22 成功 → 22 应被清除,21 保留。
    // 用 _OverrideFailSyncService:第一次调用(ledgerId=21)失败,后续成功。
    sync = _OverrideFailSyncService((() {
      var firstCall = true;
      return () {
        final fail = firstCall;
        firstCall = false;
        return fail;
      };
    })());
    await markDirty(21);
    await markDirty(22);
    buildCoordinator();
    await waitUpload();
    expect(sync.uploadedLedgerIds, containsAll([21, 22]),
        reason: '两本都应被尝试上传');
    // 第一本(21)失败保留,第二本(22)成功清除
    final remaining = await dirtyIds();
    expect(remaining, contains(21), reason: '失败账本 dirty 保留');
    expect(remaining, isNot(contains(22)), reason: '成功账本 dirty 清除');
  });
}

/// 按回调决定是否失败的替身(用于"单本失败不影响其它"测试)。
///
/// 继承 [_FakeSyncService] 以复用 uploadedLedgerIds 记录字段,仅 override
/// uploadCurrentLedger 加入可控失败逻辑。
class _OverrideFailSyncService extends _FakeSyncService {
  _OverrideFailSyncService(this._shouldFailFn);
  final bool Function() _shouldFailFn;

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    uploadedLedgerIds.add(ledgerId);
    if (_shouldFailFn()) {
      throw Exception('mock upload failure for ledger $ledgerId');
    }
  }
}
