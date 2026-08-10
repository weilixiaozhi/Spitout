import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/data/db.dart';
import 'change_tracker.dart';
import 'snapshot_dirty_tracker.dart';

/// 后端能力工厂：把「后端类型 → 同步信号实现」的策略集中到 cloud 层，
/// 装配点只做注入。
class BackendCapabilityFactory {
  const BackendCapabilityFactory();

  ({ChangeTracker? changeTracker, SnapshotDirtyTracker? snapshotDirtyTracker})
  createTrackers(
    SpitoutDatabase db,
    CloudServiceConfig config,
  ) {
    if (!config.valid) {
      return (changeTracker: null, snapshotDirtyTracker: null);
    }
    switch (config.type) {
      case CloudBackendType.spitoutCloud:
        return (changeTracker: ChangeTracker(db), snapshotDirtyTracker: null);
      case CloudBackendType.webdav:
      case CloudBackendType.s3:
      case CloudBackendType.supabase:
        return (
          changeTracker: null,
          snapshotDirtyTracker: SnapshotDirtyTracker(db),
        );
      case CloudBackendType.local:
        return (changeTracker: null, snapshotDirtyTracker: null);
    }
  }
}

/// 全局工厂实例。
final backendCapabilityFactory = BackendCapabilityFactory();
