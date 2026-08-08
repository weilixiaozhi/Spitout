// theme_providers 外观偏好持久化测试。
//
// 需求锚点：
//   1. themeModeInit：读取 prefs 恢复 light/dark/system；非法值回退 system；
//      后续变更即时落盘；
//   2. expenseColorSchemeInit：读取并持久化支出配色；
//   3. displayNameInit：读取并持久化显示名。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetGlobalTestState());

  test('themeModeInit：恢复 dark 并落盘后续变更', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await readProviderFutureFromContainer(container, themeModeInitProvider.future);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    container.read(themeModeProvider.notifier).set(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'light');
  });

  test('themeModeInit：非法值回退 system', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'garbage'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await readProviderFutureFromContainer(container, themeModeInitProvider.future);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('expenseColorSchemeInit：读取并落盘', () async {
    SharedPreferences.setMockInitialValues({'expenseColorScheme': 'green'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await readProviderFutureFromContainer(
      container,
      expenseColorSchemeInitProvider.future,
    );
    expect(container.read(expenseColorSchemeProvider), 'green');

    container.read(expenseColorSchemeProvider.notifier).set('red');
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('expenseColorScheme'), 'red');
  });

  test('displayNameInit：读取并落盘', () async {
    SharedPreferences.setMockInitialValues({'displayName': '小明'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await readProviderFutureFromContainer(container, displayNameInitProvider.future);
    expect(container.read(displayNameProvider), '小明');

    container.read(displayNameProvider.notifier).set('新名');
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('displayName'), '新名');
  });
}
