import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/utils/currency/currencies.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/data/models.dart' show Category, Transaction;

import 'package:spitout/theme/icons/app_icons.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    // 选中日统一归一化为当日零点,与日历点选返回的日期语义一致,
    // 避免下游直接比较 DateTime 时被时分秒干扰。
    _selectedDay = DateTime(now.year, now.month, now.day);

    // 日历页常驻 IndexedStack：切月会清空选中态，重新进入日历 tab 时若
    // 无选中日期，自动回到本月并选中今天，保证「自动选中当天日期」。
    ref.listenManual<int>(bottomTabIndexProvider, (prev, next) {
      if (prev == 2 || next != 2 || _selectedDay != null) return;
      final current = DateTime.now();
      setState(() {
        _focusedMonth = DateTime(current.year, current.month, 1);
        _selectedDay = DateTime(current.year, current.month, current.day);
      });
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      // 点击上/下月补充日期时,头部月份与查询月份同步切换,
      // 避免"选中日落在相邻月、统计仍按原月"的口径不一致。
      _focusedMonth = DateTime(selectedDay.year, selectedDay.month, 1);
    });
  }

  void _onPageChanged(DateTime focusedMonth) {
    setState(() {
      _focusedMonth = focusedMonth;
      // 切到其他月清空选中；回到本月时自动重新选中今天。
      final now = DateTime.now();
      _selectedDay =
          (focusedMonth.year == now.year && focusedMonth.month == now.month)
              ? DateTime(now.year, now.month, now.day)
              : null;
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> _addTransactionForSelectedDate() async {
    // 优先使用当前选中日期，未选中时回退到今天。
    // 把时间锁到中午,避开 UTC 边界导致跨日的问题(交易列表按日期分组,
    // 凌晨 00:00 在某些时区可能被算作前一天)。
    final base = _selectedDay ?? DateTime.now();
    final initialDate = DateTime(base.year, base.month, base.day, 12, 0, 0);

    await showTransactionEditorSheet(
      context,
      initialKind: 'expense',
      initialDate: initialDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final ledgerAsync = ref.watch(currentLedgerProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    // 仅未选中今天时显示「回到今天」：选中今天时隐藏；切到其他月会清空选中，
    // 此时必须保留按钮，否则没有快捷返回今天的入口。
    final showBackToToday =
        _selectedDay == null || !isSameDay(_selectedDay, DateTime.now());
    // 账本本位币代码：优先取当前账本 currency，未设置时回退 CNY。
    final ledgerCurrencyCode = ledgerAsync.maybeWhen(
      data: (ledger) => ledger?.currency ?? 'CNY',
      orElse: () => 'CNY',
    );
    // 从 ISO 4217 映射取真实符号（如 ¥ / $ / JP¥），杜绝硬编码。
    final currencySymbol = getCurrencySymbol(ledgerCurrencyCode);

    // 获取当月统计数据
    final dailyTotalsAsync = ref.watch(
      dailyTotalsByMonthProvider((ledgerId: ledgerId, month: _focusedMonth)),
    );
    // 日历最早可翻月份:按账本最早支出交易动态生成,无数据回退 2020-01-01。
    final earliestMonthAsync = ref.watch(calendarEarliestDateProvider);

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          // Header
          PrimaryHeader(
            title: l10n.calendarTitle,
            actions: [
              if (showBackToToday)
                // 「今天」文字链：统一全局文字链规格（14/w600/主题主色）
                HeaderTextAction(
                  label: l10n.calendarToday,
                  onPressed: _jumpToToday,
                ),
            ],
          ),

          // 日历主体
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              children: [
                // 日历视图
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: dailyTotalsAsync.when(
                    // 数据变更信号触发重算时不切到 loading,
                    // 旧统计保留,等新数据来无缝替换 — 避免日历整页 spinner 闪烁
                    skipLoadingOnReload: true,
                    data: (dailyTotals) =>
                        _buildCalendar(
                          context,
                          dailyTotals,
                          primaryColor,
                          currencySymbol,
                          earliestMonthAsync.value ?? DateTime(2020, 1, 1),
                        ),
                    loading: () => _buildCalendarSkeleton(context),
                    error: (err, stack) {
                      logger.error('Calendar', '加载当月统计失败', err, stack);
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(l10n.commonOperationFailed),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: 12.0),

                // 选中日期的交易列表（无日期标题和统计）
                if (_selectedDay != null)
                  _buildDateTransactionsList(context, ledgerId, _selectedDay!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建月历主体。
  ///
  /// [dailyTotals] 为当月每日支出(键为 yyyy-MM-dd),[firstDay] 是允许翻页的
  /// 最早月份 1 号(由账本最早交易动态计算,避免历史数据早于硬编码下限)。
  Widget _buildCalendar(
    BuildContext context,
    Map<String, double> dailyTotals,
    Color primaryColor,
    String currencySymbol,
    DateTime firstDay,
  ) {
    final locale = Localizations.localeOf(context);

    // firstDay 会随账本最早交易月动态变化；table_calendar 在 firstDay 于页面
    // 存活期间跳变后，内部 PageController 会失效（箭头/手势切月无响应）。
    // 用 firstDay 做 key 强制重建日历，重置翻页状态，避免「点不动」。
    return TableCalendar(
      key: ValueKey(
        'calendar_first_${firstDay.year}_${firstDay.month}',
      ),
      locale: locale.toString(),
      firstDay: firstDay,
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedMonth,
      selectedDayPredicate: (day) {
        return _selectedDay != null && isSameDay(_selectedDay, day);
      },
      onDaySelected: _onDaySelected,
      onPageChanged: _onPageChanged,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableGestures: AvailableGestures.horizontalSwipe,

      // 设置行高以适应内容
      rowHeight: 68,
      daysOfWeekHeight: 30,

      // Header 样式
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronIcon: Icon(AppIcons.chevronLeft, color: SpitoutTokens.iconTertiary(context)),
        rightChevronIcon: Icon(AppIcons.chevronRight, color: SpitoutTokens.iconTertiary(context)),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: SpitoutTokens.textPrimary(context),
        ),
      ),

      // 日历样式
      calendarStyle: CalendarStyle(
        // 今天样式
        todayDecoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),

        // 选中样式
        selectedDecoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),

        // 日期文字样式
        defaultTextStyle: TextStyle(
          color: SpitoutTokens.textPrimary(context),
        ),
        outsideTextStyle: TextStyle(
          color: SpitoutTokens.textTertiary(context).withValues(alpha: 0.3),
        ),

        // 周末样式
        weekendTextStyle: TextStyle(
          color: SpitoutTokens.textPrimary(context),
        ),

        // 标记样式
        markersAlignment: Alignment.bottomCenter,
        markerDecoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
      ),

      // 星期标题样式
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: SpitoutTokens.textSecondary(context),
          fontSize: 12,
        ),
        weekendStyle: TextStyle(
          color: SpitoutTokens.textSecondary(context),
          fontSize: 12,
        ),
      ),

      // 日期标记构建器
      calendarBuilders: CalendarBuilders(
        // 自定义默认日期单元格
        defaultBuilder: (context, day, focusedDay) {
          return _buildDateCell(
              context, day, dailyTotals, primaryColor, false, false, false, currencySymbol);
        },
        // 自定义今天日期单元格
        todayBuilder: (context, day, focusedDay) {
          return _buildDateCell(
              context, day, dailyTotals, primaryColor, true, false, false, currencySymbol);
        },
        // 自定义选中日期单元格
        selectedBuilder: (context, day, focusedDay) {
          return _buildDateCell(
              context, day, dailyTotals, primaryColor, false, true, false, currencySymbol);
        },
        // 自定义非当前月日期
        outsideBuilder: (context, day, focusedDay) {
          return _buildDateCell(
              context, day, dailyTotals, primaryColor, false, false, true, currencySymbol);
        },
      ),
    );
  }

  /// 构建单个日期单元格:日期数字(选中/今天带圆形背景)+ 当日支出缩写。
  ///
  /// [isOutside] 表示上/下月的补充日期,只渲染弱化数字、不渲染支出标记。
  Widget _buildDateCell(
    BuildContext context,
    DateTime day,
    Map<String, double> dailyTotals,
    Color primaryColor,
    bool isToday,
    bool isSelected,
    bool isOutside,
    String currencySymbol,
  ) {
    final dateKey = _formatDate(day);
    final expense = dailyTotals[dateKey] ?? 0.0;
    // 标记口径:仅"有支出且金额 > 0"的日子显示圆点/金额缩写,
    // 0 元与收入日不标记。当前全局仅支出模式(type 恒为 expense)下成立,
    // 若未来引入收入,此处需按收入/支出分别判定。
    final hasTransaction = expense > 0;

    // 文字颜色
    Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = primaryColor;
    } else if (isOutside) {
      textColor = SpitoutTokens.textTertiary(context).withValues(alpha: 0.3);
    } else {
      textColor = SpitoutTokens.textPrimary(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 日期数字（带圆形背景）
          Container(
            width: 32,
            height: 32,
            decoration: isSelected
                ? BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  )
                : isToday
                    ? BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      )
                    : null,
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight:
                    isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                height: 1.0,
              ),
            ),
          ),
          // 支出（在圆形外面）
          if (!isOutside && hasTransaction) ...[
            const SizedBox(height: 2),
            // 支出：保留 1.2k/1.2w 缩写以适配日历格子窄空间，
            // 同时加账本本位币货币符号前缀（如 -¥1.2w）。
            if (expense > 0)
              Text(
                expense >= 10000
                    ? '-$currencySymbol${(expense / 10000).toStringAsFixed(1)}w'
                    : expense >= 1000
                        ? '-$currencySymbol${(expense / 1000).toStringAsFixed(1)}k'
                        : '-$currencySymbol${expense.toInt()}',
                style: TextStyle(
                  color: ref.watch(expenseColorSchemeProvider) == 'green' ? SpitoutTokens.success(context) : SpitoutTokens.error(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
          ],
        ],
      ),
    );
  }

  /// 构建选中日期的交易列表(上方含"日期 + 在该日记账"紧凑头)。
  ///
  /// 单日交易可能很多(如批量导入):内联只渲染前 50 条,超出时提供
  /// "查看全部"入口走懒加载弹层,避免整列 Widget 全量构建卡顿。
  Widget _buildDateTransactionsList(BuildContext context, int ledgerId, DateTime date) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final localeName = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.MMMMd(localeName).format(date);
    final weekdayLabel = DateFormat.E(localeName).format(date);

    final transactionsAsync = ref.watch(
      transactionsByDateProvider((ledgerId: ledgerId, date: date)),
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: SpitoutTokens.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  weekdayLabel,
                  style: TextStyle(
                    color: SpitoutTokens.textTertiary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 「在该日记账」按钮：使用 Material 直接承载颜色与圆角，
          // 不套 Ink + boxShadow，避免出现直角浅蓝色背景蒙层。
          Material(
            color: primaryColor,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _addTransactionForSelectedDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.add,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      l10n.calendarAddTransaction,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final card = SectionCard(
      margin: EdgeInsets.zero,
      child: transactionsAsync.when(
        // 同上:bump 刷新触发的 reload 不切到 loading 分支,旧列表保持显示
        skipLoadingOnReload: true,
        data: (transactions) {
          if (transactions.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  l10n.calendarNoTransactions,
                  style: TextStyle(
                    color: SpitoutTokens.textTertiary(context),
                  ),
                ),
              ),
            );
          }

          // 直接显示交易列表;超限时截断并追加"查看全部"入口。
          const maxInline = 50;
          final hasMore = transactions.length > maxInline;
          final visible = hasMore
              ? transactions.sublist(0, maxInline)
              : transactions;
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: visible.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (hasMore && index == visible.length) {
                return _buildViewAllFooter(
                  context,
                  l10n,
                  transactions,
                  dateLabel,
                );
              }
              final item = visible[index];
              final category = item.category;
              final isExpense = item.t.type == 'expense';

              // 分类名称
              final categoryName = category?.name ?? l10n.commonUncategorized;

              // 备注作为副标题
              final subtitle = item.t.note ?? '';

              // 无标签列表

              return TransactionListItem(
                icon: getCategoryIconData(category: category),
                category: category,
                title: subtitle.isNotEmpty ? subtitle : categoryName,
                categoryName: subtitle.isNotEmpty ? categoryName : null,
                amount: item.t.amount,
                currencyCode: item.t.currencyCode,
                nativeAmount: item.t.nativeAmount,
                isExpense: isExpense,
                happenedAt: item.t.happenedAt,
                onTap: () async {
                  await TransactionEditUtils.editTransaction(
                    context,
                    ref,
                    item.t,
                    item.category,
                  );
                },
              );
            },
          );
        },
        loading: () => _buildTransactionsSkeleton(context),
        error: (err, stack) {
          logger.error('Calendar', '加载当日交易失败', err, stack);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(l10n.commonOperationFailed)),
          );
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, card],
    );
  }

  /// 内联列表超限时的"查看全部"入口:点击弹出懒加载的完整交易列表。
  Widget _buildViewAllFooter(
    BuildContext context,
    AppLocalizations l10n,
    List<({Transaction t, Category? category})> transactions,
    String dateLabel,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => _showAllTransactionsSheet(
        context,
        l10n,
        transactions,
        dateLabel,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            l10n.calendarViewAllTransactions(transactions.length),
            style: TextStyle(
              color: primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// 弹出完整当日交易列表:AppSheet 内容区为懒加载 ListView,支持大量交易。
  Future<void> _showAllTransactionsSheet(
    BuildContext context,
    AppLocalizations l10n,
    List<({Transaction t, Category? category})> transactions,
    String dateLabel,
  ) async {
    await showAppSheet<void>(
      context: context,
      child: AppSheet(
        title: dateLabel,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final item = transactions[index];
            final category = item.category;
            final isExpense = item.t.type == 'expense';
            final categoryName = category?.name ?? l10n.commonUncategorized;
            final subtitle = item.t.note ?? '';
            return TransactionListItem(
              icon: getCategoryIconData(category: category),
              category: category,
              title: subtitle.isNotEmpty ? subtitle : categoryName,
              categoryName: subtitle.isNotEmpty ? categoryName : null,
              amount: item.t.amount,
              currencyCode: item.t.currencyCode,
              nativeAmount: item.t.nativeAmount,
              isExpense: isExpense,
              happenedAt: item.t.happenedAt,
              onTap: () async {
                await TransactionEditUtils.editTransaction(
                  context,
                  ref,
                  item.t,
                  item.category,
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// 把日期格式化为 yyyy-MM-dd,与每日统计/查询的键口径一致。
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 日历整页骨架(模拟 6 周 × 7 天 的灰格,接近真实日历高度)
  // 占位等高:rowHeight 68 × 6 + daysOfWeekHeight 30 + header 50 ≈ 488
  Widget _buildCalendarSkeleton(BuildContext context) {
    return DelayedSkeleton(
      placeholder: const SizedBox(height: 488),
      child: PulseSkeleton(
        child: SizedBox(
          height: 488,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const SkeletonBar(height: 18, widthFactor: 0.4),
                const SizedBox(height: 14),
                for (int row = 0; row < 6; row++)
                  Row(
                    children: List.generate(
                      7,
                      (_) => const Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: SkeletonBar(height: 56),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 当日交易列表骨架(3 条 ListTile 风格占位)
  Widget _buildTransactionsSkeleton(BuildContext context) {
    return const DelayedSkeleton(
      placeholder: SizedBox(height: 200),
      child: PulseSkeleton(
        child: Column(
          children: [
            SkeletonListTile(),
            SkeletonListTile(),
            SkeletonListTile(),
          ],
        ),
      ),
    );
  }
}
