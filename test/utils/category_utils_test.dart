// CategoryUtils 分类名显示/翻译工具测试。
//
// 需求锚点（以行为为准）：
//   1. null/空名回退「默认分类」；自定义名原样返回；
//   2. key 格式（含下划线或默认分类表内）走 l10n 翻译：一级/二级均正确；
//   3. 未知 key 翻译缺失时回退 key 本身；
//   4. getAllCategoryDisplayNames / getSubcategoryDisplayNames 口径。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/utils/category_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构建 zh 本地化宿主并返回根 context，供翻译分支使用。
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('zh'),
        home: SizedBox(),
      ),
    );
    return tester.element(find.byType(SizedBox));
  }

  testWidgets('null/空名回退默认分类；自定义名原样返回', (tester) async {
    final context = await pumpHost(tester);
    final l10n = AppLocalizations.of(context);
    expect(CategoryUtils.getDisplayName(null, context),
        l10n.categoryDefaultTitle);
    expect(CategoryUtils.getDisplayName('', context),
        l10n.categoryDefaultTitle);
    expect(CategoryUtils.getDisplayName('自定义', context), '自定义');
  });

  testWidgets('key 格式翻译：一级 dining → 餐饮，二级 dining_breakfast → 早餐',
      (tester) async {
    final context = await pumpHost(tester);
    expect(CategoryUtils.getDisplayName('dining', context), '餐饮');
    expect(CategoryUtils.getDisplayName('dining_breakfast', context), '早餐');
  });

  testWidgets('未知 key 翻译缺失回退 key 本身', (tester) async {
    final context = await pumpHost(tester);
    expect(CategoryUtils.getDisplayName('no_such_key', context), 'no_such_key');
    expect(CategoryUtils.getDisplayName('unknown_flat', context),
        'unknown_flat');
  });

  testWidgets('isCategoryKey 识别下划线与默认分类表', (tester) async {
    await pumpHost(tester);
    expect(CategoryUtils.isCategoryKey('dining_breakfast'), isTrue);
    expect(CategoryUtils.isCategoryKey('dining'), isTrue);
    expect(CategoryUtils.isCategoryKey('自定义'), isFalse);
  });

  testWidgets('getAllCategoryDisplayNames 返回一级全量显示名', (tester) async {
    final context = await pumpHost(tester);
    final l10n = AppLocalizations.of(context);
    final names = CategoryUtils.getAllCategoryDisplayNames('expense', l10n);
    expect(names, isNotEmpty);
    expect(names, contains('餐饮'));
  });

  testWidgets('getSubcategoryDisplayNames：已知父分类非空，未知父分类为空',
      (tester) async {
    final context = await pumpHost(tester);
    final l10n = AppLocalizations.of(context);
    final subs = CategoryUtils.getSubcategoryDisplayNames(
      'dining',
      'expense',
      l10n,
    );
    expect(subs, isNotEmpty);
    expect(subs, contains('早餐'));

    expect(
      CategoryUtils.getSubcategoryDisplayNames('no_such', 'expense', l10n),
      isEmpty,
    );
  });
}
