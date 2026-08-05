import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Riverpod 3 下等待 [listenable]（通常是 `provider.future`）完成并返回首个值。
///
/// 背景：Riverpod 3 起 StreamProvider 在没有活跃监听时会暂停流订阅；
/// `read(provider.future)` 的内部临时监听器会在流首值送达前被关闭，
/// 导致 future 永久挂起（FutureProvider 无此问题，但本工具对两者均适用）。
/// 这里在等待期间保持一个真实监听，值到达后再关闭。
Future<T> _readProviderFuture<T>(
  ProviderSubscription<Future<T>> Function(
    ProviderListenable<Future<T>> provider,
    void Function(Future<T>? previous, Future<T> next) listener,
  )
  listen,
  ProviderListenable<Future<T>> listenable,
) async {
  final sub = listen(listenable, (_, _) {});
  try {
    return await sub.read();
  } finally {
    sub.close();
  }
}

/// [Ref] 载体（provider build 内部）的 [provider.future] 首值读取。
Future<T> readProviderFutureFromRef<T>(
  Ref ref,
  ProviderListenable<Future<T>> listenable,
) =>
    _readProviderFuture(ref.listen, listenable);

/// [WidgetRef] 载体（ConsumerWidget / ConsumerState）的 [provider.future] 首值读取。
Future<T> readProviderFutureFromWidgetRef<T>(
  WidgetRef ref,
  ProviderListenable<Future<T>> listenable,
) =>
    // WidgetRef.listen 返回 void（订阅随 widget 生命周期托管），
    // 这里需要手动持有订阅，因此用 listenManual。
    _readProviderFuture(ref.listenManual, listenable);

/// [ProviderContainer] 载体（后台服务 / 测试）的 [provider.future] 首值读取。
Future<T> readProviderFutureFromContainer<T>(
  ProviderContainer container,
  ProviderListenable<Future<T>> listenable,
) =>
    _readProviderFuture(container.listen, listenable);
