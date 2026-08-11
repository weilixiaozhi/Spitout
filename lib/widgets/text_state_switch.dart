import 'package:flutter/material.dart';
import 'package:spitout/theme/colors.dart';

/// 轨道内带状态文案的开关
///
/// 系统 Switch 的轨道无法绘制文字,当开关本身需要展示"当前状态说明"
/// (如"关闭AA分摊"/"开启AA分摊")时使用本组件:文案写在轨道内部,
/// 滑块随状态左右滑动(开启靠右、关闭靠左),文字在让出滑块后的
/// 剩余空间内居中展示。两态文案字数相同,文字区宽度一致,布局完全对称。
/// 颜色/尺寸均可在使用处定制,禁用态(onChanged=null)保留「开/关」语义色并
/// 半透明化,与可编辑态区分,避免只读时开启/关闭看起来一样。
class TextStateSwitch extends StatelessWidget {
  /// 当前开关状态
  final bool value;

  /// 状态切换回调,传 null 表示只读禁用(灰化不可点)
  final ValueChanged<bool>? onChanged;

  /// 开启时轨道内部展示的文案
  final String onLabel;

  /// 关闭时轨道内部展示的文案
  final String offLabel;

  /// 轨道宽度,需能容纳文案与滑块
  final double width;

  /// 轨道高度
  final double height;

  /// 轨道圆角(固定小圆角,不随高度放大成胶囊)
  static const double borderRadius = 6;

  /// 轨道内边距:滑块/文案与轨道边缘的统一间距基准
  static const double _padding = 4;

  const TextStateSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onLabel,
    required this.offLabel,
    this.width = 100,
    this.height = 25,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onChanged != null;
    // 先按「开/关」取语义色(开启=主色+白字,关闭=Switch 关闭轨道色+次级文字色),
    // 再统一叠加透明度:可编辑态不透明、只读态半透明。
    // 这样四种组合(开/关 × 可编辑/只读)两两可区分,且只读态仍保留开关语义。
    final trackColor = (value
            ? colors.primary
            : SpitoutTokens.switchInactiveTrack(context))
        .withValues(alpha: enabled ? 1 : 0.5);
    final thumbColor = (value ? Colors.white : SpitoutTokens.surface(context))
        .withValues(alpha: enabled ? 1 : 0.75);
    final textColor = (value
            ? Colors.white
            : SpitoutTokens.textSecondary(context))
        .withValues(alpha: enabled ? 1 : 0.75);
    // 滑块直径 = 轨道高度 - 上下内边距,保证滑块与轨道同心且不溢出
    final thumbSize = height - 2 * _padding;

    return Semantics(
      button: true,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: width,
          height: height,
          padding: const EdgeInsets.all(_padding),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Stack(
            children: [
              // 状态文案:文字区 = 让出滑块后的剩余空间(开启在左、关闭在右),
              // 文字在各自剩余空间内居中。两态文案字数相同,文字区宽度一致,
              // 居中位置左右对称,布局完全一致;
              // 滑块侧紧贴滑块不留内边距,把空间让给文字区,
              // 使 6 字文案(约 58px)在 100 宽轨道内居中后距两侧各约 6px
              AnimatedPositioned(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                left: value ? 0 : thumbSize,
                right: value ? thumbSize : 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    value ? onLabel : offLabel,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              // 滑块:开启靠右、关闭靠左,随状态滑动;
              // 关闭态贴内容区左侧、开启态对称贴内容区右侧(均留 1 倍内边距),
              // 两态与轨道边缘的间距一致,布局完全左右对称,
              // 不让开启态右缘直接贴到轨道外缘。
              AnimatedPositioned(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                left: value ? width - 3 * _padding - thumbSize : _padding,
                top: _padding,
                bottom: _padding,
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: thumbColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
