import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_sheet.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/typography.dart';

class WheelTimePicker extends StatefulWidget {
  final TimeOfDay initial;

  const WheelTimePicker({super.key, required this.initial});

  @override
  State<WheelTimePicker> createState() => _WheelTimePickerState();
}

Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  return showAppSheet<TimeOfDay>(
    context: context,
    child: WheelTimePicker(initial: initial),
  );
}

class _WheelTimePickerState extends State<WheelTimePicker> {
  late int hour;
  late int minute;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    hour = widget.initial.hour;
    minute = widget.initial.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: AppLocalizations.of(context).commonSelectTime,
      footer: AppSheetFilledButton(
        label: AppLocalizations.of(context).commonOk,
        onPressed: () => Navigator.of(
          context,
        ).pop(TimeOfDay(hour: hour, minute: minute)),
      ),
      child: SizedBox(
        height: 216,
        child: Row(
          children: [
            // 小时选择器
            Expanded(
              child: CupertinoPicker(
                scrollController: _hourCtrl,
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    hour = index;
                  });
                },
                children: List.generate(24, (index) {
                  return Center(
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: SpitoutTextTokens.boldTitle(context).copyWith(color: SpitoutTokens.textPrimary(context)),
                    ),
                  );
                }),
              ),
            ),

            // 分隔符
            Text(
              ':',
              style: SpitoutTextTokens.boldTitle(context).copyWith(color: SpitoutTokens.textPrimary(context)),
            ),

            // 分钟选择器
            Expanded(
              child: CupertinoPicker(
                scrollController: _minuteCtrl,
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    minute = index;
                  });
                },
                children: List.generate(60, (index) {
                  return Center(
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: SpitoutTextTokens.boldTitle(context).copyWith(color: SpitoutTokens.textPrimary(context)),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
