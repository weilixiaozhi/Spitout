// 周期账单 repository 与汇率覆盖 repository 测试（真实 SQLite）。
//
// 覆盖周期账单的增删改查/启停/已生成日期/批量插入/响应式 watch，
// 以及汇率覆盖的手动设置/移除/watch 流语义。

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_exchange_rate_repository.dart';
import 'package:spitout/data/repositories/local/local_recurring_transaction_repository.dart';

void main() {
  late SpitoutDatabase db;
  late LocalRecurringTransactionRepository recurring;
  late LocalExchangeRateRepository rates;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    recurring = LocalRecurringTransactionRepository(db);
    rates = LocalExchangeRateRepository(db, trackerGetter: () => null);
  });

  tearDown(() async => db.close());

  group('周期账单 repository', () {
    test('增删改查 / 启停 / 已生成日期 / watch', () async {
      final lid = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(name: '周期账本'),
          );

      final id = await recurring.addRecurringTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 5000,
        frequency: 'monthly',
        interval: 1,
        dayOfMonth: 15,
        startDate: DateTime(2026, 1, 1),
      );

      var list = await recurring.getRecurringTransactionsByLedger(lid);
      expect(list, hasLength(1));
      expect(list.first.amount, 5000);
      expect(list.first.enabled, isTrue);

      // 编辑金额与起始日；lastGeneratedDate 保留
      await recurring.updateRecurringTransaction(
        id: id,
        ledgerId: lid,
        type: 'expense',
        amount: 6000,
        frequency: 'monthly',
        interval: 1,
        dayOfMonth: 20,
        startDate: DateTime(2026, 2, 1),
      );
      list = await recurring.getRecurringTransactionsByLedger(lid);
      expect(list.first.amount, 6000);
      expect(list.first.dayOfMonth, 20);

      // 记录已生成日期
      await recurring.updateLastGeneratedDate(id, DateTime(2026, 6, 15));
      list = await recurring.getRecurringTransactionsByLedger(lid);
      expect(list.first.lastGeneratedDate, DateTime(2026, 6, 15));

      // 停用后 getEnabled 不再返回
      await recurring.toggleRecurringTransaction(id, false);
      final enabled = await recurring.getEnabledRecurringTransactions(lid);
      expect(enabled, isEmpty);
      list = await recurring.getRecurringTransactionsByLedger(lid);
      expect(list.first.enabled, isFalse);

      // watch 流收到更新
      final events = <int>[];
      final sub = recurring
          .watchRecurringTransactionsByLedger(lid)
          .listen((rows) => events.add(rows.length));
      await pumpEventQueue();
      await recurring.deleteRecurringTransaction(id);
      await pumpEventQueue();
      expect(events, isNotEmpty);
      expect(events.last, 0);
      await sub.cancel();
    });

    test('batchInsert 批量导入 + watchAll', () async {
      final lid = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(name: '批量账本'),
          );
      await recurring.batchInsertRecurringTransactions([
        RecurringTransactionsCompanion.insert(
          ledgerId: lid,
          type: 'expense',
          amount: 1000,
          frequency: 'weekly',
          interval: const Value(1),
          startDate: DateTime(2026, 1, 1),
        ),
        RecurringTransactionsCompanion.insert(
          ledgerId: lid,
          type: 'expense',
          amount: 2000,
          frequency: 'weekly',
          interval: const Value(2),
          startDate: DateTime(2026, 1, 1),
        ),
      ]);
      final all = await recurring.getAllRecurringTransactions();
      expect(all, hasLength(2));
      expect(all.map((r) => r.amount), containsAll([1000, 2000]));

      final watched = await recurring.watchAllRecurringTransactions().first;
      expect(watched, hasLength(2));
    });
  });

  group('汇率覆盖 repository', () {
    test('setOverride / watchOverrides / removeOverride', () async {
      await rates.setOverride(base: 'CNY', quote: 'USD', rate: '7.2');
      await rates.setOverride(base: 'CNY', quote: 'EUR', rate: '8.5');

      final overrides = await rates.getOverrides('cny'); // 大小写归一
      expect(overrides, hasLength(2));
      expect(overrides.map((o) => o.quoteCurrency), ['EUR', 'USD']);

      final events = <List<ExchangeRateOverride>>[];
      final sub = rates.watchOverrides('CNY').listen(events.add);
      await rates.removeOverride(base: 'CNY', quote: 'USD');
      await pumpEventQueue();
      expect(events, isNotEmpty);
      expect(events.last, hasLength(1));
      await sub.cancel();
    });
  });
}
