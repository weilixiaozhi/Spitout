import 'package:flutter/material.dart';

/// 全局色板唯一真相源。
///
/// 设计意图：[SpitoutTheme]（app_theme.dart）构造 [ThemeData] 与
/// [SpitoutTokens] 运行时取色均引用此处常量，杜绝「ThemeData 一份、
/// Token 一份」的双真相源隐患——改色只改这一处，亮暗与组件自动跟随。
abstract final class SpitoutColors {
  const SpitoutColors._();

  // ── 种子 / 主色 ──
  static const Color seed = Color(0xFF3F72AF);

  // ── 亮色 ──
  static const Color lightScaffold = Color(0xFFF9F7F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFEDF2F7);
  static const Color lightTextPrimary = Color(0xFF333333);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);
  static const Color lightInputBg = Color(0xFFF3F4F6);
  static const Color lightChip = Color(0xFFEEEEEE); // 对应 Colors.grey.shade200
  static const Color lightCategoryIconLight = Color(
    0xFFF5F5F5,
  ); // grey.shade100
  static const Color lightCategoryIcon = Color(0xFF616161); // grey.shade700
  static const Color lightDisabledBg = Color(0xFFE0E0E0); // grey.shade300
  static const Color lightDisabledControl = Color(0xFFE5E7EB);
  static const Color lightLink = Color(0xFF3B82F6);

  // ── 记账键盘（亮色）──
  static const Color lightKeypadBackground = Color(0xFFDEE0E7); // 键盘容器浅灰
  static const Color lightKeyDigit = Color(0xFFFFFFFF); // 数字/运算符白色色块
  static const Color lightKeyOther = Color(0xFFC0C3CC); // 日期/删除/完成等深灰

  // ── 暗色（shadcn/ui dark）──
  static const Color darkScaffold = Color(0xFF111827);
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkSurfaceSecondary = Color(0xFF374151);
  static const Color darkSurfaceMid = Color(0xFF3A3A3C);
  static const Color darkCategoryIcon = Color(0xFF48484A);
  static const Color darkIconCategory = Color(0xFFAEAEB2);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkBorder = Color(0xFFF3F4F6); // 配 withValues(alpha) 使用
  static const Color darkDisabledControl = Color(0xFF3C3C3E);
  static const Color darkLink = Color(0xFF60A5FA);

  // ── 记账键盘（暗色，与亮色亮度层级一致）──
  static const Color darkKeypadBackground = Color(0xFF151E2B); // 比 sheet 更深的灰
  static const Color darkKeyDigit = Color(0xFF374151); // 数字/运算符浅灰块
  static const Color darkKeyOther = Color(0xFF0D1522); // 日期/删除/完成等深色块

  // ── 语义色 ──
  static const Color successLight = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF34D399);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color errorLight = Color(0xFFD94A5B);
  static const Color errorDark = Color(0xFFF87171);

  // ── 品牌（亮暗一致）──
  static const Color brandLocal = Color(0xFF9E9E9E);
  static const Color brandSupabase = Color(0xFF3ECF8E);
  static const Color brandWebdav = Color(0xFFFF9800);
  static const Color brandS3 = Color(0xFF8B5CF6);
  static const Color brandCloud = Color(0xFF2196F3);

  // ── 英雄卡 ──
  static const Color cardHeroLight = Color(0xFF112D4E);
  static const Color cardHeroDark = Color(0xFF1E3A5F);
}

/// Spitout Design Token 系统
///
/// 设计理念：类似 CSS Design Tokens，通过语义化命名统一管理颜色。
/// 所有 UI 组件都应该使用 Token 而非直接使用颜色值。
///
/// Token 分类：
/// 1. Surface（背景色）- 页面、卡片、弹窗等背景
/// 2. Text（文字颜色）- 标题、正文、提示、禁用等
/// 3. Icon（图标颜色）- 主要、次要、提示图标
/// 4. Border（边框/分割线）- 卡片边框、列表分割线
/// 5. Semantic（语义色）- 成功、警告、错误、信息
/// 6. Interactive（交互色）- 按钮、链接、选中状态
/// 7. Brand（品牌图标色）- 各服务品牌固定色
///
/// 使用示例：
/// ```dart
/// Container(
///   color: SpitoutTokens.surface(context),
///   child: Text(
///     'Hello',
///     style: TextStyle(color: SpitoutTokens.textPrimary(context)),
///   ),
/// )
/// ```
class SpitoutTokens {
  // ========== 背景色 Token (Surface) ==========

  /// 页面背景色（Scaffold 背景）
  /// - 亮色模式：lightScaffold
  /// - 暗黑模式：darkScaffold
  static Color scaffoldBackground(BuildContext context) => isDark(context)
      ? SpitoutColors.darkScaffold
      : SpitoutColors.lightScaffold;

  /// 卡片背景色（贴在页面上的卡片）
  /// - 亮色模式：lightSurface
  /// - 暗黑模式：darkSurface
  static Color surface(BuildContext context) =>
      isDark(context) ? SpitoutColors.darkSurface : SpitoutColors.lightSurface;

  /// 次级背景色（嵌套卡片、输入框背景）
  /// - 亮色模式：lightSurfaceSecondary
  /// - 暗黑模式：darkSurfaceSecondary
  static Color surfaceSecondary(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurfaceSecondary
      : SpitoutColors.lightSurfaceSecondary;

  /// 悬浮卡片背景色（Dialog、BottomSheet、Dropdown 等）
  /// - 亮色模式：lightSurface
  /// - 暗黑模式：darkSurface
  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? SpitoutColors.darkSurface : SpitoutColors.lightSurface;

  /// PrimaryHeader 背景色
  /// - 亮色模式：页面底色（扁平化后 header 与页面融为一体）
  /// - 暗黑模式：darkScaffold
  static Color surfaceHeader(BuildContext context) => isDark(context)
      ? SpitoutColors.darkScaffold
      : scaffoldBackground(context);

  /// 英雄卡背景色（仅首页 + 账本页两张特殊卡片）
  /// - 亮色模式：cardHeroLight（深蓝，突出显示）
  /// - 暗黑模式：cardHeroDark（更亮的变体，确保在深色背景上有足够对比度）
  static Color cardHero(BuildContext context) => isDark(context)
      ? SpitoutColors.cardHeroDark
      : SpitoutColors.cardHeroLight;

  /// BottomSheet 背景色（金额输入等弹窗）
  /// - 亮色模式：lightSurface
  /// - 暗黑模式：darkSurface
  static Color surfaceSheet(BuildContext context) =>
      isDark(context) ? SpitoutColors.darkSurface : SpitoutColors.lightSurface;

  /// 键盘按钮背景色
  /// - 亮色模式：lightSurface
  /// - 暗黑模式：darkSurface
  static Color surfaceKey(BuildContext context) =>
      isDark(context) ? SpitoutColors.darkSurface : SpitoutColors.lightSurface;

  /// 记账键盘容器背景色
  /// - 亮色模式：lightKeypadBackground（浅灰 #DEE0E7）
  /// - 暗黑模式：darkKeypadBackground（比 sheet 更深的灰）
  static Color keypadBackground(BuildContext context) => isDark(context)
      ? SpitoutColors.darkKeypadBackground
      : SpitoutColors.lightKeypadBackground;

  /// 记账键盘数字（0-9）/运算符（+-×÷）按键背景色
  /// - 亮色模式：白色色块
  /// - 暗黑模式：浅灰块
  static Color keyDigit(BuildContext context) => isDark(context)
      ? SpitoutColors.darkKeyDigit
      : SpitoutColors.lightKeyDigit;

  /// 记账键盘其他按键背景色（日期 / 删除 / 完成等）
  /// - 亮色模式：lightKeyOther（#C0C3CC）
  /// - 暗黑模式：darkKeyOther（深色块）
  static Color keyOther(BuildContext context) => isDark(context)
      ? SpitoutColors.darkKeyOther
      : SpitoutColors.lightKeyOther;

  /// 键盘次级按钮背景色（日期、+/-等）
  /// - 亮色模式：lightSurfaceSecondary
  /// - 暗黑模式：darkSurfaceSecondary
  static Color surfaceKeySecondary(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurfaceSecondary
      : SpitoutColors.lightSurfaceSecondary;

  /// 禁用按钮背景色
  /// - 亮色模式：lightDisabledBg
  /// - 暗黑模式：darkSurfaceSecondary
  static Color surfaceDisabled(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurfaceSecondary
      : SpitoutColors.lightDisabledBg;

  /// 输入框背景色
  /// - 亮色模式：lightInputBg
  /// - 暗黑模式：darkSurfaceSecondary
  static Color surfaceInput(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurfaceSecondary
      : SpitoutColors.lightInputBg;

  /// 标签/Chip 背景色（未选中状态）
  /// - 亮色模式：lightChip
  /// - 暗黑模式：darkSurfaceSecondary
  static Color surfaceChip(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurfaceSecondary
      : SpitoutColors.lightChip;

  /// 胶囊切换器背景色（不透明）
  /// - 亮色模式：lightChip（与 6% 黑叠白底视觉一致但不透明，
  ///   避免悬浮胶囊透出下层内容——统计页周/月/年父级 Tab 即悬浮场景)
  /// - 暗黑模式：darkSurfaceSecondary
  static Color surfaceCapsule(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurfaceSecondary
      : SpitoutColors.lightChip;

  /// 弹出层/浮层内卡片背景色（如二级分类选择）
  /// - 亮色模式：lightSurface
  /// - 暗黑模式：darkSurfaceMid
  static Color surfacePopoverCard(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurfaceMid
      : SpitoutColors.lightSurface;

  /// 分类图标背景色（未选中状态）
  /// - 亮色模式：lightChip
  /// - 暗黑模式：darkCategoryIcon
  static Color surfaceCategoryIcon(BuildContext context) => isDark(context)
      ? SpitoutColors.darkCategoryIcon
      : SpitoutColors.lightChip;

  /// 分类图标背景色 - 浅色版（二级分类用）
  /// - 亮色模式：lightCategoryIconLight
  /// - 暗黑模式：darkSurfaceMid
  static Color surfaceCategoryIconLight(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurfaceMid
      : SpitoutColors.lightCategoryIconLight;

  /// 分类图标颜色（未选中状态）
  /// - 亮色模式：lightCategoryIcon
  /// - 暗黑模式：darkIconCategory
  static Color iconCategory(BuildContext context) => isDark(context)
      ? SpitoutColors.darkIconCategory
      : SpitoutColors.lightCategoryIcon;

  /// 选中状态背景色（列表项选中、高亮）
  /// - 亮色模式：主题色 8% 透明度
  /// - 暗黑模式：主题色 15% 透明度
  static Color surfaceSelected(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);

  /// 悬停/按压状态背景色
  /// - 亮色模式：rgba(0,0,0,0.04)
  /// - 暗黑模式：rgba(255,255,255,0.08)
  static Color surfaceHover(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.04);

  /// 反转背景色（FAB、浮动按钮等需要"反色"的组件背景）
  /// - 亮色模式：#000000 (纯黑)
  /// - 暗黑模式：#FFFFFF (纯白)
  static Color surfaceInverse(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black;

  // ========== 文字颜色 Token (Text) ==========

  /// 主要文字颜色（标题、正文）
  /// - 亮色模式：lightTextPrimary
  /// - 暗黑模式：darkTextPrimary
  static Color textPrimary(BuildContext context) => isDark(context)
      ? SpitoutColors.darkTextPrimary
      : SpitoutColors.lightTextPrimary;

  /// 次要文字颜色（副标题、说明文字）
  /// - 亮色模式：lightTextSecondary
  /// - 暗黑模式：darkTextSecondary
  static Color textSecondary(BuildContext context) => isDark(context)
      ? SpitoutColors.darkTextSecondary
      : SpitoutColors.lightTextSecondary;

  /// 提示文字颜色（placeholder、hint、辅助说明）
  /// - 亮色模式：lightTextTertiary
  /// - 暗黑模式：rgba(255,255,255,0.54)
  static Color textTertiary(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.54)
      : SpitoutColors.lightTextTertiary;

  /// 禁用文字颜色
  /// - 亮色模式：rgba(0,0,0,0.26)
  /// - 暗黑模式：rgba(255,255,255,0.38)
  static Color textDisabled(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.38)
      : Colors.black.withValues(alpha: 0.26);

  /// 反色文字（用于深色背景上的白色文字）
  /// - 亮色模式：#FFFFFF
  /// - 暗黑模式：#FFFFFF
  static Color textOnPrimary(BuildContext context) => Colors.white;

  /// 链接文字颜色
  /// - 亮色模式：lightLink
  /// - 暗黑模式：darkLink
  static Color textLink(BuildContext context) =>
      isDark(context) ? SpitoutColors.darkLink : SpitoutColors.lightLink;

  /// Header 内主要文字颜色（用于 PrimaryHeader 内的内容）
  /// - 亮色模式：#111827（在浅底 header 上用深色文字）
  /// - 暗黑模式：#FFFFFF（在黑色背景上用白色文字）
  static Color textOnHeader(BuildContext context) => textPrimary(context);

  /// Header 内次要文字颜色（用于 PrimaryHeader 内的副标题）
  /// - 亮色模式：rgba(0,0,0,0.54)（在浅底 header 上用半透明黑）
  /// - 暗黑模式：rgba(255,255,255,0.7)（在黑色背景上用半透明白）
  static Color textOnHeaderSecondary(BuildContext context) =>
      textSecondary(context);

  /// 反转背景上的前景色（放在 surfaceInverse 上的图标/文字颜色）
  /// - 亮色模式：#FFFFFF (纯白，在黑色 FAB 上显示白图标)
  /// - 暗黑模式：#000000 (纯黑，在白色 FAB 上显示黑图标)
  static Color onSurfaceInverse(BuildContext context) =>
      isDark(context) ? Colors.black : Colors.white;

  // ========== 图标颜色 Token (Icon) ==========

  /// 主要图标颜色
  /// - 亮色模式：#000000 (87% opacity)
  /// - 暗黑模式：#FFFFFF (白色)
  static Color iconPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black87;

  /// 次要图标颜色
  /// - 亮色模式：rgba(0,0,0,0.54)
  /// - 暗黑模式：rgba(255,255,255,0.7)
  static Color iconSecondary(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.7)
      : Colors.black.withValues(alpha: 0.54);

  /// 提示图标颜色
  /// - 亮色模式：rgba(0,0,0,0.38)
  /// - 暗黑模式：rgba(255,255,255,0.54)
  static Color iconTertiary(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.54)
      : Colors.black.withValues(alpha: 0.38);

  // ========== 边框/分割线 Token (Border) ==========

  /// 分割线颜色
  /// - 亮色模式：rgba(0,0,0,0.06)
  /// - 暗黑模式：rgba(243,244,246,0.10) (shadcn border dark)
  static Color divider(BuildContext context) => isDark(context)
      ? SpitoutColors.darkBorder.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.06);

  /// 边框颜色（卡片边框）
  /// - 亮色模式：transparent（使用阴影）
  /// - 暗黑模式：rgba(243,244,246,0.10) (shadcn border dark)
  static Color border(BuildContext context) => isDark(context)
      ? SpitoutColors.darkBorder.withValues(alpha: 0.10)
      : Colors.transparent;

  /// 强调边框颜色
  /// - 亮色模式：rgba(0,0,0,0.12)
  /// - 暗黑模式：rgba(243,244,246,0.10) (shadcn border dark)
  static Color borderStrong(BuildContext context) => isDark(context)
      ? SpitoutColors.darkBorder.withValues(alpha: 0.10)
      : Colors.black.withValues(alpha: 0.12);

  /// 主题色边框（用于卡片等）
  /// - 亮色模式：transparent
  /// - 暗黑模式：主题色 30% 透明度
  static Color borderThemed(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
      : Colors.transparent;

  // ========== 卡片边框 Token (Card Border) ==========

  /// 卡片外边框颜色
  /// - 亮色模式：transparent（使用阴影）
  /// - 暗黑模式：transparent（去掉边框）
  static Color cardOuterBorderColor(BuildContext context) => Colors.transparent;

  /// 卡片外边框宽度
  /// - 亮色模式：0
  /// - 暗黑模式：0
  static double cardOuterBorderWidth(BuildContext context) => 0;

  /// 卡片内部分割线颜色
  /// - 亮色模式：rgba(0,0,0,0.06)
  /// - 暗黑模式：transparent（去掉分割线）
  static Color cardInnerDividerColor(BuildContext context) => isDark(context)
      ? Colors.transparent
      : Colors.black.withValues(alpha: 0.06);

  /// 卡片内部分割线高度
  /// - 亮色模式：1
  /// - 暗黑模式：0（去掉分割线）
  static double cardInnerDividerHeight(BuildContext context) =>
      isDark(context) ? 0 : 1;

  /// 明细列表「天」之间的分隔线。区别于卡片内 item 分隔(cardInnerDivider
  /// 暗黑不显示):明细 day 分隔亮暗都显示细线(暗黑 white 8% / 亮 black 6%)。
  static double listDayDividerHeight(BuildContext context) => 1;
  static Color listDayDividerColor(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.06);

  /// 卡片内部分割线组件
  /// 封装了 height、thickness、color 三个属性
  /// 设置项分割线。默认左缩进 48(对齐 AppListTile 内容:icon 容器 36 + 间距 12),
  /// 让线避开左侧 icon。section 顶部 / 卡片外等需要全宽的场景传 indent: 0。
  static Widget cardDivider(BuildContext context, {double indent = 48}) =>
      Divider(
        height: cardInnerDividerHeight(context),
        thickness: cardInnerDividerHeight(context),
        color: cardInnerDividerColor(context),
        indent: indent,
      );

  // ========== 主题色 Token (Theme) ==========

  /// 主题色（自动适配用户选择的颜色）
  /// - 亮色模式：用户选择的主题色（如 #F8C91C）
  /// - 暗黑模式：深色版本（如 #C49A15）
  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 辅助色
  static Color secondary(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  // ========== 语义色 Token (Semantic) ==========

  /// 成功状态颜色
  /// - 亮色模式：successLight
  /// - 暗黑模式：successDark
  static Color success(BuildContext context) =>
      isDark(context) ? SpitoutColors.successDark : SpitoutColors.successLight;

  /// 警告状态颜色
  /// - 亮色模式：warningLight
  /// - 暗黑模式：warningDark
  static Color warning(BuildContext context) =>
      isDark(context) ? SpitoutColors.warningDark : SpitoutColors.warningLight;

  /// 错误状态颜色（shadcn destructive）
  /// - 亮色模式：errorLight
  /// - 暗黑模式：errorDark
  static Color error(BuildContext context) =>
      isDark(context) ? SpitoutColors.errorDark : SpitoutColors.errorLight;

  /// 信息提示颜色
  /// - 亮色模式：lightLink
  /// - 暗黑模式：darkLink
  static Color info(BuildContext context) =>
      isDark(context) ? SpitoutColors.darkLink : SpitoutColors.lightLink;

  // ========== 交互色 Token (Interactive) ==========

  /// 主按钮背景色
  /// - 亮色模式：主题色
  /// - 暗黑模式：主题色
  static Color buttonPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 次要按钮背景色
  /// - 亮色模式：transparent
  /// - 暗黑模式：transparent
  static Color buttonSecondary(BuildContext context) => Colors.transparent;

  /// 主按钮文字颜色
  /// - 亮色模式：#FFFFFF
  /// - 暗黑模式：#FFFFFF
  static Color buttonPrimaryText(BuildContext context) => Colors.white;

  /// 次要按钮文字颜色
  /// - 亮色模式：主题色
  /// - 暗黑模式：主题色
  static Color buttonSecondaryText(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 禁用按钮背景色
  /// - 亮色模式：lightDisabledControl
  /// - 暗黑模式：darkDisabledControl
  static Color buttonDisabled(BuildContext context) => isDark(context)
      ? SpitoutColors.darkDisabledControl
      : SpitoutColors.lightDisabledControl;

  /// Switch 开启状态轨道颜色
  /// - 亮色模式：主题色
  /// - 暗黑模式：主题色
  static Color switchActiveTrack(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Switch 关闭状态轨道颜色
  /// - 亮色模式：lightDisabledControl
  /// - 暗黑模式：darkDisabledControl
  static Color switchInactiveTrack(BuildContext context) => isDark(context)
      ? SpitoutColors.darkDisabledControl
      : SpitoutColors.lightDisabledControl;

  // ========== 品牌图标色 Token (Brand Icons) ==========
  // 这些颜色是各服务的品牌色，在亮暗模式下保持一致

  /// 本地存储图标色（灰色）
  static const Color brandLocal = SpitoutColors.brandLocal;

  /// Supabase 品牌色（绿色）
  static const Color brandSupabase = SpitoutColors.brandSupabase;

  /// WebDAV 品牌色（橙色）
  static const Color brandWebdav = SpitoutColors.brandWebdav;

  /// S3 存储品牌色（紫色）
  static const Color brandS3 = SpitoutColors.brandS3;

  /// 云服务通用图标色（蓝色）
  static const Color brandCloud = SpitoutColors.brandCloud;

  // ========== 状态指示器 Token (Status Indicators) ==========

  /// 在线/连接成功指示色
  /// - 亮色模式：successLight
  /// - 暗黑模式：successDark
  static Color statusOnline(BuildContext context) => success(context);

  /// 离线/断开连接指示色
  /// - 亮色模式：lightTextTertiary
  /// - 暗黑模式：rgba(255,255,255,0.38)
  static Color statusOffline(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.38)
      : SpitoutColors.lightTextTertiary;

  /// 待处理/等待中指示色
  /// - 亮色模式：warningLight
  /// - 暗黑模式：warningDark
  static Color statusPending(BuildContext context) => warning(context);

  // ========== 图表/统计色 Token (Chart Colors) ==========

  /// 支出颜色
  /// - 亮色模式：errorLight
  /// - 暗黑模式：errorDark
  static Color chartExpense(BuildContext context) => error(context);

  // ========== 遮罩层 Token (Overlay) ==========

  /// 模态遮罩层颜色
  /// - 亮色模式：rgba(0,0,0,0.5)
  /// - 暗黑模式：rgba(0,0,0,0.7)
  static Color overlay(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.7)
      : Colors.black.withValues(alpha: 0.5);

  /// 轻量遮罩层颜色（用于下拉刷新等）
  /// - 亮色模式：rgba(0,0,0,0.05)
  /// - 暗黑模式：rgba(255,255,255,0.05)
  static Color overlayLight(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.05);

  // ========== 悬浮 Tab 栏 Token (Floating Tab Bar) ==========

  /// 悬浮 Tab 栏背景色
  /// - 亮色模式：白色 95% 不透明
  /// - 暗黑模式：darkSurface 95% 不透明
  static Color tabBarBackground(BuildContext context) => isDark(context)
      ? SpitoutColors.darkSurface.withValues(alpha: 0.95)
      : Colors.white.withValues(alpha: 0.95);

  /// 悬浮 Tab 栏阴影
  static List<BoxShadow> get tabBarShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  // ========== 辅助方法 ==========

  /// 判断当前是否为暗黑模式
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// 根据语义获取颜色（用于动态状态）
  static Color semantic(BuildContext context, String type) {
    switch (type) {
      case 'success':
        return success(context);
      case 'warning':
        return warning(context);
      case 'error':
        return error(context);
      case 'info':
        return info(context);
      default:
        return textPrimary(context);
    }
  }
}
