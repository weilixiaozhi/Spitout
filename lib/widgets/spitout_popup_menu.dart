import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';

/// 菜单项类型
enum SpitoutMenuItemType {
  /// 普通操作项
  action,
  /// 提示信息（禁用状态）
  tip,
  /// 分隔线
  divider,
}

/// 菜单项配置
class SpitoutMenuItem {
  final String? value;
  final String? label;
  final SpitoutMenuItemType type;
  final bool isDanger;

  /// 自定义文字颜色（优先级最高，覆盖 isDanger 的红色），
  /// 用于区分不同危险等级的动作（如警示级用黄色、破坏级用红色）
  final Color? color;

  const SpitoutMenuItem._({
    this.value,
    this.label,
    required this.type,
    this.isDanger = false,
    this.color,
  });

  /// 创建普通操作项
  const SpitoutMenuItem.action({
    required String value,
    required String label,
    bool isDanger = false,
    Color? color,
  }) : this._(
          value: value,
          label: label,
          type: SpitoutMenuItemType.action,
          isDanger: isDanger,
          color: color,
        );

  /// 创建提示信息
  const SpitoutMenuItem.tip({
    required String label,
  }) : this._(
          label: label,
          type: SpitoutMenuItemType.tip,
        );

  /// 创建分隔线
  const SpitoutMenuItem.divider() : this._(type: SpitoutMenuItemType.divider);
}

/// 美化的弹出菜单组件
///
/// 严格按「微信右上角更多菜单」参考图还原：
/// - 菜单紧贴触发按钮下沿，纵向间距 4px（参考图视觉测距）
/// - 弹窗宽度固定 150px（覆盖屏幕右侧近 1/3 宽度，比省略号宽得多）
/// - 每行高度 56px、行间用 0.5px 浅灰横线分隔（"虚线"观感实际为细实线）
/// - 圆角 8px、轻阴影
class SpitoutPopupMenu extends StatelessWidget {
  /// 菜单项列表
  final List<SpitoutMenuItem> items;

  /// 选中回调
  final ValueChanged<String>? onSelected;

  /// 主题色（用于图标背景）
  final Color? primaryColor;

  /// 自定义图标
  final Widget? icon;

  /// 菜单相对触发按钮的偏移。
  ///
  /// 默认 (-15, 50) 是针对「右上角省略号」场景的既有视觉调校；换到其它位置 /
  /// 字号 / 无障碍缩放下应显式传入适配值，不再假设触发图标恒在右上角。
  final Offset menuOffset;

  /// 提示文字
  final String? tooltip;

  /// 菜单宽度：固定值让弹窗比省略号宽得多，匹配参考图观感
  static const double _menuWidth = 150;

  /// 每行高度：参考图视觉测距约 56px（与微信弹窗一致）
  static const double _rowHeight = 56;

  const SpitoutPopupMenu({
    super.key,
    required this.items,
    this.onSelected,
    this.primaryColor,
    this.icon,
    this.menuOffset = const Offset(-15, 50),
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SpitoutTokens.isDark(context);

    // 设计要点：
    // 1) offset (0, 4) 让弹窗紧贴省略号下沿（参考图纵向间距极小）；
    // 2) shape 8px 圆角、elevation 阴影与参考图一致；
    // 3) 单项宽度由 SizedBox(width: _menuWidth) 撑出，
    //    PopupMenuButton 会以最大子项宽度决定弹窗宽度。
    return PopupMenuButton<String>(
      icon: icon ?? Icon(
        AppIcons.moreVertical,
        color: SpitoutTokens.textPrimary(context),
      ),
      tooltip: tooltip,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: SpitoutTokens.surface(context),
      elevation: isDark ? 8 : 4,
      offset: menuOffset,
      onSelected: onSelected,
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> entries = [];
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          // 仅 action 项参与底部细线分隔；最后一项不画线，避免与弹窗底缘冲突。
          final isLastAction = item.type == SpitoutMenuItemType.action &&
              !_hasActionAfter(items, i);
          switch (item.type) {
            case SpitoutMenuItemType.action:
              entries.add(
                _buildActionItem(context, item, showBottomLine: !isLastAction),
              );
              break;
            case SpitoutMenuItemType.tip:
              entries.add(_buildTipItem(context, item));
              break;
            case SpitoutMenuItemType.divider:
              entries.add(const PopupMenuDivider(height: 1));
              break;
          }
        }
        return entries;
      },
    );
  }

  /// 判断 [startIndex] 之后是否还有 action 项，决定是否需要底部细线
  bool _hasActionAfter(List<SpitoutMenuItem> list, int startIndex) {
    for (var i = startIndex + 1; i < list.length; i++) {
      if (list[i].type == SpitoutMenuItemType.action) return true;
    }
    return false;
  }

  PopupMenuItem<String> _buildActionItem(
    BuildContext context,
    SpitoutMenuItem item, {
    bool showBottomLine = true,
  }) {
    // 实现细节：
    // - padding 设为 zero，把水平 16px 内边距挪到 SizedBox 外层 Container，
    //   让底部细线能贯通至弹窗左右缘，避免被 padding 截断出现"线被截断"的瑕疵；
    // - 0.5px 浅灰细线模拟参考图"虚线"观感；
    // - height 56 + 居中竖直摆放，匹配参考图行高与左右边距。
    return PopupMenuItem<String>(
      value: item.value,
      height: _rowHeight,
      padding: EdgeInsets.zero,
      child: Container(
        width: _menuWidth,
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: showBottomLine
              ? Border(
                  bottom: BorderSide(
                    color: SpitoutTokens.divider(context),
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Text(
          item.label ?? '',
          style: TextStyle(
            fontSize: 15,
            // 自定义颜色优先，其次危险红色，最后主题主色
            color: item.color ??
                (item.isDanger ? Colors.red : SpitoutTokens.textPrimary(context)),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildTipItem(BuildContext context, SpitoutMenuItem item) {
    // 提示型菜单项：纯文字辅助描述，不展示图标，与 action 项保持同一内边距
    return PopupMenuItem<String>(
      value: 'tip',
      enabled: false,
      height: 40,
      padding: EdgeInsets.zero,
      child: Container(
        width: _menuWidth,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          item.label ?? '',
          style: TextStyle(
            fontSize: 12,
            color: SpitoutTokens.textTertiary(context),
          ),
        ),
      ),
    );
  }
}
