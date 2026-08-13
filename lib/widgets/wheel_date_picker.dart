import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_sheet.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/utils/date/week_math.dart'
    show mondayOf, mondayOfWeek, weekNumber, weeksInYear;

/// 滚轮选择模式：年 / 年-月 / 年-月-日 / 年-周（统计页周账期筛选）/ 年-月-日-时-分（记账页）。
enum WheelDatePickerMode { y, ym, ymd, week, datetime }

/// datetime 模式下按边界日计算可选「小时」范围。
///
/// 边界日（与 [min] / [max] 同一天）受其时刻约束，其余日期 0-23 全量；
/// 抽出为纯函数便于单测逐列钳制逻辑。
@visibleForTesting
List<int> hourRangeForDateTime({
  required DateTime date,
  required DateTime min,
  required DateTime max,
}) {
  int start = 0, end = 23;
  if (date.year == min.year && date.month == min.month && date.day == min.day) {
    start = min.hour;
  }
  if (date.year == max.year && date.month == max.month && date.day == max.day) {
    end = max.hour;
  }
  return [for (int h = start; h <= end; h++) h];
}

/// datetime 模式下某小时可选「分钟」范围。
///
/// 仅「边界日 + 边界小时」受 [min] / [max] 分钟约束，其余时段 0-59 全量。
@visibleForTesting
List<int> minuteRangeForDateTime({
  required DateTime date,
  required int hour,
  required DateTime min,
  required DateTime max,
}) {
  int start = 0, end = 59;
  final isMinBoundary = date.year == min.year &&
      date.month == min.month &&
      date.day == min.day &&
      hour == min.hour;
  final isMaxBoundary = date.year == max.year &&
      date.month == max.month &&
      date.day == max.day &&
      hour == max.hour;
  if (isMinBoundary) start = min.minute;
  if (isMaxBoundary) end = max.minute;
  return [for (int m = start; m <= end; m++) m];
}

class WheelDatePicker extends StatefulWidget {
  /// 初始选中时间。
  final DateTime initial;

  /// 选择粒度（年 / 年月 / 年月日 / 周年 / 完整日期时间）。
  final WheelDatePickerMode mode;

  /// 可选下限（含）。不传时按模式取默认（见 [_min] 注释）。
  final DateTime? minDate;

  /// 可选上限（含）。不传时按模式取默认（见 [_max] 注释）。
  final DateTime? maxDate;

  /// 居中标题（顶部）。不传则按模式取合理默认文案。
  final String title;

  /// 居中副标题（标题下方）。不传则不渲染副标题区。
  final String? subtitle;

  /// 底部主按钮文案（如「完成」）。不传则按模式取默认文案。
  final String confirmLabel;

  const WheelDatePicker({
    super.key,
    required this.initial,
    this.mode = WheelDatePickerMode.ymd,
    this.minDate,
    this.maxDate,
    required this.title,
    this.subtitle,
    required this.confirmLabel,
  });

  @override
  State<WheelDatePicker> createState() => _WheelDatePickerState();
}

/// 统一日期/时间滚轮选择器。
///
/// 设计基准：首页 month_picker_sheet 的 AppSheet 视觉（居中标题 + 副标题 + 主色填充完成按钮），
/// 并统一所有模式（年/年月/年月日/周年/日期时间）的滚轮观感：无列标签、选中高亮带
/// primary/0.08 背景 + primary/0.3 上下描边、itemExtent 40。
Future<DateTime?> showWheelDatePicker(
  BuildContext context, {
  required DateTime initial,
  WheelDatePickerMode mode = WheelDatePickerMode.ymd,
  DateTime? minDate,
  DateTime? maxDate,
  /// 标题（可选）。不传时按 [mode] 取合理默认文案。
  String? title,
  /// 副标题（可选）。不传则按 [mode] 取默认（多数模式无副标题）。
  String? subtitle,
  /// 底部主按钮文案（可选）。不传时按 [mode] 取默认（通常「完成」）。
  String? confirmLabel,
  // 子 sheet 挂载 navigator(false = 就近 / nested);默认 true 使用主 navigator
  bool useRootNavigator = true,
  // 子 sheet 遮罩色;记账页内调用传透明以不显示遮罩
  Color? barrierColor,
}) {
  // 入口校验：minDate > maxDate 时年份列表为空，CupertinoPicker 无子项且
  // 控制器 initialItem=-1 会抛异常，提前以明确错误阻断而非运行期崩溃。
  if (minDate != null && maxDate != null && minDate.isAfter(maxDate)) {
    throw ArgumentError('WheelDatePicker: minDate 不能晚于 maxDate');
  }

  final l10n = AppLocalizations.of(context);
  // 按模式解析标题/副标题/确认文案默认值，调用方传参可覆盖。
  String resolvedTitle;
  String? resolvedSubtitle;
  String resolvedConfirm;
  switch (mode) {
    case WheelDatePickerMode.week:
      resolvedTitle = title ?? l10n.analyticsSelectWeek;
      resolvedSubtitle = subtitle;
      resolvedConfirm = confirmLabel ?? l10n.commonDone;
    case WheelDatePickerMode.datetime:
      resolvedTitle = title ?? l10n.txSelectDateTimeTitle;
      resolvedSubtitle = subtitle ?? l10n.txSelectDateTimeHint;
      resolvedConfirm = confirmLabel ?? l10n.commonFinish;
    case WheelDatePickerMode.ym:
      resolvedTitle = title ?? l10n.homeSelectBillMonth;
      resolvedSubtitle = subtitle ?? l10n.homePickerHint;
      resolvedConfirm = confirmLabel ?? l10n.commonDone;
    case WheelDatePickerMode.y:
    case WheelDatePickerMode.ymd:
      resolvedTitle = title ?? l10n.homeSelectDate;
      resolvedSubtitle = subtitle;
      resolvedConfirm = confirmLabel ?? l10n.commonDone;
  }

  return showAppSheet<DateTime>(
    context: context,
    // 内层用 surfaceSheet 圆角容器承载内容,外层透明以便记账页子 Drawer 场景透传透明遮罩。
    backgroundColor: Colors.transparent,
    useRootNavigator: useRootNavigator,
    barrierColor: barrierColor,
    child: WheelDatePicker(
      initial: initial,
      mode: mode,
      minDate: minDate,
      maxDate: maxDate,
      title: resolvedTitle,
      subtitle: resolvedSubtitle,
      confirmLabel: resolvedConfirm,
    ),
  );
}

class _WheelDatePickerState extends State<WheelDatePicker> {
  Color _textPrimary(BuildContext context) => SpitoutTokens.textPrimary(context);
  late int year;
  late int month;
  late int day;
  // 时/分（仅 datetime 模式使用,但控制器始终创建以便统一释放）。
  late int hour;
  late int minute;
  // week 模式：当前选中的「年内周序号」（1-based，口径见 weekNumber）
  late int week;
  late FixedExtentScrollController _yearCtrl;
  FixedExtentScrollController? _monthCtrl;
  FixedExtentScrollController? _dayCtrl;
  FixedExtentScrollController? _weekCtrl;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    // 入口校验（直接构造组件时同样生效）：防止 min > max 产生空年份列表。
    if (_min.isAfter(_max)) {
      throw ArgumentError('WheelDatePicker: minDate 不能晚于 maxDate');
    }
    final clamped = _clamp(widget.initial);
    year = clamped.year;
    month = clamped.month;
    day = clamped.day;
    hour = clamped.hour;
    minute = clamped.minute;
    // week 模式的「年」以周所在周一的年份为准（与子 Tab id 口径一致：
    // 跨年周归属其周一所在年），避免年初/年末选错年份。
    if (widget.mode == WheelDatePickerMode.week) {
      final monday = mondayOf(clamped);
      year = monday.year;
      week = weekNumber(monday);
    } else {
      week = 1;
    }
    // 初始化滚动控制器（year 必选;时/分必选,其余按模式惰性创建）
    final years = _yearList();
    _yearCtrl = FixedExtentScrollController(initialItem: years.indexOf(year));
    // datetime 模式下时/分列按边界日钳制（见 _hourListForDateTime），
    // initialItem 必须是「值在列表中的索引」而非值本身。
    final hours = _hourListForDateTime();
    final hourIndex = hours.indexOf(hour);
    _hourCtrl = FixedExtentScrollController(initialItem: hourIndex < 0 ? 0 : hourIndex);
    final minutes = _minuteListForDateTime(hour);
    final minuteIndex = minutes.indexOf(minute);
    _minuteCtrl = FixedExtentScrollController(initialItem: minuteIndex < 0 ? 0 : minuteIndex);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl?.dispose();
    _dayCtrl?.dispose();
    _weekCtrl?.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  // 所有模式统一使用 2000/2100 作为默认边界，datetime 不锚定「今天」。
  // 记账页无需显式传 maxDate 即可选到任意未来时间，统计/导出/循环记账范围也保持一致。
  DateTime get _min => widget.minDate ?? DateTime(2000, 1, 1);
  DateTime get _max => widget.maxDate ?? DateTime(2100, 12, 31);

  // week 模式下 min/max 统一换算为「所在周的周一」：选择器的一切边界
  // 都以周为单位对齐，保证可选项与统计页子 Tab 生成口径完全一致。
  DateTime get _effectiveMin =>
      widget.mode == WheelDatePickerMode.week ? mondayOf(_min) : _min;
  DateTime get _effectiveMax =>
      widget.mode == WheelDatePickerMode.week ? mondayOf(_max) : _max;

  DateTime _clamp(DateTime d) {
    if (d.isBefore(_min)) return _min;
    if (d.isAfter(_max)) return _max;
    return d;
  }

  List<int> _yearList() =>
      [for (int y = _effectiveMin.year; y <= _effectiveMax.year; y++) y];

  // 依据 [_min]/[_max] 裁出某年可选月份范围（边界年受 min/max 限制）。
  List<int> _monthListForYear(int y) {
    int start = 1, end = 12;
    if (y == _min.year) start = _min.month;
    if (y == _max.year) end = _max.month;
    return [for (int m = start; m <= end; m++) m];
  }

  // 依据 [_min]/[_max] 裁出某年某月可选日范围（边界年/月受 min/max 限制）。
  List<int> _dayListForYM(int y, int m) {
    final last = DateTime(y, m + 1, 0).day;
    int start = 1, end = last;
    if (y == _min.year && m == _min.month) start = _min.day;
    if (y == _max.year && m == _max.month) end = _max.day;
    return [for (int d = start; d <= end; d++) d];
  }

  // datetime 模式下某年某月某日可选「小时」范围：边界日受 [_min]/[_max]
  // 时刻约束，其余日期 0-23 全量。逐列钳制避免「整体 _clamp 把用户选的时间
  // 静默改成边界时刻」（如 min 为今天 09:00 时，今天 08:00 直接不可选）。
  List<int> _hourListForDateTime() => hourRangeForDateTime(
        date: DateTime(year, month, day),
        min: _min,
        max: _max,
      );

  // datetime 模式下某小时可选「分钟」范围：边界日 + 边界小时受 min/max 约束，
  // 其余时段 0-59 全量。
  List<int> _minuteListForDateTime(int hour) => minuteRangeForDateTime(
        date: DateTime(year, month, day),
        hour: hour,
        min: _min,
        max: _max,
      );

  // 某年可选「年内周序号」范围（边界年受 [_effectiveMin]/[_effectiveMax] 限制）。
  List<int> _weekListForYear(int y) {
    int sw = 1, ew = weeksInYear(y);
    if (y == _effectiveMin.year) sw = weekNumber(_effectiveMin);
    if (y == _effectiveMax.year) ew = weekNumber(_effectiveMax);
    if (ew < sw) ew = sw;
    return [for (var w = sw; w <= ew; w++) w];
  }

  // ── 列变更回调：更新状态并把依赖列跳转到新索引（post-frame 避免 build 中跳变）──
  void _onYearChanged(int index) {
    setState(() {
      year = _yearList()[index];
      final months = _monthListForYear(year);
      if (!months.contains(month)) month = months.last;
      final days = _dayListForYM(year, month);
      if (!days.contains(day)) day = days.last;
      if (widget.mode == WheelDatePickerMode.week) {
        final weeks = _weekListForYear(year);
        if (!weeks.contains(week)) week = weeks.last;
      }
      if (widget.mode == WheelDatePickerMode.datetime) {
        final hours = _hourListForDateTime();
        if (!hours.contains(hour)) hour = hours.last;
        final minutes = _minuteListForDateTime(hour);
        if (!minutes.contains(minute)) minute = minutes.last;
      }
    });
    final mi = _monthListForYear(year).indexOf(month);
    if (_monthCtrl != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _monthCtrl!.jumpToItem(mi < 0 ? 0 : mi));
    }
    final di = _dayListForYM(year, month).indexOf(day);
    if (_dayCtrl != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _dayCtrl!.jumpToItem(di < 0 ? 0 : di));
    }
    if (widget.mode == WheelDatePickerMode.week) {
      final wi = _weekListForYear(year).indexOf(week);
      if (_weekCtrl != null) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _weekCtrl!.jumpToItem(wi < 0 ? 0 : wi));
      }
    }
    if (widget.mode == WheelDatePickerMode.datetime) {
      final hi = _hourListForDateTime().indexOf(hour);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _hourCtrl.jumpToItem(hi < 0 ? 0 : hi));
      final mi = _minuteListForDateTime(hour).indexOf(minute);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _minuteCtrl.jumpToItem(mi < 0 ? 0 : mi));
    }
  }

  void _onMonthChanged(int index) {
    setState(() {
      month = _monthListForYear(year)[index];
      final days = _dayListForYM(year, month);
      if (!days.contains(day)) day = days.last;
      if (widget.mode == WheelDatePickerMode.datetime) {
        final hours = _hourListForDateTime();
        if (!hours.contains(hour)) hour = hours.last;
        final minutes = _minuteListForDateTime(hour);
        if (!minutes.contains(minute)) minute = minutes.last;
      }
    });
    final di = _dayListForYM(year, month).indexOf(day);
    if (_dayCtrl != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _dayCtrl!.jumpToItem(di < 0 ? 0 : di));
    }
    if (widget.mode == WheelDatePickerMode.datetime) {
      final hi = _hourListForDateTime().indexOf(hour);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _hourCtrl.jumpToItem(hi < 0 ? 0 : hi));
      final mi = _minuteListForDateTime(hour).indexOf(minute);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _minuteCtrl.jumpToItem(mi < 0 ? 0 : mi));
    }
  }

  void _onDayChanged(int index) {
    setState(() {
      day = _dayListForYM(year, month)[index];
      if (widget.mode == WheelDatePickerMode.datetime) {
        final hours = _hourListForDateTime();
        if (!hours.contains(hour)) hour = hours.last;
        final minutes = _minuteListForDateTime(hour);
        if (!minutes.contains(minute)) minute = minutes.last;
      }
    });
    if (widget.mode == WheelDatePickerMode.datetime) {
      final hi = _hourListForDateTime().indexOf(hour);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _hourCtrl.jumpToItem(hi < 0 ? 0 : hi));
      final mi = _minuteListForDateTime(hour).indexOf(minute);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _minuteCtrl.jumpToItem(mi < 0 ? 0 : mi));
    }
  }

  void _onWeekChanged(int index) =>
      setState(() => week = _weekListForYear(year)[index]);

  void _onHourChanged(int index) {
    setState(() {
      hour = _hourListForDateTime()[index];
      final minutes = _minuteListForDateTime(hour);
      if (!minutes.contains(minute)) minute = minutes.last;
    });
    // 边界小时的分钟列表可能变窄，跳转到新列表内的合法索引。
    final mi = _minuteListForDateTime(hour).indexOf(minute);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _minuteCtrl.jumpToItem(mi < 0 ? 0 : mi));
  }

  void _onMinuteChanged(int index) =>
      setState(() => minute = _minuteListForDateTime(hour)[index]);

  /// 组合当前各列得到最终 DateTime（按模式夹到有效边界内）。
  DateTime _buildResult() {
    switch (widget.mode) {
      case WheelDatePickerMode.y:
        return _clamp(DateTime(year, 1, 1));
      case WheelDatePickerMode.ym:
        return _clamp(DateTime(year, month, 1));
      case WheelDatePickerMode.ymd:
        return _clamp(DateTime(year, month, day));
      case WheelDatePickerMode.week:
        // 年 + 周序号 → 该周周一;防御性夹到有效边界内
        var result = mondayOfWeek(year, week);
        if (result.isBefore(_effectiveMin)) result = _effectiveMin;
        if (result.isAfter(_effectiveMax)) result = _effectiveMax;
        return result;
      case WheelDatePickerMode.datetime:
        // 时/分写死全量、不钳制;整体 DateTime 夹到 [_min]/[_max] 即可
        // （maxDate 通常含 23:59,实际不会截断用户选择的时间）。
        return _clamp(DateTime(year, month, day, hour, minute));
    }
  }

  /// 无列标签的单滚轮（统一 itemExtent 40 + 选中高亮带 primary/0.08 + primary/0.3）。
  Widget _buildPicker({
    required List<int> items,
    required FixedExtentScrollController? controller,
    required ValueChanged<int> onChanged,
    required String Function(int) formatter,
    required Widget selectionOverlay,
  }) {
    return Expanded(
      child: CupertinoPicker(
        selectionOverlay: selectionOverlay,
        itemExtent: 40,
        scrollController: controller,
        onSelectedItemChanged: onChanged,
        children: [
          for (final v in items)
            Center(
              child: Text(formatter(v),
                  style: SpitoutTextTokens.boldTitle(context).copyWith(color: _textPrimary(context))),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final mode = widget.mode;
    // 统一选中高亮带:primary/0.08 背景 + primary/0.3 上下描边（所有列复用同一实例）。
    final selectionOverlay = Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        border: Border(
          top: BorderSide(color: primary.withValues(alpha: 0.3), width: 1),
          bottom: BorderSide(color: primary.withValues(alpha: 0.3), width: 1),
        ),
      ),
    );

    // week 模式使用按周对齐后的边界（详见 _effectiveMin/_effectiveMax 注释）
    final years = _yearList();
    final months = _monthListForYear(year);
    final days = _dayListForYM(year, month);

    // 确保 month/day 控制器已创建并指向当前索引
    _monthCtrl ??=
        FixedExtentScrollController(initialItem: months.indexOf(month));
    final dayIndex = days.indexOf(day);
    _dayCtrl ??=
        FixedExtentScrollController(initialItem: dayIndex < 0 ? 0 : dayIndex);

    // 各列滚轮（无列标签）
    final yearPicker = _buildPicker(
      items: years,
      controller: _yearCtrl,
      onChanged: _onYearChanged,
      formatter: (v) => '$v',
      selectionOverlay: selectionOverlay,
    );
    final monthPicker = _buildPicker(
      items: months,
      controller: _monthCtrl,
      onChanged: _onMonthChanged,
      formatter: (v) => '$v',
      selectionOverlay: selectionOverlay,
    );
    final dayPicker = _buildPicker(
      items: days,
      controller: _dayCtrl,
      onChanged: _onDayChanged,
      formatter: (v) => '$v',
      selectionOverlay: selectionOverlay,
    );

    // 单组滚轮容器(固定 5 个可见项高度 40*5)
    Widget group(List<Widget> pickers) =>
        SizedBox(height: 200, child: Row(children: pickers));

    Widget body;
    switch (mode) {
      case WheelDatePickerMode.y:
        body = group([yearPicker]);
      case WheelDatePickerMode.ym:
        body = group([yearPicker, monthPicker]);
      case WheelDatePickerMode.ymd:
        body = group([yearPicker, monthPicker, dayPicker]);
      case WheelDatePickerMode.week:
        final weeks = _weekListForYear(year);
        // 仅取防御性展示值，不直接改字段（build 中改字段无 setState 会与
        // UI 状态短暂不一致；week 的收敛已由 _onYearChanged 负责）。
        final effectiveWeek = week < weeks.first
            ? weeks.first
            : (week > weeks.last ? weeks.last : week);
        _weekCtrl ??= FixedExtentScrollController(
            initialItem: weeks.indexOf(effectiveWeek));
        final weekPicker = _buildPicker(
          items: weeks,
          controller: _weekCtrl,
          onChanged: _onWeekChanged,
          formatter: (v) => l10n.analyticsWeekN(v),
          selectionOverlay: selectionOverlay,
        );
        body = group([yearPicker, weekPicker]);
      case WheelDatePickerMode.datetime:
        // 时/分按边界日逐列钳制（见 _hourListForDateTime），用户在边界日
        // 选不到越界时刻，不被整体 _clamp 静默改成 min/max。
        final hours = _hourListForDateTime();
        final minutes = _minuteListForDateTime(hour);
        final hourPicker = _buildPicker(
          items: hours,
          controller: _hourCtrl,
          onChanged: _onHourChanged,
          formatter: (v) => v.toString().padLeft(2, '0'),
          selectionOverlay: selectionOverlay,
        );
        final minutePicker = _buildPicker(
          items: minutes,
          controller: _minuteCtrl,
          onChanged: _onMinuteChanged,
          formatter: (v) => v.toString().padLeft(2, '0'),
          selectionOverlay: selectionOverlay,
        );
        // 日期组 + 时间组(上下分组,贴近原 5 列视觉结构)。
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            group([yearPicker, monthPicker, dayPicker]),
            const SizedBox(height: SpitoutDimens.p8),
            group([hourPicker, minutePicker]),
          ],
        );
    }

    return Container(
      key: const ValueKey('wheel_date_picker_sheet'),
      decoration: BoxDecoration(
        color: SpitoutTokens.surfaceSheet(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(SpitoutDimens.radius16)),
      ),
      child: SafeArea(
        top: false,
        child: AppSheet(
          title: widget.title.isEmpty ? null : widget.title,
          subtitle: widget.subtitle,
          contentPadding: const EdgeInsets.only(top: SpitoutDimens.p12),
          footer: AppSheetFilledButton(
            label: widget.confirmLabel,
            onPressed: () => Navigator.of(context).pop(_buildResult()),
          ),
          child: body,
        ),
      ),
    );
  }
}
