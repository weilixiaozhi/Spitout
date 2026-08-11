/// 账本归属移动(本地 ↔ 云端)单元测试。
///
/// 覆盖三条移动路径:
///   1. moveToCloud:秒级翻 mode='cloud' + 复用 syncId + 后台 triggerAutoSync 推送;
///      翻 mode 失败必须保持 local(fail-closed)。
///   2. moveToLocal:信号驱动——登记 abort 双中止 → waitFullPushSettle(30s 超时)
///      → 删云端副本(404/410 幂等放行)→ detach 原子断联;删失败保持 cloud、不清 syncId。
///   3. copyToLocal:保留云端副本,新建本地账本并完整拷贝交易 / 编辑历史。
///
/// 核心不变量:任何一步失败都不得留下"本地已断联、云端还在"或
/// "本地标 cloud、云端却没有"的数据孤岛;moveToLocal 全程杜绝「边删边推」孤儿 S1。
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
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

  /// 读取账本行(断言 storage_mode / syncId 用)。
  Future<Ledger> readLedger(int id) =>
      (db.select(db.ledgers)..where((l) => l.id.equals(id))).getSingle();

  /// 把账本标成共享账本(共享账本禁止 move,只能 copyToLocal)。
  Future<void> markShared(int id) async {
    await (db.update(db.ledgers)..where((l) => l.id.equals(id))).write(
      const LedgersCompanion(isShared: Value(true)),
    );
  }

  group('moveToCloud', () {
    test('云端优先:fullPush 成功并确认后翻 cloud,补发 syncId', () async {
      // 模拟真实 server:建本成功即出现在清单里,readLedgers 确认才能通过。
      provider.autoRegisterWrittenLedgers = true;
      final id = await repo.createLedger(name: '本地本', storageMode: 'local');
      await repo.addTransaction(
        ledgerId: id,
        type: 'expense',
        amount: 1250,
        happenedAt: DateTime(2026, 5, 1),
      );

      await engine.moveToCloud(id);

      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'cloud', reason: '云端确认存在后才翻 mode');
      expect(
        ledger.syncId,
        isNotNull,
        reason: '转云端必须补发 syncId 作为 server external_id',
      );
      expect(
        provider.writeCreateLedgerCalls.single.ledgerId,
        ledger.syncId,
        reason: 'fullPush 必须用同一个 syncId 建云端账本',
      );
      expect(
        await provider.storage.exists(path: ledger.syncId!),
        isTrue,
        reason: '云端优先转云端必须已上传快照',
      );
    });

    test('复用已有 syncId 不重发(避免破坏已建立的云端关联)', () async {
      provider.autoRegisterWrittenLedgers = true;
      // 本地账本但已带 syncId(如上云后又搬回本地保留了 id 的数据)。
      final id = await repo.createLedger(name: '本地本', storageMode: 'local');
      const reusedSyncId = 'reused-sync-id-123';
      await repo.updateLedgerSyncId(id: id, syncId: reusedSyncId);

      await engine.moveToCloud(id);

      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'cloud');
      expect(
        ledger.syncId,
        reusedSyncId,
        reason: '已有 syncId 必须复用,换 id 会破坏云端关联',
      );
      expect(
        provider.writeCreateLedgerCalls.single.ledgerId,
        reusedSyncId,
        reason: 'fullPush 必须复用已有 syncId,不得重新生成',
      );
    });

    // 场景 8:云端确认成功但翻 mode 失败 → 抛 CloudSyncException,账本保持 local。
    test('翻 mode 失败时抛异常且账本保持 local、回滚补发 syncId(fail-closed)',
        () async {
      provider.autoRegisterWrittenLedgers = true;
      final id = await repo.createLedger(name: '本地本', storageMode: 'local');
      final failRepo = _FailStorageModeRepo(repo);
      final failEngine = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: changeTracker,
        repo: failRepo,
      );

      await expectLater(
        failEngine.moveToCloud(id),
        throwsA(isA<CloudSyncException>()),
      );

      final ledger = await readLedger(id);
      expect(
        ledger.storageMode,
        'local',
        reason: '翻 mode 失败绝不能留下"标了 cloud 却没上云"的孤岛',
      );
      expect(
        ledger.syncId,
        isNull,
        reason: '本轮补发的 syncId 必须回滚,不留半截云端关联',
      );
    });

    test('已是云端账本时幂等返回,不重复推送', () async {
      final id = await repo.createLedger(name: '云端本', storageMode: 'cloud');

      await engine.moveToCloud(id);

      expect(provider.writeCreateLedgerCalls, isEmpty);
      expect((await readLedger(id)).storageMode, 'cloud');
    });

    test('共享账本禁止转云端(应改用复制到本地)', () async {
      final id = await repo.createLedger(name: '共享本', storageMode: 'local');
      await markShared(id);

      await expectLater(
        engine.moveToCloud(id),
        throwsA(isA<CloudSyncException>()),
      );
      expect((await readLedger(id)).storageMode, 'local');
    });

    // AA 保留:moveToCloud 只翻 mode + 补 syncId + 登记 upsert,不得触碰
    // AA 元数据(开关 / 交易 AA 字段 / 虚拟用户)。
    test('AA 账本转云端后 AA 开关/交易字段/虚拟用户全部保留', () async {
      provider.autoRegisterWrittenLedgers = true;
      final id = await repo.createLedger(
        name: 'AA本地本',
        storageMode: 'local',
        aaEnabled: true,
      );
      await repo.addTransaction(
        ledgerId: id,
        type: 'expense',
        amount: 3000,
        happenedAt: DateTime(2026, 5, 1),
        paidByUserId: 'aa-user-1',
        aaMode: 2,
        aaParticipants: '["aa-user-1","aa-user-2"]',
        aaSplits: '{"aa-user-1":"15","aa-user-2":"15"}',
      );
      final vuId = await repo.create(ledgerId: id, name: '虚拟室友');

      await engine.moveToCloud(id);

      final ledger = await readLedger(id);
      expect(
        ledger.aaEnabled,
        isTrue,
        reason: 'moveToCloud 只翻 mode,不得重置 AA 开关',
      );
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.ledgerId.equals(id))).getSingle();
      expect(tx.paidByUserId, 'aa-user-1');
      expect(tx.aaMode, 2);
      expect(tx.aaParticipants, '["aa-user-1","aa-user-2"]');
      expect(tx.aaSplits, '{"aa-user-1":"15","aa-user-2":"15"}');
      final vus = await repo.getByLedger(id);
      expect(
        vus.map((v) => v.id),
        contains(vuId),
        reason: '虚拟用户随账本保留,不得被移动操作清掉',
      );
    });

    test('账本不存在时抛异常', () async {
      await expectLater(
        engine.moveToCloud(9999),
        throwsA(isA<CloudSyncException>()),
      );
    });
  });

  group('moveToLocal', () {
    test('删除云端副本成功后翻 local 并清空 syncId(彻底断联)', () async {
      final id = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId;
      expect(syncId, isNotNull);

      await engine.moveToLocal(id);

      expect(provider.deleteLedgerCalls, contains(syncId));
      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'local');
      expect(
        ledger.syncId,
        isNull,
        reason: 'syncId 必须清空,否则重登时会被 syncLedgersFromServer 误拉回云端',
      );
    });

    test('云端删除失败时抛异常,账本保持 cloud 且 syncId 不清空', () async {
      final id = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId;
      provider.deleteLedgerErrorInjector = () => Exception('server 500');

      await expectLater(
        engine.moveToLocal(id),
        throwsA(isA<CloudSyncException>()),
      );

      final ledger = await readLedger(id);
      expect(
        ledger.storageMode,
        'cloud',
        reason: '云端副本还在却把本地标 local,会导致同一账本双份且互不同步',
      );
      expect(ledger.syncId, syncId);
    });

    test('已是本地账本时幂等返回,不调用云端删除', () async {
      final id = await repo.createLedger(name: '本地本', storageMode: 'local');

      await engine.moveToLocal(id);

      expect(provider.deleteLedgerCalls, isEmpty);
      expect((await readLedger(id)).storageMode, 'local');
    });

    // AA 保留:moveToLocal 只负责断联(删云端 + detach 清 syncId),不得触碰
    // AA 元数据(开关 / 交易 AA 字段 / 虚拟用户)。
    test('AA 账本转本地后 AA 开关/交易字段/虚拟用户全部保留', () async {
      final id = await repo.createLedger(
        name: 'AA云端本',
        storageMode: 'cloud',
        aaEnabled: true,
      );
      await repo.addTransaction(
        ledgerId: id,
        type: 'expense',
        amount: 4200,
        happenedAt: DateTime(2026, 5, 3),
        paidByUserId: 'aa-user-1',
        aaMode: 2,
        aaParticipants: '["aa-user-1","aa-user-2"]',
        aaSplits: '{"aa-user-1":"21","aa-user-2":"21"}',
      );
      final vuId = await repo.create(ledgerId: id, name: '虚拟室友');

      await engine.moveToLocal(id);

      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'local');
      expect(ledger.aaEnabled, isTrue, reason: 'moveToLocal 只做断联,不得重置 AA 开关');
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.ledgerId.equals(id))).getSingle();
      expect(tx.paidByUserId, 'aa-user-1');
      expect(tx.aaMode, 2);
      expect(tx.aaParticipants, '["aa-user-1","aa-user-2"]');
      expect(tx.aaSplits, '{"aa-user-1":"21","aa-user-2":"21"}');
      final vus = await repo.getByLedger(id);
      expect(
        vus.map((v) => v.id),
        contains(vuId),
        reason: '虚拟用户随账本保留,不得被移动操作清掉',
      );
    });

    test('共享账本禁止转本地(应改用复制到本地)', () async {
      final id = await repo.createLedger(name: '共享本', storageMode: 'cloud');
      await markShared(id);

      await expectLater(
        engine.moveToLocal(id),
        throwsA(isA<CloudSyncException>()),
      );
      expect(provider.deleteLedgerCalls, isEmpty);
      expect((await readLedger(id)).storageMode, 'cloud');
    });

    // 用例 A:个人云端账本转本地,删云端期间到达的自广播 removed 回声必须被
    // 忽略集合拦截,本地账本 + 交易数据完好(个人云端账本移动到本地被误删的
    // 主修复回归)。
    test('转本地期间自广播 removed 回声被忽略集合拦截,本地账本与交易不被删', () async {
      final id = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId!;
      await repo.addTransaction(
        ledgerId: id,
        type: 'expense',
        amount: 880,
        happenedAt: DateTime(2026, 6, 1),
      );

      // 真实路径:启动 WS 监听,让回声走 realtimeEvents → _handleMemberChange。
      engine.startListeningRealtime();

      // 在删云端的瞬间(忽略集合已登记、moveToLocal 尚未进 finally)模拟
      // 服务端向 owner 自己广播的 member_change.removed 回声。
      provider.deleteLedgerSideEffect = () async {
        provider.emitRealtimeEvent(
          SpitoutCloudRealtimeEvent(
            type: 'member_change',
            ledgerId: syncId, // externalId == syncId
            rawData: const {
              'changeType': 'removed',
              'userId': 'test-user-id', // == fake 当前登录用户 → 命中"自己被踢"分支
            },
          ),
        );
        // 等事件被 stream 派发并处理完(此刻集合内仍含 syncId → 应被跳过 purge)。
        await pumpEventQueue();
      };

      await engine.moveToLocal(id);
      engine.stopListeningRealtime();

      // 断言:回声被拦截,本地账本翻 local、断联、交易数据完好。
      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'local');
      expect(ledger.syncId, isNull);
      final txs = await (db.select(
        db.transactions,
      )..where((t) => t.ledgerId.equals(id))).get();
      expect(
        txs,
        hasLength(1),
        reason: '回声若未被拦截,_purgeLocalLedgerByExternalId 会连交易一起删掉',
      );
    });

    // 用例 B:deleteLedger 成功但 detachFromCloud 抛瞬时异常,重试后最终 syncId
    // 清空(落到成功态或 B 态),且绝不抛"保持云端"。
    test('detachFromCloud 瞬时失败,重试后最终清空 syncId 且不抛异常', () async {
      final id = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId;

      // 用可控失败的 repo 包一层:前 N 次 detachFromCloud 抛瞬时异常,之后放行。
      final flakyRepo = _FlakyDetachRepo(repo, failTimes: 2);
      final flakyEngine = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: changeTracker,
        repo: flakyRepo,
      );

      // 不应抛异常。
      await flakyEngine.moveToLocal(id);

      expect(provider.deleteLedgerCalls, contains(syncId));
      expect(
        flakyRepo.detachAttempts,
        greaterThanOrEqualTo(2),
        reason: '瞬时失败应触发重试',
      );
      final ledger = await readLedger(id);
      expect(
        ledger.syncId,
        isNull,
        reason: '重试成功后终态必须清空 syncId,消除被 pull 整本 purge 的风险',
      );
      expect(ledger.storageMode, 'local');
    });

    // 用例 C:deleteLedger 成功但 detachFromCloud 永久失败,且降级两条更新也
    // 全失败 → A 态保留(不静默丢数据),不抛"保持云端"死循环异常。
    test('detachFromCloud 永久失败且降级全失败,保留 A 态且不抛异常', () async {
      final id = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId;

      final deadRepo = _FullyFailingDetachRepo(repo);
      final deadEngine = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: changeTracker,
        repo: deadRepo,
      );

      // 关键:绝不 rethrow"保持云端"——云端已删,重试必 404 死循环。
      await deadEngine.moveToLocal(id);

      expect(provider.deleteLedgerCalls, contains(syncId), reason: '云端确实已删');
      // A 态:数据未被静默丢弃,账本行仍在(storageMode/syncId 保持原值)。
      final ledger = await readLedger(id);
      expect(
        ledger.storageMode,
        'cloud',
        reason: '降级全失败,mode 未能翻 local,账本行仍在(未被 purge)',
      );
      expect(ledger.syncId, syncId, reason: 'syncId 未能清空(A 态危险态,靠日志留痕)');
    });

    // 用例 D:忽略集合泄漏检查——moveToLocal 异常路径(删云端失败)后集合为空,
    // 后续真实 member_change.removed 仍能正常 purge(不被误忽略)。
    test('删云端失败后忽略集合不泄漏,后续真实 removed 仍正常 purge', () async {
      final id = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId!;

      // 第一次 moveToLocal:删云端失败 → 抛异常;finally 必须已清空忽略集合。
      provider.deleteLedgerErrorInjector = () => Exception('server 500');
      await expectLater(
        engine.moveToLocal(id),
        throwsA(isA<CloudSyncException>()),
      );

      // 恢复正常后,模拟一条真实的 member_change.removed(如在 web 端被删/踢)。
      provider.deleteLedgerErrorInjector = null;
      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        SpitoutCloudRealtimeEvent(
          type: 'member_change',
          ledgerId: syncId,
          rawData: const {'changeType': 'removed', 'userId': 'test-user-id'},
        ),
      );
      await pumpEventQueue();
      engine.stopListeningRealtime();

      // 集合未泄漏 → 真实 removed 未被误忽略 → 本地账本被 purge。
      final gone = await (db.select(
        db.ledgers,
      )..where((l) => l.id.equals(id))).getSingleOrNull();
      expect(gone, isNull, reason: '忽略集合若泄漏,真实 removed 会被误跳过,账本残留');
    });

    // 场景 1:快速往返——moveToCloud 后立即 moveToLocal。无 in-flight fullPush,
    // waitFullPushSettle 立即返回,删云端命中「无副本」→ 成功断联无孤儿。
    test('快速往返 moveToCloud→moveToLocal,无孤儿、成功断联', () async {
      provider.autoRegisterWrittenLedgers = true;
      final id = await repo.createLedger(name: '往返本', storageMode: 'local');
      await engine.moveToCloud(id); // 云端优先:已完整推送并确认后翻 cloud
      final syncId = (await readLedger(id)).syncId;
      expect(syncId, isNotNull);

      // 紧接着搬回本地:此刻无 in-flight fullPush,settle 立即返回。
      await engine.moveToLocal(id);

      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'local');
      expect(ledger.syncId, isNull);
      expect(provider.deleteLedgerCalls, contains(syncId));
    });

    // 场景 2:in-flight 中止——fullPush 卡在 writeCreateLedger 时 moveToLocal。
    // abort 信号命中 → settle 后删远端 → fullPush 不重建 S1。
    test('fullPush 卡 writeCreateLedger 时 moveToLocal,中止后不重建 S1', () async {
      final id = await repo.createLedger(name: '卡本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId!;
      await repo.addTransaction(
        ledgerId: id,
        type: 'expense',
        amount: 500,
        happenedAt: DateTime(2026, 7, 1),
      );

      // 让 fullPush 卡在 writeCreateLedger 前,制造 in-flight 窗口。
      final gate = Completer<void>();
      provider.writeCreateLedgerGate = gate;
      final pushFuture = engine.fullPush(ledgerId: id, force: true);
      await pumpEventQueue(); // 让 fullPush 跑到 writeCreateLedger 并卡住

      // 此时发起 moveToLocal:登记 abort → waitFullPushSettle 等 fullPush 收敛。
      final moveFuture = engine.moveToLocal(id);
      await pumpEventQueue();

      // 放行闸门:fullPush 恢复后应在检查点命中 abort 抛 FullPushAborted 并收敛,
      // 不写 S1 快照 / 不 pushChanges。
      gate.complete();
      await pushFuture; // 被中止,正常终结(不 rethrow)
      await moveFuture;

      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'local');
      expect(ledger.syncId, isNull);
      expect(provider.deleteLedgerCalls, contains(syncId));
      expect(
        provider.pushedBatches,
        isEmpty,
        reason: 'fullPush 被中止,不得把交易推成 S1 孤儿',
      );
    });

    // 场景 3:pull 翻回窗口——moveToLocal 期间手动触发 syncLedgersFromServer。
    // 信号驱动方案下,即便 pull 把 server 账本 upsert 进来,abort 信号仍生效、
    // detach 原子断联,账本终态必为 local + syncId=null(旧「先翻 local」方案会
    // 被 pull 翻回 cloud)。
    test('moveToLocal 窗口内触发 pull,终态仍为 local + syncId=null', () async {
      final id = await repo.createLedger(name: '翻回本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId!;
      // server 端存在该账本快照(pull 会读到并尝试 upsert)。
      provider.pushFakeLedger(ledgerId: syncId, ledgerName: '翻回本');

      // 在删云端瞬间(abort 已登记、server 尚含该账本)手动触发一次 pull。
      provider.deleteLedgerSideEffect = () async {
        await engine.syncLedgersFromServer();
      };

      await engine.moveToLocal(id);

      final ledger = await readLedger(id);
      expect(
        ledger.storageMode,
        'local',
        reason: 'abort 信号 + detach 原子断联,终态必为 local',
      );
      expect(ledger.syncId, isNull);
      expect(provider.deleteLedgerCalls, contains(syncId));
    });

    // 场景 5:settle 超时——mock 永不完成的 fullPush → 30s 超时 → moveToLocal
    // 中止,保持 cloud 抛异常,信号清理。
    //
    // 注:真等 30s 会拖慢测试,这里用永不放行的闸门制造「永不 settle 的 in-flight
    // fullPush」,并把 moveToLocal 的超时时长临时收窄靠不住(硬编码 30s)。改为直接
    // 验证「waitFullPushSettle 在 in-flight 未收敛时不会返回、moveToLocal 因超时
    // 抛 CloudSyncException 且删云端未被触碰」——用 timeout 参数限制测试自身时长,
    // 借助真实 30s 超时定时器触发(测试整体上限 40s)。
    test(
      'waitFullPushSettle 超时,保持 cloud 抛异常且信号清理',
      () async {
        final id = await repo.createLedger(name: '超时本', storageMode: 'cloud');
        final syncId = (await readLedger(id)).syncId;

        // 永不放行的闸门 → fullPush 永远卡在 writeCreateLedger → in-flight
        // completer 永不 settle。
        final foreverGate = Completer<void>();
        provider.writeCreateLedgerGate = foreverGate;
        // 不 await(否则永远挂起),仅触发进入 in-flight;错误/挂起交给测试结束回收。
        unawaited(
          engine.fullPush(ledgerId: id, force: true).catchError((_) {}),
        );
        await pumpEventQueue();

        // moveToLocal 应在 30s 后因 waitFullPushSettle 超时抛 CloudSyncException。
        await expectLater(
          engine.moveToLocal(id),
          throwsA(isA<CloudSyncException>()),
        );

        // 超时后:账本保持 cloud、syncId 保留、未删云端(未走到删除步骤)。
        final ledger = await readLedger(id);
        expect(ledger.storageMode, 'cloud');
        expect(ledger.syncId, syncId);
        expect(
          provider.deleteLedgerCalls,
          isEmpty,
          reason: 'settle 超时应在删除前中止,不触碰云端',
        );
        // 放行闸门收尾,让挂起的 fullPush future 有机会收敛,避免 pending timer 警告。
        foreverGate.complete();
        await pumpEventQueue();
      },
      timeout: const Timeout(Duration(seconds: 40)),
    );

    // 场景 6:增量 push 积压窗口——账本有积压 local_changes,moveToLocal 期间
    // 恰好触发增量 push,push 命中 abort 静默跳过 → 云端无孤儿 S1。
    test('moveToLocal 窗口内触发增量 push,命中 abort 静默跳过不写 S1', () async {
      final id = await repo.createLedger(name: '积压本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId!;
      // 造积压 local_changes。
      await repo.addTransaction(
        ledgerId: id,
        type: 'expense',
        amount: 900,
        happenedAt: DateTime(2026, 7, 2),
      );

      // 在删云端的瞬间(abort 信号已登记、尚未 finally)触发一次增量 push,
      // 验证该 push 命中 abort 被静默跳过、不产生 pushChanges 调用。
      provider.deleteLedgerSideEffect = () async {
        // push 接收 String ledgerId(内部 int.tryParse 还原本地 int id)。
        await engine.push(id.toString()); // 增量 push:应命中 abort 静默跳过
      };

      await engine.moveToLocal(id);

      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'local');
      expect(ledger.syncId, isNull);
      expect(provider.deleteLedgerCalls, contains(syncId));
      expect(
        provider.pushedBatches,
        isEmpty,
        reason: '窗口内的增量 push 必须被 abort 静默跳过,不写 S1 孤儿',
      );
    });

    // 场景 7:删远端 404/410(其它设备已删)→ 幂等放行 → 正常 detach,不误报。
    test('删云端命中 404 时幂等放行,正常 detach 断联', () async {
      final id = await repo.createLedger(name: '已删本', storageMode: 'cloud');
      final syncId = (await readLedger(id)).syncId;
      // 模拟其它设备已删除:server 返回 404。
      provider.deleteLedgerErrorInjector = () =>
          Exception('HTTP 404 Not Found');

      // 不应抛异常:404 视为「云端已无副本」幂等放行。
      await engine.moveToLocal(id);

      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'local', reason: '404 = 云端已无副本,应放行并正常断联');
      expect(ledger.syncId, isNull);
      expect(provider.deleteLedgerCalls, contains(syncId));
    });

    test('转本地后清空该账本遗留待推送变更(修复:账户级对账永久报差异)', () async {
      final id = await repo.createLedger(name: '积压本', storageMode: 'cloud');
      // 云端时期登记一条未推送变更(转本地前尚未推送)。
      await repo.addTransaction(
        ledgerId: id,
        type: 'expense',
        amount: 900,
        happenedAt: DateTime(2026, 7, 2),
      );
      expect(
        await changeTracker.getUnpushedChangesForLedger(id),
        isNotEmpty,
        reason: '前置:转本地前应有未推送变更',
      );

      await engine.moveToLocal(id);

      final ledger = await readLedger(id);
      expect(ledger.storageMode, 'local');
      expect(ledger.syncId, isNull);
      expect(
        await changeTracker.getUnpushedChangesForLedger(id),
        isEmpty,
        reason: '转本地后遗留变更不再推送,必须清空,否则账户级对账永久报差异',
      );
    });
  });

  group('copyToLocal', () {
    test('保留云端账本,新建本地副本并完整拷贝交易与编辑历史', () async {
      final srcId = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final txId = await repo.addTransaction(
        ledgerId: srcId,
        type: 'expense',
        amount: 1000,
        happenedAt: DateTime(2026, 5, 1),
        note: '早餐',
      );
      await repo.addTransaction(
        ledgerId: srcId,
        type: 'income',
        amount: 10000,
        happenedAt: DateTime(2026, 5, 2),
      );
      // 造一条编辑历史,验证副本连审计轨迹一起搬。
      await db
          .into(db.recordEditHistories)
          .insert(
            RecordEditHistoriesCompanion.insert(
              recordId: txId,
              version: 2,
              summary: '金额 10 → 12',
            ),
          );

      final newId = await engine.copyToLocal(srcId);

      final copy = await readLedger(newId);
      expect(copy.storageMode, 'local');
      expect(copy.syncId, isNull, reason: '本地副本不参与同步,不应持有 syncId');
      expect(copy.isShared, isFalse);
      expect(copy.name, contains('副本'));

      final copiedTxs = await (db.select(
        db.transactions,
      )..where((t) => t.ledgerId.equals(newId))).get();
      expect(copiedTxs, hasLength(2));
      final srcTxs = await (db.select(
        db.transactions,
      )..where((t) => t.ledgerId.equals(srcId))).get();
      expect(srcTxs, hasLength(2), reason: '复制不得动源账本数据');
      expect(
        copiedTxs.map((t) => t.syncId).toSet()
          ..removeAll(srcTxs.map((t) => t.syncId)),
        hasLength(2),
        reason: '副本交易必须是全新 syncId,否则会跟云端原件撞车',
      );

      final copiedHist =
          await (db.select(db.recordEditHistories)..where(
                (h) => h.recordId.equals(
                  copiedTxs.firstWhere((t) => t.note == '早餐').id,
                ),
              ))
              .get();
      expect(copiedHist, hasLength(1));
      expect(copiedHist.single.summary, '金额 10 → 12');

      // 源账本保持云端不变。
      expect((await readLedger(srcId)).storageMode, 'cloud');
      expect(provider.deleteLedgerCalls, isEmpty);
    });

    // AA 保留:副本必须继承源账本的 AA 开关、交易 AA 字段与虚拟用户,否则
    // "云端开 AA → 复制到本地" 会出现开关悄悄关闭 + 分摊数据丢失的语义漂移。
    test('复制到本地时副本保留 AA 开关/交易字段/虚拟用户', () async {
      final srcId = await repo.createLedger(
        name: 'AA云端本',
        storageMode: 'cloud',
        aaEnabled: true,
      );
      await repo.addTransaction(
        ledgerId: srcId,
        type: 'expense',
        amount: 6000,
        happenedAt: DateTime(2026, 5, 4),
        paidByUserId: 'aa-user-1',
        aaMode: 2,
        aaParticipants: '["aa-user-1","aa-user-2"]',
        aaSplits: '{"aa-user-1":"30","aa-user-2":"30"}',
      );
      await repo.create(ledgerId: srcId, name: '虚拟室友');

      final newId = await engine.copyToLocal(srcId);

      final copy = await readLedger(newId);
      expect(copy.aaEnabled, isTrue, reason: '副本必须继承源账本的 AA 开关,不能悄悄关掉');
      final copiedTx = await (db.select(
        db.transactions,
      )..where((t) => t.ledgerId.equals(newId))).getSingle();
      expect(copiedTx.paidByUserId, 'aa-user-1');
      expect(copiedTx.aaMode, 2);
      expect(copiedTx.aaParticipants, '["aa-user-1","aa-user-2"]');
      expect(copiedTx.aaSplits, '{"aa-user-1":"30","aa-user-2":"30"}');
      // 副本虚拟用户必须是独立新行(新 id),但名称要随副本迁移过来。
      final copiedVus = await repo.getByLedger(newId);
      expect(copiedVus, hasLength(1));
      expect(
        copiedVus.single.name,
        '虚拟室友',
        reason: '虚拟用户必须随副本迁移,否则 AA 分摊结果会缺参与者',
      );
      expect(copiedVus.single.id, isNot(isNull));
      // 源账本 AA 数据保持不动。
      final srcTx = await (db.select(
        db.transactions,
      )..where((t) => t.ledgerId.equals(srcId))).getSingle();
      expect(srcTx.aaMode, 2);
      expect((await readLedger(srcId)).aaEnabled, isTrue);
    });

    test('复制到本地时交易中的虚拟用户 syncId 引用被重写', () async {
      final srcId = await repo.createLedger(
        name: 'AA虚拟用户本',
        storageMode: 'cloud',
        aaEnabled: true,
      );
      await repo.create(ledgerId: srcId, name: '虚拟室友');
      final srcVu = (await repo.getByLedger(srcId)).single;
      final srcVuSyncId = srcVu.syncId!;
      await repo.addTransaction(
        ledgerId: srcId,
        type: 'expense',
        amount: 6000,
        happenedAt: DateTime(2026, 5, 4),
        paidByUserId: srcVuSyncId,
        aaMode: 2,
        aaParticipants: jsonEncode([srcVuSyncId]),
        aaSplits: jsonEncode({srcVuSyncId: '60.00'}),
      );

      final newId = await engine.copyToLocal(srcId);

      // 副本虚拟用户是新 UUID,交易里的 AA 引用必须一并指向它,而不是源账本旧 id。
      final copiedVu = (await repo.getByLedger(newId)).single;
      final copiedVuSyncId = copiedVu.syncId!;
      expect(copiedVuSyncId, isNot(srcVuSyncId));
      final copiedTx = await (db.select(
        db.transactions,
      )..where((t) => t.ledgerId.equals(newId))).getSingle();
      expect(copiedTx.paidByUserId, copiedVuSyncId);
      expect(copiedTx.aaParticipants, jsonEncode([copiedVuSyncId]));
      expect(copiedTx.aaSplits, jsonEncode({copiedVuSyncId: '60.00'}));
      expect(copiedTx.aaParticipants, isNot(contains(srcVuSyncId)));
      expect(copiedTx.aaSplits, isNot(contains(srcVuSyncId)));
    });

    test('复制出的本地副本后续变更被闸门拦截,不进 local_changes', () async {
      final srcId = await repo.createLedger(name: '云端本', storageMode: 'cloud');
      final newId = await engine.copyToLocal(srcId);

      await changeTracker.recordLedgerChange(
        ledgerId: newId,
        entityType: 'transaction',
        action: 'upsert',
        entityId: 1,
        entitySyncId: 'tx-after-copy',
      );

      expect(await changeTracker.getUnpushedChangesForLedger(newId), isEmpty);
    });

    test('本地账本禁止复制到本地', () async {
      final id = await repo.createLedger(name: '本地本', storageMode: 'local');

      await expectLater(
        engine.copyToLocal(id),
        throwsA(isA<CloudSyncException>()),
      );
    });

    test('源账本不存在时抛异常', () async {
      await expectLater(
        engine.copyToLocal(9999),
        throwsA(isA<CloudSyncException>()),
      );
    });
  });
}

/// 测试替身:detachFromCloud 前 [failTimes] 次抛瞬时异常,之后委托真实 repo。
///
/// 用于用例 B 验证「SQLite busy/locked 瞬时锁 → 短重试 → 最终成功」路径。
/// 其余所有方法经 noSuchMethod 透传给真实 [LocalRepository],不改变行为。
class _FlakyDetachRepo implements LocalRepository {
  _FlakyDetachRepo(this._real, {required this.failTimes});

  final LocalRepository _real;
  final int failTimes;
  int detachAttempts = 0;

  @override
  Future<void> detachFromCloud(int id) async {
    detachAttempts++;
    if (detachAttempts <= failTimes) {
      throw Exception('injected transient detach failure #$detachAttempts');
    }
    return _real.detachFromCloud(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _real.noSuchMethod(invocation);
}

/// 测试替身:detachFromCloud 与降级用的两条 update 全部永久抛异常。
///
/// 用于用例 C 验证「降级全失败 → 保留 A 态、不静默丢数据、不抛保持云端异常」。
class _FullyFailingDetachRepo implements LocalRepository {
  _FullyFailingDetachRepo(this._real);

  final LocalRepository _real;

  @override
  Future<void> detachFromCloud(int id) async {
    throw Exception('injected permanent detach failure');
  }

  @override
  Future<void> updateLedgerSyncId({required int id, String? syncId}) async {
    throw Exception('injected permanent updateLedgerSyncId failure');
  }

  @override
  Future<void> updateLedgerStorageMode({
    required int id,
    required String storageMode,
  }) async {
    throw Exception('injected permanent updateLedgerStorageMode failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _real.noSuchMethod(invocation);
}

/// 测试替身:updateLedgerStorageMode 抛异常,其余透传真实 repo。
///
/// 用于 moveToCloud 场景 8 验证「翻 mode 失败 → 抛 CloudSyncException、保持 local」。
/// updateLedgerSyncId 走真实 repo(补 syncId 成功),让失败精确落在翻 mode 一步。
class _FailStorageModeRepo implements LocalRepository {
  _FailStorageModeRepo(this._real);

  final LocalRepository _real;

  @override
  Future<void> updateLedgerSyncId({required int id, String? syncId}) =>
      _real.updateLedgerSyncId(id: id, syncId: syncId);

  @override
  Future<void> updateLedgerStorageMode({
    required int id,
    required String storageMode,
  }) async {
    throw Exception('injected updateLedgerStorageMode failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _real.noSuchMethod(invocation);
}
