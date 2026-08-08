// 孤儿数据清理页测试：空态渲染 → debug 塞入测试孤儿数据 → 扫描报告出现
// 记录 → 全选清理 → 恢复空态（真实 SQLite 全链路）。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/maintenance/orphan_cleanup_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/providers.dart';

import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async => db.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OrphanCleanupPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('空态 → 塞入孤儿数据 → 扫描报告 → 全选清理 → 恢复空态', (tester) async {
    await pumpPage(tester);

    // 空库：显示空态文案
    expect(find.text('本地数据干净,未发现孤儿数据'), findsOneWidget);

    // 点击 debug 塞数据按钮（kDebugMode 下可见）
    await tester.tap(find.byTooltip('Seed orphan data (debug)'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // 报告出现记录：空态消失，全选/清理按钮可用
    expect(find.text('本地数据干净,未发现孤儿数据'), findsNothing);
    expect(find.text('全选'), findsWidgets);
    expect(find.text('清理已选'), findsOneWidget);

    // 底部栏全选（页面/分组各有一个，取最后一个）→ 清理已选 → 回到空态
    await tester.tap(find.text('全选').last);
    await tester.pump();
    await tester.tap(find.text('清理已选'));
    await tester.pump();
    // 二次确认对话框
    expect(find.text('确认清理'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('本地数据干净,未发现孤儿数据'), findsOneWidget);
  });
}
