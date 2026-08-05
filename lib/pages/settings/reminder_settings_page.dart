import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:spitout/providers/reminder/reminder_providers.dart';
import '../../services/notification/notification_factory.dart';
import '../../services/notification/notification_android.dart';
import '../../core/logging/logger_service.dart';
import '../../theme/colors.dart';
import '../../widgets/widgets.dart';
import '../../theme/icons/app_icons.dart';

class ReminderSettingsPage extends ConsumerWidget {
  const ReminderSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderSettings = ref.watch(reminderSettingsProvider);

    final isDark = SpitoutTokens.isDark(context);

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).reminderTitle,
            subtitle: AppLocalizations.of(context).reminderSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
          const SizedBox(height: 16),
          
          // 提醒开关
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: SpitoutTokens.border(context)) : null,
            ),
            child: SwitchListTile(
              title: Text(
                AppLocalizations.of(context).reminderDailyTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: SpitoutTokens.textPrimary(context),
                ),
              ),
              subtitle: Text(
                AppLocalizations.of(context).reminderDailySubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: SpitoutTokens.textSecondary(context),
                ),
              ),
              value: reminderSettings.isEnabled,
              onChanged: (value) {
                ref.read(reminderSettingsProvider.notifier).updateEnabled(value);
              },
              activeThumbColor: Theme.of(context).primaryColor,
            ),
          ),

          const SizedBox(height: 16),

          // 提醒时间设置
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: SpitoutTokens.border(context)) : null,
            ),
            child: ListTile(
              title: Text(
                AppLocalizations.of(context).reminderTimeTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: SpitoutTokens.textPrimary(context),
                ),
              ),
              subtitle: Text(
                reminderSettings.timeString,
                style: TextStyle(
                  fontSize: 14,
                  color: SpitoutTokens.textSecondary(context),
                ),
              ),
              trailing: Icon(
                AppIcons.chevronRight,
                color: SpitoutTokens.iconTertiary(context),
              ),
              onTap: () async {
                final selectedTime = await showWheelTimePicker(
                  context,
                  initial: TimeOfDay(
                    hour: reminderSettings.hour,
                    minute: reminderSettings.minute,
                  ),
                );
                
                if (selectedTime != null) {
                  ref.read(reminderSettingsProvider.notifier).updateTime(
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 24),

          // 测试通知按钮
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final l10n = AppLocalizations.of(context);
                try {
                  final notificationUtil = NotificationFactory.getInstance();
                  // 在 async gap 之前缓存本地化实例，避免跨越 await 使用 BuildContext
                  // 用户主动测试通知时请求权限，确保通知能正常发出
                  await notificationUtil.requestPermissions();
                  await notificationUtil.showNotification(
                    id: 9999,
                    title: l10n.reminderTestTitle,
                    body: l10n.reminderTestBody,
                  );
                  if (context.mounted) {
                    showToast(context, l10n.reminderTestSent);
                  }
                } catch (e, st) {
                  logger.error('ReminderSettings', '发送测试通知失败', e, st);
                  if (context.mounted) {
                    showToast(context, l10n.commonOperationFailed);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context).reminderTestNotification,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),


          // Android专用电池和渠道检查按钮
          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),

            // 电池优化状态检查
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final util = NotificationFactory.getInstance();
                  if (util is! AndroidNotificationUtil) return;
                  final l10n = AppLocalizations.of(context);
                  Map<String, dynamic> batteryInfo;
                  try {
                    batteryInfo = await util.getBatteryOptimizationInfo();
                  } catch (e, st) {
                    logger.error('ReminderSettings', '获取电池优化状态失败', e, st);
                    if (context.mounted) {
                      showToast(context, l10n.commonOperationFailed);
                    }
                    return;
                  }
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.reminderBatteryStatus),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.reminderManufacturer(batteryInfo['manufacturer'] ?? 'Unknown')),
                            Text(l10n.reminderModel(batteryInfo['model'] ?? 'Unknown')),
                            Text(l10n.reminderAndroidVersion(batteryInfo['androidVersion'] ?? 'Unknown')),
                            const SizedBox(height: 8),
                            Text(
                              (batteryInfo['isIgnoring'] == true)
                                  ? l10n.reminderBatteryIgnored
                                  : l10n.reminderBatteryNotIgnored,
                              style: TextStyle(
                                color: (batteryInfo['isIgnoring'] == true) ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (batteryInfo['isIgnoring'] != true) ...[
                              const SizedBox(height: 8),
                              Text(
                                l10n.reminderBatteryAdvice,
                                style: const TextStyle(fontSize: 12, color: Colors.red),
                              ),
                            ],
                          ],
                        ),
                        actions: [
                          if (batteryInfo['isIgnoring'] != true && batteryInfo['canRequest'] == true)
                              TextButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  final u = NotificationFactory.getInstance();
                                  if (u is! AndroidNotificationUtil) return;
                                  try {
                                    await u.requestIgnoreBatteryOptimizations();
                                  } catch (e, st) {
                                    logger.error(
                                      'ReminderSettings',
                                      '请求忽略电池优化失败',
                                      e,
                                      st,
                                    );
                                  }
                                },
                                child: Text(l10n.commonSettings),
                              ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.commonConfirm),
                          ),
                        ],
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).reminderCheckBattery,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 通知渠道设置检查
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final util = NotificationFactory.getInstance();
                  if (util is! AndroidNotificationUtil) return;
                  final l10n = AppLocalizations.of(context);
                  Map<String, dynamic> channelInfo;
                  try {
                    channelInfo = await util.getNotificationChannelInfo();
                  } catch (e, st) {
                    logger.error('ReminderSettings', '获取通知渠道状态失败', e, st);
                    if (context.mounted) {
                      showToast(context, l10n.commonOperationFailed);
                    }
                    return;
                  }
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.reminderChannelStatus),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((channelInfo['isEnabled'] == true)
                                ? l10n.reminderChannelEnabled
                                : l10n.reminderChannelDisabled),
                            Text(l10n.reminderChannelImportance(channelInfo['importance'] ?? 'unknown')),
                            Text((channelInfo['sound'] == true)
                                ? l10n.reminderChannelSoundOn
                                : l10n.reminderChannelSoundOff),
                            Text((channelInfo['vibration'] == true)
                                ? l10n.reminderChannelVibrationOn
                                : l10n.reminderChannelVibrationOff),
                            if (channelInfo['bypassDnd'] != null)
                              Text((channelInfo['bypassDnd'] == true)
                                  ? l10n.reminderChannelDndBypass
                                  : l10n.reminderChannelDndNoBypass),
                            const SizedBox(height: 8),
                            if (channelInfo['isEnabled'] != true ||
                                channelInfo['importance'] == 'none' ||
                                channelInfo['importance'] == 'min' ||
                                channelInfo['importance'] == 'low') ...[
                              Text(
                                l10n.reminderChannelAdvice,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                              Text(l10n.reminderChannelAdviceImportance),
                              Text(l10n.reminderChannelAdviceSound),
                              Text(l10n.reminderChannelAdviceBanner),
                              Text(l10n.reminderChannelAdviceXiaomi),
                            ] else ...[
                              Text(
                                l10n.reminderChannelGood,
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final u = NotificationFactory.getInstance();
                              if (u is! AndroidNotificationUtil) return;
                              try {
                                await u.openNotificationChannelSettings();
                              } catch (e, st) {
                                logger.error(
                                  'ReminderSettings',
                                  '打开通知渠道设置失败',
                                  e,
                                  st,
                                );
                              }
                            },
                            child: Text(l10n.commonSettings),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.commonConfirm),
                          ),
                        ],
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).reminderCheckChannel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 打开应用设置
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final util = NotificationFactory.getInstance();
                  if (util is! AndroidNotificationUtil) return;
                  try {
                    await util.openAppSettings();
                  } catch (e, st) {
                    logger.error('ReminderSettings', '打开应用设置失败', e, st);
                    if (context.mounted) {
                      showToast(
                        context,
                        AppLocalizations.of(context).commonOperationFailed,
                      );
                    }
                    return;
                  }
                  if (context.mounted) {
                    showToast(context, AppLocalizations.of(context).reminderAppSettingsMessage);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).reminderOpenAppSettings,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],

          // 说明文字
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceSecondary(context),
              borderRadius: BorderRadius.circular(8),
              border: isDark ? null : Border.all(
                color: SpitoutTokens.borderStrong(context),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).reminderDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: SpitoutTokens.textSecondary(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).reminderAndroidInstructions,
                  style: TextStyle(
                    fontSize: 12,
                    color: SpitoutTokens.textTertiary(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      );
  }
}
