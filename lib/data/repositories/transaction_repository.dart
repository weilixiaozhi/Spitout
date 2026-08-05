import '../db.dart';

/// 批量按 syncId 更新交易时的单条 update payload。
class TransactionUpdateBySyncIdData {
  final String syncId;
  final String type;
  final int amount; // 单位:分
  final int? categoryId;
  final DateTime happenedAt;
  final String? note;

  const TransactionUpdateBySyncIdData({
    required this.syncId,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.happenedAt,
    this.note,
  });
}

/// 交易Repository接口
/// 定义交易相关的所有数据操作
abstract class TransactionRepository {
  /// 获取最近的交易记录
  Stream<List<Transaction>> watchRecentTransactions({
    required int ledgerId,
    int limit = 20,
  });

  /// 获取指定月份的交易记录
  ///
  /// [month] 为周期标签,约定传 DateTime(year, month, 1);实际范围由账本
  /// monthStartDay 决定:[y-m-起始日, y-(m+1)-起始日)。
  Stream<List<Transaction>> watchTransactionsInMonth({
    required int ledgerId,
    required DateTime month,
  });

  /// 获取所有交易记录（带分类信息）
  /// [ledgerId] 可选，不传则获取所有账本的交易
  Stream<
      List<
          ({
            Transaction t,
            Category? category,
          })>> watchTransactionsWithCategoryAll({
    int? ledgerId,
  });

  /// 获取所有交易记录（带分类信息）- 非 Stream 版本
  /// [ledgerId] 可选，不传则获取所有账本的交易
  Stream<
      List<
          ({
            Transaction t,
            Category? category,
          })>> transactionsWithCategoryAll({
    int? ledgerId,
  });

  /// 获取最近的交易记录（带分类信息）- 用于预加载
  Future<
      List<
          ({
            Transaction t,
            Category? category,
          })>> getRecentTransactionsWithCategory({
    required int ledgerId,
    required int limit,
  });

  /// 根据ID获取单条交易
  Future<Transaction?> getTransactionById(int id);

  /// 获取指定月份的交易记录（带分类信息）
  ///
  /// [month] 为周期标签,约定传 DateTime(year, month, 1);实际范围由账本
  /// monthStartDay 决定:[y-m-起始日, y-(m+1)-起始日)。
  Stream<List<({Transaction t, Category? category})>> watchTransactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  });

  /// 获取指定年份的交易记录（带分类信息）
  Stream<List<({Transaction t, Category? category})>> watchTransactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  });

  /// 获取指定分类和时间范围的交易记录（带分类信息）
  Stream<List<({Transaction t, Category? category})>> watchTransactionsForCategoryInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    int? categoryId,
    required String type,
  });

  /// 添加交易
  ///
  /// Editor 选 Owner 的 SharedLedgerCategories 行时,
  /// categoryId 留 null,改填 categorySyncIdOverride 字符串。
  /// Owner / 单人账本场景:走 categoryId int(老路径),override 留 null。
  ///
  /// 支出人(paidByUserId)属全局交易语义,由调用方显式传入(null = 未手选,
  /// 由 markTxAuthor 回填操作者);AA 分摊字段(aaMode/aaParticipants/aaSplits)
  /// 同样显式传入,非 AA 账本或非 AA 交易不传(null),子仓收"已定值"直写。
  Future<int> addTransaction({
    required int ledgerId,
    required String type,
    required int amount,
    int? categoryId,
    required DateTime happenedAt,
    String? note,
    String? syncId,
    String? categorySyncIdOverride,
    bool excludeFromStats = false,
    // 未传时聚合层兜底(currencyCode=本位币;
    // nativeAmount 外币先按有效汇率折算,取不到才 =amount)。
    String? currencyCode,
    int? nativeAmount,
    // 支出人 userId(全局交易字段,非 AA 专属;null 由 markTxAuthor 回填操作者)
    String? paidByUserId,
    // AA 分摊模式:null/0=人均,1=不分摊,2=指定
    int? aaMode,
    // AA 参与人(JSON 数组字符串)
    String? aaParticipants,
    // AA 指定分摊金额(JSON 对象字符串)
    String? aaSplits,
  });

  /// 批量新增交易，单事务内插入，返回插入条数。
  ///
  /// [recordChanges] 默认 true,会逐条登记 changeTracker.recordLedgerChange。
  /// FullPull 路径需要传 false 避免"从云端拉下来的数据又被反向 push 回去"。
  Future<int> insertTransactionsBatch(
    List<TransactionsCompanion> items, {
    bool recordChanges = true,
  });

  /// 插入单条交易（使用 Companion 对象）
  ///
  /// [recordChanges] 同 [insertTransactionsBatch]。
  Future<int> insertTransactionCompanion(
    TransactionsCompanion item, {
    bool recordChanges = true,
  });

  /// 批量插入交易，全部在单事务内完成。
  ///
  /// 用于 import 路径 — 原本的"单条 insert"会引发 N+1 + 嵌套事务,
  /// 1 万条数据耗时数十分钟;本方法把 N 次单条事务折叠成 1 次,
  /// 并用 `db.batch` 合并 local_changes 的 INSERT。
  ///
  /// [recordChanges] - 同 [insertTransactionsBatch]。
  ///
  /// 返回插入的 tx id 列表,顺序跟 [transactions] 输入对齐。
  Future<List<int>> insertTransactionsBatchWithRelations({
    required List<TransactionsCompanion> transactions,
    bool recordChanges = true,
  });

  /// 更新交易
  ///
  /// 返回值:本次更新写回后的版本号(transactions.version 自增后的值)。
  /// 设计意图:UI 层拿到此 version 后,可立即调用 [appendEditHistory] 在
  /// 编辑历史表里追加一条同版本号快照,从而让"更新交易"与"记录编辑历史"
  /// 形成闭环,避免详情页编辑记录区块永远为空。
  ///
  /// AA 分摊字段:同 [addTransaction],null = 不更新保持原值;
  /// 支出人(paidByUserId)同理,null = 不更新保持原值。
  Future<int> updateTransaction({
    required int id,
    required String type,
    required int amount,
    int? categoryId,
    String? note,
    DateTime? happenedAt,
    String? categorySyncIdOverride,
    bool? excludeFromStats,
    // 未传(null)= 不改动既有值;聚合层对 amount 变化
    // 做折算兜底。
    String? currencyCode,
    int? nativeAmount,
    // 支出人/AA 分摊字段:null = 不更新保持原值
    String? paidByUserId,
    int? aaMode,
    String? aaParticipants,
    String? aaSplits,
  });

  /// 删除交易
  Future<void> deleteTransaction(int id);

  // ==================== 编辑历史 ====================

  /// 获取某条交易的编辑历史(按版本号倒序)。
  /// 对应记录详情 Bottom Sheet 的"编辑记录(仅供查看)"区块。
  Future<List<RecordEditHistory>> getEditHistories(int recordId);

  /// 追加一条编辑历史记录。
  ///
  /// 由 UI 层在编辑交易后调用(与 markTxAuthor 同时机)。
  /// [version] 该次编辑后的版本号(updateTransaction 内部已自增并写回
  ///   transactions.version,这里传入同值,便于历史区块展示"vN"标签)。
  /// [operatorUserId] 操作者 userId(单人账本传 null;共享账本传当前用户 id)。
  /// [summary] 人类可读摘要(分类名 + 金额 + 日期),用于详情展示。
  Future<int> appendEditHistory({
    required int recordId,
    required int version,
    String? operatorUserId,
    required String summary,
  });

  /// 获取指定类型和时间范围内的交易数量
  Future<int> countByTypeInRange({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  });

  /// 获取账本的所有交易记录
  Future<List<Transaction>> getTransactionsByLedger(int ledgerId);

  /// 获取账本中参与 AA 分摊的交易(aaMode != 1,即排除了"不分摊"的交易)。
  ///
  /// 设计意图:AA 分摊统计页用此方法过滤出需要参与分摊计算的交易。
  /// aaMode=null/0(人均)和 aaMode=2(指定)都纳入;aaMode=1(不分摊)跳过。
  Future<List<Transaction>> getAaTransactionsByLedger(int ledgerId);

  /// 获取账本在指定时间范围内的交易记录
  Future<List<Transaction>> getTransactionsByLedgerInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  });

  /// 更新交易的账本
  Future<void> updateTransactionLedger({
    required int id,
    required int ledgerId,
  });

  // ==================== 日历功能相关 ====================

  /// 获取指定月份的每日交易统计（全局仅支出模式，只返回支出）
  /// 返回 Map<日期字符串, 支出金额>
  /// 例: {"2025-01-15": 1200.0, ...}
  Future<Map<String, double>> getDailyTotalsByMonth({
    required int ledgerId,
    required DateTime month,
  });

  /// 获取指定日期的所有交易（含分类）
  Future<List<({Transaction t, Category? category})>>
      getTransactionsByDate({
    required int ledgerId,
    required DateTime date,
  });

  /// 根据 syncId 获取交易
  Future<Transaction?> getTransactionBySyncId(String syncId);

  /// 根据 syncId 更新交易的全部字段
  Future<void> updateTransactionBySyncId({
    required String syncId,
    required String type,
    required int amount,
    int? categoryId,
    required DateTime happenedAt,
    String? note,
  });

  /// 根据 syncId 删除交易
  Future<void> deleteTransactionBySyncId(String syncId);

  /// 批量按 syncId 删除交易(WebDAV/Supabase 同步从远端拉账本时,如果本地有
  /// 旧账本 + 用户选择"以远端为准"覆盖,N 条 delete by syncId 单条 await 会
  /// 跑几分钟;本方法用单条 `DELETE WHERE syncId IN (...)` 一次性删除)。
  ///
  /// [recordChanges] 默认 true,wrapper 会批量补 transaction:delete change log。
  /// 返回实际删除的条数。
  Future<int> deleteTransactionsBatchBySyncIds(
    List<String> syncIds, {
    bool recordChanges = true,
  });

  /// 批量按 syncId 更新交易主表字段。同事务内逐条 UPDATE,N 次跨 isolate
  /// boundary 但 BEGIN/COMMIT 只跑一次。
  Future<Map<String, int>> updateTransactionsBatchBySyncId(
    List<TransactionUpdateBySyncIdData> updates, {
    bool recordChanges = true,
  });

}
