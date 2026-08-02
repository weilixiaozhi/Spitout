// CheckUpdateTile 组件测试。
//
// 覆盖：
//   1. 初始渲染（标题 + 当前版本副标题）；
//   2. 点击「检查更新」先弹加载框，再按注入的 checker 结果弹出对应 UpdateDialog；
//      借此验证 hasUpdate / latest / unknown 三态的端到端联动，
//      且全程不依赖真实网络或 GitHub（私有仓库降级路径也被验证）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_isolation.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/widgets/check_update_tile.dart';

/// 挂载入口组件。[check] 为注入的版本检查桩（必传）。
Future<void> _pump(
  WidgetTester tester,
  Future<AppUpdateInfo> Function() check,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: CheckUpdateTile(check: check)),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 固定当前版本，使副标题断言稳定。
    PackageInfo.setMockInitialValues(
      appName: 'spitout',
      packageName: 'com.example.spitout',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    resetGlobalTestState();
  });

  testWidgets('初始渲染：标题 + 当前版本副标题', (tester) async {
    // 初始渲染不会触发检查，传一个不会真正执行的桩函数满足必传签名。
    await _pump(tester, () async => _latestInfo());

    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('当前版本 v1.0.0'), findsOneWidget);
  });

  testWidgets('点击 → 有新版本：先弹加载框，再弹结果框', (tester) async {
    final completer = Completer<AppUpdateInfo>();
    await _pump(tester, () => completer.future);

    await tester.tap(find.text('检查更新'));
    // 仅 pump 一次，让加载框出现（避免 pumpAndSettle 因 spinner 动画超时）。
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 注入「有新版本」结果，触发结果弹窗。
    completer.complete(
      AppUpdateInfo(
        status: UpdateStatus.hasUpdate,
        hasUpdate: true,
        latestVersion: '2.0.0',
        releaseUrl: 'https://github.com/x/y/releases/tag/v2.0.0',
        currentVersion: '1.0.0',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('前往下载'), findsOneWidget);
    // 加载框已被关闭，不应残留 spinner。
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('点击 → 已是最新：弹结果框（已是最新版本/好的）', (tester) async {
    final completer = Completer<AppUpdateInfo>();
    await _pump(tester, () => completer.future);

    await tester.tap(find.text('检查更新'));
    await tester.pump();

    completer.complete(
      AppUpdateInfo(
        status: UpdateStatus.latest,
        hasUpdate: false,
        currentVersion: '1.0.0',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已是最新版本'), findsOneWidget);
    expect(find.text('好的'), findsOneWidget);
  });

  testWidgets('点击 → 无法检测：弹结果框（无法自动检查更新/前往 GitHub 查看）',
      (tester) async {
    final completer = Completer<AppUpdateInfo>();
    await _pump(tester, () => completer.future);

    await tester.tap(find.text('检查更新'));
    await tester.pump();

    // 模拟私有仓库/网络异常降级结果。
    completer.complete(
      AppUpdateInfo(
        status: UpdateStatus.unknown,
        hasUpdate: false,
        releaseUrl: 'https://github.com/x/y/releases',
        currentVersion: '1.0.0',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法自动检查更新'), findsOneWidget);
    expect(find.text('前往 GitHub 查看'), findsOneWidget);
  });
}

/// 构造「已是最新」桩结果，供不需要点击检查的用例复用。
AppUpdateInfo _latestInfo() => AppUpdateInfo(
      status: UpdateStatus.latest,
      hasUpdate: false,
      currentVersion: '1.0.0',
    );
