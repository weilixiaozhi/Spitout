import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' as fcs;
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/data/repositories/local/local_transaction_repository.dart'
    show TransactionUpdateBySyncIdData;
import 'package:spitout/data/repositories/support/data_import_port.dart';
import 'package:spitout/utils/currency/money_cents.dart';
import 'package:spitout/core/logging/logger_service.dart';

/// 同步变更类型
enum SyncChangeType { added, modified, deleted }

/// 单条变更
class SyncChange {
  final SyncChangeType type;

  /// 云端版本（added/modified 有值）
  final ImportTransaction? cloudTransaction;

  /// 本地版本（modified/deleted 有值）
  final Transaction? localTransaction;

  /// 用户是否选中，默认 true
  bool selected;

  /// 变更描述（用于 modified 类型显示差异）
  final List<String> diffDetails;

  SyncChange({
    required this.type,
    this.cloudTransaction,
    this.localTransaction,
    this.selected = true,
    this.diffDetails = const [],
  });
}

/// Diff 预览结果
class SyncPreview {
  final List<SyncChange> changes;

  int get addedCount =>
      changes.where((c) => c.type == SyncChangeType.added).length;

  int get modifiedCount =>
      changes.where((c) => c.type == SyncChangeType.modified).length;

  int get deletedCount =>
      changes.where((c) => c.type == SyncChangeType.deleted).length;

  bool get isEmpty => changes.isEmpty;

  int get selectedCount => changes.where((c) => c.selected).length;

  const SyncPreview({required this.changes});
}

/// 应用变更结果
class SyncApplyResult {
  final int addedCount;
  final int modifiedCount;
  final int deletedCount;

  const SyncApplyResult({
    this.addedCount = 0,
    this.modifiedCount = 0,
    this.deletedCount = 0,
  });

  int get totalCount => addedCount + modifiedCount + deletedCount;
}

/// Diff 计算服务
class SyncDiffService {
  final DataImportPort dataImportPort;

  SyncDiffService({required this.dataImportPort});

  /// 计算本地与云端的差异
  ///
  /// [repo] - 数据仓库
  /// [ledgerId] - 账本 ID
  /// [cloudTransactions] - 云端交易列表（含 syncId）
  /// [localTransactions] - 本地交易列表（可选，不传则自动查询）
  ///
  /// 返回 null 表示云端数据不含 syncId，无法计算 diff
  Future<SyncPreview?> computeDiff({
    required LocalRepository repo,
    required int ledgerId,
    required List<ImportTransaction> cloudTransactions,
    List<Transaction>? localTransactions,
  }) async {
    // 检查云端数据是否含有 syncId
    final hasSyncId = cloudTransactions.any((t) => t.syncId != null);
    if (!hasSyncId && cloudTransactions.isNotEmpty) {
      logger.info('SyncDiff', '云端数据不含 syncId，无法计算 diff');
      return null;
    }

    // 获取本地交易
    final local = localTransactions ??
        await repo.getTransactionsByLedger(ledgerId);

    // 账本本位币：币种比较时双方 NULL 都按本位币兜底。
    final ledger = await repo.getLedgerById(ledgerId);
    final ledgerBase =
        ((ledger?.currency.isNotEmpty ?? false) ? ledger!.currency : 'CNY')
            .toUpperCase();

    // 本地分类 id → (name, kind) 映射，用于分类差异比较
    // （本地只有 int id，云端只有 name/kind）。
    final categoryMap = <int, ({String name, String kind})>{};
    for (final c in await repo.getTopLevelCategories('expense')) {
      categoryMap[c.id] = (name: c.name, kind: c.kind);
      for (final sub in await repo.getSubCategories(c.id)) {
        categoryMap[sub.id] = (name: sub.name, kind: sub.kind);
      }
    }

    // 建立映射：syncId → 交易
    final localBySyncId = <String, Transaction>{};
    for (final tx in local) {
      if (tx.syncId != null) {
        localBySyncId[tx.syncId!] = tx;
      }
    }

    final cloudBySyncId = <String, ImportTransaction>{};
    for (final tx in cloudTransactions) {
      if (tx.syncId != null) {
        cloudBySyncId[tx.syncId!] = tx;
      }
    }

    final changes = <SyncChange>[];

    // 1. 遍历云端交易
    for (final entry in cloudBySyncId.entries) {
      final syncId = entry.key;
      final cloudTx = entry.value;
      final localTx = localBySyncId[syncId];

      if (localTx == null) {
        // 云端有、本地无 → added
        changes.add(SyncChange(
          type: SyncChangeType.added,
          cloudTransaction: cloudTx,
        ));
      } else {
        // 都有，检查是否有差异
        final diffs = _compareTx(
          localTx,
          cloudTx,
          categoryMap,
          ledgerBase,
        );
        if (diffs.isNotEmpty) {
          changes.add(SyncChange(
            type: SyncChangeType.modified,
            cloudTransaction: cloudTx,
            localTransaction: localTx,
            diffDetails: diffs,
          ));
        }
        // 相同 → unchanged，不加入变更列表
      }
    }

    // 2. 遍历本地交易，查找本地有但云端无的
    for (final entry in localBySyncId.entries) {
      final syncId = entry.key;
      if (!cloudBySyncId.containsKey(syncId)) {
        // 本地有、云端无 → deleted
        changes.add(SyncChange(
          type: SyncChangeType.deleted,
          localTransaction: entry.value,
        ));
      }
    }

    // 按类型排序：新增 → 修改 → 删除
    changes.sort((a, b) => a.type.index.compareTo(b.type.index));

    logger.info('SyncDiff',
        '差异计算完成: 新增=${changes.where((c) => c.type == SyncChangeType.added).length}, '
        '修改=${changes.where((c) => c.type == SyncChangeType.modified).length}, '
        '删除=${changes.where((c) => c.type == SyncChangeType.deleted).length}');

    return SyncPreview(changes: changes);
  }

  /// 比较本地和云端交易的差异
  List<String> _compareTx(
    Transaction local,
    ImportTransaction cloud,
    Map<int, ({String name, String kind})> categoryMap,
    String ledgerBase,
  ) {
    final diffs = <String>[];

    if (local.type != cloud.type) {
      diffs.add('类型: ${local.type} → ${cloud.type}');
    }
    // 本地金额为整数分,云端为元(Decimal);统一换算成"分"再比较,精确无尾差。
    final localCents = local.amount;
    final cloudCents = yuanToCents(cloud.amount);
    if (localCents != cloudCents) {
      diffs.add('金额: ${localCents / 100} → ${cloud.amount}');
    }
    // 比较时间（精确到秒）
    final localTime = DateTime(
      local.happenedAt.year,
      local.happenedAt.month,
      local.happenedAt.day,
      local.happenedAt.hour,
      local.happenedAt.minute,
      local.happenedAt.second,
    );
    final cloudTime = DateTime(
      cloud.happenedAt.year,
      cloud.happenedAt.month,
      cloud.happenedAt.day,
      cloud.happenedAt.hour,
      cloud.happenedAt.minute,
      cloud.happenedAt.second,
    );
    if (localTime != cloudTime) {
      diffs.add('时间变更');
    }
    if ((local.note ?? '') != (cloud.note ?? '')) {
      diffs.add('备注: "${local.note ?? ''}" → "${cloud.note ?? ''}"');
    }

    // 分类：本地按 int id 反查名称，云端按 name/kind（云端只有 id 时跳过，
    // 兼容旧快照）。
    if (cloud.categoryName != null || cloud.categoryKind != null) {
      final localCat =
          local.categoryId != null ? categoryMap[local.categoryId] : null;
      final localName = localCat?.name ?? '';
      final localKind = localCat?.kind ?? '';
      final cloudName = cloud.categoryName ?? '';
      final cloudKind = cloud.categoryKind ?? '';
      if (localName != cloudName || localKind != cloudKind) {
        diffs.add(
            '分类: ${localName.isEmpty ? "未分类" : localName} → ${cloudName.isEmpty ? "未分类" : cloudName}');
      }
    }

    // 多币种：双方 NULL 都按账本位币兜底。
    final localCurrency = (local.currencyCode ?? ledgerBase).toUpperCase();
    final cloudCurrency = (cloud.currencyCode ?? ledgerBase).toUpperCase();
    if (localCurrency != cloudCurrency) {
      diffs.add('币种: $localCurrency → $cloudCurrency');
    }

    // 折算快照（云端有值才比较；缺键的旧快照不制造差异）。
    final cloudNativeCents = cloud.nativeAmount != null
        ? yuanToCents(cloud.nativeAmount!)
        : null;
    if (cloudNativeCents != null && local.nativeAmount != cloudNativeCents) {
      diffs.add(
          '折算金额: ${(local.nativeAmount ?? 0) / 100} → ${cloud.nativeAmount}');
    }

    // 统计排除标记（云端缺键按 false 兜底）。
    final cloudExclude = cloud.excludeFromStats ?? false;
    if (local.excludeFromStats != cloudExclude) {
      diffs.add('统计排除: ${local.excludeFromStats} → $cloudExclude');
    }

    // 支出人（云端缺键按创建人兜底，与导入路径一致）。
    final cloudPaidBy = cloud.paidByUserId ?? cloud.createdByUserId ?? '';
    if ((local.paidByUserId ?? '') != cloudPaidBy) {
      diffs.add('支出人变更');
    }

    // AA 分摊三字段。
    if (local.aaMode != cloud.aaMode) {
      diffs.add('分摊模式: ${local.aaMode} → ${cloud.aaMode}');
    }
    if ((local.aaParticipants ?? '') != (cloud.aaParticipants ?? '')) {
      diffs.add('分摊参与人变更');
    }
    if ((local.aaSplits ?? '') != (cloud.aaSplits ?? '')) {
      diffs.add('分摊金额变更');
    }

    return diffs;
  }

  /// 应用选中的变更
  ///
  /// [repo] - 数据仓库
  /// [ledgerId] - 账本 ID
  /// [selectedChanges] - 用户选中的变更列表
  /// [importData] - 原始导入数据（用于导入分类/账户/标签）
  Future<SyncApplyResult> applySyncChanges({
    required LocalRepository repo,
    required int ledgerId,
    required List<SyncChange> selectedChanges,
    required ImportData importData,
  }) async {
    if (selectedChanges.isEmpty) {
      return const SyncApplyResult();
    }

    final sourceCurrency = importData.currency?.trim().toUpperCase();
    final appliesCloudAmounts = selectedChanges.any(
      (change) => change.type != SyncChangeType.deleted,
    );
    final hasSourceNativeAmount = selectedChanges.any(
      (change) => change.cloudTransaction?.nativeAmount != null,
    );
    if (appliesCloudAmounts &&
        (sourceCurrency == null || sourceCurrency.isEmpty) &&
        hasSourceNativeAmount) {
      throw fcs.CloudSyncException(
        '云端账本缺少币种信息，无法安全应用折算金额，请使用全量恢复',
      );
    }
    if (appliesCloudAmounts &&
        sourceCurrency != null &&
        sourceCurrency.isNotEmpty) {
      final ledger = await repo.getLedgerById(ledgerId);
      if (ledger == null) {
        throw fcs.CloudSyncException('账本不存在: $ledgerId');
      }
      final targetCurrency = ledger.currency.trim().toUpperCase();
      if (sourceCurrency != targetCurrency) {
        // 选择性应用会直接信任源端 nativeAmount，两个账本本位币
        // 不同时无法安全合并；必须在导入分类等任何写入之前整体拒绝。
        throw fcs.CloudSyncException(
          '云端账本币种 $sourceCurrency 与当前账本币种 '
          '$targetCurrency 不一致，无法选择性应用，请使用全量恢复',
        );
      }
    }

    // 分类:复用 DataImportService(同一份 batch 优化只在一处维护)
    final categoryCache =
        await dataImportPort.importCategories(repo, importData.categories);

    int addedCount = 0;
    int modifiedCount = 0;
    int deletedCount = 0;

    // 按类型分桶 — added 走批量(WebDAV/Supabase 从远端拉账本场景一次可能上万
    // 条全 added,单条 for 循环要几十分钟;modified/deleted 数量通常小,保持
    // 单条 await)
    final addedChanges = <SyncChange>[];
    final modifiedChanges = <SyncChange>[];
    final deletedChanges = <SyncChange>[];
    for (final c in selectedChanges) {
      switch (c.type) {
        case SyncChangeType.added:
          addedChanges.add(c);
          break;
        case SyncChangeType.modified:
          modifiedChanges.add(c);
          break;
        case SyncChangeType.deleted:
          deletedChanges.add(c);
          break;
      }
    }

    // ============ added: 复用 DataImportService 的批量插入路径 ============
    // 把 SyncChange → ImportTransaction(cloudTransaction 本来就是 ImportTransaction
    // 类型),直接交给 DataImportService.importTransactions 走 batch:500 条 /
    // 批,一个 db.transaction 内 batch insert tx + local_changes,
    // 把 N 次单条 await(WebDAV 1 万条全 added 要几十分钟)折叠成 N/500 批。
    if (addedChanges.isNotEmpty) {
      final addedTxs = addedChanges
          .map((c) => c.cloudTransaction!)
          .toList(growable: false);
      final result = await dataImportPort.importTransactions(
        repo,
        ledgerId,
        addedTxs,
        categoryCache: categoryCache,
      );
      addedCount = result.inserted;
    }

    // ============ modified: 主表用批量 UPDATE ============
    if (modifiedChanges.isNotEmpty) {
      final updates = <TransactionUpdateBySyncIdData>[];
      for (final change in modifiedChanges) {
        final cloud = change.cloudTransaction!;
        final syncId = cloud.syncId!;
        final categoryId = _resolveCategoryId(cloud, categoryCache);
        updates.add(TransactionUpdateBySyncIdData(
          syncId: syncId,
          type: cloud.type,
          amount: yuanToCents(cloud.amount),
          categoryId: categoryId,
          happenedAt: cloud.happenedAt,
          note: cloud.note,
          // 全字段快照契约：币种/折算/统计标记/支出人/AA 与云端对齐。
          currencyCode: cloud.currencyCode,
          nativeAmount: cloud.nativeAmount != null
              ? yuanToCents(cloud.nativeAmount!)
              : null,
          excludeFromStats: cloud.excludeFromStats ?? false,
          paidByUserId: cloud.paidByUserId ?? cloud.createdByUserId ?? '',
          aaMode: cloud.aaMode,
          aaParticipants: cloud.aaParticipants,
          aaSplits: cloud.aaSplits,
          overwriteSnapshot: true,
        ));
      }
      try {
        final syncIdToTxId =
            await repo.updateTransactionsBatchBySyncId(updates);
        modifiedCount = syncIdToTxId.length;
        logger.info('SyncDiff',
            '批量更新: size=${updates.length} 成功=$modifiedCount');
      } catch (e, st) {
        logger.error('SyncDiff', '批量更新失败', e, st);
      }
    }

    // ============ deleted: 批量按 syncId 删除 ============
    // 有 syncId 的批量走单条 DELETE WHERE IN;没 syncId 的(老数据)兜底单条
    if (deletedChanges.isNotEmpty) {
      final withSyncIds = <String>[];
      final fallbackIds = <int>[];
      for (final change in deletedChanges) {
        final localTx = change.localTransaction!;
        if (localTx.syncId != null && localTx.syncId!.isNotEmpty) {
          withSyncIds.add(localTx.syncId!);
        } else {
          fallbackIds.add(localTx.id);
        }
      }
      if (withSyncIds.isNotEmpty) {
        try {
          final n =
              await repo.deleteTransactionsBatchBySyncIds(withSyncIds);
          deletedCount += n;
          logger.info('SyncDiff',
              '批量删除: syncId 路径 size=${withSyncIds.length} 实删=$n');
        } catch (e, st) {
          logger.error('SyncDiff', '批量删除失败', e, st);
        }
      }
      for (final id in fallbackIds) {
        try {
          await repo.deleteTransaction(id);
          deletedCount++;
        } catch (e, st) {
          logger.error('SyncDiff', '兜底单条删除失败 id=$id', e, st);
        }
      }
    }

    logger.info('SyncDiff',
        '变更已应用: 新增=$addedCount, 修改=$modifiedCount, 删除=$deletedCount');

    return SyncApplyResult(
      addedCount: addedCount,
      modifiedCount: modifiedCount,
      deletedCount: deletedCount,
    );
  }

  // --- 辅助方法 ---

  int? _resolveCategoryId(
      ImportTransaction tx, Map<String, int> categoryCache) {
    if (tx.categoryId != null) return tx.categoryId;
    if (tx.categoryName != null && tx.categoryKind != null) {
      return categoryCache['${tx.categoryKind}|${tx.categoryName}'];
    }
    return null;
  }

  // 分类的导入逻辑统一委托给 DataImportService.importCategories,
  // 避免在本文件维护第二份实现。
}
