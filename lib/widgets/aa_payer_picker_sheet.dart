import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/settlement/aa_edit_models.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'app_sheet.dart';

/// 支出人单选 Bottom Sheet。
///
/// 点击某行即返回该参与人标识;取消返回 null。
/// 参与人标识口径:真实成员 userId,虚拟用户 syncId。
Future<String?> showAaPayerPickerSheet(
  BuildContext context, {
  required List<AaParticipantOption> options,
  String? selectedId,
}) {
  return showAppSheet<String>(
    context: context,
    child: AppSheet(
      title: AppLocalizations.of(context).aaPayer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            _AaOptionRow(
              option: o,
              checked: o.id == selectedId,
              onTap: () => Navigator.of(context).pop(o.id),
            ),
        ],
      ),
    ),
  );
}

/// 参与人选项行:显示名 + 虚拟用户徽标 + 选中勾。
///
/// 支出人单选复用此行展示选中态。
class _AaOptionRow extends StatelessWidget {
  final AaParticipantOption option;
  final bool checked;
  final VoidCallback onTap;

  const _AaOptionRow({
    required this.option,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // 参与人头像位:虚拟用户与真实成员用不同图标区分。
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: option.isVirtual
                    ? SpitoutTokens.surfaceSecondary(context)
                    : primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.person,
                size: 16,
                color: option.isVirtual
                    ? SpitoutTokens.iconSecondary(context)
                    : primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.name,
                style: TextStyle(
                  fontSize: 15,
                  color: SpitoutTokens.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (checked) Icon(AppIcons.check, size: 18, color: primary),
          ],
        ),
      ),
    );
  }
}
