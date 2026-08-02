// 分类同步 apply 路径的 parentSyncId 优先解析测试。
//
// 背景:_applyCategoryChange 此前只按 parentName 反查父分类(name+kind+level=1),
// 父分类重命名后 payload 里的 parentName 与本地名字脱节时会解析失败(挂成一级
// 或靠 seed 收编兜底)。serializer 推送时本就携带 parentSyncId,apply 端应优先
// 按 syncId 精确命中,miss 再回退 parentName。
//
// 用 engine.pull('') 走真实 applyRemoteChange seam(public 入口),
// FakeSpitoutCloudProvider.pushFakeChange 注入远端 change。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';
import 'package:drift/drift.dart' show Value;

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;

  setUp(() async {
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

  Future<Category?> catBySyncId(String syncId) =>
      (db.select(db.categories)..where((c) => c.syncId.equals(syncId)))
          .getSingleOrNull();

  test('parentName 与本地脱节时,parentSyncId 精确命中父分类', () async {
    // 本地父分类已被重命名为「餐饮-新」,远端 payload 仍带旧 parentName「餐饮」,
    // 仅靠 parentName 反查必然 miss;parentSyncId 应精确命中。
    final parentId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: '餐饮-新',
            kind: 'expense',
            syncId: const Value('parent-1'),
          ),
        );

    provider.pushFakeChange(
      entityType: 'category',
      entitySyncId: 'sub-1',
      payload: {
        'syncId': 'sub-1',
        'name': '早餐',
        'kind': 'expense',
        'level': 2,
        'parentName': '餐饮', // 旧名,本地查不到
        'parentSyncId': 'parent-1',
      },
    );

    await engine.pull('');

    final sub = await catBySyncId('sub-1');
    expect(sub, isNotNull);
    expect(sub!.level, 2);
    expect(sub.parentId, parentId,
        reason: 'parentName miss 时应按 parentSyncId 命中重命名后的父分类');
  });

  test('parentSyncId miss → 回退 parentName 反查(兼容旧 payload)', () async {
    final parentId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: '交通',
            kind: 'expense',
            syncId: const Value('parent-2'),
          ),
        );

    provider.pushFakeChange(
      entityType: 'category',
      entitySyncId: 'sub-2',
      payload: {
        'syncId': 'sub-2',
        'name': '地铁',
        'kind': 'expense',
        'level': 2,
        'parentName': '交通',
        // 旧 payload 不带 parentSyncId
      },
    );

    await engine.pull('');

    final sub = await catBySyncId('sub-2');
    expect(sub, isNotNull);
    expect(sub!.parentId, parentId,
        reason: '无 parentSyncId 键时保持既有 parentName 反查行为');
  });
}
