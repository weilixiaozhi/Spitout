/// Mine 页「备份与云同步配置」统一入口（CloudServiceEntryTile）组件测试。
///
/// 覆盖需求 1 的 9 态映射：8 种 SyncDiff + 首屏未加载态，
/// 各态断言 leading 图标、subtitle 文案与 trailing 形态。
///
/// 测试栈：flutter_test + flutter_riverpod。通过 override
/// `syncStatusProvider`（FutureProvider.family）提供确定的同步状态，
/// 避免依赖数据库 / 网络；`lastSyncStatusProvider` 默认 null 无需 override。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/cloud_service_entry_tile.dart';

/// 构造一条确定状态的 SyncStatus（localCount 固定 42 便于断言参数化文案）。
SyncStatus _st(SyncDiff diff, {int localCount = 42}) => SyncStatus(
      diff: diff,
      localCount: localCount,
      localFingerprint: 'fingerprint',
    );

/// 挂载入口组件。
///
/// [status] 为非 null 时 `syncStatusProvider` 立即返回该状态；
/// [hang] 为 true 时 provider 永不完成，模拟首屏未加载态。
Future<void> _pumpTile(
  WidgetTester tester, {
  SyncStatus? status,
  bool hang = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncStatusProvider.overrideWith((ref, ledgerId) {
          if (hang) return Completer<SyncStatus>().future;
          return Future.value(status!);
        }),
      ],
      child: MaterialApp(
        // 测试环境默认 locale 为 en，强制 zh 以渲染中文文案
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CloudServiceEntryTile(onTap: () {})),
      ),
    ),
  );
  // 不用 pumpAndSettle：spinner 动画与永不完成的 Future 都会导致超时。
  // 两次 pump 足以让 Future.value 完成并重建。
  await tester.pump();
  await tester.pump();
}

/// 断言 leading 渲染了指定图标（排除 trailing 箭头图标的干扰）。
void _expectLeadingIcon(IconData icon) {
  expect(
    find.byWidgetPredicate((w) => w is Icon && w.icon == icon),
    findsOneWidget,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('第 9 态：首屏未加载 → 加载中文案 + spinner', (tester) async {
    await _pumpTile(tester, hang: true);

    _expectLeadingIcon(AppIcons.cloudQueue);
    expect(find.text('加载中…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('notConfigured（含 local 模式）→ cloudOff + 未配置云端',
      (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.notConfigured));

    _expectLeadingIcon(AppIcons.cloudOff);
    expect(find.text('未配置云端'), findsOneWidget);
    // 有状态值后 trailing 恢复为导航箭头
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('notLoggedIn → lock + 未登录', (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.notLoggedIn));

    _expectLeadingIcon(AppIcons.lock);
    expect(find.text('未登录'), findsOneWidget);
  });

  testWidgets('noRemote → cloudQueue + 云端暂无数据', (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.noRemote));

    _expectLeadingIcon(AppIcons.cloudQueue);
    expect(find.text('云端暂无数据'), findsOneWidget);
  });

  testWidgets('inSync → verified + 已同步（带 localCount）', (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.inSync));

    _expectLeadingIcon(AppIcons.verified);
    expect(find.text('已同步 (本地42条)'), findsOneWidget);
  });

  testWidgets('localNewer → upload + 本地有更新（带 localCount）',
      (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.localNewer));

    _expectLeadingIcon(AppIcons.upload);
    expect(find.text('本地有更新 (本地42条, 建议上传)'), findsOneWidget);
  });

  testWidgets('cloudNewer → download + 云端有更新', (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.cloudNewer));

    _expectLeadingIcon(AppIcons.download);
    expect(find.text('云端有更新 (建议下载同步)'), findsOneWidget);
  });

  testWidgets('different → syncDifferent + 差异文案', (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.different));

    _expectLeadingIcon(AppIcons.syncDifferent);
    expect(find.text('本地与云端有差异，建议下载对比'), findsOneWidget);
  });

  testWidgets('error → error 图标 + 状态获取失败', (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.error));

    _expectLeadingIcon(AppIcons.error);
    expect(find.text('状态获取失败'), findsOneWidget);
  });

  testWidgets('标题为「备份与云同步配置」且入口可点击', (tester) async {
    await _pumpTile(tester, status: _st(SyncDiff.inSync));

    expect(find.text('备份与云同步配置'), findsOneWidget);
    // 入口合并后是进入配置页的唯一路径，必须始终可点（InkWell 有回调）。
    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNotNull);
  });
}
