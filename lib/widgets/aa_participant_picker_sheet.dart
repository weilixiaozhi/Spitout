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
/// 设计意图(需求方案 A):
/// - 不再用独立的「全部成员」开关,统一用逐行复选;
/// - 完成时若选中集合覆盖全部 options,语义等价于「全部成员」,
///   返回 all=true(运行时展开,aaParticipants 落 null),避免存一份
///   与成员表完全一致的冗余名单;
/// - 支出人lockedId 行强制锁定勾选(支出人必是参与人),禁用反选。
/// 取消(下滑/遮罩)返回 null。
Future<AaParticipantSelection?> showAaParticipantPickerSheet(
  BuildContext context, {
  required List<AaParticipantOption> options,
  required List<String>? initialSelectedIds,
  String? lockedId,
}) {
  return showAppSheet<AaParticipantSelection>(
    context: context,
    child: _AaParticipantPicker(
      options: options,
      initialSelectedIds: initialSelectedIds,
      lockedId: lockedId,
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

/// 参与人多选 Sheet 内容(逐行复选 + 完成按钮)。
///
/// 状态仅维护 [_selected] 集合;完成时若覆盖全部 options 则返回 all=true。
/// [lockedId] 对应的行强制保持勾选,禁用反选(支出人必是参与人)。
class _AaParticipantPicker extends StatefulWidget {
  final List<AaParticipantOption> options;
  final List<String>? initialSelectedIds;

  /// 锁定为参与人的标识(支出人);该行不可反选。
  final String? lockedId;

  const _AaParticipantPicker({
    required this.options,
    required this.initialSelectedIds,
    this.lockedId,
  });

  @override
  State<_AaParticipantPicker> createState() => _AaParticipantPickerState();
}

class _AaParticipantPickerState extends State<_AaParticipantPicker> {
  /// 当前选中的参与人标识集合。
  ///
  /// 初值 null 语义 = 全部成员(运行时展开),内部展开为全部 options 的 id,
  /// 这样统一用逐行复选表达「全部成员」态,完成时再判断是否全覆盖回写 all。
  late final Set<String> _selected = _initSelected();

  Set<String> _initSelected() {
    final init = widget.initialSelectedIds;
    if (init == null) {
      // null = 全部成员,展开为全部 options。
      return {...widget.options.map((e) => e.id)};
    }
    // 指定名单模式:确保 lockedId 一定在内(支出人必是参与人)。
    final s = {...init};
    if (widget.lockedId != null) s.add(widget.lockedId!);
    return s;
  }

  /// 切换某行选中态;lockedId 行禁用反选。
  void _toggle(String id) {
    if (id == widget.lockedId) return; // 支出人锁定,不可反选
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
    });
  }

  /// 完成时判定:选中集合覆盖全部 options → all=true(落 null,运行时展开)。
  bool _isAllSelected() {
    if (widget.options.isEmpty) return true;
    for (final o in widget.options) {
      if (!_selected.contains(o.id)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: l10n.aaParticipants,
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            final all = _isAllSelected();
            Navigator.of(context).pop(
              all
                  ? const AaParticipantSelection(all: true, ids: [])
                  : AaParticipantSelection(
                      all: false, ids: _selected.toList()),
            );
          },
          child: Text(l10n.commonFinish),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                      checked: _selected.contains(o.id),
                      // lockedId 行点击时 _toggle 内直接 return,
                      // 保持已勾选态不可反选(支出人必是参与人)。
                      onTap: () => _toggle(o.id),
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
///
/// 复用单元:支出人单选与参与人多选共用此行。锁定行(支出人)
/// 由调用方在 onTap 回调内自行拦截反选,行本身不做禁用态。
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
