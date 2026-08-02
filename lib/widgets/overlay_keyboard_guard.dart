import 'package:flutter/widgets.dart';

/// 拉起底部弹层 / 选择器前的「键盘收起」扩展。
///
/// 设计意图：
/// 多个页面在「从输入框焦点场景切换到弹层/选择器」时，都需要先收起系统键盘，
/// 再等待约 100ms 收起动画结束，给后续 showModalBottomSheet / 选择器一个干净的
/// 布局起点。本扩展统一封装这两步样板（unfocus + Future.delayed），
/// 避免在 _pickDate、_selectParentCategory、账本币种选择等位置重复书写。
///
/// 注意：本扩展【只】负责收键盘与等待，不在此处判断 mounted。原因是
/// use_build_context_synchronously 规则只认调用点「直接」出现的 `if (!mounted) return;`
/// 守卫，无法识别把 mounted 包进扩展方法后的返回值。因此调用点必须保留可见的
/// mounted 守卫（见下方调用示例），否则分析器会误报跨异步间隙使用 context。
///
/// 本扩展仅依赖 Flutter 框架（State / FocusManager），属于 UI 层通用辅助，
/// 故放在 widgets/ui 而非 core —— core 只承载框架无关的底层设施（如 logging）。
extension OverlayKeyboardGuard on State {
  /// 收起键盘并等待收起动画完成。
  ///
  /// 调用示例（务必保留 mounted 守卫以满足分析器）：
  /// ```dart
  /// await prepareForOverlay();
  /// if (!mounted) return;
  /// final res = await showXxx(context, ...);
  /// ```
  Future<void> prepareForOverlay() async {
    // 收起当前焦点（输入框）的键盘，避免弹层关闭返回时键盘重新弹起。
    FocusManager.instance.primaryFocus?.unfocus();
    // 等待键盘收起动画，给后续弹层一个干净的布局起点（实测约 100ms 足够）。
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
