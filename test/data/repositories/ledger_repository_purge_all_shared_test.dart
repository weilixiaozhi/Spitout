import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';

/// 数据层 [LocalRepository.purgeAllSharedLedgers] 与
/// [LocalRepository.purgeSharedLedger] 空 syncId 守卫的单元测试。
///
/// 设计意图：「云端下线」（登出 / 切本地 / 远端确认宕机）场景需要一个批量
/// 原语，以 `isShared=true` 为唯一闸门全量清除本地共享账本，且与 syncId
/// 是否为空完全无关——个人账本（syncId 往往为 null/空）绝不能被误伤。
/// 本测试覆盖：
///   1) 2 共享 + 1 个人：仅个人账本残留，镜像表 / 交易 / local_changes 清干净；
///   2) 空 syncId 的共享账本也被批量清（isShared 闸门与 syncId 无关）；
///   3) 幂等：无共享账本时调用不出错、不影响个人数据；
///   4) 逐本原语守卫：purgeSharedLedger('') 不误删空 syncId 的个人账本；
///   5) 逐本原语 localId 优先：externalId 为空但传 localId 时仅清该账本。
void main() {
  late SpitoutDatabase db;
  late LocalRepository repo;
  late ChangeTracker tracker;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
  });

  tearDown(() => db.close());

  /// 写入一条共享账本（成员镜像 / 共享分类镜像 / 交易 / local_changes 各一份）。
  /// [extId] 传 null 表示 syncId 缺省（离线新建未上云的半截行）。
  Future<int> seedSharedLedger(String? extId, String myRole) async {
    final localId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Shared-${extId ?? 'nosync'}',
            syncId: extId == null ? const Value.absent() : Value(extId),
            isShared: const Value(true),
            myRole: Value(myRole),
          ),
        );
    if (extId != null && extId.isNotEmpty) {
      await db.into(db.ledgerMembers).insert(
            LedgerMembersCompanion.insert(
              ledgerSyncId: extId,
              userId: 'owner-u',
              role: 'owner',
              joinedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      await db.into(db.sharedLedgerCategories).insert(
            SharedLedgerCategoriesCompanion.insert(
              ledgerSyncId: extId,
              syncId: 'cat-$extId',
              name: 'Food',
              kind: 'expense',
              updatedAt: DateTime.now(),
            ),
          );
    }
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: localId,
            type: 'expense',
            amount: 10.0,
            syncId: Value('tx-${extId ?? localId}'),
          ),
        );
    await db.into(db.localChanges).insert(
          LocalChangesCompanion.insert(
            entityType: 'ledger',
            entityId: localId,
            entitySyncId: extId ?? '',
            ledgerId: localId,
            action: 'upsert',
          ),
        );
    return localId;
  }

  /// 写入一条个人账本（非共享），带自己的交易与 local_changes。
  /// [syncId] 默认 null——个人账本往往从未上云，这是空 syncId 误删场景的关键。
  Future<int> seedPersonalLedger({String? syncId}) async {
    final localId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Personal',
            syncId: syncId == null ? const Value.absent() : Value(syncId),
            isShared: const Value(false),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: localId,
            type: 'expense',
            amount: 99.0,
            syncId: const Value.absent(),
          ),
        );
    await db.into(db.localChanges).insert(
          LocalChangesCompanion.insert(
            entityType: 'ledger',
            entityId: localId,
            entitySyncId: 'personal',
            ledgerId: localId,
            action: 'upsert',
          ),
        );
    return localId;
  }

  Future<List<Ledger>> allLedgers() => db.select(db.ledgers).get();

  test('purgeAllSharedLedgers：2 共享 + 1 个人 → 仅个人残留，级联表清干净', () async {
    final s1 = await seedSharedLedger('ext-1', 'owner');
    final s2 = await seedSharedLedger('ext-2', 'editor');
    final p1 = await seedPersonalLedger();

    await repo.purgeAllSharedLedgers();

    // 账本行：仅个人账本残留
    final remaining = await allLedgers();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, p1);

    // 共享账本的交易 / local_changes 全清
    expect(
      await (db.select(db.transactions)
            ..where((t) => t.ledgerId.isIn([s1, s2])))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.localChanges)
            ..where((c) => c.ledgerId.isIn([s1, s2])))
          .get(),
      isEmpty,
    );
    // 镜像表全清
    expect(await db.select(db.ledgerMembers).get(), isEmpty);
    expect(await db.select(db.sharedLedgerCategories).get(), isEmpty);

    // 个人账本的交易与 local_changes 完好
    expect(
      await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(p1)))
          .get(),
      hasLength(1),
    );
    expect(
      await (db.select(db.localChanges)
            ..where((c) => c.ledgerId.equals(p1)))
          .get(),
      hasLength(1),
    );
  });

  test('purgeAllSharedLedgers：空 syncId 的共享账本也被清，空 syncId 个人账本不受影响',
      () async {
    // 离线新建未上云的共享账本（syncId 缺省）——isShared 闸门必须覆盖它
    final sNoSync = await seedSharedLedger(null, 'owner');
    // 从未上云的个人账本（syncId 同样缺省）——绝不能被误伤
    final pNoSync = await seedPersonalLedger();

    await repo.purgeAllSharedLedgers();

    final remaining = await allLedgers();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, pNoSync);
    expect(
      await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(sNoSync)))
          .get(),
      isEmpty,
    );
  });

  test('purgeAllSharedLedgers：无共享账本时幂等 no-op，个人数据零变化', () async {
    final p1 = await seedPersonalLedger();

    // 连调两次都不应抛错
    await repo.purgeAllSharedLedgers();
    await repo.purgeAllSharedLedgers();

    expect((await allLedgers()).single.id, p1);
    expect(
      await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(p1)))
          .get(),
      hasLength(1),
    );
  });

  test('purgeSharedLedger 空 externalId 守卫：不误删空 syncId 的个人账本', () async {
    // 空 syncId 的个人账本 + 一条正常共享账本
    final pNoSync = await seedPersonalLedger();
    final s1 = await seedSharedLedger('ext-1', 'owner');

    // 传空串且无 localId：守卫应直接幂等返回，什么都不删。
    // 修复前 WHERE syncId='' 会误命中所有空 syncId 行（含个人账本）。
    await repo.purgeSharedLedger('');

    final remaining = await allLedgers();
    expect(remaining.map((l) => l.id), containsAll([pNoSync, s1]));
    expect(remaining, hasLength(2));
  });

  test('purgeSharedLedger 空 externalId + localId：仅清 localId 锁定的账本', () async {
    final pNoSync = await seedPersonalLedger();
    final sNoSync = await seedSharedLedger(null, 'owner');

    // externalId 为空但 localId 锁定共享账本：只清它，个人账本完好
    await repo.purgeSharedLedger('', localId: sNoSync);

    final remaining = await allLedgers();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, pNoSync);
  });
}
