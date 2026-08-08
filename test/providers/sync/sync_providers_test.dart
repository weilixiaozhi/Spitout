// sync_providers.dart 叶子 provider 测试。
//
// 覆盖：同步事件流（SyncEngine / LocalOnly 两种形态）、同步状态 provider 及其
// 最近值缓存、auto_sync 开关读写、Spitout Cloud 服务端版本号（含失败降级）。
// 使用真实 SQLite + FakeSpitoutCloudProvider，事件流场景走真实 WS 事件驱动。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import '../../helpers/test_isolation.dart';

/// 返回固定版本号的 fake，验证版本号正常解析分支。
class _VersionFake extends FakeSpitoutCloudProvider {
  @override
  Future<SpitoutCloudServerVersion> fetchServerVersion() async {
    return const SpitoutCloudServerVersion(name: 'test', version: '9.9.9');
  }
}

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
    engine.stopListeningRealtime();
    await db.close();
  });

  ProviderContainer buildContainer({
    required SyncService service,
    SpitoutCloudSyncBackend? backend,
  }) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        syncServiceProvider.overrideWithValue(service),
        spitoutCloudProviderInstance.overrideWith(
          (ref) async => backend,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> waitFor(bool Function() condition,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('waitFor 超时：条件在 $timeout 内未成立');
  }

  Future<int> seedLedger({String storageMode = 'local'}) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L',
            storageMode: Value(storageMode),
            syncId: Value(storageMode == 'cloud' ? 'ledger-1' : null),
          ),
        );
  }

  group('syncEventStreamProvider', () {
    test('LocalOnly 模式 → 空事件流', () async {
      final container = buildContainer(
        service: LocalOnlySyncService(repoResolver: () => repo),
        backend: null,
      );
      final events = <SyncEvent>[];
      final sub = container.listen<AsyncValue<SyncEvent>>(
        syncEventStreamProvider,
        (prev, next) {
          if (next.hasValue) events.add(next.value!);
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(events, isEmpty);
      sub.close();
    });

    test('SyncEngine 模式 → 订阅到 WS 驱动的 PullCompleted', () async {
      await seedLedger(storageMode: 'cloud');
      final container = buildContainer(service: engine, backend: provider);
      final events = <SyncEvent>[];
      final sub = container.listen<AsyncValue<SyncEvent>>(
        syncEventStreamProvider,
        (prev, next) {
          if (next.hasValue) events.add(next.value!);
        },
      );
      addTearDown(sub.close);

      engine.startListeningRealtime();
      provider.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'sync_change',
          ledgerId: 'ledger-1',
          rawData: {},
        ),
      );

      await waitFor(
        () => events.any((e) => e is PullCompleted && e.ledgerId == 'ledger-1'),
      );
      engine.stopListeningRealtime();
    });
  });

  group('syncStatusProvider', () {
    test('纯本地账本 → localOnly 状态，并写入最近值缓存', () async {
      final id = await seedLedger(storageMode: 'local');
      final container = buildContainer(service: engine, backend: provider);

      final status = await container.read(syncStatusProvider(id).future);
      expect(status.diff, SyncDiff.localOnly);
      expect(container.read(lastSyncStatusProvider(id)), status);
    });
  });

  group('autoSyncValueProvider / autoSyncSetterProvider', () {
    test('默认关闭；set true/false 持久化并失效缓存', () async {
      final container = buildContainer(
        service: LocalOnlySyncService(repoResolver: () => repo),
        backend: null,
      );

      expect(await container.read(autoSyncValueProvider.future), isFalse);

      await container.read(autoSyncSetterProvider).set(true);
      expect(await container.read(autoSyncValueProvider.future), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auto_sync'), isTrue);

      await container.read(autoSyncSetterProvider).set(false);
      expect(await container.read(autoSyncValueProvider.future), isFalse);
      expect(prefs.getBool('auto_sync'), isFalse);
    });
  });

  group('spitoutCloudServerVersionProvider', () {
    test('cloud 未就绪 → null', () async {
      final container = buildContainer(
        service: LocalOnlySyncService(repoResolver: () => repo),
        backend: null,
      );
      expect(await container.read(spitoutCloudServerVersionProvider.future),
          isNull);
    });

    test('版本接口失败 → null（不向上抛）', () async {
      final container = buildContainer(service: engine, backend: provider);
      expect(await container.read(spitoutCloudServerVersionProvider.future),
          isNull);
    });

    test('版本接口返回 → 透传版本号', () async {
      final versionFake = _VersionFake();
      final container = buildContainer(service: engine, backend: versionFake);
      expect(await container.read(spitoutCloudServerVersionProvider.future),
          '9.9.9');
    });
  });
}
