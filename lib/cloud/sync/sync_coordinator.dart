import 'dart:async';

import 'package:spitout/data/db.dart' show LocalChange;
import 'package:spitout/data/repositories/support/sync_signal_ports.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'sync_engine.dart';

/// 反应式同步触发器:监听 `local_changes` 表的未推送行,debounce 后调
/// [SyncEngine.triggerAutoSync] 把变更推到云端。
///
/// 把触发逻辑放在数据层,**任何写入 local_changes 表的代码路径**
/// 都自动获得同步触发能力,UI 不需要再操心。Repository 层的 mutation
/// 只要正确写了 local_changes 行就万事大吉。
///
/// 双层 debounce 保护:
/// - 本类:250ms,合并 CSV 导入 / 批量删除 / migrate 等会高频写入
///   local_changes 的场景
/// - [SyncEngine._scheduleAutoSync]:2s,合并 WS 重连 / connectivity
///   恢复 / 反应式触发等多个上游事件
///
/// 仅在 Spitout Cloud (SyncEngine) 模式下启用。本地 only / 旧 provider
/// (S3 / WebDAV) 走的是 snapshot 同步,不读 local_changes 表,这里没意义。
///
/// ⚠️ 与 [SnapshotSyncCoordinator] 的关系(防御性说明,请勿误删):
/// WebDAV / S3 协议不支持行级查询,故必须采用快照式同步。本文件与
/// [SnapshotSyncCoordinator] 并非重复实现,而是分别服务于「增量回放」
/// (Spitout Cloud 行级同步)与「整本快照重传」(WebDAV / S3)两种范式。
/// 两者不可合并或删除——后续维护者若误判为冗余而删除其中之一,将导致
/// 对应后端的同步能力整体失效。
class SyncCoordinator {
  final LocalChangePort localChanges;
  final SyncEngine engine;

  StreamSubscription<List<LocalChange>>? _subscription;
  Timer? _debounce;

  SyncCoordinator({required this.localChanges, required this.engine});

  /// 启动监听。重复调用安全:重新建立订阅前会取消旧的。
  void start() {
    _subscription?.cancel();
    _subscription = localChanges.watchUnpushed().listen(
          _onUnpushedChanged,
          onError: (Object e, StackTrace st) {
            logger.warning('SyncCoordinator', 'local_changes watch 失败: $e', st);
          },
        );
    logger.info('SyncCoordinator', '已启动: 监听 local_changes 未推送变更');
  }

  void _onUnpushedChanged(List<LocalChange> rows) {
    // 没有未推送变更:大概率是 markPushed 之后的 echo。
    // 除了跳过之外,还要取消仍在防抖窗口内挂起的定时器——否则"写入后立刻被
    // 其它同步路径推送完毕"的场景会对已全部推送的变更再做一次冗余自动同步。
    if (rows.isEmpty) {
      _debounce?.cancel();
      _debounce = null;
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      logger.info('SyncCoordinator',
          '检测到 ${rows.length} 条未推送变更,触发自动同步');
      engine.triggerAutoSync(reason: 'local_change_detected');
    });
  }

  /// 释放资源。配合 `ref.onDispose` 调用。
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _subscription?.cancel();
    _subscription = null;
  }
}
