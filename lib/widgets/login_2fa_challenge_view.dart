import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show SpitoutCloudProvider, TwoFactorChallengeRequest;
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// 2FA 输码对话框 — 当 SpitoutCloudAuthService.signInWithAccount 收到 server 的
/// requires_2fa=true 响应时,通过 [SpitoutCloudProvider.globalTwoFactorHandler]
/// 注册的回调把它弹出来,让用户输 6 位 TOTP 或 recovery code。
///
/// 失败 → 内部调 [TwoFactorChallengeRequest.verify] 拿 server 错误消息,就地
/// 展示让用户重试,**不会跳走 / 关闭**。成功 → 关闭并 pop true。用户取消 → pop false。
class Login2FAChallengeDialog extends ConsumerStatefulWidget {
  final TwoFactorChallengeRequest request;

  const Login2FAChallengeDialog({super.key, required this.request});

  /// 用法:`final ok = await Login2FAChallengeDialog.show(context, request);`
  static Future<bool> show(
    BuildContext context,
    TwoFactorChallengeRequest request,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Login2FAChallengeDialog(request: request),
    );
    return result ?? false;
  }

  @override
  ConsumerState<Login2FAChallengeDialog> createState() =>
      _Login2FAChallengeDialogState();
}

class _Login2FAChallengeDialogState
    extends ConsumerState<Login2FAChallengeDialog> {
  late final TextEditingController _codeController;
  String _method = 'totp';
  bool _verifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    final methods = widget.request.availableMethods;
    if (!methods.contains('totp') && methods.isNotEmpty) {
      _method = methods.first;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_verifying) return;
    final raw =
        _codeController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return;
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });
    try {
      final err = await widget.request.verify(_method, raw);
      if (!mounted) return;
      if (err == null) {
        // 验证通过 → 关闭对话框,handler resolve true
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = err;
          _verifying = false;
          _codeController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _verifying = false;
      });
    }
  }

  void _onCancel() {
    if (_verifying) return;
    Navigator.of(context).pop(false);
  }

  bool get _canSubmit {
    if (_verifying) return false;
    final raw =
        _codeController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (_method == 'totp') return raw.length == 6;
    final stripped = raw.replaceAll('-', '');
    return stripped.length >= 6;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final hasRecovery =
        widget.request.availableMethods.contains('recovery_code');

    final hintStyle = SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textTertiary(context),
      letterSpacing: 0,
      fontWeight: FontWeight.normal);

    return AlertDialog(
      title: Text(l10n.twofaChallengeTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.request.account,
              style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
            ),
            const SizedBox(height: SpitoutDimens.p12),
            if (hasRecovery)
              Row(
                children: [
                  Expanded(
                    child: _MethodTab(
                      label: l10n.twofaMethodTotp,
                      selected: _method == 'totp',
                      onTap: _verifying
                          ? null
                          : () {
                              setState(() {
                                _method = 'totp';
                                _codeController.clear();
                                _errorMessage = null;
                              });
                            },
                    ),
                  ),
                  Expanded(
                    child: _MethodTab(
                      label: l10n.twofaMethodRecovery,
                      selected: _method == 'recovery_code',
                      onTap: _verifying
                          ? null
                          : () {
                              setState(() {
                                _method = 'recovery_code';
                                _codeController.clear();
                                _errorMessage = null;
                              });
                            },
                    ),
                  ),
                ],
              ),
            if (hasRecovery) const SizedBox(height: SpitoutDimens.p12),
            TextField(
              controller: _codeController,
              autofocus: true,
              enabled: !_verifying,
              textAlign: TextAlign.center,
              keyboardType: _method == 'totp'
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: _method == 'totp'
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ]
                  : [LengthLimitingTextInputFormatter(20)],
              style: TextStyle(
                fontSize: _method == 'totp' ? 22 : 18,
                letterSpacing: _method == 'totp' ? 6 : 1.5,
                color: SpitoutTokens.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: _method == 'totp'
                    ? l10n.twofaTotpInputPlaceholder
                    : l10n.twofaRecoveryInputPlaceholder,
                hintStyle: hintStyle,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: SpitoutDimens.p12, vertical: SpitoutDimens.p12),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                } else {
                  setState(() {});
                }
              },
              onSubmitted: (_) {
                if (_canSubmit) _onSubmit();
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: SpitoutDimens.p8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SpitoutDimens.p8, vertical: SpitoutDimens.p4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(
                        alpha: 0.08,
                      ),
                  borderRadius: BorderRadius.circular(SpitoutDimens.radius4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.error,
                        size: SpitoutDimens.icon16,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: SpitoutDimens.p4),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: SpitoutTextTokens.label(context).copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : _onCancel,
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: SpitoutTokens.textOnPrimary(context),
          ),
          onPressed: _canSubmit ? _onSubmit : null,
          child: _verifying
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SpitoutTokens.textOnPrimary(context),
                  ),
                )
              : Text(l10n.twofaVerifyButton),
        ),
      ],
    );
  }

}

class _MethodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _MethodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p8, horizontal: SpitoutDimens.p12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: SpitoutTextTokens.body(context).copyWith(color: selected
                  ? Theme.of(context).colorScheme.primary
                  : SpitoutTokens.textSecondary(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
          ),
        ),
      ),
    );
  }
}
