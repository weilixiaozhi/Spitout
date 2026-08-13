import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 获取的统一出口。
///
/// getInstance() 本身已有进程级缓存，本 provider 的价值在于把获取动作收拢到
/// 一个可 override 的节点：providers 层统一经它读，测试可整体替换注入内存实例，
/// 不再每处直取插件静态单例。
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});
