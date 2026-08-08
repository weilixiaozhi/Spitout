// 安全相关 provider 测试：启动初始化、异常自愈（有锁无 PIN 自动禁用）、
// 持久化监听、以及 AppLockService 门面的 PIN 设置/校验。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/security/app_lock_service.dart';

import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    resetGlobalTestState();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('securityInitProvider', () {
    test('空 prefs → 默认关闭、不锁定', () async {
      await container.read(securityInitProvider.future);

      expect(container.read(appLockEnabledProvider), isFalse);
      expect(container.read(appLockBiometricEnabledProvider), isFalse);
      expect(container.read(appLockTimeoutProvider), 0);
      expect(container.read(isAppLockedProvider), isFalse);
    });

    test('已启用且有 PIN → 启动即锁定', () async {
      await AppLockService.setPin('1234');
      await container.read(securityInitProvider.future);

      expect(container.read(appLockEnabledProvider), isTrue);
      expect(container.read(isAppLockedProvider), isTrue,
          reason: '启用应用锁时启动应进入锁定态');
    });

    test('启用了但无 PIN（脏状态）→ 自动禁用并写回 prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppLockService.prefsKeyEnabled, true);

      await container.read(securityInitProvider.future);

      expect(container.read(appLockEnabledProvider), isFalse,
          reason: '有锁无 PIN 属于脏状态，应自动禁用');
      expect(prefs.getBool(AppLockService.prefsKeyEnabled), isFalse);
    });

    test('监听 provider 变更并持久化', () async {
      await container.read(securityInitProvider.future);
      final prefs = await SharedPreferences.getInstance();

      container.read(appLockEnabledProvider.notifier).set(true);
      container.read(appLockTimeoutProvider.notifier).set(300);
      container.read(appLockBiometricEnabledProvider.notifier).set(true);

      // 等待监听器写回
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(prefs.getBool(AppLockService.prefsKeyEnabled), isTrue);
      expect(prefs.getInt(AppLockService.prefsKeyTimeoutSeconds), 300);
      expect(
        prefs.getBool(AppLockService.prefsKeyBiometricEnabled),
        isTrue,
      );
    });
  });

  group('AppLockServiceFacade', () {
    test('setPin / verifyPin / hasPin / recordUnlock', () async {
      final facade = container.read(appLockServiceProvider);

      expect(await AppLockService.hasPin(), isFalse);
      await facade.setPin('1234');
      expect(await AppLockService.hasPin(), isTrue);
      expect(await facade.verifyPin('1234'), isTrue);
      expect(await facade.verifyPin('0000'), isFalse);
      facade.recordUnlock();
    });
  });
}
