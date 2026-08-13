import 'package:flutter/cupertino.dart';
import 'app_sheet.dart';
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

    return AppSheet(
      title: widget.title,
      footer: AppSheetFilledButton(
        label: AppLocalizations.of(context).commonOk,
        onPressed: () => Navigator.pop(context, selected),
      ),
      child: SizedBox(
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
    );
  }
}

/// 显示滚轮选择器
Future<T?> showWheelPicker<T>(
  BuildContext context, {
  required T initial,
  required List<T> items,
  required String Function(T) labelBuilder,
  required String title,
}) {
  return showAppSheet<T>(
    context: context,
    child: WheelPicker<T>(
      initial: initial,
      items: items,
      labelBuilder: labelBuilder,
      title: title,
    ),
  );
}
