import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/theme/colors.dart';
import './language_settings_page.dart';
import './app_lock_settings_page.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// 外观设置二级页面
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);

    String languageDisplay;
    if (currentLanguage == null) {
      languageDisplay = l10n.languageSystemDefault;
    } else {
      switch (currentLanguage.languageCode) {
        case 'zh':
          languageDisplay = l10n.languageChinese;
          break;
        case 'en':
          languageDisplay = l10n.languageEnglish;
          break;
        case 'ko':
          languageDisplay = '한국어';
          break;
        default:
          languageDisplay = currentLanguage.languageCode;
      }
    }

    // 主题模式显示文本
    String themeModeDisplay;
    switch (themeMode) {
      case ThemeMode.light:
        themeModeDisplay = l10n.appearanceThemeModeLight;
        break;
      case ThemeMode.dark:
        themeModeDisplay = l10n.appearanceThemeModeDark;
        break;
      default:
        themeModeDisplay = l10n.appearanceThemeModeSystem;
    }

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.appearanceSettingsPageTitle,
            subtitle: l10n.appearanceSettingsPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 所有偏好项合并为一个分组，不细分
                // 排序：支出颜色 → 应用语言 → 深色模式 → 应用上锁
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 支出颜色（影响列表 / 搜索 / 详情等支出金额的着色）
                      AppListTile(
                        leading: AppIcons.theme,
                        title: l10n.appearanceExpenseColorScheme,
                        subtitle:
                            ref.watch(expenseColorSchemeProvider) == 'green'
                            ? l10n.appearanceExpenseColorGreen
                            : l10n.appearanceExpenseColorRed,
                        // 圆点放进与默认右箭头相同的 24×24 图标槽位,
                        // 保证圆点中心与下方各行的右箭头中心对齐。
                        trailing: SizedBox(
                          width: 24,
                          height: 24,
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    ref.watch(expenseColorSchemeProvider) ==
                                        'green'
                                    ? SpitoutTokens.success(context)
                                    : SpitoutTokens.error(context),
                              ),
                            ),
                          ),
                        ),
                        onTap: () =>
                            _showExpenseColorSchemeDialog(context, ref, l10n),
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 应用语言
                      AppListTile(
                        leading: AppIcons.language,
                        title: l10n.mineLanguageSettings,
                        subtitle: languageDisplay,
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const LanguageSettingsPage(),
                            ),
                          );
                        },
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 深色模式
                      AppListTile(
                        leading: AppIcons.themeAuto,
                        title: l10n.appearanceThemeMode,
                        subtitle: themeModeDisplay,
                        onTap: () => _showThemeModeDialog(context, ref, l10n),
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 应用上锁
                      AppListTile(
                        leading: AppIcons.lock,
                        title: l10n.appLockTitle,
                        subtitle: l10n.appLockDesc,
                        onTap: () async {
                          await Navigator.of(context).push(
                            appPageRoute(
                              builder: (_) => const AppLockSettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 显示主题模式选择对话框
  void _showThemeModeDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final currentMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpitoutTokens.surfaceElevated(context),
        title: Text(
          l10n.appearanceThemeMode,
          style: TextStyle(color: SpitoutTokens.textPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeOption(
              context,
              ref,
              title: l10n.appearanceThemeModeSystem,
              value: ThemeMode.system,
              currentValue: currentMode,
              icon: AppIcons.settingsSuggest,
            ),
            _buildModeOption(
              context,
              ref,
              title: l10n.appearanceThemeModeLight,
              value: ThemeMode.light,
              currentValue: currentMode,
              icon: AppIcons.lightMode,
            ),
            _buildModeOption(
              context,
              ref,
              title: l10n.appearanceThemeModeDark,
              value: ThemeMode.dark,
              currentValue: currentMode,
              icon: AppIcons.darkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required ThemeMode value,
    required ThemeMode currentValue,
    required IconData icon,
  }) {
    final isSelected = value == currentValue;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryColor : SpitoutTokens.iconSecondary(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : SpitoutTokens.textPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(AppIcons.check, color: primaryColor) : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).set(value);
        Navigator.pop(context);
      },
    );
  }

  /// 显示支出颜色方案选择对话框。选项直接展示「-100」示例数字（红/绿），
  /// 让用户在切换前就能预览支出金额的着色效果。点击"保存"才写
  /// expenseColorSchemeProvider（其 listener 会落盘并同步到云端）;
  /// "取消"或弹窗外关闭则保持原值不变（本地副本自动丢弃，无需回退处理）。
  ///
  /// 保存后：颜色已在本地即时换好，关闭本弹窗后，居中展示 1s 弱化
  /// loading（无遮罩、细线条、浅颜色），结束弹 toast「已更换」。不跳转首页。
  void _showExpenseColorSchemeDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final pageContext = context; // 外观设置页 context,用于在其上展示 loading 与 toast
    // 本地副本记录对话框内当前选择,与 provider 分离;只有点"保存"才提交。
    var selected = ref.read(expenseColorSchemeProvider);
    final initialSelected = selected;
    var saving = false;
    final primaryColor = Theme.of(pageContext).colorScheme.primary;
    showDialog(
      context: pageContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: SpitoutTokens.surfaceElevated(dialogCtx),
          title: Text(
            l10n.appearanceExpenseColorScheme,
            style: TextStyle(color: SpitoutTokens.textPrimary(dialogCtx)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildExpenseColorSchemeOption(
                context: dialogCtx,
                title: l10n.appearanceExpenseColorRed,
                value: 'red',
                selected: selected,
                exampleColor: SpitoutTokens.error(dialogCtx),
                primaryColor: primaryColor,
                onTap: () {
                  // 只更新本地副本,不写 provider。
                  selected = 'red';
                  setDialogState(() {});
                },
              ),
              _buildExpenseColorSchemeOption(
                context: dialogCtx,
                title: l10n.appearanceExpenseColorGreen,
                value: 'green',
                selected: selected,
                exampleColor: SpitoutTokens.success(dialogCtx),
                primaryColor: primaryColor,
                onTap: () {
                  selected = 'green';
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      // 显示 loading,避免重复点击;落盘 + 云同步由
                      // expenseColorSchemeProvider 的 listener 在后台完成。
                      setDialogState(() => saving = true);
                      // 真正提交:有变更才落盘 + 同步云端,避免无谓写入。
                      if (selected != initialSelected) {
                        ref
                            .read(expenseColorSchemeProvider.notifier)
                            .set(selected);
                      }
                      if (!pageContext.mounted) return;
                      // 仅关闭颜色选择弹窗,停留在外观设置页(不跳转首页)。
                      Navigator.of(dialogCtx).pop();
                      // 弱化 loading：无遮罩，仅居中展示细线条、浅颜色的
                      // CircularProgressIndicator，1s 过渡反馈后弹 toast「已更换」。
                      final overlayEntry = OverlayEntry(
                        builder: (_) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey,
                            ),
                          ),
                        ),
                      );
                      Overlay.of(pageContext).insert(overlayEntry);
                      try {
                        await Future.delayed(
                          const Duration(milliseconds: 1000),
                        );
                        if (pageContext.mounted) {
                          showToast(
                            pageContext,
                            l10n.appearanceExpenseColorApplied,
                          );
                        }
                      } finally {
                        // 页面在等待期间被退出也要移除 overlay,
                        // 避免根 Overlay 上残留全屏转圈指示器。
                        if (overlayEntry.mounted) {
                          overlayEntry.remove();
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  /// 支出颜色方案单个选项：左侧选中圆圈 + 标题 + 右侧「-100」示例数字。
  Widget _buildExpenseColorSchemeOption({
    required BuildContext context,
    required String title,
    required String value,
    required String selected,
    required Color exampleColor,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selected;
    return ListTile(
      leading: Icon(
        isSelected ? AppIcons.radioChecked : AppIcons.radioUnchecked,
        color: isSelected ? primaryColor : SpitoutTokens.iconSecondary(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : SpitoutTokens.textPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      // 示例数字用方案对应颜色渲染,直观预览支出着色。
      trailing: Text(
        '-100',
        style: TextStyle(color: exampleColor, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
