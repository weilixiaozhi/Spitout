/// Mine 页宿主可见性测试。
///
/// 验证 2026-07-26 云同步页归并改造后，宿主页（Mine）的「云同步与备份」分组：
///   1. 渲染合并后的统一入口 [CloudServiceEntryTile]（原「云服务」与「同步状态」
///      两个 tile 合并为一，标题 "备份与云同步配置" 仅应出现一次，不复存在重复入口）；
///   2. 分组内其余同类 tile（明细导入导出 / 配置导入导出 / 数据清理）均存在；
///   3. 入口在确定的同步状态下能正确反映文案（host 上下文集成）。
///
/// 测试栈：flutter_test + flutter_riverpod。通过 override `syncStatusProvider`
/// 提供确定的同步状态，避免依赖数据库 / 网络。其余 provider（avatar /
/// displayName / ledgerId）均使用默认安全值，MinePageHeader 的异步头像加载在
/// 测试环境下读取不到文件即返回 null，不会抛错。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/mine_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/cloud_service_entry_tile.dart';

/// 构造一条确定状态的 [SyncStatus]，用于驱动入口 tile 的 9 态文案。
SyncStatus _st(SyncDiff diff, {int localCount = 0}) => SyncStatus(
      diff: diff,
      localCount: localCount,
      localFingerprint: 'fingerprint',
    );

/// 挂载 MinePage。
///
/// [status] 为非 null 时 `syncStatusProvider` 立即返回该状态；
/// [hang] 为 true 时 provider 永不完成，模拟首屏未加载态（本文件未使用，
/// 仅与组件测试保持同构以便将来扩展）。
Future<void> _pumpMinePage(
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
        home: const MinePage(),
      ),
    ),
  );
  // 不用 pumpAndSettle：MinePageHeader 在头像异步加载完成前会渲染一个
  // CircularProgressIndicator（无限动画），会让 pumpAndSettle 永远超时。
  // 改用有界 pump：第一帧构建；后续帧让 entry tile 的 async provider 与
  // 头像加载的 setState 完成解析即可，断言不依赖 spinner 是否消失。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Mine 页「云同步与备份」分组渲染合并入口 + 同类 tile 齐全',
    (tester) async {
      await _pumpMinePage(tester, status: _st(SyncDiff.notConfigured));

      // 合并后的统一入口存在且唯一：原「云服务」与「同步状态」两个 tile 已合并，
      // 标题 "备份与云同步配置" 不应再出现第二处（验证归并、无重复入口）。
      expect(find.byType(CloudServiceEntryTile), findsOneWidget);
      expect(find.text('备份与云同步配置'), findsOneWidget);

      // 分组内其余同类 tile 均存在（这些能力未随归并而丢失）。
      expect(find.text('明细导入导出'), findsOneWidget);
      expect(find.text('配置导入导出'), findsOneWidget);
      expect(find.text('数据清理'), findsOneWidget);
    },
  );

  testWidgets(
    'Mine 页入口在 notConfigured 态显示「未配置云端」且已解析（无加载态）',
    (tester) async {
      await _pumpMinePage(tester, status: _st(SyncDiff.notConfigured));

      expect(find.byType(CloudServiceEntryTile), findsOneWidget);
      // 状态已解析，应显示 notConfigured 对应文案
      expect(find.text('未配置云端'), findsOneWidget);
      // 不应再残留首屏加载文案
      expect(find.text('加载中…'), findsNothing);
    },
  );
}
