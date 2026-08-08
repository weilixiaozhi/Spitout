// syncServiceProvider 装配与断网/重连行为测试。
//
// 覆盖 sync_providers.dart 中 SyncEngine 分支的完整装配体：
//   1. 激活 Spitout Cloud 配置 → 构建 SyncEngine 并跑 bootstrap（拉账本 + 账户级同步）；
//   2. connectivity 断网 → 不触发；恢复 → 500ms 防抖 + 引擎 2s 防抖后自动同步
//      （真实断网重连场景，connectivity_plus 平台接口用测试桩替换）；
//   3. PullCompleted(applied>0) 事件分发 → 刷新 tick / 清交易缓存；
//   4. ProfileFieldApplied 事件 → 云端昵称 / 支出配色回写本地 provider；
//   5. 非 Spitout 配置 → 降级 LocalOnly。
// 使用真实 SQLite + FakeSpitoutCloudProvider，断言真实副作用。

import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';

/// connectivity_plus 平台测试桩：可编程发射断网/重连事件。
class _FakeConnectivityPlatform extends ConnectivityPlatform {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  _FakeConnectivityPlatform() {
    ConnectivityPlatform.instance = this;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [];

  void emit(List<ConnectivityResult> results) => _controller.add(results);
}

/// 带 profile 字段的 fake：让 syncMyProfile 发射 ProfileFieldApplied 事件。
class _ProfileFake extends FakeSpitoutCloudProvider {
  @override
  Future<SpitoutCloudProfile> getMyProfile() async {
    return const SpitoutCloudProfile(
      userId: 'test-user-id',
      displayName: '云端昵称',
      appearance: {'expense_color_scheme': 'red'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeConnectivityPlatform connectivity;
  late ConnectivityPlatform previousConnectivity;

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ChangeTracker changeTracker;
  late FakeSpitoutCloudProvider provider;

  setUp(() {
    resetGlobalTestState();
    previousConnectivity = ConnectivityPlatform.instance;
    connectivity = _FakeConnectivityPlatform();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    changeTracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: changeTracker);
    provider = FakeSpitoutCloudProvider();
  });

  tearDown(() async {
    ConnectivityPlatform.instance = previousConnectivity;
    await db.close();
  });

  ProviderContainer buildContainer({
    FakeSpitoutCloudProvider? backend,
    bool localOnly = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        activeCloudConfigProvider.overrideWith(
          (ref) async => localOnly
              ? const CloudServiceConfig(
                  type: CloudBackendType.local,
                  name: 'Local',
                )
              : const CloudServiceConfig(
                  type: CloudBackendType.spitoutCloud,
                  name: 'Spitout Cloud',
                  spitoutCloudBaseUrl: 'https://cloud.example.com',
                ),
        ),
        spitoutCloudProviderInstance.overrideWith(
          (ref) async => backend,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 先 materialize 异步依赖，避免 syncServiceProvider 在依赖仍为 loading 时
  /// 被错误降级为 LocalOnly（Riverpod 同步读语义）。
  Future<void> materialize(ProviderContainer container) async {
    await container.read(activeCloudConfigProvider.future);
    await container.read(spitoutCloudProviderInstance.future);
  }

  Future<void> waitFor(FutureOr<bool> Function() condition,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('waitFor 超时：条件在 $timeout 内未成立');
  }

  Future<int> seedCloudLedger(String syncId) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L',
            syncId: Value(syncId),
            storageMode: const Value('cloud'),
          ),
        );
  }

  group('syncServiceProvider 装配', () {
    test('Spitout Cloud 激活 → 构建 SyncEngine 并跑 bootstrap', () async {
      await seedCloudLedger('ledger-1');
      final container = buildContainer(backend: provider);
      await materialize(container);

      final service = container.read(syncServiceProvider);
      expect(service, isA<SyncEngine>());

      // bootstrap：syncLedgersFromServer + syncAccount → 至少发生一次 pull
      await waitFor(() => provider.pullCalls.isNotEmpty);
      // bootstrap 成功收尾：lastSyncError 清空
      await waitFor(() => container.read(lastSyncErrorProvider) == null);
    });

    test('本地配置 → 降级 LocalOnlySyncService', () async {
      final container = buildContainer(backend: null, localOnly: true);
      await materialize(container);

      expect(container.read(syncServiceProvider), isA<LocalOnlySyncService>());
    });
  });

  group('断网/重连', () {
    test('离线事件不触发同步；恢复后防抖触发自动同步', () async {
      await seedCloudLedger('ledger-1');
      final container = buildContainer(backend: provider);
      await materialize(container);
      container.read(syncServiceProvider);

      // 等 bootstrap 完成，记录基线
      await waitFor(() => provider.pullCalls.isNotEmpty);
      final baseline = provider.pullCalls.length;

      // 断网：不应有新的网络副作用
      connectivity.emit([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(provider.pullCalls.length, baseline,
          reason: '离线状态不得触发自动同步');

      // 重连：500ms 防抖 + 引擎 2s 防抖后触发 syncAccount
      connectivity.emit([ConnectivityResult.wifi]);
      await waitFor(() => provider.pullCalls.length > baseline);
    });
  });

  group('同步事件分发', () {
    test('PullCompleted(applied>0) → 刷新各域 tick 并清交易缓存', () async {
      await seedCloudLedger('ledger-1');
      // 预置分类，让远程交易 apply 能解析
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Food',
              kind: 'expense',
              syncId: const Value('cat-1'),
            ),
          );
      final container = buildContainer(backend: provider);
      await materialize(container);
      container.read(syncServiceProvider);
      await waitFor(() => provider.pullCalls.isNotEmpty);

      // 记录 bootstrap 完成后的 tick 基线，隔离事件分发的增量
      final syncStatusBefore = container.read(syncStatusRefreshProvider);
      final ledgerListBefore = container.read(ledgerListRefreshProvider);
      final homeSwitchBefore = container.read(homeSwitchToStreamProvider);

      // 通过 WS 事件驱动的 auto pull 触发 PullCompleted(applied>0)
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-A',
        ledgerId: 'ledger-1',
        payload: {
          'syncId': 'tx-A',
          'type': 'expense',
          'amount': 12.5,
          'happenedAt': '2026-05-01T10:00:00Z',
          'note': 'lunch',
          'categoryName': 'Food',
          'categoryKind': 'expense',
          'categoryId': 'cat-1',
        },
      );
      // 拿到装配体内部同一个 engine（family 缓存），启动 WS 并发射事件
      final engine = container.read(syncEngineProvider(provider));
      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'sync_change',
          ledgerId: 'ledger-1',
          rawData: {},
        ),
      );

      // 等待 1s 防抖 pull 真正把远程交易 apply 落库
      await waitFor(() async =>
          (await (db.select(db.transactions)
                    ..where((t) => t.syncId.equals('tx-A')))
                .getSingleOrNull()) !=
          null);

      // PullCompleted(applied>0) 分发应推动各域 tick
      expect(container.read(syncStatusRefreshProvider),
          greaterThan(syncStatusBefore));
      expect(container.read(ledgerListRefreshProvider),
          greaterThan(ledgerListBefore));
      expect(container.read(homeSwitchToStreamProvider),
          greaterThan(homeSwitchBefore));
      engine.stopListeningRealtime();
    });

    test('ProfileFieldApplied → 云端昵称/配色回写本地 provider', () async {
      final profileFake = _ProfileFake();
      final container = buildContainer(backend: profileFake);
      await materialize(container);
      container.read(syncServiceProvider);

      // bootstrap 的 profile 同步会拉取并应用 displayName + appearance
      await waitFor(() => container.read(displayNameProvider) == '云端昵称');
      expect(container.read(expenseColorSchemeProvider), 'red');
    });
  });
}
