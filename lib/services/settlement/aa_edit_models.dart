/// AA 分摊编辑页(AaEditPage)的入参 / 回传契约与参与人选项模型。
///
/// 设计意图:AaEditPage 是纯选择器(不写库)。编辑器(widgets 层)
/// 跳转前构造 [AaEditPageArgs],页面 pop 时返回 [AaEditResult],由编辑器
/// 一次性落库。契约放在 services 层,使 widgets 层编辑器、
/// providers 层与 pages 层编辑页都能引用,不破坏 pages → widgets 单向依赖。
library;

import 'aa_settlement_service.dart';

/// 参与人选项(真实成员或虚拟用户)。
///
/// [id] 参与人标识:真实成员取 userId,虚拟用户取 syncId(无 syncId 时
/// 兜底 `vu_<本地id>`,与统计 Provider 的口径一致)。
class AaParticipantOption {
  /// 参与人标识(userId 或虚拟用户 syncId)。
  final String id;

  /// 显示名(真实成员取 displayName/email,虚拟用户取 name)。
  final String name;

  /// 是否虚拟用户。
  final bool isVirtual;

  const AaParticipantOption({
    required this.id,
    required this.name,
    required this.isVirtual,
  });
}

/// 打开 AaEditPage 的入参(主体信息只读展示 + 分摊编辑初值)。
class AaEditPageArgs {
  /// 所属账本 id(用于查询参与人与虚拟用户)。
  final int ledgerId;

  /// 交易金额(交易币种口径,只读展示)。
  final double amount;

  /// 交易币种代码(只读展示);null 时由页面回退账本本位币。
  final String? currencyCode;

  /// 分类显示名(只读展示)。
  final String categoryName;

  /// 分类 Lucide 图标名(只读展示,供主体卡顶部 icon 解析);空时用兜底图标。
  final String? categoryIconName;

  /// 交易发生时间(只读展示)。
  final DateTime date;

  /// 分摊方式初值(新建默认人均;编辑回填交易当前值)。
  final AaMode mode;

  /// 支出人初值(参与人标识);null 时由页面取参与人列表首个兜底。
  final String? paidByUserId;

  /// 参与人初值;null = 全部成员(运行时展开,不落具体名单)。
  final List<String>? participantIds;

  /// 指定分摊金额初值(key=参与人标识,value=金额字符串);null = 未填写。
  final Map<String, String>? splits;

  const AaEditPageArgs({
    required this.ledgerId,
    required this.amount,
    required this.currencyCode,
    required this.categoryName,
    this.categoryIconName,
    required this.date,
    required this.mode,
    this.paidByUserId,
    this.participantIds,
    this.splits,
  });
}

/// AaEditPage pop 回传的结果;pop null 视为取消(编辑器保持开启、不落库)。
class AaEditResult {
  /// 支出人标识(userId 或虚拟用户 syncId)。
  final String? paidByUserId;

  /// 分摊方式数据库列值:0=人均,2=指定(与 Transactions.aaMode 对齐)。
  final int aaMode;

  /// 参与人标识列表;null = 全部成员(运行时展开)。
  final List<String>? aaParticipants;

  /// 指定分摊金额(key=参与人标识,value=金额字符串);人均模式为 null。
  final Map<String, String>? aaSplits;

  const AaEditResult({
    required this.paidByUserId,
    required this.aaMode,
    required this.aaParticipants,
    required this.aaSplits,
  });
}
