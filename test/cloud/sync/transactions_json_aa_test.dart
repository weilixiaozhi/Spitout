/// transactions_json v7 AA 字段 + 虚拟用户 round-trip 测试。
///
/// 覆盖:
/// - export v7 含 paidByUserId/aaMode/aaParticipants/aaSplits + aaEnabled + virtualUsers。
/// - parse v7 读回所有 AA 字段。
/// - parse v6 缺键兜底为 null/空 → 视为未启用 AA(向后兼容)。
/// - round-trip: export → parse 值完全一致。
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

  /// 种子:开启 AA 的账本 + 一条 AA 交易 + 一个虚拟用户
  Future<void> seed() async {
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'AA 账本',
          currency: const Value('CNY'),
          aaEnabled: const Value(true),
        ));
    await db.into(db.categories)
        .insert(CategoriesCompanion.insert(name: '餐饮', kind: 'expense'));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          type: 'expense',
          amount: 30.0,
          categoryId: const Value(1),
          happenedAt: Value(DateTime.utc(2026, 7, 1)),
          syncId: const Value('tx-aa'),
          paidByUserId: const Value('u1'),
          aaMode: const Value(2),
          aaParticipants: const Value('["u1","vu-1"]'),
          aaSplits: const Value('{"u1":"20.00","vu-1":"10.00"}'),
        ));
    await db.into(db.ledgerVirtualUsers).insert(
          LedgerVirtualUsersCompanion.insert(
            ledgerId: 1,
            syncId: const Value('vu-1'),
            name: '室友',
          ),
        );
  }

  test('export: v7 含 AA 字段 + aaEnabled + virtualUsers', () async {
    await seed();

    final jsonStr = await exportTransactionsJson(db, 1);
    final payload = jsonDecode(jsonStr) as Map<String, dynamic>;

    expect(payload['version'], 7);
    expect(payload['aaEnabled'], true);

    final item = (payload['items'] as List)
        .cast<Map<String, dynamic>>()
        .single;
    expect(item['paidByUserId'], 'u1');
    expect(item['aaMode'], 2);
    expect(item['aaParticipants'], '["u1","vu-1"]');
    expect(item['aaSplits'], '{"u1":"20.00","vu-1":"10.00"}');

    final vus = (payload['virtualUsers'] as List)
        .cast<Map<String, dynamic>>();
    expect(vus, hasLength(1));
    expect(vus.single['syncId'], 'vu-1');
    expect(vus.single['name'], '室友');
  });

  test('parse: v7 读回所有 AA 字段', () {
    const jsonStr = '''
    {
      "version": 7,
      "ledgerName": "AA 账本",
      "currency": "CNY",
      "aaEnabled": true,
      "categories": [],
      "items": [
        {
          "type": "expense",
          "amount": 30.0,
          "happenedAt": "2026-07-01T00:00:00.000Z",
          "syncId": "tx-aa",
          "paidByUserId": "u1",
          "aaMode": 2,
          "aaParticipants": "[\\"u1\\",\\"vu-1\\"]",
          "aaSplits": "{\\"u1\\":\\"20.00\\",\\"vu-1\\":\\"10.00\\"}"
        }
      ],
      "virtualUsers": [
        {"syncId": "vu-1", "name": "室友"}
      ]
    }
    ''';

    final data = parseJsonToImportData(jsonStr);
    expect(data.aaEnabled, true);
    expect(data.virtualUsers, hasLength(1));
    expect(data.virtualUsers.single.syncId, 'vu-1');
    expect(data.virtualUsers.single.name, '室友');

    final tx = data.transactions.single;
    expect(tx.paidByUserId, 'u1');
    expect(tx.aaMode, 2);
    expect(tx.aaParticipants, '["u1","vu-1"]');
    expect(tx.aaSplits, '{"u1":"20.00","vu-1":"10.00"}');
  });

  test('parse: v6 缺键兜底为 null/空(向后兼容)', () {
    const jsonStr = '''
    {
      "version": 6,
      "ledgerName": "旧账本",
      "currency": "CNY",
      "categories": [],
      "items": [
        {
          "type": "expense",
          "amount": 10.0,
          "happenedAt": "2026-07-01T00:00:00.000Z",
          "syncId": "tx-legacy"
        }
      ]
    }
    ''';

    final data = parseJsonToImportData(jsonStr);
    expect(data.aaEnabled, isNull, reason: 'v6 无 aaEnabled 键 → null');
    expect(data.virtualUsers, isEmpty, reason: 'v6 无 virtualUsers 键 → 空列表');

    final tx = data.transactions.single;
    expect(tx.paidByUserId, isNull);
    expect(tx.aaMode, isNull);
    expect(tx.aaParticipants, isNull);
    expect(tx.aaSplits, isNull);
  });

  test('round-trip: export → parse 值完全一致', () async {
    await seed();

    final jsonStr = await exportTransactionsJson(db, 1);
    final data = parseJsonToImportData(jsonStr);

    expect(data.aaEnabled, true);
    expect(data.virtualUsers, hasLength(1));
    expect(data.virtualUsers.single.syncId, 'vu-1');
    expect(data.virtualUsers.single.name, '室友');

    final tx = data.transactions.single;
    expect(tx.paidByUserId, 'u1');
    expect(tx.aaMode, 2);
    expect(tx.aaParticipants, '["u1","vu-1"]');
    expect(tx.aaSplits, '{"u1":"20.00","vu-1":"10.00"}');
  });
}
