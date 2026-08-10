import 'package:spitout/data/db.dart';

/// AA 分摊:虚拟用户 Repository 接口。
///
/// 设计意图:共享账本下 AA 分摊的参与人并非都是注册用户(例如室友、家人),
/// 虚拟用户用于补充参与人标识。虚拟用户是账本内实体(ledger-scoped),
/// 不跨账本共享;CRUD 写操作走 LocalRepository 委托(保证 sync 登记统一,
/// 禁止绕过)。
///
/// 删除约束:名下有账(被交易的 aaParticipants 引用)不可删,
/// 规避悬空引用;删除走硬删 + change log delete 投影。
abstract class LedgerVirtualUserRepository {
  /// 监听指定账本下的全部虚拟用户。
  Stream<List<LedgerVirtualUser>> watchByLedger(int ledgerId);

  /// 获取指定账本下的全部虚拟用户(一次性查询)。
  Future<List<LedgerVirtualUser>> getByLedger(int ledgerId);

  /// 根据 syncId 获取单个虚拟用户(跨设备同步匹配用)。
  Future<LedgerVirtualUser?> getBySyncId(String syncId);

  /// 新建虚拟用户。
  ///
  /// [syncId] 不传时本地自动生成 UUID(新建场景);sync pull 时传 server
  /// 下发的 syncId。返回本地自增 id。
  Future<int> create({
    required int ledgerId,
    required String name,
    String? syncId,
  });

  /// 重命名虚拟用户。
  Future<void> rename({
    required int id,
    required String name,
  });

  /// 删除虚拟用户(硬删)。
  ///
  /// 删除前校验该虚拟用户是否被任何交易的 aaParticipants 引用:
  /// - 被引用 → 抛 [StateError],不允许删除;
  /// - 未被引用 → 硬删并返回 true。
  ///
  /// 调用方(Provider/服务层)负责登记 change log delete 投影,
  /// 本接口只管数据层删除。
  Future<bool> delete(int id);

  /// 校验指定虚拟用户是否被交易的 aaParticipants 引用。
  /// 返回 true 表示被引用(不可删),false 表示可删。
  Future<bool> isReferencedByAnyTransaction(int id);
}
