// categoryPickerTreeProvider 自愈 + 冷却节流测试
//
// 防线 B —— 打开记账页即时自愈 + 冷却节流。
//
// 场景：Editor 切到一个 Owner 已建好分类的共享账本,但本地 SharedLedgerCategories
// 镜像表为空(WS 漏推 / 邀请接受后资源拉取失败 / 新设备首次绑定)。
// 此时打开记账 sheet,空分类网格应在"自愈"逻辑下立即触发拉取并刷新出分类;
// 同一 ledgerSyncId 5 分钟内重开不再重复打网络;失败也进入冷却,下次打开才重试。

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';

import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/providers/providers.dart';

/// 测试用 fake provider:允许注入 fetchSharedResources 返回值与调用计数,
/// 模拟 Spitout Cloud `/shared-resources` endpoint 行为,无需触网。
class _FakeProviderWithSharedResources extends FakeSpitoutCloudProvider {
  _FakeProviderWithSharedResources(this._resources);

  SpitoutCloudSharedResources? _resources;
  int fetchCallCount = 0;

  @override
  Future<SpitoutCloudSharedResources> fetchSharedResources({
    required String ledgerId,
  }) async {
    fetchCallCount++;
    if (_resources == null) {
      throw Exception('simulated network failure');
    }
    return _resources!;
  }

  /// 第二次打开时改返回值,验证后续自愈能拿到新快照
  void setResources(SpitoutCloudSharedResources? next) => _resources = next;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late ProviderContainer container;
  late _FakeProviderWithSharedResources fake;

  /// 设置当前账本为共享账本 Editor(空 SharedLedgerCategories 镜像表)
  Future<void> seedSharedEditorLedger() async {
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'Shared-LS1',
          syncId: const d.Value('LS1'),
          isShared: const d.Value(true),
          myRole: const d.Value('editor'),
        ));
    // currentLedgerIdProvider 默认 0,override 设为 1 匹配插入的账本 id
  }

  /// 轮询等待条件成立(Drift 表变更通知经 isolate 异步到达,
  /// 不能用 pumpEventQueue 假定时序),超时即失败。
  Future<void> waitFor(bool Function() cond, String reason) async {
    for (var i = 0; i < 300; i++) {
      if (cond()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('等待超时: $reason');
  }

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    fake = _FakeProviderWithSharedResources(null);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
      // 把 cloud provider 与 engine 都换成 fake / 真实 engine 实例
      spitoutCloudProviderInstance.overrideWith((ref) async => fake),
    ]);
    await seedSharedEditorLedger();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('空镜像树 → 自愈拉取并即时出现分类(本地单机无 cloud 不触发)', () async {
    // 主表数据(Editor 视角应被整体丢弃)
    await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: '本地分类', kind: 'expense'));

    // 共享资源:Owner 一父一子
    fake.setResources(SpitoutCloudSharedResources(
      ownerUserId: 'owner-1',
      categories: [
        const SpitoutCloudSharedCategory(
            syncId: 'c1', name: '共享餐饮', kind: 'expense', level: 1, sortOrder: 0),
        const SpitoutCloudSharedCategory(
            syncId: 'c2',
            name: '共享早餐',
            kind: 'expense',
            level: 2,
            parentSyncId: 'c1'),
      ],
      accounts: const [],
    ));

    // 读 stream 首帧 + 等待自愈完成(provider 内部 unawaited 触发拉取,
    // 写镜像表 → tableUpdates 自动重建 → 二次发新树)
    final sub = container.listen(
      categoryPickerTreeProvider('expense'),
      (_, _) {},
      fireImmediately: true,
    );

    await waitFor(
      () => container.read(categoryPickerTreeProvider('expense')).value
              ?.topLevel
              .isNotEmpty ==
          true,
      '自愈完成后应出现共享分类',
    );
    sub.close();

    // 自愈被调用过一次
    expect(fake.fetchCallCount, 1);
    // 本地分类未出现在 Editor 视角
    final tree = container
        .read(categoryPickerTreeProvider('expense'))
        .value!;
    expect(tree.topLevel.single.name, '共享餐饮');
    expect(tree.topLevel.any((c) => c.name == '本地分类'), false);
  });

  test('5 分钟内重开同一 ledger 不重复打网络(冷却节流)', () async {
    fake.setResources(SpitoutCloudSharedResources(
      ownerUserId: 'owner-1',
      categories: [
        const SpitoutCloudSharedCategory(
            syncId: 'c1', name: '共享餐饮', kind: 'expense', level: 1),
      ],
      accounts: const [],
    ));

    // 第一次"打开":订阅 stream → 自愈触发拉取
    final sub1 = container.listen(
      categoryPickerTreeProvider('expense'),
      (_, _) {},
      fireImmediately: true,
    );
    await waitFor(() => fake.fetchCallCount == 1, '首次自愈应触发拉取');
    sub1.close();

    // 模拟"第二次打开记账页":手动把镜像表清空,再触发一次 load。
    // 清空后 tree.topLevel.isEmpty 仍为 true,但冷却期内应直接 return。
    await (db.delete(db.sharedLedgerCategories)
          ..where((t) => t.ledgerSyncId.equals('LS1')))
        .go();
    // 触发一次 tableUpdates 让 provider 重发(模拟 sheet 关闭再开)
    await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: '触发重建', kind: 'expense'));

    final sub2 = container.listen(
      categoryPickerTreeProvider('expense'),
      (_, _) {},
      fireImmediately: true,
    );
    // 等 100ms 给 unawaited 自愈执行窗口
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(fake.fetchCallCount, 1, reason: '冷却期内重开不应重复拉取');
    sub2.close();
  });

  test('失败也进入冷却:同一 ledger 重开不再重复失败拉取', () async {
    // fake 默认 _resources=null,fetchSharedResources 抛异常
    final sub = container.listen(
      categoryPickerTreeProvider('expense'),
      (_, _) {},
      fireImmediately: true,
    );
    await waitFor(() => fake.fetchCallCount == 1, '首次自愈应触发拉取(失败)');
    sub.close();

    // 第二次打开:不应再次拉
    final sub2 = container.listen(
      categoryPickerTreeProvider('expense'),
      (_, _) {},
      fireImmediately: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(fake.fetchCallCount, 1, reason: '失败冷却期内不应重复拉取');
    sub2.close();
  });

  test('cloud 为 null(本地单机)不触发拉取,主表数据正常返回', () async {
    // 重建 container,spitoutCloudProviderInstance 返 null
    final container2 = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
      spitoutCloudProviderInstance.overrideWith((ref) async => null),
    ]);
    addTearDown(container2.dispose);

    // 把账本改回单人账本,避免 Editor 视角替换
    await (db.update(db.ledgers)..where((t) => t.id.equals(1))).write(
      const LedgersCompanion(
        isShared: d.Value(false),
        myRole: d.Value('owner'),
        syncId: d.Value(null),
      ),
    );
    await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: '本地分类', kind: 'expense'));

    final sub = container2.listen(
      categoryPickerTreeProvider('expense'),
      (_, _) {},
      fireImmediately: true,
    );
    final tree = await readProviderFutureFromContainer(
      container2,
      categoryPickerTreeProvider('expense').future,
    );
    sub.close();

    expect(tree.topLevel.single.name, '本地分类');
    expect(fake.fetchCallCount, 0, reason: '本地单机无 cloud 不应触发拉取');
  });
}
