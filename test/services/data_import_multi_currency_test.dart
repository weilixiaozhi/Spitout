/// CSV/JSON 导入路径的多币种契约:
///   - 无币种指定 → currencyCode=本位币, nativeAmount=amount
///   - CSV 显式指定币种列 → 优先于本位币兜底
///     (有汇率→折算, 无汇率→native=amount,**不落 NULL**)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:decimal/decimal.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/services/import/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
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

  Future<void> seed() async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
  }

  Future<List<Transaction>> allTx() =>
      (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  test('导入:无币种指定 → currencyCode=CNY, native=amount', () async {
    await seed();

    final result = await service.importTransactions(
      repo,
      1,
      [
        ImportTransaction(
            type: 'expense', amount: Decimal.parse('100'), happenedAt: DateTime(2026, 7, 1)),
        ImportTransaction(
            type: 'expense', amount: Decimal.parse('50'), happenedAt: DateTime(2026, 7, 2)),
      ],
      categoryCache: {},

    );
    expect(result.inserted, 2);

    final txs = await allTx();
    expect(txs[0].currencyCode, 'CNY'); // 无币种 → 本位币兜底
    expect(txs[0].nativeAmount, 10000);
    expect(txs[1].currencyCode, 'CNY');
    expect(txs[1].nativeAmount, 5000);
  });

  test('导入:CSV 币种列显式指定(反馈10)→ 优先于本位币兜底', () async {
    await seed();
    await repo.upsertAutoRates(
      base: 'CNY',
      rateDate: '2026-07-10',
      rates: {'JPY': '0.0488'},
      source: 'test',
      fetchedAt: DateTime.utc(2026, 7, 10),
    );
    final result = await service.importTransactions(
      repo,
      1,
      [
        // CSV 带币种列 JPY → 按 JPY 折算
        ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('1000'),
            currencyCode: 'JPY',
            happenedAt: DateTime(2026, 7, 1)),
      ],
      categoryCache: {},

    );
    expect(result.inserted, 1);
    final txs = await allTx();
    expect(txs[0].currencyCode, 'JPY');
    expect(txs[0].nativeAmount, 4880); // 1000 × 0.0488
  });

  test('导入:CSV 币种无汇率 → native=amount(非 NULL),补折算检测能捞到', () async {
    await seed();
    final result = await service.importTransactions(
      repo,
      1,
      [
        ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('12'),
            currencyCode: 'USD',
            happenedAt: DateTime(2026, 7, 3)),
      ],
      categoryCache: {},

    );
    expect(result.inserted, 1);

    final txs = await allTx();
    expect(txs[0].currencyCode, 'USD');
    expect(txs[0].nativeAmount, 1200, reason: '不落 NULL,按 1:1 待补折算');
    expect(await repo.countUnconvertedForeignTx(1), 1);
  });
}
