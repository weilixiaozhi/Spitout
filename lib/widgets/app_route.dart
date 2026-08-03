import 'package:flutter/material.dart';

/// 全局统一动画时长：页面转场与 bottom sheet 上滑动画共用。
///
/// 设计意图：所有全局动画时长收敛到这一处，避免各调用点各自写死时长导致
/// 观感不一致；如需整体调整动画速度，只需修改此常量一处即可全局生效。
const Duration kAppTransitionDuration = Duration(milliseconds: 200);

/// 全局统一 bottom sheet 上滑动画样式。
///
/// 线性曲线（无加速减速），时长与页面转场保持一致，视觉上匀速从底部滑入。
/// 所有 `showModalBottomSheet` / `showAppSheet` 调用点统一引用本常量，
/// 避免散落硬编码 `AnimationStyle`，保证弹层进场/退场动画全局一致。
/// 注意：`AnimationStyle` 构造非 const，故用 `final` 声明（时长与曲线均不可变）。
final AnimationStyle kSheetAnimationStyle = AnimationStyle(
  duration: kAppTransitionDuration,
  reverseDuration: kAppTransitionDuration,
  curve: Curves.linear,
  reverseCurve: Curves.linear,
);

/// 全局统一页面路由工厂。
///
/// 设计意图：所有页面跳转统一走本工厂，配合 `app_theme.dart` 中配置的
/// `PageTransitionsTheme`（左右滑动 + 线性曲线）实现全局一致的转场动画。
/// 调用点不再直接使用裸 `MaterialPageRoute`，避免散落实现导致动画不一致。
///
/// 动画来源：`MaterialPageRoute` 会自动应用主题中的 `pageTransitionsTheme`，
/// 因此本工厂本身不指定 transitionsBuilder，仅做样式与参数的统一封装。
/// 转场时长统一由 [kAppTransitionDuration] 控制（见 [_AppPageRoute]），
/// 比 Flutter 默认 300ms 更轻快，仍保持线性匀速的滑动观感。
///
/// 用法：
/// ```dart
/// await Navigator.of(context).push(appPageRoute(builder: (_) => const MyPage()));
/// await Navigator.of(context).push(appPageRoute<int>(
///   builder: (_) => const MyPage(),
///   settings: const RouteSettings(name: '/my'),
/// ));
/// ```
PageRoute<T> appPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool maintainState = true,
  bool fullscreenDialog = false,
}) {
  return _AppPageRoute<T>(
    builder: builder,
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
  );
}

/// 全局统一页面路由实现。
///
/// 覆盖 `transitionDuration` / `reverseTransitionDuration` 为
/// [kAppTransitionDuration]，使所有经 [appPageRoute] 的页面切换时长全局一致
/// （Flutter 默认 300ms 偏慢）。
class _AppPageRoute<T> extends MaterialPageRoute<T> {
  _AppPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration => kAppTransitionDuration;

  @override
  Duration get reverseTransitionDuration => kAppTransitionDuration;
}
