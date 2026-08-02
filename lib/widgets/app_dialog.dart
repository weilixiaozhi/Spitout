import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/colors.dart';

/// 弹窗底部按钮之间的最小水平间距（全局统一）。设为 60，避免确定/取消挨太近。
/// 实际间距会随弹窗宽度自适应：剩余空间由下方的 Expanded 均分到按钮之间，
/// 该值只作为保底最小间距。
const double _kButtonSpacing = 60;

/// 统一弹窗（基础 UI 组件）
class AppDialog {
  static Future<T?> confirm<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? cancelLabel,
    String? okLabel,
    VoidCallback? onCancel,
    VoidCallback? onOk,
  }) {
    final l10n = AppLocalizations.of(context);
    cancelLabel ??= l10n.commonCancel;
    okLabel ??= l10n.commonConfirm;
    return _show<T>(
      context,
      title: title,
      message: message,
      actions: [
        (
          label: cancelLabel,
          onTap: () {
            Navigator.pop(context, false);
            if (onCancel != null) onCancel();
          },
          primary: false,
        ),
        (
          label: okLabel,
          onTap: () {
            Navigator.pop(context, true);
            if (onOk != null) onOk();
          },
          primary: true,
        ),
      ],
    );
  }

  static Future<T?> info<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? okLabel,
    VoidCallback? onOk,
  }) {
    final l10n = AppLocalizations.of(context);
    okLabel ??= l10n.commonOk;
    return _show<T>(
      context,
      title: title,
      message: message,
      actions: [
        (
          label: okLabel,
          onTap: () {
            Navigator.pop(context, true);
            if (onOk != null) onOk();
          },
          primary: true,
        ),
      ],
    );
  }

  static Future<T?> error<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? okLabel,
    VoidCallback? onOk,
  }) {
    final l10n = AppLocalizations.of(context);
    okLabel ??= l10n.commonOk;
    return _show<T>(
      context,
      title: title,
      message: message,
      actions: [
        (
          label: okLabel,
          onTap: () {
            Navigator.pop(context, true);
            if (onOk != null) onOk();
          },
          primary: true,
        ),
      ],
    );
  }

  static Future<T?> warning<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? okLabel,
    VoidCallback? onOk,
  }) {
    final l10n = AppLocalizations.of(context);
    okLabel ??= l10n.commonOk;
    return _show<T>(
      context,
      title: title,
      message: message,
      actions: [
        (
          label: okLabel,
          onTap: () {
            Navigator.pop(context, true);
            if (onOk != null) onOk();
          },
          primary: true,
        ),
      ],
    );
  }

  static Future<T?> _show<T>(
    BuildContext context, {
    required String title,
    required String message,
    List<({String label, VoidCallback onTap, bool primary})>? actions,
  }) {
    final l10n = AppLocalizations.of(context);
    actions ??= [
      (
        label: l10n.commonCancel,
        onTap: () => Navigator.pop(context),
        primary: false
      ),
      (
        label: l10n.commonConfirm,
        onTap: () => Navigator.pop(context),
        primary: true
      ),
    ];
    // 将 actions 收敛为非空本地变量。闭包（如描边按钮的 Builder）内无法沿用外层可空类型的空安全推断，
    // 用本地非空变量可避免闭包里出现的"可能为 null"报错，同时让下方按钮布局逻辑统一引用 act
    final act = actions;

    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpitoutTokens.surfaceElevated(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SpitoutTokens.textPrimary(ctx)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message.replaceAll('\\n', '\n'), // 处理转义的换行符
                    textAlign: TextAlign.left,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: SpitoutTokens.textSecondary(ctx),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (int i = 0; i < act.length; i++) ...[
                    // 用 Expanded 吃掉弹窗的弹性空间，Align(center) 让按钮保持固有宽度居中：
                    // 多余空间自然落在按钮两侧，即"按钮间距"随弹窗宽度自动增大，整组仍严格居中
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        // 根据按钮主次决定样式：取消用描边按钮，确定用填充按钮
                        child: !act[i].primary
                            ? Builder(builder: (context) {
                                final primary = Theme.of(ctx).colorScheme.primary;
                                return OutlinedButton(
                                  onPressed: act[i].onTap,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primary,
                                    side: BorderSide(color: primary),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(act[i].label),
                                );
                              })
                            : FilledButton(
                                onPressed: act[i].onTap,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(act[i].label)),
                      ),
                    ),
                    // 最小间距保底 60，仅加在按钮"之间"，最后一个按钮之后不添加，
                    // 避免尾部多出一段空白导致按钮组视觉偏移
                    if (i < act.length - 1)
                      const SizedBox(width: _kButtonSpacing),
                  ]
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
