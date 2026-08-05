import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 单个 Overlay 上当前活跃的 toast（entry + 自动消失定时器）。
class _ActiveToast {
  _ActiveToast(this.entry, this.timer);

  final OverlayEntry entry;
  final Timer timer;
}

/// 按 Overlay 实例跟踪活跃 toast，避免根 / 嵌套多个 Overlay 互相干扰；
/// 同一 Overlay 上「后到覆盖前到」，不再叠加多个全屏 OverlayEntry。
final Map<OverlayState, _ActiveToast> _activeToasts = {};

/// 轻量 Toast（基础 UI 工具）：覆盖层展示，不占据布局，不顶起 FAB
void showToast(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 1)}) {
  showToastOnOverlay(
    Overlay.of(context, rootOverlay: true),
    message,
    duration: duration,
    isDark: SpitoutTokens.isDark(context),
  );
}

/// 用指定的 OverlayState 直接弹 Toast —— 给没有就近 BuildContext 的全局场景
/// (如 deep-link 处理:`globalNavigatorKey.currentState?.overlay`)。普通页面
/// 请用 [showToast]。注意不能用 navigator 的 context 走 [showToast],因为它在
/// Overlay 之上,`Overlay.of` 找不到祖先 Overlay 会抛 "No Overlay widget found"。
void showToastOnOverlay(OverlayState overlay, String message,
    {Duration duration = const Duration(seconds: 1), bool? isDark}) {
  final dark = isDark ?? SpitoutTokens.isDark(overlay.context);

  // 后到覆盖前到：先移除旧 toast 并取消其定时器，避免多条全屏浮层叠加。
  final existing = _activeToasts.remove(overlay);
  if (existing != null) {
    existing.timer.cancel();
    // 旧 entry 已经 insert 过，即使尚未构建（同一帧连续弹两条）也可直接移除；
    // 只有 Overlay 已销毁的极端场景才可能失败，静默忽略即可。
    try {
      existing.entry.remove();
    } catch (_) {}
  }

  final entry = OverlayEntry(
    builder: (ctx) => Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  // 暗黑模式下添加白色阴影，提升可见度
                  boxShadow: dark ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ] : null,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  final timer = Timer(duration, () => _removeToast(overlay));
  _activeToasts[overlay] = _ActiveToast(entry, timer);
}

/// 移除指定 Overlay 上的 toast；判活后再 remove，Overlay 已销毁时静默跳过。
void _removeToast(OverlayState overlay) {
  final active = _activeToasts.remove(overlay);
  if (active == null) return;
  active.timer.cancel();
  if (active.entry.mounted) active.entry.remove();
}
