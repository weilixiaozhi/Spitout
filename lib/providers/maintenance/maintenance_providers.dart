/// 孤儿数据维护工具的 Riverpod 集成。
///
/// 分两个 Provider:
/// - [orphanScannerProvider] / [orphanCleanerProvider]:单例服务,注入 db。
/// - [orphanScanReportProvider]:FutureProvider,UI 用 `ref.watch` 拿扫描结果;
///   `ref.invalidate(orphanScanReportProvider)` 重扫。
///
/// UI 在 cleaner 跑完后 invalidate 一次,重扫给新视图。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/maintenance/orphan_cleaner.dart';
import '../../services/maintenance/orphan_record.dart';
import '../../services/maintenance/orphan_scanner.dart';
import '../../services/maintenance/shared_ledger_category_repair.dart';
import '../../core/logging/logger_service.dart';
import 'package:spitout/providers/core/database_providers.dart';

final orphanScannerProvider = Provider<OrphanScanner>((ref) {
  final db = ref.watch(databaseProvider);
  return OrphanScanner(db: db);
});

final orphanCleanerProvider = Provider<OrphanCleaner>((ref) {
  final db = ref.watch(databaseProvider);
  return OrphanCleaner(db: db);
});

final sharedLedgerCategoryRepairProvider =
    Provider<SharedLedgerCategoryRepair>((ref) {
  final db = ref.watch(databaseProvider);
  return SharedLedgerCategoryRepair(db: db);
});

/// 启动期一次性历史脏数据修复。成功后写标志位，失败不写以便下次启动重试。
final sharedLedgerCategoryRepairRunProvider = FutureProvider<void>((ref) async {
  const key = 'shared_ledger_category_repair_v1_done';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(key) ?? false) return;
  final repair = ref.read(sharedLedgerCategoryRepairProvider);
  try {
    final result = await repair.repair();
    if (result.fixedTransactions > 0) {
      logger.info('SharedLedgerCategoryRepair',
          '已修复 ${result.fixedTransactions} 笔共享账本交易分类表示');
    }
    // 还有镜像未就绪的共享账本时不置完成标志，下次启动继续补跑
    if (result.skippedLedgers == 0) {
      await prefs.setBool(key, true);
    } else {
      logger.info('SharedLedgerCategoryRepair',
          '有 ${result.skippedLedgers} 个共享账本镜像未就绪，下次启动继续修复');
    }
  } catch (e, st) {
    logger.error('SharedLedgerCategoryRepair',
        '历史脏数据修复失败，将在下次启动重试', e, st);
  }
});

/// 一次扫描的全部结果。autoDispose:用户离开页面后下次进来重扫。
final orphanScanReportProvider =
    FutureProvider.autoDispose<OrphanScanReport>((ref) async {
  final scanner = ref.watch(orphanScannerProvider);
  return scanner.scanAll();
});
