import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';

/// 数据层 [LocalRepository.purgeSharedLedger] 空 syncId 守卫的单元测试。
///
/// 设计意图：逐本清除是「服务器确认移除（被踢/删除/退出）」后的本地兜底，
/// 必须以 syncId/localId 精确锁定目标，绝不能误删空 syncId 的个人账本。
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
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: localId,
            type: 'expense',
            amount: 1000,
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
            amount: 9900,
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
