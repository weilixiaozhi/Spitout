import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'package:spitout/providers/security/security_providers.dart';
import '../../services/security/app_lock_service.dart';
import '../../widgets/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/pin_setup_page.dart';
import '../../theme/icons/app_icons.dart';

class AppLockSettingsPage extends ConsumerStatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  ConsumerState<AppLockSettingsPage> createState() =>
      _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends ConsumerState<AppLockSettingsPage> {
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final canUse = await AppLockService.canUseBiometrics();
    if (mounted) {
      setState(() => _canUseBiometrics = canUse);
    }
  }

  Future<void> _toggleAppLock(bool enable) async {
    final l10n = AppLocalizations.of(context);

    if (enable) {
      // 开启：跳转设置 PIN
      final result = await Navigator.push<bool>(
        context,
        appPageRoute(
          builder: (_) => const PinSetupPage(mode: PinSetupMode.create),
        ),
      );
      // 如果用户取消设置，开关回弹
      if (result != true) return;
    } else {
      // 关闭：需要验证当前 PIN
      final verified = await _verifyCurrentPin();
      if (!verified) return;

      await AppLockService.clearPin();
      ref.read(appLockEnabledProvider.notifier).set(false);
      ref.read(appLockBiometricEnabledProvider.notifier).set(false);
      if (mounted) {
        showToast(context, l10n.appLockDisabled);
      }
    }
  }

  Future<bool> _verifyCurrentPin() async {
    final result = await Navigator.push<bool>(
      context,
      appPageRoute(
        builder: (_) => const _PinVerifyPage(),
      ),
    );
    return result == true;
  }

  Future<void> _changePin() async {
    await Navigator.push(
      context,
      appPageRoute(
        builder: (_) => const PinSetupPage(mode: PinSetupMode.change),
      ),
    );
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      // 先验证生物识别可用
      final success = await AppLockService.authenticateWithBiometrics(
        reason: AppLocalizations.of(context).appLockBiometricReason,
      );
      if (!success) return;
    }
    ref.read(appLockBiometricEnabledProvider.notifier).set(enable);
    await AppLockService.setBiometricEnabled(enable);
  }

  void _showTimeoutPicker() {
    final l10n = AppLocalizations.of(context);
    final currentTimeout = ref.read(appLockTimeoutProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final options = [
      (0, l10n.appLockTimeoutImmediate),
      (60, l10n.appLockTimeout1Min),
      (300, l10n.appLockTimeout5Min),
      (900, l10n.appLockTimeout15Min),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: SpitoutTokens.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // 全局统一上滑动画：线性曲线（无加速减速），时长与页面切换一致。
      sheetAnimationStyle: kSheetAnimationStyle,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.appLockTimeout,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: SpitoutTokens.textPrimary(ctx),
                  ),
                ),
              ),
              ...options.map((opt) {
                final isSelected = opt.$1 == currentTimeout;
                return ListTile(
                  title: Text(opt.$2),
                  trailing: isSelected
                      ? Icon(AppIcons.check, color: primaryColor)
                      : null,
                  onTap: () {
                    ref.read(appLockTimeoutProvider.notifier).set(opt.$1);
                    AppLockService.setTimeoutSeconds(opt.$1);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _timeoutLabel(int seconds) {
    final l10n = AppLocalizations.of(context);
    switch (seconds) {
      case 0:
        return l10n.appLockTimeoutImmediate;
      case 60:
        return l10n.appLockTimeout1Min;
      case 300:
        return l10n.appLockTimeout5Min;
      case 900:
        return l10n.appLockTimeout15Min;
      default:
        return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(appLockEnabledProvider);
    final biometricEnabled = ref.watch(appLockBiometricEnabledProvider);
    final timeout = ref.watch(appLockTimeoutProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.appLockTitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                top: 8.0,
                bottom: 16.0,
              ),
              children: [
                // 应用锁开关
                SectionCard(
                  child: Column(
                    children: [
                      _SwitchTile(
                        icon: AppIcons.lock,
                        title: l10n.appLockEnable,
                        subtitle: l10n.appLockEnableDesc,
                        value: enabled,
                        onChanged: _toggleAppLock,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                ),
                if (enabled) ...[
                  SizedBox(height: 8.0),
                  // PIN 管理
                  SectionCard(
                    child: Column(
                      children: [
                        AppListTile(
                          leading: AppIcons.dialpad,
                          title: l10n.appLockChangePin,
                          trailing: Icon(AppIcons.chevronRight,
                              color: SpitoutTokens.iconTertiary(context),
                              size: 20),
                          onTap: _changePin,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.0),
                  // 生物识别 + 超时
                  SectionCard(
                    child: Column(
                      children: [
                        if (_canUseBiometrics) ...[
                          _SwitchTile(
                            icon: AppIcons.fingerprint,
                            title: l10n.appLockBiometric,
                            subtitle: l10n.appLockBiometricDesc,
                            value: biometricEnabled,
                            onChanged: _toggleBiometric,
                            primaryColor: primaryColor,
                          ),
                          SpitoutTokens.cardDivider(context),
                        ],
                        AppListTile(
                          leading: AppIcons.timer,
                          title: l10n.appLockTimeout,
                          subtitle: _timeoutLabel(timeout),
                          trailing: Icon(AppIcons.chevronRight,
                              color: SpitoutTokens.iconTertiary(context),
                              size: 20),
                          onTap: _showTimeoutPicker,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 带开关的设置项
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color primaryColor;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SpitoutTextTokens.title(context)
                      .copyWith(color: SpitoutTokens.textPrimary(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: SpitoutTextTokens.label(context)
                      .copyWith(color: SpitoutTokens.textSecondary(context)),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primaryColor,
          ),
        ],
      ),
    );
  }
}

/// 验证当前 PIN 页面（用于关闭应用锁时验证）
class _PinVerifyPage extends ConsumerStatefulWidget {
  const _PinVerifyPage();

  @override
  ConsumerState<_PinVerifyPage> createState() => _PinVerifyPageState();
}

class _PinVerifyPageState extends ConsumerState<_PinVerifyPage> {
  String _pin = '';
  bool _isError = false;

  void _onNumberTap(String number) {
    if (_pin.length >= 4) return;
    setState(() {
      _isError = false;
      _pin += number;
    });
    if (_pin.length == 4) {
      _verify();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _isError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verify() async {
    final success = await AppLockService.verifyPin(_pin);
    if (success) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _isError = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _pin = '';
          _isError = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.appLockVerifyPin,
            showBack: true,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Text(
                    l10n.appLockVerifyCurrentPin,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      color: SpitoutTokens.textPrimary(context),
                    ),
                  ),
                  SizedBox(height: 32.0),
                  PinDotIndicator(
                    filledCount: _pin.length,
                    isError: _isError,
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 40.0),
                    child: NumberPad(
                      onNumberTap: _onNumberTap,
                      onDelete: _onDelete,
                    ),
                  ),
                  SizedBox(height: 32.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
