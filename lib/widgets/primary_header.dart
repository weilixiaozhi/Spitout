import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';

/// 全局统一页面头部组件。
///
/// 设计意图：本组件是全局头部规范的唯一载体——首行留白（上 8、下 0、左/右 12）、
/// 首行最小高度（30）、标题样式（[SpitoutTextTokens.strongTitle] 字重 w600 + 字号 14）、
/// 返回按钮（图标 20px / 热区 30x30）与 action 图标规格（图标 20px / 热区 30x30）、
/// 文字链规格（[HeaderTextAction] 14px/w600）全部内置，调用方只需传内容参数
/// （title/actions 等），无法在样式上分叉。
/// 唯一例外：我的页 [MinePageHeader] 走 content 模式保留私有布局。
class PrimaryHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? content;
  final EdgeInsetsGeometry padding;
  // 标题/副标题右侧图标（如下拉箭头）。只接收 IconData——尺寸统一由组件以
  // 20px 渲染（与 HeaderIconAction 功能键的图标规格一致，整页头部图标收敛为
  // 20px 一档），调用方无法指定 size，从而保证「头部所有图标 20px」这一规范
  // 完全收归组件管控，杜绝各页面各自维护导致规格漂移。
  final IconData? titleTrailing;
  final IconData? subtitleTrailing;
  // 标题文字隔壁的可点击功能键（如账本页「添加账本」的 + 号）。接收 Widget
  // （一般传 HeaderIconAction，复用 20px / 30×30 热区的统一规格），渲染在
  // 标题文字右侧、titleTrailing 之后。与 titleTrailing（纯装饰、不可点）区分：
  // 这里是真正的入口按钮，需要点击回调。
  final Widget? titleAction;
  final Widget? center;
  final Brightness? statusBarIconBrightness;
  final BoxDecoration? decoration;
  // 隐藏内置标题/副标题行，仅渲染自定义 content（用于我的页 MinePageHeader）
  final bool showTitleSection;
  /// 标题点击回调：非空时「标题+titleTrailing」区域整体可点（首页月份/统计页账期选择）。
  /// 为 null 时标题为纯文本，无点击热区与涟漪。
  final VoidCallback? onTitleTap;

  const PrimaryHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.actions,
    this.bottom,
    this.content,
    // 全局头部统一留白：状态栏底到标题的顶部留白为 8，标题行底部留白取消为 0，
    // 左右内缩为 12；所有页面（一级 tab 与二级页）共用此默认值，请勿在调用处覆盖。
    this.padding = const EdgeInsets.only(top: SpitoutDimens.p8, left: SpitoutDimens.p12, right: SpitoutDimens.p12, bottom: 0),
    this.titleTrailing,
    this.subtitleTrailing,
    this.titleAction,
    this.center,
    this.statusBarIconBrightness,
    this.decoration,
    this.showTitleSection = true,
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 标题规格全局统一：字重用 strongTitle 的 w600，字号收敛为 14px
    // （比 strongTitle 默认 15 略小，作为头部主标题更克制，且不大于下方内容）。
    final titleStyle = SpitoutTextTokens.strongTitle(context).copyWith(fontSize: 14);
    final subStyle = SpitoutTextTokens.label(context);

    // 内容区统一内边距：直接复用 padding（默认 all(8)，全局统一留白，
    // 保证所有页面首行顶距一致）。

    // 使用 Token 系统
    final isDark = SpitoutTokens.isDark(context);

    // 扁平化：header 底色 = 页面底色，与页面融为一体，视觉更简洁。
    // 设计意图：暗色下必须与列表区域 scaffoldBackgroundColor(0xFF111827) 一致，
    // 因此统一使用页面底色，而不单独分支为 Colors.black。
    final headerBg = Theme.of(context).scaffoldBackgroundColor;

    // 文字和图标颜色（使用 Token）
    final textColor = SpitoutTokens.textPrimary(context);
    final iconColor = SpitoutTokens.iconPrimary(context);

    // 状态栏图标颜色：亮色模式用深色图标，暗黑模式用浅色图标
    final statusBarBrightness = statusBarIconBrightness ??
        (isDark ? Brightness.light : Brightness.dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        // edge-to-edge 模式(main.dart 开启)下 header 自己画到状态栏底下,
        // 状态栏保持透明即可 —— 不依赖 OEM 响应 setStatusBarColor
        // (华为 EMUI/鸿蒙会无视它,导致背景渗透不到状态栏)。
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        statusBarIconBrightness: statusBarBrightness,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: decoration ?? BoxDecoration(color: headerBg),
          child: Stack(
            children: [
              // 主内容
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (showTitleSection)
                  Padding(
                    padding: padding,
                    // 首行最小高度全局统一为 30：无 action 的页面（标题仅 ~19px）与
                    // 含功能键的页面（热区 30）行高尽量接近，标题垂直位置稳定；
                    // 内容不足 30 时垂直居中，超出（如无障碍大字体）时随内容增高。
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 30),
                      child: Row(
                      children: [
                        if (showBack) ...[
                          IconButton(
                            // 返回键规格全局统一：图标 20px、热区 30x30，
                            // 与 HeaderIconAction 完全一致（同为首行功能键）
                            icon: Icon(AppIcons.back, size: SpitoutDimens.icon20, color: iconColor),
                            onPressed: () => Navigator.of(context).maybePop(),
                            padding: const EdgeInsets.all(SpitoutDimens.p8),
                            constraints: const BoxConstraints(
                                minWidth: 30, minHeight: 30),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: SpitoutDimens.p8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题行：onTitleTap 非空时整行可点（涟漪裁切在圆角 8 内），
                              // 供首页月份/统计页账期等"标题即入口"的场景使用；
                              // 为 null 时退化为纯文本，无额外热区。
                              () {
                                final titleRow = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        style: titleStyle.copyWith(color: textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (titleTrailing != null) ...[
                                      const SizedBox(width: SpitoutDimens.p4),
                                      // 图标尺寸收归组件：固定 20px（与 HeaderIconAction 一致），
                                      // 调用方只传 IconData，杜绝各页面各自维护导致规格漂移。
                                      Icon(titleTrailing!, size: SpitoutDimens.icon20, color: iconColor),
                                    ],
                                    if (titleAction != null) ...[
                                      const SizedBox(width: SpitoutDimens.p4),
                                      // 标题隔壁的可点击功能键：复用调用方传入的 Widget
                                      // （HeaderIconAction 自带 20px / 30×30 统一规格）。
                                      titleAction!,
                                    ],
                                  ],
                                );
                                if (onTitleTap == null) return titleRow;
                                return Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: onTitleTap,
                                    borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                                    child: titleRow,
                                  ),
                                );
                              }(),
                              if (subtitle != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        subtitle!,
                                        style: subStyle.copyWith(
                                          color: SpitoutTokens.textSecondary(context),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (subtitleTrailing != null) ...[
                                      const SizedBox(width: SpitoutDimens.p4),
                                      // 图标尺寸收归组件：固定 20px，与标题箭头一致
                                      Icon(subtitleTrailing!, size: SpitoutDimens.icon20,
                                          color: SpitoutTokens.iconTertiary(context)),
                                    ]
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (center != null) ...[
                          const SizedBox(width: SpitoutDimens.p4),
                          DefaultTextStyle(
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: iconColor,
                            ) ??
                                SpitoutTextTokens.label(
                                  context,
                                ).copyWith(color: iconColor),
                            child: center!,
                          ),
                        ],
                        ...?actions,
                      ],
                      ),
                    ),
                  ),
                if (content != null)
                  Padding(
                    padding: padding,
                    child: DefaultTextStyle(
                      style: DefaultTextStyle.of(context).style.copyWith(
                        color: textColor,
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: iconColor),
                        child: content!,
                      ),
                    ),
                  ),
                    ?bottom,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 头部图标功能键：全局统一规格的 icon action。
///
/// 设计意图：统一封装头部 action，避免裸 `IconButton` 默认 48 热区把
/// 首行行高撑大到 48（与无 action 页面不一致）。规格固定为：
/// 图标 20px、热区 30x30（与首行最小高度 30 一致）；
/// [spinning] 为 true 时图标位替换为 20x20 转圈并禁用点击（刷新中态）。
class HeaderIconAction extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool spinning;

  const HeaderIconAction({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: spinning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: SpitoutDimens.icon20),
      tooltip: tooltip,
      onPressed: spinning ? null : onPressed,
      // 热区统一 30x30（图标 20 + 四周 0）：与首行最小高度 30 一致，
      // 含功能键的页面首行行高与纯文字页保持同一高度。
      padding: const EdgeInsets.all(0),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// 头部文字链功能键：全局统一规格的 text action。
///
/// 设计意图：全局唯一规格的头部文字链 —— 14px / w600 / 主题主色，
/// 紧凑热区，各页面统一调用。
class HeaderTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const HeaderTextAction({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p8, vertical: SpitoutDimens.p4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      child: Text(
        label,
        style: SpitoutTextTokens.body(context).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
