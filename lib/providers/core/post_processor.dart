import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/sync/sync_providers.dart';

/// 统一的 provider 读取函数签名。
///
/// 三种载体的 `read` 方法签名完全一致（`T read<T>(ProviderListenable<T>)`），
/// 直接以 read 的 tear-off 作为参数即可让三套入口共享同一份实现。
typedef _Read = T Function<T>(ProviderListenable<T> provider);

/// 数据变更后的统一后处理服务
///
/// 职责：读取/刷新各 provider 并编排同步触发，属 provider 层编排逻辑；
/// services 层只保留不感知 Riverpod 的纯服务。
///
/// 两类方法：
/// - `run` 系列：交易创建后使用，编排同步
/// - `sync` 系列：其他数据变更后使用（分类等），仅同步
///
/// 所有汇总/统计的刷新已由统一数据变更信号（dataChangeSignalProvider）自动
/// 驱动——任何业务表写入都会触发首页/统计/日历/分类/成员/AA 重算，本服务不再
/// 负责 bump 数据刷新 tick，只处理同步状态缓存与 UI 状态信号。
///
/// 每类各有 3 个入口（WidgetRef / ProviderContainer / Ref），
/// 仅载体不同，内部全部收敛到同一份实现。
class PostProcessor {
  // ============ 交易后完整处理 ============

  /// UI 层使用（WidgetRef）
  static Future<void> run(
    WidgetRef ref, {
    required int ledgerId,
  }) =>
      _run(ref.read, ledgerId);

  /// 后台服务使用（ProviderContainer）
  static Future<void> runC(
    ProviderContainer c, {
    required int ledgerId,
  }) =>
      _run(c.read, ledgerId);

  /// Provider 内部使用（Ref）
  static Future<void> runR(
    Ref ref, {
    required int ledgerId,
  }) =>
      _run(ref.read, ledgerId);

  // ============ 仅同步 ============

  /// UI 层使用（WidgetRef）
  static Future<void> sync(WidgetRef ref, {required int ledgerId}) =>
      _sync(ref.read, ledgerId);

  /// 后台服务使用（ProviderContainer）
  static Future<void> syncC(ProviderContainer c, {required int ledgerId}) =>
      _sync(c.read, ledgerId);

  /// Provider 内部使用（Ref）
  static Future<void> syncR(Ref ref, {required int ledgerId}) =>
      _sync(ref.read, ledgerId);

  // ============ 云端下载后处理（仅刷新，不触发同步） ============

  /// 云端下载后的处理：刷新统计和UI状态，但不触发同步上传
  /// UI 层使用（WidgetRef）
  static void runAfterDownload(WidgetRef ref) => _runAfterDownload(ref.read);

  /// 云端下载后的处理：刷新统计和UI状态，但不触发同步上传
  /// 后台服务使用（ProviderContainer）
  static void runAfterDownloadC(ProviderContainer c) =>
      _runAfterDownload(c.read);

  // ============ 内部统一实现 ============

  /// 交易后完整处理：再走同步（汇总刷新由数据变更信号自动完成）
  static Future<void> _run(_Read read, int ledgerId) async {
    await _doSync(read, ledgerId);
  }

  /// 仅同步
  static Future<void> _sync(_Read read, int ledgerId) async {
    await _doSync(read, ledgerId);
  }

  /// 云端下载后：只刷新同步状态/账本列表信号，不触发同步上传
  /// （汇总刷新由数据变更信号自动完成）
  static void _runAfterDownload(_Read read) {
    read(syncStatusRefreshProvider.notifier).tick();
    read(ledgerListRefreshProvider.notifier).tick();
    logger.info('PostProcessor', '云端下载后刷新完成');
  }

  /// 同步触发核心：标记本地变更 → bump 刷新信号。
  ///
  /// 自动同步由数据变更驱动，[SyncCoordinator] /
  /// [SnapshotSyncCoordinator] 已在 syncServiceProvider 装配，分别监听
  /// local_changes / snapshot_dirty_ledgers 信号表（250/500ms 防抖后触发）。
  /// 这里只负责清空同步状态缓存并刷新 UI 信号，绝不直接调 sync.sync() /
  /// uploadCurrentLedger()——否则会与两个 Coordinator 形成双触发，每次本地
  /// 写操作都会产生两轮重复网络请求。
  static Future<void> _doSync(_Read read, int ledgerId) async {
    final sync = read(syncServiceProvider);
    try {
      sync.markLocalChanged(ledgerId: ledgerId);
    } catch (e, st) {
      // markLocalChanged 只清状态缓存，失败不应阻断 UI 刷新，但必须留痕，
      // 否则后续同步状态显示会失真且无从排查。
      logger.warning(
        'PostProcessor',
        'markLocalChanged 失败 ledgerId=$ledgerId',
        '$e\n$st',
      );
    }

    read(syncStatusRefreshProvider.notifier).tick();
    read(ledgerListRefreshProvider.notifier).tick();
  }
}
