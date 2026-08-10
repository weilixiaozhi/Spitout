import 'package:flutter/material.dart';

import 'app_route.dart';
import 'sheet_grab_handle.dart';
import '../theme/colors.dart';

/// shadcn/ui 风格 Bottom Sheet wrapper（AppSheet 语义组件）。
///
/// 统一了拖拽条、顶部圆角(16px)、标题/副标题区、内容区、底部按钮区。
/// 所有新 BottomSheet(月份选择、记录详情等)都走本组件,保证视觉一致。
///
/// 用法:[showAppSheet] 弹出容器(封装 showModalBottomSheet 样式),
/// 内部传 [AppSheet] 作为内容(标题 + 副标题 + child + footer)。
class AppSheet extends StatelessWidget {
  /// 标题(可选)。无标题时不渲染标题区。
  final String? title;

  /// 副标题(可选),展示在标题下方,mutedForeground 色。
  final String? subtitle;

  /// 内容区。
  final Widget child;

  /// 底部按钮区(可选)。通常放主/次按钮(如"完成"/"取消")。
  final Widget? footer;

  /// 标题栏右侧操作位(可选),如删除/关闭图标。
  /// 在 [pinnedHeader]=true 时常驻可见,即便内容滚动也不会被挤出可视区。
  /// 例:云同步配置弹窗把「清除配置」图标放在这里。
  final Widget? trailing;

  /// 内容区内边距。标题区与底部按钮区有各自固定内边距,这里只控制 child。
  ///
  /// 注意:标题区在 [title]/[subtitle] 均为空时仍会渲染(仅放 trailing),
  /// 以保证无标题弹层的右上角操作位(如删除 icon)不丢失。
  final EdgeInsets contentPadding;

  /// 是否显示顶部拖拽条。默认 true。
  final bool showGrabHandle;

  /// 标题区是否吸顶(固定不随内容滚动)。
  /// 默认 true:标题常驻,内容区独立滚动,长内容也能看到标题。
  final bool pinnedHeader;

  const AppSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.footer,
    this.trailing,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 4, 20, 16),
    this.showGrabHandle = true,
    this.pinnedHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final header = (title != null || subtitle != null || trailing != null)
        ? Padding(
            // 顶部内边距 12(标题不贴边);底部 0:标题与首行内容间距收敛到 ~8px。
            // 删除图标按钮高度已收紧为 32px(见 cloud_service_page 的 IconButton
            // constraints),标题栏 Row 在「有/无删除图标」两种状态下都恒为 32px,
            // 顶部留白保持一致。
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              // 标题栏标题与右侧操作位(如删除图标)垂直居中对齐:
              // trailing 是 IconButton(已收紧为最小 48×32,22px 图标在其中居中),
              // 图标视觉上沿约在 32px 行内距顶 5px;若用 start 对齐,标题文字会比图标
              // 更靠上、显得贴边。center 后单行标题(24px 行高)在 32px 行内居中,
              // 标题上沿 ≈(32-24)/2=4px、图标上沿 ≈(32-22)/2=5px,二者精确对齐。
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  // 固定标题列最小高度 32px:无删除图标时也能把 Row 撑到 32px,
                  // 使「配置 / 首次配置」两种状态顶部留白一致;配合 mainAxisAlignment
                  // 居中,标题在 32px 内与同高删除图标垂直对齐。
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      // 标题在 32px 列内垂直居中,视觉上与 32px 删除图标按钮对齐。
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      if (title != null)
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: SpitoutTokens.textPrimary(context),
                            // 行高 24px(=16px 字号 ×1.5):标题 24px 文字框在 32px 的删除图标
                            // 按钮(IconButton 最小 48×32)内随 Row 垂直居中,标题上沿 ≈(32-24)/2=4px、
                            // 图标上沿 ≈(32-22)/2=5px,二者精确对齐;配合顶部 12px 内边距,标题不贴边。
                            height: 1.5,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: SpitoutTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                // 标题栏右侧操作位:删除/关闭图标等。吸顶时始终可见。
                ?trailing,
              ],
            ),
          )
        : const SizedBox.shrink();

    final grab = showGrabHandle ? const SheetGrabHandle() : const SizedBox.shrink();

    // 标题吸顶:用 Column 包裹(grab + header 固定),内容区 Flexible 自适应滚动。
    // 标题不吸顶(pinnedHeader=false):整体交给外层滚动,本组件不做滚动容器。
    if (pinnedHeader) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          grab,
          header,
          Flexible(child: Padding(padding: contentPadding, child: child)),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: footer,
            ),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          grab,
          header,
          Padding(padding: contentPadding, child: child),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// 弹出 shadcn/ui 风格 Bottom Sheet。
///
/// 封装 showModalBottomSheet 的统一样式:顶部 16px 圆角、surfaceSheet 背景、
/// 半透明遮罩、enableDrag。返回值类型 [T] 同 showModalBottomSheet。
///
/// [heightFactor] 最大高度占屏幕比例,默认 0.85。
/// [child] 通常是 [AppSheet],也可传自定义内容(自行处理拖拽条)。
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  double heightFactor = 0.85,
}) {
  final mediaQuery = MediaQuery.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    // shadcn card/popover 背景:亮色白、暗色 #1F2937
    backgroundColor: SpitoutTokens.surfaceSheet(context),
    // 半透明遮罩(40% 黑),比 Material 默认更柔和
    barrierColor: Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    enableDrag: true,
    // 用自定义 SheetGrabHandle,关闭 Material 自带拖拽条
    showDragHandle: false,
    // 全局统一上滑动画：线性曲线（无加速减速），时长与页面切换一致。
    sheetAnimationStyle: kSheetAnimationStyle,
    constraints: BoxConstraints(
      maxHeight: mediaQuery.size.height * heightFactor,
    ),
    builder: (context) => child,
  );
}

/// 顶部贴边弹层(无入场/退场动画,且高度随键盘瞬缩)。
///
/// 设计意图:云同步配置这类多输入框表单,若用底部弹层,Flutter 的
/// `showModalBottomSheet` 内部 `AnimatedPadding` 会跟随键盘 `viewInsets` 做 200ms
/// 动画,而切换输入框时焦点变化会触发 IME 收起/拉起,进一步放大 `viewInsets` 抖动,
/// 表现为弹窗上下"弹跳"。本方法使用自定义路由,且:
///  1. `transitionDuration`/`reverseTransitionDuration` 均为零 → 进场/退场完全无动画,点开即现;
///  2. 不使用 `AnimatedPadding`,使用普通 `ConstrainedBox` 限制高度 = 屏高 - 键盘高,
///     键盘起伏时高度即时生效(无动画),弹层永远钉在顶部、绝不上下移动 → 永不弹跳;
///  3. 键盘自屏幕底部拉起,与顶部弹层物理上不重叠,保存/取消始终位于键盘之上随手可点。
///
/// [heightFactor] 弹层最大高度占屏幕比例(键盘未拉起时);键盘拉起时实际高度再减去键盘高。
/// 返回值为子组件通过 `Navigator.pop` 回传的结果。
Future<T?> showAppSheetTop<T>({
  required BuildContext context,
  required Widget child,
  double heightFactor = 0.9,
}) {
  // 记录整屏高度用于计算弹层最大高度。键盘高度通过 pageBuilder 内 MediaQuery.of
  // 实时读取,因该 context 为路由构建上下文,读取后即注册为 MediaQuery 依赖,
  // 键盘起伏时路由会自动 rebuild 并重新计算高度(无动画 → 瞬变,不弹跳)。
  final mediaQuery = MediaQuery.of(context);
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      // 零动画:瞬显瞬隐,无转场效果。
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      // 关闭遮罩点击退出:barrierDismissible=false,点击半透明遮罩不自动 pop 退出弹窗。
      // 同时该设置会拦截系统返回键/返回手势,实现「只有取消/确定才能退出弹窗」。
      // 收起键盘/退出光标由 Flutter 默认 onTapOutside 及各处的显式
      // FocusManager.unfocus() 处理。
      barrierDismissible: false,
      opaque: false,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        final mq = MediaQuery.of(ctx);
        // 顶部贴边:Align(topCenter) 将弹层锚定在屏幕顶部(y=0 起铺满),
        // 不使用 SafeArea,由下方内边距补偿状态栏,使弹层上沿与屏幕顶边融合。
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // 关键约束:最大高度 = 屏高比例 - 键盘高。普通约束(非 AnimatedPadding),
            // 键盘变化时高度即时收缩到键盘上方,保存/取消必在键盘之上、永不被遮挡。
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * heightFactor -
                  mq.viewInsets.bottom,
            ),
            child: Material(
              color: SpitoutTokens.surfaceSheet(ctx),
              // 仅底部圆角、顶部直角:上沿融进屏幕顶边(消除顶部圆角处的遮罩三角),
              // 仅弹层下方保留遮罩,视觉等同「底部弹层」的镜像。
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                // 弹层背景仍从 y=0 起铺满屏幕顶边实现「头部与背景融合」;
                // 内容顶部内缩一个状态栏高度,保证标题/删除按钮不被状态栏图标压住。
                padding: EdgeInsets.only(top: mq.padding.top),
                child: child,
              ),
            ),
          ),
        );
      },
      // 无转场动画(直接返回子组件)。
      transitionsBuilder: (ctx, animation, secondaryAnimation, routeChild) =>
          routeChild,
    ),
  );
}
