/// 变更记录器抽象（data 层端口 / port）。
///
/// 设计意图：本地 Repository 写操作后需要登记一条"待同步变更"，
/// 但变更追踪的具体实现（local_changes 表写入）属于 cloud/sync 层。
/// data 层若直接 import cloud 层实现会形成上行依赖（data → cloud），
/// 违反分层方向。故在此定义抽象接口，由 cloud/sync 的 ChangeTracker
/// 实现并在 Provider 注入点组装（依赖倒置，注入点见
/// providers/core/database_providers.dart 的 repositoryProvider）。
///
/// 未注入实现时（changeTracker == null）本地写操作照常执行，
/// 仅跳过变更登记 —— "空实现"效果由调用处的 null 判断承担，
/// 无需额外提供 Noop 类。
library;

abstract class ChangeRecorder {
  /// 记录一条 user-global 实体（category / exchange_rate_override）的变更。
  ///
  /// 实现方负责把变更挂到全局同步通道（ledgerId = 0），
  /// 调用方不感知 scope 选择。
  Future<void> recordUserGlobalChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required String action,
    String? payloadJson,
  });

  /// 记录一条 ledger-scoped 实体（transaction / ledger / ledger_snapshot）
  /// 的变更。[ledgerId] 必须为具体账本 id（> 0）。
  Future<void> recordLedgerChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  });
}
