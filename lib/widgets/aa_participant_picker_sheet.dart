import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/settlement/aa_edit_models.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'app_sheet.dart';

/// 参与人多选结果。
///
/// [all] = true 表示「全部成员」(运行时展开,不落具体名单);
/// [all] = false 时 [ids] 为具体选中的参与人标识列表。
class AaParticipantSelection {
  final bool all;
  final List<String> ids;

  const AaParticipantSelection({required this.all, required this.ids});
}

/// 参与人多选 Bottom Sheet(分摊参与人)。
///
/// 顶部固定「全部成员」选项:选中后下方个人选项禁用,语义为运行时展开
/// 全部成员(aaParticipants 落 null)。取消(下滑/遮罩)返回 null。
Future<AaParticipantSelection?> showAaParticipantPickerSheet(
  BuildContext context, {
  required List<AaParticipantOption> options,
  required List<String>? initialSelectedIds,
}) {
  return showAppSheet<AaParticipantSelection>(
    context: context,
    child: _AaParticipantPicker(
      options: options,
      initialSelectedIds: initialSelectedIds,
    ),
  );
}

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

/// 参与人多选 Sheet 内容(带「全部成员」开关 + 完成按钮)。
class _AaParticipantPicker extends StatefulWidget {
  final List<AaParticipantOption> options;
  final List<String>? initialSelectedIds;

  const _AaParticipantPicker({
    required this.options,
    required this.initialSelectedIds,
  });

  @override
  State<_AaParticipantPicker> createState() => _AaParticipantPickerState();
}

class _AaParticipantPickerState extends State<_AaParticipantPicker> {
  /// true = 全部成员(初始 selectedIds 为 null 时)。
  late bool _all = widget.initialSelectedIds == null;

  /// 具体选中的参与人标识(_all=false 时生效)。
  late final Set<String> _selected = {...?widget.initialSelectedIds};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: l10n.aaParticipants,
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _all
                ? const AaParticipantSelection(all: true, ids: [])
                : AaParticipantSelection(
                    all: false, ids: _selected.toList()),
          ),
          child: Text(l10n.commonFinish),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 全部成员:选中后个人选择禁用,语义为运行时展开(aaParticipants=null)。
          // 已选中时再次点击 → 切到指定成员模式并以全选起步,便于逐个反选,
          // 否则全选态下永远无法进入指定成员模式。
          _AaSimpleRow(
            title: l10n.aaParticipantsAll,
            checked: _all,
            onTap: () => setState(() {
              if (_all) {
                _all = false;
                _selected
                  ..clear()
                  ..addAll(widget.options.map((e) => e.id));
              } else {
                _all = true;
              }
            }),
          ),
          Divider(height: 1, color: SpitoutTokens.divider(context)),
          ConstrainedBox(
            // 个人选项区限高滚动,避免成员过多撑爆 sheet。
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in widget.options)
                    _AaOptionRow(
                      option: o,
                      checked: _all || _selected.contains(o.id),
                      enabled: !_all,
                      onTap: () => setState(() {
                        // 行仅在指定成员模式下可点(enabled: !_all),直接切换选中态
                        if (!_selected.remove(o.id)) {
                          _selected.add(o.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 参与人选项行:显示名 + 虚拟用户徽标 + 选中勾。
class _AaOptionRow extends StatelessWidget {
  final AaParticipantOption option;
  final bool checked;
  final bool enabled;
  final VoidCallback onTap;

  const _AaOptionRow({
    required this.option,
    required this.checked,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
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
      ),
    );
  }
}

/// 纯文本选项行(用于「全部成员」这类无头像的选项)。
class _AaSimpleRow extends StatelessWidget {
  final String title;
  final bool checked;
  final VoidCallback onTap;

  const _AaSimpleRow({
    required this.title,
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                  color: checked
                      ? primary
                      : SpitoutTokens.textPrimary(context),
                ),
              ),
            ),
            if (checked) Icon(AppIcons.check, size: 18, color: primary),
          ],
        ),
      ),
    );
  }
}
