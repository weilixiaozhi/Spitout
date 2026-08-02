/// [LocalLedgerRepository.normalizeOrphanCloudLedgers] 归一化单测。
///
/// 场景背景：整库文件级备份恢复会原子覆盖 sqlite、绕过归属闸门，把
/// `storageMode='cloud'` / `isShared=true` 的账本原样写回本地。若此时设备
/// 处于未登录（本地模式），这些账本就成了「孤儿云端账本」——能记账但转本地
/// 入口强依赖登录态，用户卡死在云分区。归一化是这条路径的兜底：把孤儿云端
/// 账本就地改写成纯本地账本，数据一行不删。
///
/// 覆盖：分计数语义、6 字段清理、镜像表先删、幂等、纯本地账本零影响。
library;

// hide isNull:drift 与 matcher 同时导出该符号,测试里用的是 matcher 版本。
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_ledger_repository.dart';

void main() {
  late SpitoutDatabase db;
  late LocalLedgerRepository repo;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalLedgerRepository(db);
  });

  tearDown(() => db.close());

  /// 个人云端账本：storageMode='cloud' 且非共享。
  Future<int> seedCloudPersonal(String syncId) => db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          name: 'Cloud-$syncId',
          syncId: Value(syncId),
          storageMode: const Value('cloud'),
          isShared: const Value(false),
          myRole: const Value('owner'),
          ownerUserId: Value('remote-user-$syncId'),
        ),
      );

  /// 共享账本：isShared=true，带 ledgerMembers 镜像行（协作侧数据）。
  Future<int> seedShared(String syncId) async {
    final id = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Shared-$syncId',
            syncId: Value(syncId),
            storageMode: const Value('cloud'),
            isShared: const Value(true),
            myRole: const Value('editor'),
            memberCount: const Value(3),
            ownerUserId: Value('remote-owner-$syncId'),
          ),
        );
    final now = DateTime.now();
    await db.into(db.ledgerMembers).insert(
          LedgerMembersCompanion.insert(
            ledgerSyncId: syncId,
            userId: 'remote-owner-$syncId',
            role: 'owner',
            joinedAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.sharedLedgerCategories).insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: syncId,
            syncId: 'cat-$syncId',
            name: '餐饮',
            kind: 'expense',
            updatedAt: now,
          ),
        );
    return id;
  }

  /// 纯本地账本：归一化必须一行不动。
  Future<int> seedLocal() => db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          name: 'Local',
          storageMode: const Value('local'),
          isShared: const Value(false),
        ),
      );

  test('孤儿云端账本被归一化为纯本地账本，并按 isShared 原值分计数', () async {
    final cloudId = await seedCloudPersonal('sync-cloud');
    final sharedId = await seedShared('sync-shared');

    final counts = await repo.normalizeOrphanCloudLedgers();

    // 分计数按 isShared 原值区分：个人云端 1 本、共享 1 本
    expect(counts.personal, 1);
    expect(counts.shared, 1);

    for (final id in [cloudId, sharedId]) {
      final l = await (db.select(db.ledgers)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(l.storageMode, 'local', reason: '归属必须落到本地');
      expect(l.isShared, isFalse, reason: '共享标记必须清除，否则仍被云闸门拦截');
      expect(l.syncId, isNull, reason: 'syncId 残留会让后续同步误认领');
      expect(l.myRole, 'owner', reason: '本地账本的持有者只能是自己');
      expect(l.memberCount, 1);
      expect(l.ownerUserId, isNull);
    }
  });

  test('共享账本的镜像表数据被先行清理，不留协作残留', () async {
    await seedShared('sync-shared');

    await repo.normalizeOrphanCloudLedgers();

    expect(await db.select(db.ledgerMembers).get(), isEmpty);
    expect(await db.select(db.sharedLedgerCategories).get(), isEmpty);
  });

  test('幂等：重复调用第二次返回零计数且不抛错', () async {
    await seedCloudPersonal('sync-cloud');
    await seedShared('sync-shared');

    final first = await repo.normalizeOrphanCloudLedgers();
    final second = await repo.normalizeOrphanCloudLedgers();

    expect(first.personal, 1);
    expect(first.shared, 1);
    expect(second.personal, 0);
    expect(second.shared, 0);
  });

  test('纯本地账本完全不受影响，计数为零', () async {
    final localId = await seedLocal();

    final counts = await repo.normalizeOrphanCloudLedgers();

    expect(counts.personal, 0);
    expect(counts.shared, 0);
    final l = await (db.select(db.ledgers)..where((t) => t.id.equals(localId)))
        .getSingle();
    expect(l.storageMode, 'local');
    expect(l.isShared, isFalse);
  });

  test('交易数据不被删除：归一化只改归属字段', () async {
    final cloudId = await seedCloudPersonal('sync-cloud');
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: cloudId,
            type: 'expense',
            amount: 12.5,
          ),
        );

    await repo.normalizeOrphanCloudLedgers();

    final txs = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(cloudId)))
        .get();
    expect(txs, hasLength(1), reason: '归一化是就地改写归属，绝不能丢用户数据');
  });
}
