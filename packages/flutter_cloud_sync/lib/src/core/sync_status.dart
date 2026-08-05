import 'package:meta/meta.dart';

/// 同步状态枚举。
enum SyncState {
  /// 云服务未配置。
  notConfigured,

  /// 用户未登录。
  notAuthenticated,

  /// 仅存在本地数据，无云端备份。
  localOnly,

  /// 本地与云端数据一致。
  synced,

  /// 本地与云端数据不一致。
  outOfSync,

  /// 上传进行中。
  uploading,

  /// 下载进行中。
  downloading,

  /// 发生错误。
  error,

  /// 无法判断（例如无本地数据可比对）。
  unknown,
}

/// 数据不一致时的同步方向。
enum SyncDirection {
  /// 本地数据较新。
  localNewer,

  /// 云端数据较新。
  cloudNewer,

  /// 无法判断哪边较新。
  unknown,
}

/// 同步状态信息。
///
/// 不可变对象；`==` 比较全部字段，保证上层（Riverpod / StateNotifier）用
/// 相等性判断状态变化时，计数、方向、进度等任一字段变化都能触发刷新。
@immutable
class SyncStatus {
  /// 当前同步状态。
  final SyncState state;

  /// 本地数据指纹（可选）。
  final String? localFingerprint;

  /// 云端数据指纹（可选）。
  final String? cloudFingerprint;

  /// 最近一次同步时间（可选）。
  final DateTime? lastSyncedAt;

  /// 本地数据更新时间（可选）。
  final DateTime? localUpdatedAt;

  /// 云端数据更新时间（可选）。
  final DateTime? cloudUpdatedAt;

  /// 不一致时的同步方向（可选）。
  final SyncDirection? direction;

  /// 本地数据条数（可选）。
  final int? localCount;

  /// 云端数据条数（可选）。
  final int? cloudCount;

  /// 状态文案或错误描述（可选）。
  final String? message;

  /// 进度（0.0 - 1.0，可选）。
  final double? progress;

  const SyncStatus({
    required this.state,
    this.localFingerprint,
    this.cloudFingerprint,
    this.lastSyncedAt,
    this.localUpdatedAt,
    this.cloudUpdatedAt,
    this.direction,
    this.localCount,
    this.cloudCount,
    this.message,
    this.progress,
  });

  /// 是否已同步。
  bool get isSynced => state == SyncState.synced;

  /// 是否需要同步（不一致或仅本地）。
  bool get needsSync =>
      state == SyncState.outOfSync || state == SyncState.localOnly;

  /// 是否具备执行同步的条件。
  bool get canSync =>
      state != SyncState.notConfigured &&
      state != SyncState.notAuthenticated &&
      state != SyncState.uploading &&
      state != SyncState.downloading;

  /// 是否有操作进行中。
  bool get isLoading =>
      state == SyncState.uploading || state == SyncState.downloading;

  /// 本地数据是否较新。
  bool get isLocalNewer => direction == SyncDirection.localNewer;

  /// 云端数据是否较新。
  bool get isCloudNewer => direction == SyncDirection.cloudNewer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          localFingerprint == other.localFingerprint &&
          cloudFingerprint == other.cloudFingerprint &&
          lastSyncedAt == other.lastSyncedAt &&
          localUpdatedAt == other.localUpdatedAt &&
          cloudUpdatedAt == other.cloudUpdatedAt &&
          direction == other.direction &&
          localCount == other.localCount &&
          cloudCount == other.cloudCount &&
          message == other.message &&
          progress == other.progress;

  @override
  int get hashCode => Object.hash(
        state,
        localFingerprint,
        cloudFingerprint,
        lastSyncedAt,
        localUpdatedAt,
        cloudUpdatedAt,
        direction,
        localCount,
        cloudCount,
        message,
        progress,
      );

  @override
  String toString() => 'SyncStatus(state: $state, message: $message)';

  /// 创建副本并修改指定字段。
  SyncStatus copyWith({
    SyncState? state,
    String? localFingerprint,
    String? cloudFingerprint,
    DateTime? lastSyncedAt,
    DateTime? localUpdatedAt,
    DateTime? cloudUpdatedAt,
    SyncDirection? direction,
    int? localCount,
    int? cloudCount,
    String? message,
    double? progress,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      localFingerprint: localFingerprint ?? this.localFingerprint,
      cloudFingerprint: cloudFingerprint ?? this.cloudFingerprint,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      cloudUpdatedAt: cloudUpdatedAt ?? this.cloudUpdatedAt,
      direction: direction ?? this.direction,
      localCount: localCount ?? this.localCount,
      cloudCount: cloudCount ?? this.cloudCount,
      message: message ?? this.message,
      progress: progress ?? this.progress,
    );
  }
}
