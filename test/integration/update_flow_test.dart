// 检查更新流程的集成级测试（flutter_test，可在 CI 无设备环境运行）。
//
// 与单测不同，这里把多个组件组合起来做端到端验证：
// CheckUpdateTile（入口）→ 加载框 → UpdateDialog（结果弹窗），
// 并覆盖三种状态在与 AppListTile / l10n / SectionCard 组合下的真实渲染，
// 确保「检查更新」整条链路无破坏。
//
// 说明：设备级 integration_test 包因与本项目 Dart 3.6.0 版本冲突未引入，
// 改为本 flutter_test 集成用例，同样覆盖端到端行为且可被 CI 稳定运行。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_isolation.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
// SectionCard 由 widgets/widgets.dart 导出，CheckUpdateTile 由 widgets/widgets.dart 导出。
import 'package:spitout/widgets/widgets.dart';

/// 用真实页面骨架包裹入口：SectionCard + CheckUpdateTile（与 MinePage 一致）。
Future<void> _pumpFlow(
  WidgetTester tester,
  Future<AppUpdateInfo> Function() check, {
  Locale locale = const Locale('zh'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SectionCard(
          margin: EdgeInsets.zero,
          child: CheckUpdateTile(check: check),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'spitout',
      packageName: 'com.example.spitout',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    resetGlobalTestState();
  });

  testWidgets('组合渲染：SectionCard + CheckUpdateTile 正常显示且可点击',
      (tester) async {
    final completer = Completer<AppUpdateInfo>();
    await _pumpFlow(tester, () => completer.future);

    // 入口与版本副标题渲染正常。
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('当前版本 v1.0.0'), findsOneWidget);

    // 点击触发检查：先弹加载框。
    await tester.tap(find.text('检查更新'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 注入「有新版本」结果，端到端弹出结果弹窗。
    completer.complete(
      AppUpdateInfo(
        status: UpdateStatus.hasUpdate,
        latestVersion: '2.0.0',
        releaseUrl: 'https://github.com/x/y/releases/tag/v2.0.0',
        currentVersion: '1.0.0',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('前往下载'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('英文 locale 下文案同样正确渲染', (tester) async {
    final completer = Completer<AppUpdateInfo>();
    await _pumpFlow(tester, () => completer.future,
        locale: const Locale('en'));

    expect(find.text('Check for Updates'), findsOneWidget);

    await tester.tap(find.text('Check for Updates'));
    await tester.pump();
    completer.complete(
      AppUpdateInfo(
        status: UpdateStatus.latest,
        currentVersion: '1.0.0',
      ),
    );
    await tester.pumpAndSettle();

    // 英文「已是最新」标题 + 单按钮 OK。
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}
