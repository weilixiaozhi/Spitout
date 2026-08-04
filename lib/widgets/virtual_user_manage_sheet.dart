import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';
import 'app_dialog.dart';
import 'app_sheet.dart';
import 'toast.dart';

/// 虚拟用户管理 Bottom Sheet(新建 / 重命名 / 删除)。
///
/// 数据源为 [ledgerVirtualUsersProvider](Stream,增删改自动刷新);
/// 全部写操作走 aa_statistics_providers 动作函数(LocalRepository 委托,
/// 保证 sync 登记统一)。删除受硬约束:名下有账不可删,子仓抛
/// [StateError],此处 catch 后 toast 提示。
///
/// 打开方式:AaEditPage 参与人区 / 账本设置页「管理虚拟用户」入口。
Future<void> showVirtualUserManageSheet(
  BuildContext context, {
  required int ledgerId,
}) {
  return showAppSheet<void>(
    context: context,
    child: _VirtualUserManageBody(ledgerId: ledgerId),
  );
}

class _VirtualUserManageBody extends ConsumerWidget {
  final int ledgerId;

  const _VirtualUserManageBody({required this.ledgerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usersAsync = ref.watch(ledgerVirtualUsersProvider(ledgerId));

    return AppSheet(
      title: l10n.aaVirtualUserTitle,
      // 标题栏右侧常驻「新建」入口,空列表与非空列表入口位置一致。
      trailing: IconButton(
        icon: const Icon(AppIcons.add, size: 20),
        tooltip: l10n.aaVirtualUserAdd,
        onPressed: () => _editName(context, ref, l10n, null),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      child: usersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            '$e',
            style: TextStyle(
              fontSize: 13,
              color: SpitoutTokens.error(context),
            ),
          ),
        ),
        data: (users) => users.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.aaVirtualUserEmpty,
                    style: TextStyle(
                      fontSize: 13,
                      color: SpitoutTokens.textTertiary(context),
                    ),
                  ),
                ),
              )
            : ConstrainedBox(
                // 列表限高滚动,避免虚拟用户过多撑爆 sheet。
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < users.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: SpitoutTokens.divider(context),
                          ),
                        _VirtualUserRow(
                          user: users[i],
                          onRename: () =>
                              _editName(context, ref, l10n, users[i]),
                          onDelete: () =>
                              _confirmDelete(context, ref, l10n, users[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 新建([user] = null)或重命名虚拟用户。
  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    LedgerVirtualUser? user,
  ) async {
    final ctrl = TextEditingController(text: user?.name ?? '');
    final entered = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(
            user == null ? l10n.aaVirtualUserAdd : l10n.aaVirtualUserRename),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: InputDecoration(hintText: l10n.aaVirtualUserNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(AppLocalizations.of(dctx).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
            child: Text(AppLocalizations.of(dctx).commonConfirm),
          ),
        ],
      ),
    );
    if (entered == null || entered.isEmpty || !context.mounted) return;
    try {
      if (user == null) {
        await createVirtualUser(ref, ledgerId: ledgerId, name: entered);
      } else {
        await renameVirtualUser(ref, id: user.id, name: entered);
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, '${l10n.commonFailed}: $e');
      }
    }
  }

  /// 删除虚拟用户:二次确认 → 动作函数;名下有账(StateError)toast 拦截。
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    LedgerVirtualUser user,
  ) async {
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.commonDelete,
      message: l10n.aaVirtualUserDeleteConfirm(user.name),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await deleteVirtualUser(ref, user.id);
    } on StateError {
      if (context.mounted) {
        showToast(context, l10n.aaVirtualUserInUse);
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, '${l10n.commonFailed}: $e');
      }
    }
  }
}

/// 单个虚拟用户行:昵称 + 重命名 / 删除操作。
class _VirtualUserRow extends StatelessWidget {
  final LedgerVirtualUser user;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _VirtualUserRow({
    required this.user,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceSecondary(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.person,
              size: 16,
              color: SpitoutTokens.iconSecondary(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.name,
              style: TextStyle(
                fontSize: 15,
                color: SpitoutTokens.textPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(AppIcons.edit, size: 18),
            tooltip: AppLocalizations.of(context).aaVirtualUserRename,
            onPressed: onRename,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: SpitoutTokens.iconSecondary(context),
            ),
          ),
          IconButton(
            icon: const Icon(AppIcons.delete, size: 18),
            tooltip: AppLocalizations.of(context).commonDelete,
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: SpitoutTokens.error(context),
            ),
          ),
        ],
      ),
    );
  }
}
