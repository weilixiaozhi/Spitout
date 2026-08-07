import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../core/logging/logger_service.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';
import 'package:spitout/providers/core/refresh_ticks.dart';

// 账本列表 provider（统一本地列表）。
//
// 设计意图：从 sync_providers.dart 拆出。shared_ledger_providers 的
// 踢人/退出流程需要 invalidate localLedgersProvider，若本组留在
// sync_providers（SyncEvent 编排器），shared_ledger 就必须 import 编排器，
// 重新引入域 → 编排的反向边。本文件只依赖叶子模块（refresh_ticks /
// sync_state）与 database / statistics，不 import 任何
// 编排模块，保证 shared_ledger_providers 可以只依赖「叶子 + 本文件」。
//
// 消费方无需感知本文件：sync_providers.dart 对其做了 re-export，
// providers.dart barrel 的可见符号保持不变。

/// 当前正在上传的账本ID集合
final uploadingLedgerIdsProvider =
    NotifierProvider<SimpleStateNotifier<Set<int>>, Set<int>>(
  () => SimpleStateNotifier((ref) => {}),
);

/// 本地账本列表（快速，仅本地）
final localLedgersProvider =
    FutureProvider<List<LedgerDisplayItem>>((ref) async {
  // 监听刷新触发器（账本列表和统计信息）
  ref.watch(ledgerListRefreshProvider);
  // 监听统一数据变更信号，确保任意写库（自动记账/导入/同步）后刷新统计信息。
  ref.watch(dataChangeSignalProvider);

  try {
    final repo = ref.watch(repositoryProvider);

    final localLedgers = await repo.getAllLedgers();
    // 批量统计：单条聚合 SQL 一次查回全部账本，避免逐本 getLedgerStats 的
    // N+1 全量扫描（账本多 / 交易多时列表刷新成本线性放大）。
    final statsMap = await repo.getAllLedgerStats();

    final result = <LedgerDisplayItem>[];
    for (final ledger in localLedgers) {
      final stats = statsMap[ledger.id] ??
          (expenseTotal: 0, transactionCount: 0);

      result.add(LedgerDisplayItem.fromLocal(
        id: ledger.id,
        name: ledger.name,
        currency: ledger.currency,
        createdAt: ledger.createdAt,
        transactionCount: stats.transactionCount,
        expenseTotal: stats.expenseTotal,
        isShared: ledger.isShared,
        memberCount: ledger.memberCount,
        myRole: ledger.myRole,
        // 账本归属:列表页据此分「本地账本 / Spitout Cloud 账本」两个分区。
        storageMode: ledger.storageMode,
      ));
    }

    return result;
  } catch (e, stackTrace) {
    logger.error('LocalLedgers', '获取本地账本列表失败', e, stackTrace);
    return [];
  }
});
