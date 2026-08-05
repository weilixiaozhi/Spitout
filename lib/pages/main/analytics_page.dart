import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'package:spitout/providers/providers.dart';
import '../../widgets/widgets.dart';
import '../transaction/category_detail_page.dart';

import '../../l10n/app_localizations.dart';
import '../../data/models.dart' as db;
import '../../utils/category_utils.dart';
import '../../utils/date/month_range.dart';
import '../../utils/date/week_math.dart';
import '../../utils/date/analytics_sub_tabs.dart';
import '../../utils/format_utils.dart';
import '../../theme/icons/app_icons.dart';

/// 统计页（账单统计）
/// - 顶部记账周期选择器：以 `07月 · 2026年` 形式展示账期（与首页头部共用同一标签构造）。
///   全局空数据（无任何支出交易）时禁用点击并隐藏下拉箭头；
///   局部空数据（有历史但当前周期无账）时保留筛选入口。
/// - 顶部周期子 Tab：按真实数据范围 earliest..latest 生成，默认定位最新数据。
/// - 悬浮父级周期 Tab：固定在底部中央的 周/月/年 分段控件。
/// - 支出趋势模块：总支出 / 环比 / 日均支出 网格 + 折线图（禁用横滑）。
/// - 分类排行模块：居中环图（空数据时显示灰色饼图）+ 四周引导标注 + 可展开分类列表（空列表显示骨架屏）。
/// - 横滑切周期仅作用于环图+列表容器；趋势图区域不响应横滑。
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

/// 一级分类聚合后的记录类型（与 totalsByCategoryWithHierarchy 输出对齐）
typedef _TopCat = ({
  int? id,
  String name,
  db.Category? category,
  double total,
  List<({int id, db.Category? category, String name, double total})> subCategories,
});

/// 一次统计计算的结果聚合，供 UI 直接消费
class _AnalyticsData {
  final List<_TopCat> catData; // 一级分类聚合（已按金额降序）
  final dynamic seriesRaw; // 折线图原始序列：日序列或月序列
  final int txCount; // 区间内交易笔数
  final double sum; // 当前账期支出总额
  final double prevTotal; // 上一周期支出总额（用于环比）

  const _AnalyticsData({
    required this.catData,
    required this.seriesRaw,
    required this.txCount,
    required this.sum,
    required this.prevTotal,
  });
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  // 父级周期：week / month / year（悬浮 Tab 控制）
  AnalyticsPeriod _period = AnalyticsPeriod.month;
  // 全局仅支出模式，统计页只呈现支出
  final String _type = 'expense';

  // 各父级周期独立记忆的选中子周期，避免切换父级后丢失选择
  late DateTime _selMonth; // 月视图：选中的账期（label month）
  late int _selYear; // 年视图：选中的年份
  late DateTime _selWeekStart; // 周视图：选中的周一（周起点）

  // 缓存的 Future：避免 build 内每次创建新 Future（B12 反模式）。
  // 仅在依赖参数变化时重建。
  Future<_AnalyticsData>? _dataFuture;
  // 上一次刷新计数与账本 id 快照：用于检测「数据或账本已变更」，
  // 保存/删除/导入/清空/切换账本后必须让缓存 Future 失效，否则 FutureBuilder 始终消费旧数据。
  int _lastStatsRefresh = 0;
  int? _lastLedgerId;
  // 重试 tick：错误态点击重试时 +1，触发 Future 重建。
  int _retryTick = 0;

  // 子 Tab 滚动控制器：选中项滚动到视图中。
  final ScrollController _subTabController = ScrollController();
  // 子 Tab 已定位标记，避免重复 ensureVisible。
  String? _lastEnsuredTabId;
  // 上一次用于定位的 Tab id 列表快照：analyticsDataRangeProvider 异步
  // resolve 后，子 Tab 列表会「由单个当前周期扩展为 earliest..latest 全量」；
  // 另外在首页新增数据后该 provider 被 invalidate，列表也会变长/变短。
  // 列表长度或内容变化时必须重新定位，否则会出现「内容已是最新周、
  // 但 tab 横向滚动仍停留在开头 1-8 周」的错位（BUG）。
  List<String>? _lastEnsuredTabIds;

  /// 顺序比较两个 tab id 列表是否完全一致。
  bool _tabIdsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    // 初始默认账期取自全局选中的账期（与首页保持一致）
    _selMonth = ref.read(selectedMonthProvider);
    final now = DateTime.now();
    _selYear = now.year;
    _selWeekStart = mondayOf(now);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  /// 当前选中账期的时间范围；当前周期截断到今天，历史周期取完整区间。
  ({DateTime start, DateTime end, bool isCurrent}) _currentRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sd = ref.read(currentMonthStartDayProvider);
    switch (_period) {
      case AnalyticsPeriod.week:
        // 周视图始终展示完整 7 天，使图表轴稳定（含未来天=0）
        final start = _selWeekStart;
        final isCurrent = start == mondayOf(now);
        return (start: start, end: start.add(const Duration(days: 7)), isCurrent: isCurrent);
      case AnalyticsPeriod.year:
        final range = yearRangeFor(_selYear, sd);
        final isCurrent =
            !now.isBefore(range.start) && now.isBefore(range.end);
        final end = isCurrent ? today.add(const Duration(days: 1)) : range.end;
        return (start: range.start, end: end, isCurrent: isCurrent);
      case AnalyticsPeriod.month:
        final range = periodForLabel(_selMonth.year, _selMonth.month, sd);
        final nowLabel = labelForDate(now, sd);
        final isCurrent =
            _selMonth.year == nowLabel.year && _selMonth.month == nowLabel.month;
        final end = isCurrent ? today.add(const Duration(days: 1)) : range.end;
        return (start: range.start, end: end, isCurrent: isCurrent);
    }
  }

  /// 一键回到当前周期（本周/本月/今年）。
  /// 当用户在非当前周期浏览时，点击头部「回到本周/月/年」文字链调用此方法。
  void _jumpToCurrentPeriod() {
    final now = DateTime.now();
    final sd = ref.read(currentMonthStartDayProvider);
    setState(() {
      switch (_period) {
        case AnalyticsPeriod.week:
          _selWeekStart = mondayOf(now);
        case AnalyticsPeriod.month:
          final nowLabel = labelForDate(now, sd);
          _selMonth = DateTime(nowLabel.year, nowLabel.month, 1);
        case AnalyticsPeriod.year:
          _selYear = now.year;
      }
    });
  }

  /// 上一周期范围，用于环比（MoM）对比
  ({DateTime start, DateTime end}) _prevRange() {
    final sd = ref.read(currentMonthStartDayProvider);
    switch (_period) {
      case AnalyticsPeriod.week:
        final start = _selWeekStart.subtract(const Duration(days: 7));
        return (start: start, end: _selWeekStart);
      case AnalyticsPeriod.year:
        final range = yearRangeFor(_selYear - 1, sd);
        return (start: range.start, end: range.end);
      case AnalyticsPeriod.month:
        final prev = DateTime(_selMonth.year, _selMonth.month - 1, 1);
        final range = periodForLabel(prev.year, prev.month, sd);
        return (start: range.start, end: range.end);
    }
  }

  /// 根据当前父级周期拉取折线图序列：年视图按月聚合，其余按日聚合
  Future<dynamic> _fetchSeries(DateTime start, DateTime end, {bool isPrev = false}) {
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (_period == AnalyticsPeriod.year) {
      final year = isPrev ? _selYear - 1 : _selYear;
      return repo.totalsByMonth(ledgerId: ledgerId, type: _type, year: year);
    }
    return repo.totalsByDay(ledgerId: ledgerId, type: _type, start: start, end: end);
  }

  /// 汇总任意序列（日或月）的总额
  double _sumSeries(dynamic s) {
    if (s is List<({DateTime day, double total})>) {
      return s.fold(0.0, (a, e) => a + e.total);
    }
    if (s is List<({DateTime month, double total})>) {
      return s.fold(0.0, (a, e) => a + e.total);
    }
    return 0.0;
  }

  /// 一次性拉取分类聚合、折线序列、交易笔数以及上一周期总额。
  /// 在 _ensureFuture 中被缓存，避免每次 build 重建（B12）。
  Future<_AnalyticsData> _loadData() async {
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    final cur = _currentRange();
    final prev = _prevRange();

    final curSeries = _fetchSeries(cur.start, cur.end);
    final prevSeries = _fetchSeries(prev.start, prev.end, isPrev: true);

    final results = await Future.wait<dynamic>([
      repo.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId,
        type: _type,
        start: cur.start,
        end: cur.end,
      ),
      curSeries,
      repo.countByTypeInRange(
        ledgerId: ledgerId,
        type: _type,
        start: cur.start,
        end: cur.end,
      ),
      repo.getSharedSyntheticCategoriesForLedger(ledgerId),
      prevSeries,
    ]);

    final hierarchyData = results[0]
        as List<({int? id, String name, String? icon, int? parentId, int level, double total})>;
    final sharedSynthetic = results[3] as Map<int, db.Category>;
    final catData = await _aggregateTopLevelCategories(hierarchyData, sharedSynthetic);
    final sum = catData.fold<double>(0, (a, b) => a + b.total);
    final seriesRaw = results[1];
    final prevTotal = _sumSeries(results[4]);
    return _AnalyticsData(
      catData: catData,
      seriesRaw: seriesRaw,
      txCount: results[2] as int,
      sum: sum,
      prevTotal: prevTotal,
    );
  }

  /// 将带层级的分类聚合结果折叠为一级分类（保留预计算二级明细，避免展开时重复查询）。
  /// 使用 getCategoriesByIds 批量取回 Category，避免 N+1 查询（P1）。
  Future<List<_TopCat>> _aggregateTopLevelCategories(
    List<({int? id, String name, String? icon, int? parentId, int level, double total})> hierarchyData,
    Map<int, db.Category> sharedSynthetic,
  ) async {
    final repo = ref.read(repositoryProvider);

    // 收集所有需要查询的真实分类 id（排除已在 sharedSynthetic 中的合成 id）
    final realIds = <int>{};
    for (final row in hierarchyData) {
      if (row.id != null && !sharedSynthetic.containsKey(row.id)) {
        realIds.add(row.id!);
      }
      final topId = row.parentId ?? row.id;
      if (topId != null && !sharedSynthetic.containsKey(topId)) {
        realIds.add(topId);
      }
    }
    // 一次性批量查询，避免循环内 await getCategoryById
    final catMap = await repo.getCategoriesByIds(realIds);
    // 合并：sharedSynthetic 优先（共享账本合成分类），否则用真实分类
    db.Category? catOf(int? id) => id == null ? null : (sharedSynthetic[id] ?? catMap[id]);

    final Map<int?, ({String name, double total, List<({int id, db.Category? category, String name, double total})> subs})>
        topMap = {};
    for (final row in hierarchyData) {
      final topId = row.parentId ?? row.id;
      final isTop = row.parentId == null;
      final cat = catOf(row.id);
      final subName = cat?.name ?? row.name;
      topMap.putIfAbsent(
        topId,
        () => (
          name: catOf(topId)?.name ?? row.name,
          total: 0.0,
          subs: <({int id, db.Category? category, String name, double total})>[],
        ),
      );
      final entry = topMap[topId]!;
      topMap[topId] = (
        name: entry.name,
        total: entry.total + row.total,
        subs: isTop
            ? entry.subs
            : <({int id, db.Category? category, String name, double total})>[
                ...entry.subs,
                (id: row.id!, category: cat, name: subName, total: row.total),
              ],
      );
    }
    final result = <_TopCat>[];
    for (final e in topMap.entries) {
      final c = e.value;
      result.add((
        id: e.key,
        name: c.name,
        category: catOf(e.key),
        total: c.total,
        subCategories: c.subs,
      ));
    }
    result.sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  /// 表头账期文案：月视图 `07月 · 2026年`，年视图 `2026年`，周视图 `第28周 · 2026年`
  ///
  /// 统一经 [monthYearLabel]/[AppLocalizations.homeYear] 构造，与首页头部完全一致
  /// （年份始终带"年"，如中文 `2026年`），单一构造出口。
  String _headerLabel() {
    final l10n = AppLocalizations.of(context);
    switch (_period) {
      case AnalyticsPeriod.week:
        // 周视图年份同样走 homeYear，保证与首页一致带"年"
        return '${l10n.analyticsWeekN(weekNumber(_selWeekStart))} · ${l10n.homeYear(_selWeekStart.year)}';
      case AnalyticsPeriod.year:
        // 年视图只展示年份，也经 homeYear 带"年"
        return l10n.homeYear(_selYear);
      case AnalyticsPeriod.month:
        // 复用首页同款「月份 · 年份」构造，避免两套补零/语言分支
        return monthYearLabel(context, _selMonth.month, _selMonth.year);
    }
  }

  /// 顶部记账周期选择器的点击：周/月/年视图均调起对应的滚轮选择器。
  /// 全局空数据时此方法不会被调用（Header 已禁用点击）。
  ///
  /// - 周视图调起「年+周」双滚轮选择器，选中后定位到该周周一，
  ///   与月/年视图交互一致。
  /// - 三个模式统一在选中后重置 _dataFuture 缓存，避免 FutureBuilder
  ///   继续消费旧 Future 导致图表仍显示旧账期数据。
  void _showPeriodPicker() async {
    DateTime? res;
    if (_period == AnalyticsPeriod.week) {
      res = await showWheelDatePicker(
        context,
        initial: _selWeekStart,
        mode: WheelDatePickerMode.week,
      );
    } else if (_period == AnalyticsPeriod.month) {
      res = await showWheelDatePicker(
        context,
        initial: _selMonth,
        mode: WheelDatePickerMode.ym,
      );
    } else if (_period == AnalyticsPeriod.year) {
      res = await showWheelDatePicker(
        context,
        initial: DateTime(_selYear, 1, 1),
        mode: WheelDatePickerMode.y,
      );
    }
    if (res == null) return;
    setState(() {
      switch (_period) {
        case AnalyticsPeriod.week:
          // 选择器已按周对齐返回周一，mondayOf 再兜底一次防御
          _selWeekStart = mondayOf(res!);
          break;
        case AnalyticsPeriod.month:
          _selMonth = DateTime(res!.year, res.month, 1);
          break;
        case AnalyticsPeriod.year:
          _selYear = res!.year;
          break;
      }
      // 重置数据缓存与子 Tab 定位标记，触发新账期数据加载
      _dataFuture = null;
      _lastEnsuredTabId = null;
    });
  }

  /// 构建子 Tab 列表：按真实数据范围 earliest..latest 生成。
  List<AnalyticsSubTab> _buildSubTabs() {
    final range = ref.read(analyticsDataRangeProvider).value;
    final l10n = AppLocalizations.of(context);
    return generateSubTabs(
      period: _period,
      earliest: range?.earliest,
      latest: range?.latest,
      now: DateTime.now(),
      monthStartDay: ref.read(currentMonthStartDayProvider),
      // 复用共享月份标签（与首页日期组件完全一致，补零为两位数如 01月）
      monthLabel: (m) => monthLabel(context, m),
      weekNLabel: (n) => l10n.analyticsWeekN(n),
      thisWeekLabel: l10n.analyticsThisWeek,
      // 年子 Tab 复用 homeYear，与顶部账期表头（2026年）口径一致，避免裸数字
      yearLabel: (y) => l10n.homeYear(y),
    );
  }

  /// 当前选中子 Tab 的 id（用于高亮 + 滚动定位）
  String _currentSubTabId() {
    switch (_period) {
      case AnalyticsPeriod.month:
        return '${_selMonth.year}-${_selMonth.month.toString().padLeft(2, '0')}';
      case AnalyticsPeriod.year:
        return '$_selYear';
      case AnalyticsPeriod.week:
        return '${_selWeekStart.year}-W${weekNumber(_selWeekStart)}';
    }
  }

  /// 顶部周期子 Tab：在当前父级周期内切换具体账期（横向滚动）。
  /// 选中项自动滚动到视图中央。
  ///
  /// 交互层用 Material + InkWell 提供标准水波纹 + 触觉反馈，避免滚动动画期间
  /// hit test 被 ScrollView 拦截导致点击看似无响应；context 注册放在 build 期，
  /// 与 tab 重建保持同步。
  Widget _buildPeriodSubTabs() {
    final tabs = _buildSubTabs();
    final activeId = _currentSubTabId();

    // 清理过期的 BuildContext（切换父级周期后旧 tab.id 不会再用），
    // 防止 _subTabKeyContexts 无限增长。
    final currentIds = tabs.map((t) => t.id).toSet();
    _subTabKeyContexts.removeWhere((id, _) => !currentIds.contains(id));

    // 选中项滚动到视图中（postFrame，避免 build 期布局未完成）。
    // 触发条件有两条，任一满足都要重新定位：
    //  1) 选中项变化（用户点击/切换父级周期）；
    //  2) Tab 列表本身发生变化（analyticsDataRangeProvider 异步 resolve
    //     后列表由短变长，或首页新增数据后列表扩展）。
    // 仅判断选中项变化会在列表扩张后漏掉定位，导致「内容是最新周、
    // tab 却停留在开头」的错位（BUG）。
    final newIds = tabs.map((t) => t.id).toList();
    final listChanged =
        _lastEnsuredTabIds == null || !_tabIdsEqual(newIds, _lastEnsuredTabIds!);
    if (tabs.isNotEmpty && (activeId != _lastEnsuredTabId || listChanged)) {
      _lastEnsuredTabId = activeId;
      _lastEnsuredTabIds = newIds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_subTabController.hasClients) return;
        final ctx = _subTabKeyContexts[activeId];
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 200));
        }
      });
    }

    return SingleChildScrollView(
      controller: _subTabController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        spacing: 8,
        children: [
          for (final tab in tabs)
            _SubTabChipBuilder(
              key: ValueKey(tab.id),
              tab: tab,
              selected: tab.id == activeId,
              onTap: () => _onSubTabTap(tab),
              registerContext: (ctx) => _subTabKeyContexts[tab.id] = ctx,
            ),
        ],
      ),
    );
  }

  // 子 Tab id → BuildContext 映射，供 ensureVisible 定位
  final Map<String, BuildContext> _subTabKeyContexts = {};

  /// 子 Tab 点击：更新对应周期的选中值，并重置 Future 缓存，
  /// 附带 HapticFeedback.lightImpact 触觉反馈，让周 tab 点击有明确感知。
  void _onSubTabTap(AnalyticsSubTab tab) {
    // 触觉反馈：让用户明确感知到点击已生效
    HapticFeedback.lightImpact();
    setState(() {
      switch (_period) {
        case AnalyticsPeriod.month:
          _selMonth = DateTime(tab.start.year, tab.start.month, 1);
          break;
        case AnalyticsPeriod.year:
          _selYear = tab.start.year;
          break;
        case AnalyticsPeriod.week:
          _selWeekStart = tab.start;
          break;
      }
      _dataFuture = null;
      _lastEnsuredTabId = null;
    });
  }

  /// 底部悬浮父级周期 Tab（周/月/年）
  Widget _buildFloatingPeriodTab() {
    final l10n = AppLocalizations.of(context);
    // 胶囊底色为纯白 surface(#FFFFFF)，与页面底色(#F9F7F7)在明度上拉开
    // 差距，让悬浮的父级 Tab 更清晰可辨；
    // 外层再叠一层很轻的阴影使其微微浮起，但阴影足够克制不会喧宾夺主。
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 214),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: CapsuleSwitcher<AnalyticsPeriod>(
          selectedValue: _period,
          backgroundColor: SpitoutTokens.surface(context),
          // 选中态底色用 surfaceSelected（primary 8%/15% 浅色提示），
          // 浅色底避免遮挡内容，同时保留选中项的底色区分。
          selectedBackgroundColor: SpitoutTokens.surfaceSelected(context),
          selectedTextColor: SpitoutTokens.primary(context),
          options: [
            CapsuleOption(value: AnalyticsPeriod.week, label: l10n.analyticsWeek),
            CapsuleOption(value: AnalyticsPeriod.month, label: l10n.analyticsMonth),
            CapsuleOption(value: AnalyticsPeriod.year, label: l10n.analyticsYear),
          ],
          onChanged: (v) => setState(() {
            _period = v;
            _dataFuture = null;
            _lastEnsuredTabId = null;
          }),
        ),
      ),
    );
  }

  /// 内容区横滑：切换到下一周期（不跨越当前周期，且不超出子 Tab 范围）
  void _onContentSwipeLeft() {
    final tabs = _buildSubTabs();
    final activeId = _currentSubTabId();
    final idx = tabs.indexWhere((t) => t.id == activeId);
    if (idx < 0 || idx >= tabs.length - 1) return; // 已是最新，不切换
    _onSubTabTap(tabs[idx + 1]);
  }

  /// 内容区横滑：切换到上一周期
  void _onContentSwipeRight() {
    final tabs = _buildSubTabs();
    final activeId = _currentSubTabId();
    final idx = tabs.indexWhere((t) => t.id == activeId);
    if (idx <= 0) return; // 已是最早，不切换
    _onSubTabTap(tabs[idx - 1]);
  }

  /// 支出趋势网格：总支出 / 环比 / 日均支出
  Widget _buildTrendGrid(double sum, double dailyAvg, _MomInfo mom, Color primary) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statCell(
          l10n.analyticsTotalExpenseLabel,
          AmountText(value: sum, signed: false, decimals: 0, showCurrency: true),
        ),
        _statCell(
          mom.label,
          mom.none
              ? Text('—', style: SpitoutTextTokens.title(context).copyWith(fontSize: 16))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mom.up ? AppIcons.arrowUp : AppIcons.arrowDown,
                      size: 14,
                      color: mom.up ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      mom.value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: mom.up ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
        ),
        _statCell(
          l10n.analyticsDailyExpense,
          AmountText(value: dailyAvg, signed: false, decimals: 0, showCurrency: true),
        ),
      ],
    );
  }

  Widget _statCell(String label, Widget value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: SpitoutTokens.textTertiary(context)),
          ),
          const SizedBox(height: 6),
          value,
        ],
      ),
    );
  }

  /// 环比信息：计算上一周期对比百分比，并返回对应文案标签
  _MomInfo _momInfo(double cur, double prev, AppLocalizations l10n) {
    final label = switch (_period) {
      AnalyticsPeriod.week => l10n.analyticsMoMLastWeek,
      AnalyticsPeriod.year => l10n.analyticsMoMLastYear,
      AnalyticsPeriod.month => l10n.analyticsMoMLastMonth,
    };
    if (prev == 0) {
      return _MomInfo(label: label, value: '—', up: false, none: true);
    }
    final pct = (cur - prev) / prev * 100;
    return _MomInfo(
      label: label,
      value: '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
      up: pct >= 0,
      none: false,
    );
  }

  /// 星期简称（用于周视图折线图 X 轴）
  String _weekdayShort(int weekday) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'en') {
      const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return en[weekday - 1];
    }
    const zh = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${zh[weekday - 1]}';
  }

  /// 确保 Future 缓存：仅在依赖参数变化时重建。
  void _ensureFuture() {
    if (_dataFuture != null) return;
    _dataFuture = _loadData();
  }

  @override
  Widget build(BuildContext context) {
    // 监听刷新信号，交易增删改/导入/清空后重新统计
    final statsTick = ref.watch(statsRefreshProvider);
    // 同时监听当前账本：切换账本后统计页必须整体重算，否则仍显示旧账本数据
    final ledgerId = ref.watch(currentLedgerIdProvider);
    // statsRefresh 自增或切换账本都说明数据已变更，必须让缓存 Future 失效；
    // 否则 FutureBuilder 始终消费旧 _dataFuture，导致新增/删除/导入/清空/切换账本后统计页不渲染。
    if (statsTick != _lastStatsRefresh || ledgerId != _lastLedgerId) {
      _lastStatsRefresh = statsTick;
      _lastLedgerId = ledgerId;
      _dataFuture = null;
      _lastEnsuredTabId = null;
    }
    final primary = Theme.of(context).colorScheme.primary;

    // 全局空数据判定：无任何支出交易时 Header 禁用点击
    final hasAnyDataAsync = ref.watch(analyticsHasAnyExpenseProvider);
    final hasAnyData = hasAnyDataAsync.value ?? false;
    // watch 数据范围 provider：resolve 后触发重建，让子 Tab 按真实范围生成
    ref.watch(analyticsDataRangeProvider);

    // 判断当前选中的周期是否为「本周/本月/今年」；
    // 非当前周期时在头部显示「回到本周/月/年」文字链。
    final bool isCurrentPeriod = _currentRange().isCurrent;

    // 全局空数据（无任何支出交易）：直接渲染完整空页面，不进入加载态。
    // 默认周期始终保持「月」，不强制切周——用户可自由切换父级周期。
    final bool globalEmpty = hasAnyDataAsync.hasValue && !hasAnyData;

    // 仅非全局空数据时才构建并缓存数据 Future；空数据态无需拉取数据，避免切换父Tab闪屏。
    if (!globalEmpty) {
      _ensureFuture();
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // 首行：全局统一头部组件（账期标题可点击拉起周期选择）。
              // 全局空数据时禁用点击 + 隐藏下拉箭头：
              // onTitleTap 为 null 即纯文本无热区，与 IgnorePointer 禁用态外观一致。
              PrimaryHeader(
                title: _headerLabel(),
                onTitleTap: hasAnyData ? _showPeriodPicker : null,
                titleTrailing: hasAnyData ? AppIcons.chevronDown : null,
                actions: [
                  // 非当前周期时显示「回到本周/月/年」文字链，点击一键回到当前周期
                  if (!isCurrentPeriod)
                    HeaderTextAction(
                      label: _period == AnalyticsPeriod.week
                          ? AppLocalizations.of(context).analyticsBackToThisWeek
                          : _period == AnalyticsPeriod.month
                              ? AppLocalizations.of(context).analyticsBackToThisMonth
                              : AppLocalizations.of(context).analyticsBackToThisYear,
                      onPressed: _jumpToCurrentPeriod,
                    ),
                ],
                // 顶部周期子 Tab（悬浮在内容上方）
                bottom: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: _buildPeriodSubTabs(),
                ),
              ),
              // 横滑切账期提示：放在子 Tab 下方（共用 SwipeHint，样式与首页一致）
              SwipeHint(
                icon: AppIcons.swipe,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                text: AppLocalizations.of(context).analyticsSwipePeriodHint(
                  _period == AnalyticsPeriod.week
                      ? AppLocalizations.of(context).analyticsWeek
                      : _period == AnalyticsPeriod.month
                          ? AppLocalizations.of(context).analyticsMonth
                          : AppLocalizations.of(context).analyticsYear,
                ),
              ),
              _buildRecalcForeignBanner(context),
              _buildConvertedFootnote(context),
              Expanded(
                // 全局空数据：直接渲染完整空页面（日期/子Tab/图表空态/父Tab悬浮），
                // 不进入加载态，切换父级周期也不会闪屏。
                child: globalEmpty
                    ? _buildEmpty(primary)
                    : FutureBuilder<_AnalyticsData>(
                        key: ValueKey(
                            '$_period-$_selMonth-$_selYear-$_selWeekStart-$_type-$_retryTick'),
                        future: _dataFuture,
                        builder: (context, snapshot) {
                    // 错误态：显示重试 UI
                    if (snapshot.hasError) {
                      return _buildError(snapshot.error, primary);
                    }
                    // 加载态：骨架屏近似最终布局
                    if (!snapshot.hasData) {
                      return _buildSkeleton();
                    }
                    final data = snapshot.data!;
                    // 空态判定：以交易笔数为准
                    if (data.txCount == 0) {
                      return _buildEmpty(primary);
                    }
                    return _buildContent(data, primary);
                  },
                ),
              ),
            ],
          ),
          // 悬浮父级周期 Tab（底部中央）。
          // 底部上移 20px（bottom 12 → 32），让用户更容易触达，
          // 同时与底部留出视觉空间，避免贴在屏幕边缘。底部留白同步增加。
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewPadding.bottom + 32,
            child: Center(child: _buildFloatingPeriodTab()),
          ),
        ],
      ),
    );
  }

  /// 加载态骨架屏：近似最终布局，避免 CircularProgressIndicator 的突兀感。
  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SkeletonBar(height: 18, width: 100),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: SkeletonBar(height: 40)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBar(height: 40)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBar(height: 40)),
          ],
        ),
        const SizedBox(height: 12),
        SkeletonBar(height: 240, widthFactor: 1),
        const SizedBox(height: 24),
        SkeletonBar(height: 18, width: 80),
        const SizedBox(height: 12),
        SkeletonBar(height: 250, widthFactor: 1),
        const SizedBox(height: 12),
        for (var i = 0; i < 4; i++) const SkeletonListTile(),
      ],
    );
  }

  /// 错误态：内嵌提示 + 重试按钮
  Widget _buildError(Object? error, Color primary) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.cloudOff, size: 48, color: SpitoutTokens.textTertiary(context)),
            const SizedBox(height: 12),
            Text(
              l10n.analyticsLoadFailed,
              style: TextStyle(color: SpitoutTokens.textSecondary(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _retryTick++;
                  _dataFuture = null;
                });
              },
              icon: const Icon(AppIcons.refresh, size: 18),
              label: Text(l10n.analyticsRetry),
            ),
          ],
        ),
      ),
    );
  }

  /// 图表主体内容（有数据 / 空数据共用）：支出趋势模块 + 分类排行模块。
  /// 空数据态通过传入空序列 / 空分类渲染：折线图绘制带箭头 xy 轴骨架、环图显示灰色饼图、列表显示骨架屏。
  Widget _buildMainContent({
    required List<DonutCategory> donutData,
    required List<_TopCat> catData,
    required List<double> values,
    required List<String> xLabels,
    required int? highlightIndex,
    required double sum,
    required double dailyAvg,
    required _MomInfo mom,
    required Color primary,
  }) {
    final l10n = AppLocalizations.of(context);
    final cur = _currentRange();
    return GestureDetector(
      // 横滑切周期仅作用于环图+列表容器
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < 0) {
          _onContentSwipeLeft();
        } else if (v > 0) {
          _onContentSwipeRight();
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 支出趋势模块
          Text(l10n.analyticsTrend, style: SpitoutTextTokens.title(context)),
          const SizedBox(height: 12),
          _buildTrendGrid(sum, dailyAvg, mom, primary),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              // 折线图高度 280：容纳 Y 轴刻度标签 + X 轴单位 + 上下安全区留白
              height: 280,
              // fl_chart 实现：空数据态只画轴骨架（无 0 值基线）；
              // 右侧 46px 安全区保证折线/数值标注/单位标签不遮 X 轴箭头。
              child: AnalyticsLineChart(
                values: values,
                xLabels: xLabels,
                highlightIndex: highlightIndex,
                xUnitLabel: _period == AnalyticsPeriod.week
                    ? l10n.analyticsWeek
                    : _period == AnalyticsPeriod.year
                        ? l10n.analyticsYear
                        : l10n.analyticsMonth,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 分类排行模块
          Text(l10n.analyticsCategoryLabel, style: SpitoutTextTokens.title(context)),
          const SizedBox(height: 12),
          CategoryDonutChart(data: donutData, sum: sum),
          const SizedBox(height: 12),
          // 空数据态不展示任何列表条目，仅保留占位区域
          for (final item in catData)
            CategoryRankRow(
              categoryId: item.id,
              category: item.category,
              name: item.name,
              value: item.total,
              percent: sum == 0 ? 0 : item.total / sum,
              color: primary,
              onCategoryTap: (categoryId, categoryName) =>
                  _openCategoryDetail(categoryId, categoryName, cur),
              subCategories: item.subCategories,
            ),
          // 空数据态：分类列表展示骨架屏占位（灰圆 + 灰条 + 带下横线进度条）
          if (catData.isEmpty) ..._buildCategorySkeleton(context, primary),
          // 底部留白：不小于 120px，避免悬浮 Tab 遮挡
          SizedBox(height: _bottomPadding(context)),
        ],
      ),
    );
  }

  /// 打开分类详情页（导航放在 page 层以保持 pages → widgets 单向依赖；
  /// 周期标签在这里按统计范围重新生成后透传）。
  void _openCategoryDetail(
    int categoryId,
    String categoryName,
    ({DateTime start, DateTime end, bool isCurrent}) cur,
  ) {
    final scope = _period.name;
    final selMonth =
        _period == AnalyticsPeriod.week ? _selWeekStart : _selMonth;

    // 生成周期标签
    String? periodLabel;
    if (scope != 'all') {
      periodLabel = switch (scope) {
        'year' => '${selMonth.year}',
        // 周视图：用选中周一展示该周区间（周一 ~ 周日）
        'week' => () {
            final end = selMonth.add(const Duration(days: 6));
            return '${selMonth.month}/${selMonth.day}-${end.month}/${end.day}';
          }(),
        _ => '${selMonth.year}.${selMonth.month.toString().padLeft(2, '0')}',
      };
    }

    Navigator.of(context).push(
      appPageRoute(
        builder: (_) => CategoryDetailPage(
          categoryId: categoryId,
          categoryName: categoryName,
          startDate: scope != 'all' ? cur.start : null,
          endDate: scope != 'all' ? cur.end : null,
          periodLabel: periodLabel,
        ),
      ),
    );
  }

  /// 分类列表空状态骨架：若干占位行（灰圆 + 灰条 + 带下横线的灰进度条），
  /// 提示「即将展示分类明细」，避免空列表突兀。
  List<Widget> _buildCategorySkeleton(BuildContext context, Color primary) {
    final placeholder = SpitoutTokens.divider(context);
    return List.generate(4, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: placeholder,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: placeholder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 带下横线的占位进度条（对应分类占比条）
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: placeholder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              height: 12,
              decoration: BoxDecoration(
                color: placeholder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 有数据的主体内容
  Widget _buildContent(_AnalyticsData data, Color primary) {
    final l10n = AppLocalizations.of(context);
    final cur = _currentRange();
    final rangeDays = cur.end.difference(cur.start).inDays;
    final dailyAvg = data.sum / (rangeDays <= 0 ? 1 : rangeDays);

    // 折线图序列处理：年视图按月序列需截断到当前月；其余为日序列
    final sd = ref.read(currentMonthStartDayProvider);
    final filteredSeriesRaw = () {
      if (data.seriesRaw is List<({DateTime month, double total})>) {
        final nowLabel = labelForDate(DateTime.now(), sd);
        final isCurrentYear = _selYear == nowLabel.year;
        if (isCurrentYear) {
          return (data.seriesRaw as List<({DateTime month, double total})>)
              .where((e) => e.month.month <= nowLabel.month)
              .toList();
        }
        return data.seriesRaw;
      }
      return data.seriesRaw;
    }();

    // 提取数值与 X 轴标签
    final values = <double>[];
    final xLabels = <String>[];
    int? highlightIndex;
    if (filteredSeriesRaw is List<({DateTime day, double total})>) {
      final series = filteredSeriesRaw;
      for (final e in series) {
        values.add(e.total);
        xLabels.add(e.day.day.toString());
      }
      if (_period == AnalyticsPeriod.week) {
        final today = DateTime.now();
        if (cur.isCurrent) highlightIndex = today.weekday - 1;
      } else {
        final today = DateTime.now();
        if (cur.isCurrent) highlightIndex = today.day - 1;
      }
    } else if (filteredSeriesRaw is List<({DateTime month, double total})>) {
      final series = filteredSeriesRaw;
      for (final e in series) {
        values.add(e.total);
        // 年视图折线图 X 轴月份：复用共享月份标签（与首页日期组件完全一致）
        xLabels.add(monthLabel(context, e.month.month));
      }
      // 年视图高亮用 nowLabel.month（与过滤口径一致），非当前年置 null
      if (cur.isCurrent) {
        final nowLabel = labelForDate(DateTime.now(), sd);
        highlightIndex = nowLabel.month - 1;
        if (highlightIndex < 0 || highlightIndex >= series.length) {
          highlightIndex = null;
        }
      }
    }

    // 周视图 X 轴用星期简称更直观
    if (_period == AnalyticsPeriod.week) {
      xLabels.clear();
      for (int i = 0; i < values.length; i++) {
        final d = cur.start.add(Duration(days: i));
        xLabels.add(_weekdayShort(d.weekday));
      }
    }

    // 环图展示 Top5 + 「其他」聚合：各扇区占比合计恒等于 100%，
    // 与下方完整分类排行榜口径一致。若只画 Top5，分类多于 5 个时
    // fl_chart 会把部分数据拉满整圆，形成「假 100%」（视觉误导）。
    final restTotal =
        data.catData.skip(5).fold<double>(0, (a, c) => a + c.total);
    final donutData = [
      for (final c in data.catData.take(5))
        DonutCategory(
          name: CategoryUtils.getDisplayName(c.name, context),
          percent: data.sum == 0 ? 0 : c.total / data.sum,
          total: c.total,
        ),
      // 「其他」聚合扇区固定排最后（即使金额大于第 5 名），
      // 符合记账类 App 的阅读习惯；restTotal 为 0 时不追加。
      if (restTotal > 0)
        DonutCategory(
          name: l10n.commonOther,
          percent: data.sum == 0 ? 0 : restTotal / data.sum,
          total: restTotal,
          isOther: true,
        ),
    ];

    final mom = _momInfo(data.sum, data.prevTotal, l10n);

    return _buildMainContent(
      donutData: donutData,
      catData: data.catData,
      values: values,
      xLabels: xLabels,
      highlightIndex: highlightIndex,
      sum: data.sum,
      dailyAvg: dailyAvg,
      mom: mom,
      primary: primary,
    );
  }

  /// 计算底部留白：取 140px 与「悬浮 Tab 高度+上移+安全区+间距」的较大值。
  /// 底部悬浮 Tab 上移 20px，bottom 留白从 140 起步。
  double _bottomPadding(BuildContext context) {
    final needed = 56 + 32 + MediaQuery.of(context).viewPadding.bottom + 16;
    return needed > 140 ? needed : 140.0;
  }

  /// 空数据态（全局无数据 或 当前周期无账）：渲染完整页面（日期/子Tab/图表空态/父Tab悬浮）。
  /// 折线图无线条、环图居中"0"、列表不展示任何条目。
  Widget _buildEmpty(Color primary) {
    final l10n = AppLocalizations.of(context);
    // 无数据时环比无对比基准
    final mom = _momInfo(0, 0, l10n);
    return _buildMainContent(
      donutData: const [],
      catData: const [],
      values: const [],
      xLabels: const [],
      highlightIndex: null,
      sum: 0,
      dailyAvg: 0,
      mom: mom,
      primary: primary,
    );
  }

  /// 外币补折算横幅：账本存在未折算外币交易时提示，并可一键补折算
  Widget _buildRecalcForeignBanner(BuildContext context) {
    final count =
        ref.watch(ledgerUnconvertedForeignTxCountProvider).value ?? 0;
    if (count <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Material(
        color: SpitoutTokens.surface(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(AppIcons.currencyExchange,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.recalcForeignTxBanner,
                  style: SpitoutTextTokens.label(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _runRecalcForeignTx(count),
                child: Text(l10n.recalcForeignTxAction, style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 折算脚注：账本存在外币交易（含已折算）时，提示统计数字已折本位币
  Widget _buildConvertedFootnote(BuildContext context) {
    final count = ref.watch(ledgerForeignTxCountProvider).value ?? 0;
    if (count <= 0) return const SizedBox.shrink();
    final base = ref.watch(currentLedgerCurrencyProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          AppLocalizations.of(context).statsConvertedFootnote(base),
          style: TextStyle(
            fontSize: 11,
            color: SpitoutTokens.textTertiary(context),
          ),
        ),
      ),
    );
  }

  /// 一键补折算：先刷新本位币汇率组，再按最新汇率重算账本内所有外币交易
  Future<void> _runRecalcForeignTx(int count) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.recalcForeignTxAction),
        content: Text(l10n.recalcSyncCountHint(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(AppLocalizations.of(dctx).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(AppLocalizations.of(dctx).commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    // 补折算前先确保本位币汇率组是新鲜的（缺组则整体跳过）；
    // extraQuotes 带上账本交易实际涉及的外币，避免无账户的币种永远补不上。
    final foreign = await repo.getLedgerForeignCurrencies(ledgerId);
    await refreshExchangeRatesFromUi(ref, force: true, extraQuotes: foreign);
    final n = await repo.recomputeForeignTxForLedger(ledgerId);
    if (!mounted) return;
    showToast(context, l10n.recalcForeignTxDone(n));
    // bump 统计刷新：横幅重查消失 + 各统计图表按新折算重算
    ref.read(statsRefreshProvider.notifier).tick();
  }
}

/// 环比展示信息
class _MomInfo {
  final String label; // 文案标签（如"环比上月"）
  final String value; // 百分比文案
  final bool up; // 是否上升
  final bool none; // 无对比基准（上期=0）

  const _MomInfo({required this.label, required this.value, required this.up, required this.none});
}

/// 子 Tab 胶囊构建器：独立 Widget 以便注册 BuildContext 供 ensureVisible 定位。
///
/// 采用 Material + InkWell：由 Material 处理 ink 反应 + 触摸优先级，
/// 相比 GestureDetector + HitTestBehavior.opaque 在 SingleChildScrollView
/// 内（特别是滚动期间）点击命中更可靠。
class _SubTabChipBuilder extends StatefulWidget {
  final AnalyticsSubTab tab;
  final bool selected;
  final VoidCallback onTap;
  final void Function(BuildContext) registerContext;

  const _SubTabChipBuilder({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.registerContext,
  });

  @override
  State<_SubTabChipBuilder> createState() => _SubTabChipBuilderState();
}

class _SubTabChipBuilderState extends State<_SubTabChipBuilder> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.registerContext(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final selected = widget.selected;
    // 文字 + 下横线样式：选中项用主色文字与下横线区分，未选中用次级色且无下横线，
    // 轻量聚焦当前账期。
    // 交互层用 Material + InkWell：标准 ink 反应 + Splash 视觉反馈 + 触摸优先级由 Material 处理。
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        // splash 颜色用主色淡色，highlight 透明，保留选中项的视觉差异。
        splashColor: primary.withValues(alpha: 0.12),
        highlightColor: primary.withValues(alpha: 0.06),
        // 显式约束 ink 区域为整块 chip，避免只在 Text 上出 ink。
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            widget.tab.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? primary : SpitoutTokens.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}