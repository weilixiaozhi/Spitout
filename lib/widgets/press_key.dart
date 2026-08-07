import 'package:flutter/material.dart';

/// 按压反馈按键：按下即触发（可选）、松开/取消分别回调，并带按压态视觉。
///
/// 与系统键盘一致：
/// - [onDown]：按下瞬间提交（数字、运算符等），配合 [onCancel] 做滑出回滚；
/// - [onUp]：松手才提交（如"完成"这类会关页的按钮）；
/// - 按压期间背景压暗并轻微缩小，松开或取消立即恢复。
class PressKey extends StatefulWidget {
  const PressKey({
    super.key,
    required this.child,
    this.onDown,
    this.onUp,
    this.onCancel,
    this.onLongPress,
    this.onLongPressStart,
    this.backgroundColor,
    this.pressedColor,
    this.borderRadius,
    this.scale = 1.0,
    this.enabled = true,
  });

  final Widget child;

  /// 按下瞬间回调（用于即时提交）。
  final VoidCallback? onDown;

  /// 松手回调（用于需要确认后才提交的操作）。
  final VoidCallback? onUp;

  /// 手势取消/滑出按键范围回调（用于回滚 [onDown] 的即时提交）。
  final VoidCallback? onCancel;

  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressStart;

  /// 常态背景色；null = 透明。
  final Color? backgroundColor;

  /// 按压态背景色；null 时按明暗模式在常态色上叠 18% 黑/白。
  final Color? pressedColor;

  final BorderRadius? borderRadius;

  /// 按压时视觉缩放比例；长条/区域按钮请保持 1.0，避免整条跳动。
  final double scale;

  /// 禁用时无按压态、不触发任何回调。
  final bool enabled;

  @override
  State<PressKey> createState() => _PressKeyState();
}

class _PressKeyState extends State<PressKey> {
  bool _pressed = false;

  /// 统一切换按压态，避免重复 setState。
  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleDown(TapDownDetails _) {
    if (!widget.enabled) return;
    widget.onDown?.call();
  }

  void _handleUp(TapUpDetails _) {
    if (!widget.enabled) return;
    _setPressed(false);
    widget.onUp?.call();
  }

  void _handleCancel() {
    if (!widget.enabled) return;
    _setPressed(false);
    widget.onCancel?.call();
  }

  void _handleLongPressStart(LongPressStartDetails _) {
    if (!widget.enabled) return;
    widget.onLongPressStart?.call();
  }

  void _handleLongPress() {
    if (!widget.enabled) return;
    widget.onLongPress?.call();
  }

  Color _resolvedPressedColor(BuildContext context) {
    final explicit = widget.pressedColor;
    if (explicit != null) return explicit;
    final base = widget.backgroundColor ?? Colors.transparent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 统一加强到 18%：纯白数字键（亮色）与深色键（暗色）都能看到明显按压反馈
    return Color.alphaBlend(
      (isDark ? Colors.white : Colors.black).withValues(alpha: 0.18),
      base,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _pressed
        ? _resolvedPressedColor(context)
        : (widget.backgroundColor ?? Colors.transparent);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? _handleDown : null,
      onTapUp: widget.enabled ? _handleUp : null,
      onTapCancel: widget.enabled ? _handleCancel : null,
      onLongPressStart: widget.enabled && widget.onLongPressStart != null
          ? _handleLongPressStart
          : null,
      onLongPress: widget.enabled && widget.onLongPress != null
          ? _handleLongPress
          : null,
      // 按压视觉由原始指针事件驱动（Listener 不走手势竞技场），而不是
      // 依赖 TapGestureRecognizer.onTapDown：在 BottomSheet 里按键会和
      // sheet 自带的竖向拖拽识别器竞争手势竞技场，onTapDown 会被推迟到
      // 100ms 超时或抬手才触发，快速点击时按压态一帧都渲染不出来。
      // 回调（onDown/onUp/onCancel/onLongPress）仍由 GestureDetector 负责，
      // 语义与之前完全一致。
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
        onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
        onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          child: Material(
            color: color,
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            clipBehavior: Clip.antiAlias,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
