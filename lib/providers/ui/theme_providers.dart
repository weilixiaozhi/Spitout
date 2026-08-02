import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logging/logger_service.dart';
// 只依赖叶子模块拿云客户端实例。
import 'package:spitout/providers/sync/cloud_client_providers.dart';

// 主题模式Provider（默认跟随系统）
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// 主题模式持久化初始化
final themeModeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('themeMode');
  if (saved != null) {
    switch (saved) {
      case 'light':
        ref.read(themeModeProvider.notifier).state = ThemeMode.light;
        break;
      case 'dark':
        ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
        break;
      default:
        ref.read(themeModeProvider.notifier).state = ThemeMode.system;
    }
  }
  ref.listen<ThemeMode>(themeModeProvider, (prev, next) async {
    String value;
    switch (next) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      default:
        value = 'system';
    }
    await prefs.setString('themeMode', value);
  });
});

/// 把支出颜色方案等外观偏好的当前值打包推给 server 的 /profile/me。
/// 非 Spitout Cloud 模式 provider 返回 null 直接跳过。
/// fire-and-forget,失败只打 warning。
///
/// 用整包 PATCH 是故意的:以上属于同一组"外观",任何一个改动都重发全量,server
/// 写入 appearance_json 整体替换,对端用 WS profile_change 事件拉 /profile/me
/// 拿到最新 dict 应用。
void _pushAppearanceToCloud(Ref ref) {
  unawaited(() async {
    try {
      final cloudProvider =
          await ref.read(spitoutCloudProviderInstance.future);
      if (cloudProvider == null) return;
      final appearance = <String, dynamic>{
        // 支出颜色方案：随其它外观项整体 PATCH 到 /profile/me，server 原样存 appearance_json。
        'expense_color_scheme': ref.read(expenseColorSchemeProvider),
      };
      await cloudProvider.updateMyProfileAppearance(appearance: appearance);
      logger.info(
          'theme_providers', 'pushed appearance to server: $appearance');
    } catch (e, st) {
      logger.warning(
          'theme_providers', 'push appearance failed (non-blocking): $e', st);
    }
  }());
}

// 支出颜色方案Provider。取值：'red' = 红色表示支出（默认），'green' = 绿色表示支出。
// 全局仅支出模式，所以这里只管「支出」用哪种颜色，不涉及收入配色。
final expenseColorSchemeProvider = StateProvider<String>((ref) => 'red');

// 支出颜色方案持久化初始化：启动从 prefs 读取，用户修改时写回并同步到 Spitout Cloud。
// 复用 appearance JSON 管道（见 _pushAppearanceToCloud），不新增后端字段。
final expenseColorSchemeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('expenseColorScheme');
  if (saved != null) {
    ref.read(expenseColorSchemeProvider.notifier).state = saved;
  }
  ref.listen<String>(expenseColorSchemeProvider, (prev, next) async {
    // 用户切换方案后落盘，并整包推到云端 /profile/me 的 appearance_json。
    await prefs.setString('expenseColorScheme', next);
    _pushAppearanceToCloud(ref);
  });
});

// 用户显示名(昵称)。本地真值存 prefs 'displayName';Spitout Cloud 模式下改动
// 会推到 server,其余云模式 / 纯本地只存本地。空串 = 未设置。v1 不支持"清空已设
// 昵称"——不会推空串给 server,因此无需改后端 / 包层(包层对空串本就 throw)。
final displayNameProvider = StateProvider<String>((ref) => '');

// 显示名持久化初始化:启动加载 prefs + 监听变化写回本地,并在 cloud 模式下推送。
// 写法与 themeMode 等外观项一致(自己管理 prefs 读写与 cloud 推送)。
final displayNameInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('displayName');
  if (saved != null) {
    ref.read(displayNameProvider.notifier).state = saved;
  }
  ref.listen<String>(displayNameProvider, (prev, next) async {
    await prefs.setString('displayName', next);
    _pushDisplayNameToCloud(ref, next);
  });
});

/// 把显示名推给 server 的 /profile/me(仅 Spitout Cloud 模式)。非 cloud 模式
/// provider 返回 null 直接跳过;空串不推(server 不支持清空,且包层对空串会 throw)。
/// fire-and-forget,失败只打 warning。
void _pushDisplayNameToCloud(Ref ref, String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return;
  unawaited(() async {
    try {
      final cloudProvider =
          await ref.read(spitoutCloudProviderInstance.future);
      if (cloudProvider == null) return;
      await cloudProvider.updateMyProfileDisplayName(displayName: trimmed);
      logger.info('theme_providers', 'display name pushed to server: $trimmed');
    } catch (e, st) {
      logger.warning('theme_providers',
          'push display name failed (non-blocking): $e', st);
    }
  }());
}