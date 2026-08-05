/// CategorySelectorDialog 分类加载 future 缓存回归测试。
///
/// 修复点：分类列表 future 由 State 缓存，搜索 / 父级重建只做内存过滤，
/// 不再每次按键都全量重查「一级分类 + 逐父查子分类」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/category_selector_dialog.dart';

class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  db.Category category(int id, String name) => db.Category(
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
    when(() => repo.getTopLevelCategories('expense')).thenAnswer(
      (_) async => [category(1, '餐饮'), category(2, '交通')],
    );
    when(() => repo.getSubCategories(any())).thenAnswer((_) async => const []);
    when(() => repo.filterCategoriesForLedgerPicker(
          any(),
          ledgerId: any(named: 'ledgerId'),
          topLevelOnly: any(named: 'topLevelOnly'),
        )).thenAnswer((invocation) async =>
        invocation.positionalArguments.first as List<db.Category>);
  });

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
                onPressed: () => showCategorySelector(
                  context,
                  type: 'expense',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('搜索按键不再触发数据库重查（future 缓存）', (tester) async {
    var topLevelQueries = 0;
    when(() => repo.getTopLevelCategories('expense')).thenAnswer((_) async {
      topLevelQueries++;
      return [category(1, '餐饮'), category(2, '交通')];
    });

    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 首次加载：一级分类查询 1 次
    expect(topLevelQueries, 1);

    // 输入搜索文本触发多次 setState / rebuild
    await tester.enterText(find.byType(TextField), '餐');
    await tester.pumpAndSettle();

    // 数据库仍只查 1 次；过滤在内存完成
    expect(topLevelQueries, 1);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsNothing);
  });
}
