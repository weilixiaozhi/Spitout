/// 统一数据导入模型。
///
/// 设计意图：
/// - 四个 DTO 为纯数据载体，零依赖（不引 db/drift/任何服务），放 data/
///   层不会引入任何反向依赖，作为「数据底座」完全合法。
/// - 它们同时被 CSV 导入（UI 层）与云端恢复（cloud/sync 层）消费，
///   所有层统一经 `data/models.dart` 门面取类型，不直连
///   services/import/data_import_service.dart 取类型。
/// - 落库编排逻辑仍留在 services/import/data_import_service.dart（依赖
///   services/currency 做汇率补拉），本文件只承载类型。

library;

/// 导入分类（CSV/云端恢复统一口径）
class ImportCategory {
  final String name;
  final String kind; // 全局仅支出模式，固定为 'expense'
  final int level; // 1 or 2
  final int sortOrder; // 排序顺序
  final String? icon;
  final String? parentName; // 二级分类的父分类名称

  const ImportCategory({
    required this.name,
    required this.kind,
    this.level = 1,
    this.sortOrder = 0,
    this.icon,
    this.parentName,
  });
}

/// 导入交易数据
class ImportTransaction {
  final String type; // 全局仅支出模式，固定为 'expense'
  final double amount;
  final String? categoryName;
  final String? categoryKind;
  final DateTime happenedAt;
  final String? note;
  final int? categoryId; // 预解析的分类ID（优先于categoryName）
  final String? syncId; // 跨设备同步唯一标识
  /// 多币种:CSV 币种列。null → 账本本位币兜底。
  final String? currencyCode;

  /// 源端折算快照(折账本本位币金额)。
  ///
  /// 仅云端全量恢复路径携带:/sync/full 的 tx item 输出的 nativeAmount 是
  /// 源设备记账时按当时汇率折算的真实所见金额。null(CSV 导入/无该字段的
  /// 备份) → 落库时按本地有效汇率重算,与常规导入语义一致。
  final double? nativeAmount;

  /// 不计入支出统计标记。null(JSON 无此键) → 落库默认 false,
  /// 与 server snapshot「缺键 = false」语义对齐。
  final bool? excludeFromStats;

  /// AA 分摊:支出人 userId。null(JSON/CSV 无此键) → 落库 null,
  /// 由运行时写入层 ?? 操作者 userId 兜底,展示层空串降级"未知"。
  final String? paidByUserId;

  /// AA 分摊模式:null/0=人均,1=不分摊,2=指定。null 视为人均。
  final int? aaMode;

  /// AA 参与人(JSON 数组字符串:元素为 userId 或虚拟用户 syncId)。
  /// null/空 → 运行时展开为账本全部成员。
  final String? aaParticipants;

  /// AA 指定分摊金额(JSON 对象字符串:key=参与人,value=金额字符串)。
  /// 仅 aaMode=2 时有意义。
  final String? aaSplits;

  const ImportTransaction({
    required this.type,
    required this.amount,
    this.currencyCode,
    this.nativeAmount,
    this.excludeFromStats,
    this.categoryName,
    this.categoryKind,
    required this.happenedAt,
    this.note,
    this.categoryId,
    this.syncId,
    this.paidByUserId,
    this.aaMode,
    this.aaParticipants,
    this.aaSplits,
  });
}

/// 导入虚拟用户(AA 分摊专用,随账本 JSON v7 导出导入)。
///
/// 设计意图:虚拟用户是 ledger-scoped 实体,若不随账本备份导出,导入后
/// 指定分摊数据(aaParticipants/aaSplits 引用虚拟用户 syncId)会悬空(R9)。
class ImportVirtualUser {
  /// 跨设备唯一标识(UUID),与 server virtual_user 投影对齐。
  final String? syncId;

  /// 虚拟用户昵称。
  final String name;

  const ImportVirtualUser({
    this.syncId,
    required this.name,
  });
}

/// 统一的导入数据格式
class ImportData {
  final List<ImportCategory> categories;
  final List<ImportTransaction> transactions;

  /// 虚拟用户列表(可选):仅云端全量恢复 / v7 备份携带。
  /// CSV 导入路径不填,落库时跳过虚拟用户导入。
  final List<ImportVirtualUser> virtualUsers;

  /// 账本名称（可选，用于更新账本信息）
  final String? ledgerName;
  /// 货币（可选，用于更新账本信息）
  final String? currency;

  /// AA 分摊开关(可选):仅云端全量恢复 / v7 备份携带。
  /// null → 不更新账本既有值。
  final bool? aaEnabled;

  const ImportData({
    this.categories = const [],
    this.transactions = const [],
    this.virtualUsers = const [],
    this.ledgerName,
    this.currency,
    this.aaEnabled,
  });
}

/// 导入结果
class ImportResult {
  final int inserted;
  final int failed;

  const ImportResult({
    required this.inserted,
    required this.failed,
  });
}
