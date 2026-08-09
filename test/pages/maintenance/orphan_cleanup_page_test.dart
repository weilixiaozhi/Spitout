// 孤儿数据清理页测试：空态渲染 → debug 塞入测试孤儿数据 → 扫描报告出现
// 记录 → 全选清理 → 恢复空态（真实 SQLite 全链路）。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/maintenance/orphan_cleanup_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/maintenance/orphan_cleaner.dart';
import 'package:spitout/services/maintenance/orphan_record.dart';

import '../../helpers/test_isolation.dart';

class _MockCleaner extends Mock implements OrphanCleaner {}

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

  /// 点击 debug 按钮塞入测试孤儿数据并等待重扫完成。
  Future<void> seedOrphans(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Seed orphan data (debug)'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
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

  testWidgets('单条删除：确认后清理并提示', (tester) async {
    await pumpPage(tester);
    await seedOrphans(tester);

    // 任选一条非 tx 记录删除
    await tester.tap(find.byTooltip('删除此项').first);
    await tester.pumpAndSettle();
    expect(find.text('确认清理'), findsOneWidget);
    expect(find.textContaining('确定清理'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('已清理 1 项'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // toast 定时器
  });

  testWidgets('分组全选与取消全选切换', (tester) async {
    await pumpPage(tester);
    await seedOrphans(tester);

    // 底部栏「全选」→ 全选后切换为「取消全选」并显示计数
    await tester.tap(find.text('全选').last);
    await tester.pump();
    expect(find.text('取消全选'), findsWidgets);
    expect(find.textContaining('已选 '), findsOneWidget);
    expect(find.text('清理已选'), findsOneWidget);

    // 再点底部「取消全选」→ 计数归零
    await tester.tap(find.text('取消全选').last);
    await tester.pump();
    expect(find.text('已选 0 项'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('无账本交易：亚组渲染并可批量移动到目标账本', (tester) async {
    await repo.createLedger(name: '目标账本', currency: 'CNY');
    await pumpPage(tester);
    await seedOrphans(tester);

    // 已删账本亚组在列表底部，先滚动到可见再断言
    await tester.scrollUntilVisible(
      find.textContaining('已删账本 #').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('已删账本 #'), findsWidgets);

    // 亚组头部「全选」→ 底部出现「移动到账本」
    final subgroupRow = find
        .ancestor(
          of: find.textContaining('已删账本 #').first,
          matching: find.byType(Row),
        )
        .first;
    await tester.tap(find.descendant(
      of: subgroupRow,
      matching: find.text('全选'),
    ));
    await tester.pump();
    expect(find.text('移动到账本'), findsOneWidget);

    // 选择目标账本 → 批量迁移成功提示
    await tester.tap(find.text('移动到账本'));
    await tester.pumpAndSettle();
    expect(find.text('选择账本'), findsOneWidget);
    await tester.tap(find.text('目标账本'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('已将 '), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // toast 定时器
  });

  testWidgets('单条移动：取消选择器则不动', (tester) async {
    await repo.createLedger(name: '目标账本', currency: 'CNY');
    await pumpPage(tester);
    await seedOrphans(tester);

    // 单条移动按钮位于列表底部，先滚动到可见
    await tester.scrollUntilVisible(
      find.byTooltip('移动到账本').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('移动到账本').first);
    await tester.pumpAndSettle();
    expect(find.text('选择账本'), findsOneWidget);

    // 点击遮罩取消 → 无 toast、无迁移
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('选择账本'), findsNothing);
    expect(find.textContaining('已将 '), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('重新扫描按钮触发重扫', (tester) async {
    await pumpPage(tester);
    expect(find.text('本地数据干净,未发现孤儿数据'), findsOneWidget);

    await tester.tap(find.byTooltip('重新扫描'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('本地数据干净,未发现孤儿数据'), findsOneWidget);
  });

  testWidgets('扫描失败：展示统一错误文案', (tester) async {
    var calls = 0;
    final failing = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        orphanScanReportProvider.overrideWith((ref) async {
          calls++;
          // 首次失败展示错误态；Riverpod 自动重试后成功，避免重试定时器残留
          if (calls == 1) throw Exception('scan boom');
          return OrphanScanReport.empty;
        }),
      ],
    );
    addTearDown(failing.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: failing,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OrphanCleanupPage(),
        ),
      ),
    );
    await tester.pump();

    // 首帧内 future 已失败并渲染错误态；Riverpod 重试定时器尚未触发
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    // 冲刷 Riverpod 重试(400ms)与 LoggerService 保存定时器(2s)
    await tester.pump(const Duration(seconds: 3));
    expect(calls, greaterThan(1));
  });

  testWidgets('清理部分失败：展示成功/失败计数', (tester) async {
    final cleaner = _MockCleaner();
    final fakeRecord = OrphanRecord(
      type: OrphanType.categoryMissingParent,
      title: '坏记录',
      subtitle: 'sub',
      localId: 99,
    );
    when(() => cleaner.clean(any())).thenAnswer(
      (_) async => OrphanCleanResult(
        successCount: 1,
        failures: [(record: fakeRecord, error: 'boom')],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        orphanCleanerProvider.overrideWithValue(cleaner),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OrphanCleanupPage(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await seedOrphans(tester);

    await tester.tap(find.text('全选').last);
    await tester.pump();
    await tester.tap(find.text('清理已选'));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('成功 1 项,失败 1 项'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('清理异常：提示操作失败', (tester) async {
    final cleaner = _MockCleaner();
    when(() => cleaner.clean(any())).thenThrow(Exception('db down'));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        orphanCleanerProvider.overrideWithValue(cleaner),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OrphanCleanupPage(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await seedOrphans(tester);

    await tester.tap(find.text('全选').last);
    await tester.pump();
    await tester.tap(find.text('清理已选'));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
