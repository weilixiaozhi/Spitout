/// 孤儿数据清理器。
///
/// 接 `List<OrphanRecord>` 按 [OrphanType] dispatch 到具体删除路径,所有 DB
/// 修改统一包在一个 Drift `transaction()` 里。失败的 record 收集到 [OrphanCleanResult.failures]
/// 不阻断其余。
///
/// 删除策略:
/// - **A1/A2/A3/A4/A7/A8/A10**:直接删 DB 行(它们本身就是孤儿,无下游引用)
/// - **A6(tx 失主 category)**:**不删** tx,只把 `category_id` 置 null
/// - **A9(共享二级分类失父)**:删 SharedLedgerCategories 行(复合主键)
/// - **A_dup(syncId 重复交易)**:直接删多余重复行(绕过变更追踪,避免把
///   删除推送到云端误删共用同一 syncId 的真实记录)
/// - **C1**:删 local_changes 行
library;

import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../../core/logging/logger_service.dart';
import 'orphan_record.dart';

class OrphanCleaner {
  OrphanCleaner({required this.db});

  final SpitoutDatabase db;

  /// 批量清理。返回 (成功数,失败列表)。
  Future<OrphanCleanResult> clean(List<OrphanRecord> records) async {
    if (records.isEmpty) return OrphanCleanResult.empty;

    final failures = <({OrphanRecord record, String error})>[];
    var success = 0;

    // 分离 DB / sync 两类:DB 操作走一个事务。
    final dbRecords = <OrphanRecord>[];
    final syncRecords = <OrphanRecord>[];
    for (final r in records) {
      switch (r.type) {
        case OrphanType.localChangeMissingEntity:
          syncRecords.add(r);
        default:
          dbRecords.add(r);
      }
    }

    if (dbRecords.isNotEmpty) {
      try {
        await db.transaction(() async {
          for (final r in dbRecords) {
            try {
              await _cleanDb(r);
              success++;
            } catch (e, st) {
              logger.warning('OrphanCleaner',
                  'DB record ${r.uniqueKey} 失败: $e', st);
              failures.add((record: r, error: e.toString()));
            }
          }
        });
      } catch (e, st) {
        // 整个事务失败 — 把 dbRecords 都标失败(success 计数回退)。
        logger.error('OrphanCleaner', 'DB 事务整体失败', e, st);
        // success 反正只在 commit 后才生效,这里事务回滚后 caller 看到的
        // success 是错的 — 重置 + 所有 dbRecords 进 failures。
        success = success - dbRecords.length + failures.length;
        if (success < 0) success = 0;
        for (final r in dbRecords) {
          if (failures.any((f) => f.record.uniqueKey == r.uniqueKey)) continue;
          failures.add((record: r, error: e.toString()));
        }
      }
    }

    for (final r in syncRecords) {
      try {
        await _cleanSync(r);
        success++;
      } catch (e, st) {
        logger.warning('OrphanCleaner',
            'sync record ${r.uniqueKey} 失败: $e', st);
        failures.add((record: r, error: e.toString()));
      }
    }

    return OrphanCleanResult(successCount: success, failures: failures);
  }

  // ─────────────────────────── DB ───────────────────────────

  Future<void> _cleanDb(OrphanRecord r) async {
    switch (r.type) {
      case OrphanType.txMissingCategory:
        await _clearTxCategory(r);
      case OrphanType.categoryMissingParent:
        await _deleteCategory(r);
      case OrphanType.sharedCategoryMissingParent:
        await _deleteSharedCategory(r);
      case OrphanType.txMissingLedger:
        await _deleteTxMissingLedger(r);
      case OrphanType.txDuplicateSyncId:
        await _deleteDuplicateTx(r);
      case OrphanType.localChangeMissingEntity:
        throw StateError('_cleanDb 收到非 DB 类型: ${r.type}');
    }
  }

  /// 把 tx.category_id 置 null,保留交易本体。
  Future<void> _clearTxCategory(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('tx record 缺 localId');
    await (db.update(db.transactions)..where((t) => t.id.equals(id)))
        .write(const TransactionsCompanion(categoryId: d.Value<int?>(null)));
  }

  Future<void> _deleteCategory(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('category record 缺 localId');
    await (db.delete(db.categories)..where((t) => t.id.equals(id))).go();
  }

  /// SharedLedgerCategories 复合主键 (ledger_sync_id, sync_id)。
  Future<void> _deleteSharedCategory(OrphanRecord r) async {
    final syncId = r.syncId;
    final ledgerSyncId = r.extra?['ledgerSyncId'] as String?;
    if (syncId == null || ledgerSyncId == null) {
      throw StateError('shared category record 缺 syncId/ledgerSyncId');
    }
    await (db.delete(db.sharedLedgerCategories)
          ..where((t) =>
              t.ledgerSyncId.equals(ledgerSyncId) & t.syncId.equals(syncId)))
        .go();
  }

  /// A_new:交易的 ledger_id 失主 → 直接删除该交易
  /// 与 A6(清除 categoryId)不同,这里 ledger_id 为 NOT NULL 列,
  /// 无法置空,账本既已删除,关联交易的业务上下文也丢失,故直接 DELETE。
  Future<void> _deleteTxMissingLedger(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('tx missing ledger 缺 localId');
    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
  }

  /// A_dup:删除 sync_id 重复的多余交易行(扫描时已保证保留组内 MIN(id))。
  ///
  /// 关键设计:必须直接走 DB DELETE,绕过 repository/changeTracker。
  /// 若走带变更追踪的删除路径,会生成一条 delete 变更推送到云端,
  /// 因保留行与被删行共用同一 syncId,会把云端的真实记录一并误删。
  Future<void> _deleteDuplicateTx(OrphanRecord r) async {
    final id = r.localId;
    if (id == null) throw StateError('duplicate tx record 缺 localId');
    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
  }

  /// 将一条无账本孤儿交易迁移到指定账本。
  ///
  /// 与删除不同,迁移是保留交易数据,仅更新 ledger_id 到目标账本。
  /// `targetLedgerId` 必须指向一个现存账本,调用方应在打开账本选择器
  /// 时即确保目标合法。
  Future<void> moveTxToLedger(int txId, int targetLedgerId) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(txId)))
        .write(TransactionsCompanion(ledgerId: d.Value(targetLedgerId)));
  }

  /// 批量迁移多条无账本交易到指定账本,返回成功迁移数。
  Future<int> batchMoveTxToLedger(
      List<int> txIds, int targetLedgerId) async {
    var count = 0;
    await db.transaction(() async {
      for (final id in txIds) {
        await (db.update(db.transactions)..where((t) => t.id.equals(id)))
            .write(TransactionsCompanion(ledgerId: d.Value(targetLedgerId)));
        count++;
      }
    });
    return count;
  }

  // ─────────────────────────── Sync ───────────────────────────

  Future<void> _cleanSync(OrphanRecord r) async {
    if (r.type != OrphanType.localChangeMissingEntity) {
      throw StateError('_cleanSync 收到非 sync 类型: ${r.type}');
    }
    final id = r.localId;
    if (id == null) throw StateError('local_change record 缺 localId');
    await (db.delete(db.localChanges)..where((t) => t.id.equals(id))).go();
  }
}
