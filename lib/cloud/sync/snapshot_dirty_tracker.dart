import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../../data/repositories/support/snapshot_dirty_marker.dart';
import '../../core/logging/logger_service.dart';

/// 快照型后端脏账本标记器实现。
///
/// 实现 data 层 [SnapshotDirtyMarker] 端口：把"账本脏了需要重传快照"的
/// 信号写入 `snapshot_dirty_ledgers` 表，供 [SnapshotSyncCoordinator] 监听
/// 并响应式触发上传（规则4：同步由数据变更驱动）。
///
/// 与 [ChangeTracker] 的区别：
/// - [ChangeTracker] 写 `local_changes`（实体粒度，需 entitySyncId 非空，
///   供 SyncEngine 增量推送）；
/// - 本类写 `snapshot_dirty_ledgers`（账本粒度，只需 ledgerId，供快照后端
///   整本重传）。
///
/// 仅在快照型后端（webdav/s3/supabase）激活时由 database_providers 注入。
class SnapshotDirtyTracker implements SnapshotDirtyMarker {
  final SpitoutDatabase db;

  SnapshotDirtyTracker(this.db);

  /// 标记账本为脏（INSERT OR IGNORE 语义）。
  ///
  /// 为什么用 insertOrIgnore 而非 insertOnConflictUpdate：
  /// 重复标记同一账本时保留**首次** dirtyAt，便于诊断"这本账本脏了多久"。
  /// "脏"是布尔语义（存在即需要重传），不需要更新时间戳。
  @override
  Future<void> markLedgerDirty(int ledgerId) async {
    await db.into(db.snapshotDirtyLedgers).insert(
          SnapshotDirtyLedgersCompanion.insert(
              ledgerId: d.Value(ledgerId)),
          mode: d.InsertMode.insertOrIgnore,
        );
    logger.debug('SnapshotDirtyTracker', 'markLedgerDirty($ledgerId)');
  }
}
