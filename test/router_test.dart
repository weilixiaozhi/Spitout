/// 全局路由层（router.dart）单元测试。
///
/// 覆盖重构核心：页面不再互相 import，统一通过 [Routes] 名称
/// 交给 appRoute 解析，形成唯一「名称 → 页面」映射层。
/// 验证内容：
///   1. 分类管理路由名 → 返回非空 MaterialPageRoute，settings 名称正确；
///   2. 未知路由名 → 返回 null（由调用方走回退分支）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/router.dart';
import 'package:spitout/routes.dart';
import 'package:spitout/services/settlement/aa_edit_models.dart';
import 'package:spitout/services/settlement/aa_settlement_service.dart';

void main() {
  group('appRoute 路由解析', () {
    test('分类管理路由名映射到 CategoryManagePage', () {
      final route = appRoute(const RouteSettings(name: Routes.categoryManage));

      expect(route, isNotNull, reason: '已知路由名必须解析出 Route');
      expect(route!.settings.name, Routes.categoryManage,
          reason: 'Route 应保留原 settings.name');
      expect(route, isA<MaterialPageRoute<dynamic>>(),
          reason: '应返回 MaterialPageRoute');
    });

    test('AA 结算页 / 分摊编辑页路由名可解析', () {
      final settlement = appRoute(const RouteSettings(name: Routes.aaSettlement));
      expect(settlement, isNotNull, reason: '分摊结算页路由必须注册');
      expect(settlement, isA<MaterialPageRoute<dynamic>>());

      // 分摊编辑页为压栈式全屏页面,必须携带 AaEditPageArgs 入参,
      // 缺失参数视为非法跳转返回 null(由调用方走回退,避免白屏)。
      final edit = appRoute(RouteSettings(
        name: Routes.aaEdit,
        arguments: AaEditPageArgs(
          ledgerId: 1,
          amount: 100,
          currencyCode: 'CNY',
          categoryName: '餐饮',
          date: DateTime(2026, 8, 3),
          mode: AaMode.custom,
        ),
      ));
      expect(edit, isNotNull, reason: '携带合法入参的分摊编辑页路由必须解析');
      expect(edit, isA<MaterialPageRoute<dynamic>>());

      final editNoArgs = appRoute(const RouteSettings(name: Routes.aaEdit));
      expect(editNoArgs, isNull, reason: '缺失入参的分摊编辑页路由应返回 null');
    });

    test('未知路由名返回 null（由 onGenerateRoute 回退默认分支）', () {
      final route = appRoute(const RouteSettings(name: '/unknown/xxx'));
      expect(route, isNull, reason: '未注册的路由名不应解析出 Route');
    });
  });
}
