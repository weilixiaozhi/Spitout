library;

import 'dart:async';

import 'package:spitout/data/db.dart';

/// 本地增量同步信号端口（data 层抽象）。
///
/// cloud 层的同步协调器只依赖本端口监听/消费 `local_changes`，
/// 不直接触碰 Drift schema；实现由 cloud/sync 的 [ChangeTracker] 提供，
/// 在 Provider 装配点注入。
abstract class LocalChangePort {
  /// 监听未推送变更。
  Stream<List<LocalChange>> watchUnpushed();
}

/// 快照脏信号端口（data 层抽象）。
///
/// cloud 层的快照同步协调器只依赖本端口监听/消费
/// `snapshot_dirty_ledgers`，不直接触碰 Drift schema；实现由
/// cloud/sync 的 [SnapshotDirtyTracker] 提供，在 Provider 装配点注入。
abstract class SnapshotDirtyPort {
  /// 监听脏账本信号。
  Stream<List<SnapshotDirtyLedger>> watchDirty();

  /// 读取当前全部脏账本。
  Future<List<SnapshotDirtyLedger>> getDirtyLedgers();

  /// 删除指定账本的脏信号（上传成功后消费）。
  Future<void> deleteDirtyLedger(int ledgerId);
}
