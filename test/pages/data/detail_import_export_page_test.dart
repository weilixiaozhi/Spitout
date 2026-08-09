// 明细导入导出页面 - 账本数据迁移提示说明测试
//
// 覆盖：在功能说明区新增「账本数据迁移」提示分节后，
// 页面应正确渲染迁移提示的标题与说明文案，且原有功能说明文本保持不变。
// 另覆盖：点击「导出明细」跳转 `DetailExportPage` 二级页面。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/data/detail_export_page.dart';
import 'package:spitout/pages/data/detail_import_export_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/app_list_tile.dart';

// Mock 整个 BaseRepository，未 stub 的方法返回默认值不抛异常。
class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    resetGlobalTestState();
    repo = _MockRepo();
    // 导出明细二级页面会查询账本列表，这里 stub 一个默认账本
    when(() => repo.getAllLedgers()).thenAnswer(
      (_) async => [
        Ledger(
          id: 1,
          name: '默认账本',
          currency: 'CNY',
          type: 'personal',
          createdAt: DateTime(2026, 1, 1),
          myRole: 'owner',
          memberCount: 1,
          isShared: false,
          monthStartDay: 1,
          storageMode: 'local',
        aaEnabled: false,
        ),
      ],
    );
  });

  /// 构建测试宿主，注入 mock repo 与账本 ID，并挂载多语言 delegates。
  Widget buildApp({Locale locale = const Locale('zh')}) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const DetailImportExportPage(),
      ),
    );
  }

  /// 分步 pump：让首帧与异步加载（l10n 资源）完成。
  Future<void> prime(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('账本数据迁移提示', () {
    testWidgets('页面标题与原有功能说明文本保持不变', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 头部标题仍为「明细导入导出」
      expect(find.text('明细导入导出'), findsOneWidget,
          reason: '页面标题应为「明细导入导出」');
      // 原有导入/导出说明标题与按钮文案仍存在（标题与按钮各一处，合计多处）
      expect(find.text('导入明细'), findsWidgets,
          reason: '应保留「导入明细」说明与按钮');
      expect(find.text('导出明细'), findsWidgets,
          reason: '应保留「导出明细」说明与按钮');
      // 功能说明头部标题保持
      expect(find.text('功能说明'), findsOneWidget,
          reason: '功能说明头部标题应为「功能说明」');
    });

    testWidgets('简体中文下显示账本迁移提示标题与说明', (tester) async {
      await tester.pumpWidget(buildApp(locale: const Locale('zh')));
      await prime(tester);

      expect(find.text('账本数据迁移'), findsOneWidget,
          reason: '应显示迁移提示标题「账本数据迁移」');
      expect(
        find.text(
          '你可以先将当前账本数据导出为 CSV 文件，再切换到目标账本导入该文件，即可实现账本间数据的平滑迁移。',
        ),
        findsOneWidget,
        reason: '应显示迁移提示说明文案',
      );
    });

    testWidgets('英文 locale 下显示对应的迁移提示文案', (tester) async {
      await tester.pumpWidget(buildApp(locale: const Locale('en')));
      await prime(tester);

      expect(find.text('Ledger Data Migration'), findsOneWidget,
          reason: '英文应显示迁移提示标题');
      expect(
        find.text(
          "Export the current ledger's data to a CSV file, then switch to the target ledger and import that file to migrate your data between ledgers seamlessly.",
        ),
        findsOneWidget,
        reason: '英文应显示迁移提示说明文案',
      );
    });
  });

  group('导出明细入口', () {
    testWidgets('点击「导出明细」跳转 DetailExportPage 二级页面', (tester) async {
      await tester.pumpWidget(buildApp());
      await prime(tester);

      // 点击功能按钮卡片中的「导出明细」（说明区分节标题不含在 AppListTile 内）
      final exportTile = find.widgetWithText(AppListTile, '导出明细');
      await tester.ensureVisible(exportTile);
      await tester.pumpAndSettle();
      await tester.tap(exportTile);
      await tester.pumpAndSettle();

      expect(find.byType(DetailExportPage), findsOneWidget,
          reason: '点击后应跳转导出明细二级页面');
      // 二级页面默认选中当前账本
      expect(find.text('默认账本'), findsOneWidget);
    });
  });

  group('导入明细流程', () {
    testWidgets('选择文件 → 流式读取 → 进入字段映射页', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('detail_import');
      addTearDown(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      });
      final csvFile = File('${tempDir.path}/trans.csv');
      csvFile.writeAsStringSync(
        '日期,类型,金额,分类\n2026-01-01,支出,12.50,餐饮\n',
      );

      const pickerChannel =
          MethodChannel('miguelruivo.flutter.plugins.filepicker');
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pickerChannel,
        (call) async {
          if (call.method == 'clear') return true;
          return [
            {
              'path': csvFile.path,
              'name': 'trans.csv',
              'size': 60,
              'identifier': 'f1',
              'type': 'file',
            },
          ];
        },
      );
      addTearDown(() => binding.defaultBinaryMessenger
          .setMockMethodCallHandler(pickerChannel, null));

      await tester.pumpWidget(buildApp());
      await prime(tester);
      // ImportConfirmPage 加载分类列表所需的仓库调用
      when(() => repo.getAllCategories())
          .thenAnswer((_) async => <Category>[]);
      when(() => repo.getLedgerById(1)).thenAnswer((_) async => null);

      // 文件读取与后台解析均为真实 IO / isolate，须在 runAsync 中推进
      await tester.runAsync(() async {
        await tester.tap(find.text('导入明细').last);
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 已进入 ImportConfirmPage 字段映射步骤
      expect(find.text('确认映射'), findsOneWidget);

      // 返回入口页
      await tester.tap(find.byIcon(AppIcons.back));
      await tester.pumpAndSettle();
      expect(find.text('明细导入导出'), findsOneWidget);
    });

    testWidgets('取消选择文件：停留在入口页', (tester) async {
      const pickerChannel =
          MethodChannel('miguelruivo.flutter.plugins.filepicker');
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pickerChannel,
        (call) async => null,
      );
      addTearDown(() => binding.defaultBinaryMessenger
          .setMockMethodCallHandler(pickerChannel, null));

      await tester.pumpWidget(buildApp());
      await prime(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('导入明细').last);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('确认映射'), findsNothing);
      expect(find.text('明细导入导出'), findsOneWidget);
    });
  });
}
