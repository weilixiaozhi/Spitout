import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:spitout/providers/reminder/reminder_providers.dart';
import '../../services/notification/notification_factory.dart';
import '../../services/notification/notification_android.dart';
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
              activeColor: Theme.of(context).primaryColor,
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
                final notificationUtil = NotificationFactory.getInstance();
                // 在 async gap 之前缓存本地化实例，避免跨越 await 使用 BuildContext
                final l10n = AppLocalizations.of(context);
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
                  final androidUtil = NotificationFactory.getInstance() as AndroidNotificationUtil;
                  final batteryInfo = await androidUtil.getBatteryOptimizationInfo();
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.of(context).reminderBatteryStatus),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context).reminderManufacturer(batteryInfo['manufacturer'] ?? 'Unknown')),
                            Text(AppLocalizations.of(context).reminderModel(batteryInfo['model'] ?? 'Unknown')),
                            Text(AppLocalizations.of(context).reminderAndroidVersion(batteryInfo['androidVersion'] ?? 'Unknown')),
                            const SizedBox(height: 8),
                            Text(
                              (batteryInfo['isIgnoring'] == true)
                                  ? AppLocalizations.of(context).reminderBatteryIgnored
                                  : AppLocalizations.of(context).reminderBatteryNotIgnored,
                              style: TextStyle(
                                color: (batteryInfo['isIgnoring'] == true) ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (batteryInfo['isIgnoring'] != true) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context).reminderBatteryAdvice,
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
                                final androidUtil = NotificationFactory.getInstance() as AndroidNotificationUtil;
                                await androidUtil.requestIgnoreBatteryOptimizations();
                              },
                              child: Text(AppLocalizations.of(context).commonSettings),
                            ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(AppLocalizations.of(context).commonConfirm),
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
                  final androidUtil = NotificationFactory.getInstance() as AndroidNotificationUtil;
                  final channelInfo = await androidUtil.getNotificationChannelInfo();
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.of(context).reminderChannelStatus),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((channelInfo['isEnabled'] == true)
                                ? AppLocalizations.of(context).reminderChannelEnabled
                                : AppLocalizations.of(context).reminderChannelDisabled),
                            Text(AppLocalizations.of(context).reminderChannelImportance(channelInfo['importance'] ?? 'unknown')),
                            Text((channelInfo['sound'] == true)
                                ? AppLocalizations.of(context).reminderChannelSoundOn
                                : AppLocalizations.of(context).reminderChannelSoundOff),
                            Text((channelInfo['vibration'] == true)
                                ? AppLocalizations.of(context).reminderChannelVibrationOn
                                : AppLocalizations.of(context).reminderChannelVibrationOff),
                            if (channelInfo['bypassDnd'] != null)
                              Text((channelInfo['bypassDnd'] == true)
                                  ? AppLocalizations.of(context).reminderChannelDndBypass
                                  : AppLocalizations.of(context).reminderChannelDndNoBypass),
                            const SizedBox(height: 8),
                            if (channelInfo['isEnabled'] != true ||
                                channelInfo['importance'] == 'none' ||
                                channelInfo['importance'] == 'min' ||
                                channelInfo['importance'] == 'low') ...[
                              Text(
                                AppLocalizations.of(context).reminderChannelAdvice,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                              Text(AppLocalizations.of(context).reminderChannelAdviceImportance),
                              Text(AppLocalizations.of(context).reminderChannelAdviceSound),
                              Text(AppLocalizations.of(context).reminderChannelAdviceBanner),
                              Text(AppLocalizations.of(context).reminderChannelAdviceXiaomi),
                            ] else ...[
                              Text(
                                AppLocalizations.of(context).reminderChannelGood,
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final androidUtil = NotificationFactory.getInstance() as AndroidNotificationUtil;
                              await androidUtil.openNotificationChannelSettings();
                            },
                            child: Text(AppLocalizations.of(context).commonSettings),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(AppLocalizations.of(context).commonConfirm),
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
                  final androidUtil = NotificationFactory.getInstance() as AndroidNotificationUtil;
                  await androidUtil.openAppSettings();
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