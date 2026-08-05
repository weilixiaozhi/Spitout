/// 云同步服务接口（状态模型定义于 data/models/sync_models.dart）
library;

import '../../core/logging/logger_service.dart';
import '../../data/repositories/ledger_repository.dart';
import 'sync_diff_service.dart' show SyncChange, SyncPreview, SyncApplyResult;

// 状态模型定义于 data/models/sync_models.dart。
// 注意:import 用于本库内使用(接口签名引用 PullOutcome/SyncStatus/SyncDiff);
// export 用于对外 re-export —— sync_engine.dart 以 `app.SyncStatus` 前缀
// 方式引用本库符号,Dart 的 `as app` 只能看到本库定义或 re-export 的名字,
// import 进来的符号对 `app.` 前缀不可见,所以二者缺一不可。
import '../../data/models.dart'
    show PullOutcome, SyncDiff, SyncStatus, ImportData;
export '../../data/models.dart'
    show PullOutcome, SyncDiff, SyncStatus, ImportData;
export 'sync_diff_service.dart' show SyncChange, SyncPreview, SyncApplyResult;

// ---- 同步服务接口 ----

abstract class SyncService {
  /// 是否支持「下载前 diff 预览」。
  ///
  /// 快照型后端（TransactionsSyncManager）支持:先下载云端数据并计算
  /// 增删改预览,由用户勾选后再落库;纯本地实现不支持。UI 只按本能力
  /// 分支,不依赖具体实现类。
  bool get supportsDiffPreview;

  /// 下载云端数据并计算 diff 预览;仅 [supportsDiffPreview] 为 true 时可用。
  ///
  /// 返回 null 表示云端无备份;preview 为 null 表示旧格式无法计算 diff,
  /// 调用方应退回全量替换流程。
  Future<({SyncPreview? preview, ImportData importData, int version})?>
      downloadAndPreview({required int ledgerId});

  /// 应用预览中选中的变更;仅 [supportsDiffPreview] 为 true 时可用。
  Future<SyncApplyResult> applyPreviewChanges({
    required int ledgerId,
    required List<SyncChange> selectedChanges,
    required ImportData importData,
  });

  Future<void> uploadCurrentLedger({required int ledgerId});

  /// 下载并导入到当前账本
  /// 返回 (inserted, deletedDup) 二元组：
  /// - inserted: 新增条数
  /// - deletedDup: 下载后去重删除的重复交易条数
  Future<({int inserted, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId});

  /// 仅执行增量拉取，返回本次拉取到的变更条数。
  ///
  /// 供下拉刷新等高频入口使用：与 [downloadAndRestoreToCurrentLedger] 的区别是
  /// **绝不触发全量恢复**（全量恢复应只保留给云同步页/账本页明确的"从云端恢复"
  /// 操作）。增量型后端（SyncEngine）直接走增量 pull；快照型后端（无增量能力）
  /// 可退化为幂等的快照下载（导入侧已按 syncId 去重，不会产生重复行）。
  Future<int> pullIncremental({required int ledgerId});

  /// 增量拉取 + 缺失自愈，返回结构化的 [PullOutcome]。
  ///
  /// 供"用户主动手势"类低频入口（首页下拉刷新）使用，调用方明确期待数据
  /// 落地。与 [pullIncremental] 的区别仅在于：增量返回 0 时多做一次
  /// **受闸门 / 节流 / 熔断保护**的自愈检查——本地游标越过云端历史变更
  /// （数据丢失但游标未回退）时能把缺失数据补回来。
  ///
  /// 各后端语义：
  /// - 增量型（SyncEngine）：pull + 自愈检查；自愈内部幂等且节流，
  ///   健康设备至多每 5 分钟一次健康验证请求，不破坏轻量原则。
  /// - 快照型（无增量能力）：现有 [pullIncremental] 已退化为幂等快照下载，
  ///   天然具备自愈能力，直接委托。
  Future<PullOutcome> pullIncrementalWithHeal({required int ledgerId});

  Future<SyncStatus> getStatus({required int ledgerId});

  /// 主动刷新云端指纹：强制下载云端对象并计算指纹，返回 (fingerprint, count, exportedAt)。
  /// 实现可在内部根据对比结果适度更新缓存，便于 UI 立即反映状态。
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId});

  /// 当本地数据发生变更（增删改）时调用，以便使缓存状态失效
  void markLocalChanged({required int ledgerId});

  /// 删除云端备份（若存在）。应忽略 404。
  Future<void> deleteRemoteBackup({required int ledgerId});

  /// 全局删除账本：远端删 → 本地删 → 清 local_changes，三步收敛在单个方法内。
  ///
  /// 为什么收敛成一个方法:删除的三步存在严格顺序依赖 ——
  /// 1. syncId 必须在本地行删除**之前**回查,否则无法定位远端记录;
  /// 2. 本地删除会向 local_changes 登记 delete change,必须随后抹掉,
  ///    否则同步协调器会向已删除的远端账本推 change / 触发快照复活。
  /// 若拆散到 UI 层组合调用,任何一步顺序错乱都会产生幽灵账本 bug。
  ///
  /// 实现要求:**不得**触发 PostProcessor.sync / engine.sync。
  Future<void> deleteLedgerGlobally(int ledgerId);

  /// 把本地账本搬到云端:先全量推送,确认云端存在后才翻 mode(失败抛异常、不改 mode)。
  /// 共享账本不支持,应使用 [copyToLocal]。
  Future<void> moveToCloud(int ledgerId);

  /// 把云端账本搬到本地:删云端副本 → 翻 local → 置空 syncId(彻底断联)。
  /// 共享账本不支持,应使用 [copyToLocal]。
  Future<void> moveToLocal(int ledgerId);

  /// 复制云端/共享账本到本地:保留云端副本不动,新建本地账本并拷贝全量交易与编辑历史。
  /// 返回新建本地账本 id。本地账本禁止复制。
  Future<int> copyToLocal(int sourceLedgerId);

  /// 清除指定账本的状态缓存，下次 getStatus 会重新从云端获取
  void clearStatusCache({int? ledgerId});
}

// ---- 本地存储实现（无云同步） ----

class LocalOnlySyncService implements SyncService {
  /// 纯本地模式也要支持「删除账本」,因此注入账本仓库的**惰性解析器**。
  ///
  /// 为什么是解析器而不是实例:syncServiceProvider 在应用启动/页面构建时
  /// 就会被 watch,若此处直接持有仓库实例,等于强迫每次构建都实例化数据库
  /// 仓库(widget 测试中还会触发 LoggerService 的异步定时器导致 pending
  /// timer 断言失败)。惰性解析把仓库创建推迟到真正执行删除的那一刻。
  /// 可空:大量测试直接 `LocalOnlySyncService()` 构造且不触达删除路径,
  /// 保持无参构造兼容;真正走删除时解析器为空则抛错提示配置缺失。
  // 参数保持公共名:私有字段不能作为跨库命名参数调用(如 sync_providers.dart 注入处)
  LocalOnlySyncService({LedgerRepository Function()? repoResolver})
      : _repoResolver = repoResolver; // ignore: prefer_initializing_formals

  final LedgerRepository Function()? _repoResolver;

  @override
  bool get supportsDiffPreview => false;

  @override
  Future<({SyncPreview? preview, ImportData importData, int version})?>
      downloadAndPreview({required int ledgerId}) {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<SyncApplyResult> applyPreviewChanges({
    required int ledgerId,
    required List<SyncChange> selectedChanges,
    required ImportData importData,
  }) {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<({int inserted, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<int> pullIncremental({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<PullOutcome> pullIncrementalWithHeal({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    return const SyncStatus(
      diff: SyncDiff.notConfigured,
      localCount: 0,
      localFingerprint: '',
      message: '__SYNC_NOT_CONFIGURED__', // 特殊标记，在UI层处理本地化
    );
  }

  @override
  void markLocalChanged({required int ledgerId}) {}

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<void> deleteRemoteBackup({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<void> deleteLedgerGlobally(int ledgerId) async {
    // 纯本地模式没有远端,也不产生 local_changes(无 ChangeTracker 注入),
    // 因此只需删本地行,无需清 change。
    final repo = _repoResolver?.call();
    if (repo == null) {
      throw UnsupportedError('LocalOnlySyncService 未注入 LedgerRepository');
    }
    try {
      await repo.deleteLedger(ledgerId);
      logger.info('LocalOnlySync', 'deleteLedgerGlobally($ledgerId) 本地删除完成');
    } catch (e, st) {
      logger.error('LocalOnlySync', '删除账本失败 ledgerId=$ledgerId', e, st);
      rethrow;
    }
  }

  @override
  Future<void> moveToCloud(int ledgerId) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<void> moveToLocal(int ledgerId) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<int> copyToLocal(int sourceLedgerId) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  void clearStatusCache({int? ledgerId}) {}
}
