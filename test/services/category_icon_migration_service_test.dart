// CategoryIconMigrationService 迁移测试。
//
// 覆盖核心契约：
//   1. 订阅服务/转账的存量默认分类（确定性 syncId + 旧图标）被回写为新图标；
//   2. 共享账本镜像表同步更新；
//   3. 手动换过图标或非默认分类不受影响；
//   4. 每个被迁移分类登记一条 user-global 待推送变更（ledgerId=0）；
//   5. 幂等：第二次调用跳过（prefs 标记位命中），不重复写变更。

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/services/data/category_icon_migration_service.dart';
import 'package:spitout/services/data/seed_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => db.close());

  String syncId(String key) => SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 1,
        key: key,
      );

  Future<int> insertCategory({
    required String name,
    required String icon,
    required String syncIdValue,
  }) {
    return db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            kind: 'expense',
            icon: Value(icon),
            syncId: Value(syncIdValue),
          ),
        );
  }

  test('默认订阅/转账分类图标被迁移，其他分类不受影响', () async {
    final subId = await insertCategory(
      name: '订阅服务',
      icon: 'repeat',
      syncIdValue: syncId('subscription'),
    );
    final transferId = await insertCategory(
      name: '转账',
      icon: 'arrowLeftRight',
      syncIdValue: syncId('transfer'),
    );
    final customId = await insertCategory(
      name: '自定义分类',
      icon: 'repeat',
      syncIdValue: 'custom-random-v4-1',
    );

    await db.into(db.sharedLedgerCategories).insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: 'ledger-1',
            syncId: syncId('subscription'),
            name: '订阅服务',
            kind: 'expense',
            icon: const Value('repeat'),
            updatedAt: DateTime.now(),
          ),
        );

    await CategoryIconMigrationService.migrate(
      db: db,
      changeRecorder: ChangeTracker(db),
    );

    final sub = await (db.select(db.categories)
          ..where((c) => c.id.equals(subId)))
        .getSingle();
    final transfer = await (db.select(db.categories)
          ..where((c) => c.id.equals(transferId)))
        .getSingle();
    final custom = await (db.select(db.categories)
          ..where((c) => c.id.equals(customId)))
        .getSingle();

    expect(sub.icon, 'calendarClock');
    expect(transfer.icon, 'handCoins');
    expect(custom.icon, 'repeat', reason: '非默认分类不应被迁移');

    final mirror = await (db.select(db.sharedLedgerCategories)
          ..where((s) => s.syncId.equals(syncId('subscription'))))
        .getSingle();
    expect(mirror.icon, 'calendarClock');

    final changes = await (db.select(db.localChanges)
          ..where((c) => c.entityType.equals('category')))
        .get();
    expect(changes, hasLength(2));
    expect(
      changes.map((c) => c.entitySyncId),
      containsAll([syncId('subscription'), syncId('transfer')]),
    );
    expect(
      changes.every((c) => c.ledgerId == 0 && c.action == 'update'),
      isTrue,
    );
  });

  test('手动换过图标的默认分类不被覆盖', () async {
    final subId = await insertCategory(
      name: '订阅服务',
      icon: 'star',
      syncIdValue: syncId('subscription'),
    );

    await CategoryIconMigrationService.migrate(
      db: db,
      changeRecorder: ChangeTracker(db),
    );

    final sub = await (db.select(db.categories)
          ..where((c) => c.id.equals(subId)))
        .getSingle();
    expect(sub.icon, 'star');
  });

  test('幂等：第二次调用跳过，不重复写待推送变更', () async {
    await insertCategory(
      name: '订阅服务',
      icon: 'repeat',
      syncIdValue: syncId('subscription'),
    );
    await insertCategory(
      name: '转账',
      icon: 'arrowLeftRight',
      syncIdValue: syncId('transfer'),
    );

    final tracker = ChangeTracker(db);
    await CategoryIconMigrationService.migrate(db: db, changeRecorder: tracker);
    await CategoryIconMigrationService.migrate(db: db, changeRecorder: tracker);

    final changes = await (db.select(db.localChanges)
          ..where((c) => c.entityType.equals('category')))
        .get();
    expect(changes, hasLength(2));
  });
}
