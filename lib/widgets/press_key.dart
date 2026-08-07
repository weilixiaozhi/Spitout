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

  /// 按压态背景色；null 时按明暗模式在常态色上叠 10% 黑/白。
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

  void _handleDown(TapDownDetails _) {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
    widget.onDown?.call();
  }

  void _handleUp(TapUpDetails _) {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
    widget.onUp?.call();
  }

  void _handleCancel() {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
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
    return Color.alphaBlend(
      (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
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
      onLongPressStart:
          widget.enabled && widget.onLongPressStart != null
              ? _handleLongPressStart
              : null,
      onLongPress:
          widget.enabled && widget.onLongPress != null ? _handleLongPress : null,
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
    );
  }
}
