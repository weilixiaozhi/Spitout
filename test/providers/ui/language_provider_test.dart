// LanguageNotifier 语言设置测试。
//
// 需求锚点：
//   1. build 先返回 null（跟随系统），再异步加载已保存语言；
//   2. setLanguage 持久化 languageCode/countryCode，null 清空跟随系统；
//   3. 显示名映射：null→系统默认，zh→简体中文，zh_TW→繁体中文，en→English。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetGlobalTestState());

  test('build 同步返回 null，随后加载已保存语言', () async {
    SharedPreferences.setMockInitialValues({
      'selected_language': 'en',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(languageProvider.notifier);
    expect(container.read(languageProvider), isNull, reason: '先同步返回跟随系统');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(languageProvider), const Locale('en'));
    expect(notifier, isA<LanguageNotifier>());
  });

  test('setLanguage 持久化语言与国家码；null 清空', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(languageProvider.notifier);

    await notifier.setLanguage(const Locale('zh', 'TW'));
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_language'), 'zh');
    expect(prefs.getString('selected_language_country'), 'TW');

    await notifier.setLanguage(const Locale('en'));
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_language_country'), isNull);

    await notifier.setLanguage(null);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_language'), isNull);
    expect(container.read(languageProvider), isNull);
  });

  testWidgets('getLanguageDisplayName 映射', (tester) async {
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
    final context = tester.element(find.byType(SizedBox));
    final notifier = LanguageNotifier();

    expect(notifier.getLanguageDisplayName(context, null), '跟随系统');
    expect(notifier.getLanguageDisplayName(context, const Locale('zh')),
        '简体中文');
    expect(notifier.getLanguageDisplayName(context, const Locale('zh', 'TW')),
        '繁體中文');
    expect(notifier.getLanguageDisplayName(context, const Locale('en')),
        'English');
  });
}
