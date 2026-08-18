import 'package:drift/drift.dart' as d;

import 'package:spitout/data/db.dart';

/// 本地周期记账Repository实现
/// 基于 Drift 数据库实现
class LocalRecurringTransactionRepository {
  final SpitoutDatabase db;

  LocalRecurringTransactionRepository(this.db);

  Future<List<RecurringTransaction>> getAllRecurringTransactions() async {
    return await (db.select(db.recurringTransactions)).get();
  }

  Future<List<RecurringTransaction>> getRecurringTransactionsByLedger(
    int ledgerId,
  ) async {
    return await (db.select(
      db.recurringTransactions,
    )..where((t) => t.ledgerId.equals(ledgerId))).get();
  }

  Future<List<RecurringTransaction>> getEnabledRecurringTransactions(
    int ledgerId,
  ) async {
    return await (db.select(db.recurringTransactions)
          ..where((t) => t.ledgerId.equals(ledgerId) & t.enabled.equals(true)))
        .get();
  }

  /// 新建周期模板，并固化金额的原记账币种。
  ///
  /// 未指定 [currencyCode] 时取创建时的账本本位币，确保账本以后换币时模板金额
  /// 仍保持原单位；显式币种供配置导入等跨账本恢复场景使用。
  Future<int> addRecurringTransaction({
    required int ledgerId,
    required String type,
    required int amount,
    String? currencyCode,
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
    final ledger = await (db.select(
      db.ledgers,
    )..where((l) => l.id.equals(ledgerId))).getSingleOrNull();
    if (ledger == null) {
      throw StateError('账本不存在: $ledgerId');
    }
    // 新建模板默认沿用当时的账本本位币；显式传入则用于配置导入等
    // 跨账本场景，之后即使模板归属或账本本位币变化也不改金额单位。
    final normalizedCurrencyCode = currencyCode?.trim().toUpperCase();
    final resolvedCurrencyCode = normalizedCurrencyCode?.isNotEmpty == true
        ? normalizedCurrencyCode!
        : ledger.currency.trim().toUpperCase();
    return await db
        .into(db.recurringTransactions)
        .insert(
          RecurringTransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            currencyCode: d.Value(resolvedCurrencyCode),
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

  /// 更新周期模板，未指定 [currencyCode] 时保留已固化的原记账币种。
  ///
  /// 归属账本与金额币种是两个独立维度，因此模板跨账本只更新 [ledgerId]，
  /// 不会把相同金额数值静默解释为目标账本币种。
  Future<void> updateRecurringTransaction({
    required int id,
    required int ledgerId,
    required String type,
    required int amount,
    String? currencyCode,
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
    final normalizedCurrencyCode = currencyCode?.trim().toUpperCase();
    await (db.update(
      db.recurringTransactions,
    )..where((t) => t.id.equals(id))).write(
      RecurringTransactionsCompanion(
        ledgerId: d.Value(ledgerId),
        type: d.Value(type),
        amount: d.Value(amount),
        // 未显式传币种时保留模板原币种；编辑页面跨账本只改变归属，
        // 否则相同数值会被静默改成目标账本的金额单位。
        currencyCode: normalizedCurrencyCode?.isNotEmpty != true
            ? const d.Value.absent()
            : d.Value(normalizedCurrencyCode),
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

  Future<void> deleteRecurringTransaction(int id) async {
    await (db.delete(
      db.recurringTransactions,
    )..where((t) => t.id.equals(id))).go();
  }

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

  Stream<List<RecurringTransaction>> watchAllRecurringTransactions() {
    return (db.select(db.recurringTransactions)).watch();
  }

  Stream<List<RecurringTransaction>> watchRecurringTransactionsByLedger(
    int ledgerId,
  ) {
    return (db.select(
      db.recurringTransactions,
    )..where((t) => t.ledgerId.equals(ledgerId))).watch();
  }

  Future<void> batchInsertRecurringTransactions(
    List<RecurringTransactionsCompanion> items,
  ) async {
    await db.batch((batch) {
      batch.insertAll(db.recurringTransactions, items);
    });
  }
}
