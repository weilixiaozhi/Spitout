library;

/// P1 幂等测试：importTransactions 按 syncId 去重，重复导入不会产生重复行。
///
/// 修复前 bug：云端全量恢复时 transactions.syncId 无 UNIQUE 约束，同 syncId
/// 的云端交易会被再次 INSERT（盲插），导致每次下拉刷新数据翻倍。
/// 修复后：导入前预取目标账本已有 syncId 集合，命中即跳过（跨批次 / 本批次内）。

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/services/import/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;
  late DataImportService service;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    service = DataImportService();
  });

  tearDown(() async => db.close());

  Future<void> seedLedger(int id) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES ($id, 'L$id', 'CNY')");
  }

  Future<int> countInLedger(int ledgerId) async =>
      (await (db.select(db.transactions)
                ..where((t) => t.ledgerId.equals(ledgerId)))
              .get())
          .length;

  ImportTransaction makeTx(String syncId, {double amount = 10.0}) =>
      ImportTransaction(
        type: 'expense',
        amount: amount,
        happenedAt: DateTime(2026, 7, 1),
        syncId: syncId,
      );

  group('P1 按 syncId 幂等', () {
    test('跨批次重复 syncId 不重复插入', () async {
      await seedLedger(1);
      // 首批：2 条新交易
      final r1 = await service.importTransactions(
        repo, 1, [makeTx('tx-A'), makeTx('tx-B')], categoryCache: {});
      expect(r1.inserted, 2);

      // 第二批：tx-A 已存在（应跳过），tx-C 为新（应插入）
      final r2 = await service.importTransactions(
        repo, 1, [makeTx('tx-A'), makeTx('tx-C')], categoryCache: {});
      expect(r2.inserted, 1, reason: '已存在的 tx-A 应被去重跳过');

      // 最终本地只有 3 条，不会翻倍
      expect(await countInLedger(1), 3);
      final synced =
          (await db.select(db.transactions).get()).map((t) => t.syncId).toList();
      expect(synced.where((s) => s == 'tx-A').length, 1,
          reason: 'tx-A 只能出现一次');
    });

    test('本批次内重复 syncId 只插一条', () async {
      await seedLedger(2);
      final r = await service.importTransactions(
        repo, 2,
        [makeTx('dup-x'), makeTx('dup-x'), makeTx('dup-x')],
        categoryCache: {});
      expect(r.inserted, 1, reason: '同批次同 syncId 只应插入一条');
      expect(await countInLedger(2), 1);
    });

    test('无 syncId 的 CSV 记录不被误杀', () async {
      await seedLedger(3);
      final r = await service.importTransactions(
        repo, 3,
        [
          ImportTransaction(
              type: 'expense', amount: 10.0, happenedAt: DateTime(2026, 7, 1), syncId: null),
          ImportTransaction(
              type: 'expense', amount: 20.0, happenedAt: DateTime(2026, 7, 2), syncId: null),
        ],
        categoryCache: {},
      );
      expect(r.inserted, 2, reason: '无 syncId 的记录应正常插入，不做去重');
      expect(await countInLedger(3), 2);
    });

    test('多账本隔离：A 账本已存在的 syncId 在 B 账本仍应插入', () async {
      await seedLedger(1);
      await seedLedger(4);
      // ledger1 已有 tx-X
      await service.importTransactions(repo, 1, [makeTx('tx-X')],
          categoryCache: {});
      // 向 ledger4 导入同 syncId tx-X —— existingSyncIds 按 ledger 预取，
      // 不应误判为已存在
      final r = await service.importTransactions(repo, 4, [makeTx('tx-X')],
          categoryCache: {});
      expect(r.inserted, 1);
      expect(await countInLedger(4), 1);
    });
  });
}
