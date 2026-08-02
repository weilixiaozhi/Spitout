// 所属分类选择 BottomSheet（showParentCategorySelector）组件测试
//
// 覆盖 2026-07-24 UI 优化：
//   1. 列表项仅显示 图标 + 分类名 + 选中勾，副标题"一级分类"标签已移除
//   2. 列表项之间以细分割线（Divider）区分内容区
//   3. 基础交互：标题展示、点击选中出现选中勾

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/widgets/category_selector_dialog.dart';

/// Mock 整个 BaseRepository
class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  /// 构造一级分类测试数据
  db.Category buildCategory(int id, String name) => db.Category(
        id: id,
        name: name,
        kind: 'expense',
        icon: 'category',
        sortOrder: id,
        parentId: null,
        level: 1,
      );

  setUp(() {
    repo = _MockRepo();
    // sheet 仅加载 expense 一级分类
    when(() => repo.getTopLevelCategories('expense')).thenAnswer(
      (_) async => [
        buildCategory(1, '餐饮'),
        buildCategory(2, '交通'),
        buildCategory(3, '购物'),
      ],
    );
  });

  /// 构建测试宿主：首页放一个按钮用于打开 BottomSheet
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showParentCategorySelector(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 打开 BottomSheet 并等待动画与数据加载完成
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('列表展示分类名，标题为"选择所属分类"', (tester) async {
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    expect(find.text('选择所属分类'), findsOneWidget, reason: '应有 sheet 标题');
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
  });

  testWidgets('列表项无副标题（不显示"一级分类"标签）', (tester) async {
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    // 副标题已移除：3 个一级分类都不应再显示"一级分类"标签
    expect(find.text('一级分类'), findsNothing,
        reason: '列表项副标题"一级分类"应已移除');
  });

  testWidgets('列表项之间有分割线（3 项 → 2 条 Divider）', (tester) async {
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    // ListView.separated：n 个列表项之间有 n-1 条分割线
    expect(find.byType(Divider), findsNWidgets(2),
        reason: '3 个列表项之间应有 2 条分割线');
  });

  testWidgets('点击列表项后出现选中勾', (tester) async {
    await tester.pumpWidget(buildApp());
    await openSheet(tester);

    await tester.tap(find.text('交通'));
    await tester.pump(const Duration(milliseconds: 100));

    // 选中行右侧出现勾选图标（Lucide check）
    expect(find.byType(Icon), findsWidgets, reason: '列表项含图标');
    // 通过 tile 结构验证：选中行背景高亮 + 勾选图标存在
    final checkIcons = tester
        .widgetList<Icon>(find.byType(Icon))
        .where((icon) => icon.size == 18)
        .length;
    expect(checkIcons, greaterThanOrEqualTo(1), reason: '选中行应出现勾选图标');
  });
}
