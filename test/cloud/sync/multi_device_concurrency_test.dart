// 多设备并发同步测试：两台设备共享同一「服务器」（FakeSpitoutCloudProvider），
// 并发编辑同一交易，验证 last-write-wins 收敛一致。
//
// 设计意图：mock 层测试只能验证"单设备 push 被调用"，无法覆盖真实并发冲突语义。
// 本测试用两台设备各自的真实 SQLite 库 + 同一 fake server，模拟：
//   1. A 建账本 + 建交易并推送（server 物化）；
//   2. B 全新设备从 0 拉全量历史（等价新设备登录恢复）；
//   3. A、B 未互相同步即各自修改同一交易并推送（并发冲突）；
//   4. 双方各自 pull 后收敛到 server 上最后写入者的值。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSpitoutCloudProvider server;

  setUp(() {
    resetGlobalTestState();
    server = FakeSpitoutCloudProvider();
  });

  late SpitoutDatabase dbA;
  late LocalRepository repoA;
  late ChangeTracker trackerA;
  late SyncEngine engineA;

  late SpitoutDatabase dbB;
  late LocalRepository repoB;
  late ChangeTracker trackerB;
  late SyncEngine engineB;

  Future<void> buildDeviceA() async {
    dbA = SpitoutDatabase.forTesting(NativeDatabase.memory());
    trackerA = ChangeTracker(dbA);
    repoA = LocalRepository(dbA, changeTracker: trackerA);
    engineA = SyncEngine(
      db: dbA,
      provider: server,
      changeTracker: trackerA,
      repo: repoA,
    );
  }

  Future<void> buildDeviceB() async {
    dbB = SpitoutDatabase.forTesting(NativeDatabase.memory());
    trackerB = ChangeTracker(dbB);
    repoB = LocalRepository(dbB, changeTracker: trackerB);
    engineB = SyncEngine(
      db: dbB,
      provider: server,
      changeTracker: trackerB,
      repo: repoB,
    );
  }

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  /// 把最近一次 push 的批次「物化」为 server 上的 sync_change，
  /// 模拟真实服务器把 A 的推送变成其他设备可拉取的变更流。
  Future<void> materializeLastPush() async {
    for (final change in server.pushedBatches.last) {
      server.pushFakeChange(
        entityType: change['entity_type'] as String,
        entitySyncId: change['entity_sync_id'] as String,
        ledgerId: (change['ledger_id'] as String?) ?? '',
        action: (change['action'] as String?) ?? 'upsert',
        payload: change['payload'] as Map<String, dynamic>?,
      );
    }
  }

  Future<({int ledgerId, int txId})> createLedgerWithTx(
    SpitoutDatabase db,
    ChangeTracker tracker,
    LocalRepository repo,
    int amount,
  ) async {
    final ledgerId = await repo.createLedger(name: '协作账本', storageMode: 'cloud');
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingle();
    // 显式登记 ledger:upsert 变更，让对端能创建同一账本
    await tracker.recordLedgerChange(
      entityType: 'ledger',
      entityId: ledgerId,
      entitySyncId: ledger.syncId!,
      ledgerId: ledgerId,
      action: 'upsert',
    );
    final txId = await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: amount,
      happenedAt: DateTime(2026, 7, 1),
    );
    return (ledgerId: ledgerId, txId: txId);
  }

  test('并发编辑同一交易 → 双方 pull 后 last-write-wins 收敛一致', () async {
    await buildDeviceA();

    // 1) A 建账 + 建交易(100)并推送
    final a = await createLedgerWithTx(dbA, trackerA, repoA, 10000);
    await engineA.push(a.ledgerId.toString());
    await materializeLastPush();

    // 2) B 全新设备：独立 prefs 存储（等价真实设备的独立磁盘）
    SharedPreferences.setMockInitialValues({});
    await buildDeviceB();
    await engineB.pull('');
    // B 端按账本名定位（B 的本地 id 与 A 不同）
    final ledgerBRow = await (dbB.select(dbB.ledgers)
          ..where((l) => l.name.equals('协作账本')))
        .getSingle();
    final txB = await (dbB.select(dbB.transactions)
          ..where((t) => t.ledgerId.equals(ledgerBRow.id)))
        .getSingle();
    expect(txB.amount, 10000, reason: 'B 应从 0 拉全量历史');

    // 3) 并发冲突：A 改 100→200 推送；B 未同步即改 100→300 推送
    await repoA.updateTransaction(id: a.txId, type: 'expense', amount: 20000);
    await engineA.push(a.ledgerId.toString());
    await materializeLastPush();

    await repoB.updateTransaction(
      id: txB.id,
      type: 'expense',
      amount: 30000,
    );
    await engineB.push(ledgerBRow.id.toString());
    await materializeLastPush();

    // 4) 双方各自 pull，收敛到 server 最后写入者(300)
    await engineA.pull('');
    await engineB.pull('');

    final txAFinal = await (dbA.select(dbA.transactions)
          ..where((t) => t.syncId.equals(txB.syncId ?? '')))
        .getSingle();
    final txBFinal = await (dbB.select(dbB.transactions)
          ..where((t) => t.id.equals(txB.id)))
        .getSingle();
    expect(txAFinal.amount, 30000);
    expect(txBFinal.amount, 30000);
  });
}
