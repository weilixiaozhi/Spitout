import 'package:drift/drift.dart' as d;

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/recurring_transaction_repository.dart';

/// 本地周期记账Repository实现
/// 基于 Drift 数据库实现
class LocalRecurringTransactionRepository
    implements RecurringTransactionRepository {
  final SpitoutDatabase db;

  LocalRecurringTransactionRepository(this.db);

  @override
  Future<List<RecurringTransaction>> getAllRecurringTransactions() async {
    return await (db.select(db.recurringTransactions)).get();
  }

  @override
  Future<List<RecurringTransaction>> getRecurringTransactionsByLedger(
    int ledgerId,
  ) async {
    return await (db.select(
      db.recurringTransactions,
    )..where((t) => t.ledgerId.equals(ledgerId))).get();
  }

  @override
  Future<List<RecurringTransaction>> getEnabledRecurringTransactions(
    int ledgerId,
  ) async {
    return await (db.select(db.recurringTransactions)
          ..where((t) => t.ledgerId.equals(ledgerId) & t.enabled.equals(true)))
        .get();
  }

  @override
  Future<int> addRecurringTransaction({
    required int ledgerId,
    required String type,
    required int amount,
    int? categoryId,
    String? note,
    required String frequency,
    required int interval,
    int? dayOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
    required DateTime startDate,
    DateTime? endDate,
    bool enabled = true,
  }) async {
    return await db
        .into(db.recurringTransactions)
        .insert(
          RecurringTransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: d.Value(categoryId),
            note: d.Value(note),
            frequency: frequency,
            interval: d.Value(interval),
            dayOfMonth: d.Value(dayOfMonth),
            dayOfWeek: d.Value(dayOfWeek),
            monthOfYear: d.Value(monthOfYear),
            startDate: startDate,
            endDate: d.Value(endDate),
            enabled: d.Value(enabled),
          ),
        );
  }

  @override
  Future<void> updateRecurringTransaction({
    required int id,
    required int ledgerId,
    required String type,
    required int amount,
    int? categoryId,
    String? note,
    required String frequency,
    required int interval,
    int? dayOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
    required DateTime startDate,
    DateTime? endDate,
    bool? enabled,
    bool clearLastGeneratedDate = false,
  }) async {
    await (db.update(
      db.recurringTransactions,
    )..where((t) => t.id.equals(id))).write(
      RecurringTransactionsCompanion(
        ledgerId: d.Value(ledgerId),
        type: d.Value(type),
        amount: d.Value(amount),
        categoryId: d.Value(categoryId),
        note: d.Value(note),
        frequency: d.Value(frequency),
        interval: d.Value(interval),
        dayOfMonth: d.Value(dayOfMonth),
        dayOfWeek: d.Value(dayOfWeek),
        monthOfYear: d.Value(monthOfYear),
        startDate: d.Value(startDate),
        endDate: d.Value(endDate),
        enabled: enabled != null ? d.Value(enabled) : const d.Value.absent(),
        // 普通编辑保持 lastGeneratedDate 不变；只有显式重置时才清空，
        // 否则用户改一次模板就会丢掉“已生成到哪天”的锚点，触发重复生成。
        lastGeneratedDate: clearLastGeneratedDate
            ? d.Value<DateTime?>(null)
            : const d.Value.absent(),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteRecurringTransaction(int id) async {
    await (db.delete(
      db.recurringTransactions,
    )..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> toggleRecurringTransaction(int id, bool enabled) async {
    await (db.update(
      db.recurringTransactions,
    )..where((t) => t.id.equals(id))).write(
      RecurringTransactionsCompanion(
        enabled: d.Value(enabled),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateLastGeneratedDate(int id, DateTime date) async {
    await (db.update(
      db.recurringTransactions,
    )..where((t) => t.id.equals(id))).write(
      RecurringTransactionsCompanion(
        lastGeneratedDate: d.Value(date),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  @override
  Stream<List<RecurringTransaction>> watchAllRecurringTransactions() {
    return (db.select(db.recurringTransactions)).watch();
  }

  @override
  Stream<List<RecurringTransaction>> watchRecurringTransactionsByLedger(
    int ledgerId,
  ) {
    return (db.select(
      db.recurringTransactions,
    )..where((t) => t.ledgerId.equals(ledgerId))).watch();
  }

  @override
  Future<void> batchInsertRecurringTransactions(
    List<RecurringTransactionsCompanion> items,
  ) async {
    await db.batch((batch) {
      batch.insertAll(db.recurringTransactions, items);
    });
  }
}
