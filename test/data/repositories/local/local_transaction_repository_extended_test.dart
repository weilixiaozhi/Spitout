// LocalTransactionRepository 补充测试。
//
// 锚点：AA 分摊字段必须在落库前完成 JSON 合法性校验（审计 7 的存储层守卫），
// 共享账本 Editor 记的交易通过 categorySyncIdOverride 反查
// SharedLedgerCategories 转 synthetic Category（与 picker/统计口径一致）。
// 覆盖此前未触达的分支：AA JSON 错误路径、缺失实体报错、共享 hydration、
// 批量 syncId 更新的快照覆盖语义。
library;

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_transaction_repository.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalTransactionRepository repo;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalTransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createLedger({String name = '账本', String? syncId}) async {
    final id = await db
        .into(db.ledgers)
        .insert(LedgersCompanion.insert(name: name, syncId: d.Value(syncId)));
    return id;
  }

  Future<int> insertTx({
    required int ledgerId,
    int amount = 100,
    String? categorySyncIdOverride,
    int? categoryId,
    String? aaParticipants,
    String? aaSplits,
    int? aaMode,
  }) =>
      repo.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: amount,
          categoryId: d.Value(categoryId),
          categorySyncIdOverride: d.Value(categorySyncIdOverride),
          aaParticipants: d.Value(aaParticipants),
          aaSplits: d.Value(aaSplits),
          aaMode: d.Value(aaMode),
          happenedAt: d.Value(DateTime(2026, 8, 8, 12)),
        ),
      );

  group('AA JSON 存储层校验', () {
    test('addTransaction 非法 aaParticipants / aaSplits 抛 ArgumentError', () async {
      final ledgerId = await createLedger();
      expect(
        () => repo.addTransaction(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 100,
          happenedAt: DateTime(2026, 8, 8),
          aaParticipants: '不是JSON',
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.addTransaction(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 100,
          happenedAt: DateTime(2026, 8, 8),
          aaSplits: '{broken',
        ),
        throwsArgumentError,
      );
    });

    test('updateTransaction 非法 AA JSON 抛 ArgumentError', () async {
      final ledgerId = await createLedger();
      final txId = await insertTx(ledgerId: ledgerId);
      expect(
        () => repo.updateTransaction(
          id: txId,
          type: 'expense',
          amount: 200,
          happenedAt: DateTime(2026, 8, 8),
          aaParticipants: '[]]',
        ),
        throwsArgumentError,
      );
    });

    test('insertTransactionCompanion 非法 AA JSON 抛 ArgumentError', () async {
      final ledgerId = await createLedger();
      expect(
        () => repo.insertTransactionCompanion(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 100,
            aaParticipants: d.Value('{oops'),
            happenedAt: d.Value(DateTime(2026, 8, 8)),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('合法 JSON 数组/对象可写入', () async {
      final ledgerId = await createLedger();
      final txId = await insertTx(
        ledgerId: ledgerId,
        aaMode: 2,
        aaParticipants: '["u1","u2"]',
        aaSplits: '{"u1":"600","u2":"400"}',
      );
      final tx = await repo.getTransactionById(txId);
      expect(tx?.aaParticipants, '["u1","u2"]');
      expect(tx?.aaSplits, '{"u1":"600","u2":"400"}');
    });
  });

  group('缺失实体报错', () {
    test('updateTransaction 不存在的 id 抛 StateError', () async {
      expect(
        () => repo.updateTransaction(
          id: 999,
          type: 'expense',
          amount: 100,
          happenedAt: DateTime(2026, 8, 8),
        ),
        throwsStateError,
      );
    });

    test('appendEditHistory 不存在的交易抛 StateError', () async {
      expect(
        () => repo.appendEditHistory(
          recordId: 999,
          version: 2,
          summary: '编辑',
        ),
        throwsStateError,
      );
    });
  });

  group('共享账本 category hydration', () {
    Future<void> seedShared({
      required String ledgerSyncId,
      required String syncId,
      String name = '共享餐饮',
    }) =>
        db.into(db.sharedLedgerCategories).insert(
              SharedLedgerCategoriesCompanion.insert(
                ledgerSyncId: ledgerSyncId,
                syncId: syncId,
                name: name,
                kind: 'expense',
                updatedAt: DateTime(2026, 8, 8),
              ),
            );

    test('transactionsWithCategoryAll / getRecentTransactionsWithCategory '
        '把 override 转 synthetic Category', () async {
      final ledgerId = await createLedger(name: '共享', syncId: 'led-h1');
      await seedShared(ledgerSyncId: 'led-h1', syncId: 'cat-h1');
      await insertTx(
        ledgerId: ledgerId,
        categorySyncIdOverride: 'cat-h1',
      );

      final all = await repo.transactionsWithCategoryAll();
      final hydrated = all.single;
      expect(hydrated.category, isNotNull);
      expect(hydrated.category?.syncId, 'cat-h1');
      expect(hydrated.category?.id, syntheticIdForSyncId('cat-h1'));
      expect(hydrated.category?.id, lessThan(0));

      final recent = await repo.getRecentTransactionsWithCategory(
        ledgerId: ledgerId,
        limit: 10,
      );
      expect(recent.single.category?.name, '共享餐饮');
    });

    test('getTransactionsByDate 走共享 hydration', () async {
      final ledgerId = await createLedger(name: '共享', syncId: 'led-h2');
      await seedShared(ledgerSyncId: 'led-h2', syncId: 'cat-h2');
      await insertTx(
        ledgerId: ledgerId,
        categorySyncIdOverride: 'cat-h2',
      );

      final rows = await repo.getTransactionsByDate(
        ledgerId: ledgerId,
        date: DateTime(2026, 8, 8),
      );
      expect(rows.single.category?.name, '共享餐饮');
    });

    test('override 匹配不到共享分类 → category 保持 null', () async {
      final ledgerId = await createLedger(name: '共享', syncId: 'led-h3');
      await insertTx(
        ledgerId: ledgerId,
        categorySyncIdOverride: 'cat-missing',
      );

      final all = await repo.transactionsWithCategoryAll();
      expect(all.single.category, isNull);
    });

    test('watchTransactionsWithCategoryInMonth 输出 hydration 结果', () async {
      final ledgerId = await createLedger(name: '共享', syncId: 'led-h4');
      await seedShared(ledgerSyncId: 'led-h4', syncId: 'cat-h4');
      await insertTx(
        ledgerId: ledgerId,
        categorySyncIdOverride: 'cat-h4',
      );

      final rows = await repo
          .watchTransactionsWithCategoryInMonth(
            ledgerId: ledgerId,
            month: DateTime(2026, 8),
          )
          .first;
      expect(rows.single.category?.name, '共享餐饮');
    });
  });

  group('批量 syncId 更新快照语义', () {
    test('overwriteSnapshot=false 不动币种/AA；true 时按成对约束补快照', () async {
      final ledgerId = await createLedger(name: 'batch-snap');
      await repo.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 100,
          syncId: d.Value('snap-1'),
          currencyCode: d.Value('USD'),
          nativeAmount: d.Value(720),
          happenedAt: d.Value(DateTime(2026, 8, 8)),
        ),
      );
      await repo.insertTransactionCompanion(
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 200,
          syncId: d.Value('snap-2'),
          happenedAt: d.Value(DateTime(2026, 8, 8)),
        ),
      );

      // 不覆盖快照：只改金额/类型，保留旧币种与快照
      await repo.updateTransactionsBatchBySyncId([
        TransactionUpdateBySyncIdData(
          syncId: 'snap-1',
          type: 'expense',
          amount: 150,
          happenedAt: DateTime(2026, 8, 8),
        ),
      ]);
      final keep = await repo.getTransactionBySyncId('snap-1');
      expect(keep?.amount, 150);
      expect(keep?.currencyCode, 'USD');
      expect(keep?.nativeAmount, 720);

      // 覆盖快照但缺币种 → 清空快照，避免破坏成对 CHECK
      await repo.updateTransactionsBatchBySyncId([
        TransactionUpdateBySyncIdData(
          syncId: 'snap-2',
          type: 'expense',
          amount: 300,
          happenedAt: DateTime(2026, 8, 8),
          overwriteSnapshot: true,
          currencyCode: 'JPY',
        ),
      ]);
      final overwritten = await repo.getTransactionBySyncId('snap-2');
      expect(overwritten?.currencyCode, 'JPY');
      expect(overwritten?.nativeAmount, 300);
    });

    test('空更新列表直接返回空 map', () async {
      expect(
        await repo.updateTransactionsBatchBySyncId([]),
        isEmpty,
      );
    });
  });

  group('watchRecentTransactions 与月内 watch', () {
    test('watchRecentTransactions limit 生效', () async {
      final ledgerId = await createLedger();
      await insertTx(ledgerId: ledgerId, amount: 100);
      await insertTx(ledgerId: ledgerId, amount: 200);

      final recent = await repo.watchRecentTransactions(
        ledgerId: ledgerId,
        limit: 1,
      ).first;
      expect(recent.single.amount, 200);
    });

    test('watchTransactionsForCategoryInRange 按分类/类型过滤', () async {
      final ledgerId = await createLedger();
      final rows = await repo
          .watchTransactionsForCategoryInRange(
            ledgerId: ledgerId,
            start: DateTime(2026, 8, 1),
            end: DateTime(2026, 9, 1),
            type: 'expense',
          )
          .first;
      expect(rows, isEmpty);
    });
  });
}
