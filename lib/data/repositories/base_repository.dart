import 'package:spitout/data/db.dart';
import 'ledger_repository.dart';
import 'transaction_repository.dart';
import 'category_repository.dart';
import 'statistics_repository.dart';
import 'recurring_transaction_repository.dart';
import 'exchange_rate_repository.dart';
import 'ledger_virtual_user_repository.dart';

/// 基础 Repository 抽象类
/// 组合所有 Repository 接口，用于类型约束
/// LocalRepository、CloudRepository、ApiRepository 等都应该实现这个抽象类
///
/// 设计原则：
/// - 不包含任何具体实现细节（如数据库访问）
/// - 仅定义数据访问的抽象接口
/// - 支持无缝切换不同的数据源实现
abstract class BaseRepository
    implements
        LedgerRepository,
        TransactionRepository,
        CategoryRepository,
        StatisticsRepository,
        RecurringTransactionRepository,
        ExchangeRateRepository,
        LedgerVirtualUserRepository {
  // -------------------------------------------------------------------
  // 重算 / 检测。
  // 声明在聚合层而非 TransactionRepository:这些方法要同时访问交易表与
  // 有效汇率(ExchangeRateRepository),交易子仓拿不到汇率。
  // -------------------------------------------------------------------

  /// 本位币变更后全量重算该账本交易的 nativeAmount(用当前有效汇率,历史
  /// 汇率不可得)。逐笔记 change,确保云端投影同步更新。返回实际改动条数。
  /// [recordChanges] 为 false 时只写数据库、不登记 local_changes；
  /// pull 路径应用远端币种变更时必须传 false，避免重算结果被反向推回 server。
  Future<int> recalcNativeAmountsForLedger(
    int ledgerId,
    String newBase, {
    bool recordChanges = true,
  });

  /// 存量补折算:只重算「currencyCode≠本位币 且 nativeAmount==amount」
  /// 的外币交易(缺汇率的跳过留待用户)。逐笔记 change。
  /// 返回实际改动条数。
  Future<int> recomputeForeignTxForLedger(int ledgerId);

  /// 检测:该账本「未折算外币交易」条数(currencyCode≠本位币 且
  /// nativeAmount==amount)。统计页横幅按 >0 显示。
  Future<int> countUnconvertedForeignTx(int ledgerId);

  /// 该账本外币交易条数(currencyCode≠本位币,含已折算)。统计页折算脚注
  /// 按 >0 显示。
  Future<int> countForeignCurrencyTx(int ledgerId);

  /// 该账本交易涉及的全部外币币种集合(重算前并入汇率拉取 extraQuotes)。
  Future<Set<String>> getLedgerForeignCurrencies(int ledgerId);

  /// 全局已使用的币种集合(从 transactions.currency_code distinct 查询)。
  Future<Set<String>> getUsedCurrencies();

  /// 原子生成一笔周期交易并推进 lastGeneratedDate 锚点。
  ///
  /// 交易写入与锚点更新必须在同一事务内完成：锚点更新失败时整体回滚，
  /// 避免下次扫描按旧锚点重复生成同一天交易。返回新交易 id。
  Future<int> generateRecurringTransaction({
    required RecurringTransaction recurring,
    required DateTime happenedAt,
  });

  /// 回填交易作者字段(createdByUserId / lastEditedByUserId / paidByUserId)。
  ///
  /// 本地写入路径(addTransaction / updateTransaction)无法感知当前操作者,
  /// 由 UI 层写完交易后调用本方法补齐作者字段。详见
  /// [LocalTransactionRepository.markTxAuthor] 的兜底规则。
  Future<void> markTxAuthor({
    required int txId,
    required String userId,
    required bool isCreate,
  });
}
