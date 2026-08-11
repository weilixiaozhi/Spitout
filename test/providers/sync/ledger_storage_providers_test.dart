// 账本归属操作（本地 ↔ Spitout Cloud）的 provider 层测试。
//
// 覆盖 ledger_storage_providers.dart 的四个对外入口：
//   1. moveLedgerToCloudProvider：未登录抛可读异常；登录后身份迁移 + moveToCloud + 刷新；
//   2. moveLedgerToLocalProvider：云端账本完整迁回本地（删云端 + 原子断联）；
//   3. copyLedgerToLocalProvider：云端账本复制本地副本（云端保留）；
//   4. migrateLocalIdentityAfterLoginWithContainer：登录后云端账本 localSelfId → 云 userId、
//      本地账本收敛为 localSelfId，未登录 / 无 userId / 异常均不阻断。
// 使用真实 SQLite + 真实 SyncEngine + FakeSpitoutCloudProvider 断言真实副作用。
// WidgetRef 通过 Consumer 在 build 阶段捕获（与 shared_ledger_providers_test 同模式）。

import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ChangeTracker changeTracker;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;

  setUp(() {
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

  tearDown(() async {
    // 兜底取消 moveToCloud 调度的 2s auto sync 定时器。
    engine.dispose();
    await db.close();
  });

  ProviderContainer buildContainer({
    bool cloudReady = true,
    String localSelfId = 'local-self-id',
  }) {
    final backend = cloudReady ? provider : null;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        syncEngineProvider.overrideWith((ref, arg) => engine),
        spitoutCloudProviderInstance.overrideWith((ref) async => backend),
        localSelfIdProvider.overrideWith(
          (ref) async => localSelfId,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 通过 Consumer 在 build 阶段取回真实 WidgetRef。
  Future<WidgetRef> captureRef(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    final refCompleter = Completer<WidgetRef>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            if (!refCompleter.isCompleted) refCompleter.complete(ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return refCompleter.future;
  }

  /// 推进时间让 LoggerService 的 2s 日志保存定时器等落定，避免 pending timer。
  Future<void> flushTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
  }

  Future<int> createLedger(String name, String storageMode) async {
    return repo.createLedger(name: name, storageMode: storageMode);
  }

  /// 把账本内交易与账本行标记为 localSelfId 作者（模拟未登录本地数据）。
  Future<void> markLocalSelfAuthors(int ledgerId) async {
    await db.customUpdate(
      'UPDATE transactions SET paid_by_user_id = ?1, created_by_user_id = ?1, '
      'last_edited_by_user_id = ?1 WHERE ledger_id = ?2',
      variables: [Variable<String>('local-self-id'), Variable<int>(ledgerId)],
      updates: {db.transactions},
    );
    await db.customUpdate(
      'UPDATE ledgers SET owner_user_id = ?1 WHERE id = ?2',
      variables: [Variable<String>('local-self-id'), Variable<int>(ledgerId)],
      updates: {db.ledgers},
    );
  }

  Future<void> addTx(int ledgerId) async {
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1000,
      happenedAt: DateTime(2026, 7, 1),
    );
  }

  group('moveLedgerToCloudProvider', () {
    testWidgets('未登录（cloud 未就绪）→ 抛可读异常，账本保持本地', (tester) async {
      final id = await createLedger('本地账本', 'local');
      final container = buildContainer(cloudReady: false);
      final ref = await captureRef(tester, container);

      await expectLater(
        moveLedgerToCloudProvider(ref, ledgerId: id),
        throwsA(
          isA<CloudSyncException>().having(
            (e) => e.message,
            'message',
            contains('请先登录'),
          ),
        ),
      );
      final ledger = await repo.getLedgerById(id);
      expect(ledger!.storageMode, 'local');
      await flushTimers(tester);
    });

    testWidgets('登录后：身份迁移 + 云端优先推送 + 翻 cloud', (tester) async {
      // 模拟真实 server：建本成功即出现在清单里，统一 GC 才不会把
      // 刚翻 cloud 的账本当残留清掉。
      provider.autoRegisterWrittenLedgers = true;
      final id = await createLedger('本地账本', 'local');
      await addTx(id);
      await markLocalSelfAuthors(id);
      final container = buildContainer();
      final ref = await captureRef(tester, container);

      await moveLedgerToCloudProvider(ref, ledgerId: id);

      final ledger = await repo.getLedgerById(id);
      expect(ledger!.storageMode, 'cloud');
      expect(ledger.syncId, isNotNull);
      // 身份迁移：localSelfId 引用改写成云 userId
      final tx = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(id)))
          .getSingle();
      expect(tx.paidByUserId, 'test-user-id');
      expect(tx.createdByUserId, 'test-user-id');
      expect(ledger.ownerUserId, 'test-user-id');
      expect(
        provider.writeCreateLedgerCalls.single.ledgerId,
        ledger.syncId,
        reason: '云端优先转云端必须用同一个 syncId 建云端账本',
      );
      // 云端优先：fullPush 已推全量数据，本地不再登记 create/upsert 变更。
      final unpushed = await changeTracker.getUnpushedChangesForLedger(id);
      expect(unpushed, isEmpty,
          reason: '云端已建，本地不得再登记未推送变更');

      // 推进时间让 LoggerService 的日志保存定时器落定，避免 pending timer；
      // 同时确认统一 GC 不会把已上云的账本误删。
      await flushTimers(tester);
      expect(await repo.getLedgerById(id), isNotNull,
          reason: '云端已确认存在，列表 GC 不得删除该账本');
    });
  });

  group('moveLedgerToLocalProvider', () {
    testWidgets('云端账本迁回本地：删云端 + 断联 + 数据保留', (tester) async {
      final id = await createLedger('云端账本', 'cloud');
      final syncId = (await repo.getLedgerById(id))!.syncId!;
      await addTx(id);
      final container = buildContainer();
      final ref = await captureRef(tester, container);

      await moveLedgerToLocalProvider(ref, ledgerId: id);

      final ledger = await repo.getLedgerById(id);
      expect(ledger!.storageMode, 'local');
      expect(ledger.syncId, isNull, reason: '断联后 syncId 必须清空');
      expect(provider.deleteLedgerCalls, contains(syncId));
      final txs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(id)))
          .get();
      expect(txs, hasLength(1), reason: '迁回本地不得丢数据');
      await flushTimers(tester);
    });
  });

  group('copyLedgerToLocalProvider', () {
    testWidgets('云端账本复制本地副本：云端保留，副本完整', (tester) async {
      final id = await createLedger('云端账本', 'cloud');
      await addTx(id);
      final container = buildContainer();
      final ref = await captureRef(tester, container);

      final newId = await copyLedgerToLocalProvider(ref, ledgerId: id);

      expect(newId, isNot(id));
      final src = await repo.getLedgerById(id);
      expect(src!.storageMode, 'cloud', reason: '云端原件必须保留');
      final copy = await repo.getLedgerById(newId);
      expect(copy!.storageMode, 'local');
      expect(copy.syncId, isNull);
      expect(copy.name, contains('副本'));
      final copyTxs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(newId)))
          .get();
      expect(copyTxs, hasLength(1));
      await flushTimers(tester);
    });
  });

  group('createCloudLedgerFromUi（云端优先新建）', () {
    testWidgets('成功：先建云端再落本地绑定行，不登记未推送变更', (tester) async {
      provider.autoRegisterWrittenLedgers = true;
      final container = buildContainer();

      final id = await createCloudLedgerFromUi(
        container,
        name: '云端账本',
        currency: 'CNY',
        ownerUserId: 'local-self-id',
        aaEnabled: false,
      );

      expect(provider.writeCreateLedgerCalls, hasLength(1));
      final ledger = await repo.getLedgerById(id);
      expect(ledger!.storageMode, 'cloud');
      expect(
        ledger.syncId,
        provider.writeCreateLedgerCalls.single.ledgerId,
        reason: '本地行必须绑定云端创建使用的同一个 syncId',
      );
      final unpushed = await changeTracker.getUnpushedChangesForLedger(id);
      expect(unpushed, isEmpty, reason: '云端已建，本地不得再登记 create 变更');
      await flushTimers(tester);
    });

    testWidgets('aaEnabled=true + monthStartDay≠1 随建本请求落到服务端，对账后不回滚', (tester) async {
      provider.autoRegisterWrittenLedgers = true;
      final container = buildContainer();

      final id = await createCloudLedgerFromUi(
        container,
        name: 'AA账本',
        currency: 'CNY',
        ownerUserId: 'local-self-id',
        aaEnabled: true,
        monthStartDay: 15,
      );

      // 本地绑定行必须保留用户选择的开关与月起始日
      final ledger = await repo.getLedgerById(id);
      expect(ledger!.aaEnabled, isTrue);
      expect(ledger.monthStartDay, 15);

      // 服务端 canonical 状态必须与本地一致，否则下次 syncLedgersFromServer 对账会回滚
      final serverLedgers = await provider.readLedgers();
      expect(serverLedgers.single.aaEnabled, isTrue);
      expect(serverLedgers.single.monthStartDay, 15);

      // 模拟下一次对账：拉取服务端清单后本地值不得被默认值覆盖
      await engine.syncLedgersFromServer();
      final after = await repo.getLedgerById(id);
      expect(after!.aaEnabled, isTrue);
      expect(after.monthStartDay, 15);
      await flushTimers(tester);
    });

    testWidgets('云端创建失败 → 抛错且本地不落账本', (tester) async {
      provider.writeCreateLedgerErrorInjector = () => Exception('cloud boom');
      final container = buildContainer();

      await expectLater(
        createCloudLedgerFromUi(
          container,
          name: '失败账本',
          ownerUserId: 'local-self-id',
        ),
        throwsA(isA<Exception>()),
      );

      expect(
        await repo.getAllLedgers(),
        isEmpty,
        reason: '云端失败时不得在本地留下孤儿云端账本',
      );
      await flushTimers(tester);
    });

    testWidgets('云端创建超时 → 抛超时且本地不落账本', (tester) async {
      final gate = Completer<void>();
      provider.writeCreateLedgerGate = gate;
      final container = buildContainer();

      // 不能直接 await：fake async 下超时计时器需要 pump 推进才会触发。
      final future = createCloudLedgerFromUi(
        container,
        name: '超时账本',
        ownerUserId: 'local-self-id',
        timeout: const Duration(milliseconds: 50),
      );
      // 先挂上断言再推进计时器，避免 future 提前以 error 完成变成未捕获异常。
      final expectation = expectLater(
        future,
        throwsA(isA<TimeoutException>()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectation;
      expect(await repo.getAllLedgers(), isEmpty);

      // 放行闸门，避免未完成的 future 影响测试退出。
      gate.complete();
      await flushTimers(tester);
    });
  });

  group('migrateLocalIdentityAfterLoginWithContainer', () {
    testWidgets('登录后：云端账本收敛为云 userId，本地账本收敛为 localSelfId', (tester) async {
      final localId = await createLedger('本地账本', 'local');
      await addTx(localId);
      await markLocalSelfAuthors(localId);
      // 模拟历史混存：本地账本交易里混入云 userId。
      await db.customUpdate(
        'UPDATE transactions SET paid_by_user_id = ?1 WHERE ledger_id = ?2',
        variables: [Variable<String>('test-user-id'), Variable<int>(localId)],
        updates: {db.transactions},
      );

      final cloudId = await createLedger('云端账本', 'cloud');
      await addTx(cloudId);
      await markLocalSelfAuthors(cloudId);
      final container = buildContainer();

      await migrateLocalIdentityAfterLoginWithContainer(container);

      final localTx = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(localId)))
          .getSingle();
      expect(localTx.paidByUserId, 'local-self-id',
          reason: '本地账本混入的云 userId 必须收敛回本地身份');
      expect(localTx.createdByUserId, 'local-self-id');
      expect(localTx.lastEditedByUserId, 'local-self-id');
      final localLedger = await repo.getLedgerById(localId);
      expect(localLedger!.ownerUserId, 'local-self-id');

      final cloudTx = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(cloudId)))
          .getSingle();
      expect(cloudTx.paidByUserId, 'test-user-id');
      expect(cloudTx.createdByUserId, 'test-user-id');
      expect(cloudTx.lastEditedByUserId, 'test-user-id');
      final cloudLedger = await repo.getLedgerById(cloudId);
      expect(cloudLedger!.ownerUserId, 'test-user-id');

      // 幂等：再跑一次不报错、不改变结果。
      await migrateLocalIdentityAfterLoginWithContainer(container);
      await flushTimers(tester);
    });

    testWidgets('cloud 未就绪 → 无操作不抛异常', (tester) async {
      final id = await createLedger('本地账本', 'local');
      await addTx(id);
      await markLocalSelfAuthors(id);
      final container = buildContainer(cloudReady: false);

      await migrateLocalIdentityAfterLoginWithContainer(container);

      final tx = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(id)))
          .getSingle();
      expect(tx.paidByUserId, 'local-self-id', reason: '未登录不得迁移');
      await flushTimers(tester);
    });

    testWidgets('localSelfId 与云 userId 相同 → 跳过迁移', (tester) async {
      final id = await createLedger('本地账本', 'local');
      await addTx(id);
      // 本地身份恰好等于云 userId（理论上同一套身份体系）：无需迁移，
      // 数据库不应发生任何改写。
      final container = buildContainer(localSelfId: 'test-user-id');

      await migrateLocalIdentityAfterLoginWithContainer(container);
      final tx = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(id)))
          .getSingle();
      expect(tx.paidByUserId, isNull, reason: '本地身份即云身份，不应触发任何改写');
      await flushTimers(tester);
    });
  });
}
