import '../db.dart';

/// 周期记账 Repository 接口
abstract class RecurringTransactionRepository {
  /// 获取所有周期记账
  Future<List<RecurringTransaction>> getAllRecurringTransactions();

  /// 获取指定账本的周期记账
  Future<List<RecurringTransaction>> getRecurringTransactionsByLedger(
    int ledgerId,
  );

  /// 获取指定账本的启用的周期记账
  Future<List<RecurringTransaction>> getEnabledRecurringTransactions(
    int ledgerId,
  );

  /// 添加周期记账
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
  });

  /// 更新周期记账。
  ///
  /// [clearLastGeneratedDate] 仅在需要重置“已生成到哪天”的锚点时传 true；
  /// 默认为 false 表示普通编辑不触碰 lastGeneratedDate，避免后续扫描重复补生成历史账目。
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
  });

  /// 删除周期记账
  Future<void> deleteRecurringTransaction(int id);

  /// 启用/禁用周期记账
  Future<void> toggleRecurringTransaction(int id, bool enabled);

  /// 更新最后生成日期
  Future<void> updateLastGeneratedDate(int id, DateTime date);

  /// 监听所有周期记账变化
  Stream<List<RecurringTransaction>> watchAllRecurringTransactions();

  /// 监听指定账本的周期记账变化
  Stream<List<RecurringTransaction>> watchRecurringTransactionsByLedger(
    int ledgerId,
  );

  /// 批量插入周期记账
  Future<void> batchInsertRecurringTransactions(
    List<RecurringTransactionsCompanion> items,
  );
}
