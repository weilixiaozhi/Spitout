import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../data/models.dart';
// 列表项的删除/编辑动作由调用方注入，组件内不直接依赖
// repositoryProvider / currentLedgerIdProvider / statsRefreshProvider /
// countsForLedgerProvider，故不 import 对应 providers。
// 仍用 TransactionDisplayItem 类型别名，故保留对 ui_state_providers 的引入。
import 'package:spitout/providers/ui/ui_state_providers.dart' show TransactionDisplayItem;
import 'package:spitout/providers/providers.dart'
    show SpitoutCloudLedgerMember, currentLedgerProvider;
import '../core/logging/logger_service.dart';
// 精确导入而非 barrel 自引用，避免 biz.dart export 本文件时形成循环依赖
import 'app_empty.dart';
import 'day_section_header.dart';
import 'transaction_list_item.dart';
import '../theme/divider.dart';
import '../utils/category_utils.dart';
import 'category_icon.dart';
import '../l10n/app_localizations.dart';
import '../utils/date/month_range.dart';

/// 可复用的交易列表组件
/// 支持显示分组的交易列表，包含日期头部和交易项
class TransactionList extends ConsumerStatefulWidget {
  /// 完整交易数据（无需二次加载）
  final List<TransactionDisplayItem>? transactionsWithDetails;

  /// 交易数据
  final List<({Transaction t, Category? category})>? transactions;

  /// 是否启用可见性检测用于月份跳转（主要用于首页）
  final bool enableVisibilityTracking;

  /// 月份变化回调（用于首页月份跳转逻辑）
  final Function(String dateKey, bool isVisible)? onDateVisibilityChanged;

  /// 自定义空状态显示
  final Widget? emptyWidget;

  /// 列表控制器（可选，用于精准跳转）
  final FlutterListViewController? controller;

  /// 列表项点击回调：onTap / onCategoryTap / onDelete 三个动作由调用方决定
  /// 如何打开编辑器 / 删除（首页用长按删除 + 模态确认）。
  final Future<void> Function(Transaction t, Category? category)? onEdit;

  /// 列表项删除回调（长按触发后的最终删除动作）。
  final Future<void> Function(Transaction t)? onDelete;

  /// 列表项点击分类图标的回调。
  final Future<void> Function(Category category)? onCategoryTap;

  /// 共享账本成员表:userId → SpitoutCloudLedgerMember(含 avatarUrl/displayName)。
  /// 由调用方(HomePage)在共享账本场景从 ledgerMembersProvider 构建,
  /// 传给列表项渲染真实头像 + 创建人/编辑人重叠(与详情页一致)。
  /// null = 单人账本,不展示头像。
  final Map<String, SpitoutCloudLedgerMember>? memberDisplayMap;

  /// 是否为共享账本。仅共享账本渲染协作头像;非共享账本不渲染(避免占位圆)。
  final bool isShared;

  /// 下拉刷新回调:由调用方(HomePage)传入 _onRefresh;列表滚到顶部下拉时触发。
  /// 为 null 时不启用下拉刷新(向前兼容其他使用方)。
  final Future<void> Function()? onRefresh;

  /// 是否使用外部自定义下拉刷新（首页专用）。
  ///
  /// 设计意图：首页下拉刷新从卡片底部拉出自定义指示器（Figma 2035:81），
  /// 不使用内置 RefreshIndicator 的圆形指示器。当此值为 true 时：
  /// - 不包裹 RefreshIndicator，仅返回可滚动容器（含空表场景）
  /// - 列表使用 BouncingScrollPhysics + AlwaysScrollableScrollPhysics，
  ///   让外部 NotificationListener 能捕获 overscroll 做跟手动画
  /// - onRefresh 由外部（HomePage）自行管理，此参数为 true 时 onRefresh 可为 null
  final bool useExternalRefresh;

  const TransactionList({
    super.key,
    this.transactionsWithDetails,
    this.transactions,
    this.enableVisibilityTracking = false,
    this.onDateVisibilityChanged,
    this.emptyWidget,
    this.controller,
    this.onEdit,
    this.onDelete,
        this.onCategoryTap,
    this.memberDisplayMap,
    this.isShared = false,
    this.onRefresh,
    this.useExternalRefresh = false,
  }) : assert(transactionsWithDetails != null || transactions != null,
            'Either transactionsWithDetails or transactions must be provided');

  @override
  ConsumerState<TransactionList> createState() => TransactionListState();
}

class TransactionListState extends ConsumerState<TransactionList> {
  late FlutterListViewController _controller;
  List<dynamic> _flatItems = []; // 扁平化的项目列表
  final Map<String, int> _dateIndexMap = {}; // 日期到列表索引的映射

  // 标记是否应使用预加载数据（当 Stream 数据与预加载数据不同时切换）
  bool _usePreloadedData = true;

  /// 获取统一格式的交易列表（用于内部处理）
  List<({Transaction t, Category? category})> get _transactionsList {
    return widget.transactions ?? [];
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FlutterListViewController();
    // 首次进入即构建扁平列表，build 不重复分组排序。
    _buildFlatItems();
  }

  @override
  void didUpdateWidget(covariant TransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检测预加载数据是否变化（如账本切换），重置状态
    if (widget.transactionsWithDetails != oldWidget.transactionsWithDetails) {
      if (widget.transactionsWithDetails != null) {
        _usePreloadedData = true; // 重置为预加载模式
      }
    }
    // 交易数据变化时才重建分组/排序结果（memo 化），
    // 避免月交易量大时每帧 build 都重复 O(n log n)。
    if (!identical(widget.transactions, oldWidget.transactions)) {
      _buildFlatItems();
    }
  }
  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose(); // 只在我们创建的controller时才dispose
    }
    super.dispose();
  }

  /// 跳转到列表顶部
  void jumpToTop() {
    try {
      _controller.sliverController.jumpToIndex(0);
    } catch (e) {
      // 跳转失败，忽略错误
    }
  }

  /// 切换到 Stream 模式（在用户离开首页时调用）
  /// 这样后续数据变化能正常刷新，且用户看不到切换过程
  void switchToStreamMode() {
    if (_usePreloadedData) {
      // 延迟 100ms 再切换，等导航动画开始后用户看不到
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _usePreloadedData) {
          logger.info('TransactionList', '用户交互，切换到Stream模式');
          // 用 setState 改 _usePreloadedData,否则后续 build 还在跑
          // preloaded 路径,共享账本 WS 推送下来的新数据永远不会显示
          // (preloaded 是 Splash 阶段的快照)。
          setState(() {
            _usePreloadedData = false;
          });
        }
      });
    }
  }

  /// 共享账本 WS 推送强制切到 Stream 模式 — 没有导航动画顾虑,立即切。
  /// 用于 sharedResourceRefreshProvider tick 触发的场景:Owner 改 tx 引用的
  /// category,Editor 这边需要立即丢掉 preloaded(里面挂的是
  /// Splash 阶段的旧值)走 provider 拉新值。
  void forceStreamModeImmediate() {
    if (!mounted) return;
    if (!_usePreloadedData) return;
    logger.info('TransactionList', 'WS 推送强制切 Stream 模式 (immediate)');
    setState(() {
      _usePreloadedData = false;
    });
  }

  /// 跳转到指定月份(按账本起始日的周期范围匹配,而非 yyyy-MM 前缀)
  bool jumpToMonth(DateTime targetMonth, {int startDay = 1}) {
    final range = periodForLabel(targetMonth.year, targetMonth.month, startDay);

    // 查找该周期内的任意一天
    for (final entry in _dateIndexMap.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      if (!d.isBefore(range.start) && d.isBefore(range.end)) {
        try {
          _controller.sliverController.jumpToIndex(entry.value);
          return true;
        } catch (e) {
          // 跳转失败，返回false
          return false;
        }
      }
    }

    return false; // 没有找到目标月份
  }

  /// 构建扁平化的项目列表
  void _buildFlatItems() {
    final transactions = _transactionsList;

    // 按天分组
    final dateFmt = DateFormat('yyyy-MM-dd');
    final groups = <String, List<({Transaction t, Category? category})>>{};
    for (final item in transactions) {
      final dt = item.t.happenedAt.toLocal();
      final key = dateFmt.format(DateTime(dt.year, dt.month, dt.day));
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    // 构建扁平的项目列表和日期索引映射
    _flatItems = <dynamic>[];
    _dateIndexMap.clear();

    for (final key in sortedKeys) {
      final list = groups[key]!;
      // 记录日期头部在扁平化列表中的索引
      _dateIndexMap[key] = _flatItems.length;
      // 添加日期头部
      _flatItems.add(('header', key, list));
      // 添加所有交易项
      for (final item in list) {
        _flatItems.add(('transaction', item, list));
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    // 无数据时展示空状态。
    // 空表也必须能下拉刷新 —— 用户场景是"刚切换账本/新装应用时空表,
    // 想下拉从云端同步数据进来"。用 SingleChildScrollView +
    // AlwaysScrollableScrollPhysics 包一层,内容尺寸为 0 也能触发下拉。
    if (_flatItems.isEmpty) {
      final empty = widget.emptyWidget ??
          AppEmpty(
            text: AppLocalizations.of(context).commonEmpty,
            subtext: AppLocalizations.of(context).homeNoRecords,
          );
      // 无刷新需求且非外部刷新模式时直接返回空态（向前兼容其他使用方）
      if (widget.onRefresh == null && !widget.useExternalRefresh) return empty;

      // 可滚动容器：即使内容尺寸为 0,physics 也允许 overscroll,从而触发外部
      // NotificationListener 的下拉检测。SizedBox(height: maxHeight) 让空态撑满
      // viewport 居中展示,整个区域都能作为下拉触发区。
      final scrollable = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          // BouncingScrollPhysics 允许 overscroll 回弹，让外部能跟踪下拉偏移
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: SizedBox(
            height: constraints.maxHeight,
            child: empty,
          ),
        ),
      );

      // 外部刷新模式：不包 RefreshIndicator，仅返回可滚动容器
      if (widget.useExternalRefresh) return scrollable;

      // 内置刷新模式：包 RefreshIndicator
      return RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: widget.onRefresh!,
        child: scrollable,
      );
    }

    // 使用FlutterListView渲染列表;外层包 RefreshIndicator,仅列表滚到顶部下拉触发刷新。
    final listView = FlutterListView(
      controller: _controller,
      // 数据不足一屏时也要能下拉刷新。
      // BouncingScrollPhysics 默认在内容 < viewport 时禁止 overscroll → 拉不动;
      // 以 AlwaysScrollableScrollPhysics 作为父级,让任何情况都允许 overscroll,
      // 同时保留 Bouncing(iOS 风格回弹)的视觉效果。
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      delegate: FlutterListViewDelegate(
        (BuildContext context, int index) {
          final item = _flatItems[index];
          final type = item.$1 as String;

          if (type == 'header') {
            // 渲染日期头部
            final dateKey = item.$2 as String;
            final list = item.$3 as List<({Transaction t, Category? category})>;
            // 整数分累加,避免 double 尾差;展示时再转"元"。
            int dayExpense = 0;
            for (final it in list) {
              // 全局仅支出模式，type 固定为 'expense'
              if (it.t.type == 'expense') {
                dayExpense += it.t.nativeAmount ?? it.t.amount;
              }
            }
            // 日支出汇总统一以账本本位币符号展示（nativeAmount 已折算为本位币），
            // currencyCode 为 null 时 DaySectionHeader 回退为无符号纯数字。
            final ledgerCurrency =
                ref.watch(currentLedgerProvider).asData?.value?.currency;
            // 不在每个 DaySectionHeader 上方画分割线。
            // 视觉上"天"靠日期标题 + 行间分割线区分,避免每天顶部都出现一条
            // 横线导致列表显得零碎;数据行之间的分割线由 _TransactionListRow
            // 内部的 SpitoutDivider.short 保持(每个交易项之间仍有分割线)。
            Widget header = DaySectionHeader(
              dateText: dateKey,
              expense: dayExpense / 100,
              currencyCode: ledgerCurrency,
            );

            // 如果启用可见性跟踪，则包装VisibilityDetector
            if (widget.enableVisibilityTracking && widget.onDateVisibilityChanged != null) {
              header = VisibilityDetector(
                key: Key('header-$dateKey'),
                onVisibilityChanged: (VisibilityInfo info) {
                  // 当可见比例大于50%时认为可见
                  widget.onDateVisibilityChanged!(dateKey, info.visibleFraction > 0.5);
                },
                child: header,
              );
            }

            return header;
          } else {
            // 渲染交易项
            final it = item.$2 as ({Transaction t, Category? category});
            final allItemsInDay = item.$3 as List<({Transaction t, Category? category})>;
            final isExpense = it.t.type == 'expense';

            // 获取分类显示名称
            final categoryName =
                CategoryUtils.getDisplayName(it.category?.name, context);

            // 删除入口为长按 → 外部 onDelete 回调。
            return _TransactionListRow(
              index: index,
              it: it,
              categoryName: categoryName,
              isExpense: isExpense,
              allItemsInDay: allItemsInDay,
              memberDisplayMap: widget.memberDisplayMap,
              isShared: widget.isShared,
              onTap: widget.onEdit == null
                  ? null
                  : () async {
                      switchToStreamMode();
                      await widget.onEdit!(it.t, it.category);
                    },
              onCategoryTap: (widget.onCategoryTap == null ||
                      it.category?.id == null)
                  ? null
                  : () async {
                      switchToStreamMode();
                      await widget.onCategoryTap!(it.category!);
                    },
        onLongPress: widget.onDelete == null
            ? null
            : () async {
                // 删除确认统一由调用方(onDelete)负责(首页会展示"将删除{分类}"提示),
                // 此处不重复弹窗,避免双重确认。
                await widget.onDelete!(it.t);
              },
            );
          }
        },
        childCount: _flatItems.length,
      ),
    );
    // 外部刷新模式：不包 RefreshIndicator，直接返回可滚动列表
    // 外部（HomePage）通过 NotificationListener 跟踪 overscroll 实现自定义指示器
    if (widget.useExternalRefresh) return listView;
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: widget.onRefresh ?? () async {},
      child: listView,
    );
  }
}

/// 单条交易行：长按删除 + 点击编辑。封装后便于在 _buildListDelegate 中复用。
class _TransactionListRow extends StatelessWidget {
  final int index;
  final ({Transaction t, Category? category}) it;
  final String categoryName;
  final bool isExpense;
  final List<({Transaction t, Category? category})> allItemsInDay;
  final Map<String, SpitoutCloudLedgerMember>? memberDisplayMap;
  final bool isShared;
  final VoidCallback? onTap;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onLongPress;

  const _TransactionListRow({
    required this.index,
    required this.it,
    required this.categoryName,
    required this.isExpense,
    required this.allItemsInDay,
    required this.memberDisplayMap,
    required this.isShared,
    required this.onTap,
    required this.onCategoryTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isLastInGroup = allItemsInDay.last.t.id == it.t.id;
    // 把整张成员表 + 交易的创建人/编辑人 userId 透传给列表项,
    // 由 TransactionListItem 自行解析真实头像并做重叠展示。
    return Column(
      children: [
        GestureDetector(
          onLongPress: onLongPress,
          child: TransactionListItem(
            icon: getCategoryIconData(category: it.category),
            category: it.category,
            title: it.t.note ?? '',
            categoryName: categoryName,
            amount: it.t.amount,
            currencyCode: it.t.currencyCode,
            nativeAmount: it.t.nativeAmount,
            isExpense: isExpense,
            happenedAt: it.t.happenedAt,
            lastEditedAt: it.t.lastEditedAt,
            collaboratorMap: memberDisplayMap,
            creatorUserId: it.t.createdByUserId,
            editorUserId: it.t.lastEditedByUserId,
            isShared: isShared,
            excludeFromStats: it.t.excludeFromStats,
            onTap: onTap,
            onCategoryTap: onCategoryTap,
          ),
        ),
        if (!isLastInGroup) SpitoutDivider.short(context, indent: 56 + 16, endIndent: 16),
      ],
    );
  }
}
