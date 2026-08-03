import 'package:flutter/material.dart';

import 'pages/category/category_manage_page.dart';
import 'pages/settlement/aa_edit_page.dart';
import 'pages/settlement/aa_settlement_page.dart';
import 'routes.dart';
import 'services/settlement/aa_edit_models.dart';

/// 全局唯一路由解析层。
///
/// 设计意图：所有按名称跳转的页面统一在此映射，页面之间不互相 import；
/// 本文件是唯一允许 import 具体页面（且属于 pages 层）的路由层文件。
Route<dynamic>? appRoute(RouteSettings settings) {
  switch (settings.name) {
    case Routes.categoryManage:
      return MaterialPageRoute<void>(
        builder: (_) => const CategoryManagePage(),
        settings: settings,
      );
    case Routes.aaSettlement:
      return MaterialPageRoute<void>(
        builder: (_) => const AaSettlementPage(),
        settings: settings,
      );
    case Routes.aaEdit:
      // 参数由调用方(记账编辑器)经 arguments 传入;缺失/类型不符视为
      // 非法跳转,返回 null 走调用方回退,避免白屏。
      final args = settings.arguments;
      if (args is! AaEditPageArgs) return null;
      return MaterialPageRoute<AaEditResult?>(
        builder: (_) => AaEditPage(args: args),
        settings: settings,
      );
    default:
      return null;
  }
}
