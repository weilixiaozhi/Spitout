import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../cloud/sync/sync_engine.dart';
import '../../core/logging/logger_service.dart';
import 'package:spitout/providers/statistics/calendar_providers.dart';
import 'package:spitout/providers/statistics/statistics_providers.dart';
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
/// - `run` 系列：交易创建后使用，刷新统计 + 同步
/// - `sync` 系列：其他数据变更后使用（分类等），仅同步
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
  /// 注：统计页刷新由各调用方在 sync 之后自行 bump statsRefreshProvider；
  /// 这里统一补上日历刷新，避免「新增/删除/导入/清空」后日历不渲染。
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

  /// 交易后完整处理：刷新统计 + 日历，再走同步
  static Future<void> _run(_Read read, int ledgerId) async {
    read(statsRefreshProvider.notifier).tick();
    // 数据已变更：同时刷新日历（与统计页一致），覆盖新增/删除/导入/清空等场景
    read(calendarRefreshProvider.notifier).tick();
    await _doSync(read, ledgerId);
  }

  /// 仅同步：补日历刷新后走同步
  static Future<void> _sync(_Read read, int ledgerId) async {
    read(calendarRefreshProvider.notifier).tick();
    await _doSync(read, ledgerId);
  }

  /// 云端下载后：只刷新四个信号，不触发同步上传
  static void _runAfterDownload(_Read read) {
    read(statsRefreshProvider.notifier).tick();
    // 云端拉取的记录同样要刷新日历
    read(calendarRefreshProvider.notifier).tick();
    read(syncStatusRefreshProvider.notifier).tick();
    read(ledgerListRefreshProvider.notifier).tick();
    logger.info('PostProcessor', '云端下载后刷新完成');
  }

  /// 同步触发核心：标记本地变更 → bump 刷新信号 → 视后端类型后台同步。
  static Future<void> _doSync(_Read read, int ledgerId) async {
    final sync = read(syncServiceProvider);
    try {
      sync.markLocalChanged(ledgerId: ledgerId);
    } catch (_) {}

    read(syncStatusRefreshProvider.notifier).tick();
    read(ledgerListRefreshProvider.notifier).tick();

    // Spitout Cloud：始终自动双向同步
    if (sync is SyncEngine) {
      final refresh = read(syncStatusRefreshProvider.notifier);
      Future(() async {
        try {
          await sync.sync(ledgerId: ledgerId.toString());
          refresh.tick();
          logger.info(
              'PostProcessor', 'Spitout Cloud 自动同步完成', 'ledgerId=$ledgerId');
        } catch (e) {
          logger.error('PostProcessor', 'Spitout Cloud 自动同步失败', e);
        }
      });
      return;
    }

    // 其他 provider（webdav/s3/supabase 等快照型后端）：受 auto_sync 开关约束，
    // 开关关闭时仅完成 markLocalChanged + 刷新信号，不会真正上传快照。
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('auto_sync') ?? false) {
      final refresh = read(syncStatusRefreshProvider.notifier);
      Future(() async {
        try {
          await sync.uploadCurrentLedger(ledgerId: ledgerId);
          refresh.tick();
          logger.info('PostProcessor', '后台同步完成', 'ledgerId=$ledgerId');
        } catch (e) {
          logger.error('PostProcessor', '后台同步失败', e);
        }
      });
    }
  }
}
