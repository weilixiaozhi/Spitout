import 'dart:async';

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

/// [createInviteAndRefresh] 的单元测试 —— 防线 A「发邀请前确保分类上云」。
///
/// 锁定行为:
///   1) 在 cloud.createInvite 之前必须先调用 syncEngine.pushUserGlobalEntities,
///      把本地 user-global 实体(category 等)推上云,避免「云端空快照」流到
///      Editor 端导致协作者看不到 Owner 的分类;
///   2) pushUserGlobalEntities 首次失败时,重试一次(单飞锁 finally 已复位,
///      重试安全);
///   3) 重试仍失败 → throw 阻断邀请,cloud.createInvite 不被调用;
///   4) push 成功后 → 正常调 cloud.createInvite 并返回邀请。
///
/// 实现手段:用一个可注入 pushUserGlobalEntities 行为的 SyncEngine 子类
/// [_SteerableSyncEngine] override `syncEngineProvider`,避免依赖真实 push
/// 路径(真实路径要先塞 user-global change + 控制 pushChanges 抛错,过于曲折)。
void main() {
  Future<_Harness> harness({
    /// pushUserGlobalEntities 每次调用的行为:返回值=推了多少条;
    /// 抛错=本次失败。null=用真实实现(本测试不需要)。
    List<Future<int> Function()>? pushUserGlobalBehaviors,
  }) async {
    resetGlobalTestState();
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    final fake = FakeSpitoutCloudProvider();
    final engine = _SteerableSyncEngine(
      db: db,
      provider: fake,
      changeTracker: tracker,
      repo: repo,
      pushUserGlobalBehaviors: pushUserGlobalBehaviors ?? [],
    );
    final container = ProviderContainer(overrides: [
      spitoutCloudProviderInstance.overrideWith((ref) async => fake),
      syncEngineProvider.overrideWith((ref, arg) => engine),
      currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(null)),
    ]);
    return _Harness(db, repo, fake, container, engine);
  }

  /// 通过 Consumer 在 build 阶段取回真实 WidgetRef。
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

  testWidgets('pushUserGlobalEntities 成功后调用 cloud.createInvite 并返回邀请',
      (tester) async {
    final h = await harness(
      pushUserGlobalBehaviors: [() async => 3],
    );
    final ref = await captureRef(tester, h.container);

    final invite = await createInviteAndRefresh(
      ref,
      ledgerId: 'ext-1',
      role: 'editor',
      expiresInHours: 24,
    );

    // LoggerService 写日志会调度 2 秒 debounce 定时器,推进时间避免测试
    // 结束时遗留 pending timer。
    await tester.pump(const Duration(seconds: 3));

    // 1) pushUserGlobalEntities 被调用一次
    expect(h.engine.pushUserGlobalCallCount, 1);
    // 2) cloud.createInvite 被调用一次,参数透传
    expect(h.fake.createInviteCalls, [
      (ledgerId: 'ext-1', role: 'editor', expiresInHours: 24),
    ]);
    // 3) 返回的是 cloud 造的邀请
    expect(invite.code, isNotEmpty);

    h.container.dispose();
    h.db.close();
  });

  testWidgets('pushUserGlobalEntities 首次失败 → 重试一次成功 → 邀请发出',
      (tester) async {
    final h = await harness(
      pushUserGlobalBehaviors: [
        () async => throw Exception('first push boom'),
        () async => 2,
      ],
    );
    final ref = await captureRef(tester, h.container);

    final invite = await createInviteAndRefresh(
      ref,
      ledgerId: 'ext-1',
      role: 'editor',
      expiresInHours: 24,
    );

    // 首次失败会写 warning 日志,推进其 debounce 定时器。
    await tester.pump(const Duration(seconds: 3));

    // 重试一次:共调用 2 次 pushUserGlobalEntities
    expect(h.engine.pushUserGlobalCallCount, 2);
    // 重试成功后邀请仍正常发出
    expect(h.fake.createInviteCalls, hasLength(1));
    expect(invite.code, isNotEmpty);

    h.container.dispose();
    h.db.close();
  });

  testWidgets('pushUserGlobalEntities 重试仍失败 → throw 阻断邀请,createInvite 不被调用',
      (tester) async {
    final h = await harness(
      pushUserGlobalBehaviors: [
        () async => throw Exception('first push boom'),
        () async => throw Exception('second push boom'),
      ],
    );
    final ref = await captureRef(tester, h.container);

    // 阻断邀请:抛错冒泡到调用方(由 member_list_page 的 catch 兜底)
    await expectLater(
      createInviteAndRefresh(
        ref,
        ledgerId: 'ext-1',
        role: 'editor',
        expiresInHours: 24,
      ),
      throwsA(isA<Exception>()),
    );

    // 首次失败写 warning、重试仍失败写 error,两条日志各调度 debounce
    // 定时器,推进时间避免 pending timer 断言失败。
    await tester.pump(const Duration(seconds: 3));

    // 重试一次后仍失败:共调用 2 次 pushUserGlobalEntities
    expect(h.engine.pushUserGlobalCallCount, 2);
    // 关键:cloud.createInvite 必须未被调用,不能让「云端空快照」流到 Editor 端
    expect(h.fake.createInviteCalls, isEmpty);

    h.container.dispose();
    h.db.close();
  });
}

/// 可注入 pushUserGlobalEntities 行为的 SyncEngine 子类。
///
/// 为什么要子类而不是用 mockito:项目测试惯例是「真实 SyncEngine + Fake provider」,
/// 这里只需在 createInviteAndRefresh 路径上替换 pushUserGlobalEntities 的行为,
/// 其它方法仍走真实实现,保持与生产路径最大一致性。
class _SteerableSyncEngine extends SyncEngine {
  _SteerableSyncEngine({
    required super.db,
    required super.provider,
    required super.changeTracker,
    required super.repo,
    required this.pushUserGlobalBehaviors,
  });

  /// 按调用顺序依次消费的行为队列;队列耗尽后再调用会抛 StateError(测试漏配)。
  final List<Future<int> Function()> pushUserGlobalBehaviors;

  int pushUserGlobalCallCount = 0;

  @override
  Future<int> pushUserGlobalEntities() async {
    pushUserGlobalCallCount++;
    if (pushUserGlobalCallCount > pushUserGlobalBehaviors.length) {
      throw StateError(
          '测试未配置第 $pushUserGlobalCallCount 次 pushUserGlobalEntities 行为');
    }
    return pushUserGlobalBehaviors[pushUserGlobalCallCount - 1]();
  }
}

class _Harness {
  _Harness(this.db, this.repo, this.fake, this.container, this.engine);

  final SpitoutDatabase db;
  final LocalRepository repo;
  final FakeSpitoutCloudProvider fake;
  final ProviderContainer container;
  final _SteerableSyncEngine engine;
}
