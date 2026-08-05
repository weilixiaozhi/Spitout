/// 全量恢复保真(S1)落库语义测试:importTransactions 对 nativeAmount /
/// excludeFromStats 的处理。
///
/// 锁定语义:
///   1. nativeAmount 快照优先 —— 云端全量恢复时,源端折算快照是源设备记账
///      时的真实所见,优先于本地按汇率重算(汇率时点不同会失真);
///   2. nativeAmount 缺键(null) → 走既有重算路径(CSV 导入行为不变);
///   3. excludeFromStats 显式 true → 落库 true;缺键(null) → 落库 false。
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

  test('nativeAmount 快照优先:不随本地汇率重算而失真', () async {
    await seed();
    // 本地有 JPY 汇率 0.0488 —— 若走重算会得到 48.8,
    // 但快照值 35.5 是源端真实所见,必须优先采用。
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
        ImportTransaction(
          type: 'expense',
          amount: Decimal.parse('1000'),
          currencyCode: 'JPY',
          nativeAmount: Decimal.parse('35.5'),
          happenedAt: DateTime(2026, 7, 1),
        ),
      ],
      categoryCache: {},
    );
    expect(result.inserted, 1);

    final txs = await allTx();
    expect(txs[0].currencyCode, 'JPY');
    expect(txs[0].nativeAmount, 3550,
        reason: '源端快照优先,不得被本地汇率重算覆盖为 48.8');
  });

  test('nativeAmount 缺键(null) → 走既有重算路径', () async {
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
        ImportTransaction(
          type: 'expense',
          amount: Decimal.parse('1000'),
          currencyCode: 'JPY',
          // nativeAmount 缺键 → 重算
          happenedAt: DateTime(2026, 7, 1),
        ),
      ],
      categoryCache: {},
    );
    expect(result.inserted, 1);

    final txs = await allTx();
    expect(txs[0].nativeAmount, 4880);
  });

  test('excludeFromStats: 显式 true 落库 true;缺键(null)落库 false', () async {
    await seed();

    final result = await service.importTransactions(
      repo,
      1,
      [
        ImportTransaction(
          type: 'expense',
          amount: Decimal.parse('10'),
          excludeFromStats: true,
          happenedAt: DateTime(2026, 7, 1),
        ),
        ImportTransaction(
          type: 'expense',
          amount: Decimal.parse('20'),
          // excludeFromStats 缺键
          happenedAt: DateTime(2026, 7, 2),
        ),
      ],
      categoryCache: {},
    );
    expect(result.inserted, 2);

    final txs = await allTx();
    expect(txs[0].excludeFromStats, isTrue);
    expect(txs[1].excludeFromStats, isFalse,
        reason: '缺键 = false,与 server snapshot 语义对齐');
  });
}
