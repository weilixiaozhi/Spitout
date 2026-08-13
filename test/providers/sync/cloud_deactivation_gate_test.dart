/// P0-b 同步闸门单元测试。
///
/// 背景:删除激活的云配置时,`_deleteConfig` 会 invalidate
/// [activeCloudConfigProvider]。Riverpod 的 invalidate 存在"旧值窗口"——
/// 在下游 rebuild 完成前,依赖它的 [spitoutCloudProviderInstance] /
/// [syncServiceProvider] 仍可能持有旧 Spitout 配置并重建云客户端,
/// 触发 setRecoveryCredentials + currentUser 的静默重登,把已登出的账号拉回来。
///
/// [cloudDeactivationInProgressProvider] 闸门:失活流程先关闸,
/// 下游在读 active 之前先查闸门,为 true 直接降级 null / LocalOnly。
///
/// 红测试断言:
/// 1. 闸门 true + active 仍为 Spitout 配置 → [spitoutCloudProviderInstance]
///    必须 resolve null,且云服务工厂【不被调用】(不重建客户端=不静默重登)。
/// 2. 闸门 true + active 仍为 Spitout 配置 → [syncServiceProvider] 必须降级
///    LocalOnly,且同样不触达云工厂。
/// 3. 开闸后恢复正常装配(回归保护,防闸门"只关不开"卡死全量同步)。
library;

import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';

/// 合法的 Spitout Cloud 激活配置:让未守卫时下游必走 Spitout 分支、必然触达云工厂。
CloudServiceConfig _spitoutActive() => const CloudServiceConfig(
      type: CloudBackendType.spitoutCloud,
      name: 'Spitout Cloud',
      spitoutCloudBaseUrl: 'https://cloud.example.com',
    );

/// 组装带"调用计数"云工厂桩的容器,并把 active 推进到 data 态。
///
/// 设计意图:工厂桩只计数不真正创建服务,「未调用」即证明闸门生效——
/// 下游连客户端装配都没做,自然不可能发生静默重登。
ProviderContainer _containerWithSpy(List<int> factoryCalls) {
  final container = ProviderContainer(overrides: [
    activeCloudConfigProvider.overrideWith((ref) async => _spitoutActive()),
    cloudServicesFactoryProvider.overrideWith(
      (ref) => (config) async {
        factoryCalls[0]++;
        return (provider: null, auth: null);
      },
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('闸门开启期间: spitoutCloudProviderInstance 降级 null,云工厂不被调用', () async {
    final calls = [0];
    final container = _containerWithSpy(calls);
    // 先让 active 进入 data 态,制造 invalidate 的"旧值窗口"
    await container.read(activeCloudConfigProvider.future);

    // 模拟 _deleteConfig 流程:先关闸,再 invalidate 级联根
    container.read(cloudDeactivationInProgressProvider.notifier).set(true);
    container.invalidate(activeCloudConfigProvider);
    // 重新 materialize active:此处 active 仍会解析出 Spitout 配置
    await container.read(activeCloudConfigProvider.future);

    final provider = await container.read(spitoutCloudProviderInstance.future);
    expect(provider, isNull,
        reason: '闸门开启期间即使 active 仍是 Spitout,云客户端也必须降级 null');
    expect(calls[0], 0,
        reason: '闸门开启期间禁止重建云客户端——否则 setRecoveryCredentials + '
            'currentUser 会触发静默重登,把已登出的账号拉回来');
  });

  test('闸门开启期间: syncServiceProvider 降级 LocalOnly,不触达云工厂', () async {
    final calls = [0];
    final container = _containerWithSpy(calls);
    await container.read(activeCloudConfigProvider.future);

    container.read(cloudDeactivationInProgressProvider.notifier).set(true);
    container.invalidate(activeCloudConfigProvider);
    await container.read(activeCloudConfigProvider.future);

    final sync = container.read(syncServiceProvider);
    expect(sync, isA<LocalOnlySyncService>(),
        reason: '闸门开启期间 sync 必须立即降级本地,不得重建 SyncEngine/连 WS');
    expect(calls[0], 0, reason: '闸门开启期间不得触达云工厂');
  });

  test('闸门开启期间: repositoryProvider 以无 tracker 装配，不注入 ChangeTracker', () async {
    final calls = [0];
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activeCloudConfigProvider.overrideWith((ref) async => _spitoutActive()),
      cloudServicesFactoryProvider.overrideWith(
        (ref) => (config) async {
          calls[0]++;
          return (provider: null, auth: null);
        },
      ),
    ]);
    addTearDown(container.dispose);
    addTearDown(() => db.close());

    // 先让 active 进入 data 态，制造 invalidate 的"旧值窗口"
    await container.read(activeCloudConfigProvider.future);
    container.read(cloudDeactivationInProgressProvider.notifier).set(true);
    container.invalidate(activeCloudConfigProvider);
    await container.read(activeCloudConfigProvider.future);

    final repo = container.read(repositoryProvider);
    expect(repo, isA<LocalRepository>());
    final local = repo;
    expect(local.changeTracker, isNull,
        reason: '失活窗口内仓库不得注入 ChangeTracker，本地写不会登记到失效通道');
    expect(local.snapshotDirtyMarker, isNull);
    expect(calls[0], 0, reason: '仓库降级路径同样不得触达云工厂');
  });

  test('开闸后恢复正常装配(回归保护:闸门不得只关不开)', () async {
    final calls = [0];
    final container = _containerWithSpy(calls);
    await container.read(activeCloudConfigProvider.future);

    container.read(cloudDeactivationInProgressProvider.notifier).set(true);
    container.invalidate(activeCloudConfigProvider);
    await container.read(activeCloudConfigProvider.future);

    // 失活流程结束,开闸
    container.read(cloudDeactivationInProgressProvider.notifier).set(false);

    // 开闸后 watch 闸门的 provider 自动重建,重新评估 active → 恢复正常装配
    final provider = await container.read(spitoutCloudProviderInstance.future);
    expect(provider, isNull,
        reason: '工厂桩返回 null provider,故实例仍为 null(语义上"已就绪")');
    expect(calls[0], greaterThanOrEqualTo(1),
        reason: '开闸后必须恢复云工厂装配,证明闸门只是流程窗口而非永久关闭');
  });
}
