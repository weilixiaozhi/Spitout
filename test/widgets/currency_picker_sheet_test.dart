// 币种选择 bottom sheet（showCurrencyPickerSheet）组件测试。
//
// 需求锚点（以行为为准）：
//   1. 弹出 sheet 展示标题、搜索框与币种行「名称 (CODE)」，当前选中带勾；
//   2. visibleCurrencies 过滤可见集合，且当前选中值与 rateBase 强制保留；
//   3. 搜索按名称/代码过滤，不触发重新查询；
//   4. rateBase 传入时展示换算行：(1 USD = 7.24 CNY)；主币种自身行在
//      showRateAsBaseLabel=true 时展示「账本主币种 · ¥1.00」；
//   5. 点行返回 code；点遮罩取消返回 null。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/currency_picker_sheet.dart';

class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  Widget buildApp({
    String selected = 'CNY',
    String? rateBase,
    bool showRateAsBaseLabel = false,
    Set<String>? visibleCurrencies,
    Map<String, double>? rates,
    String title = '选择币种',
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        if (rates != null)
          currencyPickerRatesProvider.overrideWith(
            (ref, base) async => rates,
          ),
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
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await showCurrencyPickerSheet(
                    context,
                    selected: selected,
                    primaryColor: Theme.of(context).colorScheme.primary,
                    title: title,
                    rateBase: rateBase,
                    showRateAsBaseLabel: showRateAsBaseLabel,
                    visibleCurrencies: visibleCurrencies,
                  );
                  debugPrint('picked:$result');
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('zh');
    addTearDown(
      () => tester.binding.platformDispatcher.clearLocaleTestValue(),
    );
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// 用指定参数直接构建并打开 sheet。
  Future<void> openWith(WidgetTester tester, Widget app) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('zh');
    addTearDown(
      () => tester.binding.platformDispatcher.clearLocaleTestValue(),
    );
    await tester.pumpWidget(app);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('弹出展示标题/搜索框/币种行，选中行带勾', (tester) async {
    await openSheet(tester);

    expect(find.text('选择币种'), findsOneWidget);
    expect(find.text('搜索：中文或代码'), findsOneWidget);
    expect(find.text('人民币 (CNY)'), findsOneWidget);
    expect(find.text('美元 (USD)'), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget,
        reason: '当前选中 CNY 行应有勾');
  });

  testWidgets('visibleCurrencies 过滤集合，选中值与 rateBase 强制保留', (tester) async {
    await openWith(
      tester,
      buildApp(
        selected: 'HKD',
        rateBase: 'CNY',
        visibleCurrencies: const {'CNY', 'USD'},
      ),
    );

    // 集合外但为当前选中值的 HKD 与 rateBase CNY 必须保留
    expect(find.text('人民币 (CNY)'), findsOneWidget);
    expect(find.text('美元 (USD)'), findsOneWidget);
    expect(find.text('港币 (HKD)'), findsOneWidget,
        reason: '当前选中值即使不在集合内也强制保留');
    expect(find.text('日元 (JPY)'), findsNothing);
  });

  testWidgets('搜索按名称与代码过滤', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), '美');
    await tester.pumpAndSettle();
    expect(find.text('美元 (USD)'), findsOneWidget);
    expect(find.text('人民币 (CNY)'), findsNothing);

    await tester.enterText(find.byType(TextField), 'JP');
    await tester.pumpAndSettle();
    expect(find.text('日元 (JPY)'), findsOneWidget);
    expect(find.text('美元 (USD)'), findsNothing);
  });

  testWidgets('rateBase 换算行 + 主币种自身符号化展示', (tester) async {
    await openWith(
      tester,
      buildApp(
        rateBase: 'CNY',
        showRateAsBaseLabel: true,
        rates: const {'USD': 7.24},
      ),
    );

    expect(find.text('账本主币种 · ¥1.00'), findsOneWidget,
        reason: '主币种自身行使用符号化展示');
    expect(find.text('1 USD = 7.24 CNY'), findsOneWidget,
        reason: '有汇率的币种行展示换算');
  });

  testWidgets('点行返回 code；点遮罩取消返回 null', (tester) async {
    String? picked;
    tester.binding.platformDispatcher.localeTestValue = const Locale('zh');
    addTearDown(
      () => tester.binding.platformDispatcher.clearLocaleTestValue(),
    );
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
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showCurrencyPickerSheet(
                    context,
                    selected: 'CNY',
                    primaryColor: Colors.blue,
                    title: '选择币种',
                  );
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
    await tester.tap(find.text('美元 (USD)'));
    await tester.pumpAndSettle();
    expect(picked, 'USD');
    expect(find.text('选择币种'), findsNothing);

    // 重开并点遮罩 → null
    picked = 'unset';
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });
}
