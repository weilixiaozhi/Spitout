import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';

/// [leaveAndDeleteSharedLedgerProvider] 与 [deleteSharedLedgerAsOwnerProvider]
/// 的集成测试（cloud-first 编排）。
///
/// 设计意图：这两个 provider 是本次修复的"业务入口"，串联「先云端操作
/// （退出/删除）→ 再本地 purge → 失效相关缓存」。测试用真实的
/// [SyncEngine] + 真实 [LocalRepository] + 测试桩 [FakeSpitoutCloudProvider]
/// 跑完整链路，断言：
///   1) 云端方法确实被调用（协作者走 leaveLedger / Owner 走 deleteLedger）；
///   2) 本地账本及其交易被 purge 干净（幽灵账本不再复活）；
///   3) 缓存失效调用不抛错。
///
/// 说明：两个 provider 是顶层异步函数（签名为 (WidgetRef, {ledgerId})），
/// 需要一个真正的 [WidgetRef]。这里用一个 [Consumer] 在 build 时把真实
/// `ref` 通过 [Completer] 交回测试体，随后直接 `await` 调用 provider 函数——
/// 这样任何异常都会立即冒泡为测试失败，而不是被 widget 的 onPressed 吞掉
/// 导致 Completer 永不完成而挂起。
void main() {
  Future<_Harness> harness() async {
    resetGlobalTestState();
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    final fake = FakeSpitoutCloudProvider();
    final engine =
        SyncEngine(db: db, provider: fake, changeTracker: tracker, repo: repo);
    final container = ProviderContainer(overrides: [
      spitoutCloudProviderInstance.overrideWith((ref) async => fake),
      syncEngineProvider.overrideWith((ref, arg) => engine),
      currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(null)),
    ]);
    return _Harness(db, repo, fake, container);
  }

  Future<int> seedSharedLedger(SpitoutDatabase db, String extId, String myRole) async {
    final localId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Shared-$extId',
            syncId: Value(extId),
            isShared: const Value(true),
            myRole: Value(myRole),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: localId,
            type: 'expense',
            amount: 1000,
            syncId: Value('tx-$extId'),
          ),
        );
    await db.into(db.localChanges).insert(
          LocalChangesCompanion.insert(
            entityType: 'ledger',
            entityId: localId,
            entitySyncId: extId,
            ledgerId: localId,
            action: 'delete',
          ),
        );
    return localId;
  }

  Future<bool> ledgerExists(SpitoutDatabase db, String extId) async =>
      (await (db.select(db.ledgers)..where((l) => l.syncId.equals(extId))).get())
          .isNotEmpty;

  /// 通过 Consumer 在 build 阶段取回真实 WidgetRef。
  Future<WidgetRef> captureRef(WidgetTester tester, ProviderContainer container) async {
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

  testWidgets('协作者退出并删除：先 leaveLedger，再本地 purge，且不残留删除标记',
      (tester) async {
    final h = await harness();
    final localId = await seedSharedLedger(h.db, 'ext-1', 'editor');
    final ref = await captureRef(tester, h.container);

    // 直接调用 provider 函数；异常会立即冒泡，不会挂起。
    await leaveAndDeleteSharedLedgerProvider(ref, ledgerId: 'ext-1');

    // syncLedgersFromServer 内部经 LoggerService 写入日志会调度一个 2 秒
    // debounce 定时器；推进时间让其触发，避免测试结束时遗留 pending timer。
    await tester.pump(const Duration(seconds: 3));

    // 1) 云端退出接口被调用
    expect(h.fake.leaveLedgerCalls, contains('ext-1'));
    // 2) 本地账本被 purge
    expect(await ledgerExists(h.db, 'ext-1'), isFalse);
    // 3) 交易被清掉
    expect(
      await (h.db.select(h.db.transactions)
            ..where((t) => t.ledgerId.equals(localId)))
          .get(),
      isEmpty,
    );
    // 4) 关键：删除标记被清掉（否则 sync 会重新 upsert 回来）
    expect(
      await (h.db.select(h.db.localChanges)
            ..where((c) => c.entityType.equals('ledger'))
            ..where((c) => c.entityId.equals(localId)))
          .get(),
      isEmpty,
    );

    h.container.dispose();
    h.db.close();
  });

  testWidgets('Owner 删除共享账本：先 deleteLedger，再本地 purge', (tester) async {
    final h = await harness();
    final localId = await seedSharedLedger(h.db, 'ext-1', 'owner');
    final ref = await captureRef(tester, h.container);

    await deleteSharedLedgerAsOwnerProvider(ref, ledgerId: 'ext-1');

    // 同上：让 LoggerService 的 debounce 定时器触发，避免遗留 pending timer。
    await tester.pump(const Duration(seconds: 3));

    // 1) 云端删除接口被调用
    expect(h.fake.deleteLedgerCalls, contains('ext-1'));
    // 2) 本地账本被 purge
    expect(await ledgerExists(h.db, 'ext-1'), isFalse);
    expect(
      await (h.db.select(h.db.transactions)
            ..where((t) => t.ledgerId.equals(localId)))
          .get(),
      isEmpty,
    );

    h.container.dispose();
    h.db.close();
  });
}

class _Harness {
  _Harness(this.db, this.repo, this.fake, this.container);

  final SpitoutDatabase db;
  final LocalRepository repo;
  final FakeSpitoutCloudProvider fake;
  final ProviderContainer container;
}
