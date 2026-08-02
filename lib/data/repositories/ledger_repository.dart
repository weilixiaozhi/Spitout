import '../db.dart';

/// 账本Repository接口
/// 定义账本相关的所有数据操作
abstract class LedgerRepository {
  /// 监听所有账本列表
  Stream<List<Ledger>> watchLedgers();

  /// 获取所有账本列表（一次性查询）
  Future<List<Ledger>> getAllLedgers();

  /// 根据ID获取单个账本
  Future<Ledger?> getLedgerById(int id);

  /// 获取指定账本的统计信息（记账天数、交易笔数）
  Future<({int dayCount, int txCount})> getCountsForLedger({
    required int ledgerId,
  });

  /// 获取账本统计信息（支出总额、交易数等）
  Future<({double expenseTotal, int transactionCount})> getLedgerStats({
    required int ledgerId,
    List<Transaction>? transactions,
  });

  /// 创建账本。
  /// [storageMode] 归属模式:cloud 才分配跨设备 syncId;local 账本 syncId 为 null,
  /// 从源头断开云端关联。默认 'cloud' 以兼容现有调用方;未登录用户由 UI 显式传 'local'。
  Future<int> createLedger({
    required String name,
    String currency = 'CNY',
    String storageMode = 'cloud',
  });

  /// 更新账本归属模式(local / cloud),移动操作完成后调用。
  Future<void> updateLedgerStorageMode({
    required int id,
    required String storageMode,
  });

  /// 更新账本 syncId;传入 null 用于"移动到本地"彻底断联云端。
  Future<void> updateLedgerSyncId({
    required int id,
    String? syncId,
  });

  /// 「转本地」时把账本从云端断联:同一事务内翻 storageMode='local' 并清空 syncId。
  ///
  /// 设计意图:归属翻本地(storageMode)与断联(syncId=null)必须原子一致——若
  /// 拆成两条裸 update,中途失败会留下「mode 已翻 local 但 syncId 仍在」或反之的
  /// 半截态;这种中间态会被 pull 当成云端账本回灌,或被 tombstone 按 syncId 命中
  /// 误删。事务化保证要么全成功、要么全回滚,不留半截态。
  Future<void> detachFromCloud(int id);

  /// 将源账本的分类/交易/编辑历史整体拷贝到目标账本(跨账本搬运)。
  /// 新建副本使用新的 syncId、断开共享关联;用于"复制到本地"等场景。
  Future<void> copyLedgerData({
    required int sourceLedgerId,
    required int targetLedgerId,
  });

  /// 更新账本名称
  Future<void> updateLedgerName({
    required int id,
    required String name,
  });

  /// 更新账本信息
  Future<void> updateLedger({
    required int id,
    String? name,
    String? currency,
    int? monthStartDay,
  });

  /// 监听单个账本(sync pull 改了 ledger 行时自动通知 watcher)
  Stream<Ledger?> watchLedger(int id);

  /// 删除账本（同时删除关联的所有交易）
  Future<void> deleteLedger(int id);

  /// 清除指定账本在 local_changes 中的所有待推送变更。
  ///
  /// 使用场景:「全局删除账本」时远端已先行删除,[deleteLedger] 登记的
  /// delete change 不应再被同步协调器推送(否则会向已删除的远端账本推
  /// change,甚至触发快照复活),必须在删除完成后一次性抹掉。
  Future<void> clearLocalChangesForLedger(int ledgerId);

  /// 获取当前最大账本ID
  Future<int> getMaxLedgerId();

  /// 获取下一个未占用的账本ID
  Future<int> getNextFreeLedgerId();

  /// 将账本ID从 fromId 迁移到 toId（同时更新关联的 transactions）
  Future<void> reassignLedgerId({
    required int fromId,
    required int toId,
  });

  /// 清空指定账本的所有交易记录，返回删除的条数
  Future<int> clearLedgerTransactions(int ledgerId);

  /// 彻底清本地某共享账本的所有数据(被踢 / Owner 删账本 / 自己退出后调用)。
  ///
  /// 与 [deleteLedger] 的区别:本方法**不**写 local_changes,因为云端已经完成了
  /// 删除 / 退出的状态变更;本地只需抹掉残留数据,避免下次 sync 又被云端重新 upsert 回来。
  /// 幂等:若本地已无该账本(externalId 解析不到 localId),直接返回。
  Future<void> purgeSharedLedger(String externalId, {int? localId});

  /// 批量清除本地所有 isShared=true 账本（云端下线场景）。
  ///
  /// 以 isShared 为唯一闸门,级联清理 local_changes / 镜像表 / 交易 / 账本行。
  /// 选择键与 syncId 无关,因此个人账本(即使 syncId 为空)绝不受影响。
  /// 幂等:本地无共享账本时直接返回。
  Future<void> purgeAllSharedLedgers();

  /// 批量清除本地所有云端账本（退出登录场景）。
  ///
  /// 选择键 `storage_mode='cloud' OR isShared=true`:云端账本的数据留在服务端,
  /// 退出后不该滞留在这台设备上;共享账本更是别人的资源。
  /// 纯本地账本(storage_mode='local' 且非共享)完全不受影响。
  /// 幂等:本地无云端账本时直接返回。
  Future<void> purgeAllCloudLedgers();

  /// 把本地残留的「孤儿云端账本」就地归一化为纯本地账本（未登录恢复兜底）。
  ///
  /// 语义:整库文件级备份恢复会原子覆盖 sqlite、绕过归属闸门,把
  /// `storage_mode='cloud'` / `isShared=true` 的账本原样写回本地。设备此刻若
  /// 处于未登录(本地模式),这些账本就成了孤儿云端态——能记账,但「转本地」
  /// 入口强依赖登录态,用户被卡死在云分区。本方法把它们就地改写成纯本地账本
  /// (storage_mode='local' / isShared=false / syncId=null / myRole='owner' /
  /// memberCount=1 / owner_user_id=null),**一行数据都不删**,只改归属字段。
  ///
  /// 选区:与 [purgeAllCloudLedgers] 同源的 `cloudLedgerFilter`
  /// (`storage_mode='cloud' OR isShared=true`),纯本地账本完全不受影响。
  ///
  /// 实现约束:必须在同一事务内**先删镜像表(ledger_members /
  /// shared_ledger_categories)再清字段**。字段一旦清空 syncId,镜像表就再也
  /// 关联不到账本、只能变成永久孤儿行。
  ///
  /// 调用约束:**严禁在已登录的认领路径(reregisterRestoredLedgers)之前预调用**。
  /// 认领依赖旧 syncId 命中 server 的 409 走幂等重认领,预先清空 syncId 会让
  /// 同账号恢复退化成「新建一本」,产生云端重复账本。
  ///
  /// 返回:按每本账本 `isShared` 的**原值**分别计数——
  /// `personal` 为个人云端账本数(isShared=false),`shared` 为共享账本数
  /// (isShared=true),供日志/审计与 UI 区分提示。
  /// 幂等:选区为空时不做任何写操作,直接返回 `(personal: 0, shared: 0)`。
  Future<({int personal, int shared})> normalizeOrphanCloudLedgers();
}
