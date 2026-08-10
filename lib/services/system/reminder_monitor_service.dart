import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/services/notification/reminder_constants.dart';
import 'package:spitout/services/notification/notification_factory.dart';

/// 记账提醒监控服务
///
/// 功能：
/// 1. 监听应用生命周期
/// 2. 应用从后台恢复到前台时，检查提醒是否仍然有效
/// 3. 如果提醒丢失，自动重新设置
class ReminderMonitorService with WidgetsBindingObserver {
  static final ReminderMonitorService _instance =
      ReminderMonitorService._internal();
  factory ReminderMonitorService() => _instance;
  ReminderMonitorService._internal();

  DateTime? _lastCheckTime;
  static const _checkInterval = Duration(hours: 6); // 最多6小时检查一次
  BuildContext Function()? _contextProvider;

  /// 开始监控
  ///
  /// [contextProvider] 用于取 l10n 文案（恢复提醒时按当前语言发送通知）；
  /// 未注入时回退内置文案。
  void startMonitoring({BuildContext Function()? contextProvider}) {
    _contextProvider = contextProvider;
    WidgetsBinding.instance.addObserver(this);
    logger.info('ReminderMonitor', '✅ 记账提醒监控服务已启动');
  }

  /// 停止监控
  void stopMonitoring() {
    WidgetsBinding.instance.removeObserver(this);
    logger.info('ReminderMonitor', '🛑 记账提醒监控服务已停止');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    logger.info('ReminderMonitor', '📱 应用生命周期变化: $state');

    if (state == AppLifecycleState.resumed) {
      // 应用从后台恢复到前台
      _checkAndRestoreReminder();
    }
  }

  /// 检查并恢复提醒
  Future<void> _checkAndRestoreReminder() async {
    try {
      // 避免频繁检查
      if (_lastCheckTime != null &&
          DateTime.now().difference(_lastCheckTime!) < _checkInterval) {
        logger.info('ReminderMonitor', 'ℹ️  距离上次检查时间过短，跳过本次检查');
        return;
      }

      logger.info('ReminderMonitor', '🔍 开始检查记账提醒状态...');
      _lastCheckTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(ReminderPrefs.enabled) ?? false;

      if (!isEnabled) {
        logger.info('ReminderMonitor', 'ℹ️  用户未启用记账提醒');
        return;
      }

      // 检查是否有待处理的提醒
      final notificationUtil = NotificationFactory.getInstance();
      final pending = await notificationUtil.getPendingNotifications();
      final hasMainReminder = pending.any(
        (n) => n.id == ReminderPrefs.mainNotificationId,
      );

      if (!hasMainReminder) {
        logger.info('ReminderMonitor', '⚠️  警告：检测到记账提醒丢失，正在重新设置...');

        final hour = prefs.getInt(ReminderPrefs.hour) ?? 21;
        final minute = prefs.getInt(ReminderPrefs.minute) ?? 0;
        final ctx = _contextProvider?.call();
        // 优先取注入的 BuildContext（跟随当前语言）；拿不到时按系统语言解析，
        // 不硬编码中文兜底（文案统一收敛到 l10n）。
        final l10n = (ctx != null && ctx.mounted)
            ? AppLocalizations.of(ctx)
            : lookupAppLocalizations(ui.PlatformDispatcher.instance.locale);

        await notificationUtil.scheduleDailyReminder(
          id: ReminderPrefs.mainNotificationId,
          title: l10n.reminderTitle,
          body: l10n.reminderBody,
          hour: hour,
          minute: minute,
        );

        logger.info('ReminderMonitor', '✅ 记账提醒已重新设置');
      } else {
        logger.info(
          'ReminderMonitor',
          '✅ 记账提醒状态正常 (待处理通知数: ${pending.length})',
        );
      }
    } catch (e) {
      logger.warning('ReminderMonitor', '❌ 检查提醒状态失败: $e');
    }
  }
}
