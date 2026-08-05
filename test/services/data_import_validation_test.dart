/// 导入入口统一校验测试：非法分类/交易被拦截并计入 ImportResult.failed。
///
/// 覆盖 ImportCategory.level、二级缺父、ImportTransaction 金额非正、币种非法，
/// 以及直接调用 importTransactions 时的兜底校验。
library;

import 'package:flutter_test/flutter_test.dart';
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
  // 防止跨用例残留导致顺序依赖。详见 test/helpers/test_isolation.dart。
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

  test('importData: 非法分类/交易计入 failed 且不落库', () async {
    await seed();

    final result = await service.importData(
      repo,
      1,
      ImportData(
        categories: [
          const ImportCategory(name: '合法分类', kind: 'expense', level: 1),
          const ImportCategory(name: '非法层级', kind: 'expense', level: 3),
          const ImportCategory(name: '二级缺父', kind: 'expense', level: 2),
        ],
        transactions: [
          ImportTransaction(
              type: 'expense',
              amount: Decimal.parse('10'),
              happenedAt: DateTime(2026, 7, 1)),
          ImportTransaction(
              type: 'expense',
              amount: Decimal.parse('-5'),
              happenedAt: DateTime(2026, 7, 2)),
          ImportTransaction(
              type: 'expense',
              amount: Decimal.parse('8'),
              currencyCode: 'BAD1',
              happenedAt: DateTime(2026, 7, 3)),
        ],
      ),
    );

    expect(result.failed, 4,
        reason: '非法层级 + 二级缺父 + 负数金额 + 非法币种 各计 1 条失败');
    expect(result.inserted, 1);

    final txs = await (db.select(db.transactions)).get();
    expect(txs.length, 1);
    expect(txs.single.amount, 1000);

    final cats = await (db.select(db.categories)).get();
    expect(cats.length, 1);
    expect(cats.single.name, '合法分类');
  });

  test('importTransactions 直调路径同样拦截非法交易', () async {
    await seed();

    final result = await service.importTransactions(
      repo,
      1,
      [
        ImportTransaction(
            type: 'income',
            amount: Decimal.parse('10'),
            happenedAt: DateTime(2026, 7, 1)),
        ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('0'),
            happenedAt: DateTime(2026, 7, 2)),
      ],
      categoryCache: {},
    );

    expect(result.failed, 2);
    expect(result.inserted, 0);
    expect(await (db.select(db.transactions)).get(), isEmpty);
  });
}
