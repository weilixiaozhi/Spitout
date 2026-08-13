import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/providers.dart';

import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/core/router/routes.dart';
import 'package:spitout/widgets/check_update_tile.dart';
import 'package:spitout/pages/cloud/cloud_service_page.dart';
import 'package:spitout/pages/maintenance/orphan_cleanup_page.dart';
import 'package:spitout/pages/transaction/recurring_transaction_page.dart';
import 'package:spitout/pages/settings/reminder_settings_page.dart';
import 'package:spitout/pages/settings/appearance_settings_page.dart';
import 'package:spitout/pages/settings/config_import_export_page.dart';
import 'package:spitout/pages/currency/exchange_rate_page.dart';
import 'package:spitout/pages/data/detail_import_export_page.dart';
import 'package:spitout/theme/icons/app_icons.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context), // ⭐ 使用 Token
      body: Column(
        children: [
          PrimaryHeader(
            showBack: false,
            title: AppLocalizations.of(context).mineTitle,
            showTitleSection: false,
            content: const MinePageHeader(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: SpitoutDimens.p8),
                // 一级分组：功能管理
                // 包含：分类管理 → 汇率管理 → 周期账单 → 记账提醒 → 偏好调节
                // 数据清理已移至「云同步与备份」分组（统计 / 日历已提升为底部导航一级入口）
                SectionCard(
                  margin: EdgeInsets.fromLTRB(SpitoutDimens.p12, 0, SpitoutDimens.p12, 0),
                  child: Column(
                    children: [
                      // 分类管理
                      AppListTile(
                        leading: AppIcons.category,
                        title: AppLocalizations.of(
                          context,
                        ).mineCategoryManagement,
                        subtitle: AppLocalizations.of(
                          context,
                        ).mineCategoryManagementSubtitle,
                        trailing: Icon(
                          AppIcons.chevronRight,
                          color: SpitoutTokens.iconTertiary(context),
                          size: SpitoutDimens.icon20,
                        ),
                        // 按路由名跳转分类管理页，由 router.dart 统一解析
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(Routes.categoryManage),
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 汇率管理
                      AppListTile(
                        leading: AppIcons.currencyExchange,
                        title: AppLocalizations.of(
                          context,
                        ).exchangeRatePageTitle,
                        subtitle: AppLocalizations.of(
                          context,
                        ).exchangeRateEntrySubtitle,
                        trailing: Icon(
                          AppIcons.chevronRight,
                          color: SpitoutTokens.iconTertiary(context),
                          size: SpitoutDimens.icon20,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const ExchangeRatePage(),
                            ),
                          );
                        },
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 周期账单
                      AppListTile(
                        leading: AppIcons.repeat,
                        title: AppLocalizations.of(
                          context,
                        ).mineRecurringTransactions,
                        subtitle: AppLocalizations.of(
                          context,
                        ).mineRecurringTransactionsSubtitle,
                        trailing: Icon(
                          AppIcons.chevronRight,
                          color: SpitoutTokens.iconTertiary(context),
                          size: SpitoutDimens.icon20,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const RecurringTransactionPage(),
                            ),
                          );
                        },
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 记账提醒
                      AppListTile(
                        leading: AppIcons.notifications,
                        title: AppLocalizations.of(
                          context,
                        ).mineReminderSettings,
                        subtitle: AppLocalizations.of(
                          context,
                        ).mineReminderSettingsSubtitle,
                        trailing: Icon(
                          AppIcons.chevronRight,
                          color: SpitoutTokens.iconTertiary(context),
                          size: SpitoutDimens.icon20,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const ReminderSettingsPage(),
                            ),
                          );
                        },
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 偏好调节
                      AppListTile(
                        leading: AppIcons.theme,
                        title: AppLocalizations.of(context).appearanceSettings,
                        subtitle: AppLocalizations.of(
                          context,
                        ).appearanceSettingsDesc,
                        trailing: Icon(
                          AppIcons.chevronRight,
                          color: SpitoutTokens.iconTertiary(context),
                          size: SpitoutDimens.icon20,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const AppearanceSettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: SpitoutDimens.p8),
                // 一级分组：云同步与备份
                // 包含：备份与云同步配置 → 明细导入导出 → 配置导入导出 → 数据清理
                // 云服务与同步状态统一经 CloudServiceEntryTile 进入。
                SectionCard(
                  margin: EdgeInsets.fromLTRB(SpitoutDimens.p12, 0, SpitoutDimens.p12, 0),
                  child: Column(
                    children: [
                      // 备份与云同步配置 —— 统一入口：图标与文案按 9 种同步状态切换，
                      // 点击统一进入 CloudServicePage（不按后端类型路由分叉）。
                      // 调整至本分组首位，突出云同步与备份的核心入口地位。
                      CloudServiceEntryTile(
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const CloudServicePage(),
                            ),
                          );
                        },
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 明细导入导出(合并原导入/导出入口,逻辑复用 import/export 页)
                      AppListTile(
                        leading: AppIcons.currencyExchange,
                        title: AppLocalizations.of(
                          context,
                        ).detailImportExportTitle,
                        subtitle: AppLocalizations.of(
                          context,
                        ).detailImportExportSubtitle,
                        trailing: Icon(
                          AppIcons.chevronRight,
                          color: SpitoutTokens.iconTertiary(context),
                          size: SpitoutDimens.icon20,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const DetailImportExportPage(),
                            ),
                          );
                        },
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 配置导入导出
                      AppListTile(
                        leading: AppIcons.backupRestore,
                        title: AppLocalizations.of(
                          context,
                        ).configImportExportTitle,
                        subtitle: AppLocalizations.of(
                          context,
                        ).configImportExportSubtitle,
                        trailing: Icon(
                          AppIcons.chevronRight,
                          color: SpitoutTokens.iconTertiary(context),
                          size: SpitoutDimens.icon20,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const ConfigImportExportPage(),
                            ),
                          );
                        },
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 数据清理(从功能管理分组移入)
                      AppListTile(
                        leading: AppIcons.cleaning,
                        title: AppLocalizations.of(
                          context,
                        ).maintenanceOrphanCleanupTitle,
                        subtitle: AppLocalizations.of(
                          context,
                        ).maintenanceOrphanCleanupSubtitle,
                        trailing: Icon(
                          AppIcons.chevronRight,
                          color: SpitoutTokens.iconTertiary(context),
                          size: SpitoutDimens.icon20,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const OrphanCleanupPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: SpitoutDimens.p16),
                // 「检查更新」入口：复用全站统一的 AppListTile，
                // 检测到新版本时显示成功色「更新」胶囊与版本提示。
                SectionCard(
                  margin: EdgeInsets.fromLTRB(SpitoutDimens.p12, 0, SpitoutDimens.p12, 0),
                  // 页面负责注入检查动作（providers 动作函数），
                  // CheckUpdateTile 保持纯 UI 职责，不直连 services 层。
                  child: CheckUpdateTile(check: () => checkAppUpdate(ref)),
                ),
                SizedBox(height: SpitoutDimens.p16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 「检查更新」相关逻辑由 CheckUpdateTile（widgets/biz）承载，
  // MinePage 只负责页面骨架。
}
