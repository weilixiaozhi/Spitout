import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db.dart';
import '../../core/logging/logger_service.dart';
import 'sync_service.dart';

/// 快照型后端(webdav/s3/supabase)的反应式同步触发器。
///
/// 镜像 [SyncCoordinator] 的设计,但面向快照同步范式:
/// - [SyncCoordinator] 监听 `local_changes`(实体级增量),调 SyncEngine 推送;
/// - 本类监听 `snapshot_dirty_ledgers`(账本级脏信号),调
///   [SyncService.uploadCurrentLedger] 上传整本快照,成功后 DELETE 信号行
///   (消费完成)。
///
/// 为什么独立而非扩展 [SyncCoordinator]:
/// 两者信号表、上传语义、消费方式完全不同(增量回放 vs 整本重传),混在一起
/// 会让单一类承担两种范式分支,违反单一职责且增加测试复杂度。
///
/// ⚠️ 与 [SyncCoordinator] 的关系(防御性说明,请勿误删):
/// WebDAV / S3 协议不支持行级查询,故必须采用快照式同步。本文件与
/// [SyncCoordinator] 并非重复实现,而是分别服务于「整本快照重传」
/// (WebDAV / S3)与「增量回放」(Spitout Cloud 行级同步)两种范式。
/// 两者不可合并或删除——后续维护者若误判为冗余而删除其中之一,将导致
/// 对应后端的同步能力整体失效。
///
/// 触发链(规则4:同步由数据变更驱动,UI 不显式调 sync):
///   createLedger 写 snapshot_dirty_ledgers → 本类 watch 命中 →
///   debounce → auto_sync 闸门 → uploadCurrentLedger → 成功 DELETE。
///
/// auto_sync 闸门:关闭时不上传、不清信号(保留 dirty 等下次开启重试);
/// 开启时由 syncServiceProvider 监听 autoSyncValueProvider 调 [scanNow]
/// 主动补扫残留信号。
class SnapshotSyncCoordinator {
  final SpitoutDatabase db;
  final SyncService syncService;

  /// auto_sync 开关读取函数。
  ///
  /// 默认读 SharedPreferences(生产接线不传此参数即走默认);测试可注入
  /// 受控实现,避免 SharedPreferences 静态单例跨测试缓存导致中途切换不生效。
  final Future<bool> Function() _autoSyncEnabled;

  StreamSubscription<List<SnapshotDirtyLedger>>? _subscription;
  Timer? _debounce;

  /// 防重入锁:uploadCurrentLedger 是异步串行操作,并发触发会重复上传整本,
  /// 不仅浪费带宽还可能产生写冲突。
  bool _uploading = false;

  SnapshotSyncCoordinator({
    required this.db,
    required this.syncService,
    Future<bool> Function()? autoSyncEnabled,
  }) : _autoSyncEnabled = autoSyncEnabled ?? _readAutoSyncFromPrefs;

  /// 默认 auto_sync 读取:从 SharedPreferences 读 'auto_sync' 键。
  static Future<bool> _readAutoSyncFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_sync') ?? false;
  }

  /// 启动监听。重复调用安全:重新建立订阅前会取消旧的。
  ///
  /// 启动即扫描:处理 app 重启后残留的 dirty 行(上次退出时 auto_sync 关闭
  /// 或上传未完成留下的信号),确保不会"建了账本但因 app 重启漏传首快照"。
  void start() {
    _subscription?.cancel();
    _subscription = db.select(db.snapshotDirtyLedgers).watch().listen(
          _onDirtyChanged,
          onError: (Object e, StackTrace st) {
            logger.warning(
                'SnapshotSyncCoordinator', 'snapshot_dirty_ledgers watch 失败: $e', st);
          },
        );
    // 不等 watch 首帧,主动补一次处理残留 dirty。
    _scanNow();
    logger.info('SnapshotSyncCoordinator', '已启动: 监听 snapshot_dirty_ledgers');
  }

  void _onDirtyChanged(List<SnapshotDirtyLedger> rows) {
    // 没有脏账本:可能是上传成功 DELETE 后的 echo,跳过即可。
    if (rows.isEmpty) return;
    _scheduleUpload();
  }

  void _scheduleUpload() {
    _debounce?.cancel();
    // 500ms debounce:合并"新建账本 + 紧接的设置月起始日"等高频同事务写入,
    // 避免对同一本账本连续触发多次整本上传。
    _debounce = Timer(const Duration(milliseconds: 500), _uploadDirtyLedgers);
  }

  /// auto_sync 开关刚被打开时由 syncServiceProvider 主动调用的补扫入口。
  ///
  /// 场景:用户关闭 auto_sync 期间建了账本(脏信号已写入但未上传),此时
  /// 开启 auto_sync,需要主动扫一次把残留信号消费掉——watch 不会因开关
  /// 变化而重发,只能靠外部触发。
  Future<void> scanNow() => _scanNow();

  Future<void> _scanNow() async {
    final rows = await db.select(db.snapshotDirtyLedgers).get();
    if (rows.isNotEmpty) _scheduleUpload();
  }

  /// 消费脏信号:逐本上传快照,成功后 DELETE 对应行。
  ///
  /// 单本失败不阻断其它账本:失败的行保留信号,下一次 watch 命中或 [scanNow]
  /// 时重试;成功的行立即 DELETE 防止重复上传。
  Future<void> _uploadDirtyLedgers() async {
    if (_uploading) return; // 防重入
    _uploading = true;
    try {
      // auto_sync 闸门:关闭时不上传、不清信号。保留 dirty 行,等用户
      // 开启 auto_sync 时由 syncServiceProvider 调 scanNow 主动补扫。
      if (!await _autoSyncEnabled()) {
        logger.info('SnapshotSyncCoordinator', 'auto_sync 关闭, 保留 dirty 信号等待开启');
        return;
      }

      final rows = await db.select(db.snapshotDirtyLedgers).get();
      if (rows.isEmpty) return;

      for (final row in rows) {
        try {
          await syncService.uploadCurrentLedger(ledgerId: row.ledgerId);
          // 上传成功 → DELETE 信号行(消费完成)。
          await (db.delete(db.snapshotDirtyLedgers)
                ..where((t) => t.ledgerId.equals(row.ledgerId)))
              .go();
          logger.info('SnapshotSyncCoordinator',
              '账本 ${row.ledgerId} 首快照上传完成, 已清除脏信号');
        } catch (e, st) {
          // 单本失败不影响其它账本:继续处理剩余 dirty 行,失败的保留信号。
          logger.error('SnapshotSyncCoordinator',
              '账本 ${row.ledgerId} 首快照上传失败, 保留脏信号待重试', e, st);
        }
      }
    } catch (e, st) {
      logger.error('SnapshotSyncCoordinator', '上传脏账本流程异常', e, st);
    } finally {
      _uploading = false;
    }
  }

  /// 释放资源。配合 `ref.onDispose` 调用。
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _subscription?.cancel();
    _subscription = null;
  }
}
