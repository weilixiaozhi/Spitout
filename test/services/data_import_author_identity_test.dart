// 导入作者身份落库测试。
//
// 需求锚点：导入的数据以当前身份导入——本地账本落 localSelfId，云端账本落云 userId；
// 创建者/编辑者一并回填，避免详情页「空，没有信息」；云同步拉取路径不传身份时保持原行为。

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

  ImportTransaction tx() => ImportTransaction(
        type: 'expense',
        amount: Decimal.parse('10'),
        happenedAt: DateTime(2026, 7, 1),
      );

  test('importTransactions：传入 authorUserId 时三作者字段都落当前身份', () async {
    await seed();

    final result = await service.importTransactions(
      repo,
      1,
      [tx()],
      categoryCache: {},
      authorUserId: 'current-user',
    );
    expect(result.inserted, 1);

    final t = (await allTx()).single;
    expect(t.paidByUserId, 'current-user');
    expect(t.createdByUserId, 'current-user');
    expect(t.lastEditedByUserId, 'current-user');
  });

  test('importData：传入 authorUserId 时同样落当前身份', () async {
    await seed();

    final result = await service.importData(
      repo,
      1,
      ImportData(transactions: [tx()]),
      authorUserId: 'current-user',
    );
    expect(result.inserted, 1);

    final t = (await allTx()).single;
    expect(t.paidByUserId, 'current-user');
    expect(t.createdByUserId, 'current-user');
    expect(t.lastEditedByUserId, 'current-user');
  });

  test('不传 authorUserId：保持原语义（paidBy 按备份值/空串，作者字段为空）', () async {
    await seed();

    final result = await service.importTransactions(
      repo,
      1,
      [tx()],
      categoryCache: {},
    );
    expect(result.inserted, 1);

    final t = (await allTx()).single;
    expect(t.paidByUserId, '');
    expect(t.createdByUserId, isNull);
    expect(t.lastEditedByUserId, isNull);
  });
}
