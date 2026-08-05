/// 账本展示项模型
///
/// 纯数据模型，不包含同步状态（同步状态通过 syncStatusProvider 单独获取）
library;

import 'ledger_kind.dart';

/// 账本展示项（纯数据，不含同步状态）
class LedgerDisplayItem {
  /// 账本ID（本地）
  final int id;

  /// 账本名称
  final String name;

  /// 货币代码
  final String currency;

  /// 账单数量
  final int transactionCount;

  /// 账本支出总额（正数,= Σ expense）
  final double expenseTotal;

  /// 最后更新时间
  final DateTime lastUpdated;

  /// >1 时显示 🤝 角标。
  final bool isShared;

  /// 含 Owner 在内的成员数,UI 显示 "🤝 N人"。
  final int memberCount;

  /// 当前用户在该账本的角色 (owner/editor)。
  final String myRole;

  /// 账本归属:`'local'` 纯本地账本 / `'cloud'` 云端账本。
  ///
  /// 这是账本列表分区(「本地账本」/「Spitout Cloud 账本」)的唯一依据。
  /// 判断一个账本会不会同步的唯一权威来源是 storageMode —— 用户可以把
  /// 云端账本移回本地,那时 syncId 会被清空但用户心智里它仍是"我原来那本账"。
  final String storageMode;

  const LedgerDisplayItem({
    required this.id,
    required this.name,
    required this.currency,
    required this.transactionCount,
    required this.expenseTotal,
    required this.lastUpdated,
    this.isShared = false,
    this.memberCount = 1,
    this.myRole = 'owner',
    this.storageMode = 'local',
  });

  /// 是否为云端账本(参与被动同步、退出登录时会被清理)。
  ///
  /// 统一走 ledger_kind.dart 的谓词:storageMode == 'cloud' || isShared,
  /// 共享账本即使 storageMode 缺失也不会被误判为本地账本。
  bool get isCloudLedger => isCloudLedgerOf(storageMode, isShared: isShared);

  /// 从本地账本创建
  factory LedgerDisplayItem.fromLocal({
    required int id,
    required String name,
    required String currency,
    required DateTime createdAt,
    required int transactionCount,
    required double expenseTotal,
    bool isShared = false,
    int memberCount = 1,
    String myRole = 'owner',
    String storageMode = 'local',
  }) {
    return LedgerDisplayItem(
      id: id,
      name: name,
      currency: currency,
      transactionCount: transactionCount,
      expenseTotal: expenseTotal,
      lastUpdated: createdAt,
      isShared: isShared,
      memberCount: memberCount,
      myRole: myRole,
      storageMode: storageMode,
    );
  }

  /// 相等语义为“身份相等”：本地 id 相同即视为同一账本，
  /// 名称/金额/成员数等字段变化不影响判等。
  /// 列表刷新用新实例整体替换，不依赖 == 做字段变更检测。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerDisplayItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// 与“身份相等”的语义一致，仅以本地 id 参与哈希。
  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LedgerDisplayItem(id: $id, name: $name)';
}
