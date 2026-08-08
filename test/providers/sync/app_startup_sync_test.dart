// AppStartupSync 启动同步收敛器测试。
//
// 用真实 SQLite(in-memory) + ProviderContainer override + FakeSpitoutCloudProvider，
// 验证冷启动同步编排：
//   1. SyncEngine 模式 + 本地有账本 → 启动后自动触发 syncAccount；
//   2. LocalOnly 模式 → 不触发任何网络副作用；
//   3. 本地无账本 → 跳过首次同步；
//   4. 5 秒幂等节流 → 短时间内重复 start 只跑一次；
//   5. 监听 syncServiceProvider 由 LocalOnly 切到 SyncEngine → 触发首次同步。
// 用 provider.pullCalls/pushedBatches 断言真实副作用，而非 mock 方法调用。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/providers/sync/app_startup_sync.dart';

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

  tearDown(() async => db.close());

  ProviderContainer buildContainer({required SyncService service}) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        syncServiceProvider.overrideWithValue(service),
        spitoutCloudProviderInstance.overrideWith((ref) async => provider),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 构造一个 syncService 可切换的容器：通过修改持有者 + invalidate 重建 provider，
  /// 触发 AppStartupSync 构造时注册的监听回调。
  ProviderContainer buildSwitchableContainer(SyncService Function() current) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        syncServiceProvider.overrideWith((ref) => current()),
        spitoutCloudProviderInstance.overrideWith((ref) async => provider),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> seedLocalLedger() async {
    await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L',
            syncId: const Value('ledger-1'),
            storageMode: const Value('cloud'),
          ),
        );
  }

  /// 轮询等待网络副作用发生（syncAccount 为异步编排，避免固定 sleep flaky）。
  Future<void> waitFor(bool Function() condition,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('waitFor 超时：条件在 $timeout 内未成立');
  }

  group('AppStartupSync', () {
    test('SyncEngine + 本地有账本 → 冷启动自动同步', () async {
      await seedLocalLedger();
      final container = buildContainer(service: engine);
      final startup = container.read(appStartupSyncProvider);

      startup.start();

      // 首次同步应触发 pull（账户级 syncAccount 内含 pull('')）
      await waitFor(() => provider.pullCalls.isNotEmpty);
      // 同步状态与账本列表 tick 不应导致任何异常
      expect(container.read(ledgerListRefreshProvider), greaterThanOrEqualTo(0));
    });

    test('LocalOnly 模式 → 不触发任何网络副作用', () async {
      await seedLocalLedger();
      final localOnly = LocalOnlySyncService(repoResolver: () => repo);
      final container = buildContainer(service: localOnly);

      container.read(appStartupSyncProvider).start();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(provider.pullCalls, isEmpty);
      expect(provider.pushedBatches, isEmpty);
    });

    test('本地无账本 → 跳过首次同步', () async {
      final container = buildContainer(service: engine);
      container.read(appStartupSyncProvider).start();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(provider.pullCalls, isEmpty,
          reason: '本地无账本时不应发起账户级首次同步');
    });

    test('5 秒幂等节流：短时间内重复 start 只同步一次', () async {
      await seedLocalLedger();
      final container = buildContainer(service: engine);
      final startup = container.read(appStartupSyncProvider);

      startup.start();
      startup.start();

      await waitFor(() => provider.pullCalls.isNotEmpty);
      // 给第二个 start 的 microtask 留出执行窗口，确认被节流吞掉
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(provider.pullCalls, hasLength(1),
          reason: '5 秒节流内第二次触发应被跳过');
    });

    test('切换监听：LocalOnly→SyncEngine 触发首次同步，5 秒内重复命中被合并', () async {
      await seedLocalLedger();
      SyncService current = LocalOnlySyncService(repoResolver: () => repo);
      final container = buildSwitchableContainer(() => current);
      // 构造时注册监听（provider 常驻，与 App 生命周期一致）
      container.read(appStartupSyncProvider);

      // 配置就绪：LocalOnly → SyncEngine，监听触发首次同步
      current = engine;
      container.invalidate(syncServiceProvider);
      container.read(syncServiceProvider);
      await waitFor(() => provider.pullCalls.isNotEmpty);

      // 5 秒节流窗口内"切走再切回"的第二次命中，不应重复同步
      current = LocalOnlySyncService(repoResolver: () => repo);
      container.invalidate(syncServiceProvider);
      container.read(syncServiceProvider);
      current = engine;
      container.invalidate(syncServiceProvider);
      container.read(syncServiceProvider);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(provider.pullCalls, hasLength(1),
          reason: '5 秒节流内重复命中 SyncEngine 应被合并为一次');
    });
  });
}
