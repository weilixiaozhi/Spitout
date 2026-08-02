import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';

import '../../helpers/test_isolation.dart';

/// Surface 2 [purgeLocalCloudLedgersProvider] 集成测试。
///
/// 设计意图：该 provider 是「云端主动失活（退出登录 / 切回本地 / 清 active
/// 配置）」的统一入口，串联「repo.purgeAllCloudLedgers() 批量清 →
/// selectFirstLedger 重指当前账本 → 失效相关缓存」。用真实
/// [LocalRepository] + 内存库跑完整链路，断言：
///   1) 云端账本（storage_mode='cloud'）与共享账本（含交易）被清干净；
///   2) 纯本地账本（storage_mode='local'）不被误伤 —— 归属模型的核心承诺；
///   3) 当前账本指向被清的账本时，自动重指到第一个可用账本；
///   4) 失效缓存的调用不抛错（异常被内部捕获，不打断登出主流程）。
void main() {
  Future<_Harness> harness() async {
    resetGlobalTestState();
    SharedPreferences.setMockInitialValues({});
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    final container = ProviderContainer(overrides: [
      // 仓库端口直接注入测试内存库实例（架构规则 #3：抽象端口注入）
      repositoryProvider.overrideWithValue(repo),
    ]);
    return _Harness(db, repo, container);
  }

  Future<int> seedSharedLedger(SpitoutDatabase db, String extId) async {
    final localId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Shared-$extId',
            syncId: Value(extId),
            storageMode: const Value('cloud'),
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

  /// 纯本地账本：退出登录后必须原样保留。
  Future<int> seedPersonalLedger(SpitoutDatabase db) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Personal',
            syncId: const Value.absent(),
            storageMode: const Value('local'),
            isShared: const Value(false),
          ),
        );
  }

  /// 个人云端账本：非共享，但归属云账号，退出登录同样要清。
  Future<int> seedCloudLedger(SpitoutDatabase db, String extId) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Cloud-$extId',
            syncId: Value(extId),
            storageMode: const Value('cloud'),
            isShared: const Value(false),
          ),
        );
  }

  /// 通过 Consumer 在 build 阶段取回真实 WidgetRef（既有测试模式）。
  Future<WidgetRef> captureRef(
      WidgetTester tester, ProviderContainer container) async {
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

  testWidgets('登出后全量清云端账本：本地账本残留，当前账本重指到本地账本',
      (tester) async {
    final h = await harness();
    final shared1 = await seedSharedLedger(h.db, 'ext-1');
    final shared2 = await seedSharedLedger(h.db, 'ext-2');
    final cloudOwn = await seedCloudLedger(h.db, 'ext-3');
    final personal = await seedPersonalLedger(h.db);
    // 模拟用户当前正停在共享账本上——purge 后必须重指
    h.container.read(currentLedgerIdProvider.notifier).state = shared1;
    final ref = await captureRef(tester, h.container);

    await purgeLocalCloudLedgersProvider(ref);

    // LoggerService 的 debounce 定时器：推进时间避免遗留 pending timer
    await tester.pump(const Duration(seconds: 3));

    // 1) 共享账本 + 个人云端账本（含交易）全清，只剩纯本地账本
    final remaining = await h.db.select(h.db.ledgers).get();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, personal);
    expect(remaining.single.storageMode, 'local');
    expect(
      await (h.db.select(h.db.transactions)
            ..where((t) => t.ledgerId.isIn([shared1, shared2, cloudOwn])))
          .get(),
      isEmpty,
    );
    // 2) 当前账本已重指到唯一残留的本地账本
    expect(h.container.read(currentLedgerIdProvider), personal);

    h.container.dispose();
    await h.db.close();
  });

  testWidgets('无云端账本时幂等：不抛错、当前选中不被打扰', (tester) async {
    final h = await harness();
    final personal = await seedPersonalLedger(h.db);
    h.container.read(currentLedgerIdProvider.notifier).state = personal;
    final ref = await captureRef(tester, h.container);

    // 连调两次验证幂等；任何异常都会冒泡为测试失败
    await purgeLocalCloudLedgersProvider(ref);
    await purgeLocalCloudLedgersProvider(ref);

    await tester.pump(const Duration(seconds: 3));

    expect(await h.db.select(h.db.ledgers).get(), hasLength(1));
    // 个人账本仍存在且选中未变（selectFirstLedger 幂等保护）
    expect(h.container.read(currentLedgerIdProvider), personal);

    h.container.dispose();
    await h.db.close();
  });

  test('purgeLocalCloudLedgersWithContainer 与 WidgetRef 版行为一致:无需 WidgetRef 即可清云端账本',
      () async {
    final h = await harness();
    final shared1 = await seedSharedLedger(h.db, 'ext-1');
    final cloudOwn = await seedCloudLedger(h.db, 'ext-3');
    final personal = await seedPersonalLedger(h.db);
    h.container.read(currentLedgerIdProvider.notifier).state = shared1;

    // 关键:直接传入 ProviderContainer(无 WidgetRef、无 mounted 守卫),证明页面
    // 销毁后也能完成清理(修复"退出页面跳过 purge"的核心机制,对应方案 H)。
    await purgeLocalCloudLedgersWithContainer(h.container);

    final remaining = await h.db.select(h.db.ledgers).get();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, personal);
    expect(
      await (h.db.select(h.db.transactions)
            ..where((t) => t.ledgerId.isIn([shared1, cloudOwn])))
          .get(),
      isEmpty,
    );
    // 当前账本重指到唯一残留的本地账本
    expect(h.container.read(currentLedgerIdProvider), personal);

    h.container.dispose();
    await h.db.close();
  });

  group('purge 结果可见化(独立2:异常不再静默吞掉)', () {
    test('purge 失败返回 false,不再静默吞掉异常', () async {
      resetGlobalTestState();
      SharedPreferences.setMockInitialValues({});
      // 用「仅 purgeAllCloudLedgers 抛错」的 repo 子类注入失败场景:
      // 关闭 db 不是可靠注入方式(drift 对已关闭的内存库查询不抛错),
      // 子类重写单点更精确、也完全避开网络/时序因素。
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _FailingPurgeLocalRepository(
        db,
        changeTracker: ChangeTracker(db),
      );
      final container = ProviderContainer(overrides: [
        repositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final ok = await purgeLocalCloudLedgersWithContainer(container);
      expect(ok, isFalse,
          reason: 'purge 失败必须返回 false,调用方才能提示「云端账本清理失败」'
              ',而不是静默吞掉异常让用户误以为清理成功');
    });

    test('purge 成功返回 true(回归保护:返回值不得恒为 false)', () async {
      final h = await harness();
      final shared1 = await seedSharedLedger(h.db, 'ext-1');
      h.container.read(currentLedgerIdProvider.notifier).state = shared1;

      final ok = await purgeLocalCloudLedgersWithContainer(h.container);
      expect(ok, isTrue, reason: 'purge 成功必须返回 true');

      // 云端账本确实被清掉
      expect(await h.db.select(h.db.ledgers).get(), isEmpty);
      h.container.dispose();
      await h.db.close();
    });
  });
}

class _Harness {
  _Harness(this.db, this.repo, this.container);

  final SpitoutDatabase db;
  final LocalRepository repo;
  final ProviderContainer container;
}

/// 仅让 purgeAllCloudLedgers 抛错的 repo 子类:用于独立2 失败路径测试,
/// 其余能力全部继承真实 LocalRepository,最小化桩面。
class _FailingPurgeLocalRepository extends LocalRepository {
  _FailingPurgeLocalRepository(super.db, {super.changeTracker});

  @override
  Future<void> purgeAllCloudLedgers() async {
    throw Exception('simulated purge failure');
  }
}
