import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/settlement/aa_settlement_service.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'app_sheet.dart';

/// 分摊方式选择 Bottom Sheet(人均分摊 / 指定分摊)。
///
/// 单选列表,点击即返回选中的 [AaMode];下滑/点遮罩取消返回 null。
/// 记账编辑器 AA 区块与 AaEditPage 共用,保证两处选择体验一致。
Future<AaMode?> showAaModePickerSheet(
  BuildContext context, {
  required AaMode selected,
}) {
  return showAppSheet<AaMode>(
    context: context,
    child: AppSheet(
      title: AppLocalizations.of(context).aaSplitMode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AaModeOption(
            mode: AaMode.perPerson,
            selected: selected,
          ),
          _AaModeOption(
            mode: AaMode.custom,
            selected: selected,
          ),
        ],
      ),
    ),
  );
}

/// 单个分摊方式选项行:标题 + 副标题说明,选中态右侧打勾。
class _AaModeOption extends StatelessWidget {
  final AaMode mode;
  final AaMode selected;

  const _AaModeOption({required this.mode, required this.selected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSelected = mode == selected;
    final (title, subtitle) = switch (mode) {
      AaMode.perPerson => (l10n.aaModePerPerson, l10n.aaPerPersonAllMembers),
      AaMode.custom => (l10n.aaModeCustom, l10n.aaSplitAmounts),
      // 不分摊不在选择器提供入口(编辑器仅人均/指定)。
      AaMode.noSplit => ('', ''),
    };
    return InkWell(
      onTap: () => Navigator.of(context).pop(mode),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : SpitoutTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: SpitoutTokens.textTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                AppIcons.check,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
