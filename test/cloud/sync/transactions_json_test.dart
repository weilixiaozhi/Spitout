/// 全量恢复保真(S1)契约测试:transactions_json 的 export/parse round-trip。
///
/// 背景:/sync/full 的 tx item 已输出 currencyCode/nativeAmount(服务端 0018),
/// excludeFromStats 也随服务端 C4 补齐输出;但 parseJsonToImportData 此前
/// 只读 type/amount/category/happenedAt/note/syncId,三个字段全量恢复后丢失。
/// 同时 exportTransactionsJson 此前也不导出这三字段,导致"JSON 备份恢复"
/// 与上传的 ledger_snapshot content 同样失真。
///
/// 本测试锁定:
///   1. export 导出 currencyCode/nativeAmount,excludeFromStats 仅 true 时输出
///      (缺键 = false,与 server snapshot 语义对齐);
///   2. parse 能读回这三字段;
///   3. JSON(缺键)解析 → 字段为 null(走既有兜底);
///   4. export → parse round-trip 值完全一致。
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/cloud/sync/transactions_json.dart';
import 'package:spitout/data/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  /// 种子:账本(CNY) + 一级分类 + 两条交易
  /// 第一条:USD 外币 + 折算快照 35.5 + 免统计
  /// 第二条:普通本币交易(无币种快照、未免统计)
  Future<void> seed() async {
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L',
          currency: const Value('CNY'),
        ));
    final catId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: '餐饮', kind: 'expense'));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 5.0,
          categoryId: Value(catId),
          happenedAt: Value(DateTime.utc(2026, 7, 1)),
          syncId: const Value('tx-usd'),
          currencyCode: const Value('USD'),
          nativeAmount: const Value(35.5),
          excludeFromStats: const Value(true),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 12.0,
          categoryId: Value(catId),
          happenedAt: Value(DateTime.utc(2026, 7, 2)),
          syncId: const Value('tx-cny'),
          currencyCode: const Value('CNY'),
          nativeAmount: const Value(12.0),
          // excludeFromStats 走默认 false
        ));
  }

  test('export: 外币交易导出 currencyCode/nativeAmount/excludeFromStats', () async {
    await seed();

    final jsonStr = await exportTransactionsJson(db, 1);
    final payload = jsonDecode(jsonStr) as Map<String, dynamic>;
    final items = (payload['items'] as List).cast<Map<String, dynamic>>();

    final usd = items.firstWhere((it) => it['syncId'] == 'tx-usd');
    expect(usd['currencyCode'], 'USD');
    expect(usd['nativeAmount'], 35.5);
    expect(usd['excludeFromStats'], true);

    final cny = items.firstWhere((it) => it['syncId'] == 'tx-cny');
    expect(cny['currencyCode'], 'CNY');
    expect(cny['nativeAmount'], 12.0);
    expect(cny.containsKey('excludeFromStats'), isFalse,
        reason: '缺键 = false,与 server snapshot 语义对齐,payload 保持干净');
  });

  test('parse: 读出 currencyCode/nativeAmount/excludeFromStats', () {
    const jsonStr = '''
    {
      "version": 6,
      "ledgerName": "L",
      "currency": "CNY",
      "categories": [],
      "items": [
        {
          "type": "expense",
          "amount": 5.0,
          "happenedAt": "2026-07-01T00:00:00.000Z",
          "note": null,
          "syncId": "tx-usd",
          "currencyCode": "USD",
          "nativeAmount": 35.5,
          "excludeFromStats": true
        }
      ]
    }
    ''';

    final data = parseJsonToImportData(jsonStr);
    expect(data.transactions, hasLength(1));
    final tx = data.transactions.single;
    expect(tx.currencyCode, 'USD');
    expect(tx.nativeAmount, 35.5);
    expect(tx.excludeFromStats, true);
  });

  test('parse: JSON 缺键 → 三字段为 null(走既有兜底)', () {
    const jsonStr = '''
    {
      "version": 6,
      "ledgerName": "L",
      "currency": "CNY",
      "categories": [],
      "items": [
        {
          "type": "expense",
          "amount": 12.0,
          "happenedAt": "2026-07-02T00:00:00.000Z",
          "note": "午餐",
          "syncId": "tx-legacy"
        }
      ]
    }
    ''';

    final data = parseJsonToImportData(jsonStr);
    final tx = data.transactions.single;
    expect(tx.currencyCode, isNull);
    expect(tx.nativeAmount, isNull);
    expect(tx.excludeFromStats, isNull);
  });

  test('round-trip: export → parse 值完全一致', () async {
    await seed();

    final jsonStr = await exportTransactionsJson(db, 1);
    final data = parseJsonToImportData(jsonStr);

    final usd = data.transactions.firstWhere((t) => t.syncId == 'tx-usd');
    expect(usd.currencyCode, 'USD');
    expect(usd.nativeAmount, 35.5);
    expect(usd.excludeFromStats, true);

    final cny = data.transactions.firstWhere((t) => t.syncId == 'tx-cny');
    expect(cny.currencyCode, 'CNY');
    expect(cny.nativeAmount, 12.0);
    expect(cny.excludeFromStats, isNull,
        reason: 'export 不为 false 输出键,parse 读到 null,落库时 ?? false 兜底');
  });
}
