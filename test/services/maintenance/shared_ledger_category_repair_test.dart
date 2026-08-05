// 共享账本分类存储表示修复服务测试。
//
// 锁死两类历史脏数据修复：
// - Editor 视角：正数分类 id（错绑到成员本地分类）→ categorySyncIdOverride；
// - Owner 视角：override → 主表正数分类 id；
// 并保证个人账本与无法映射的分类不被误动。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/services/maintenance/shared_ledger_category_repair.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late SharedLedgerCategoryRepair repair;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repair = SharedLedgerCategoryRepair(db: db);
  });

  tearDown(() async => db.close());

  Future<int> insertLedger({
    required String syncId,
    required bool isShared,
    required String myRole,
  }) {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: syncId,
            syncId: Value(syncId),
            storageMode: const Value('cloud'),
            isShared: Value(isShared),
            myRole: Value(myRole),
          ),
        );
  }

  Future<void> insertSharedCategory(String ledgerSyncId, String syncId) {
    return db.into(db.sharedLedgerCategories).insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: ledgerSyncId,
            syncId: syncId,
            name: '交通',
            kind: 'expense',
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<int> insertLocalCategory(String syncId) {
    return db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: '交通',
            kind: 'expense',
            syncId: Value(syncId),
          ),
        );
  }

  Future<Transaction> getTx(int txId) async {
    return (await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle());
  }

  test('Editor 脏数据: 正数分类 syncId 命中共享镜像 → 转为 override', () async {
    final lid = await insertLedger(
      syncId: 'L1',
      isShared: true,
      myRole: 'editor',
    );
    final catId = await insertLocalCategory('cat-traffic');
    await insertSharedCategory('L1', 'cat-traffic');
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 1000,
            syncId: const Value('tx-editor-dirty'),
            categoryId: Value(catId),
          ),
        );

    final result = await repair.repair();
    expect(result.fixedTransactions, 1);

    final tx = await getTx(txId);
    expect(tx.categoryId, isNull);
    expect(tx.categorySyncIdOverride, 'cat-traffic');
  });

  test('Editor 双写混合: override 在镜像中 → 清掉正数 id 保留 override', () async {
    final lid = await insertLedger(
      syncId: 'L2',
      isShared: true,
      myRole: 'editor',
    );
    final catId = await insertLocalCategory('cat-traffic');
    await insertSharedCategory('L2', 'cat-traffic');
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 2000,
            syncId: const Value('tx-editor-mixed'),
            categoryId: Value(catId),
            categorySyncIdOverride: const Value('cat-traffic'),
          ),
        );

    final result = await repair.repair();
    expect(result.fixedTransactions, 1);

    final tx = await getTx(txId);
    expect(tx.categoryId, isNull);
    expect(tx.categorySyncIdOverride, 'cat-traffic');
  });

  test('Owner 脏数据: override → 主表正数分类 id', () async {
    final lid = await insertLedger(
      syncId: 'L3',
      isShared: true,
      myRole: 'owner',
    );
    final catId = await insertLocalCategory('cat-traffic');
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 3000,
            syncId: const Value('tx-owner-dirty'),
            categorySyncIdOverride: const Value('cat-traffic'),
          ),
        );

    final result = await repair.repair();
    expect(result.fixedTransactions, 1);

    final tx = await getTx(txId);
    expect(tx.categoryId, catId);
    expect(tx.categorySyncIdOverride, isNull);
  });

  test('Editor 镜像为空 → 本次跳过且不计为已修复', () async {
    final lid = await insertLedger(
      syncId: 'L5',
      isShared: true,
      myRole: 'editor',
    );
    final catId = await insertLocalCategory('cat-traffic');
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 4000,
            syncId: const Value('tx-editor-no-mirror'),
            categoryId: Value(catId),
          ),
        );

    final result = await repair.repair();
    expect(result.fixedTransactions, 0);
    expect(result.skippedLedgers, 1);
    expect((await getTx(txId)).categoryId, catId);
  });

  test('无法映射到共享镜像的正数分类与个人账本不被误动', () async {
    // 个人账本：即使有分类也不应被扫描
    final personalLid = await insertLedger(
      syncId: 'P1',
      isShared: false,
      myRole: 'owner',
    );
    final personalCatId = await insertLocalCategory('cat-personal');
    final personalTxId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: personalLid,
            type: 'expense',
            amount: 100,
            syncId: const Value('tx-personal'),
            categoryId: Value(personalCatId),
          ),
        );

    // 共享账本 Editor，但本地分类 syncId 不在共享镜像中
    final sharedLid = await insertLedger(
      syncId: 'L4',
      isShared: true,
      myRole: 'editor',
    );
    final unknownCatId = await insertLocalCategory('cat-unknown');
    await insertSharedCategory('L4', 'cat-traffic');
    final unknownTxId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: sharedLid,
            type: 'expense',
            amount: 500,
            syncId: const Value('tx-unknown'),
            categoryId: Value(unknownCatId),
          ),
        );

    final result = await repair.repair();
    expect(result.fixedTransactions, 0);

    expect((await getTx(personalTxId)).categoryId, personalCatId);
    expect((await getTx(unknownTxId)).categoryId, unknownCatId);
  });
}
