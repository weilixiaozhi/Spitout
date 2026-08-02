import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';

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
          margin: EdgeInsets.symmetric(horizontal: 10.0),
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
          padding: EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key == 'bio') {
                return _buildKeyButton(
                  context,
                  ref,
                  child: showBiometric
                      ? Icon(AppIcons.fingerprint,
                          size: 28.0,
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
                      size: 24.0,
                      color: SpitoutTokens.textPrimary(context)),
                  onTap: onDelete,
                );
              }
              return _buildKeyButton(
                context,
                ref,
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 28.0,
                    fontWeight: FontWeight.w400,
                    color: SpitoutTokens.textPrimary(context),
                  ),
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
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap();
        }
      },
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null
              ? SpitoutTokens.surfaceSecondary(context)
              : Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}
