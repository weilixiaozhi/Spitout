import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/theme/colors.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/core/logging/logger_service.dart';

enum PinSetupMode { create, change }

class PinSetupPage extends ConsumerStatefulWidget {
  final PinSetupMode mode;

  const PinSetupPage({super.key, this.mode = PinSetupMode.create});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  // 步骤：0=验证旧PIN（仅change模式）, 1=输入新PIN, 2=确认新PIN
  int _step = 0;
  String _pin = '';
  String _firstPin = '';
  bool _isError = false;
  // 服务调用进行中：禁用键盘输入，避免验证期间继续输入造成竞态。
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _step = widget.mode == PinSetupMode.change ? 0 : 1;
  }

  String get _title {
    final l10n = AppLocalizations.of(context);
    if (_step == 0) return l10n.appLockVerifyCurrentPin;
    if (_step == 1) return l10n.appLockSetNewPin;
    return l10n.appLockConfirmPin;
  }

  /// 数字键点击：追加一位 PIN；第 4 位时立即提交并清空输入。
  ///
  /// 设计意图：提交前先快照 _pin 并清空，避免验证期间用户继续输入的新数字
  /// 被失败分支的延迟清空逻辑一起清掉（输入竞态）。
  void _onNumberTap(String number) {
    if (_processing || _pin.length >= 4) return;
    setState(() {
      _isError = false;
      _pin += number;
    });
    if (_pin.length == 4) {
      final pin = _pin;
      setState(() => _pin = '');
      _handlePinComplete(pin);
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

  /// 处理一次完整的 4 位 PIN 提交：按步骤验证 / 记录 / 设置新 PIN。
  ///
  /// 服务调用统一 try-catch：失败时提示友好错误并允许重试，避免未处理异常
  /// 以框架错误形式冒泡。
  Future<void> _handlePinComplete(String pin) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _processing = true);
    try {
      final service = ref.read(appLockServiceProvider);
      if (_step == 0) {
        // 验证旧 PIN
        final valid = await service.verifyPin(pin);
        if (!mounted) return;
        if (valid) {
          setState(() => _step = 1);
        } else {
          _showError();
        }
      } else if (_step == 1) {
        // 记录第一次输入，进入确认步骤
        setState(() {
          _firstPin = pin;
          _step = 2;
        });
      } else {
        // 确认 PIN
        if (pin == _firstPin) {
          await service.setPin(pin);
          ref.read(appLockEnabledProvider.notifier).set(true);
          if (mounted) {
            showToast(context, l10n.appLockPinSetSuccess);
            Navigator.pop(context, true);
          }
        } else {
          _showError();
          // 两次输入不一致：重置到输入新 PIN 步骤
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            setState(() {
              _step = 1;
              _firstPin = '';
            });
          }
        }
      }
    } catch (e, st) {
      logger.error('PinSetup', 'PIN 操作失败', e, st);
      if (mounted) {
        showToast(context, l10n.commonOperationFailed);
        _showError();
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  /// 展示输入错误态：点亮红点，延迟 500ms 后复位。
  void _showError() {
    setState(() => _isError = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _pin = '';
          _isError = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: widget.mode == PinSetupMode.create
                ? AppLocalizations.of(context).appLockSetPin
                : AppLocalizations.of(context).appLockChangePin,
            showBack: true,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // 步骤提示
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      color: SpitoutTokens.textPrimary(context),
                    ),
                  ),
                  SizedBox(height: 32.0),
                  // PIN 圆点
                  PinDotIndicator(filledCount: _pin.length, isError: _isError),
                  const Spacer(flex: 1),
                  // 数字键盘
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.0),
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
