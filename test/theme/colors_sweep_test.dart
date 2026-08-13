// SpitoutTokens 全量 token 扫描测试。
//
// 需求锚点：所有 token 在亮/暗主题下均可用且返回对应类型。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/theme/app_theme.dart';
import 'package:spitout/theme/colors.dart';

void main() {
  late ThemeData lightTheme;
  late ThemeData darkTheme;

  setUp(() {
    lightTheme = SpitoutTheme.lightTheme(platform: TargetPlatform.android);
    darkTheme = SpitoutTheme.darkTheme(platform: TargetPlatform.android);
  });

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

  testWidgets('亮/暗全量 token 扫描', (tester) async {
    for (final theme in [lightTheme, darkTheme]) {
      final ctx = await pumpContext(tester, theme);

      expect(SpitoutTokens.surfaceSheet(ctx), isA<Color>());
      expect(SpitoutTokens.keypadBackground(ctx), isA<Color>());
      expect(SpitoutTokens.keyDigit(ctx), isA<Color>());
      expect(SpitoutTokens.surfaceInput(ctx), isA<Color>());
      expect(SpitoutTokens.surfaceChip(ctx), isA<Color>());
      expect(SpitoutTokens.surfaceCapsule(ctx), isA<Color>());
      expect(SpitoutTokens.surfaceCategoryIcon(ctx), isA<Color>());
      expect(SpitoutTokens.surfaceCategoryIconLight(ctx), isA<Color>());
      expect(SpitoutTokens.iconCategory(ctx), isA<Color>());
      expect(SpitoutTokens.surfaceSelected(ctx), isA<Color>());
      expect(SpitoutTokens.surfaceInverse(ctx), isA<Color>());

      expect(SpitoutTokens.textOnPrimary(ctx), Colors.white);
      expect(SpitoutTokens.textLink(ctx), isA<Color>());
      expect(SpitoutTokens.onSurfaceInverse(ctx), isA<Color>());
      expect(SpitoutTokens.iconPrimary(ctx), isA<Color>());
      expect(SpitoutTokens.iconSecondary(ctx), isA<Color>());
      expect(SpitoutTokens.iconTertiary(ctx), isA<Color>());

      expect(SpitoutTokens.border(ctx), isA<Color>());
      expect(SpitoutTokens.borderStrong(ctx), isA<Color>());
      expect(SpitoutTokens.grabHandleColor(ctx), isA<Color>());
      expect(SpitoutTokens.cardOuterBorderColor(ctx), Colors.transparent);
      expect(SpitoutTokens.cardOuterBorderWidth(ctx), 0);
      expect(SpitoutTokens.cardInnerDividerColor(ctx), isA<Color>());
      expect(SpitoutTokens.cardInnerDividerHeight(ctx), isA<double>());
      expect(SpitoutTokens.cardDivider(ctx), isA<Divider>());

      expect(SpitoutTokens.primary(ctx), isA<Color>());
      expect(SpitoutTokens.success(ctx), isA<Color>());
      expect(SpitoutTokens.warning(ctx), isA<Color>());
      expect(SpitoutTokens.error(ctx), isA<Color>());
      expect(SpitoutTokens.info(ctx), isA<Color>());
      expect(SpitoutTokens.buttonPrimary(ctx), isA<Color>());
      expect(SpitoutTokens.buttonPrimaryText(ctx), Colors.white);
      expect(SpitoutTokens.buttonDisabled(ctx), isA<Color>());
      expect(SpitoutTokens.switchInactiveTrack(ctx), isA<Color>());

      expect(SpitoutTokens.brandLocal, isA<Color>());
      expect(SpitoutTokens.brandSupabase, isA<Color>());
      expect(SpitoutTokens.brandWebdav, isA<Color>());
      expect(SpitoutTokens.brandS3, isA<Color>());
      expect(SpitoutTokens.brandCloud, isA<Color>());
      expect(SpitoutTokens.statusOnline(ctx), isA<Color>());
      expect(SpitoutTokens.statusOffline(ctx), isA<Color>());
      expect(SpitoutTokens.statusPending(ctx), isA<Color>());
      expect(SpitoutTokens.chartExpense(ctx), isA<Color>());
      expect(SpitoutTokens.overlay(ctx), isA<Color>());
      expect(SpitoutTokens.tabBarBackground(ctx), isA<Color>());
      expect(SpitoutTokens.tabBarShadow, isNotEmpty);
      expect(SpitoutTokens.toastBackground, isA<Color>());
      expect(SpitoutTokens.toastShadow, isNotEmpty);
    }
  });
}
