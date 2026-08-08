import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/core/identity/local_user_identity.dart';
import 'package:spitout/services/notification/notification_factory.dart';

/// 重置跨用例残留的全局状态，让每个测试用例都在干净的初始环境下运行。
///
/// 设计意图：部分全局状态会在同一 isolate 内跨用例残留，表现为
/// "单独跑通过、批量按随机顺序跑偶发失败"的顺序依赖：
///   1. SharedPreferences mock —— 上一个用例若写入 prefs，后续用例会读到残留；
///   2. NotificationFactory 单例 —— 其 `_instance` 是进程级全局，跨用例不回收；
///   3. 平台 platformDispatcher 的 TestValue（如 locale）—— 上一个用例改了
///      平台 locale，后续用例未重置就会继承错误 locale。
/// 在 `setUp` 中调用本函数，使每个用例都从同一基线起步，从根源消除此类污染。
///
/// [initialPrefs] 为各测试文件期望的 SharedPreferences 初始值；传 `{}` 表示清空。
/// 其余全局状态（平台 TestValue、通知单例）一律重置为默认值，调用方无需关心。
void resetGlobalTestState({Map<String, Object> initialPrefs = const {}}) {
  // 1) 重置 SharedPreferences mock 到文件指定的初始值。
  //    每次 setUp 都重新设置会覆盖上一个用例可能写入的残留，避免文件内污染。
  SharedPreferences.setMockInitialValues(initialPrefs);

  // 2) 重置通知工厂单例（其 _instance 是进程级全局，跨用例不会自动回收）。
  NotificationFactory.reset();
  LocalSelfId.resetForTest();

  // 3) 重置平台级 TestValue（locale / 亮度 / 语义）。
  //    仅当 Widget binding 已初始化时才有意义；纯逻辑测试无 binding，跳过即可。
  try {
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    dispatcher.clearLocaleTestValue();
    dispatcher.clearPlatformBrightnessTestValue();
    dispatcher.clearSemanticsEnabledTestValue();
  } catch (_) {
    // 非 Widget 测试环境（未初始化 binding），平台 TestValue 不存在，忽略。
  }
}
