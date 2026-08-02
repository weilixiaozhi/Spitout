// 回归测试:replayAllChanges / 增量 pull 中 ledger_snapshot:delete 必须清除
// 已删账本及其全部交易(幽灵账本复活 bug 的固化)。
//
// 背景:云端 sync_changes 是 append-only 日志,删除账本只是追加一条
// ledger_snapshot:delete 墓碑,历史 ledger:create / transaction:create 记录
// 从不物理消失。新设备登录 / 重装 / 从云端恢复时 replayAllChanges() 从
// change_id=0 整段重放(复用 applyRemoteChange,但不走 fullPull)。
// 因此 applyRemoteChange 在 ledger_snapshot 且 action==delete 时须就近调用
// _purgeLocalLedgerByExternalId,连账本行带交易一起清掉,否则
// ledger:create + transaction:create 会把账本连同交易重新建回本地,
// 出现已删账本带数据"诈尸"。本测试固化该行为。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;

  setUp(() async {
    resetGlobalTestState();
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

  /// 模拟"云端变更日志":创建账本 + 两条交易 + 删除墓碑。
  /// 顺序即 change_id 递增,删除在最后,与 replay 重放顺序一致。
  void seedDeletedLedgerLog({required String ledgerSyncId}) {
    // 1) 账本创建(ledger:create 经 applyRemoteChange 在本地 insert 一行)
    provider.pushFakeChange(
      entityType: 'ledger',
      entitySyncId: ledgerSyncId,
      ledgerId: '',
      action: 'upsert',
      payload: {
        'ledgerName': '已删账本',
        'currency': 'CNY',
        'monthStartDay': 1,
      },
    );
    // 2) 两条交易(ledgerId 用账本 external_id = ledgerSyncId,apply 据此挂回)
    for (final txId in const ['tx-ghost-1', 'tx-ghost-2']) {
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: txId,
        ledgerId: ledgerSyncId,
        payload: {
          'syncId': txId,
          'type': 'expense',
          'amount': 10,
          'happenedAt': '2026-07-12T00:00:00Z',
        },
      );
    }
    // 3) 删除墓碑(关键:必须清除它,否则账本带数据复活)
    provider.pushFakeChange(
      entityType: 'ledger_snapshot',
      entitySyncId: ledgerSyncId,
      ledgerId: '',
      action: 'delete',
    );
  }

  /// 断言本地既不残留账本、也不残留其交易。
  Future<void> expectNoLedgerOrTx() async {
    final ledgers = await db.select(db.ledgers).get();
    final txs = await db.select(db.transactions).get();
    expect(ledgers, isEmpty, reason: '已删账本不应在重放后被复活');
    expect(txs, isEmpty, reason: '已删账本的交易不应随账本复活');
  }

  test('replayAllChanges:已删账本及其交易不应被重放复活', () async {
    const ledgerSyncId = 'ghost-ledger-uuid';
    seedDeletedLedgerLog(ledgerSyncId: ledgerSyncId);

    // 新设备 / 重装 / 从云端恢复 → 从 cursor=0 整段重放
    await engine.replayAllChanges();

    await expectNoLedgerOrTx();
  });

  test('增量 pull:其他设备删除的账本也应被 purge', () async {
    const ledgerSyncId = 'remote-deleted-ledger';
    seedDeletedLedgerLog(ledgerSyncId: ledgerSyncId);

    // 普通增量 pull 复用同一 apply 入口,delete 信号同样必须生效
    await engine.pull('');

    await expectNoLedgerOrTx();
  });

  test('ledger_snapshot:delete 对本地本就不存在的账本幂等(不报错)', () async {
    const ledgerSyncId = 'never-local-ledger';
    // 只下发 delete 墓碑,本地从未建过该账本
    provider.pushFakeChange(
      entityType: 'ledger_snapshot',
      entitySyncId: ledgerSyncId,
      ledgerId: '',
      action: 'delete',
    );

    // _purgeLocalLedgerByExternalId 在 localId==null 时静默返回,不应抛异常
    await engine.replayAllChanges();

    final ledgers = await db.select(db.ledgers).get();
    expect(ledgers, isEmpty);
  });
}
