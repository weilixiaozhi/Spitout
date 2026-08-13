import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';
import 'press_key.dart';

/// PIN 码圆点指示器
class PinDotIndicator extends ConsumerWidget {
  final int length;
  final int filledCount;
  final bool isError;

  const PinDotIndicator({
    super.key,
    this.length = 4,
    required this.filledCount,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final filled = index < filledCount;
        final dotSize = 14.0;
        final color = isError
            ? SpitoutTokens.error(context)
            : (filled ? primaryColor : SpitoutTokens.border(context));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(horizontal: SpitoutDimens.p8),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
        );
      }),
    );
  }
}

/// 数字键盘
class NumberPad extends ConsumerWidget {
  final ValueChanged<String> onNumberTap;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final bool showBiometric;

  const NumberPad({
    super.key,
    required this.onNumberTap,
    required this.onDelete,
    this.onBiometric,
    this.showBiometric = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['bio', '0', 'del'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: keys.map((row) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: SpitoutDimens.p4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key == 'bio') {
                return _buildKeyButton(
                  context,
                  ref,
                  child: showBiometric
                      ? Icon(AppIcons.fingerprint,
                          size: SpitoutDimens.icon28,
                          color: SpitoutTokens.textPrimary(context))
                      : const SizedBox.shrink(),
                  onTap: showBiometric ? onBiometric : null,
                );
              }
              if (key == 'del') {
                return _buildKeyButton(
                  context,
                  ref,
                  child: Icon(AppIcons.backspace,
                      size: SpitoutDimens.icon22,
                      color: SpitoutTokens.textPrimary(context)),
                  onTap: onDelete,
                );
              }
              return _buildKeyButton(
                context,
                ref,
                child: Text(
                  key,
                  style: SpitoutTextTokens.display2(context).copyWith(color: SpitoutTokens.textPrimary(context)),
                ),
                onTap: () => onNumberTap(key),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyButton(
    BuildContext context,
    WidgetRef ref, {
    required Widget child,
    VoidCallback? onTap,
  }) {
    final size = 72.0;
    return PressKey(
      enabled: onTap != null,
      scale: 0.94,
      // 触觉在按下瞬间触发，视觉按压态立即呈现；数字提交仍走松手，避免误触
      onDown: onTap == null ? null : () => HapticFeedback.lightImpact(),
      onUp: onTap,
      backgroundColor: onTap != null
          ? SpitoutTokens.surfaceSecondary(context)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}
