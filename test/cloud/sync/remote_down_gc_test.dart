import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

/// Surface 1「远端下线 → 全量清本地共享账本」引擎级集成测试。
///
/// 设计意图：`syncLedgersFromServer` 的 readLedgers 异常分类是本次改造核心——
///   - CloudNotAuthenticated / CloudConfiguration：session 确认失效，
///     远端等价于空集 → 立即 `_gcAllLocalSharedLedgers()`、返回 0 不报错；
///   - CloudStorage 404/410：路由确死 → 同上立即清；
///   - CloudStorage 5xx / 其它网络错误：可能瞬时抖动 → 阈值状态机
///     （10 分钟窗口内 3 次）命中才清，且错误 rethrow 逃逸给 bootstrap；
///   - 成功一次即重置失败计数。
/// 全程断言个人账本（isShared=false）不被误伤，并验证 LedgersPurged 事件广播。
void main() {
  // LoggerService 初始化依赖平台通道,必须先确保测试 binding 就绪
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late FakeSpitoutCloudProvider fake;
  late SyncEngine engine;
  late List<SyncEvent> events;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    fake = FakeSpitoutCloudProvider();
    engine =
        SyncEngine(db: db, provider: fake, changeTracker: tracker, repo: repo);
    events = [];
    engine.events.listen(events.add);
  });

  tearDown(() => db.close());

  /// 本地写入一条共享账本（带交易），返回本地自增 id。
  Future<int> seedLocalSharedLedger(String extId) async {
    final localId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Shared-$extId',
            syncId: Value(extId),
            isShared: const Value(true),
            myRole: const Value('editor'),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: localId,
            type: 'expense',
            amount: 10.0,
            syncId: Value('tx-$extId'),
          ),
        );
    return localId;
  }

  /// 本地写入一条个人账本（非共享、无 syncId），返回本地自增 id。
  Future<int> seedLocalPersonalLedger() async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Personal',
            syncId: const Value.absent(),
            isShared: const Value(false),
          ),
        );
  }

  Future<int> sharedLedgerCount() async =>
      (await (db.select(db.ledgers)..where((l) => l.isShared.equals(true)))
              .get())
          .length;

  Future<bool> personalLedgerExists(int id) async =>
      (await (db.select(db.ledgers)..where((l) => l.id.equals(id))).get())
          .isNotEmpty;

  test('CloudNotAuthenticated：立即全量清共享账本 + 广播 LedgersPurged，个人账本不动',
      () async {
    await seedLocalSharedLedger('ext-1');
    await seedLocalSharedLedger('ext-2');
    final personal = await seedLocalPersonalLedger();
    fake.readLedgersErrorInjector =
        () => CloudNotAuthenticatedException('session 失效');

    // 非错误态：不抛出，返回 0
    final n = await engine.syncLedgersFromServer();

    expect(n, 0);
    expect(await sharedLedgerCount(), 0);
    expect(await personalLedgerExists(personal), isTrue);
    expect(events.whereType<LedgersPurged>(), hasLength(1));
  });

  test('CloudConfiguration：配置失效同样立即清', () async {
    await seedLocalSharedLedger('ext-1');
    final personal = await seedLocalPersonalLedger();
    fake.readLedgersErrorInjector =
        () => CloudConfigurationException('storage 未就绪');

    final n = await engine.syncLedgersFromServer();

    expect(n, 0);
    expect(await sharedLedgerCount(), 0);
    expect(await personalLedgerExists(personal), isTrue);
    expect(events.whereType<LedgersPurged>(), hasLength(1));
  });

  test('CloudStorage 404：路由确死 → 立即清，不抛错', () async {
    await seedLocalSharedLedger('ext-1');
    final personal = await seedLocalPersonalLedger();
    fake.readLedgersErrorInjector =
        () => CloudStorageException('Read ledgers failed: not found', null, 404);

    final n = await engine.syncLedgersFromServer();

    expect(n, 0);
    expect(await sharedLedgerCount(), 0);
    expect(await personalLedgerExists(personal), isTrue);
    expect(events.whereType<LedgersPurged>(), hasLength(1));
  });

  test('CloudStorage 5xx：走阈值——前两次失败不清且 rethrow，第三次命中阈值才清',
      () async {
    await seedLocalSharedLedger('ext-1');
    final personal = await seedLocalPersonalLedger();
    fake.readLedgersErrorInjector =
        () => CloudStorageException('Read ledgers failed: 503', null, 503);

    // 第 1、2 次：错误逃逸（供 bootstrap 记 lastSyncError），但共享账本保留
    for (var i = 0; i < 2; i++) {
      await expectLater(
        engine.syncLedgersFromServer(),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await sharedLedgerCount(), 1,
          reason: '第 ${i + 1} 次失败未命中阈值,不应误清');
      expect(events.whereType<LedgersPurged>(), isEmpty);
    }

    // 第 3 次：命中阈值（10 分钟窗口内 3 次）→ 清共享账本，错误仍上抛
    await expectLater(
      engine.syncLedgersFromServer(),
      throwsA(isA<CloudStorageException>()),
    );
    expect(await sharedLedgerCount(), 0);
    expect(await personalLedgerExists(personal), isTrue);
    expect(events.whereType<LedgersPurged>(), hasLength(1));
  });

  test('未知网络异常（无 statusCode）：同样走阈值判定', () async {
    await seedLocalSharedLedger('ext-1');
    fake.readLedgersErrorInjector = () => Exception('SocketException: 断网');

    for (var i = 0; i < 2; i++) {
      await expectLater(
          engine.syncLedgersFromServer(), throwsA(isA<Exception>()));
      expect(await sharedLedgerCount(), 1);
    }
    await expectLater(
        engine.syncLedgersFromServer(), throwsA(isA<Exception>()));
    expect(await sharedLedgerCount(), 0);
  });

  test('成功一次即重置阈值计数：2 次失败 → 成功 → 再 2 次失败仍不清', () async {
    await seedLocalSharedLedger('ext-1');
    // server 端也返回该账本：成功轮次的 GC1 不会把它当孤儿清掉
    fake.pushFakeLedger(
      ledgerId: 'ext-1',
      ledgerName: 'Shared-ext-1',
      role: 'editor',
      isShared: true,
    );

    CloudStorageException storageError() =>
        CloudStorageException('Read ledgers failed: 502', null, 502);

    // 2 次失败（未达阈值）
    fake.readLedgersErrorInjector = storageError;
    for (var i = 0; i < 2; i++) {
      await expectLater(
        engine.syncLedgersFromServer(),
        throwsA(isA<CloudStorageException>()),
      );
    }

    // 成功一次 → 计数归零
    fake.readLedgersErrorInjector = null;
    await engine.syncLedgersFromServer();
    expect(await sharedLedgerCount(), 1, reason: 'server 仍返回该账本,GC1 不清');

    // 再失败 2 次：由于计数已重置，仍未达阈值 → 不清
    fake.readLedgersErrorInjector = storageError;
    for (var i = 0; i < 2; i++) {
      await expectLater(
        engine.syncLedgersFromServer(),
        throwsA(isA<CloudStorageException>()),
      );
    }
    expect(await sharedLedgerCount(), 1);
    expect(events.whereType<LedgersPurged>(), isEmpty);
  });
}
