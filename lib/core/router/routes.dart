/// 全局路由名常量表。
///
/// 设计意图：将页面跳转从「页面直接 import 目标页」解耦为「按路由名跳转」，
/// 由 [router.dart] 这一唯一路由层负责名称 → 页面实例的映射。
/// 页面之间因此不存在编译期 import 环，满足 pages → widgets 单向依赖。
///
/// 约束：本文件不得 import 任何页面/项目文件，仅存放纯常量。
class Routes {
  Routes._();

  /// 分类管理页
  static const String categoryManage = '/category/manage';

  /// AA 分摊统计页
  static const String aaStatistics = '/statistics/aa';

  /// AA 分摊编辑页(纯选择器,参数经 RouteSettings.arguments 传
  /// [AaEditPageArgs],返回 [AaEditResult?],null = 取消)
  static const String aaEdit = '/statistics/aa/edit';

  /// AA 分摊统计-成员账单详情页(按支出人维度汇总,
  /// 参数经 RouteSettings.arguments 传 [AaMemberDetailArgs])
  static const String aaMemberDetail = '/statistics/aa/member-detail';
}
