/// 云端账本边界单元测试 —— Phase C。
///
/// 账本归属模型下，"云端账本属于云账号、本地账本属于这台设备" 必须在
/// 登录拉取与退出清理两条边界上都成立：
///   1. syncLedgersFromServer 拉下来的账本一律标 storage_mode='cloud'；
///   2. 纯本地账本(storage_mode='local')不得被同名远端账本静默收编上云，
///      同名时远端账本以带后缀的新账本落地，避免用户混淆；
///   3. 退出登录清理只清云端账本(cloud / 遗留共享)，本地账本零影响。
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    changeTracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: changeTracker);
    provider = FakeSpitoutCloudProvider();
    engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: changeTracker,
      repo: repo,
    );
  });

  tearDown(() async => db.close());

  Future<List<Ledger>> allLedgers() => db.select(db.ledgers).get();

  group('syncLedgersFromServer 账本归属', () {
    test('server 新账本落地时标记为云端账本(storage_mode=cloud)', () async {
      provider.pushFakeLedger(ledgerId: 'srv-1', ledgerName: '工资卡');

      await engine.syncLedgersFromServer();

      final rows = await allLedgers();
      expect(rows, hasLength(1));
      expect(rows.single.syncId, 'srv-1');
      expect(rows.single.storageMode, 'cloud',
          reason: '从云端拉下来的账本必须标 cloud,否则会被本地闸门挡住永远同步不了');
    });

    test('同名纯本地账本不被静默收编,远端账本另建并加区分后缀', () async {
      final localId = await repo.createLedger(name: '日常', storageMode: 'local');
      provider.pushFakeLedger(ledgerId: 'srv-2', ledgerName: '日常');

      await engine.syncLedgersFromServer();

      final local = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(localId)))
          .getSingle();
      expect(local.storageMode, 'local',
          reason: '纯本地账本被同名远端账本收编 = 本地数据静默上云,违反核心不变量');
      expect(local.syncId, isNull);
      expect(local.name, '日常');

      final cloudRows = await (db.select(db.ledgers)
            ..where((l) => l.syncId.equals('srv-2')))
          .get();
      expect(cloudRows, hasLength(1), reason: '远端账本应另建一行,不能丢');
      expect(cloudRows.single.storageMode, 'cloud');
      expect(cloudRows.single.name, isNot('日常'),
          reason: '与本地账本重名会让用户分不清哪个上云,需加区分后缀');
    });

    test('云端账本丢了 syncId(移动中断)时按同名收编,不重复建本', () async {
      final id = await repo.createLedger(name: '出差', storageMode: 'cloud');
      // 模拟 moveToCloud 在补 syncId 之前中断:mode 已是 cloud 但 syncId 为空。
      await (db.update(db.ledgers)..where((l) => l.id.equals(id)))
          .write(const LedgersCompanion(syncId: Value(null)));
      provider.pushFakeLedger(ledgerId: 'srv-3', ledgerName: '出差');

      await engine.syncLedgersFromServer();

      final rows = await allLedgers();
      expect(rows, hasLength(1), reason: '同一个云端账本不该被拆成两行');
      expect(rows.single.id, id);
      expect(rows.single.syncId, 'srv-3');
      expect(rows.single.storageMode, 'cloud');
    });
  });

  group('purgeAllCloudLedgers 退出清理', () {
    test('只清云端账本,本地账本与其交易零影响', () async {
      final cloudId = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final localId = await repo.createLedger(name: '本地本', storageMode: 'local');
      await repo.addTransaction(
        ledgerId: cloudId,
        type: 'expense',
        amount: 10,
        happenedAt: DateTime(2026, 5, 1),
      );
      await repo.addTransaction(
        ledgerId: localId,
        type: 'expense',
        amount: 20,
        happenedAt: DateTime(2026, 5, 1),
      );

      await repo.purgeAllCloudLedgers();

      final rows = await allLedgers();
      expect(rows.map((l) => l.id), [localId]);
      final txs = await db.select(db.transactions).get();
      expect(txs.map((t) => t.ledgerId), everyElement(localId));
      final changes = await db.select(db.localChanges).get();
      expect(changes.where((c) => c.ledgerId == cloudId), isEmpty,
          reason: '云端账本的待推变更必须一并清掉,否则重登会重放幽灵数据');
    });

    test('遗留共享账本(storage_mode 非 cloud)也被清', () async {
      final sharedId = await repo.createLedger(name: '共享本', storageMode: 'local');
      await (db.update(db.ledgers)..where((l) => l.id.equals(sharedId)))
          .write(const LedgersCompanion(isShared: Value(true)));
      final localId = await repo.createLedger(name: '本地本', storageMode: 'local');

      await repo.purgeAllCloudLedgers();

      final rows = await allLedgers();
      expect(rows.map((l) => l.id), [localId]);
    });

    test('没有云端账本时幂等 no-op', () async {
      final localId = await repo.createLedger(name: '本地本', storageMode: 'local');

      await repo.purgeAllCloudLedgers();
      await repo.purgeAllCloudLedgers();

      final rows = await allLedgers();
      expect(rows.map((l) => l.id), [localId]);
    });
  });
}
