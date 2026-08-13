import 'package:flutter/material.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';
  void showMultiDeviceDetailDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryText = SpitoutTokens.textPrimary(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpitoutTokens.surfaceElevated(context),
        title: Row(
          children: [
            Icon(
              AppIcons.info,
              color: Theme.of(context).colorScheme.primary,
              size: SpitoutDimens.icon22,
            ),
            const SizedBox(width: SpitoutDimens.p12),
            Expanded(
              child: Text(
                l10n.cloudSyncGuideTitle,
                style: SpitoutTextTokens.boldTitle(context).copyWith(color: primaryText,),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            // ignore: sort_child_properties_last
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 工作原理
                _buildGuideSection(
                  context,
                  icon: AppIcons.refresh,
                  title: l10n.cloudSyncGuideHowItWorks,
                  items: [
                    l10n.cloudSyncGuideHowItem1,
                    l10n.cloudSyncGuideHowItem2,
                    l10n.cloudSyncGuideHowItem3,
                  ],
                ),
                const SizedBox(height: SpitoutDimens.p16),
                // 正确用法
                _buildGuideSection(
                  context,
                  icon: AppIcons.checkCircle,
                  iconColor: SpitoutTokens.success(context),
                  title: l10n.cloudSyncGuideCorrect,
                  items: [
                    l10n.cloudSyncGuideCorrectItem1,
                    l10n.cloudSyncGuideCorrectItem2,
                    l10n.cloudSyncGuideCorrectItem3,
                    l10n.cloudSyncGuideCorrectItem4,
                  ],
                ),
                const SizedBox(height: SpitoutDimens.p16),
                // 错误用法
                _buildGuideSection(
                  context,
                  icon: AppIcons.cancel,
                  iconColor: SpitoutTokens.error(context),
                  title: l10n.cloudSyncGuideWrong,
                  items: [
                    l10n.cloudSyncGuideWrongItem1,
                    l10n.cloudSyncGuideWrongItem2,
                    l10n.cloudSyncGuideWrongItem3,
                  ],
                ),
                const SizedBox(height: SpitoutDimens.p16),
                // 已知限制
                _buildGuideSection(
                  context,
                  icon: AppIcons.warning,
                  iconColor: SpitoutTokens.warning(context),
                  title: l10n.cloudSyncGuideLimitations,
                  items: [
                    l10n.cloudSyncGuideLimitItem1,
                    l10n.cloudSyncGuideLimitItem2,
                    l10n.cloudSyncGuideLimitItem3,
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cloudSyncGuideGotIt,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: SpitoutDimens.icon16,
              color: iconColor ?? SpitoutTokens.textSecondary(context),
            ),
            const SizedBox(width: SpitoutDimens.p4),
            Text(
              title,
              style: SpitoutTextTokens.strongTitle(context).copyWith(color: SpitoutTokens.textPrimary(context),),
            ),
          ],
        ),
        const SizedBox(height: SpitoutDimens.p4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: SpitoutDimens.p20, bottom: SpitoutDimens.p4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context),
                      height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void showSupabaseHelpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.storage, color: SpitoutTokens.brandSupabase),
            const SizedBox(width: SpitoutDimens.p8),
            Text(l10n.cloudSupabaseHelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(context, l10n.cloudSupabaseHelpIntro, [
                l10n.cloudSupabaseHelpIntro1,
                l10n.cloudSupabaseHelpIntro2,
                l10n.cloudSupabaseHelpIntro3,
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              _buildHelpSection(context, l10n.cloudSupabaseHelpSteps, [
                l10n.cloudSupabaseHelpStep1,
                l10n.cloudSupabaseHelpStep2,
                l10n.cloudSupabaseHelpStep3,
                l10n.cloudSupabaseHelpStep4,
                l10n.cloudSupabaseHelpStep5,
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              _buildHelpSection(context, l10n.cloudSupabaseHelpFaq, [
                '• ${l10n.cloudSupabaseHelpFaq1}',
                '• ${l10n.cloudSupabaseHelpFaq2}',
                '• ${l10n.cloudSupabaseHelpFaq3}',
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              Container(
                padding: const EdgeInsets.all(SpitoutDimens.p12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandSupabase.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.info,
                      color: SpitoutTokens.brandSupabase,
                      size: SpitoutDimens.icon20,
                    ),
                    const SizedBox(width: SpitoutDimens.p8),
                    Expanded(
                      child: Text(
                        l10n.cloudSupabaseHelpNote,
                        style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  void showSpitoutCloudHelpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.cloudQueue, color: SpitoutTokens.brandCloud),
            const SizedBox(width: SpitoutDimens.p8),
            Text(l10n.cloudTutorialTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 介绍
              Text(
                l10n.cloudTutorialIntro,
                style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context),
                  height: 1.5),
              ),
              const SizedBox(height: SpitoutDimens.p16),
              // 4 步教程
              _buildBeeCloudStep(context,
                '1',
                l10n.cloudTutorialStep1Title,
                l10n.cloudTutorialStep1Desc,
              ),
              _buildBeeCloudStep(context,
                '2',
                l10n.cloudTutorialStep2Title,
                l10n.cloudTutorialStep2Desc,
              ),
              _buildBeeCloudStep(context,
                '3',
                l10n.cloudTutorialStep3Title,
                l10n.cloudTutorialStep3Desc,
              ),
              _buildBeeCloudStep(context,
                '4',
                l10n.cloudTutorialStep4Title,
                l10n.cloudTutorialStep4Desc,
              ),
              const SizedBox(height: SpitoutDimens.p4),
              // 特色功能 —— 强调 Web + 多设备协同 + 多用户 + 共享账本
              Container(
                padding: const EdgeInsets.all(SpitoutDimens.p12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandCloud.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cloudTutorialFeaturesTitle,
                      style: SpitoutTextTokens.label(context).copyWith(fontWeight: FontWeight.w600, color: SpitoutTokens.brandCloud),
                    ),
                    const SizedBox(height: SpitoutDimens.p4),
                    Text(
                      l10n.cloudTutorialFeature1,
                      style: SpitoutTextTokens.caption(context).copyWith(height: 1.7),
                    ),
                    Text(
                      l10n.cloudTutorialFeature2,
                      style: SpitoutTextTokens.caption(context).copyWith(height: 1.7),
                    ),
                    Text(
                      l10n.cloudTutorialFeature3,
                      style: SpitoutTextTokens.caption(context).copyWith(height: 1.7),
                    ),
                    Text(
                      l10n.cloudTutorialFeature4,
                      style: SpitoutTextTokens.caption(context).copyWith(height: 1.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpitoutDimens.p12),
              // Tip
              Container(
                padding: const EdgeInsets.all(SpitoutDimens.p12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandCloud.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.info,
                      color: SpitoutTokens.brandCloud,
                      size: SpitoutDimens.icon20,
                    ),
                    const SizedBox(width: SpitoutDimens.p8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${l10n.cloudTutorialTipTitle}: ',
                              style: SpitoutTextTokens.label(context).copyWith(fontWeight: FontWeight.w600, color: SpitoutTokens.textSecondary(context)),
                            ),
                            TextSpan(
                              text: l10n.cloudTutorialTipDesc,
                              style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cloudTutorialGotIt),
          ),
        ],
      ),
    );
  }

  Widget _buildBeeCloudStep(BuildContext context, String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpitoutDimens.p12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: SpitoutTokens.brandCloud,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: SpitoutTextTokens.label(context).copyWith(color: Colors.white,
                fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: SpitoutDimens.p8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SpitoutTextTokens.label(context).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context),
                    height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showWebdavHelpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.folderShared, color: SpitoutTokens.brandWebdav),
            const SizedBox(width: SpitoutDimens.p8),
            Text(l10n.cloudWebdavHelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(context, l10n.cloudWebdavHelpIntro, [
                l10n.cloudWebdavHelpIntro1,
                l10n.cloudWebdavHelpIntro2,
                l10n.cloudWebdavHelpIntro3,
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              _buildHelpSection(context, l10n.cloudWebdavHelpProviders, [
                l10n.cloudWebdavHelpProvider1,
                l10n.cloudWebdavHelpProvider2,
                l10n.cloudWebdavHelpProvider3,
                l10n.cloudWebdavHelpProvider4,
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              _buildHelpSection(context, l10n.cloudWebdavHelpSteps, [
                l10n.cloudWebdavHelpStep1,
                l10n.cloudWebdavHelpStep2,
                l10n.cloudWebdavHelpStep3,
                l10n.cloudWebdavHelpStep4,
                l10n.cloudWebdavHelpStep5,
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              Container(
                padding: const EdgeInsets.all(SpitoutDimens.p12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandWebdav.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.info,
                      color: SpitoutTokens.brandWebdav,
                      size: SpitoutDimens.icon20,
                    ),
                    const SizedBox(width: SpitoutDimens.p8),
                    Expanded(
                      child: Text(
                        l10n.cloudWebdavHelpNote,
                        style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  void showS3HelpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.storage, color: SpitoutTokens.brandS3),
            const SizedBox(width: SpitoutDimens.p8),
            Text(l10n.cloudS3HelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(context, l10n.cloudS3HelpIntro, [
                l10n.cloudS3HelpIntro1,
                l10n.cloudS3HelpIntro2,
                l10n.cloudS3HelpIntro3,
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              _buildHelpSection(context, l10n.cloudS3HelpProviders, [
                l10n.cloudS3HelpProvider1,
                l10n.cloudS3HelpProvider2,
                l10n.cloudS3HelpProvider3,
                l10n.cloudS3HelpProvider4,
                l10n.cloudS3HelpProvider5,
                l10n.cloudS3HelpProvider6,
                l10n.cloudS3HelpProvider7,
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              _buildHelpSection(context, l10n.cloudS3HelpSteps, [
                l10n.cloudS3HelpStep1,
                l10n.cloudS3HelpStep2,
                l10n.cloudS3HelpStep3,
                l10n.cloudS3HelpStep4,
                l10n.cloudS3HelpStep5,
              ]),
              const SizedBox(height: SpitoutDimens.p16),
              Container(
                padding: const EdgeInsets.all(SpitoutDimens.p12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandS3.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.info, color: SpitoutTokens.brandS3, size: SpitoutDimens.icon20),
                    const SizedBox(width: SpitoutDimens.p8),
                    Expanded(
                      child: Text(
                        l10n.cloudS3HelpNote,
                        style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: SpitoutTextTokens.body(context).copyWith(fontWeight: FontWeight.w600, color: SpitoutTokens.textPrimary(context)),
        ),
        const SizedBox(height: SpitoutDimens.p8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: SpitoutDimens.p8, bottom: SpitoutDimens.p4),
            child: Text(
              item,
              style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
            ),
          ),
        ),
      ],
    );
  }
