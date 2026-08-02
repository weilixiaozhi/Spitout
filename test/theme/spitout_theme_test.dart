import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/theme/app_theme.dart';
import 'package:spitout/theme/colors.dart';

/// ThemeData pin 值与 SpitoutColors 单一真相源契约测试（阶段二）。
///
/// 守护核心架构契约：SpitoutTheme 构造 ThemeData 时把关键色显式 pin 为
/// SpitoutColors 常量，因此「改 SpitoutColors 一处，ThemeData 自动跟随」，
/// 杜绝 ThemeData 与 Token 双真相源。一旦有人在 app_theme.dart 里改回字面量，
/// 本测试会立即失败。
void main() {
  test('lightTheme 关键 pin 值与 SpitoutColors 一致', () {
    final t = SpitoutTheme.lightTheme(platform: TargetPlatform.android);
    expect(t.scaffoldBackgroundColor, SpitoutColors.lightScaffold,
        reason: '亮色页面底色必须引用 SpitoutColors.lightScaffold');
    expect(t.colorScheme.surface, SpitoutColors.lightSurface,
        reason: '亮色卡片表面必须引用 SpitoutColors.lightSurface');
    expect(t.colorScheme.primary, SpitoutColors.seed,
        reason: '主色必须 pin 为 SpitoutColors.seed（唯一主色真相源）');
  });

  test('darkTheme 关键 pin 值与 SpitoutColors 一致', () {
    final t = SpitoutTheme.darkTheme(platform: TargetPlatform.android);
    expect(t.scaffoldBackgroundColor, SpitoutColors.darkScaffold,
        reason: '暗色页面底色必须引用 SpitoutColors.darkScaffold');
    expect(t.colorScheme.primary, SpitoutColors.seed,
        reason: '暗色主色仍必须 pin 为 SpitoutColors.seed（亮暗一致）');
  });
}
