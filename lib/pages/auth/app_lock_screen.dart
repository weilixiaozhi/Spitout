import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/colors.dart';
import 'package:spitout/providers/security/security_providers.dart';
import '../../services/security/app_lock_service.dart';
import '../../widgets/pin_entry_pad.dart';
import '../../widgets/spitout_icon.dart';
import '../../l10n/app_localizations.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _pin = '';
  bool _isError = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final canUse = await AppLockService.canUseBiometrics();
    final enabled = await AppLockService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = canUse;
        _biometricEnabled = enabled;
      });
      if (canUse && enabled) {
        _authenticateWithBiometrics();
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final l10n = AppLocalizations.of(context);
    final success = await AppLockService.authenticateWithBiometrics(
      reason: l10n.appLockBiometricReason,
    );
    if (success && mounted) {
      _unlock();
    }
  }

  void _onNumberTap(String number) {
    if (_pin.length >= 4) return;
    setState(() {
      _isError = false;
      _pin += number;
    });
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _isError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    final success = await AppLockService.verifyPin(_pin);
    if (success) {
      _unlock();
    } else {
      setState(() {
        _isError = true;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _pin = '';
          _isError = false;
        });
      }
    }
  }

  void _unlock() {
    AppLockService.recordUnlock();
    ref.read(isAppLockedProvider.notifier).set(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showBiometric = _biometricAvailable && _biometricEnabled;

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Logo
            SpitoutIcon(
              size: 64.0,
            ),
            SizedBox(height: 24.0),
            // 标题
            Text(
              l10n.appLockEnterPin,
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
                color: SpitoutTokens.textPrimary(context),
              ),
            ),
            SizedBox(height: 32.0),
            // PIN 圆点
            PinDotIndicator(
              filledCount: _pin.length,
              isError: _isError,
            ),
            const Spacer(flex: 1),
            // 数字键盘
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 40.0),
              child: NumberPad(
                onNumberTap: _onNumberTap,
                onDelete: _onDelete,
                showBiometric: showBiometric,
                onBiometric:
                    showBiometric ? _authenticateWithBiometrics : null,
              ),
            ),
            SizedBox(height: 32.0),
          ],
        ),
      ),
    );
  }
}
