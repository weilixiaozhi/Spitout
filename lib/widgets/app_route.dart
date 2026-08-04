import 'package:flutter/material.dart';

/// 全局统一动画时长：页面转场与 bottom sheet 上滑动画共用。
///
/// 设计意图：所有全局动画时长收敛到这一处，避免各调用点各自写死时长导致
/// 观感不一致；如需整体调整动画速度，只需修改此常量一处即可全局生效。
const Duration kAppTransitionDuration = Duration(milliseconds: 200);

/// AA 分摊编辑页退场动画时长（硬编码，不跟随全局参数）。
///
/// 设计意图：AA 页在记账编辑器 sheet 之上 push，保存时 sheet 同步下滑收起，
/// 两者退场必须同向同速才无重叠拖影。sheet 收起动画时长见
/// [kSheetAnimationStyle]（与全局转场一致），此处刻意硬编码为相同时长，
/// 而非引用 [kAppTransitionDuration]，避免全局参数调整时破坏同步。
const Duration kAaPageSlideDuration = Duration(milliseconds: 200);

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

/// AA 分摊编辑页专用路由工厂。
///
/// 设计意图：AA 页通常在记账编辑器 sheet 之上 push，保存时 sheet 会同步
/// 下滑收起。若退场沿用全局左右滑动动画，会与 sheet 的下滑方向不一致，
/// 产生两层重叠、拖影。本工厂固定退场为下滑动画（与 sheet 同向同速），
/// 视觉上两层"一起收起来"。进入动画仍保持全局左右滑动，不影响正常 push。
PageRoute<T> aaSlidePageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool maintainState = true,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    maintainState: maintainState,
    transitionDuration: kAppTransitionDuration,
    // 退场下滑时长硬编码，不跟随全局转场参数，保证与 sheet 收起动画同步
    reverseTransitionDuration: kAaPageSlideDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 进入：从右向左滑入（与全局页面转场一致）；退场反向时下滑移出。
      // 用一个 Tween 同时描述"右入/下出"两个阶段：正向动画为右滑入，
      // 反向（value 从 1→0）时偏移量从 (0,0) 滑向 (0,1)，即向下收起。
      final slideTween = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.linear));
      // 退场阶段：从原位向下滑出，与 sheet 收起方向一致。
      // reverse 动画值从 1→0，经 ReverseAnimation 反转为 0→1 驱动下滑，
      // 保证退场起始帧处于原位 (0,0)，避免从屏外跳回造成闪动。
      final exitTween = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0, 1),
      ).chain(CurveTween(curve: Curves.linear));
      final isExiting = animation.status == AnimationStatus.reverse;
      return SlideTransition(
        position: isExiting
            ? exitTween.animate(ReverseAnimation(animation))
            : slideTween.animate(animation),
        child: child,
      );
    },
  );
}
