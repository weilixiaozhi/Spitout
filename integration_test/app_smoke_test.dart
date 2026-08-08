// 设备级集成测试（integration_test）：在真实设备/桌面端跑完整应用冒烟。
//
// 与 test/ 下的 flutter_test 单测不同，本测试走真实渲染管线与真实平台通道，
// 验证应用能启动、主页渲染、底部导航切换。运行方式：
//   flutter test integration_test -d <device>
// （本机 CI 无设备时该目录不参与 `flutter test` 主流程，互不影响。）

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:spitout/app.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/pages/main/home_page.dart';
import 'package:spitout/pages/main/mine_page.dart';
import 'package:spitout/providers/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('应用启动冒烟：主页渲染 + 底部导航切换', (tester) async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // 设备级冒烟不触网：默认无云配置 → LocalOnly，此处显式声明无云后端。
          spitoutCloudProviderInstance.overrideWith((ref) async => null),
        ],
        child: const SpitoutApp(),
      ),
    );

    // 等异步初始化（seed / 启动同步编排）落定，避免 pumpAndSettle 被长任务卡住。
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // 首页（明细）渲染
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(SpitoutBottomBar), findsOneWidget);

    // 切到「我的」Tab
    await tester.tap(find.text('我的'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MinePage), findsOneWidget);

    // 切回「明细」Tab
    await tester.tap(find.text('明细'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomePage), findsOneWidget);
  });
}
