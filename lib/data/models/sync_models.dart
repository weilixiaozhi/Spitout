/// 云同步相关纯数据模型。
///
/// 设计意图：
/// UI 层（pages/widgets）从本文件（或经 data/models.dart barrel）获取
/// 云同步的纯数据类型，不直连 `cloud/sync/sync_service.dart` 与
/// `cloud/sync/sync_engine.dart`。这些类型不依赖任何引擎实现（不持有
/// provider / db 引用），属于纯数据结构——依赖方向保持
/// `pages/widgets → providers → services(cloud/sync) → data` 单向流动。
///
/// 注意：本文件**不包含** SyncService 接口与 SyncEngine 实现（它们留在
/// cloud 层），只包含跨层共享的数据模型。cloud 层反向 import 本文件
/// （services → data）是规则允许的方向。
library;

/// 同步拉取结果（`SyncService.pullIncrementalWithHeal` 的结构化返回）。
///
/// UI 据此区分四种结果并选择文案：
/// - 增量拉到数据（incremental > 0）
/// - 自愈补回数据（didHeal == true，healed > 0）
/// - 无差异（全部 0 / false）→ "已同步"
/// - 有差异但未能恢复（gapRemaining / circuitBroken）→ 引导手动"从云端恢复"
class PullOutcome {
  const PullOutcome({
    required this.incremental,
    this.healed = 0,
    this.didHeal = false,
    this.gapRemaining = false,
    this.circuitBroken = false,
  });

  /// 增量 pull 拉到的变更条数。
  final int incremental;

  /// 自愈补回的变更条数（重放 applied + 快照 inserted）。
  final int healed;

  /// 是否实际执行过自愈且补到了数据。
  final bool didHeal;

  /// 自愈执行后"云端多、本地缺"的差异仍未消除。
  final bool gapRemaining;

  /// 自愈已熔断（连续恢复失败），需用户手动"从云端恢复"。
  final bool circuitBroken;

  /// 本次总共落地的变更条数（增量 + 自愈）。
  int get total => incremental + healed;
}

/// 同步差异枚举，供 UI 分状态渲染。
///
/// 9 种取值覆盖：未登录 / 未配置 / 纯本地不上云 / 无远端 / 一致 / 本地新 /
/// 云端新 / 双向差异 / 错误。
enum SyncDiff {
  notConfigured,
  notLoggedIn,
  localOnly,
  noRemote,
  inSync,
  localNewer,
  cloudNewer,
  different,
  error,
}

/// 单账本同步状态（`SyncService.getStatus` 的返回）。
///
/// 与 `flutter_cloud_sync` 包同名 `SyncStatus` 无任何关系；同时 import 两个
/// 来源的文件须用 `hide SyncStatus` 规避同名冲突（见 cloud_sync_section.dart）。
class SyncStatus {
  final SyncDiff diff;
  final int localCount;
  final int? cloudCount;
  final String localFingerprint;
  final String? cloudFingerprint;
  final DateTime? cloudExportedAt;
  final String? message; // 错误或说明

  const SyncStatus({
    required this.diff,
    required this.localCount,
    required this.localFingerprint,
    this.cloudCount,
    this.cloudFingerprint,
    this.cloudExportedAt,
    this.message,
  });
}

/// `SyncEngine.syncAccount()` 的账户级汇总结果。
///
/// 设计意图：供启动日志与测试断言使用，UI 不直接展示——
/// 云同步页展示的是对账面板（checkAccountHealth），同步按钮只转圈不看数字。
///
/// 字段口径：
/// - [pushed]：推送到远端的变更数（Phase1 user-global + 各账本 push/fullPush）；
/// - [pulled]：从远端拉取应用的变更数（Phase1 用户级 + 各账本 pull）；
/// - [skipped]：fast-skip（无待推 + 已绑定）跳过的账本数；
/// - [elapsedMs]：整轮同步耗时。
class SyncAccountResult {
  const SyncAccountResult({
    required this.pushed,
    required this.pulled,
    required this.skipped,
    required this.elapsedMs,
  });
  final int pushed;
  final int pulled;
  final int skipped;
  final int elapsedMs;
}

/// 一组 local/remote 计数。-1 表示拉不到（网络错 / 老 server 没这个字段）。
class SyncCountPair {
  const SyncCountPair({required this.local, required this.remote});
  const SyncCountPair.missing()
      : local = 0,
        remote = -1;
  final int local;
  final int remote;
  bool get hasDiff => remote >= 0 && local != remote;

  /// 云端比本地多的条数（自愈闸门用）。
  ///
  /// remote 拉不到(-1)时 remote > local 恒为 false → 返回 0，避免网络错误
  /// 被误判成"本地缺云端数据"而误触发自愈；remote <= local（本地多 / 持平）
  /// 同样返回 0 —— 自愈只关心"云端有、本地缺"这个方向。
  int get remoteOnly => remote > local ? remote - local : 0;
}

/// 深度同步检测报告。UI 分两组展示：
/// - `当前账本`：tx，随 current ledger 走
/// - `全部账本`：tx 的全量合计，以及 category 用户级实体（per-ledger 跟 total 同值）
class SyncHealthReport {
  const SyncHealthReport({
    required this.ledgerTx,
    required this.totalTx,
    required this.categories,
    required this.unpushedChanges,
    this.carrierLedgerId,
    this.error,
    this.recovering = false,
    this.needsLogin = false,
    this.recoveryRemaining,
  });

  factory SyncHealthReport.error(String message) => const SyncHealthReport(
        ledgerTx: SyncCountPair.missing(),
        totalTx: SyncCountPair.missing(),
        categories: SyncCountPair.missing(),
        unpushedChanges: 0,
      ).copyWithError(message);

  /// 鉴权正在静默恢复（撞上 30s 冷却期）。UI 不应展示"检测失败"，
  /// 而是提示"登录状态恢复中…"并在 [recoveryRemaining] 后自动重试。
  ///
  /// 设计意图：把"冷却期内拉接口必然未认证"从错误降级为等待态，
  /// 避免用户看到 raw 异常后手动狂刷（冷却期内刷新也只会继续失败）。
  factory SyncHealthReport.recovering([Duration? remaining]) =>
      SyncHealthReport(
        ledgerTx: SyncCountPair.missing(),
        totalTx: SyncCountPair.missing(),
        categories: SyncCountPair.missing(),
        unpushedChanges: 0,
        recovering: true,
        recoveryRemaining: remaining,
      );

  /// 无恢复凭证 / 静默恢复彻底失败，必须用户手动重新登录。
  factory SyncHealthReport.needsLogin() => SyncHealthReport(
        ledgerTx: SyncCountPair.missing(),
        totalTx: SyncCountPair.missing(),
        categories: SyncCountPair.missing(),
        unpushedChanges: 0,
        needsLogin: true,
      );

  SyncHealthReport copyWithError(String message) => SyncHealthReport(
        ledgerTx: ledgerTx,
        totalTx: totalTx,
        categories: categories,
        unpushedChanges: unpushedChanges,
        carrierLedgerId: carrierLedgerId,
        error: message,
        recovering: recovering,
        needsLogin: needsLogin,
        recoveryRemaining: recoveryRemaining,
      );

  /// 当前账本口径。
  final SyncCountPair ledgerTx;

  /// 全量口径（跨当前用户所有账本）。
  final SyncCountPair totalTx;

  /// 用户级实体（per-ledger 跟 total 同值，只留一组）
  final SyncCountPair categories;

  final int unpushedChanges;

  /// 账户级对账的载体账本 id。
  ///
  /// 仅账户级健康检查（cloud 层 `SyncEngineHealthChecks.checkAccountHealth`）
  /// 填充：UI 需要知道这份报告的 ledgerTx 是**哪个**账本的口径，才能决定
  /// 是否展示「当前账本」组（载体不是当前账本时展示会误导用户）。
  /// 自愈 / 错误占位等账本级报告为 null。
  final int? carrierLedgerId;

  final String? error;

  /// 鉴权正在静默恢复（冷却中）。见 [SyncHealthReport.recovering]。
  final bool recovering;

  /// 无凭证 / 恢复彻底失败，需手动登录。见 [SyncHealthReport.needsLogin]。
  final bool needsLogin;

  /// 静默恢复冷却剩余时间；用于 UI 计算自动重试的延迟。
  final Duration? recoveryRemaining;

  bool get hasDiff {
    if (error != null || recovering || needsLogin) return false;
    if (unpushedChanges > 0) return true;
    return ledgerTx.hasDiff ||
        totalTx.hasDiff ||
        categories.hasDiff;
  }

  /// 本地比远端多，但没 unpushed change → 绕过 changeTracker 的历史种子数据。
  ///
  /// 刻意只比较 categories（user-global 实体）：目前的自愈通道只对 category
  /// 补写 change 记录；ledger-scoped 交易的差异由 [hasDiff] → syncAccount 的
  /// 全量对账处理，这里不纳入交易维度，避免 UI 进入“可回填”分支却没有对应动作。
  bool get needsBackfill {
    if (error != null || unpushedChanges > 0 || recovering || needsLogin) {
      return false;
    }
    // 仅 category 维度参与回填判断：ledgerTx/totalTx 没有对应的补写通道，
    // 若纳入会导致 UI 误入“可回填”分支但实际无法回填。
    if (categories.remote >= 0 && categories.local > categories.remote) {
      return true;
    }
    return false;
  }
}
