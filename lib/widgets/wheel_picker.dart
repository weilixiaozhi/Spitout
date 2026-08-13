import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_route.dart';
import 'sheet_grab_handle.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';

/// 通用滚轮选择器
class WheelPicker<T> extends StatefulWidget {
  final T initial;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String title;

  const WheelPicker({
    super.key,
    required this.initial,
    required this.items,
    required this.labelBuilder,
    required this.title,
  });

  @override
  State<WheelPicker<T>> createState() => _WheelPickerState<T>();
}

class _WheelPickerState<T> extends State<WheelPicker<T>> {
  Color _textPrimary(BuildContext context) => SpitoutTokens.textPrimary(context);

  late T selected;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    // initial 不在 items 中时修正为列表首项，避免「确定」返回列表外的值；
    // 空列表是调用方配置错误，保持 initial 且靠 CupertinoPicker 空列表兜底，
    // 不在此处崩溃。
    selected = widget.items.contains(widget.initial)
        ? widget.initial
        : (widget.items.isEmpty ? widget.initial : widget.items.first);
    final index = widget.items.indexOf(selected);
    _controller = FixedExtentScrollController(initialItem: index >= 0 ? index : 0);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetGrabHandle(),
          WheelPickerHeader(
            title: widget.title,
            onConfirm: () => Navigator.pop(context, selected),
          ),
          SizedBox(
            height: 156,
            child: CupertinoPicker(
              itemExtent: 52,
              scrollController: _controller,
              onSelectedItemChanged: (i) => setState(() {
                selected = items[i];
              }),
              children: [
                for (final item in items)
                  Center(
                    child: Text(
                      widget.labelBuilder(item),
                      style: TextStyle(fontSize: 18, color: _textPrimary(context)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 滚轮选择弹层统一标题栏：取消（左）+ 标题（中）+ 确定（右）。
///
/// [WheelPicker] 与 [WheelTimePicker] 共用，避免两处各自维护同一套标题栏样式。
class WheelPickerHeader extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;

  const WheelPickerHeader({
    super.key,
    required this.title,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(
                fontSize: 16,
                color: SpitoutTokens.textTertiary(context),
              ),
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: SpitoutTokens.textPrimary(context),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onConfirm,
            child: Text(
              l10n.commonOk,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 滚轮选择类弹层的统一样式封装：surfaceElevated 背景、顶部 16 圆角、
/// 全局上滑动画。[WheelPicker] / [WheelTimePicker] 共用。
Future<T?> showWheelPickerSheet<T>(
  BuildContext context,
  Widget Function(BuildContext) builder,
) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: SpitoutTokens.surfaceElevated(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    // 全局统一上滑动画：线性曲线（无加速减速），时长与页面切换一致。
    sheetAnimationStyle: kSheetAnimationStyle,
    builder: builder,
  );
}

/// 显示滚轮选择器
Future<T?> showWheelPicker<T>(
  BuildContext context, {
  required T initial,
  required List<T> items,
  required String Function(T) labelBuilder,
  required String title,
}) {
  return showWheelPickerSheet<T>(
    context,
    (_) => WheelPicker<T>(
      initial: initial,
      items: items,
      labelBuilder: labelBuilder,
      title: title,
    ),
  );
}
