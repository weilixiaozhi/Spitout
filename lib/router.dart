import 'package:flutter/material.dart';

import 'widgets/app_route.dart';
import 'pages/category/category_manage_page.dart';
import 'pages/statistics/aa_edit_page.dart';
import 'pages/statistics/aa_member_detail_page.dart';
import 'pages/statistics/aa_statistics_page.dart';
import 'core/router/routes.dart';
import 'services/statistics/aa_edit_models.dart';
import 'services/statistics/aa_member_detail_models.dart';

/// 全局唯一路由解析层。
///
/// 设计意图：所有按名称跳转的页面统一在此映射，页面之间不互相 import；
/// 本文件是唯一允许 import 具体页面（且属于 pages 层）的路由层文件。
/// 所有路由均通过 [appPageRoute] 创建，自动应用全局页面转场动画。
Route<dynamic>? appRoute(RouteSettings settings) {
  switch (settings.name) {
    case Routes.categoryManage:
      return appPageRoute<void>(
        builder: (_) => const CategoryManagePage(),
        settings: settings,
      );
    case Routes.aaStatistics:
      // 账本 id 由调用方(账本编辑页)经 arguments 传入,遵循"从哪里进入
      // 就是哪个账本";缺失/类型不符(如新建态)时传 null,统计页按空数据渲染。
      final args = settings.arguments;
      return appPageRoute<void>(
        builder: (_) => AaStatisticsPage(ledgerId: args is int ? args : null),
        settings: settings,
      );
    case Routes.aaEdit:
      // 参数由调用方(记账编辑器)经 arguments 传入;缺失/类型不符视为
      // 非法跳转,返回 null 走调用方回退,避免白屏。
      // 退场固定为下滑动画(见 [aaSlidePageRoute]):AA 页通常在记账编辑器
      // sheet 之上 push,保存时 sheet 同步下滑收起,两者同向视觉统一。
      final args = settings.arguments;
      if (args is! AaEditPageArgs) return null;
      return aaSlidePageRoute<AaEditResult?>(
        builder: (_) => AaEditPage(args: args),
        settings: settings,
      );
    case Routes.aaMemberDetail:
      // 参数由分摊统计页经 arguments 传入；缺失/类型不符视为非法跳转，
      // 返回 null 走调用方回退，避免白屏。
      final args = settings.arguments;
      if (args is! AaMemberDetailArgs) return null;
      return appPageRoute<void>(
        builder: (_) => AaMemberDetailPage(args: args),
        settings: settings,
      );
    default:
      return null;
  }
}
