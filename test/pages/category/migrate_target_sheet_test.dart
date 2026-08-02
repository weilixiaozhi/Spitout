// 迁移目标分类选择 BottomSheet 测试。
//
// 覆盖任务：迁移分类 bottom sheet 优化
//   1. 顶部搜索框：按分类显示名过滤，命中项保持父 → 子相对顺序
//   2. 排列顺序：先父后子——列完一个一级分类及其全部二级分类，再列下一个
//   3. 层级标注：一级分类显示"一级分类"，二级分类显示"二级 · 所属父分类名"
//   4. 选择目标后确定按钮启用，确定后返回选中分类 id

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/category/category_manage_page.dart';

typedef _CatWithCount = ({db.Category category, int transactionCount});

/// 构造测试分类（kind 固定 expense，与迁移目标候选口径一致）
db.Category _cat({
  required int id,
  required String name,
  required int level,
  int? parentId,
  int sortOrder = 0,
}) {
  return db.Category(
    id: id,
    name: name,
    kind: 'expense',
    icon: 'utensils',
    sortOrder: sortOrder,
    parentId: parentId,
    level: level,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  // 故意打乱传入顺序：验证 sheet 内部重排为 餐饮(父) → 早餐/午餐(子) → 交通(父)
  final cats = <_CatWithCount>[
    (category: _cat(id: 4, name: '交通', level: 1, sortOrder: 1), transactionCount: 5),
    (category: _cat(id: 3, name: '午餐', level: 2, parentId: 1, sortOrder: 1), transactionCount: 2),
    (category: _cat(id: 1, name: '餐饮', level: 1, sortOrder: 0), transactionCount: 3),
    (category: _cat(id: 2, name: '早餐', level: 2, parentId: 1, sortOrder: 0), transactionCount: 1),
  ];

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  /// 构建宿主并弹起迁移目标 sheet；[onResult] 在 sheet 关闭后回传结果
  Future<void> openSheet(
    WidgetTester tester, {
    required void Function(int?) onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final r = await showMigrateTargetSheet(
                    ctx,
                    availableCategories: cats,
                  );
                  onResult(r);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// 文本左上角 x 坐标（Wrap 单行布局下用于断言排列顺序）
  double xOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dx;

  testWidgets('先父后子排列：列完一个父分类的全部子分类再列下一个', (tester) async {
    await openSheet(tester, onResult: (_) {});

    // 标题与搜索框存在
    expect(find.text(l10n.categoryMigrateSelectTargetTitle), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // 单行 Wrap 下 x 坐标递增即排列顺序：餐饮 → 早餐 → 午餐 → 交通
    expect(xOf(tester, '餐饮'), lessThan(xOf(tester, '早餐')));
    expect(xOf(tester, '早餐'), lessThan(xOf(tester, '午餐')));
    expect(xOf(tester, '午餐'), lessThan(xOf(tester, '交通')),
        reason: '应先列完餐饮的全部子分类（早餐、午餐），再列下一个父分类交通');
  });

  testWidgets('层级标注：一级显示"一级分类"，二级显示"二级 · 父分类名"', (tester) async {
    await openSheet(tester, onResult: (_) {});

    // 两个一级分类（餐饮、交通）均标注"一级分类"
    expect(find.text(l10n.categoryTopLevelLabel), findsNWidgets(2));
    // 两个二级分类（早餐、午餐）均标注所属父分类名
    expect(
      find.text(l10n.categoryMigrateChildLabel('餐饮')),
      findsNWidgets(2),
      reason: '二级分类应标注"二级 · 餐饮"指明所属父分类',
    );
  });

  testWidgets('搜索过滤：按显示名过滤且命中项保持父 → 子顺序', (tester) async {
    await openSheet(tester, onResult: (_) {});

    // 输入"餐"：命中 餐饮、早餐、午餐（名称含"餐"），交通被过滤
    await tester.enterText(find.byType(TextField), '餐');
    await tester.pump();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('交通'), findsNothing, reason: '名称不含"餐"的分类应被过滤');

    // 命中项仍保持父 → 子相对顺序
    expect(xOf(tester, '餐饮'), lessThan(xOf(tester, '早餐')));
    expect(xOf(tester, '早餐'), lessThan(xOf(tester, '午餐')));

    // 清空搜索词后恢复完整列表
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('交通'), findsOneWidget);
  });

  testWidgets('未选择时确定按钮禁用，选择后启用并返回目标 id', (tester) async {
    int? result;
    await openSheet(tester, onResult: (v) => result = v);

    FilledButton confirmButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.categoryMigrateConfirmButton));

    expect(confirmButton().onPressed, isNull, reason: '未选择目标时确定按钮应禁用');

    await tester.tap(find.text('交通'));
    await tester.pump();
    expect(confirmButton().onPressed, isNotNull, reason: '选择目标后确定按钮应启用');

    await tester.tap(find.text(l10n.categoryMigrateConfirmButton));
    await tester.pumpAndSettle();

    expect(result, 4, reason: '确定后应返回选中分类 id（交通 = 4）');
    expect(find.byType(TextField), findsNothing, reason: '确定后 sheet 应关闭');
  });
}
