/// 针对本次修复新增/改写的 provider 单元测试。
///
/// 固化两类关键行为，避免回归：
/// 1. [authServiceProvider] 各类配置的降级路径（本地 / Spitout 但 provider 未就绪）
///    不抛异常，统一降级 [NoopAuthService]。
/// 2. [cloudCurrentUserProvider] 的「种子 + 跟随」语义：
///    - NoopAuthService → 单发 null（UI 走未登录态，不卡 loading）。
///    - 已登录 → 先以 currentUser 快照作首屏种子，再跟随 authStateChanges，
///      即使广播流在订阅前已触发也能立刻给出 data（修复"已登录重进页面卡 loading"
///      的根因：广播流不重放）。
///    - 登出事件（authStateChanges 发 null）经流传播，最终回退未登录态。
library;

import 'dart:async';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/providers/providers.dart';

/// 已登录 Fake：currentUser 返回固定用户，authStateChanges 为单订阅流。
///
/// 用 `extends Fake` 只实现测试用到的读取接口，其余写路径默认抛
/// UnimplementedError（本测试不触发）。[authStateChanges] 仅在被订阅后才发值，
/// 用来验证「种子先行」能保证即使跟随流晚到也能拿到用户态。
class _LoggedInAuth extends Fake implements CloudAuthService {
  final CloudUser user;
  _LoggedInAuth(this.user);

  @override
  Future<CloudUser?> get currentUser async => user;

  @override
  Stream<CloudUser?> get authStateChanges => Stream<CloudUser?>.value(user);
}

/// 顺序事件 Fake：currentUser 返回 user，authStateChanges 依次发 user、null。
///
/// 用于验证「登录态 → 登出事件」能经 [cloudCurrentUserProvider] 传播，
/// 最终落到 null（未登录）。用确定的事件序列避免异步时序抖动。
class _SeqAuth extends Fake implements CloudAuthService {
  final CloudUser user;
  _SeqAuth(this.user);

  @override
  Future<CloudUser?> get currentUser async => user;

  @override
  Stream<CloudUser?> get authStateChanges =>
      Stream<CloudUser?>.fromIterable([user, null]);
}

/// 合法的 Spitout Cloud 激活配置（带 baseUrl → valid 为 true，能走到 Spitout 分支）。
CloudServiceConfig _spitoutActive() => const CloudServiceConfig(
      type: CloudBackendType.spitoutCloud,
      name: 'Spitout Cloud',
      spitoutCloudBaseUrl: 'https://cloud.example.com',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('authServiceProvider: 本地模式降级 NoopAuthService', () async {
    final container = ProviderContainer(overrides: [
      activeCloudConfigProvider.overrideWith((ref) async =>
          const CloudServiceConfig(
              type: CloudBackendType.local, name: 'Local')),
    ]);
    addTearDown(container.dispose);
    // 先 materialize 依赖，规避嵌套 FutureProvider 经 .future 直读时的 zone 时序问题。
    await container.read(activeCloudConfigProvider.future);
    final auth = await container.read(authServiceProvider.future);
    expect(auth, isA<NoopAuthService>());
  });

  test('authServiceProvider: Spitout 配置但 provider 未就绪 → Noop（不抛）',
      () async {
    final container = ProviderContainer(overrides: [
      activeCloudConfigProvider.overrideWith((ref) async => _spitoutActive()),
      // provider 实例为 null：Spitout 分支应安全降级 Noop，而非抛异常。
      spitoutCloudProviderInstance.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    await container.read(activeCloudConfigProvider.future);
    await container.read(spitoutCloudProviderInstance.future);
    final auth = await container.read(authServiceProvider.future);
    expect(auth, isA<NoopAuthService>());
  });

  test('cloudCurrentUserProvider: NoopAuthService → 单发 null，不卡 loading',
      () async {
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWith((ref) async => NoopAuthService()),
    ]);
    addTearDown(container.dispose);
    // 先让 authServiceProvider 进入 data 态，cloudCurrentUserProvider 才会返回
    // 单发 null 的流（而非等待依赖的空流），避免 .future 捕获到永远 loading 的空流。
    await container.read(authServiceProvider.future);
    final user = await container.read(cloudCurrentUserProvider.future);
    expect(user, isNull);
  });

  test('cloudCurrentUserProvider: 已登录 → 种子当前用户，不卡 loading（回归点）',
      () async {
    final user = const CloudUser(id: 'u1', email: 'a@b.com');
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWith((ref) async => _LoggedInAuth(user)),
    ]);
    addTearDown(container.dispose);
    await container.read(authServiceProvider.future);
    final resolved = await container.read(cloudCurrentUserProvider.future);
    expect(resolved, user);
  });

  test('cloudCurrentUserProvider: 登出事件(null)经流传播，最终回退未登录',
      () async {
    final user = const CloudUser(id: 'u2', email: 'b@b.com');
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWith((ref) async => _SeqAuth(user)),
    ]);
    addTearDown(container.dispose);
    await container.read(authServiceProvider.future);

    // StreamProvider.future 只返回首值，无法观测登出事件；用 listen 收集全部态迁移。
    final seen = <CloudUser?>[];
    final sub = container.listen(
      cloudCurrentUserProvider,
      (prev, next) {
        if (next.hasValue) seen.add(next.value);
      },
      fireImmediately: true,
    );
    // 等待种子（user）与顺序事件（user、null）全部流入流。
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    sub.close();

    expect(seen, contains(user)); // 首屏种子为已登录态
    expect(seen.last, isNull); // 登出事件后自动回退未登录
  });

  test('invalidate(activeCloudConfigProvider) 级联重建 auth/sync provider', () async {
    final container = ProviderContainer(overrides: [
      activeCloudConfigProvider.overrideWith((ref) async =>
          const CloudServiceConfig(
              type: CloudBackendType.local, name: 'Local')),
    ]);
    addTearDown(container.dispose);

    // 先 materialize 依赖，规避嵌套 FutureProvider 经 .future 直读时的 zone 时序问题。
    await container.read(activeCloudConfigProvider.future);

    // 依赖 active 的两个 provider 各自解析出实例 A（每次 provider 重建都会 new 出新实例）
    final authBefore = await container.read(authServiceProvider.future);
    final syncBefore = container.read(syncServiceProvider);

    // 仅 invalidate 级联根；syncServiceProvider / authServiceProvider 没有手写 invalidate。
    container.invalidate(activeCloudConfigProvider);
    // 重新 materialize active：级联下游的 nested future 需要拿到「已解析」的 active，
    // 否则在裸 ProviderContainer 里会卡在 loading 态（widget 树中由 addPostFrameCallback
    // 触发重建，不存在此问题）。
    await container.read(activeCloudConfigProvider.future);

    final authAfter = await container.read(authServiceProvider.future);
    final syncAfter = container.read(syncServiceProvider);

    // 身份不同 → 证明 invalidate active 后，二者确实被级联重建
    // （即 cloud_service_page 中删除冗余 invalidate 不会影响同步状态刷新）
    expect(identical(authBefore, authAfter), isFalse);
    expect(identical(syncBefore, syncAfter), isFalse);
  });
}
