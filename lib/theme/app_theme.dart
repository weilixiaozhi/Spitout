import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'colors.dart';
import 'typography.dart';

/// 全局主题定义。
///
/// 主题色系统：
/// - 使用原生 [ColorScheme.fromSeed] 生成亮暗主题，零第三方依赖。
/// - 主色 `#3F72AF` 是唯一定义，全 app 通过 `Theme.of(context).colorScheme.primary`
///   读取，实现"主色单一真相源"。
/// - 亮色页面底色、卡片表面、文字色等全部引用 [SpitoutColors]，
///   与 [SpitoutTokens] 运行时取色共享同一份常量，消除双真相源。
/// - `main.dart` 只需调用 `SpitoutTheme.lightTheme()` / `darkTheme()` 即可。
class SpitoutTheme {
  /// 主色 / 种子色：引用 [SpitoutColors.seed]（#3F72AF，蓝色）。
  ///
  /// 设计意图：全 app 唯一的主色定义。
  /// `ColorScheme.fromSeed` 以此为种子派生完整色板，
  /// 再通过 `copyWith(primary: seedColor)` pin 回确保值不偏移。
  static const Color seedColor = SpitoutColors.seed;

  /// 亮色主题：基于 [ColorScheme.fromSeed] 生成，pin 主色 + 页面底色 + 卡片表面，
  /// 并内联全部按钮 / 卡片 / 对话框 / 列表项等子主题。
  static ThemeData lightTheme({TargetPlatform? platform}) {
    final base = ThemeData.light();
    final pf = platform ?? defaultTargetPlatform;
    final isIOS = pf == TargetPlatform.iOS || pf == TargetPlatform.macOS;

    // 从种子色派生完整亮色 ColorScheme，再 pin 关键色确保不偏移
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: seedColor, // pin 主色为 #3F72AF
      surface: SpitoutColors.lightSurface, // pin 卡片表面为纯白
    );

    final textTheme = SpitoutTypography.buildBase(base.textTheme, isIOS: isIOS)
        .apply(
            bodyColor: SpitoutColors.lightTextPrimary,
            displayColor: SpitoutColors.lightTextPrimary);

    return base.copyWith(
      colorScheme: cs,
      primaryColor: seedColor,
      scaffoldBackgroundColor: SpitoutColors.lightScaffold,
      textTheme: textTheme,
      // 全局页面转场：左右滑动 + 线性曲线（无加速减速），全平台统一。
      // 设计意图：取代 Material 默认的缩放/淡入，向小红书等大众 App 的平移切换看齐。
      // 所有 MaterialPageRoute 自动走该配置，无需各调用点单独设置。
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _SlidePageTransitionsBuilder(),
        TargetPlatform.iOS: _SlidePageTransitionsBuilder(),
        TargetPlatform.macOS: _SlidePageTransitionsBuilder(),
        TargetPlatform.windows: _SlidePageTransitionsBuilder(),
        TargetPlatform.linux: _SlidePageTransitionsBuilder(),
        TargetPlatform.fuchsia: _SlidePageTransitionsBuilder(),
      }),
      // 亮色分割线：极浅黑
      dividerColor: Colors.black.withValues(alpha: 0.06),
      appBarTheme: const AppBarTheme(
        backgroundColor: SpitoutColors.lightSurface,
        foregroundColor: SpitoutColors.lightTextPrimary,
        elevation: 0.0,
        centerTitle: true,
      ),
      // 列表项紧凑样式，图标用深灰
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        iconColor: Colors.black87,
      ),
      // 对话框：白底 + 圆角 + 深灰标题/正文
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: SpitoutColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleMedium?.copyWith(
            color: SpitoutColors.lightTextPrimary,
            fontWeight: FontWeight.w600),
        contentTextStyle: textTheme.bodyMedium
            ?.copyWith(color: SpitoutColors.lightTextSecondary),
      ),
      // 文字按钮：主色文字
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seedColor,
          textStyle: textTheme.labelLarge,
        ),
      ),
      // 填充按钮：主色背景 + 白字 + 圆角
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      // 次按钮（描边按钮）：M3 默认描边是灰色，这里显式指定为主色描边 + 主色文字
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: seedColor,
          side: BorderSide(color: seedColor),
        ),
      ),
      // FAB：主色背景 + 白字
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
      ),
      // 卡片：白底 + 无阴影 + 圆角 + 无外边距
      cardTheme: base.cardTheme.copyWith(
        color: SpitoutColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      // 全局输入框主题：色块样式（filled 背景 + 无描边圆角），
      // 替代原先各处散用的 OutlineInputBorder 描边样式，统一视觉。
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SpitoutColors.lightInputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: SpitoutColors.errorLight,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: SpitoutColors.errorLight,
            width: 1,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  /// 暗色主题：基于 [ColorScheme.fromSeed] 生成，pin 主色，
  /// 页面背景为 shadcn dark 深蓝灰 `#111827`（非纯黑）。
  /// 按钮等子主题与亮色保持一致的主色方案。
  static ThemeData darkTheme({TargetPlatform? platform}) {
    final base = ThemeData.dark();
    final pf = platform ?? defaultTargetPlatform;
    final isIOS = pf == TargetPlatform.iOS || pf == TargetPlatform.macOS;

    // 从种子色派生完整暗色 ColorScheme，pin 主色确保亮暗一致
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: seedColor, // pin 主色为 #3F72AF（与亮色一致）
    );

    // shadcn/ui 暗色 token：foreground darkTextPrimary（非纯白，降低对比刺眼感）
    final textTheme = SpitoutTypography.buildBase(base.textTheme, isIOS: isIOS)
        .apply(
            bodyColor: SpitoutColors.darkTextPrimary,
            displayColor: SpitoutColors.darkTextPrimary);

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: cs,
      primaryColor: seedColor,
      // shadcn/ui 暗色 token：background darkScaffold（深蓝灰，非纯黑）
      scaffoldBackgroundColor: SpitoutColors.darkScaffold,
      textTheme: textTheme,
      // 全局页面转场：左右滑动 + 线性曲线（无加速减速），与亮色保持一致。
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _SlidePageTransitionsBuilder(),
        TargetPlatform.iOS: _SlidePageTransitionsBuilder(),
        TargetPlatform.macOS: _SlidePageTransitionsBuilder(),
        TargetPlatform.windows: _SlidePageTransitionsBuilder(),
        TargetPlatform.linux: _SlidePageTransitionsBuilder(),
        TargetPlatform.fuchsia: _SlidePageTransitionsBuilder(),
      }),
      // shadcn/ui 暗色 token：card/popover darkSurface，foreground darkTextPrimary
      appBarTheme: const AppBarTheme(
        backgroundColor: SpitoutColors.darkScaffold,
        foregroundColor: SpitoutColors.darkTextPrimary,
        elevation: 0.0,
        centerTitle: true,
        iconTheme: IconThemeData(color: SpitoutColors.darkTextPrimary),
      ),
      // 列表项紧凑样式，图标用白色
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        iconColor: Colors.white,
      ),
      // 对话框：shadcn/ui 暗色 card darkSurface + 圆角 + foreground/mutedForeground
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: SpitoutColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleMedium?.copyWith(
            color: SpitoutColors.darkTextPrimary, fontWeight: FontWeight.w600),
        contentTextStyle: textTheme.bodyMedium
            ?.copyWith(color: SpitoutColors.darkTextSecondary),
      ),
      // 文字按钮：主色文字
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seedColor,
          textStyle: textTheme.labelLarge,
        ),
      ),
      // 填充按钮：主色背景 + 白字 + 圆角
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      // 次按钮（描边按钮）：主色描边 + 主色文字
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: seedColor,
          side: BorderSide(color: seedColor),
        ),
      ),
      // FAB：主色背景 + 白字
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
      ),
      // 暗色卡片：shadcn/ui card darkSurface + border rgba(243,244,246,0.10)
      cardTheme: CardThemeData(
        color: SpitoutColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: SpitoutColors.darkBorder.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
      ),
      // 暗色分割线：shadcn/ui border rgba(243,244,246,0.10)
      dividerTheme: DividerThemeData(
        color: SpitoutColors.darkBorder.withValues(alpha: 0.10),
        thickness: 1,
      ),
      // 全局输入框主题：色块样式（filled 背景 + 无描边圆角），
      // 替代原先各处散用的 OutlineInputBorder 描边样式，统一视觉。
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SpitoutColors.darkSurfaceSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: SpitoutColors.errorDark,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: SpitoutColors.errorDark,
            width: 1,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      iconTheme: const IconThemeData(
        color: SpitoutColors.darkTextPrimary,
      ),
    );
  }
}

/// 全局页面转场 Builder：左右滑动 + 线性曲线。
///
/// 设计意图：取代 Material 默认的缩放淡入与 iOS 默认的带 ease 曲线滑动，
/// 采用纯线性（`Curves.linear`）实现"匀速平移"，避免任何加速/减速感，
/// 视觉效果对标小红书等大众 App 的页面切换。
///
/// 动画时长由 `appPageRoute`（`lib/widgets/app_route.dart`）统一覆盖为 200ms，
/// 本 Builder 仅负责转场的视觉位移效果，不改变时长。
class _SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 入场页面从右侧 100% 平移到 0（从右向左滑入）；
    // 出场时反向（从左向右滑出）。全程线性，无加速减速。
    const curve = Curves.linear;

    // 主页面（新页面）水平位移动画：从右侧滑入到原位
    final pageTween = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: curve));

    // 次要页面（被覆盖的旧页面）轻微左移，保持全可见不缩放，
    // 实现"前页让位"的视差效果，与小红书等大众 App 一致。
    final secondaryPageTween = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0.0),
    ).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: secondaryAnimation.drive(secondaryPageTween),
      child: SlideTransition(
        position: animation.drive(pageTween),
        child: child,
      ),
    );
  }
}
