// UpdateDialog 三态渲染测试。
//
// 覆盖：hasUpdate / latest / unknown 三种状态各自的标题、正文与按钮排版
// （latest 只有单个「好的」主按钮；unknown 才是「前往 GitHub 查看」+「取消」）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/widgets/update_dialog.dart';

/// 构造确定状态的 [AppUpdateInfo]（releaseUrl 给个非兜底值便于区分）。
AppUpdateInfo _info(
  UpdateStatus status, {
  String? latestVersion,
  String releaseUrl = 'https://github.com/x/y/releases',
}) =>
    AppUpdateInfo(
      status: status,
      hasUpdate: status == UpdateStatus.hasUpdate,
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      currentVersion: '1.0.0',
    );

/// 挂载弹窗。强制 zh 以渲染中文文案。
Future<void> _pump(WidgetTester tester, AppUpdateInfo info) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UpdateDialog(
        info: info,
        onOpenGitHub: () {},
        onDismiss: () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hasUpdate → 标题/版本对比/下载与稍后再说', (tester) async {
    await _pump(tester, _info(UpdateStatus.hasUpdate, latestVersion: '2.0.0'));

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('最新版本 v2.0.0'), findsOneWidget);
    // 主行动：醒目的「前往下载」。
    expect(find.text('前往下载'), findsOneWidget);
    // 次要行动：不抢戏的「稍后再说」。
    expect(find.text('稍后再说'), findsOneWidget);
    // 不应出现诡异的「取消」。
    expect(find.text('取消'), findsNothing);
  });

  testWidgets('latest → 标题/版本/单按钮「好的」', (tester) async {
    await _pump(tester, _info(UpdateStatus.latest));

    expect(find.text('已是最新版本'), findsOneWidget);
    expect(find.text('当前已是最新版本 v1.0.0'), findsOneWidget);
    expect(find.text('好的'), findsOneWidget);
    // 已是最新不应再出现「取消」或「稍后再说」。
    expect(find.text('取消'), findsNothing);
    expect(find.text('稍后再说'), findsNothing);
  });

  testWidgets('unknown → 标题/引导文案/前往 GitHub 查看 + 取消', (tester) async {
    await _pump(tester, _info(UpdateStatus.unknown));

    expect(find.text('无法自动检查更新'), findsOneWidget);
    expect(find.text('无法获取版本信息，可前往 GitHub 查看最新版本'),
        findsOneWidget);
    expect(find.text('前往 GitHub 查看'), findsOneWidget);
    // unknown 态才允许「取消」（私有仓库/网络异常降级）。
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('点击「前往下载」主按钮 → 触发 onOpenGitHub',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UpdateDialog(
          info: _info(UpdateStatus.hasUpdate, latestVersion: '2.0.0'),
          onOpenGitHub: () => opened = true,
          onDismiss: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('前往下载'));
    expect(opened, isTrue);
  });

  testWidgets('点击「好的」主按钮 → 触发 onDismiss', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UpdateDialog(
          info: _info(UpdateStatus.latest),
          onOpenGitHub: () {},
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('好的'));
    expect(dismissed, isTrue);
  });
}
