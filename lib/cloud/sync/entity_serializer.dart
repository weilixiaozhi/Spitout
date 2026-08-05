import 'dart:convert';

import '../../data/db.dart';

/// 实体序列化工具
/// 将本地 Drift 实体转为 JSON payload（用于 sync push）
/// 以及从 JSON payload 还原为本地实体
class EntitySerializer {
  // ==================== Transaction ====================

  /// 序列化 [Transaction] 为 sync push payload。
  ///
  /// AA 分摊字段(paidByUserId/aaMode/aaParticipants/aaSplits)采用"非空才发"
  /// 守卫：null 字段不发键,server merge 走缺键保护(保留本地既有值),
  /// 旧 server 收不到未知键也不会崩(向后兼容)。
  static Map<String, dynamic> serializeTransaction(
    Transaction tx, {
    String? categoryName,
    String? categoryKind,
    String? categorySyncId,
    String? ledgerSyncId,
  }) {
    // 同时带 *Name 和 *Id（syncId）到服务端。服务端的 read 会优先按 id 反查
    // snapshot 里当前 entity 的名字，名字字段只作为历史/兼容兜底。这样任何
    // 实体重命名都不依赖"每个引用位点的 cascade 改写"，兑现"按 id 取实时
    // 名字"的承诺。
    //
    // ledgerSyncId 是跨设备关键：change log 外层的 ledger_id 是推送方的本地
    // int id，对端设备可能匹配不上；payload 里带上 ledger 的 syncId，对端
    // apply 时能先按 syncId 找到本地账本，再用 int id 兜底。
    //
    final nativeAmount = tx.nativeAmount;
    return {
      'syncId': tx.syncId,
      'type': tx.type,
      // 数据库存整数分,同步接口仍按"元"口径下发(服务端契约不变)。
      'amount': tx.amount / 100,
      'happenedAt': tx.happenedAt.toUtc().toIso8601String(),
      'note': tx.note,
      // 账单标记:两个独立 bool。camelCase 键与 server 端
      // projection upsert 对齐 —— 改键名会让标记跨设备静默丢失。
      'excludeFromStats': tx.excludeFromStats,
    // 交易级多币种:原币种 + 折账本本位币快照(与服务端两列对齐)。
    // 有值才发:NULL 发出去会被 server merge 视为"不更新"(None 被过滤),
    // 语义等价;省略保持 payload 干净。
    if (tx.currencyCode != null) 'currencyCode': tx.currencyCode,
      if (nativeAmount != null) 'nativeAmount': nativeAmount / 100,
      if (ledgerSyncId != null && ledgerSyncId.isNotEmpty)
        'ledgerSyncId': ledgerSyncId,
      'categoryName': categoryName,
      'categoryKind': categoryKind,
      if (categorySyncId != null && categorySyncId.isNotEmpty)
        'categoryId': categorySyncId,
      // 发送创建者/编辑者字段，键名与 sync_engine_apply 读取端对齐。
      if (tx.createdByUserId != null && tx.createdByUserId!.isNotEmpty)
        'createdByUserId': tx.createdByUserId,
      if (tx.lastEditedByUserId != null && tx.lastEditedByUserId!.isNotEmpty)
        'updatedByUserId': tx.lastEditedByUserId,
      // AA 分摊:支出人 userId。非空才发,缺键保护下旧 server / 旧客户端
      // apply 时视为未启用 AA。运行时写入层已 ?? 操作者 userId 兜底,
      // 此处仅在确实有值时下发。
      if (tx.paidByUserId != null && tx.paidByUserId!.isNotEmpty)
        'paidByUserId': tx.paidByUserId,
      // AA 分摊模式:null/0=人均,1=不分摊,2=指定。非空才发,
      // null 视为人均(历史交易默认进人均统计)。
      if (tx.aaMode != null) 'aaMode': tx.aaMode,
      // AA 参与人(JSON 数组字符串:元素为 userId 或虚拟用户 syncId)。
      // 空值运行时展开为账本全部成员,此处不展开,只发已写入值。
      if (tx.aaParticipants != null && tx.aaParticipants!.isNotEmpty)
        'aaParticipants': tx.aaParticipants,
      // AA 指定分摊金额(JSON 对象字符串:key=参与人,value=金额字符串)。
      // 仅 aaMode=2 时有意义。
      if (tx.aaSplits != null && tx.aaSplits!.isNotEmpty)
        'aaSplits': tx.aaSplits,
    };
  }

  // ==================== ExchangeRateOverride ====================

  /// 字段与 server 端 projection.upsert_exchange_rate_override 一一对应;
  /// 方向:1 quote = rate base。
  static Map<String, dynamic> serializeExchangeRateOverride(
      ExchangeRateOverride o) {
    return {
      'syncId': o.syncId,
      'baseCurrency': o.baseCurrency,
      'quoteCurrency': o.quoteCurrency,
      'rate': o.rate,
      'updatedAt': (o.updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };
  }

  // ==================== Category ====================

  static Map<String, dynamic> serializeCategory(
    Category category, {
    String? parentName,
    String? parentSyncId,
  }) {
    return {
      'syncId': category.syncId,
      'name': category.name,
      'kind': category.kind,
      'level': category.level,
      'sortOrder': category.sortOrder,
      'icon': category.icon,
      // 共享账本二级分类:parent 的稳定 syncId,server 端 projection.upsert_category
      // 直接用,不依赖 parent_name 反查(同名 + 重命名场景更稳)。
      'parentName': ?parentName,
      'parentSyncId': ?parentSyncId,
    };
  }

  // ==================== Ledger ====================

  /// 账本元数据(名字 / 币种 / 月度起始日 / AA 分摊开关)的跨设备 payload。
  /// 字段名对齐 server `WriteLedgerMetaUpdateRequest`,server materialize 时
  /// 会用这些字段更新 `ledger_snapshot` 的 top-level `ledgerName` / `currency`。
  /// `monthStartDay` 对齐 server `ReadLedgerOut.month_start_day`(1-28)。
  ///
  /// `aaEnabled` 必须跨设备同步:与 ledger 名/币种同通道下发,关闭后入口隐藏、
  /// 历史数据不展示不参与统计,重开数据仍在。
  static Map<String, dynamic> serializeLedger(Ledger ledger) {
    return {
      'syncId': ledger.syncId,
      'ledgerName': ledger.name,
      'currency': ledger.currency,
      'monthStartDay': ledger.monthStartDay,
      'aaEnabled': ledger.aaEnabled,
    };
  }

  // ==================== VirtualUser ====================

  /// 序列化虚拟用户为 sync push payload。
  ///
  /// 虚拟用户是 ledger-scoped 实体(与 transaction 同通道),change log 走
  /// create/update/delete 三类 action。字段对齐 server virtual_user projection:
  /// `syncId`(跨设备唯一标识) + `name`(昵称)。
  ///
  /// 不带 ledgerId:ledger_id 走 change log 外层(recordLedgerChange 传入),
  /// 与 transaction payload 模式一致。
  static Map<String, dynamic> serializeVirtualUser(LedgerVirtualUser user) {
    return {
      'syncId': user.syncId,
      'name': user.name,
    };
  }

  // ==================== JSON Encode ====================

  static String toJsonString(Map<String, dynamic> payload) {
    return jsonEncode(payload);
  }

  static Map<String, dynamic> fromJsonString(String json) {
    return jsonDecode(json) as Map<String, dynamic>;
  }
}
