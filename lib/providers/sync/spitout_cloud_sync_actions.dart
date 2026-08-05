import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/cloud/spitout_cloud.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/providers/sync/sync_providers.dart' as sync_providers;

/// Spitout Cloud 同步操作门面。
///
/// 设计意图：UI 层对 `SyncEngine` 实现类的直连统一经本门面 —— `is SyncEngine`
/// 判断（「当前后端是否具备云能力」的分发逻辑）集中在 providers 层，
/// 不散落在 pages/widgets 层。统一在这里 resolve `syncServiceProvider`
/// 并做类型收窄。非 SyncEngine（如 LocalOnly / 快照型后端）时各方法返回
/// 空值兜底。
///
/// 依赖方向：pages/widgets → providers（本类）→ services（SyncEngine），
/// 符合项目 rule 1 的单向分层约束。
class SpitoutCloudSyncActions {
  /// 门面不持有引擎实例，每次方法调用时从 provider 解析当前服务，
  /// 保证与 `syncEngineProvider` 的 family 共享语义一致（全局唯一实例）。
  SpitoutCloudSyncActions(this._ref);

  final Ref _ref;

  /// resolve 当前同步服务；仅当它是 [SyncEngine]（Spitout Cloud 增量同步引擎）
  /// 时才视为具备云操作能力，否则返回 null 由调用方按「无云能力」兜底。
  SyncEngine? _resolveEngine() {
    final service = _ref.read(sync_providers.syncServiceProvider);
    return service is SyncEngine ? service : null;
  }

  /// 当前后端是否具备 Spitout Cloud 增量同步能力。
  ///
  /// UI 侧统一调本 getter 做「无云能力早退」（LocalOnly / 快照型后端直接
  /// 跳过整个刷新流程，连 loading 都不起），无需直接触碰 SyncEngine 类型。
  bool get hasSyncEngine => _resolveEngine() != null;

  /// 账户健康检查：对账本地/云端计数并产出 [SyncHealthReport]。
  ///
  /// 非 SyncEngine 后端返回 null（UI 现状 L123 `is! SyncEngine → return`
  /// 的等价行为），让 UI 无需再关心后端类型分发。
  Future<SyncHealthReport?> checkAccountHealth({int? carrierLedgerId}) async {
    final engine = _resolveEngine();
    if (engine == null) return null;
    return engine.checkAccountHealth(carrierLedgerId: carrierLedgerId);
  }

  /// 补写未跟踪实体（本地有但从未写过 sync_change 的实体，如手工创建的分类），
  /// 返回补写的 change 条数。非 SyncEngine 后端返回 0（无操作）。
  Future<int> backfillUntrackedEntities({required int ledgerId}) async {
    final engine = _resolveEngine();
    if (engine == null) return 0;
    return engine.backfillUntrackedEntities(ledgerId: ledgerId);
  }

  /// 拉取 `/profile/me` 并回落本地（appearance / 头像），任一字段有更新
  /// 返回 true 供调用方 bump 刷新 tick。非 SyncEngine 后端返回 false。
  Future<bool> syncMyProfile() async {
    final engine = _resolveEngine();
    if (engine == null) return false;
    return engine.syncMyProfile();
  }

  /// 自愈闸门：任一云端账本处于「连续自愈失败」熔断期则返回 true。
  /// 非 SyncEngine 后端返回 false（熔断是 SyncEngine 特有概念）。
  bool anySelfHealBroken() {
    final engine = _resolveEngine();
    return engine != null && engine.anySelfHealBroken();
  }

  /// 账户级同步原语：枚举全部云端账本逐个同步 + Phase1 用户级数据。
  /// 非 SyncEngine 后端返回 null（UI 现状同样在 is 判断后早退）。
  Future<SyncAccountResult?> syncAccount() async {
    final engine = _resolveEngine();
    if (engine == null) return null;
    return engine.syncAccount();
  }

  /// 对账 profile：把「server 为空但本地非默认」的字段补推上去。
  ///
  /// 薄包装 `sync_providers.dart` 的同名顶层函数，避免造成第二份实现
  /// （该函数内部依赖 `spitoutCloudProviderInstance` 等 provider）。
  Future<void> reconcileProfileToServer({
    required Future<SpitoutCloudSyncBackend?> cloudProviderFuture,
    required String currentDisplayName,
    required String currentExpenseColorScheme,
  }) {
    return sync_providers.reconcileProfileToServer(
      cloudProviderFuture: cloudProviderFuture,
      currentDisplayName: currentDisplayName,
      currentExpenseColorScheme: currentExpenseColorScheme,
    );
  }
}

/// 门面 provider：全局唯一实例，UI 经 providers.dart barrel re-export 获取。
///
/// 保持非 autoDispose：与 `syncEngineProvider` 的 family 共享语义一致，
/// 避免页面切走导致门面重建、进而触发 syncServiceProvider 重建。
final spitoutCloudSyncActionsProvider = Provider<SpitoutCloudSyncActions>(
  (ref) => SpitoutCloudSyncActions(ref),
);
