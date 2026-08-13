import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/notification/notification_factory.dart';
import 'package:spitout/services/notification/notification_android.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/theme/icons/app_icons.dart';

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
          const SizedBox(height: SpitoutDimens.p16),
          
          // 提醒开关
          Container(
            margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surface(context),
              borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
              border: isDark ? Border.all(color: SpitoutTokens.border(context)) : null,
            ),
            // Material 透明层：ListTile 的墨迹/背景绘制在最近 Material 祖先上，
            // 若直接被带背景的 DecoratedBox 包裹会被遮挡（Flutter debug 断言）。
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                title: Text(
                  AppLocalizations.of(context).reminderDailyTitle,
                  style: SpitoutTextTokens.title(context).copyWith(color: SpitoutTokens.textPrimary(context)),
                ),
                subtitle: Text(
                  AppLocalizations.of(context).reminderDailySubtitle,
                  style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                ),
                value: reminderSettings.isEnabled,
                onChanged: (value) {
                  ref.read(reminderSettingsProvider.notifier).updateEnabled(value);
                },
                activeThumbColor: Theme.of(context).primaryColor,
              ),
            ),
          ),

          const SizedBox(height: SpitoutDimens.p16),

          // 提醒时间设置
          Container(
            margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surface(context),
              borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
              border: isDark ? Border.all(color: SpitoutTokens.border(context)) : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                title: Text(
                  AppLocalizations.of(context).reminderTimeTitle,
                  style: SpitoutTextTokens.title(context).copyWith(color: SpitoutTokens.textPrimary(context)),
                ),
                subtitle: Text(
                  reminderSettings.timeString,
                  style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textSecondary(context)),
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
          ),

          const SizedBox(height: SpitoutDimens.p20),

          // 测试通知按钮
          Container(
            margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
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
                foregroundColor: SpitoutTokens.textOnPrimary(context),
                padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context).reminderTestNotification,
                style: SpitoutTextTokens.title(context),
              ),
            ),
          ),


          // Android专用电池和渠道检查按钮
          if (Platform.isAndroid) ...[
            const SizedBox(height: SpitoutDimens.p16),

            // 电池优化状态检查
            Container(
              margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
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
                            const SizedBox(height: SpitoutDimens.p8),
                            Text(
                              (batteryInfo['isIgnoring'] == true)
                                  ? l10n.reminderBatteryIgnored
                                  : l10n.reminderBatteryNotIgnored,
                              style: TextStyle(color: (batteryInfo['isIgnoring'] == true)
                                    ? SpitoutTokens.success(context)
                                    : SpitoutTokens.warning(context)),
                            ),
                            if (batteryInfo['isIgnoring'] != true) ...[
                              const SizedBox(height: SpitoutDimens.p8),
                              Text(
                                l10n.reminderBatteryAdvice,
                                style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.error(context)),
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
                  padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).reminderCheckBattery,
                  style: SpitoutTextTokens.title(context),
                ),
              ),
            ),

            const SizedBox(height: SpitoutDimens.p16),

            // 通知渠道设置检查
            Container(
              margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
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
                            const SizedBox(height: SpitoutDimens.p8),
                            if (channelInfo['isEnabled'] != true ||
                                channelInfo['importance'] == 'none' ||
                                channelInfo['importance'] == 'min' ||
                                channelInfo['importance'] == 'low') ...[
                              Text(
                                l10n.reminderChannelAdvice,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: SpitoutTokens.warning(context),
                                ),
                              ),
                              Text(l10n.reminderChannelAdviceImportance),
                              Text(l10n.reminderChannelAdviceSound),
                              Text(l10n.reminderChannelAdviceBanner),
                              Text(l10n.reminderChannelAdviceXiaomi),
                            ] else ...[
                              Text(
                                l10n.reminderChannelGood,
                                style: TextStyle(
                                  color: SpitoutTokens.success(context),
                                  fontWeight: FontWeight.bold,
                                ),
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
                  padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).reminderCheckChannel,
                  style: SpitoutTextTokens.title(context),
                ),
              ),
            ),

            const SizedBox(height: SpitoutDimens.p16),

            // 打开应用设置
            Container(
              margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
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
                  padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).reminderOpenAppSettings,
                  style: SpitoutTextTokens.title(context),
                ),
              ),
            ),

            const SizedBox(height: SpitoutDimens.p16),
          ],

          // 说明文字
          Container(
            margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
            padding: const EdgeInsets.all(SpitoutDimens.p16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceSecondary(context),
              borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
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
                  style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context),
                    height: 1.4),
                ),
                const SizedBox(height: SpitoutDimens.p8),
                Text(
                  AppLocalizations.of(context).reminderAndroidInstructions,
                  style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textTertiary(context),
                    height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: SpitoutDimens.p32),
                ],
              ),
            ),
          ],
        ),
      );
  }
}
