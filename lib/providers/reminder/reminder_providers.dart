import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/services/notification/reminder_constants.dart';
import 'package:spitout/services/notification/notification_factory.dart';
import 'package:spitout/providers/ui/language_provider.dart';
import 'package:spitout/providers/core/shared_preferences_provider.dart';

/// 记账提醒设置
class ReminderSettings {
  final bool isEnabled;
  final int hour;  // 0-23
  final int minute; // 0-59

  const ReminderSettings({
    required this.isEnabled,
    required this.hour,
    required this.minute,
  });

  factory ReminderSettings.defaultSettings() {
    return const ReminderSettings(
      isEnabled: false,
      hour: 21, // 默认晚上9点
      minute: 0,
    );
  }

  ReminderSettings copyWith({
    bool? isEnabled,
    int? hour,
    int? minute,
  }) {
    return ReminderSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  String get timeString {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettings &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => isEnabled.hashCode ^ hour.hashCode ^ minute.hashCode;
}

/// 记账提醒设置的 Notifier
class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  /// 用户是否已在本轮 build 之后显式修改过设置。
  ///
  /// build 里异步加载 prefs 的 `_loadSettings` 可能晚于用户操作完成，
  /// 若不加保护会把刚写入的设置覆盖回旧值（启动即操作的竞态）；
  /// 一旦用户显式修改，迟到的加载结果必须丢弃。
  bool _userTouched = false;

  @override
  ReminderSettings build() {
    // 先同步返回默认设置，再异步加载保存的配置，避免首次渲染等待 IO。
    _loadSettings();
    return ReminderSettings.defaultSettings();
  }

  // prefs 键统一引用服务层常量（与 main / 监控服务 / 配置导入导出共用），
  // 避免字符串散落导致改名后静默失联。
  static const String _keyEnabled = ReminderPrefs.enabled;
  static const String _keyHour = ReminderPrefs.hour;
  static const String _keyMinute = ReminderPrefs.minute;

  /// 当前语言下的提醒文案（无 BuildContext，按语言 provider / 系统语言解析）。
  AppLocalizations get _l10n {
    final locale =
        ref.read(languageProvider) ?? ui.PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(locale);
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      if (_userTouched) return;
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final isEnabled = prefs.getBool(_keyEnabled) ?? false;
      final hour = prefs.getInt(_keyHour) ?? 21;
      final minute = prefs.getInt(_keyMinute) ?? 0;

      // await 期间用户可能已显式修改（updateEnabled/updateTime/updateSettings），
      // 迟到的加载结果必须丢弃，否则会覆盖刚写入的设置。
      if (_userTouched) return;
      state = ReminderSettings(
        isEnabled: isEnabled,
        hour: hour,
        minute: minute,
      );
    } catch (e) {
      // 保持默认设置
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setBool(_keyEnabled, state.isEnabled);
      await prefs.setInt(_keyHour, state.hour);
      await prefs.setInt(_keyMinute, state.minute);
    } catch (e) {
      // 忽略保存错误
    }
  }

  /// 更新启用状态
  Future<void> updateEnabled(bool enabled) async {
    _userTouched = true;
    state = state.copyWith(isEnabled: enabled);
    await _saveSettings();

    final notificationUtil = NotificationFactory.getInstance();
    if (enabled) {
      // 用户主动开启提醒时才请求通知权限，避免应用首次安装即弹出权限请求
      await notificationUtil.requestPermissions();
      await notificationUtil.scheduleDailyReminder(
        id: ReminderPrefs.mainNotificationId,
        title: _l10n.reminderTitle,
        body: _l10n.reminderBody,
        hour: state.hour,
        minute: state.minute,
      );
    } else {
      await notificationUtil.cancelNotification(ReminderPrefs.mainNotificationId);
    }
  }

  /// 更新提醒时间
  Future<void> updateTime(int hour, int minute) async {
    _userTouched = true;
    state = state.copyWith(hour: hour, minute: minute);
    await _saveSettings();

    // 如果提醒已启用，重新设置通知
    if (state.isEnabled) {
      final notificationUtil = NotificationFactory.getInstance();
      // 先取消旧的完整通知链（主通知 + 7 天备用 + AlarmManager 备用），
      // 再按新时间重建，避免旧备用通知残留旧时间造成重复提醒。
      await notificationUtil.cancelNotification(ReminderPrefs.mainNotificationId);
      await notificationUtil.scheduleDailyReminder(
        id: ReminderPrefs.mainNotificationId,
        title: _l10n.reminderTitle,
        body: _l10n.reminderBody,
        hour: hour,
        minute: minute,
      );
    }
  }

  /// 更新完整设置
  Future<void> updateSettings(ReminderSettings settings) async {
    _userTouched = true;
    state = settings;
    await _saveSettings();

    final notificationUtil = NotificationFactory.getInstance();
    if (settings.isEnabled) {
      // 用户主动开启提醒时才请求通知权限，避免应用首次安装即弹出权限请求
      await notificationUtil.requestPermissions();
      await notificationUtil.scheduleDailyReminder(
        id: ReminderPrefs.mainNotificationId,
        title: _l10n.reminderTitle,
        body: _l10n.reminderBody,
        hour: settings.hour,
        minute: settings.minute,
      );
    } else {
      await notificationUtil.cancelNotification(ReminderPrefs.mainNotificationId);
    }
  }
}

/// 记账提醒设置Provider
final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
  ReminderSettingsNotifier.new,
);
