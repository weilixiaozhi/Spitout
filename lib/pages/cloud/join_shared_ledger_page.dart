// 加入共享账本页 — 输入 6 位邀请码 → preview → accept。
// Phase 1 不做 QR 扫码 / 短链 deeplink;两者都推到 Phase 3。MVP 只支持手动
// 输入邀请码。accept 成功后 sync engine 走 onInviteAccepted 拉 shared-resources。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudInvitePreview;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/widgets.dart';

class JoinSharedLedgerPage extends ConsumerStatefulWidget {
  const JoinSharedLedgerPage({super.key, this.prefilledCode});

  /// 从 deeplink 跳过来时,自动填好的邀请码。
  final String? prefilledCode;

  @override
  ConsumerState<JoinSharedLedgerPage> createState() =>
      _JoinSharedLedgerPageState();
}

class _JoinSharedLedgerPageState extends ConsumerState<JoinSharedLedgerPage> {
  final TextEditingController _codeController = TextEditingController();
  SpitoutCloudInvitePreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCode != null && widget.prefilledCode!.isNotEmpty) {
      _codeController.text = _normalizeForInput(widget.prefilledCode!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _doPreview());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// 输入框显示 "ABC 123",发送 server 时 strip 空格。
  String _normalizeForInput(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (cleaned.length == 6) return '${cleaned.substring(0, 3)} ${cleaned.substring(3)}';
    return cleaned;
  }

  String _normalizeForApi(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

  Future<void> _doPreview() async {
    final code = _normalizeForApi(_codeController.text);
    if (code.length != 6) {
      setState(() => _error = AppLocalizations.of(context).sharedJoinCodeFormatError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await previewInvite(ref, code: code);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _formatError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doAccept() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 接受邀请 + onInviteAccepted 一站式初始化 + 强力刷新全部收敛到
      // shared_ledger_providers 的一次性触发函数(页面不直接触碰 SyncEngine)。
      final result = await acceptSharedLedgerInvite(
        ref,
        code: preview.code,
        ledgerExternalId: preview.ledgerExternalId,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showToast(
        context,
        l10n.sharedJoinSuccess(result.ledgerName ?? preview.ledgerExternalId),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _formatError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatError(Object error) {
    final raw = error.toString();
    if (raw.contains('Already a member')) {
      return AppLocalizations.of(context).sharedJoinAlreadyMember;
    }
    if (raw.contains('Invalid or expired')) {
      return AppLocalizations.of(context).sharedJoinInvalidOrExpired;
    }
    if (raw.contains('member limit')) {
      return AppLocalizations.of(context).sharedJoinMemberLimit;
    }
    return raw;
  }

  String _formatRoleLabel(String role, AppLocalizations l10n) {
    switch (role) {
      case 'owner':
        return l10n.sharedRoleOwner;
      case 'editor':
        return l10n.sharedRoleEditor;
      default:
        return role;
    }
  }

  String _formatExpiry(DateTime expiresAt, AppLocalizations l10n) {
    final now = DateTime.now().toUtc();
    final delta = expiresAt.difference(now);
    if (delta.inMinutes <= 0) return l10n.sharedJoinInvalidOrExpired;
    if (delta.inHours < 1) {
      return l10n.sharedJoinExpiresInMinutes(delta.inMinutes);
    }
    if (delta.inHours < 24) {
      return l10n.sharedJoinExpiresInHours(delta.inHours);
    }
    return l10n.sharedJoinExpiresInDays(delta.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = _preview;

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.sharedJoinPageTitle,
            subtitle: l10n.sharedJoinPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                if (preview != null)
                  _buildPreviewCard(preview, l10n)
                else
                  _buildInputCard(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(AppLocalizations l10n) {
    return SectionCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sharedJoinEnterCode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sharedJoinEnterCodeHint,
              style: TextStyle(color: SpitoutTokens.textSecondary(context)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              autofocus: true,
              textAlign: TextAlign.center,
              maxLength: 7, // 6 chars + 1 space
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 6,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'ABC 123',
                counterText: '',
                errorText: _error,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[A-Za-z2-9\s]'),
                ),
              ],
              onChanged: (raw) {
                final normalized = _normalizeForInput(raw);
                if (normalized != raw) {
                  _codeController.value = TextEditingValue(
                    text: normalized,
                    selection: TextSelection.collapsed(offset: normalized.length),
                  );
                }
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              onSubmitted: (_) => _doPreview(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _doPreview,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.sharedJoinPreviewButton),
            ),
          ],
        ),
    );
  }

  Widget _buildPreviewCard(SpitoutCloudInvitePreview preview, AppLocalizations l10n) {
    return SectionCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 28,
                child: Text(
                  preview.invitedByDisplay.isNotEmpty
                      ? preview.invitedByDisplay.substring(0, 1).toUpperCase()
                      : '?',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                l10n.sharedJoinInvitedBy(preview.invitedByDisplay),
                style: TextStyle(color: SpitoutTokens.textSecondary(context)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                preview.ledgerName ?? preview.ledgerExternalId,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Chip(
                label: Text(
                  l10n.sharedJoinRoleLine(_formatRoleLabel(preview.targetRole, l10n)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _formatExpiry(preview.expiresAt, l10n),
                style: TextStyle(
                  color: SpitoutTokens.textTertiary(context),
                  fontSize: 12,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _preview = null;
                              _error = null;
                            });
                          },
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _doAccept,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.sharedJoinAcceptButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                DateFormat('yyyy-MM-dd HH:mm').format(preview.expiresAt.toLocal()),
                style: TextStyle(
                    color: SpitoutTokens.textTertiary(context), fontSize: 11),
              ),
            ),
          ],
        ),
    );
  }
}