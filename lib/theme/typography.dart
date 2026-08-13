import 'package:flutter/material.dart';

import 'colors.dart';

/// 文本样式令牌：全局统一字号与字重
class SpitoutTextTokens {
  // 标题：用于列表主标题、条目标题
  static TextStyle title(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            color: SpitoutTokens.textPrimary(ctx),
          ) ??
      TextStyle(
          fontSize: 16, color: SpitoutTokens.textPrimary(ctx), fontWeight: FontWeight.w400);

  // 强调标题：用于统计数字等需要比普通列表标题更醒目的场景
  static TextStyle strongTitle(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            color: SpitoutTokens.textPrimary(ctx),
            fontWeight: FontWeight.w600,
          ) ??
      TextStyle(
          fontSize: 16, color: SpitoutTokens.textPrimary(ctx), fontWeight: FontWeight.w600);

  // 加粗标题：用于极强强调（如大额数字/主标题）
  static TextStyle boldTitle(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            fontSize: 18,
            color: SpitoutTokens.textPrimary(ctx),
            fontWeight: FontWeight.w800,
          ) ??
      TextStyle(
          fontSize: 18, color: SpitoutTokens.textPrimary(ctx), fontWeight: FontWeight.w800);

  // 正文：用于一般性文字
  static TextStyle body(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: SpitoutTokens.textPrimary(ctx),
          ) ??
      TextStyle(fontSize: 14, color: SpitoutTokens.textPrimary(ctx));

  // 标签/说明：用于次要说明、辅助信息
  static TextStyle label(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelMedium?.copyWith(
            fontSize: 12,
            color: SpitoutTokens.textSecondary(ctx),
          ) ??
      TextStyle(fontSize: 12, color: SpitoutTokens.textSecondary(ctx));

  // 小字/角标：用于时间戳、辅助标注（10px，颜色取 textSecondary）
  static TextStyle caption(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: SpitoutTokens.textSecondary(ctx),
          ) ??
      TextStyle(fontSize: 10, color: SpitoutTokens.textSecondary(ctx));

  // 大额数字 display 系列：22 / 26 / 32px，w800，用于金额/统计大数
  static TextStyle display1(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            fontSize: 22,
            color: SpitoutTokens.textPrimary(ctx),
            fontWeight: FontWeight.w800,
          ) ??
      TextStyle(
          fontSize: 22, color: SpitoutTokens.textPrimary(ctx), fontWeight: FontWeight.w800);

  static TextStyle display2(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            fontSize: 26,
            color: SpitoutTokens.textPrimary(ctx),
            fontWeight: FontWeight.w800,
          ) ??
      TextStyle(
          fontSize: 26, color: SpitoutTokens.textPrimary(ctx), fontWeight: FontWeight.w800);

  static TextStyle display3(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            fontSize: 32,
            color: SpitoutTokens.textPrimary(ctx),
            fontWeight: FontWeight.w800,
          ) ??
      TextStyle(
          fontSize: 32, color: SpitoutTokens.textPrimary(ctx), fontWeight: FontWeight.w800);
}

// ============================================================================
// 字体令牌 (Typography Tokens)
// ============================================================================

/// 字体配置令牌
class SpitoutTypography {
  static bool useBundledFonts = false; // 已禁用打包字体，使用系统字体

  // Primary Latin family when bundled
  static const String bundledLatin = 'Inter';
  // Primary Chinese family when bundled
  static const String bundledCJK = 'NotoSansSC';
  // iOS system Chinese font
  static const String systemCJKiOS = 'PingFang SC';

  /// 构建基础文本主题
  static TextTheme buildBase(TextTheme base, {required bool isIOS}) {
    final bodyW = FontWeight.w400;
    final titleW = FontWeight.w600;
    final useBundledHere = useBundledFonts && !isIOS;
    final latin =
        useBundledHere ? bundledLatin : (isIOS ? 'Helvetica Neue' : 'Roboto');
    final cjk =
        useBundledHere ? bundledCJK : (isIOS ? systemCJKiOS : 'NotoSans');
    final familyFallback = <String>{
      latin,
      cjk,
      'PingFang SC',
      'Helvetica Neue',
      'Roboto',
      'Arial'
    };

    TextStyle merge(TextStyle? src, double size, FontWeight w,
        {double? height}) {
      return (src ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: w,
        height: height ?? 1.25,
        fontFamily: latin,
        fontFamilyFallback: familyFallback.toList(),
      );
    }

    return base.copyWith(
      bodySmall: merge(base.bodySmall, 12, bodyW),
      bodyMedium: merge(base.bodyMedium, 14, bodyW),
      bodyLarge: merge(base.bodyLarge, 14, bodyW, height: 1.28),
      labelLarge: merge(base.labelLarge, 13, FontWeight.w600),
      titleMedium: merge(base.titleMedium, 15, FontWeight.w500),
      titleLarge: merge(base.titleLarge, 18, titleW, height: 1.3),
      headlineSmall: merge(base.headlineSmall, 20, titleW, height: 1.3),
    );
  }
}
