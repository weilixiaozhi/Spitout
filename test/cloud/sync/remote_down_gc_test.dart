/// syncLedgersFromServer 的“读列表失败是否清本地”集成测试。
///
/// 需求锚点（大众 app 行为）：
/// - 只有**成功**读到服务器列表后，才能按列表做 GC（服务器明确不返回的
///   共享账本 → 清本地副本；个人云账本不受 GC 影响，仍只在登出/切换时清）；
/// - 任何读列表失败（未认证 / 配置损坏 / 404 / 5xx / Socket / 超时）
///   一律**不清**本地数据，只把错误抛给上层展示同步失败。
library;

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

void main() {
  // LoggerService 初始化依赖平台通道,必须先确保测试 binding 就绪。
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
    engine = SyncEngine(
      db: db,
      provider: fake,
      changeTracker: tracker,
      repo: repo,
    );
    events = [];
    engine.events.listen(events.add);
  });

  tearDown(() => db.close());

  /// 本地写入一条共享账本（带交易），返回本地自增 id。
  Future<int> seedLocalSharedLedger(String extId) async {
    final localId = await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            name: 'Shared-$extId',
            syncId: Value(extId),
            isShared: const Value(true),
            myRole: const Value('editor'),
          ),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            ledgerId: localId,
            type: 'expense',
            amount: 1000,
            syncId: Value('tx-$extId'),
          ),
        );
    return localId;
  }

  /// 本地写入一条个人云账本（storage_mode='cloud'，非共享）。
  Future<int> seedLocalPersonalCloudLedger() async {
    return db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            name: 'PersonalCloud',
            syncId: const Value('personal-1'),
            isShared: const Value(false),
            storageMode: const Value('cloud'),
          ),
        );
  }

  Future<int> sharedLedgerCount() async => (await (db.select(
    db.ledgers,
  )..where((l) => l.isShared.equals(true))).get()).length;

  Future<bool> ledgerExists(int id) async => (await (db.select(
    db.ledgers,
  )..where((l) => l.id.equals(id))).get()).isNotEmpty;

  test('CloudNotAuthenticated：抛未认证错误，共享账本保留', () async {
    await seedLocalSharedLedger('ext-1');
    final personal = await seedLocalPersonalCloudLedger();
    fake.readLedgersErrorInjector = () =>
        CloudNotAuthenticatedException('session 失效');

    await expectLater(
      engine.syncLedgersFromServer(),
      throwsA(isA<CloudNotAuthenticatedException>()),
    );

    expect(await sharedLedgerCount(), 1, reason: '认证失败不得清本地数据');
    expect(await ledgerExists(personal), isTrue, reason: '个人云账本同样保留');
  });

  test('CloudConfiguration：抛配置错误，共享账本保留', () async {
    await seedLocalSharedLedger('ext-1');
    fake.readLedgersErrorInjector = () =>
        CloudConfigurationException('storage 未就绪');

    await expectLater(
      engine.syncLedgersFromServer(),
      throwsA(isA<CloudConfigurationException>()),
    );

    expect(await sharedLedgerCount(), 1);
  });

  test('CloudStorage 404/410：抛存储错误，共享账本保留', () async {
    await seedLocalSharedLedger('ext-1');
    fake.readLedgersErrorInjector = () =>
        CloudStorageException('Read ledgers failed: not found', null, 404);

    await expectLater(
      engine.syncLedgersFromServer(),
      throwsA(isA<CloudStorageException>()),
    );

    expect(await sharedLedgerCount(), 1);
  });

  test('5xx 连续 3 次失败：只抛错误，永不触发全量清', () async {
    await seedLocalSharedLedger('ext-1');
    fake.readLedgersErrorInjector = () =>
        CloudStorageException('Read ledgers failed: 503', null, 503);

    for (var i = 0; i < 3; i++) {
      await expectLater(
        engine.syncLedgersFromServer(),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await sharedLedgerCount(), 1,
          reason: '第 ${i + 1} 次失败也不得清共享账本');
    }
  });

  test('未知网络异常连续 3 次失败：只抛错误，永不触发全量清', () async {
    await seedLocalSharedLedger('ext-1');
    fake.readLedgersErrorInjector = () => Exception('SocketException: 断网');

    for (var i = 0; i < 3; i++) {
      await expectLater(
        engine.syncLedgersFromServer(),
        throwsA(isA<Exception>()),
      );
      expect(await sharedLedgerCount(), 1);
    }
  });

  test('成功读取后按服务器列表 GC：返回则保留，缺失则逐本清共享账本', () async {
    final ext1 = 'ext-1';
    await seedLocalSharedLedger(ext1);
    await seedLocalSharedLedger('ext-2');
    final personal = await seedLocalPersonalCloudLedger();

    // 服务器只返回 ext-1：ext-2 被逐本清，ext-1 与个人云账本保留。
    fake.pushFakeLedger(
      ledgerId: ext1,
      ledgerName: 'Shared-$ext1',
      role: 'editor',
      isShared: true,
    );

    final n = await engine.syncLedgersFromServer();

    expect(n, 0);
    final rows = await (db.select(db.ledgers)).get();
    final syncIds = rows.map((r) => r.syncId).toSet();
    expect(syncIds, contains(ext1), reason: '服务器返回的账本应保留');
    expect(syncIds, isNot(contains('ext-2')), reason: '服务器缺失的共享账本应清除');
    expect(await ledgerExists(personal), isTrue, reason: '个人云账本不受 GC 影响');
  });
}
