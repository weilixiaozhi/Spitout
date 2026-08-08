// 账本归属操作（本地 ↔ Spitout Cloud）的 provider 层测试。
//
// 覆盖 ledger_storage_providers.dart 的四个对外入口：
//   1. moveLedgerToCloudProvider：未登录抛可读异常；登录后身份迁移 + moveToCloud + 刷新；
//   2. moveLedgerToLocalProvider：云端账本完整迁回本地（删云端 + 原子断联）；
//   3. copyLedgerToLocalProvider：云端账本复制本地副本（云端保留）；
//   4. migrateLocalIdentityAfterLoginWithContainer：登录后全库 localSelfId → 云 userId，
//      幂等标记、未登录 / 无 userId / 异常均不阻断。
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

    testWidgets('登录后：身份迁移 + 秒级翻 cloud + 登记增量推送', (tester) async {
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
      // 已登记 ledger:upsert 到 local_changes，供后续增量推送
      final unpushed = await changeTracker.getUnpushedChangesForLedger(id);
      expect(unpushed, isNotEmpty);

      // moveToCloud 调度的 2s auto sync 定时器：推进时间让其触发；
      // 再推进一轮，让同步日志触发的 LoggerService 2s 保存定时器也落定，避免 pending timer。
      await flushTimers(tester);
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

  group('migrateLocalIdentityAfterLoginWithContainer', () {
    testWidgets('登录后全库 localSelfId → 云 userId，并写幂等标记', (tester) async {
      final id = await createLedger('本地账本', 'local');
      await addTx(id);
      await markLocalSelfAuthors(id);
      final container = buildContainer();

      await migrateLocalIdentityAfterLoginWithContainer(container);

      final tx = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(id)))
          .getSingle();
      expect(tx.paidByUserId, 'test-user-id');
      expect(tx.createdByUserId, 'test-user-id');
      expect(tx.lastEditedByUserId, 'test-user-id');
      final ledger = await repo.getLedgerById(id);
      expect(ledger!.ownerUserId, 'test-user-id');

      // 幂等：再跑一次不报错（prefs 标记命中）
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
