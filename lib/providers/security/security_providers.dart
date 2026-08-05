import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';
import '../../services/security/app_lock_service.dart';

// 应用是否处于锁定状态
final isAppLockedProvider =
    NotifierProvider<SimpleStateNotifier<bool>, bool>(
  () => SimpleStateNotifier((ref) => false),
);

// 隐私模糊屏是否显示（多任务切换时）
final showPrivacyScreenProvider =
    NotifierProvider<SimpleStateNotifier<bool>, bool>(
  () => SimpleStateNotifier((ref) => false),
);

// 应用锁是否启用
final appLockEnabledProvider =
    NotifierProvider<SimpleStateNotifier<bool>, bool>(
  () => SimpleStateNotifier((ref) => false),
);

// 生物识别是否启用
final appLockBiometricEnabledProvider =
    NotifierProvider<SimpleStateNotifier<bool>, bool>(
  () => SimpleStateNotifier((ref) => false),
);

// 超时时间（秒）：0=立即, 60=1分钟, 300=5分钟, 900=15分钟
final appLockTimeoutProvider =
    NotifierProvider<SimpleStateNotifier<int>, int>(
  () => SimpleStateNotifier((ref) => 0),
);

// 初始化安全相关 Provider（在 splash 阶段调用）
final securityInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  // 读取应用锁状态
  // key 统一引用 AppLockService 常量，避免字符串散落导致改名后静默失联。
  final enabled = prefs.getBool(AppLockService.prefsKeyEnabled) ?? false;
  final biometric =
      prefs.getBool(AppLockService.prefsKeyBiometricEnabled) ?? false;
  final timeout =
      prefs.getInt(AppLockService.prefsKeyTimeoutSeconds) ?? 0;

  ref.read(appLockEnabledProvider.notifier).set(enabled);
  ref.read(appLockBiometricEnabledProvider.notifier).set(biometric);
  ref.read(appLockTimeoutProvider.notifier).set(timeout);

  // 安全检查：锁已启用但无 PIN，自动禁用
  if (enabled && !(await AppLockService.hasPin())) {
    ref.read(appLockEnabledProvider.notifier).set(false);
    await prefs.setBool(AppLockService.prefsKeyEnabled, false);
    return;
  }

  // 启动时如果锁启用，设置为锁定状态
  if (enabled) {
    ref.read(isAppLockedProvider.notifier).set(true);
  }

  // 监听 Provider 变化并持久化
  ref.listen<bool>(appLockEnabledProvider, (prev, next) async {
    await prefs.setBool(AppLockService.prefsKeyEnabled, next);
  });
  ref.listen<bool>(appLockBiometricEnabledProvider, (prev, next) async {
    await prefs.setBool(AppLockService.prefsKeyBiometricEnabled, next);
  });
  ref.listen<int>(appLockTimeoutProvider, (prev, next) async {
    await prefs.setInt(AppLockService.prefsKeyTimeoutSeconds, next);
  });
});
