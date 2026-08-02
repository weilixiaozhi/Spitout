import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../support/change_recorder.dart';
import '../support/snapshot_dirty_marker.dart';
import '../../../utils/currency/rate_math.dart';
import '../../../core/logging/logger_service.dart';
import '../base_repository.dart';
import '../category_repository.dart';
import '../transaction_repository.dart'
    show
        TransactionUpdateBySyncIdData;
import 'local_ledger_repository.dart';
import 'local_transaction_repository.dart';
import 'local_category_repository.dart';
import 'local_statistics_repository.dart';
import 'local_recurring_transaction_repository.dart';
import 'local_exchange_rate_repository.dart';

/// LocalRepository 本地数据库实现
/// 基于 Drift 本地数据库实现所有 Repository 接口
/// 使用委托模式，将具体实现委托给各个子 Repository
class LocalRepository extends BaseRepository {
  /// 底层数据库实例
  /// 仅供需要直接数据库访问的场景使用（如数据库初始化、导入导出）
  final SpitoutDatabase db;

  /// 可选的变更追踪器，用于云同步。
  /// 类型为 data 层抽象 [ChangeRecorder]，具体实现(cloud/sync ChangeTracker)
  /// 由注入点组装，本层不感知 cloud 模块。
  ChangeRecorder? changeTracker;

  /// 可选的快照型后端脏账本标记器(与 [changeTracker] 互斥注入)。
  ///
  /// 类型为 data 层抽象 [SnapshotDirtyMarker]，具体实现
  /// (cloud/sync SnapshotDirtyTracker)由注入点(database_providers)组装。
  /// 仅快照型后端(webdav/s3/supabase)激活时注入,用于登记"账本脏了需要
  /// 重传整本快照"的信号;Spitout Cloud 走 [changeTracker] 增量通道,不注入本字段。
  SnapshotDirtyMarker? snapshotDirtyMarker;

  /// UUID 生成器,批量方法需要预填 syncId 才能查回插入的行登记变更。
  static const _uuid = Uuid();

  // 子 Repository 实例
  late final LocalLedgerRepository _ledgerRepo;
  late final LocalTransactionRepository _transactionRepo;
  late final LocalCategoryRepository _categoryRepo;
  late final LocalStatisticsRepository _statisticsRepo;
  late final LocalRecurringTransactionRepository _recurringTransactionRepo;
  late final LocalExchangeRateRepository _exchangeRateRepo;

  LocalRepository(
    this.db, {
    this.changeTracker,
    this.snapshotDirtyMarker,
  }) {
    // 注入 trackerGetter / snapshotDirtyMarkerGetter:createLedger 在数据层直接
    // 登记变更(增量走 local_changes / 快照走 snapshot_dirty_ledgers),由各自
    // 的 Coordinator 监听驱动同步(规则4),UI 不参与。
    _ledgerRepo = LocalLedgerRepository(
      db,
      trackerGetter: () => changeTracker,
      snapshotDirtyMarkerGetter: () => snapshotDirtyMarker,
    );
    _transactionRepo = LocalTransactionRepository(db);
    _categoryRepo = LocalCategoryRepository(db);
    _statisticsRepo = LocalStatisticsRepository(db);
    _recurringTransactionRepo = LocalRecurringTransactionRepository(db);
    _exchangeRateRepo = LocalExchangeRateRepository(db, trackerGetter: () => changeTracker);
  }

  // ============================================
  // LedgerRepository 接口实现 - 委托给 LocalLedgerRepository
  // ============================================

  @override
  Stream<List<Ledger>> watchLedgers() => _ledgerRepo.watchLedgers();

  @override
  Stream<Ledger?> watchLedger(int id) => _ledgerRepo.watchLedger(id);

  @override
  Future<List<Ledger>> getAllLedgers() => _ledgerRepo.getAllLedgers();

  @override
  Future<Ledger?> getLedgerById(int id) => _ledgerRepo.getLedgerById(id);

  @override
  Future<({int dayCount, int txCount})> getCountsForLedger({required int ledgerId}) =>
      _ledgerRepo.getCountsForLedger(ledgerId: ledgerId);

  @override
  Future<({double expenseTotal, int transactionCount})> getLedgerStats({
    required int ledgerId,
    List<Transaction>? transactions,
  }) =>
      _ledgerRepo.getLedgerStats(
        ledgerId: ledgerId,
        transactions: transactions,
      );

  @override
  Future<int> createLedger({
    required String name,
    String currency = 'CNY',
    String storageMode = 'cloud',
  }) =>
      _ledgerRepo.createLedger(
        name: name,
        currency: currency,
        storageMode: storageMode,
      );

  @override
  Future<void> updateLedgerStorageMode({
    required int id,
    required String storageMode,
  }) =>
      _ledgerRepo.updateLedgerStorageMode(id: id, storageMode: storageMode);

  @override
  Future<void> updateLedgerSyncId({required int id, String? syncId}) =>
      _ledgerRepo.updateLedgerSyncId(id: id, syncId: syncId);

  @override
  Future<void> detachFromCloud(int id) => _ledgerRepo.detachFromCloud(id);

  @override
  Future<void> copyLedgerData({
    required int sourceLedgerId,
    required int targetLedgerId,
  }) =>
      _ledgerRepo.copyLedgerData(
        sourceLedgerId: sourceLedgerId,
        targetLedgerId: targetLedgerId,
      );

  @override
  Future<void> updateLedgerName({required int id, required String name}) =>
      _ledgerRepo.updateLedgerName(id: id, name: name);

  @override
  Future<void> updateLedger(
      {required int id, String? name, String? currency, int? monthStartDay}) async {
    await _ledgerRepo.updateLedger(
        id: id, name: name, currency: currency, monthStartDay: monthStartDay);
    if (changeTracker != null) {
      final row =
          await (db.select(db.ledgers)..where((l) => l.id.equals(id))).getSingleOrNull();
      if (row != null && row.syncId != null && row.syncId!.isNotEmpty) {
        await changeTracker!.recordLedgerChange(
          entityType: 'ledger',
          entityId: id,
          entitySyncId: row.syncId!,
          ledgerId: id,
          action: 'update',
        );
      }
    }
  }

  @override
  Future<void> deleteLedger(int id) async {
    if (changeTracker == null) {
      await _ledgerRepo.deleteLedger(id);
      return;
    }
    // 删除前预查级联会消失的 transactions,删完后逐条登记 delete change。
    // 级联交易一并登记,server 端即使不做级联也能正确收敛;多记不会错,
    // server 重复 delete 是幂等的。
    //
    // 先把 ledger.syncId 拿出来,否则 _ledgerRepo.deleteLedger
    // 之后 ledger 行就没了,后续 _push 拿不到 syncId 推不掉云端账本。
    await db.transaction(() async {
      final ledgerRow = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(id)))
          .getSingleOrNull();
      // ledger.syncId 是 server 端的 external_id,删本地行之后这个值就丢了,
      // 所以必须现在捕获,否则后续无法把删除事件推送到云端。
      final ledgerSyncId = ledgerRow?.syncId ?? id.toString();

      final txs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(id)))
          .get();

      await _ledgerRepo.deleteLedger(id);

      for (final tx in txs) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: id,
          action: 'delete',
        );
      }
      // ledger_snapshot:delete 用 ledger.syncId 作为 entity_sync_id,server
      // 才能按 external_id 找到对应的 ledger 删掉(server 用 syncId/UUID 做
      // external_id,不是本地 int id)。这点跟 sync_engine._pushAllEntities
      // line 2116 `final ledgerId = ledger.syncId ?? ledger.id.toString()`
      // 完全一致。
      await changeTracker!.recordLedgerChange(
        entityType: 'ledger_snapshot',
        entityId: id,
        entitySyncId: ledgerSyncId,
        ledgerId: id,
        action: 'delete',
      );
      logger.info('LocalRepository',
          'deleteLedger($id) 已登记 ${txs.length} 条 transaction:delete + '
          '1 条 ledger_snapshot:delete '
          '(ledgerSyncId=$ledgerSyncId)');
    });
  }

  @override
  Future<void> clearLocalChangesForLedger(int ledgerId) async {
    // 为什么需要这个方法:deleteLedger 会向 local_changes 登记
    // transaction:delete + ledger_snapshot:delete 变更(供正常同步推送)。
    // 但「全局删除账本」场景下远端已经先行删除,这些残留 change 若被
    // SyncCoordinator 捡起会向已删除的远端账本推送、甚至触发快照复活。
    // 因此删除完成后必须一次性抹掉该账本的所有待推送变更。
    final n = await (db.delete(db.localChanges)
          ..where((c) => c.ledgerId.equals(ledgerId)))
        .go();
    logger.info('LocalRepository',
        'clearLocalChangesForLedger($ledgerId) 已清除 $n 条待推送变更');
  }

  @override
  Future<void> purgeSharedLedger(String externalId, {int? localId}) async {
    // purge 是「云端已删除 / 退出」后的本地兜底清除:不写 local_changes,
    // 因为云端状态已经变更,本地只需抹掉残留数据,避免 sync 又被云端重新 upsert 回来。
    // 直接委托给账本子仓执行实际清除。
    await _ledgerRepo.purgeSharedLedger(externalId, localId: localId);
  }

  @override
  Future<void> purgeAllSharedLedgers() async {
    // 云端失活批量清共享账本:不写 local_changes(云端状态已变更,本地只需抹掉
    // 残留数据,避免 sync 又被云端重新 upsert 回来)。直接委托账本子仓执行。
    await _ledgerRepo.purgeAllSharedLedgers();
  }

  @override
  Future<void> purgeAllCloudLedgers() async {
    // 退出登录清理:云端账本数据在服务端,重登会重新拉回,本地无需保留。
    // 同样不写 local_changes —— 这不是用户的删除操作,只是本地副本失效。
    await _ledgerRepo.purgeAllCloudLedgers();
  }

  @override
  Future<({int personal, int shared})> normalizeOrphanCloudLedgers() {
    // 未登录恢复兜底:把孤儿云端账本改写成纯本地账本,一行数据都不删。
    // 同样不写 local_changes —— 这是本地归属修复,不是用户发起的数据变更,
    // 且未登录场景下也没有可推送的目标。
    return _ledgerRepo.normalizeOrphanCloudLedgers();
  }

  @override
  Future<int> getMaxLedgerId() => _ledgerRepo.getMaxLedgerId();

  @override
  Future<int> getNextFreeLedgerId() => _ledgerRepo.getNextFreeLedgerId();

  @override
  Future<void> reassignLedgerId({required int fromId, required int toId}) =>
      _ledgerRepo.reassignLedgerId(fromId: fromId, toId: toId);

  @override
  Future<int> clearLedgerTransactions(int ledgerId) async {
    if (changeTracker == null) {
      return _ledgerRepo.clearLedgerTransactions(ledgerId);
    }
    // 删除前预查 (id, syncId),删完才能登记 N 条 transaction:delete 变更,
    // 否则 UI 调 sync 时 ChangeTracker 为空,云端收不到删除。
    return db.transaction(() async {
      final txs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(ledgerId)))
          .get();
      final n = await _ledgerRepo.clearLedgerTransactions(ledgerId);
      for (final tx in txs) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: ledgerId,
          action: 'delete',
        );
      }
      return n;
    });
  }

  // ============================================
  // TransactionRepository 接口实现 - 委托给 LocalTransactionRepository
  // ============================================

  @override
  Stream<List<Transaction>> watchRecentTransactions({required int ledgerId, int limit = 20}) =>
      _transactionRepo.watchRecentTransactions(ledgerId: ledgerId, limit: limit);

  @override
  Stream<List<Transaction>> watchTransactionsInMonth({required int ledgerId, required DateTime month}) =>
      _transactionRepo.watchTransactionsInMonth(ledgerId: ledgerId, month: month);

  @override
  Stream<List<({Transaction t, Category? category})>> watchTransactionsWithCategoryAll({int? ledgerId}) =>
      _transactionRepo.watchTransactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Stream<List<({Transaction t, Category? category})>> watchTransactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transactionRepo.watchTransactionsWithCategoryInMonth(ledgerId: ledgerId, month: month);

  @override
  Stream<List<({Transaction t, Category? category})>> watchTransactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  }) =>
      _transactionRepo.watchTransactionsWithCategoryInYear(ledgerId: ledgerId, year: year);

  @override
  Stream<List<({Transaction t, Category? category})>> watchTransactionsForCategoryInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    int? categoryId,
    required String type,
  }) =>
      _transactionRepo.watchTransactionsForCategoryInRange(
        ledgerId: ledgerId,
        start: start,
        end: end,
        categoryId: categoryId,
        type: type,
      );

  @override
  Future<int> addTransaction({
    required int ledgerId,
    required String type,
    required double amount,
    int? categoryId,
    required DateTime happenedAt,
    String? note,
    String? syncId,
    String? categorySyncIdOverride,
    bool excludeFromStats = false,
    String? currencyCode,
    double? nativeAmount,
  }) async {
    // 带折算兜底:任何调用方(单币种记账/AI/周期模板)未传两字段
    // 时在此补齐 —— 外币先查有效汇率,取不到则等于 amount,由未折算检测统一捞回。
    final (cc, na) = await _resolveTxCurrency(
      ledgerId: ledgerId,
      amount: amount,
      currencyCode: currencyCode,
      nativeAmount: nativeAmount,
    );
    final id = await _transactionRepo.addTransaction(
      ledgerId: ledgerId,
      type: type,
      amount: amount,
      categoryId: categoryId,
      happenedAt: happenedAt,
      note: note,
      syncId: syncId,
      categorySyncIdOverride: categorySyncIdOverride,
      excludeFromStats: excludeFromStats,
      currencyCode: cc,
      nativeAmount: na,
    );
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx != null) {
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: tx.syncId!,
          ledgerId: ledgerId,
          action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<int> insertTransactionsBatch(
    List<TransactionsCompanion> items, {
    bool recordChanges = true,
  }) async {
    // recordChanges=false:FullPull 走静默写入路径,云端拉下来的数据**不**再
    // 反向 push 回去(否则 10k 条 fullPull 会产生 10k 行 local_changes,触发
    // SyncCoordinator 反向同步,白白多一轮)。
    if (!recordChanges || changeTracker == null || items.isEmpty) {
      return _transactionRepo.insertTransactionsBatch(items);
    }
    // 预填充 syncId,这样插入完能根据 syncId 查回行,逐条登记 create change。
    // 子仓库虽然也会自动补 syncId,但补完是局部变量,wrapper 这里看不到,所
    // 以不能依赖。
    final effective = items.map((item) {
      if (item.syncId == const d.Value.absent() || item.syncId.value == null) {
        return item.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return item;
    }).toList();
    return db.transaction(() async {
      final n = await _transactionRepo.insertTransactionsBatch(effective);
      final syncIds =
          effective.map((c) => c.syncId.value).whereType<String>().toList();
      if (syncIds.isEmpty) return n;
      final inserted = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      for (final tx in inserted) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'create',
        );
      }
      return n;
    });
  }

  @override
  Future<int> updateTransaction({
    required int id,
    required String type,
    required double amount,
    int? categoryId,
    String? note,
    DateTime? happenedAt,
    String? categorySyncIdOverride,
    bool? excludeFromStats,
    String? currencyCode,
    double? nativeAmount,
  }) async {
    final old = await _transactionRepo.getTransactionById(id);
    // 联动兜底:调用方不传两字段时——
    //   仅 amount 变了 → 按该笔隐含汇率联动缩放;amount 未变 → 不动。
    var effCurrency = currencyCode;
    var effNative = nativeAmount;
    if (currencyCode == null && nativeAmount == null && old != null) {
      if (old.nativeAmount != null && old.amount != amount) {
        final oldNative = old.nativeAmount!;
        if (old.amount == 0 || oldNative == old.amount) {
          effNative = amount; // 同币种/未折算(隐含汇率 1)→ 跟随
        } else {
          effNative = oldNative / old.amount * amount; // 外币按隐含汇率缩放
        }
      }
    }
    if (changeTracker != null) {
      if (old?.syncId != null) {
        final version = await _transactionRepo.updateTransaction(
          id: id, type: type, amount: amount,
          categoryId: categoryId, note: note,
          happenedAt: happenedAt,
          categorySyncIdOverride: categorySyncIdOverride,
          excludeFromStats: excludeFromStats,
          currencyCode: effCurrency,
          nativeAmount: effNative,
        );
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: old!.syncId!,
          ledgerId: old.ledgerId,
          action: 'update',
        );
        // 透传内部返回的版本号:无论是否走 changeTracker 路径,
        // UI 层都需要拿到 version 去写编辑历史,避免历史快照版本号缺失。
        return version;
      }
    }
    return _transactionRepo.updateTransaction(
      id: id, type: type, amount: amount,
      categoryId: categoryId, note: note,
      happenedAt: happenedAt,
      categorySyncIdOverride: categorySyncIdOverride,
      excludeFromStats: excludeFromStats,
      currencyCode: effCurrency,
      nativeAmount: effNative,
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    if (changeTracker != null) {
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx?.syncId != null) {
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: tx!.syncId!,
          ledgerId: tx.ledgerId,
          action: 'delete',
        );
      }
    }
    await _transactionRepo.deleteTransaction(id);
  }

  // ==================== 编辑历史 ====================
  // 纯委托:编辑历史是本地展示数据,不参与 cloud sync(同步层只管 transaction
  // 主表的 create/update/delete,历史快照由各端各自记录),故不经 changeTracker。

  @override
  Future<List<RecordEditHistory>> getEditHistories(int recordId) =>
      _transactionRepo.getEditHistories(recordId);

  @override
  Future<int> appendEditHistory({
    required int recordId,
    required int version,
    String? operatorUserId,
    required String summary,
  }) =>
      _transactionRepo.appendEditHistory(
        recordId: recordId,
        version: version,
        operatorUserId: operatorUserId,
        summary: summary,
      );

  @override
  Future<Transaction?> getTransactionById(int id) => _transactionRepo.getTransactionById(id);

  // ---------------------------------------------------------------------
  // 折算兜底 + 重算/检测
  // ---------------------------------------------------------------------

  /// 以 [base] 为本位币合成有效汇率(手动 > 最新自动)。repo 层不读 provider,
  /// 聚合层自身实现 ExchangeRateRepository,直接查表合成。
  Future<Map<String, EffectiveRate>> _effectiveRatesFor(String base) async {
    final autos = await getLatestAutoRates(base);
    final overrides = await getOverrides(base);
    return mergeEffectiveRates(
      autoRates: [
        for (final r in autos)
          (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
      ],
      overrides: [
        for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
      ],
    );
  }

  /// 兜底解析 (currencyCode, nativeAmount):
  /// currencyCode ??= 账本本位币;
  /// nativeAmount ??= 同币种 → amount;外币 → 有效汇率折算,取不到 → amount
  /// (恰命中「未折算外币」检测条件 currencyCode≠base && native==amount,横幅可捞回)。
  Future<(String, double)> _resolveTxCurrency({
    required int ledgerId,
    required double amount,
    String? currencyCode,
    double? nativeAmount,
  }) async {
    // 两字段都显式传入(UI 记账主路径)→ 零查询直通,批量调用不放大 I/O
    if (currencyCode != null && currencyCode.isNotEmpty && nativeAmount != null) {
      return (currencyCode.toUpperCase(), nativeAmount);
    }
    final ledger = await getLedgerById(ledgerId);
    final base = ((ledger?.currency.isNotEmpty ?? false)
            ? ledger!.currency
            : 'CNY')
        .toUpperCase();
    // 币种默认值直接取账本本位币
    var cc = currencyCode?.toUpperCase();
    if (cc == null || cc.isEmpty) {
      cc = base;
    }
    var na = nativeAmount;
    if (na == null) {
      if (cc == base) {
        na = amount;
      } else {
        final rates = await _effectiveRatesFor(base);
        na = computeNativeAmount(
                amount: amount,
                accountCurrency: cc,
                ledgerBase: base,
                rates: rates) ??
            amount;
      }
    }
    return (cc, na);
  }

  /// 重算核心:遍历该账本交易按 [base] 重算 nativeAmount。
  /// [onlyUnconverted]=true → 只补「currencyCode≠base 且 native==amount」的
  /// 存量外币交易;false → 全量(改本位币)。
  /// 每笔改动**必须**逐笔记 change:changeTracker 挂本层,直接 db.update
  /// 不会产生 change,导致云端投影永远是旧值、full_pull 会把重算成果冲回。
  Future<int> _recalcNativeAmounts(
    int ledgerId,
    String base, {
    required bool onlyUnconverted,
  }) =>
      // 单事务包裹:逐笔 UPDATE + change INSERT 不各自 commit/fsync
      // (万笔账本从 ~2 万次独立 commit 降到 1 次)
      db.transaction(() => _recalcNativeAmountsInner(ledgerId, base,
          onlyUnconverted: onlyUnconverted));

  Future<int> _recalcNativeAmountsInner(
    int ledgerId,
    String base, {
    required bool onlyUnconverted,
  }) async {
    final baseUp = base.toUpperCase();
    final rates = await _effectiveRatesFor(baseUp);
    final txs = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    // 币种只读 t.currency_code
    var n = 0;
    for (final t in txs) {
      final cc = (t.currencyCode ?? baseUp).toUpperCase();
      if (cc == baseUp) {
        // 本位币交易:全量重算时对齐 native=amount(改本位币后旧快照失效);
        // 补折算模式跳过(非外币)。
        if (onlyUnconverted || t.nativeAmount == t.amount) continue;
        await (db.update(db.transactions)..where((x) => x.id.equals(t.id)))
            .write(TransactionsCompanion(nativeAmount: d.Value(t.amount)));
      } else {
        if (onlyUnconverted &&
            t.nativeAmount != null &&
            t.nativeAmount != t.amount) {
          continue; // 已折算过,不动(只补从没折算的)
        }
        var na = computeNativeAmount(
            amount: t.amount,
            accountCurrency: cc,
            ledgerBase: baseUp,
            rates: rates);
        if (na == null) {
          if (onlyUnconverted) {
            // 补折算模式:native==amount 原样保留,横幅继续亮,下次有汇率再补
            continue;
          }
          // 全量重算(改本位币):旧 native 是按【旧本位币】折算的,保留它比
          // 1:1 更错,且 native≠amount 会让「未折算」检测永远命中 → 退化 =amount,
          // 让检测横幅能捞回(原 continue 会留下永久静默错值)。
          na = t.amount;
        }
        if (t.nativeAmount == na) continue; // 无变化
        await (db.update(db.transactions)..where((x) => x.id.equals(t.id)))
            .write(TransactionsCompanion(
          nativeAmount: d.Value(na),
          // 不修改 currencyCode:交易原币种是用户记账时选择的,
          // 不随账本主币种变更而改变。少数 currencyCode 为空的交易留待
          // _resolveTxCurrency 在下次写入时补齐。
        ));
      }
      if (changeTracker != null && t.syncId != null) {
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: t.id,
          entitySyncId: t.syncId!,
          ledgerId: ledgerId,
          action: 'update',
        );
      }
      n++;
    }
    if (n > 0) {
      logger.info('LocalRepository',
          '多币种重算完成 ledger=$ledgerId base=$baseUp onlyUnconverted=$onlyUnconverted 改动 $n 笔');
    }
    return n;
  }

  @override
  Future<int> recalcNativeAmountsForLedger(int ledgerId, String newBase) =>
      _recalcNativeAmounts(ledgerId, newBase, onlyUnconverted: false);

  @override
  Future<int> recomputeForeignTxForLedger(int ledgerId) async {
    final ledger = await getLedgerById(ledgerId);
    final base = ((ledger?.currency.isNotEmpty ?? false)
            ? ledger!.currency
            : 'CNY')
        .toUpperCase();
    return _recalcNativeAmounts(ledgerId, base, onlyUnconverted: true);
  }

  @override
  Future<int> countUnconvertedForeignTx(int ledgerId) async {
    final ledger = await getLedgerById(ledgerId);
    final base = ((ledger?.currency.isNotEmpty ?? false)
            ? ledger!.currency
            : 'CNY')
        .toUpperCase();
    // currency_code IS NULL 的行用账本币种兜底
    final row = await db.customSelect(
      'SELECT COUNT(*) AS cnt FROM transactions t '
      'WHERE t.ledger_id = ?1 '
      "AND UPPER(COALESCE(t.currency_code, ?2)) != ?2 "
      'AND t.native_amount = t.amount',
      variables: [d.Variable.withInt(ledgerId), d.Variable.withString(base)],
      readsFrom: {db.transactions},
    ).getSingle();
    return row.read<int>('cnt');
  }

  @override
  Future<int> countForeignCurrencyTx(int ledgerId) async {
    final ledger = await getLedgerById(ledgerId);
    final base = ((ledger?.currency.isNotEmpty ?? false)
            ? ledger!.currency
            : 'CNY')
        .toUpperCase();
    final row = await db.customSelect(
      'SELECT COUNT(*) AS cnt FROM transactions t '
      'WHERE t.ledger_id = ?1 '
      "AND UPPER(COALESCE(t.currency_code, ?2)) != ?2",
      variables: [d.Variable.withInt(ledgerId), d.Variable.withString(base)],
      readsFrom: {db.transactions},
    ).getSingle();
    return row.read<int>('cnt');
  }

  @override
  // 批量插入交易(无标签/附件关联)
  Future<List<int>> insertTransactionsBatchWithRelations({
    required List<TransactionsCompanion> transactions,
    bool recordChanges = true,
  }) async {
    if (transactions.isEmpty) return const [];
    // recordChanges=false / 没挂 changeTracker → 直接走子仓库,不补 change log。
    if (!recordChanges || changeTracker == null) {
      return _transactionRepo.insertTransactionsBatchWithRelations(
        transactions: transactions,
      );
    }
    // 预填充 syncId 让 wrapper 也能根据 syncId 查回行后登记 change(子仓库会
    // 看到这些已填的 syncId,不会重复生成)。
    final effective = transactions.map((tx) {
      if (tx.syncId == const d.Value.absent() || tx.syncId.value == null) {
        return tx.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return tx;
    }).toList();
    return db.transaction(() async {
      final ids = await _transactionRepo.insertTransactionsBatchWithRelations(
        transactions: effective,
      );
      // 一次性 batch insert N 条 transaction:create change,代替逐条
      // recordLedgerChange,把 N 次跨 isolate boundary 摊成 1 次。
      final syncIds =
          effective.map((c) => c.syncId.value).whereType<String>().toList();
      if (syncIds.isEmpty) return ids;
      final inserted = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      await db.batch((b) {
        for (final tx in inserted) {
          if (tx.syncId == null) continue;
          b.insert(
            db.localChanges,
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: tx.id,
              entitySyncId: tx.syncId!,
              ledgerId: tx.ledgerId,
              action: 'create',
            ),
          );
        }
      });
      return ids;
    });
  }

  @override
  Future<int> insertTransactionCompanion(
    TransactionsCompanion item, {
    bool recordChanges = true,
  }) async {
    if (!recordChanges || changeTracker == null) {
      return _transactionRepo.insertTransactionCompanion(item);
    }
    // 此处只做交易自身插入与 change 登记。
    return db.transaction(() async {
      final id = await _transactionRepo.insertTransactionCompanion(item);
      final tx = await _transactionRepo.getTransactionById(id);
      if (tx != null && tx.syncId != null) {
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'create',
        );
      }
      return id;
    });
  }

  @override
  Stream<List<({Transaction t, Category? category})>> transactionsWithCategoryAll({int? ledgerId}) =>
      _transactionRepo.transactionsWithCategoryAll(ledgerId: ledgerId);

  @override
  Future<List<({Transaction t, Category? category})>> getRecentTransactionsWithCategory({
    required int ledgerId,
    required int limit,
  }) =>
      _transactionRepo.getRecentTransactionsWithCategory(ledgerId: ledgerId, limit: limit);

  @override
  Future<int> countByTypeInRange({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
      _transactionRepo.countByTypeInRange(
        ledgerId: ledgerId,
        type: type,
        start: start,
        end: end,
      );

  @override
  Future<List<Transaction>> getTransactionsByLedger(int ledgerId) =>
      _transactionRepo.getTransactionsByLedger(ledgerId);

  @override
  Future<List<Transaction>> getTransactionsByLedgerInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) =>
      _transactionRepo.getTransactionsByLedgerInRange(
        ledgerId: ledgerId,
        start: start,
        end: end,
      );

  @override
  Future<void> updateTransactionLedger({required int id, required int ledgerId}) async {
    await _transactionRepo.updateTransactionLedger(id: id, ledgerId: ledgerId);
    // nativeAmount 是按【原账本】本位币折算的快照,跨账本移动后必须按
    // 新账本本位币重算;缺汇率退化 =amount,绝不保留旧口径错值
    // (已折算外币移动后 native≠amount,「未折算」检测永远命中)。
    final tx = await _transactionRepo.getTransactionById(id);
    if (tx == null) return;
    final ledger = await getLedgerById(ledgerId);
    final base = ((ledger?.currency.isNotEmpty ?? false)
            ? ledger!.currency
            : 'CNY')
        .toUpperCase();
    final cc = (tx.currencyCode ?? base).toUpperCase();
    double na;
    if (cc == base) {
      na = tx.amount;
    } else {
      final rates = await _effectiveRatesFor(base);
      na = computeNativeAmount(
              amount: tx.amount,
              accountCurrency: cc,
              ledgerBase: base,
              rates: rates) ??
          tx.amount;
    }
    if (na != tx.nativeAmount) {
      await (db.update(db.transactions)..where((x) => x.id.equals(id)))
          .write(TransactionsCompanion(nativeAmount: d.Value(na)));
    }
    if (changeTracker != null && tx.syncId != null) {
      await changeTracker!.recordLedgerChange(
        entityType: 'transaction',
        entityId: id,
        entitySyncId: tx.syncId!,
        ledgerId: ledgerId,
        action: 'update',
      );
    }
  }

  /// 该账本交易涉及的全部外币币种(≠本位币,含 currencyCode 为空的兜底判定)。
  /// 补折算/改本位币重算前把它们并入汇率拉取(extraQuotes),否则
  /// CSV 导入/手选的币种拉不到汇率,重算永远补不上。
  @override
  Future<Set<String>> getLedgerForeignCurrencies(int ledgerId) async {
    final ledger = await getLedgerById(ledgerId);
    final base = ((ledger?.currency.isNotEmpty ?? false)
            ? ledger!.currency
            : 'CNY')
        .toUpperCase();
    final rows = await db.customSelect(
      'SELECT DISTINCT UPPER(COALESCE(t.currency_code, ?2)) AS cc '
      'FROM transactions t '
      'WHERE t.ledger_id = ?1',
      variables: [d.Variable.withInt(ledgerId), d.Variable.withString(base)],
      readsFrom: {db.transactions},
    ).get();
    return {
      for (final r in rows)
        if (r.read<String>('cc') != base) r.read<String>('cc')
    };
  }

  /// 共享账本:本地 tx 写完后回填 createdByUserId / lastEditedByUserId。
  /// 详见 [LocalTransactionRepository.markTxAuthor]。
  Future<void> markTxAuthor({
    required int txId,
    required String userId,
    required bool isCreate,
  }) =>
      _transactionRepo.markTxAuthor(
        txId: txId,
        userId: userId,
        isCreate: isCreate,
      );

  // ==================== 日历功能相关 ====================

  @override
  Future<Map<String, double>> getDailyTotalsByMonth({
    required int ledgerId,
    required DateTime month,
  }) =>
      _transactionRepo.getDailyTotalsByMonth(ledgerId: ledgerId, month: month);

  @override
  // 返回单日交易及其关联分类（不含 tags / 附件等附加字段）
  Future<List<({Transaction t, Category? category})>> getTransactionsByDate({
    required int ledgerId,
    required DateTime date,
  }) =>
      _transactionRepo.getTransactionsByDate(ledgerId: ledgerId, date: date);

  @override
  Future<Transaction?> getTransactionBySyncId(String syncId) =>
      _transactionRepo.getTransactionBySyncId(syncId);

  @override
  Future<void> updateTransactionBySyncId({
    required String syncId,
    required String type,
    required double amount,
    int? categoryId,
    required DateTime happenedAt,
    String? note,
  }) =>
      _transactionRepo.updateTransactionBySyncId(
        syncId: syncId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        happenedAt: happenedAt,
        note: note,
      );

  @override
  Future<void> deleteTransactionBySyncId(String syncId) =>
      _transactionRepo.deleteTransactionBySyncId(syncId);

  @override
  Future<Map<String, int>> updateTransactionsBatchBySyncId(
    List<TransactionUpdateBySyncIdData> updates, {
    bool recordChanges = true,
  }) async {
    if (updates.isEmpty) return const {};
    if (!recordChanges || changeTracker == null) {
      return _transactionRepo.updateTransactionsBatchBySyncId(updates);
    }
    return db.transaction(() async {
      final syncIdToTxId =
          await _transactionRepo.updateTransactionsBatchBySyncId(updates);
      if (syncIdToTxId.isEmpty) return syncIdToTxId;
      // 反查 ledgerId 用于 change log
      final txs = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIdToTxId.keys.toList())))
          .get();
      await db.batch((b) {
        for (final tx in txs) {
          if (tx.syncId == null) continue;
          b.insert(
            db.localChanges,
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: tx.id,
              entitySyncId: tx.syncId!,
              ledgerId: tx.ledgerId,
              action: 'update',
            ),
          );
        }
      });
      return syncIdToTxId;
    });
  }

  @override
  Future<int> deleteTransactionsBatchBySyncIds(
    List<String> syncIds, {
    bool recordChanges = true,
  }) async {
    if (syncIds.isEmpty) return 0;
    // recordChanges=false / 无 changeTracker → 直接走子仓库,不写 change log
    if (!recordChanges || changeTracker == null) {
      return _transactionRepo.deleteTransactionsBatchBySyncIds(syncIds);
    }
    return db.transaction(() async {
      // 先 SELECT 出待删的 tx(留下 ledgerId / syncId 用于 change log)
      final rows = await (db.select(db.transactions)
            ..where((t) => t.syncId.isIn(syncIds)))
          .get();
      if (rows.isEmpty) return 0;
      final deleted =
          await _transactionRepo.deleteTransactionsBatchBySyncIds(syncIds);
      // 一次性 batch insert N 条 transaction:delete change,代替逐条
      // recordLedgerChange,跨 isolate boundary 从 N 次降到 1 次。
      await db.batch((b) {
        for (final tx in rows) {
          if (tx.syncId == null) continue;
          b.insert(
            db.localChanges,
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: tx.id,
              entitySyncId: tx.syncId!,
              ledgerId: tx.ledgerId,
              action: 'delete',
            ),
          );
        }
      });
      return deleted;
    });
  }

  // ============================================
  // CategoryRepository 接口实现 - 委托给 LocalCategoryRepository
  // ============================================

  @override
  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    int level = 1,
    int? parentId,
    String? syncId,
  }) async {
    final id = await _categoryRepo.createCategory(
      name: name,
      kind: kind,
      icon: icon,
      sortOrder: sortOrder,
      level: level,
      parentId: parentId,
      syncId: syncId,
    );
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<int> createSubCategory({
    required int parentId,
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    String? syncId,
  }) async {
    final id = await _categoryRepo.createSubCategory(
      parentId: parentId, name: name, kind: kind, icon: icon,
      sortOrder: sortOrder, syncId: syncId,
    );
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, action: 'create',
        );
      }
    }
    return id;
  }

  @override
  Future<void> updateCategory(int id, {String? name, String? icon, int? parentId, int? level}) async {
    final cat = changeTracker != null ? await _categoryRepo.getCategoryById(id) : null;
    await _categoryRepo.updateCategory(id, name: name, icon: icon, parentId: parentId, level: level);
    if (cat?.syncId != null) {
      await changeTracker!.recordUserGlobalChange(
        entityType: 'category', entityId: id,
        entitySyncId: cat!.syncId!, action: 'update',
      );
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    if (changeTracker != null) {
      final cat = await _categoryRepo.getCategoryById(id);
      if (cat?.syncId != null) {
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category', entityId: id,
          entitySyncId: cat!.syncId!, action: 'delete',
        );
      }
    }
    await _categoryRepo.deleteCategory(id);
  }

  @override
  Future<void> deleteCategoriesByIds(List<int> ids) async {
    if (changeTracker == null || ids.isEmpty) {
      logger.info('LocalRepository',
          'deleteCategoriesByIds(${ids.length}): changeTracker=null=${changeTracker == null} → 不登记 change');
      return _categoryRepo.deleteCategoriesByIds(ids);
    }
    // 子仓库会同时删 ids 自身和 parent_id 在 ids 里的子分类,所以这里也要把
    // 子分类的 syncId 一并预查出来登记 delete change。
    await db.transaction(() async {
      final cats = await (db.select(db.categories)
            ..where((c) => c.id.isIn(ids) | c.parentId.isIn(ids)))
          .get();
      await _categoryRepo.deleteCategoriesByIds(ids);
      var recorded = 0;
      var skippedNoSyncId = 0;
      for (final c in cats) {
        if (c.syncId == null) {
          skippedNoSyncId++;
          continue;
        }
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category',
          entityId: c.id,
          entitySyncId: c.syncId!,
          action: 'delete',
        );
        recorded++;
      }
      logger.info('LocalRepository',
          'deleteCategoriesByIds(${ids.length}): 预查到 ${cats.length} 行,'
          '登记 $recorded 条 category:delete change'
          '${skippedNoSyncId > 0 ? ", $skippedNoSyncId 条因 syncId=null 跳过(本地未同步过的种子分类)" : ""}');
    });
  }

  @override
  Future<int> deleteTransactionsByCategoryIds(List<int> categoryIds) async {
    if (changeTracker == null || categoryIds.isEmpty) {
      return _categoryRepo.deleteTransactionsByCategoryIds(categoryIds);
    }
    // 变更追踪：预查受影响的交易，删除后逐条登记 delete change
    return db.transaction(() async {
      final affected = await (db.select(db.transactions)
            ..where((t) => t.categoryId.isIn(categoryIds)))
          .get();
      final count = await _categoryRepo.deleteTransactionsByCategoryIds(categoryIds);
      for (final tx in affected) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'delete',
        );
      }
      return count;
    });
  }

  @override
  Future<int> promoteSubCategoriesToTopLevel(int parentId) async {
    if (changeTracker == null) {
      return _categoryRepo.promoteSubCategoriesToTopLevel(parentId);
    }
    // 变更追踪：预查子分类，提升后逐条登记 update change
    return db.transaction(() async {
      final subCategories = await _categoryRepo.getSubCategories(parentId);
      final count = await _categoryRepo.promoteSubCategoriesToTopLevel(parentId);
      for (final sub in subCategories) {
        if (sub.syncId == null) continue;
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category',
          entityId: sub.id,
          entitySyncId: sub.syncId!,
          action: 'update',
        );
      }
      return count;
    });
  }

  @override
  Future<int> upsertCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  }) =>
      _categoryRepo.upsertCategory(
          name: name, kind: kind, icon: icon, sortOrder: sortOrder);

  @override
  Future<Category?> getCategoryById(int categoryId) =>
      _categoryRepo.getCategoryById(categoryId);

  @override
  Future<Category?> findCategoryBySyntheticId(int id) =>
      _categoryRepo.findCategoryBySyntheticId(id);

  @override
  Future<List<Category>> filterCategoriesForLedgerPicker(
    List<Category> all, {
    int? ledgerId,
    String? kind,
    bool topLevelOnly = true,
  }) =>
      _categoryRepo.filterCategoriesForLedgerPicker(
        all,
        ledgerId: ledgerId,
        kind: kind,
        topLevelOnly: topLevelOnly,
      );

  @override
  Future<Map<int, Category>> getCategoriesByIds(Iterable<int> ids) =>
      _categoryRepo.getCategoriesByIds(ids);

  @override
  Future<List<Category>> getTopLevelCategories(String kind) =>
      _categoryRepo.getTopLevelCategories(kind);

  @override
  Future<List<Category>> getSubCategories(int parentId) =>
      _categoryRepo.getSubCategories(parentId);

  @override
  Future<CategoryPickerTree> getCategoryTree(String kind) =>
      _categoryRepo.getCategoryTree(kind);

  @override
  Future<List<Category>> getUsableCategories(String kind) =>
      _categoryRepo.getUsableCategories(kind);

  @override
  Future<bool> isCategoryNameDuplicate({required String name, required String kind, int? excludeId, int? parentId}) =>
      _categoryRepo.isCategoryNameDuplicate(name: name, kind: kind, excludeId: excludeId, parentId: parentId);

  @override
  Future<bool> hasSubCategories(int categoryId) =>
      _categoryRepo.hasSubCategories(categoryId);

  @override
  Future<int> getSubCategoryCount(int categoryId) =>
      _categoryRepo.getSubCategoryCount(categoryId);

  @override
  Future<int> getTransactionCountByCategory(int categoryId) =>
      _categoryRepo.getTransactionCountByCategory(categoryId);

  @override
  Future<Map<int, int>> getAllCategoryTransactionCounts() =>
      _categoryRepo.getAllCategoryTransactionCounts();

  @override
  Future<({int totalCount, double totalAmount, double averageAmount})> getCategorySummary(int categoryId) =>
      _categoryRepo.getCategorySummary(categoryId);

  @override
  Future<List<Transaction>> getTransactionsByCategory(int categoryId) =>
      _categoryRepo.getTransactionsByCategory(categoryId);

  @override
  Future<List<Transaction>> getTransactionsByCategoryWithSort(
    int categoryId, {
    String sortBy = 'time',
    bool ascending = false,
  }) =>
      _categoryRepo.getTransactionsByCategoryWithSort(
        categoryId,
        sortBy: sortBy,
        ascending: ascending,
      );

  @override
  Future<int> migrateCategory({required int fromCategoryId, required int toCategoryId}) async {
    if (changeTracker == null) {
      return _categoryRepo.migrateCategory(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );
    }
    return db.transaction(() async {
      // 预查受影响的交易,迁移完后逐条登记 update change。
      final affected = await (db.select(db.transactions)
            ..where((t) => t.categoryId.equals(fromCategoryId)))
          .get();
      final n = await _categoryRepo.migrateCategory(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );
      for (final tx in affected) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'update',
        );
      }
      return n;
    });
  }

  @override
  Future<({int migratedTransactions, int migratedSubCategories})> migrateCategoryTransactions({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    if (changeTracker == null) {
      return _categoryRepo.migrateCategoryTransactions(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );
    }
    return db.transaction(() async {
      // 预查 fromCategory + 子分类(level=1 时),以及所有可能受影响的交易。
      // 子分类有两种命运:
      //   - 目标父类下已有同名 → 子分类被合并(删除)
      //   - 没有同名 → 子分类被移动(parentId 改变)
      // 用"迁移前 vs 迁移后"对比来区分这两种情况,避免提前 hardcode 决策。
      final fromCategory = await _categoryRepo.getCategoryById(fromCategoryId);
      final subCategories = fromCategory?.level == 1
          ? await _categoryRepo.getSubCategories(fromCategoryId)
          : <Category>[];
      final affectedCategoryIds = [
        fromCategoryId,
        ...subCategories.map((s) => s.id),
      ];
      final affectedTxs = await (db.select(db.transactions)
            ..where((t) => t.categoryId.isIn(affectedCategoryIds)))
          .get();

      final result = await _categoryRepo.migrateCategoryTransactions(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );

      // 受影响交易: categoryId 变了,登记 update。
      for (final tx in affectedTxs) {
        if (tx.syncId == null) continue;
        await changeTracker!.recordLedgerChange(
          entityType: 'transaction',
          entityId: tx.id,
          entitySyncId: tx.syncId!,
          ledgerId: tx.ledgerId,
          action: 'update',
        );
      }
      // 子分类:迁移后查不到 → 被合并删除;parentId 变了 → 被移动。
      for (final sub in subCategories) {
        if (sub.syncId == null) continue;
        final after = await _categoryRepo.getCategoryById(sub.id);
        if (after == null) {
          await changeTracker!.recordUserGlobalChange(
            entityType: 'category',
            entityId: sub.id,
            entitySyncId: sub.syncId!,
            action: 'delete',
          );
        } else if (after.parentId != sub.parentId) {
          await changeTracker!.recordUserGlobalChange(
            entityType: 'category',
            entityId: sub.id,
            entitySyncId: sub.syncId!,
            action: 'update',
          );
        }
      }
      return result;
    });
  }

  @override
  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo({
    required int fromCategoryId,
    required int toCategoryId,
  }) =>
      _categoryRepo.getCategoryMigrationInfo(
        fromCategoryId: fromCategoryId,
        toCategoryId: toCategoryId,
      );

  @override
  Future<void> updateCategorySortOrders(List<({int id, int sortOrder})> updates) =>
      _categoryRepo.updateCategorySortOrders(updates);

  @override
  Future<String> getCategoryFullName(int categoryId) =>
      _categoryRepo.getCategoryFullName(categoryId);

  @override
  Stream<Category?> watchCategory(int categoryId) =>
      _categoryRepo.watchCategory(categoryId);

  @override
  Stream<List<Transaction>> watchTransactionsByCategory(
    int categoryId, {
    int? ledgerId,
    bool includeSubCategories = false,
  }) =>
      _categoryRepo.watchTransactionsByCategory(
        categoryId,
        ledgerId: ledgerId,
        includeSubCategories: includeSubCategories,
      );

  @override
  Stream<List<Category>> watchCategoryWithSubs(int categoryId) =>
      _categoryRepo.watchCategoryWithSubs(categoryId);

  @override
  Stream<List<({Category category, int transactionCount})>> watchCategoriesWithCount() =>
      _categoryRepo.watchCategoriesWithCount();

  @override
  Future<List<Category>> getAllCategories() => _categoryRepo.getAllCategories();

  @override
  Future<List<Category>> getAllCategoriesIncludingShared() =>
      _categoryRepo.getAllCategoriesIncludingShared();

  @override
  Future<void> batchInsertCategories(List<CategoriesCompanion> categories) async {
    if (changeTracker == null || categories.isEmpty) {
      return _categoryRepo.batchInsertCategories(categories);
    }
    // 预填充 syncId 以便插入后查回登记 create change。子仓库 batchInsert
    // 不会自动补 syncId,companion 里没有的会被插成 NULL,跨设备同步对不上。
    final effective = categories.map((c) {
      if (c.syncId == const d.Value.absent() || c.syncId.value == null) {
        return c.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return c;
    }).toList();
    await db.transaction(() async {
      await _categoryRepo.batchInsertCategories(effective);
      final syncIds =
          effective.map((c) => c.syncId.value).whereType<String>().toList();
      if (syncIds.isEmpty) return;
      final inserted = await (db.select(db.categories)
            ..where((c) => c.syncId.isIn(syncIds)))
          .get();
      for (final c in inserted) {
        if (c.syncId == null) continue;
        await changeTracker!.recordUserGlobalChange(
          entityType: 'category',
          entityId: c.id,
          entitySyncId: c.syncId!,
          action: 'create',
        );
      }
    });
  }

  @override
  Future<int> insertCategory(CategoriesCompanion category) =>
      _categoryRepo.insertCategory(category);

  @override
  Future<Set<String>> getUsedCurrencies() async {
    // 直接从 transactions 表的 currency_code 字段 distinct 查询
    final rows = await db.customSelect(
      "SELECT DISTINCT currency_code FROM transactions "
      "WHERE currency_code IS NOT NULL AND currency_code != ''",
    ).get();
    return rows.map((r) => r.read<String>('currency_code')).toSet();
  }

  // ============================================
  // StatisticsRepository 接口实现 - 委托给 LocalStatisticsRepository
  // ============================================

  @override
  Future<List<({int? id, String name, String? icon, double total})>> totalsByCategory({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
      _statisticsRepo.totalsByCategory(
        ledgerId: ledgerId,
        type: type,
        start: start,
        end: end,
      );

  @override
  Future<List<({int? id, String name, String? icon, int? parentId, int level, double total})>>
      totalsByCategoryWithHierarchy({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
          _statisticsRepo.totalsByCategoryWithHierarchy(
            ledgerId: ledgerId,
            type: type,
            start: start,
            end: end,
          );

  @override
  Future<List<({DateTime day, double total})>> totalsByDay({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) =>
      _statisticsRepo.totalsByDay(
        ledgerId: ledgerId,
        type: type,
        start: start,
        end: end,
      );

  @override
  Future<List<({DateTime month, double total})>> totalsByMonth({
    required int ledgerId,
    required String type,
    required int year,
  }) =>
      _statisticsRepo.totalsByMonth(
        ledgerId: ledgerId,
        type: type,
        year: year,
      );

  @override
  Future<List<({int year, double total})>> totalsByYearSeries({
    required int ledgerId,
    required String type,
  }) =>
      _statisticsRepo.totalsByYearSeries(
        ledgerId: ledgerId,
        type: type,
      );

  @override
  Future<DateTime?> earliestExpenseDate({required int ledgerId}) =>
      _statisticsRepo.earliestExpenseDate(ledgerId: ledgerId);

  @override
  Future<DateTime?> latestExpenseDate({required int ledgerId}) =>
      _statisticsRepo.latestExpenseDate(ledgerId: ledgerId);

  @override
  Future<bool> hasAnyExpenseTx({required int ledgerId}) =>
      _statisticsRepo.hasAnyExpenseTx(ledgerId: ledgerId);

  @override
  Future<double> totalsInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) =>
      _statisticsRepo.totalsInRange(
        ledgerId: ledgerId,
        start: start,
        end: end,
      );

  @override
  Future<double> monthlyTotals({
    required int ledgerId,
    required DateTime month,
  }) =>
      _statisticsRepo.monthlyTotals(
        ledgerId: ledgerId,
        month: month,
      );

  @override
  Future<double> todayExpense({
    required int ledgerId,
    required DateTime now,
  }) =>
      _statisticsRepo.todayExpense(ledgerId: ledgerId, now: now);

  @override
  Future<double> weekExpense({
    required int ledgerId,
    required DateTime now,
  }) =>
      _statisticsRepo.weekExpense(ledgerId: ledgerId, now: now);

  @override
  Future<double> yearlyTotals({
    required int ledgerId,
    required int year,
  }) =>
      _statisticsRepo.yearlyTotals(
        ledgerId: ledgerId,
        year: year,
      );

  @override
  Future<Map<int, Category>> getSharedSyntheticCategoriesForLedger(
          int ledgerId) =>
      _statisticsRepo.getSharedSyntheticCategoriesForLedger(ledgerId);

  // ============================================
  // RecurringTransactionRepository 接口实现 - 委托给 LocalRecurringTransactionRepository
  // ============================================

  @override
  Future<List<RecurringTransaction>> getAllRecurringTransactions() =>
      _recurringTransactionRepo.getAllRecurringTransactions();

  @override
  Future<List<RecurringTransaction>> getRecurringTransactionsByLedger(int ledgerId) =>
      _recurringTransactionRepo.getRecurringTransactionsByLedger(ledgerId);

  @override
  Future<List<RecurringTransaction>> getEnabledRecurringTransactions(int ledgerId) =>
      _recurringTransactionRepo.getEnabledRecurringTransactions(ledgerId);

  @override
  Future<int> addRecurringTransaction({
    required int ledgerId,
    required String type,
    required double amount,
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
  }) =>
      _recurringTransactionRepo.addRecurringTransaction(
        ledgerId: ledgerId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        note: note,
        frequency: frequency,
        interval: interval,
        dayOfMonth: dayOfMonth,
        dayOfWeek: dayOfWeek,
        monthOfYear: monthOfYear,
        startDate: startDate,
        endDate: endDate,
        enabled: enabled,
      );

  @override
  Future<void> updateRecurringTransaction({
    required int id,
    required int ledgerId,
    required String type,
    required double amount,
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
    DateTime? lastGeneratedDate,
  }) =>
      _recurringTransactionRepo.updateRecurringTransaction(
        id: id,
        ledgerId: ledgerId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        note: note,
        frequency: frequency,
        interval: interval,
        dayOfMonth: dayOfMonth,
        dayOfWeek: dayOfWeek,
        monthOfYear: monthOfYear,
        startDate: startDate,
        endDate: endDate,
        enabled: enabled,
        lastGeneratedDate: lastGeneratedDate,
      );

  @override
  Future<void> deleteRecurringTransaction(int id) =>
      _recurringTransactionRepo.deleteRecurringTransaction(id);

  @override
  Future<void> toggleRecurringTransaction(int id, bool enabled) =>
      _recurringTransactionRepo.toggleRecurringTransaction(id, enabled);

  @override
  Future<void> updateLastGeneratedDate(int id, DateTime date) =>
      _recurringTransactionRepo.updateLastGeneratedDate(id, date);

  @override
  Stream<List<RecurringTransaction>> watchAllRecurringTransactions() =>
      _recurringTransactionRepo.watchAllRecurringTransactions();

  @override
  Stream<List<RecurringTransaction>> watchRecurringTransactionsByLedger(int ledgerId) =>
      _recurringTransactionRepo.watchRecurringTransactionsByLedger(ledgerId);

  @override
  Future<void> batchInsertRecurringTransactions(List<RecurringTransactionsCompanion> items) =>
      _recurringTransactionRepo.batchInsertRecurringTransactions(items);



  // ============================================
  // ExchangeRateRepository 接口实现 - 委托给 LocalExchangeRateRepository
  // ============================================

  @override
  Future<void> upsertAutoRates({
    required String base,
    required String rateDate,
    required Map<String, String> rates,
    required String source,
    required DateTime fetchedAt,
  }) =>
      _exchangeRateRepo.upsertAutoRates(
        base: base, rateDate: rateDate, rates: rates,
        source: source, fetchedAt: fetchedAt,
      );

  @override
  Future<List<ExchangeRate>> getLatestAutoRates(String base) =>
      _exchangeRateRepo.getLatestAutoRates(base);

  @override
  Future<DateTime?> getLastFetchedAt(String base) =>
      _exchangeRateRepo.getLastFetchedAt(base);

  @override
  Future<List<ExchangeRateOverride>> getOverrides(String base) =>
      _exchangeRateRepo.getOverrides(base);

  @override
  Stream<List<ExchangeRateOverride>> watchOverrides(String base) =>
      _exchangeRateRepo.watchOverrides(base);

  @override
  Future<void> setOverride({
    required String base,
    required String quote,
    required String rate,
  }) =>
      _exchangeRateRepo.setOverride(base: base, quote: quote, rate: rate);

  @override
  Future<void> removeOverride({required String base, required String quote}) =>
      _exchangeRateRepo.removeOverride(base: base, quote: quote);
}
