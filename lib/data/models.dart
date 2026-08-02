/// 数据模型统一出口（barrel）。
///
/// 设计意图：
/// UI 层（pages/widgets）只允许从本文件获取数据模型类型，
/// 不直连 db.dart（Drift schema / 数据库定义文件）。这样
/// schema 变更对 UI 的波及面收敛到本 barrel 一个文件——
/// db.dart 内部的表定义、Companion、SpitoutDatabase 与查询 API
/// 均不暴露给 UI。
///
/// 分层约定：
/// - 写路径与查询：一律走 repositoryProvider，UI 不感知 Drift；
/// - 读路径：StreamProvider 包装 repository 暴露的 stream，可保留；
/// - 模型类型：经本 barrel re-export，是 UI 唯一合法的数据层依赖。
///
/// 注意：本文件只 re-export UI 实际使用的行类型；新增表后若 UI
/// 需要引用其模型，须在此显式补充 show 条目（保持出口最小化）。
library;

export 'db.dart'
    show
        Category,
        Transaction,
        Ledger,
        RecurringTransaction,
        RecordEditHistory;

// 非表行模型（纯 Dart 数据模型与层级构建器）统一经本 barrel 出口。
// 设计意图：UI 与云同步层统一只认 data/models.dart 一个入口。
export 'models/ledger_display_item.dart';
// 出口最小化：UI 层只用到 `isCloudLedgerOf` 这一个归属判定谓词；
// SQL 工厂 `cloudLedgerFilter` 与 `isLocalLedgerOf` 属于同步引擎内部细节,
// 经本 barrel 的 show 白名单强制屏蔽,即使未来新增符号也不会自动泄漏给 UI。
export 'models/ledger_kind.dart' show isCloudLedgerOf;
// 云同步纯数据模型：
// UI 获取同步状态/差异/健康报告类型统一走本 barrel，不直连
// cloud/sync/sync_service.dart 与 cloud/sync/sync_engine.dart。
export 'models/sync_models.dart'
    show
        PullOutcome,
        SyncDiff,
        SyncStatus,
        SyncAccountResult,
        SyncCountPair,
        SyncHealthReport;
// 应用更新检查纯数据模型：
// UI 获取更新状态/结果类型统一走本 barrel，不直连
// services/update/app_update_service.dart。
// releasePageBase 为 AppUpdateInfo 静态常量，随 show 自动导出。
export 'models/app_update_info.dart' show AppUpdateInfo, UpdateStatus;
// 统一数据导入模型：
// UI 与 cloud/sync 层取 Import* 类型统一走本 barrel；落库编排逻辑仍留在
// services/import/data_import_service.dart（依赖汇率服务）。
export 'models/import_models.dart'
    show ImportCategory, ImportTransaction, ImportData, ImportResult;
