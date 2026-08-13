import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/theme/colors.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/core/logging/logger_service.dart';

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
  // 验证进行中：禁用键盘输入，避免输入竞态。
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  /// 启动时检查生物识别可用性与开关；可用且开启时自动发起认证。
  Future<void> _checkBiometric() async {
    try {
      final service = ref.read(appLockServiceProvider);
      final canUse = await service.canUseBiometrics();
      final enabled = await service.isBiometricEnabled();
      if (!mounted) return;
      setState(() {
        _biometricAvailable = canUse;
        _biometricEnabled = enabled;
      });
      if (canUse && enabled) {
        _authenticateWithBiometrics();
      }
    } catch (e, st) {
      logger.error('AppLock', '读取生物识别配置失败', e, st);
    }
  }

  /// 发起生物识别认证；成功则解锁。
  Future<void> _authenticateWithBiometrics() async {
    final l10n = AppLocalizations.of(context);
    try {
      final service = ref.read(appLockServiceProvider);
      final success = await service.authenticateWithBiometrics(
        reason: l10n.appLockBiometricReason,
      );
      if (success && mounted) {
        _unlock();
      }
    } catch (e, st) {
      logger.error('AppLock', '生物识别认证失败', e, st);
    }
  }

  /// 数字键点击：追加一位 PIN；第 4 位时快照并立即验证。
  ///
  /// 设计意图：提交前清空输入并置 _processing，验证期间的新输入不会与
  /// 失败分支的延迟清空逻辑互相干扰。
  void _onNumberTap(String number) {
    if (_processing || _pin.length >= 4) return;
    setState(() {
      _isError = false;
      _pin += number;
    });
    if (_pin.length == 4) {
      final pin = _pin;
      setState(() => _pin = '');
      _verifyPin(pin);
    }
  }

  /// 删除键：移除最后一位 PIN；验证进行中忽略输入。
  void _onDelete() {
    if (_processing || _pin.isEmpty) return;
    setState(() {
      _isError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  /// 验证 PIN：成功解锁；失败展示错误态并延迟复位。
  ///
  /// 服务调用统一 try-catch：异常时提示友好错误，避免未处理异常冒泡。
  Future<void> _verifyPin(String pin) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _processing = true);
    try {
      final service = ref.read(appLockServiceProvider);
      final success = await service.verifyPin(pin);
      if (!mounted) return;
      if (success) {
        _unlock();
      } else {
        setState(() => _isError = true);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _isError = false;
          });
        }
      }
    } catch (e, st) {
      logger.error('AppLock', 'PIN 验证失败', e, st);
      if (mounted) {
        showToast(context, l10n.commonOperationFailed);
        setState(() => _isError = false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  /// 解锁：记录解锁时间并清除锁定状态。
  void _unlock() {
    ref.read(appLockServiceProvider).recordUnlock();
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
            SpitoutIcon(size: 64.0),
            SizedBox(height: SpitoutDimens.p20),
            // 标题
            Text(
              l10n.appLockEnterPin,
              style: SpitoutTextTokens.boldTitle(context).copyWith(color: SpitoutTokens.textPrimary(context)),
            ),
            SizedBox(height: SpitoutDimens.p32),
            // PIN 圆点
            PinDotIndicator(filledCount: _pin.length, isError: _isError),
            const Spacer(flex: 1),
            // 数字键盘
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SpitoutDimens.p40),
              child: NumberPad(
                onNumberTap: _onNumberTap,
                onDelete: _onDelete,
                showBiometric: showBiometric,
                onBiometric: showBiometric ? _authenticateWithBiometrics : null,
              ),
            ),
            SizedBox(height: SpitoutDimens.p32),
          ],
        ),
      ),
    );
  }
}
