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
