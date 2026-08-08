// ui_state_providers 基础状态 provider 测试。
//
// 需求锚点：
//   1. 默认状态：启动页 splash、底部索引 0、不显示欢迎页、选中月为本月 1 号；
//   2. welcomeCheck：未看过欢迎页 → true 并置 shouldShowWelcome；看过 → false。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetGlobalTestState());

  test('默认状态：splash / 底部索引 0 / 不显示欢迎页', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appInitStateProvider), AppInitState.splash);
    expect(container.read(bottomTabIndexProvider), 0);
    expect(container.read(shouldShowWelcomeProvider), isFalse);
    expect(container.read(homeScrollToTopProvider), 0);
  });

  test('selectedMonth 默认本月 1 号', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final now = DateTime.now();
    expect(
      container.read(selectedMonthProvider),
      DateTime(now.year, now.month, 1),
    );
  });

  test('welcomeCheck：首次启动返回 true 并置欢迎页标志', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = await readProviderFutureFromContainer(
      container,
      welcomeCheckProvider.future,
    );
    expect(first, isTrue);
    expect(container.read(shouldShowWelcomeProvider), isTrue);
  });

  test('welcomeCheck：已看过欢迎页返回 false', () async {
    SharedPreferences.setMockInitialValues({'welcome_shown': true});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await readProviderFutureFromContainer(
      container,
      welcomeCheckProvider.future,
    );
    expect(result, isFalse);
    expect(container.read(shouldShowWelcomeProvider), isFalse);
  });
}
