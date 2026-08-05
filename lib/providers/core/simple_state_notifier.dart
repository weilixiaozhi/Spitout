import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通用可变状态 Notifier，用于替代 legacy 的 `StateProvider`。
///
/// Riverpod 3 中 `Notifier.state` 的读写均为 `@protected`，外部只能通过公开方法
/// 修改状态；[set] 即统一入口。[build] 通过 [_initial] 回调（可访问
/// Ref）计算初始值，与 `StateProvider((ref) => ...)` 的语义保持一致。
class SimpleStateNotifier<T> extends Notifier<T> {
  SimpleStateNotifier(this._initial);

  final T Function(Ref ref) _initial;

  @override
  T build() => _initial(ref);

  /// 直接替换状态；新值与旧值相等（`==`）时不会通知监听者。
  void set(T value) => state = value;
}

/// 整数 tick 计数器：每次 [tick] 自增 1，供各类“刷新信号”provider 使用。
class TickStateNotifier extends SimpleStateNotifier<int> {
  TickStateNotifier(super.initial);

  void tick() => state++;
}
