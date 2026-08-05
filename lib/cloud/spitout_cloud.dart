/// Spitout Cloud 白名单门面。
///
/// 设计意图：
/// 1. 作为「全 app」获取 Spitout Cloud 类型的唯一入口，屏蔽底层 adapter 包
///    `flutter_cloud_sync_spitout_cloud` 的直接感知。除本门面与 `lib/main.dart`
///    （Composition Root 装配点，注册 backend 与两因素回调）外，`lib/` 下
///    任何文件都不得直接 import 新 adapter 包（符合 CI 门禁：
///    `rg` 全 `lib/` 扫描，豁免门面与 main.dart）。
/// 2. 使用 show 白名单，仅导出实际使用的符号，避免全量 barrel 把
///    `SyncStatus` 等易与业务同名类型泄漏出去（业务侧在
///    `data/models/sync_models.dart` 有自己的 `SyncStatus`）。
/// 3. 门面本身位于 `lib/cloud/`，允许直接 import 新包；services / providers /
///    cloud-sync 层一律经此门面获取类型，保证 adapter 包暴露半径收敛到一处。
library;

// 核心包类型（Spitout Cloud 之外的通用云同步类型）
export 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show
        CloudBackendType,
        CloudServiceConfig,
        CloudUser,
        CloudAuthException,
        CloudProvider,
        CloudAuthService,
        NoopAuthService,
        CloudSyncException,
        CloudNotAuthenticatedException,
        CloudConfigurationException,
        CloudStorageException,
        CloudSerializationException,
        CloudSyncLogger,
        CloudCredentialStorage,
        SharedPreferencesCredentialStorage,
        createCloudServices,
        CloudServiceStore,
        encodeCloudConfig,
        decodeCloudConfig;

// Spitout Cloud adapter 类型（白名单，随 analyze 实测收敛）
export 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart'
    show
        SpitoutCloudProvider,
        SpitoutCloudSyncBackend,
        SpitoutCloudLedgerMember,
        SpitoutCloudInvite,
        SpitoutCloudInvitePreview,
        SpitoutCloudMemberStats,
        SpitoutCloudMemberStatItem,
        TwoFactorChallengeRequest,
        TwoFactorStatus,
        SpitoutCloudAuthService,
        SpitoutCloudRealtimeEvent,
        SpitoutCloudReadLedger,
        SpitoutCloudPullResult,
        SpitoutCloudSyncChange,
        SpitoutCloudInviteAcceptResult;
