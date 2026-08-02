import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/theme/app_theme.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/divider.dart';

/// SpitoutTokens 亮/暗取色 + SpitoutDivider context 参数化测试。
///
/// 覆盖本次重构阶段三/四涉及的逻辑：
/// - SpitoutTokens 各语义取色在亮/暗主题下返回 SpitoutColors 对应常量；
/// - SpitoutDivider.thin/short 改为接收 BuildContext 后用 divider(context) 取色
///   （阶段四：暗黑模式下分割线颜色不再回退到亮色静态兜底）。
void main() {
  late ThemeData lightTheme;
  late ThemeData darkTheme;

  setUp(() {
    lightTheme = SpitoutTheme.lightTheme(platform: TargetPlatform.android);
    darkTheme = SpitoutTheme.darkTheme(platform: TargetPlatform.android);
  });

  /// 把 ThemeData 直接挂到 widget 树并返回其子树 context。
  ///
  /// 设计意图：SpitoutTokens 仅依赖 Theme.of(context).brightness 取色，不依赖
  /// Material。这里绕过 MaterialApp——MaterialApp 会依据 MediaQuery.platformBrightness
  /// 在 theme/darkTheme 间选择，测试默认平台亮度为 light，暗色主题极易被误判成
  /// 亮色。直接用 Theme(data: theme) 包裹能确保 Theme.of(context).brightness
  /// 精确等于传入主题的 brightness。
  ///
  /// 重要：每个测试内如需同时验证亮/暗，必须「先 pump 亮色断言、再 pump 暗色断言」
  /// 顺序执行，绝不能两次 pump 后同时保留两个 context——第二次 pump 会销毁整个
  /// widget 树，使先前的 context 失效，Theme.of(失效context) 会返回错误值。
  Future<BuildContext> pumpContext(WidgetTester tester, ThemeData theme) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Theme(
        data: theme,
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  group('SpitoutTokens 亮/暗取色', () {
    testWidgets('isDark 正确识别亮/暗主题', (tester) async {
      var ctx = await pumpContext(tester, lightTheme);
      expect(SpitoutTokens.isDark(ctx), isFalse);
      // 重新 pump 暗色主题（旧亮色 ctx 已失效，不再引用）。
      ctx = await pumpContext(tester, darkTheme);
      expect(SpitoutTokens.isDark(ctx), isTrue);
    });

    testWidgets('scaffoldBackground / surface 亮暗值正确', (tester) async {
      var ctx = await pumpContext(tester, lightTheme);
      expect(SpitoutTokens.scaffoldBackground(ctx), SpitoutColors.lightScaffold);
      expect(SpitoutTokens.surface(ctx), SpitoutColors.lightSurface);
      ctx = await pumpContext(tester, darkTheme);
      expect(SpitoutTokens.scaffoldBackground(ctx), SpitoutColors.darkScaffold);
      expect(SpitoutTokens.surface(ctx), SpitoutColors.darkSurface);
    });

    testWidgets('textPrimary / textSecondary 亮暗值正确', (tester) async {
      var ctx = await pumpContext(tester, lightTheme);
      expect(SpitoutTokens.textPrimary(ctx), SpitoutColors.lightTextPrimary);
      expect(SpitoutTokens.textSecondary(ctx), SpitoutColors.lightTextSecondary);
      // textTertiary 暗色为 rgba(255,255,255,0.54)（非 pin 常量），仅断言亮色侧。
      expect(SpitoutTokens.textTertiary(ctx), SpitoutColors.lightTextTertiary);
      ctx = await pumpContext(tester, darkTheme);
      expect(SpitoutTokens.textPrimary(ctx), SpitoutColors.darkTextPrimary);
      expect(SpitoutTokens.textSecondary(ctx), SpitoutColors.darkTextSecondary);
    });

    /// 阶段四核心回归点：divider 必须随 context 取色，
    /// 暗色不再错误地指向亮色静态兜底。
    testWidgets('divider 亮暗值正确（暗色不再用亮色静态兜底）', (tester) async {
      var ctx = await pumpContext(tester, lightTheme);
      expect(SpitoutTokens.divider(ctx), Colors.black.withValues(alpha: 0.06));
      ctx = await pumpContext(tester, darkTheme);
      expect(SpitoutTokens.divider(ctx),
          SpitoutColors.darkBorder.withValues(alpha: 0.10));
    });
  });

  group('SpitoutDivider 参数化（阶段四）', () {
    testWidgets('thin/short 接收 BuildContext 并返回带正确颜色的 Divider',
        (tester) async {
      final ctx = await pumpContext(tester, lightTheme);
      final thin = SpitoutDivider.thin(ctx);
      final short = SpitoutDivider.short(ctx, indent: 8, endIndent: 8);
      expect(thin, isA<Divider>());
      expect(short, isA<Divider>());
      // 颜色必须等于 divider(context) 取色，确认参数化生效。
      expect(thin.color, SpitoutTokens.divider(ctx));
      expect(short.color, SpitoutTokens.divider(ctx));
    });
  });
}
