/// 快照型后端脏账本标记器（data 层端口 / port）。
///
/// 设计意图：类比 [ChangeRecorder] —— 本地 Repository 在 createLedger 后
/// 需要登记"这本账本需要上传快照"的信号，但信号的具体实现（写
/// `snapshot_dirty_ledgers` 表）属于 cloud/sync 层。data 层若直接 import
/// cloud 层实现会形成上行依赖（data → cloud），违反分层方向。故在此定义
/// 抽象端口，由 cloud/sync 的 `SnapshotDirtyTracker` 实现并在 Provider
/// 注入点组装（依赖倒置，注入点见 providers/core/database_providers.dart
/// 的 repositoryProvider）。
///
/// 注入策略（与 [ChangeRecorder] 互斥，由后端类型决定）：
/// - Spitout Cloud：注入 [ChangeRecorder]，走 local_changes 增量通道；
/// - 快照型后端（webdav/s3/supabase）：注入本端口，走整本快照重传通道；
/// - 无后端 / 配置未就绪：两者都不注入，本地写操作照常执行仅跳过信号登记。
///
/// 未注入实现时（marker == null）本地写操作照常执行，仅跳过信号登记 ——
/// "空实现"效果由调用处的 null 判断承担，无需额外提供 Noop 类。
library;

abstract class SnapshotDirtyMarker {
  /// 标记指定账本为"脏"——需要上传整本快照。
  ///
  /// 实现方负责 UPSERT 语义（同账本多次标记只留一行，保留首次标记时间）。
  /// 调用方不感知后端类型，仅按"账本被新建/变更"的事实登记。
  Future<void> markLedgerDirty(int ledgerId);
}
