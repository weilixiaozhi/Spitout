import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/statistics/aa_edit_models.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'app_sheet.dart';
import 'me_suffix.dart';
import 'person_avatar.dart';

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
            // 参与人头像位:未设置头像时统一展示虚拟用户同等 person 图标,
            // 虚拟用户与真实成员保持一致,不再用底色区分。
            const PersonAvatar(size: 32, iconSize: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
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
                  // 本人「(我)」后缀统一走共享 MeSuffix,与成员管理样式一致。
                  if (option.isSelf) const MeSuffix(),
                ],
              ),
            ),
            if (checked) Icon(AppIcons.check, size: 18, color: primary),
          ],
        ),
      ),
    );
  }
}
