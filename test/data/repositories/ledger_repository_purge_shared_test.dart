import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';

/// 数据层 [LocalRepository.purgeSharedLedger] 单元测试。
///
/// 设计意图：本次修复的核心是「本地删除共享账本时，必须把本地所有相关行
/// （账本行、成员镜像、共享分类镜像、交易、以及会触发重新 upsert 的
/// local_changes 删除标记）一次性清干净，且不向 local_changes 写入任何
/// 待推送记录」。本测试直接验证这套清理逻辑，覆盖：
///   1) 单条共享账本：镜像表 / 交易 / local_changes 全部清掉；
///   2) dup 行（同一 syncId 多条本地行）：所有重复行都清掉；
///   3) 无关的本地账本不被误伤。
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

  /// 写入一条共享账本，并附带成员镜像 / 共享分类 / 交易 / 一条 local_changes 删除标记。
  /// 返回账本本地自增 id。
  Future<int> seedSharedLedger(String extId, String myRole) async {
    final localId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Shared-$extId',
            syncId: Value(extId),
            isShared: const Value(true),
            myRole: Value(myRole),
          ),
        );

    // 成员镜像：owner + 本人（collaborator）
    await db.into(db.ledgerMembers).insert(
          LedgerMembersCompanion.insert(
            ledgerSyncId: extId,
            userId: 'owner-u',
            role: 'owner',
            joinedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
    await db.into(db.ledgerMembers).insert(
          LedgerMembersCompanion.insert(
            ledgerSyncId: extId,
            userId: 'me-u',
            role: myRole,
            joinedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    // 共享分类镜像
    await db.into(db.sharedLedgerCategories).insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: extId,
            syncId: 'cat-$extId',
            name: 'Food',
            kind: 'expense',
            updatedAt: DateTime.now(),
          ),
        );

    // 交易（挂在账本本地 id 上）
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: localId,
            type: 'expense',
            amount: 10.0,
            syncId: Value('tx-$extId'),
          ),
        );

    // 关键：一条待推送的「删除」标记。若 purge 不清理它，sync 会把删除
    // 重新 upsert 回来（即本次修复要解决的"幽灵账本复活"）。
    await db.into(db.localChanges).insert(
          LocalChangesCompanion.insert(
            entityType: 'ledger',
            entityId: localId,
            entitySyncId: extId,
            ledgerId: localId,
            action: 'delete',
          ),
        );

    return localId;
  }

  /// 某 syncId 的账本行是否还存在。
  Future<bool> ledgerExists(String extId) async =>
      (await (db.select(db.ledgers)..where((l) => l.syncId.equals(extId))).get())
          .isNotEmpty;

  test('单条共享账本 purge：本地所有相关行被清掉，且不残留删除标记', () async {
    final localId = await seedSharedLedger('ext-1', 'editor');

    // 执行被测方法
    await repo.purgeSharedLedger('ext-1');

    // 账本行消失
    expect(await ledgerExists('ext-1'), isFalse);
    // 成员镜像清空
    expect(
      await (db.select(db.ledgerMembers)
            ..where((m) => m.ledgerSyncId.equals('ext-1')))
          .get(),
      isEmpty,
    );
    // 共享分类镜像清空
    expect(
      await (db.select(db.sharedLedgerCategories)
            ..where((c) => c.ledgerSyncId.equals('ext-1')))
          .get(),
      isEmpty,
    );
    // 交易清空
    expect(
      await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(localId)))
          .get(),
      isEmpty,
    );
    // 关键的删除标记被清掉（否则 sync 会重新 upsert 回来）
    expect(
      await (db.select(db.localChanges)
            ..where((c) => c.entityType.equals('ledger'))
            ..where((c) => c.entityId.equals(localId)))
          .get(),
      isEmpty,
    );
  });

  test('dup 行（同一 syncId 多条本地行）：所有重复行都被清掉', () async {
    // 两条本地行共享同一个 syncId，且各带一条交易
    final idA = await seedSharedLedger('ext-dup', 'owner');
    final idB = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Shared-ext-dup-B',
            syncId: const Value('ext-dup'),
            isShared: const Value(true),
            myRole: const Value('owner'),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: idB,
            type: 'expense',
            amount: 20.0,
            syncId: const Value('tx-dup-b'),
          ),
        );

    // 执行被测方法（不传 localId，依赖内部按 syncId 取全部本地行）
    await repo.purgeSharedLedger('ext-dup');

    // 两条本地行都应消失
    expect(await ledgerExists('ext-dup'), isFalse);
    // 两笔交易都应消失
    expect(
      await (db.select(db.transactions)
            ..where((t) => t.ledgerId.isIn([idA, idB])))
          .get(),
      isEmpty,
    );
  });

  test('purge 不应误伤无关的本地账本', () async {
    final localId = await seedSharedLedger('ext-1', 'editor');

    // 一条完全无关的本地账本（非共享），带自己的交易与 local_changes
    final otherId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Local-Only',
            syncId: const Value.absent(),
            isShared: const Value(false),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: otherId,
            type: 'expense',
            amount: 99.0,
            syncId: const Value('tx-other'),
          ),
        );
    await db.into(db.localChanges).insert(
          LocalChangesCompanion.insert(
            entityType: 'ledger',
            entityId: otherId,
            entitySyncId: 'other',
            ledgerId: otherId,
            action: 'upsert',
          ),
        );

    // 只清 ext-1
    await repo.purgeSharedLedger('ext-1');

    // 无关账本仍在
    expect(await ledgerExists('ext-1'), isFalse);
    final other = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(otherId)))
        .get();
    expect(other, hasLength(1));
    // 无关账本的交易与 local_changes 仍在
    expect(
      await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(otherId)))
          .get(),
      hasLength(1),
    );
    expect(
      await (db.select(db.localChanges)
            ..where((c) => c.entityId.equals(otherId)))
          .get(),
      hasLength(1),
    );
    // 确认 localId 变量被使用，避免未使用告警
    expect(localId, isPositive);
  });
}
