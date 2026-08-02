import 'package:flutter/material.dart';

import 'pages/category/category_manage_page.dart';
import 'routes.dart';

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
    default:
      return null;
  }
}
