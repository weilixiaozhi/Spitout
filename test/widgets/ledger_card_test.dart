/// LedgerCard 共享账本角标图标测试。
///
/// 锁定:共享账本角标使用 AppIcons.people(与成员管理入口一致),
/// 不再使用握手图标(LucideIcons.heartHandshake),并带成员数文本。
library;

import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/ledger_card.dart';

/// 构造账本展示项 — storageMode 'local' 避免卡片状态图标分支
/// 触发 activeCloudConfigProvider 依赖,收窄测试面。
LedgerDisplayItem _ledger({required bool isShared, int memberCount = 1}) =>
    LedgerDisplayItem(
      id: 1,
      name: '测试账本',
      currency: 'CNY',
      transactionCount: 3,
      expenseTotal: 12.5,
      lastUpdated: DateTime(2026, 1, 1),
      isShared: isShared,
      memberCount: memberCount,
      storageMode: 'local',
    );

/// 构造指定 storageMode 的账本展示项(供状态图标三态测试使用)。
LedgerDisplayItem _display({required String storageMode}) => LedgerDisplayItem(
      id: 99,
      name: '图标测试账本',
      currency: 'CNY',
      transactionCount: 0,
      expenseTotal: 0,
      lastUpdated: DateTime(2026, 1, 1),
      storageMode: storageMode,
    );

Future<void> _pump(
  WidgetTester tester,
  LedgerDisplayItem ledger, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // 同步状态桩:notConfigured,避免真实 SyncService 触发 IO
        syncStatusProvider.overrideWith(
          (ref, ledgerId) async => const SyncStatus(
            diff: SyncDiff.notConfigured,
            localCount: 0,
            localFingerprint: '',
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LedgerCard(ledger: ledger)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('共享账本角标使用 people 图标 + 成员数,不再用握手图标',
      (tester) async {
    await _pump(tester, _ledger(isShared: true, memberCount: 2));

    expect(find.byIcon(AppIcons.people), findsOneWidget);
    expect(find.byIcon(LucideIcons.heartHandshake), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('非共享账本不渲染成员角标', (tester) async {
    await _pump(tester, _ledger(isShared: false));

    expect(find.byIcon(AppIcons.people), findsNothing);
    expect(find.byIcon(LucideIcons.heartHandshake), findsNothing);
  });

  group('状态图标(方案B重构)', () {
    testWidgets('云端账本恒为云形:即便激活 webdav 也不显示 storage 备份图标',
        (tester) async {
      final ledger = _display(storageMode: 'cloud');
      await _pump(
        tester,
        ledger,
        overrides: [
          activeCloudConfigProvider.overrideWith(
            (ref) async => const CloudServiceConfig(
              type: CloudBackendType.webdav,
              name: 'wd',
              webdavUrl: 'https://x',
              webdavUsername: 'u',
              webdavPassword: 'p',
            ),
          ),
        ],
      );
      // 核心断言:云端账本不再按后端形态显示 database 图标
      expect(find.byIcon(AppIcons.storage), findsNothing);
      // 云形图标必然存在(头部头像 + 状态图标各一个)
      expect(find.byIcon(AppIcons.cloudQueue), findsWidgets);
    });

    testWidgets('本地账本+快照型后端(webdav)激活:显示 database 备份图标',
        (tester) async {
      final ledger = _display(storageMode: 'local');
      await _pump(
        tester,
        ledger,
        overrides: [
          activeCloudConfigProvider.overrideWith(
            (ref) async => const CloudServiceConfig(
              type: CloudBackendType.webdav,
              name: 'wd',
              webdavUrl: 'https://x',
              webdavUsername: 'u',
              webdavPassword: 'p',
            ),
          ),
        ],
      );
      expect(find.byIcon(AppIcons.storage), findsOneWidget);
      expect(find.byIcon(AppIcons.localStorage), findsNothing);
    });

    testWidgets('本地账本+纯本地激活:显示灰色硬盘图标', (tester) async {
      final ledger = _display(storageMode: 'local');
      await _pump(
        tester,
        ledger,
        overrides: [
          activeCloudConfigProvider.overrideWith(
            (ref) async => CloudServiceConfig.localStorage(),
          ),
        ],
      );
      expect(find.byIcon(AppIcons.localStorage), findsOneWidget);
      expect(find.byIcon(AppIcons.storage), findsNothing);
    });
  });
}
