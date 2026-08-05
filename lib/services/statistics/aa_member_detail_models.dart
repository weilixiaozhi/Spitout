/// 成员账单详情页的入参 / 数据契约。
///
/// 设计意图：分摊详情表的每个成员都可点击进入「该成员作为支出人的账单
/// 详情」。入参与结果模型放在 services 层，使 pages 层（统计页 / 详情页）
/// 与 providers 层（[aaMemberDetailProvider]）都能引用，保持页面间通过
/// 路由参数解耦、不互相 import。
library;

import '../../data/models.dart';
import 'aa_statistics_service.dart';

/// 打开成员账单详情页的入参。
///
/// 只携带定位所需的最小信息（账本 + 参与人），成员名/本人标记随路由参数
/// 一并传入，用于数据加载期间头部即可渲染，不依赖详情数据先就绪。
class AaMemberDetailArgs {
  /// 所属账本 id（与分摊统计页一致）。
  final int ledgerId;

  /// 参与人标识（真实成员 userId 或虚拟用户 syncId）。
  final String participantId;

  /// 参与人显示名（真实成员 displayName/email、虚拟用户 name）。
  final String displayName;

  /// 是否本人；UI 据此渲染「(我)」共享后缀与本地头像。
  final bool isSelf;

  const AaMemberDetailArgs({
    required this.ledgerId,
    required this.participantId,
    required this.displayName,
    this.isSelf = false,
  });
}

/// 单笔账单中某参与人的分摊项。
class AaMemberSplit {
  /// 参与人标识（userId 或虚拟用户 syncId）。
  final String participantId;

  /// 参与人显示名。
  final String displayName;

  /// 应摊金额（元，展示口径）。
  final double amount;

  /// 是否本人；UI 据此追加「(我)」后缀。
  final bool isSelf;

  const AaMemberSplit({
    required this.participantId,
    required this.displayName,
    required this.amount,
    this.isSelf = false,
  });
}

/// 成员账单详情中的单笔 AA 账单（该成员作为支出人）。
class AaMemberBill {
  /// 交易本体（取分类/备注/时间等展示字段）。
  final Transaction tx;

  /// 交易分类（用于图标与分类名展示，与首页列表同源）。
  final Category? category;

  /// 分摊方式（人均 / 指定金额），UI 据此渲染方式徽标。
  final AaMode mode;

  /// 账单实付金额（元）。
  final double totalAmount;

  /// 该成员在本笔账单中的应摊金额（元）；指定金额未填本人时兜底 0。
  final double myShare;

  /// 支出人显示名（本页按支出人维度汇总，通常即成员本人）。
  final String payerName;

  /// 分摊明细（参与人 → 应摊金额）。
  final List<AaMemberSplit> splits;

  const AaMemberBill({
    required this.tx,
    this.category,
    required this.mode,
    required this.totalAmount,
    required this.myShare,
    required this.payerName,
    required this.splits,
  });
}

/// 成员账单详情页数据源（按支出人维度汇总）。
class AaMemberDetailData {
  /// 账本名（头部副标题）。
  final String ledgerName;

  /// 成员汇总（实付/应摊/净额），与分摊详情表口径一致。
  final AaParticipantSummary member;

  /// 该成员作为支出人的 AA 账单列表（按时间倒序）。
  final List<AaMemberBill> bills;

  const AaMemberDetailData({
    required this.ledgerName,
    required this.member,
    required this.bills,
  });
}
