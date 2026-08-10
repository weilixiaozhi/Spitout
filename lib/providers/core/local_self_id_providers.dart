import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/core/identity/local_user_identity.dart';

/// 全局 localSelfId Provider。
///
/// 非 autoDispose：设备身份在 app 生命周期内不变，缓存一次即可。
/// 首次 await 时触发生成与持久化，后续读取走缓存。
final localSelfIdProvider = FutureProvider<String>((ref) async {
  return LocalSelfId.getOrCreate();
});
