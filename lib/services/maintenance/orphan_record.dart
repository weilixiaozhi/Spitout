/// 本地孤儿数据清理 — 数据模型。
///
/// `OrphanScanner` 扫出来的每条异常对应一个 `OrphanRecord`。`OrphanCleaner`
/// 接 `List<OrphanRecord>` 按 `type` dispatch 到具体删除分支。UI 层按 type
/// 分组显示、按 record 勾选。
///
/// type 枚举跟 plan 文件里的 A 类 / C1 一一对应(无文件类 B,分类图标不支持
/// 自定义),后续加新检测项只需扩枚举 + scanner / cleaner 各加一个 case。
library;

/// 孤儿数据类型,跟 plan 检测清单对齐（不含标签/预算/附件/图标文件相关类型）
enum OrphanType {
  /// A6 交易的 category_id 失主
  txMissingCategory,

  /// A7 二级分类失父
  categoryMissingParent,

  /// A9 共享二级分类失父
  sharedCategoryMissingParent,

  /// A_new 交易的 ledger_id 指向已删除账本(无账本孤儿数据)
  txMissingLedger,

  /// A_dup 同账本内 sync_id 重复的交易(云端全量恢复盲插导致的重复行)。
  /// 每组重复只保留最早插入的一条(MIN(id)),其余行报为孤儿待删。
  txDuplicateSyncId,

  /// C1 local_changes 失主实体
  localChangeMissingEntity,
}

/// 单条孤儿数据。
///
/// DB 类(A/C):`localId` 或 `syncId` 至少一个非空。
class OrphanRecord {
  const OrphanRecord({
    required this.type,
    required this.title,
    required this.subtitle,
    this.localId,
    this.syncId,
    this.extra,
  });

  final OrphanType type;

  /// UI 主标题,e.g. "预算 #5"
  final String title;

  /// UI 副标题,e.g. "金额 ¥3000 · 账本已删 (ledgerId=2)"
  final String subtitle;

  /// 主表行 id。cleaner 按 type + localId 删 DB 行。
  final int? localId;

  /// 实体 syncId(部分类型有)。C1 用 syncId 定位 local_changes 行。
  final String? syncId;

  /// 类型专属附加 payload(不必序列化),cleaner 内部用。
  /// 例:txTagMissingTx 携带 txId 用于复用主表更新逻辑。
  final Map<String, Object?>? extra;

  /// 稳定的唯一标识 — UI 给 ListView key + 勾选集合用。
  String get uniqueKey {
    final id = localId ?? syncId ?? '';
    return '${type.name}:$id';
  }
}

/// 孤儿数据按 group 聚合结果。UI 用两组 SectionCard 渲染。
class OrphanScanReport {
  const OrphanScanReport({
    required this.dbOrphans,
    required this.syncOrphans,
  });

  /// A 类
  final List<OrphanRecord> dbOrphans;

  /// C1
  final List<OrphanRecord> syncOrphans;

  int get totalCount => dbOrphans.length + syncOrphans.length;

  Iterable<OrphanRecord> get all sync* {
    yield* dbOrphans;
    yield* syncOrphans;
  }

  static const empty = OrphanScanReport(
    dbOrphans: [],
    syncOrphans: [],
  );
}

/// 清理结果 — `OrphanCleaner.clean` 返回。
class OrphanCleanResult {
  const OrphanCleanResult({
    required this.successCount,
    required this.failures,
  });

  final int successCount;

  /// 失败列表,key=record.uniqueKey, value=异常信息
  final List<({OrphanRecord record, String error})> failures;

  bool get hasFailure => failures.isNotEmpty;
  int get totalAttempted => successCount + failures.length;

  static const empty =
      OrphanCleanResult(successCount: 0, failures: <({OrphanRecord record, String error})>[]);
}
