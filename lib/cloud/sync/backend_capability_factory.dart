import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/data/db.dart';
import 'change_tracker.dart';
import 'snapshot_dirty_tracker.dart';

/// 后端能力装配结果：增量型与快照型追踪器互斥。
class BackendTrackers {
  final ChangeTracker? changeTracker;
  final SnapshotDirtyTracker? snapshotDirtyTracker;

  const BackendTrackers({
    this.changeTracker,
    this.snapshotDirtyTracker,
  });
}

/// 后端能力工厂：把「后端类型 → 同步信号实现」的策略集中到 cloud 层，
/// 装配点只做注入。
class BackendCapabilityFactory {
  const BackendCapabilityFactory();

  BackendTrackers createTrackers(
    SpitoutDatabase db,
    CloudServiceConfig config,
  ) {
    if (!config.valid) {
      return const BackendTrackers();
    }
    switch (config.type) {
      case CloudBackendType.spitoutCloud:
        return BackendTrackers(changeTracker: ChangeTracker(db));
      case CloudBackendType.webdav:
      case CloudBackendType.s3:
      case CloudBackendType.supabase:
        return BackendTrackers(
          snapshotDirtyTracker: SnapshotDirtyTracker(db),
        );
      case CloudBackendType.local:
        return const BackendTrackers();
    }
  }
}

/// 全局工厂实例。
final backendCapabilityFactory = BackendCapabilityFactory();
