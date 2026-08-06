import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../../../core/logging/logger_service.dart';

/// 共享账本分类表示修复结果。
class SharedLedgerCategoryRepairResult {
  const SharedLedgerCategoryRepairResult({
    required this.fixedTransactions,
    this.skippedLedgers = 0,
  });

  /// 本次被修正存储表示的交易条数。
  final int fixedTransactions;

  /// 镜像表仍为空、本次无法评估的共享账本(Editor)数量。
  /// 大于 0 时调用方不应标记“已修复完成”，等下次镜像就绪后重试。
  final int skippedLedgers;

  static const empty = SharedLedgerCategoryRepairResult(
    fixedTransactions: 0,
  );
}

/// 修复共享账本历史脏数据：同一账本内交易分类的存储表示按角色统一。
///
/// 存量数据中 Owner 分类可能被按 syncId/名称解析成成员自己主表的正数分类 id，
/// 而成员本机新建的交易走 categorySyncIdOverride，导致统计出现两个同名分类、
/// 分类汇总页查不到自己的交易。
///
/// 修复规则：
/// - Editor 视角统一为 categoryId=null + categorySyncIdOverride=Owner 分类 syncId；
/// - Owner 视角统一为 categoryId=主表正数 id + categorySyncIdOverride=null。
///
/// 仅改写本地表示，不写 local_changes：服务端 payload 的 categoryId 本来就是
/// Owner 的 syncId，推送冗余更新只会造成无谓的同步 churn。
class SharedLedgerCategoryRepair {
  SharedLedgerCategoryRepair({required this.db});

  final SpitoutDatabase db;

  /// 扫描所有共享账本并修正历史交易分类表示，返回修正条数。
  Future<SharedLedgerCategoryRepairResult> repair() async {
    var fixed = 0;
    var skipped = 0;
    try {
      await db.transaction(() async {
        final ledgers = await db.select(db.ledgers).get();
        final cats = await db.select(db.categories).get();
        final catIdToSyncId = <int, String?>{
          for (final c in cats) c.id: c.syncId,
        };
        final catSyncIdToId = <String, int>{
          for (final c in cats)
            if (c.syncId != null && c.syncId!.isNotEmpty) c.syncId!: c.id,
        };

        for (final ledger in ledgers) {
          if (!ledger.isShared ||
              ledger.syncId == null ||
              ledger.syncId!.isEmpty) {
            continue;
          }
          final sharedRows = await (db.select(db.sharedLedgerCategories)
                ..where((t) => t.ledgerSyncId.equals(ledger.syncId!)))
              .get();
          final sharedSyncIds = sharedRows.map((r) => r.syncId).toSet();
          final txs = await (db.select(db.transactions)
                ..where((t) => t.ledgerId.equals(ledger.id)))
              .get();

          final isOwner = ledger.myRole == 'owner';
          // Editor 视角镜像为空时无法确认 Owner 分类映射，本次先跳过，
          // 等 SharedResources 拉取到位后由下次启动修复补跑。
          if (!isOwner && sharedSyncIds.isEmpty) {
            skipped++;
            continue;
          }
          for (final tx in txs) {
            fixed += isOwner
                ? await _normalizeOwnerTx(tx, catSyncIdToId)
                : await _normalizeEditorTx(
                    tx,
                    sharedSyncIds,
                    catIdToSyncId,
                  );
          }
        }
      });
    } catch (e, st) {
      logger.error('SharedLedgerCategoryRepair', '共享账本分类表示修复失败', e, st);
      rethrow;
    }
    return SharedLedgerCategoryRepairResult(
      fixedTransactions: fixed,
      skippedLedgers: skipped,
    );
  }

  /// Owner 视角统一主表正数分类 id，并清掉 override。
  Future<int> _normalizeOwnerTx(
    Transaction tx,
    Map<String, int> catSyncIdToId,
  ) async {
    final cov = tx.categorySyncIdOverride;
    if (cov == null || cov.isEmpty) return 0;
    final targetId = catSyncIdToId[cov];
    if (targetId == null) return 0;
    await (db.update(db.transactions)..where((t) => t.id.equals(tx.id)))
        .write(TransactionsCompanion(
      categoryId: d.Value(targetId),
      categorySyncIdOverride: d.Value<String?>(null),
    ));
    return 1;
  }

  /// Editor 视角统一 categorySyncIdOverride，清掉本地正数分类 id。
  Future<int> _normalizeEditorTx(
    Transaction tx,
    Set<String> sharedSyncIds,
    Map<int, String?> catIdToSyncId,
  ) async {
    final cov = tx.categorySyncIdOverride;
    final catId = tx.categoryId;
    if (cov != null && cov.isNotEmpty) {
      if (catId == null) return 0;
      // 双写混合：override 在镜像中则 override 优先；
      // 否则若正数分类在镜像中，则把它提升为 override。
      if (sharedSyncIds.contains(cov)) {
        await _clearCategoryId(tx.id);
        return 1;
      }
      final catSyncId = catIdToSyncId[catId];
      if (catSyncId != null && sharedSyncIds.contains(catSyncId)) {
        await _setOverride(tx.id, catSyncId);
        return 1;
      }
      return 0;
    }
    if (catId == null) return 0;
    final catSyncId = catIdToSyncId[catId];
    if (catSyncId == null ||
        catSyncId.isEmpty ||
        !sharedSyncIds.contains(catSyncId)) {
      return 0;
    }
    await _setOverride(tx.id, catSyncId);
    return 1;
  }

  Future<void> _clearCategoryId(int txId) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(txId)))
        .write(TransactionsCompanion(
      categoryId: d.Value<int?>(null),
    ));
  }

  Future<void> _setOverride(int txId, String syncId) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(txId)))
        .write(TransactionsCompanion(
      categoryId: d.Value<int?>(null),
      categorySyncIdOverride: d.Value<String?>(syncId),
    ));
  }
}
