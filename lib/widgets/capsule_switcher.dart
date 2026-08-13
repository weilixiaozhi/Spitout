import 'package:flutter/material.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// 胶囊选项配置
class CapsuleOption<T> {
  final T value;
  final String label;
  final VoidCallback? onTap; // 点击箭头的回调
  final bool showArrow;

  const CapsuleOption({
    required this.value,
    required this.label,
    this.onTap,
    this.showArrow = false,
  });
}

/// 通用胶囊切换器组件
class CapsuleSwitcher<T> extends StatelessWidget {
  final T selectedValue;
  final List<CapsuleOption<T>> options;
  final ValueChanged<T> onChanged;
  final Color? backgroundColor;
  final Color? selectedBackgroundColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final double height;
  final BorderRadius? borderRadius;

  const CapsuleSwitcher({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.height = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // 空选项降级为空容器：options.length * 2 - 1 在空列表时为 -1，
    // take(-1) 会抛 RangeError，未来新增入口直接传空列表也不应崩溃。
    if (options.isEmpty) return const SizedBox.shrink();

    final isDark = SpitoutTokens.isDark(context);
    final bg = backgroundColor ?? SpitoutTokens.surfaceCapsule(context);
    final selectedBg = selectedBackgroundColor ??
        (isDark
            ? SpitoutTokens.primary(context)
            : SpitoutTokens.surfaceInverse(context));
    final selectedFg = selectedTextColor ?? Colors.white;
    final unselectedFg = unselectedTextColor ?? SpitoutTokens.textPrimary(context);
    final radius = borderRadius ?? BorderRadius.circular(20);

    Widget buildSegment(CapsuleOption<T> option) {
      final selected = selectedValue == option.value;
      // 分段圆角与选中态底色变化保持一致；选中变色即反馈，按统一原则不加涟漪
      final radius = BorderRadius.circular((height - 6) / 2);
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(option.value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: height - 6, // 减去padding
            decoration: BoxDecoration(
              color: selected ? selectedBg : Colors.transparent,
              borderRadius: radius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                // 段内宽度由 Expanded 均分后可能小于英文长标签（如 Week/Month/Year）
                // 的自然宽度，直接放 Text 会触发 RenderFlex overflow；
                // 用 FittedBox(scaleDown) 让标签在放不下时等比缩小、放得下时保持原样。
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      option.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: selected ? selectedFg : unselectedFg,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                if (option.showArrow && option.onTap != null) ...[
                  const SizedBox(width: 4),
                  // 箭头是独立的纯动作（拉起下拉），无选中态，按原则补涟漪反馈
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: option.onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(
                        AppIcons.chevronDown,
                        size: 18,
                        color: SpitoutTokens.iconTertiary(context),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
      ),
      child: Row(
        children: options
            .map((option) => buildSegment(option))
            .expand((widget) => [widget, const SizedBox(width: 4)])
            .take(options.length * 2 - 1) // 移除最后一个SizedBox
            .toList(),
      ),
    );
  }
}
