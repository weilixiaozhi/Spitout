// 共享账本 synthetic 分类树监听测试。
//
// 锁死分类汇总页的渲染前提：watchCategoryWithSubs 对负数 synthetic id 必须
// 从 SharedLedgerCategories 镜像返回「一级 + 全部二级」，否则详情页列表会把
// override 交易全部跳过，表现为有汇总数字但没有明细。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  /// 写入共享账本的一级分类「交通」和二级分类「打车」镜像行。
  Future<void> seedSharedParentAndChild(
    String ledgerSyncId,
  ) async {
    await db
        .into(db.sharedLedgerCategories)
        .insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: ledgerSyncId,
            syncId: 'c1',
            name: '交通',
            kind: 'expense',
            updatedAt: DateTime.now(),
          ),
        );
    await db
        .into(db.sharedLedgerCategories)
        .insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: ledgerSyncId,
            syncId: 'c2',
            name: '打车',
            kind: 'expense',
            level: const Value(2),
            parentSyncId: const Value('c1'),
            updatedAt: DateTime.now(),
          ),
        );
  }

  /// 插入一笔共享账本 Editor 视角的交易：categoryId 为空，真实分类引用在
  /// categorySyncIdOverride 中。返回账本 id 与交易 id。
  Future<(int, int)> seedSharedTransaction(
    String ledgerSyncId,
  ) async {
    final ledgerId = await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            name: 'Shared',
            syncId: Value(ledgerSyncId),
            storageMode: const Value('cloud'),
            isShared: const Value(true),
            myRole: const Value('editor'),
          ),
        );
    final txId = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 2000,
            categorySyncIdOverride: const Value('c2'),
          ),
        );
    return (ledgerId, txId);
  }

  test(
    '共享交易按父分类汇总时，categoryId 回填子分类 synthetic id，详情页不会退回父分类',
    () async {
      await seedSharedParentAndChild('LS-TX');
      final (ledgerId, _) = await seedSharedTransaction('LS-TX');

      final txs = await repo
          .watchTransactionsByCategory(
            syntheticIdForSyncId('c1'),
            ledgerId: ledgerId,
            includeSubCategories: true,
          )
          .first;

      expect(txs, hasLength(1));
      expect(
        txs.first.categoryId,
        syntheticIdForSyncId('c2'),
        reason: '共享交易的分类引用在 categorySyncIdOverride，'
            '返回流必须回填为子分类 synthetic id，详情页才能按实际子分类渲染',
      );
    },
  );

  test(
    'transactionsWithCategoryAll 的共享二级分类保留 parentId，导出才能拆出二级分类',
    () async {
      await seedSharedParentAndChild('LS-EXP');
      final (ledgerId, _) = await seedSharedTransaction('LS-EXP');

      final rows = await repo.transactionsWithCategoryAll(ledgerId: ledgerId);

      expect(rows, hasLength(1));
      final cat = rows.first.category;
      expect(cat, isNotNull);
      expect(cat!.level, 2);
      expect(
        cat.parentId,
        syntheticIdForSyncId('c1'),
        reason: '合成 Category 必须由 parentSyncId 派生 parentId，'
            '导出服务靠 level==2 且 parentId!=null 判断二级分类',
      );
    },
  );

  test('负数 synthetic id → 返回共享一级 + 全部二级分类', () async {
    await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            name: 'Shared',
            syncId: const Value('LS1'),
            storageMode: const Value('cloud'),
            isShared: const Value(true),
            myRole: const Value('editor'),
          ),
        );
    await db
        .into(db.sharedLedgerCategories)
        .insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: 'LS1',
            syncId: 'c1',
            name: '交通',
            kind: 'expense',
            updatedAt: DateTime.now(),
          ),
        );
    await db
        .into(db.sharedLedgerCategories)
        .insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: 'LS1',
            syncId: 'c2',
            name: '地铁',
            kind: 'expense',
            level: const Value(2),
            parentSyncId: const Value('c1'),
            updatedAt: DateTime.now(),
          ),
        );

    final result = await repo
        .watchCategoryWithSubs(syntheticIdForSyncId('c1'))
        .first;

    expect(result, hasLength(2));
    expect(result.first.id, syntheticIdForSyncId('c1'));
    expect(result.first.name, '交通');
    expect(result.first.parentId, isNull);
    expect(result.last.id, syntheticIdForSyncId('c2'));
    expect(result.last.parentId, syntheticIdForSyncId('c1'));
  });

  test('不存在的 synthetic id → 返回空列表', () async {
    final result = await repo.watchCategoryWithSubs(-999999).first;
    expect(result, isEmpty);
  });

  test('findCategoryBySyntheticId 按 ledgerSyncId 过滤,避免跨账本取错分类', () async {
    await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            name: '账本A',
            syncId: const Value('LS-A'),
            storageMode: const Value('cloud'),
            isShared: const Value(true),
            myRole: const Value('editor'),
          ),
        );
    await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            name: '账本B',
            syncId: const Value('LS-B'),
            storageMode: const Value('cloud'),
            isShared: const Value(true),
            myRole: const Value('editor'),
          ),
        );
    await db
        .into(db.sharedLedgerCategories)
        .insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: 'LS-A',
            syncId: 'collide',
            name: '甲账本分类',
            kind: 'expense',
            updatedAt: DateTime.now(),
          ),
        );
    await db
        .into(db.sharedLedgerCategories)
        .insert(
          SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: 'LS-B',
            syncId: 'collide',
            name: '乙账本分类',
            kind: 'expense',
            updatedAt: DateTime.now(),
          ),
        );

    final synthId = syntheticIdForSyncId('collide');
    final fromB = await repo.findCategoryBySyntheticId(
      synthId,
      ledgerSyncId: 'LS-B',
    );
    expect(fromB, isNotNull);
    expect(fromB!.name, '乙账本分类');
  });
}
