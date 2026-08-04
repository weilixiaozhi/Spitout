import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'dart:async';

import 'package:spitout/providers/providers.dart';
import '../../data/models.dart';
import '../../widgets/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../core/logging/logger_service.dart';
import 'package:spitout/providers/core/post_processor.dart';
import '../../services/maintenance/analytics_test_data_seeder.dart';
import '../../utils/format_utils.dart';
import '../../utils/date/month_range.dart';
import '../../utils/category_utils.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart' show ledgerMembersProvider;
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudLedgerMember;
import '../../core/identity/local_user_identity.dart' show localSelfIdProvider;
import '../../services/data/tx_author_service.dart';
import '../transaction/category_detail_page.dart';
import 'ledgers_page.dart';
import '../../routes.dart';
import '../../theme/icons/app_icons.dart';

/// 首页内容区统一水平内边距（8）：头部汇总卡与下方交易列表共用，保证两者左右边缘对齐。

/// 首页【明细】tab 视图。
///
/// 设计目标：
/// - 头部按 Figma 稿(53:6)布局：首行「月份选择 + 日历本」同行，
///   汇总卡右缘挂账本徽章 tab，轻扫提示行位于日期组件与卡片之间；
/// - 列表**仅展示单月**，左右滑跟手切月（ViewPager 驱动），松手时偏移 ≥ 80% 屏宽才切页否则回弹；
/// - 头部固定，列表区域切月；拖动过程相邻目标页显示骨架屏占位；
/// - 头部卡片为主色汇总卡「本月支出 + 账本徽章 + 今日/本周」；
/// - 每天明细用分割线隔开，右侧小字显示「当天支出」；
/// - 列表项长按删除、点击编辑，下拉刷新拉取云/本地数据。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  // 三屏 PageView：左=上月、中=当月、右=下月。
  // 始终以中页（index 1）为基准：手指拖动时页面跟手位移，松手时偏移 ≥ 80% 屏宽才翻月并重置回中页。
  static const int _centerPageIndex = 1;
  late final PageController _monthPager;

  // 下拉刷新进行中(用于指示器展开/收起控制)。
  bool _isPulling = false;

  // 刷新结果文案：
  // - null  → 刷新进行中，指示器内显示"正在同步账本数据"（常驻旋转 icon）。
  // - 非 null → 刷新完成，指示器内就地展示该结果文案（如"已同步云端账本数据"），
  //            不弹 toast，停留 1 秒后随指示器平滑收起。
  // 设计意图：复用刷新指示器本身承载结果，减少打断、保持视觉连贯
  // （避免另弹 toast 过于打扰）。
  // 归零约定：指示器收起动画完成时必须把本字段重置为 null（见 _onRefresh 的收起计时器）。
  // 否则下次下拉拖拽阶段（_onRefresh 需松手后才触发，拖拽中尚未置空）指示器已随手势展开，
  // 会先残留显示"上次的刷新结果文案"而非"正在同步账本数据"，造成视觉回退。
  String? _syncResultText;

  // 刷新完成后延时收起指示器的计时器（结果文案停留 1 秒）。
  // 设计意图：结果文案需要"停留 1 秒再收起"，用 Timer 实现延时；
  // 必须在 dispose 中 cancel，避免页面销毁后回调访问已释放的 State。
  Timer? _refreshDoneTimer;

  // ── 自定义下拉刷新指示器状态（Figma 2035:81）──
  //
  // 设计意图：刷新指示器为从卡片底部拉出的单一指示器（icon 旋转 + 文案常驻）。
  //
  // 指示器高度由 _indicatorCtrl 驱动（0.0=隐藏, 1.0=全高 32px）：
  // - 拖拽阶段：直接设值，跟手展开
  // - 松手达标：animateTo(1.0) 平滑过渡到全高
  // - 松手未达标 / 刷新完成：animateTo(0.0) 平滑收起
  //
  // _spinCtrl 在拖拽阶段即启动 repeat()，刷新期间持续旋转，完成后 stop()。
  late final AnimationController _indicatorCtrl;
  late final AnimationController _spinCtrl;

  // 当前下拉偏移（像素，正值=向下拉）。仅拖拽阶段有意义。
  double _pullOffset = 0;
  // 本次拖拽过程中的最大偏移（用于判断是否达到触发阈值，避免回弹后误判）。
  double _maxPullOffsetThisDrag = 0;
  // 上一帧的 scroll pixels（用于区分"用户在拉"vs"松手回弹"：
  // pixels 变得更负 = 用户在拉；pixels 变得更接近 0 = 松手回弹，此时冻结指示器高度）。
  double _lastPullPixels = 0;

  // 指示器全高（Figma：8px 上 padding + 16px 内容行高 + 8px 下 padding）
  static const double _kIndicatorHeight = 32.0;
  // 触发刷新的下拉阈值（略大于指示器全高，提供合理阻尼感）
  static const double _kRefreshThreshold = 48.0;

  // 切月防重入锁。
  // 设计意图：_onPageScrollSettled 由 ScrollEndNotification 驱动，而
  // jumpToPage(中页) 本身也会派发 ScrollEndNotification；若不加锁，
  // jumpToPage 前后到达的通知可能在 _monthPager.page 仍为 0/2 的瞬间
  // 重复触发切月，导致 selectedMonth 被连续偏移成离谱年份(如 1723/-3127)。
  // 加锁后：切月 + jumpToPage 期间丢弃后续通知，下一帧布局稳定后再解锁。
  bool _isSwitchingMonth = false;

  @override
  void initState() {
    super.initState();
    _monthPager = PageController(initialPage: _centerPageIndex);
    // 指示器高度控制器：0.0=隐藏, 1.0=全高。拖拽时直接设值，松手/收起时 animateTo。
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 0.0,
    );
    // icon 旋转控制器：刷新期间 repeat() 持续旋转，完成后 stop()。
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _monthPager.dispose();
    _indicatorCtrl.dispose();
    _spinCtrl.dispose();
    // 防止页面销毁后延时收起回调触发 setState/animateTo 访问已释放的控制器。
    _refreshDoneTimer?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // 头部交互
  // -----------------------------------------------------------------------

  /// 点击账本胶囊 → 进入账本管理页（LedgersPage）。
  /// 空状态也只进管理页，由用户在内部主动新建。
  void _onTapLedgerCapsule() {
    Navigator.push(
      context,
      appPageRoute(
        builder: (_) => const LedgersPage(),
      ),
    );
  }

  /// 点击左上角日期拉起统一日期滚轮(年-月),视觉与 AppSheet 一致。
  /// 草稿模式:滚轮只更新草稿,点"完成"才切月。
  Future<void> _onTapDateHeader() async {
    final month = ref.read(selectedMonthProvider);
    final l10n = AppLocalizations.of(context);
    final res = await showWheelDatePicker(
      context,
      initial: month,
      mode: WheelDatePickerMode.ym,
      title: l10n.homeSelectBillMonth,
      subtitle: l10n.homePickerHint,
      confirmLabel: l10n.commonDone,
    );
    if (res == null || !mounted) return;
    if (res.year == month.year && res.month == month.month) {
      return;
    }
    // 切月：重置 PageView 到中间页，让 _buildPageView 自动按新月份渲染。
    setState(() {
      ref.read(selectedMonthProvider.notifier).state = res;
    });
    if (_monthPager.hasClients) {
      _monthPager.jumpToPage(_centerPageIndex);
    }
  }

    /// debug 包专用：弹窗选择范围（年/月/周/日），一键填充统计页测试数据。
  /// 填充后刷新统计相关 provider，使进入统计页立即呈现数据。
  Future<void> _onTapFillTestData() async {
    final scope = await showDialog<TestDataScope>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('填充测试数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.calendarViewWeek),
              title: const Text('按年（全年12个月）'),
              onTap: () => Navigator.pop(ctx, TestDataScope.year),
            ),
            ListTile(
              leading: const Icon(AppIcons.calendarViewMonth),
              title: const Text('按月（整月）'),
              onTap: () => Navigator.pop(ctx, TestDataScope.month),
            ),
            ListTile(
              leading: const Icon(AppIcons.viewWeek),
              title: const Text('按周（本周7天）'),
              onTap: () => Navigator.pop(ctx, TestDataScope.week),
            ),
            ListTile(
              leading: const Icon(AppIcons.calendarToday),
              title: const Text('按日（今日）'),
              onTap: () => Navigator.pop(ctx, TestDataScope.day),
            ),
          ],
        ),
      ),
    );
    if (scope == null) return;

    final ledgerId = ref.read(currentLedgerIdProvider);
    final baseCurrency = ref.read(currentLedgerCurrencyProvider);
    // 解析当前操作者标识作为填充交易的支出人(云 userId 优先,未登录
    // 用设备身份兜底),与真实创建路径的 markTxAuthor 回填口径一致,
    // 避免填充数据出现「支出人未知」或分摊统计误归因。
    String? paidByUserId;
    try {
      final cloud = await ref.read(spitoutCloudProviderInstance.future);
      final cloudUserId = await TxAuthorService.currentUserId(cloud);
      final localSelfId = await ref.read(localSelfIdProvider.future);
      paidByUserId =
          (cloudUserId != null && cloudUserId.isNotEmpty) ? cloudUserId : localSelfId;
    } catch (e) {
      // 未配置/未登录时跳过,seeder 侧不传支出人(仅 debug 数据,不影响生产)。
      paidByUserId = null;
    }
    final seeder = AnalyticsTestDataSeeder(ref.read(repositoryProvider));
    final count = await seeder.fill(
      ledgerId: ledgerId,
      baseCurrency: baseCurrency,
      scope: scope,
      paidByUserId: paidByUserId,
    );
    if (!mounted) return;

    // 刷新统计页相关 provider，清除「全局无数据」空态
    ref.invalidate(analyticsHasAnyExpenseProvider);
    ref.invalidate(analyticsDataRangeProvider);
    ref.read(statsRefreshProvider.notifier).state++;
    showToast(context, '已填充 $count 条测试数据');
  }

  /// 紧凑头部"回到当月"按钮:切回当前自然月,重置 PageView 到中页。
  void _backToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      ref.read(selectedMonthProvider.notifier).state =
          DateTime(now.year, now.month, 1);
    });
    if (_monthPager.hasClients) {
      _monthPager.jumpToPage(_centerPageIndex);
    }
  }

  /// 下拉刷新。
  /// 统一刷新策略：无论是否配置云同步（含增量/全量等所有云同步方式）、
  /// 无论云同步成功或失败，均先尝试云下载，再【必定】执行本地刷新
  /// （汇率 + 个性化设置 + 汇总 + 补折算）。
  /// 云同步连接失败只降级兜底，不会阻断用户「刷新汇率等本地字段」的核心诉求；
  /// 云端拉取失败会在 WS 重连 / 网络恢复后由后台自动静默重试。
  ///
  /// 云失败（含未配置、连接/鉴权异常）一并降级到 _runLocalRefresh()，
  /// 不会让云失败贯穿外层 catch 把整次刷新判为失败。
  Future<void> _onRefresh() async {
    if (_isPulling) return;
    setState(() {
      _isPulling = true;
      // 刷新开始：清空结果文案，让指示器回到"正在同步账本数据"常驻态。
      _syncResultText = null;
    });
    // 启动 icon 旋转动画（刷新期间持续转圈）
    _spinCtrl.repeat();
    final l10n = AppLocalizations.of(context);
    final ledgerId = ref.read(currentLedgerIdProvider);
    final sync = ref.read(syncServiceProvider);

    // 云同步结果分类：
    // - isCloud=true 且 cloudOk=true  → 云端成功
    // - isCloud=true 且 cloudOk=false → 云端已配置但连接/下载失败（已降级本地刷新）
    // - isCloud=false                 → 未配置云同步（纯本地刷新）
    bool isCloud = false;
    bool cloudOk = false;
    // 云端拉取的结构化结果(成功时非空),据此区分"增量拉到 / 自愈补回 /
    // 无差异 / 有差异但未能恢复"四种结果文案。
    PullOutcome? outcome;
    // 刷新结果文案在指示器内展示，避免弹窗打扰。
    String? resultText;
    try {
      // 1) 先尝试云同步下载（已配置云同步时才会真正走网络）。
      // 走 pullIncrementalWithHeal —— 只做增量 pull + 受闸门/节流/熔断保护的
      // 缺失自愈，不做无条件全量恢复；无条件全量恢复只用于云同步页明确的
      // "从云端恢复"操作。自愈的幂等性由 syncId upsert/去重保证。
      try {
        outcome = await sync.pullIncrementalWithHeal(ledgerId: ledgerId);
        isCloud = true;
        cloudOk = true;
        logger.info('HomePage',
            '下拉刷新云端成功: ledgerId=$ledgerId pulled=${outcome.incremental} healed=${outcome.healed} gap=${outcome.gapRemaining} circuit=${outcome.circuitBroken}');
      } on UnsupportedError {
        // 未配置云同步（LocalOnlySyncService 抛此异常）：按纯本地刷新处理。
        isCloud = false;
      } catch (e, st) {
        // 兜底：云同步已配置但连接/下载失败（网络异常、鉴权失败、超时等），
        // 单独 catch 降级为本地刷新，不阻断整个下拉刷新；
        // 云同步会在 WS 重连 / 网络恢复后由后台自动静默重试。
        logger.warning('HomePage', '云同步下载失败，降级为本地刷新: $e', st);
        isCloud = true;
        cloudOk = false;
      }

      // 2) 本地刷新：只要触发了下拉刷新，无论云同步成功/失败/未配置，必定执行。
      // 这是「刷新永远生效」的核心保证——抽成 _runLocalRefresh() 复用。
      await _runLocalRefresh();
    } catch (e, st) {
      // 仅当本地刷新兜底逻辑自身也失败，才视为真正的刷新失败。
      logger.error('HomePage', '下拉刷新失败（本地兜底也失败）', e, st);
      resultText = l10n.homePullCloudFailed;
    }

    if (!mounted) return;

    // 成功结果文案（原 toast 文案），失败分支已在 catch 中写入 resultText。
    resultText ??= isCloud
        ? (cloudOk
            ? _cloudRefreshMessage(l10n, outcome)
            : l10n.homePullCloudFailedButLocalOk)
        : l10n.homePullLocalSuccess;

    // 停止 icon 旋转并归位到自然角度，避免结果展示阶段 icon 停留在半旋转角（视觉异常）。
    _spinCtrl.stop();
    _spinCtrl.value = 0;

    // 把结果文案写入指示器并触发重建：在指示器内就地展示，减少打断。
    setState(() => _syncResultText = resultText);

    // 结果文案停留 1 秒后平滑收起指示器。期间保持 _isPulling=true，
    // 避免用户新的下拉拖拽在结果展示中途干扰指示器高度或重复触发刷新。
    _refreshDoneTimer?.cancel();
    _refreshDoneTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _isPulling = false);
      // 平滑收起指示器。收起动画完成后再把结果文案归零（而非立即清零），
      // 这样收起过程中仍展示结果文案（不闪变"正在同步"），归零发生在指示器已不可见时，
      // 最终实现"下次下拉拖拽即从'正在同步账本数据'开始"的归零状态。
      _indicatorCtrl.animateTo(0.0).then((_) {
        if (!mounted) return;
        setState(() => _syncResultText = null);
      });
    });
  }

  /// 云端下拉刷新成功的文案:
  /// - 自愈也未能拉回差异(含熔断)→ 引导到云同步页手动"从云端恢复";
  /// - 自愈补回了历史缺失数据 → 明示补回条数;
  /// - 其余(增量拉到 / 无差异)→ 通用"已同步"。
  String _cloudRefreshMessage(AppLocalizations l10n, PullOutcome? outcome) {
    final o = outcome;
    if (o == null) return l10n.homePullCloudSuccess;
    if (o.circuitBroken || o.gapRemaining) return l10n.homePullCloudGap;
    if (o.didHeal) return l10n.homePullCloudHealed(o.total);
    return l10n.homePullCloudSuccess;
  }

  /// 本地刷新（下拉刷新与云同步降级共用）。
  /// 刷新汇率、重新汇总与列表、刷新当前账本与个性化配色设置，并补折算未折算外币交易。
  /// 抽成独立方法供「未配置云同步」「云同步失败降级」「云同步成功」三条分支复用，
  /// 避免重复代码；保证只要在刷新/同步路径上就必定执行本地刷新。
  Future<void> _runLocalRefresh() async {
    // 刷新汇率（force 跳过 24h 节流），并 bump 全局汇率 tick 触发相关 provider 重算。
    await refreshExchangeRatesFromUi(ref, force: true);
    // 重新汇总与列表：invalidate 月度汇总 + 当前账本 + 统计刷新信号。
    ref.invalidate(monthlyTotalsProvider);
    ref.invalidate(currentLedgerProvider);
    ref.read(statsRefreshProvider.notifier).state++;
    // 重新拉一次个性化设置（颜色方案 / 主题模式）以确保与磁盘一致。
    await ref.read(themeModeInitProvider.future);
    await ref.read(expenseColorSchemeInitProvider.future);
    ref.invalidate(expenseColorSchemeProvider);

    // 补折算：检查是否有未折算的外币交易（如导入/同步进来的数据缺汇率），
    // 有则补拉涉及外币的汇率并折算，避免数据失真。非致命，失败仅告警。
    try {
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);
      final unconvertedCount = await repo.countUnconvertedForeignTx(ledgerId);
      if (unconvertedCount > 0) {
        // 先拉取涉及外币的汇率（force 确保不跳过 24h 节流）
        final foreignCurrencies =
            await repo.getLedgerForeignCurrencies(ledgerId);
        final rateOk = await refreshExchangeRatesFromUi(ref,
            force: true, extraQuotes: foreignCurrencies);
        final recalcCount = await repo.recomputeForeignTxForLedger(ledgerId);
        logger.info('HomePage',
            '本地刷新补折算: 未折算=$unconvertedCount 拉取汇率=$rateOk 补折算=$recalcCount');
        if (recalcCount > 0) {
          // 折算成功 → invalidate currentLedgerProvider 强制 _MonthPage
          // 重建 stream（StreamBuilder 的 key 依赖 ledgerId，重新订阅 Drift 流），
          // 同时 invalidate 月度汇总让「今日/本月」卡片立刻刷新。
          ref.invalidate(monthlyTotalsProvider);
          ref.invalidate(currentLedgerProvider);
          ref.read(statsRefreshProvider.notifier).state++;
        }
      }
    } catch (e) {
      logger.warning('HomePage', '本地刷新补折算失败(非致命): $e');
    }
  }

  // -----------------------------------------------------------------------
  // 左右滑切月逻辑
  // -----------------------------------------------------------------------

  /// PageView 滚动结束后判定是否提交月份切换。
  /// 仅当视图落在相邻页（0=上月 / 2=下月）时才提交：更新 selectedMonth 并重置回中页，
  /// 中页随即按新月份渲染真实数据；落在中页（未达阈值回弹）则不切月。
  void _onPageScrollSettled() {
    // 防重入：上一次切月的 jumpToPage 派发的 ScrollEndNotification 尚未平息，
    // 此时 _monthPager.page 可能仍为旧值(0/2)，必须丢弃，否则会重复切月。
    if (_isSwitchingMonth) return;
    if (!_monthPager.hasClients) return;
    // page 在布局未完成(viewportDimension=0)时可能为 null 或 NaN:
    // double.nan.round() == 0 会被误判为上月页 → 误切月，故必须显式兜底。
    final rawPage = _monthPager.page;
    if (rawPage == null || rawPage.isNaN || rawPage.isInfinite) return;
    final page = rawPage.round();
    if (page == _centerPageIndex) return;
    _isSwitchingMonth = true;
    // page 2 → 下月(dir=1)，page 0 → 上月(dir=-1)
    final dir = page == 2 ? 1 : -1;
    final current = ref.read(selectedMonthProvider);
    final target = DateTime(current.year, current.month + dir, 1);
    ref.read(selectedMonthProvider.notifier).state = target;
    // 重置到中页：中页会按新 selectedMonth 渲染真实交易列表，
    // 相邻页保持骨架屏占位，下一次左右滑仍以中页为基准。
    _monthPager.jumpToPage(_centerPageIndex);
    // 下一帧解锁：确保 jumpToPage 派发的 ScrollEndNotification 已被本锁拦截，
    // 且此时 page 已稳定在中页，不会再次误切月。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _isSwitchingMonth = false;
    });
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // 顶部安全区由 PrimaryHeader 内置 SafeArea 接管，外层不叠加（避免双重消费）
      body: Column(
        children: [
          _buildHeader(),
          // 左右滑切月列表(下拉刷新指示器以 Stack 叠层方式在 _buildPageView 内部渲染，
          // 避免指示器高度变化影响列表 viewport 导致抖动)
          Expanded(
            child: _buildPageView(),
          ),
        ],
      ),
    );
  }

  // 头部(Figma 首页头部稿 node 53:6 布局):
  //   首行(月份选择 + 回到当月)由全局统一 PrimaryHeader 渲染
  //   → 轻扫提示行位于日期组件(首行)与汇总卡之间
  //   → 汇总卡(账本徽章以 tab 挂在卡片右缘)
  // 首行留白/标题/图标/文字链规范全部内置在 PrimaryHeader，本页只组装内容。
  Widget _buildHeader() {
    final month = ref.watch(selectedMonthProvider);
    return Consumer(
      builder: (context, ref, _) {
        final currentLedgerAsync = ref.watch(currentLedgerProvider);
        return currentLedgerAsync.when(
          skipLoadingOnReload: true,
          data: (ledger) {
            final l10n = AppLocalizations.of(context);
            final isEmpty = ledger == null;
            final ledgerName = isEmpty
                ? l10n.ledgersNew
                : translateLedgerName(context, ledger.name);
            final now = DateTime.now();
            // 非当月时由首行"回到当月"文字链提供快捷回到当月入口
            final isCurrentMonth =
                month.year == now.year && month.month == now.month;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 首行：全局统一头部组件。月份标题可点击拉起日期滚轮。
                // 下拉刷新指示器已移至卡片下方（_buildRefreshIndicator），
                // 不在 header bottom 显示 LinearProgressIndicator。
                PrimaryHeader(
                  title: monthYearLabel(context, month.month, month.year),
                  onTitleTap: _onTapDateHeader,
                  titleTrailing: AppIcons.chevronDown,
                  actions: [
                    if (!isCurrentMonth)
                      HeaderTextAction(
                        label: l10n.homeBackToCurrentMonth,
                        onPressed: _backToCurrentMonth,
                      ),
                    // debug 包：一键填充统计页测试数据（年/月/周/日 + 多币种）
                    if (foundation.kDebugMode)
                      HeaderIconAction(
                        icon: AppIcons.autoAwesome,
                        tooltip: '填充测试数据',
                        onPressed: _onTapFillTestData,
                      ),
                  ],
                ),
                // 轻扫提示行：从原「卡片下方」上移到「日期组件(首行)与汇总卡之间」，
                // 轻扫提示行：放在日期组件与汇总卡之间（共用 SwipeHint，统一样式）。
                // 左内边距对齐 PrimaryHeader 的日期标题(距左 14)，让图标左边缘与日期文字左边缘对齐，主副标题块左边界一致。
                // PrimaryHeader→提示的间距承接标题行底部留白，下方留 8 接卡片(该距离已确认刚好，保持不变)。
                SwipeHint(
                  icon: AppIcons.swipe,
                  padding: const EdgeInsets.only(left: 14, bottom: 8),
                  text: l10n.homeSwitchMonthHint,
                ),
                // 汇总卡：与下方列表共用统一水平内边距(8)，保证左右边缘对齐
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 汇总卡:蓝底白字(本月支出 + 今日 + 本周),账本徽章挂右缘 tab。
                      // 整张卡片可点击 → 进入账本管理页。
                      _HeaderSummary(
                        month: month,
                        onTapLedger: _onTapLedgerCapsule,
                        ledgerName: ledgerName,
                        isEmpty: isEmpty,
                      ),
                    ],
                  ),
                ),
                // 分摊统计入口：当前账本开启 AA 分摊时显示，
                // 位于汇总卡下方、交易列表上方，样式与编辑页原入口保持一致。
                if (ledger != null && ledger.aaEnabled) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(AppIcons.pieChart, size: 18),
                      label: Text(l10n.ledgerAaStatisticsEntry),
                      onPressed: () {
                        // 从首页进入即当前账本的分摊统计，直接传账本 id。
                        Navigator.of(context).pushNamed(
                          Routes.aaStatistics,
                          arguments: ledger.id,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // 自定义下拉刷新指示器（Figma 2035:81）
  // -----------------------------------------------------------------------

  /// 构建刷新指示器：从卡片底部拉出的 Row（旋转 icon + "正在同步账本数据"文案）。
  ///
  /// 视觉规范（Figma）：
  /// - Row 居中，gap 8px，垂直 padding 8px
  /// - icon: refreshCw 12px，色 = colorScheme.primary（#3F72AF）
  /// - text: 12px Inter Regular，同色
  ///
  /// 动画行为：
  /// - 拖拽阶段：SizeTransition 跟手展开（_indicatorCtrl.value 直接映射偏移）
  /// - 刷新阶段：全高常驻，icon 持续旋转（_spinCtrl.repeat()）
  /// - 收起阶段：animateTo(0) 平滑收起
  Widget _buildRefreshIndicator(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return SizeTransition(
      // axisAlignment: -1.0 = 顶部对齐，从卡片底部向下展开
      axisAlignment: -1.0,
      sizeFactor: _indicatorCtrl,
      child: Container(
        // 背景色 = scaffold 底色：叠层模式下覆盖下方列表内容，
        // 使刷新常驻期间指示器不被列表透出
        color: Theme.of(context).scaffoldBackgroundColor,
        // Figma：垂直 padding 8px
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 刷新 icon：刷新期间自然旋转，拖拽阶段静止
            RotationTransition(
              turns: _spinCtrl,
              child: Icon(
                AppIcons.refresh,
                size: 12,
                color: primary,
              ),
            ),
            // Figma：icon 与文案间距 8px
            const SizedBox(width: 8),
            Text(
              // 刷新中显示"正在同步账本数据"；刷新完成后就地切换为结果文案（停留 1 秒）。
              _syncResultText ?? l10n.homeSyncing,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: primary,
                height: 16 / 12, // Figma lineHeight 16px / fontSize 12px
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理下拉会话结束（松手后 overscroll 回弹完毕或 ScrollEnd）。
  ///
  /// 判定逻辑：本次拖拽最大偏移 ≥ 阈值 → 触发刷新（指示器 animateTo 全高）；
  /// 否则 → 收起指示器（animateTo 0）。
  void _handlePullEnd() {
    final shouldRefresh = _maxPullOffsetThisDrag >= _kRefreshThreshold;
    _maxPullOffsetThisDrag = 0;
    _pullOffset = 0;
    _lastPullPixels = 0;
    if (shouldRefresh && !_isPulling) {
      // 确保指示器过渡到全高（阈值达标时通常已在 1.0，此处兜底平滑过渡）
      _indicatorCtrl.animateTo(1.0);
      _onRefresh();
    } else if (!_isPulling) {
      // 未达阈值：停止旋转 + 收起指示器
      _spinCtrl.stop();
      _indicatorCtrl.animateTo(0.0);
    }
  }

  Widget _buildPageView() {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    // PageView 启用原生跟手滚动：手指左右拖动时页面完全跟随手指位移（ViewPager 驱动模式）。
    // 横向手势由 PageView 接管，竖向手势下沉给列表，由手势竞技场自动分流，
    // 解决竖向列表滑动与横向月份切换的冲突（参考微信列表交互），禁止点击即切换或松手才动的生硬效果。
    // 外包统一水平内边距：让交易列表（及相邻页骨架屏）整体内缩，与头部卡片左右边缘对齐；
    // 仅收窄可视区，PageView 仍接管跟手切月手势，且阈值物理基于 viewportDimension 自适应，翻页逻辑不受影响。
    //
    // 关键架构：指示器以 Stack 叠层覆盖在 PageView 上方（Positioned top:0），
    // 而非放在 Column 中撑开布局。这样指示器高度变化完全不影响 PageView 的 viewport，
    // 避免了"指示器增长 → viewport 缩小 → BouncingScrollPhysics 修正 pixels → 回弹到 0 →
    // 结束下拉会话 → 指示器收起 → viewport 恢复"的反馈循环抖动。
    return Stack(
      children: [
        Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
        // ── 1. PageView 自身横向滚动（depth==0）──
        // 仅响应 PageView 自身的滚动结束，据此判定松手后视图落点，决定是否提交月份切换。
        if (notification is ScrollEndNotification && notification.depth == 0) {
          _onPageScrollSettled();
        }

        // ── 2. 内部列表竖向滚动（depth>0）──
        // 跟踪列表 overscroll 实现自定义下拉刷新指示器。
        // 仅在非刷新态（!_isPulling）时跟踪，避免刷新期间的滚动通知干扰指示器。
        if (notification.depth > 0 && !_isPulling) {
          if (notification is ScrollUpdateNotification) {
            final pixels = notification.metrics.pixels;
            if (pixels < 0) {
              // 列表顶部 overscroll（向下拉）
              // 区分"用户在拉"（pixels 变得更负）vs"松手回弹"（pixels 变得更接近 0）：
              // 仅用户主动下拉时更新指示器高度，回弹阶段冻结以避免指示器跟随回弹缩放。
              if (pixels <= _lastPullPixels) {
                _pullOffset = -pixels;
                // 跟踪本次拖拽的最大偏移（回弹后仍保留峰值用于阈值判定）
                if (_pullOffset > _maxPullOffsetThisDrag) {
                  _maxPullOffsetThisDrag = _pullOffset;
                }
                // 直接设值（非 animateTo），实现跟手展开
                _indicatorCtrl.value =
                    (_pullOffset / _kIndicatorHeight).clamp(0.0, 1.0);
                // 拉拽阶段即启动 icon 旋转，不等刷新确定才转
                if (!_spinCtrl.isAnimating) {
                  _spinCtrl.repeat();
                }
              }
              // else: 回弹阶段，不更新 _indicatorCtrl，让指示器停留在松手时的高度
            } else if (_maxPullOffsetThisDrag > 0) {
              // overscroll 回弹到 0 → 结束本次下拉会话
              _handlePullEnd();
            }
            _lastPullPixels = pixels;
          } else if (notification is ScrollEndNotification) {
            // 滚动完全停止 → 确保下拉会话结束（兜底：防止某些场景下
            // pixels 未精确回 0 就收到 ScrollEnd 导致会话悬挂）
            if (_maxPullOffsetThisDrag > 0) {
              _handlePullEnd();
            }
          }
        }

        return false;
      },
      child: PageView.builder(
        controller: _monthPager,
        // 高阈值翻页物理：松手时偏移超过屏宽 80% 才切到相邻页，否则回弹至中页，避免误触频繁刷新。
        physics: const _HighThresholdPagePhysics(),
        itemCount: 3,
        itemBuilder: (context, pageIndex) {
          // 相邻页（0=上月、2=下月）始终渲染骨架屏：
          // 拖动过程中作为"目标月份"占位（左侧当前月真实内容 + 右侧目标月骨架屏），模拟平滑加载；
          // 提交后通过 jumpToPage 重置回中页，由中页加载真实数据，相邻页保持骨架屏等待下一次滑动。
          if (pageIndex != _centerPageIndex) {
            return const _MonthSkeleton();
          }
          // 中页按 selectedMonth 渲染当前月份真实交易列表。
          final month = ref.watch(selectedMonthProvider);
          return _MonthPage(
            ledgerId: ledgerId,
            month: month,
            getStream: () => repo.transactionsWithCategoryAll(ledgerId: ledgerId),
            onEdit: (tx, cat) async {
              await TransactionEditUtils.editTransaction(
                context,
                ref,
                tx,
                cat,
              );
            },
            onDelete: (tx) async {
              // 设计稿删除确认:标题 + 含"分类名"的描述(恒定分类值,不用备注)
              final l10n = AppLocalizations.of(context);
              String categoryName = l10n.categoryEmpty;
              if (tx.categoryId != null) {
                final cat = await repo.getCategoryById(tx.categoryId!);
                if (cat != null && cat.name.isNotEmpty) {
                  // 在 await 之后使用 context,先做 mounted 校验避免跨异步间隙使用 BuildContext
                  if (!context.mounted) return;
                  categoryName = CategoryUtils.getDisplayName(cat.name, context);
                }
              }
              if (!context.mounted) return;
              final ok = await AppDialog.confirm<bool>(
                context,
                title: l10n.homeDeleteDetailTitle,
                message: l10n.homeDeleteDetailMessage(categoryName),
              );
              if (ok != true) return;
              await repo.deleteTransaction(tx.id);
              if (!context.mounted) return;
              ref.invalidate(countsForLedgerProvider(ledgerId));
              ref.read(statsRefreshProvider.notifier).state++;
              PostProcessor.sync(ref, ledgerId: ledgerId);
              if (context.mounted) showToast(context, l10n.ledgersDeleted);
            },
            onCategoryTap: (cat) async {
              // 点击分类图标跳到分类详情。
              ref.read(homeSwitchToStreamProvider.notifier).state++;
              if (!context.mounted) return;
              await Navigator.of(context).push(
                appPageRoute(
                  builder: (_) => CategoryDetailPage(
                    categoryId: cat.id,
                    categoryName: CategoryUtils.getDisplayName(cat.name, context),
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
        ),
        // 刷新指示器叠层（Figma 2035:81）：从列表顶部（卡片底部）向下展开。
        // 以 Positioned 覆盖在 PageView 上方，不影响列表 viewport。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildRefreshIndicator(context),
        ),
      ],
    );
  }
}

/// 头部汇总卡片:设计稿"本月支出汇总卡"(主色背景 + 白色文字 + 圆角 19px)。
///
/// 布局(Figma 53:6):
/// - 卡片内边距四边 20;内容自上而下:标题(本月支出) → 间距 10 → 主金额
///   (36px / Regular / 字距 -0.05em) → 间距 12 → 今日/本周小字。
/// - 账本徽章以 tab 形式挂在卡片右缘(半透明白底、仅左侧圆角 5),
///   与标题行纵向齐平,不内嵌占用标题行宽度。
/// - 整张卡片可点击 → 跳转账本管理页(点击热区大,符合拇指操作友好原则)。
/// - 今日/本周常驻展示(非当月金额显示为 -,保证切页时卡片高度固定不抖动)。
/// - 金额统一带主币种符号,且不以 + 号开头(为 0 时直接显示 0)。
class _HeaderSummary extends ConsumerWidget {
  final DateTime month;
  /// 整张卡片点击回调(由调用方决定跳转目标:有账本跳账本管理,无账本跳新建)。
  final VoidCallback onTapLedger;
  /// 账本显示名(已翻译/已回退到 ledgersNew)。
  final String ledgerName;
  /// 是否为无账本状态(无账本时只展示"新建账本"文字,语义和点击目标不同)。
  final bool isEmpty;

  const _HeaderSummary({
    required this.month,
    required this.onTapLedger,
    required this.ledgerName,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    // "今日/本周"天生指真实当前日/周,与所选查看月无关:仅当月显示真实数值,
    // 非当月金额显示为 "-" 占位。该行常驻不隐藏,确保切页时卡片高度固定。
    final isCurrentMonth =
        month.year == now.year && month.month == now.month;
    final ledgerId = ref.watch(currentLedgerIdProvider);
    // 当前账本本位币:徽章币种码与汇总金额符号的同一来源(折算基准 = 账本本位币)
    final currency =
        ref.watch(currentLedgerProvider).asData?.value?.currency ?? 'CNY';

    final params = (ledgerId: ledgerId, month: month);
    // 三个支出数据:本月 / 今日 / 本周,均走 last 缓存避免 loading 闪烁
    ref.watch(monthlyTotalsProvider(params));
    final monthCached = ref.watch(lastMonthlyTotalsProvider(params)) ?? 0.0;
    ref.watch(todayExpenseProvider(ledgerId));
    final todayCached = ref.watch(lastTodayExpenseProvider(ledgerId)) ?? 0.0;
    ref.watch(weekExpenseProvider(ledgerId));
    final weekCached = ref.watch(lastWeekExpenseProvider(ledgerId)) ?? 0.0;
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    // 今日/本周行次要文字统一样式:12px、主色 75% 透明(与主金额形成层次)。
    final dimStyle = TextStyle(
      fontSize: 12,
      color: onPrimary.withValues(alpha: 0.75),
    );
    // 局部辅助:渲染同色次要文字(标签 / 分隔符 / 占位 "-"),统一字号与颜色,
    // 避免重复书写同一 TextStyle。
    Text dim(String t) => Text(t, style: dimStyle);

    return Material(
      color: Colors.transparent,
      // 圆角与 Container 一致:避免 InkWell 水波纹在角落溢出圆角外。
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapLedger,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: primary, // shadcn primary 蓝底
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // Stack:内容列 + 右缘账本徽章 tab(UI稿徽章挂卡片右缘,不占标题行)。
          child: Stack(
            children: [
              Padding(
                // UI稿:卡片内边距四边 20
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题联动:当月显示"本月支出",非当月显示"X月支出"
                    // (与可视月份实时绑定)。标题始终很短,不会与右缘徽章重叠。
                    Text(
                      isCurrentMonth
                          ? l10n.homeMonthExpense
                          : l10n.homeMonthExpenseOf(month.month.toString()),
                      style: TextStyle(
                        fontSize: 14,
                        color: onPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                    // UI稿:标题与主金额间距 10
                    const SizedBox(height: 10),
                    // 主金额:36px、Regular、带主币种符号、无 + 号。
                    // 复用全局金额组件 AmountText:字距走主题默认(0),与全站金额口径统一,
                    // 不硬编码负值导致数字相互紧贴。
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AmountText(
                        value: monthCached,
                        showCurrency: true,
                        currencyCode: currency,
                        signed: false,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w400,
                          color: onPrimary,
                        ),
                      ),
                    ),
                    // UI稿:主金额与今日/本周间距 12
                    const SizedBox(height: 12),
                    // 今日/本周,常驻渲染(卡片三行结构固定,高度不随切页变化)。
                    // 当月显示真实数值;非当月没有对应"今日/本周"语义,金额以 "-" 占位。
                    // 拆成 Row(标签 + AmountText 金额 + 分隔符):复用全局金额组件,
                    // 避免把金额硬拼进单一字符串而绕开 AmountText。整行 FittedBox
                    // 等比缩小兜底极端窄屏(完整可读)。
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          dim(l10n.homeTodayExpense),
                          const SizedBox(width: 4),
                          dim('·'),
                          const SizedBox(width: 4),
                          isCurrentMonth
                              ? AmountText(
                                  value: todayCached,
                                  showCurrency: true,
                                  currencyCode: currency,
                                  signed: false,
                                  style: dimStyle,
                                )
                              : dim('-'),
                          const SizedBox(width: 4),
                          dim('|'),
                          const SizedBox(width: 4),
                          dim(l10n.homeWeekExpense),
                          const SizedBox(width: 4),
                          dim('·'),
                          const SizedBox(width: 4),
                          isCurrentMonth
                              ? AmountText(
                                  value: weekCached,
                                  showCurrency: true,
                                  currencyCode: currency,
                                  signed: false,
                                  style: dimStyle,
                                )
                              : dim('-'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 账本徽章 tab:挂卡片右缘(top 20 与标题行齐平,right 0 贴边)。
              // 底色沿用 token 体系内"主色之上的白"(onPrimary 0.18,与空态图标底
              // 同一透明度),仅左侧圆角 5 —— 对应 UI稿的右缘 tab 形态,但不引入
              // UI稿的具体灰色值,保证亮暗主题一致。
              Positioned(
                top: 20,
                right: 0,
                child: Container(
                  // UI稿徽章内边距:左 7 / 上 6 / 右 8 / 下 6(上下加大以增高色块)
                  padding: const EdgeInsets.fromLTRB(7, 6, 8, 6),
                  decoration: BoxDecoration(
                    color: onPrimary.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(5)),
                  ),
                  child: _LedgerEntryInCard(
                    ledgerName: ledgerName,
                    currencyCode: currency,
                    onPrimary: onPrimary,
                    isEmpty: isEmpty,
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

/// 汇总卡片右缘 tab 内的账本徽章:币种名称 + 账本名 + 右箭头。
/// - 徽章只承担「当前账本 + 本位币」展示,不承担切币;
///   onTap 不在此处:整张卡片已经可点击进入账本。
/// - Row 用 mainAxisSize.min 让 tab 宽度随内容收缩贴右缘;账本名用
///   ConstrainedBox 限宽 96、超出省略号,避免长名把 tab 顶穿卡片左半区。
/// - 无账本态保持原「合作圈 + 新建账本」引导样式。
class _LedgerEntryInCard extends StatelessWidget {
  final String ledgerName;
  final String currencyCode;
  final Color onPrimary;
  final bool isEmpty;

  const _LedgerEntryInCard({
    required this.ledgerName,
    required this.currencyCode,
    required this.onPrimary,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      // 无账本:半透明白圆合作图标 + "新建账本"引导,保持视觉一致性
      final iconBg = onPrimary.withValues(alpha: 0.18);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBg,
            ),
            alignment: Alignment.center,
            child: Icon(AppIcons.people, size: 13, color: onPrimary),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(
              ledgerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onPrimary,
              ),
            ),
          ),
        ],
      );
    }

    // 有账本:币种 ISO 代码 + 账本名。
    // 设计意图:徽章仅展示币种 ISO 代码(不展示名称/符号),与账本名同色(onPrimary),
    // 因徽章底色是主色之上的半透明白(onPrimary 0.18),用 onSurface 在蓝底上会发暗、
    // 与账本名颜色不一致,故两者统一用 onPrimary 保证视觉一致。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          currencyCode.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: onPrimary,
          ),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: Text(
            ledgerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}



/// 单月页：单月交易 stream + 骨架屏。
class _MonthPage extends ConsumerStatefulWidget {
  final int ledgerId;
  final DateTime month;
  final Stream<List<({Transaction t, Category? category})>> Function()
      getStream;
  final Future<void> Function(Transaction, Category?) onEdit;
  final Future<void> Function(Transaction) onDelete;
  final Future<void> Function(Category) onCategoryTap;

  const _MonthPage({
    required this.ledgerId,
    required this.month,
    required this.getStream,
    required this.onEdit,
    required this.onDelete,
    required this.onCategoryTap,
  });

  @override
  ConsumerState<_MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends ConsumerState<_MonthPage> {
  late final FlutterListViewController _listCtrl;
  // 缓存上一次成功的成员表;刷新(重新 loading)期间复用,避免头像/首字母闪烁。
  Map<String, SpitoutCloudLedgerMember>? _cachedMemberMap;
  // 缓存交易流：避免每次 build 都新建流（Drift 的 watch() 每次 new StreamController），
  // 否则 StreamBuilder 重新订阅时 snapshot.data 会短暂为 null → 渲染 _MonthSkeleton（灰色长方块）。
  // 流引用固定后，成员/账本 provider 变化触发的普通 rebuild 不会重新订阅，从而避免灰屏。
  Stream<List<({Transaction t, Category? category})>>? _txStream;

  @override
  void initState() {
    super.initState();
    _listCtrl = FlutterListViewController();
    // 首次进入即创建流并缓存到 State；之后所有 rebuild 复用同一引用，不重新订阅。
    // getStream 是 _MonthPage 持有、在 HomePage 创建时捕获了 repo 的闭包，
    // 内部仅依赖 widget.ledgerId/widget.month（均为 final），initState 时已就绪，安全。
    _txStream = widget.getStream();
  }

  @override
  void didUpdateWidget(covariant _MonthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅当账本或月份变化时重建流；成员/账本 provider 变化触发的普通 rebuild 复用旧引用。
    // didUpdateWidget 在 build 之前调用，保证「先换流、再 build 传新引用」无空窗。
    if (oldWidget.ledgerId != widget.ledgerId ||
        oldWidget.month != widget.month) {
      _txStream = widget.getStream();
    }
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final period = periodForLabel(
      month.year,
      month.month,
      ref.watch(currentMonthStartDayProvider),
    );
    // 仅展示当月数据：在 Repository 上过滤后传 list（保留 join 性能），
    // 单纯 client 过滤是 O(n) 但单月量级可控，避免再加一个 family provider。
    // ref.watch 上提到 StreamBuilder 之前（独立清理）：成员/账本 provider 变化只触发
    // _MonthPage 整体 rebuild，build 重跑时 memberMap 照常重算、头像实时更新，
    // 不依赖 StreamBuilder.builder 闭包内的 watch。
    final ledger = ref.watch(currentLedgerProvider).asData?.value;
    // 整张成员表透传(含 avatarUrl/displayName),供列表项渲染真实头像 + 重叠,
    // 保证首页头像与详情页一致。
    Map<String, SpitoutCloudLedgerMember>? memberMap;
    if (ledger != null &&
        ledger.isShared &&
        ledger.syncId != null &&
        ledger.syncId!.isNotEmpty) {
      final members = ref.watch(ledgerMembersProvider(ledger.syncId!));
      final loaded = members.asData?.value;
      if (loaded != null) {
        // 注意：fold 的种子必须是可变 Map 字面量，不能用 const {}。
        // const {} 在 Dart 中是 unmodifiable Map，回调里 m[...] = ... 写入会抛
        // UnsupportedError（"Cannot set value in an unmodifiable Map"）。
        // 只要成员列表非空、回调执行一次就会崩，故使用 <String, SpitoutCloudLedgerMember>{} 作为可写种子。
        memberMap = loaded.fold<Map<String, SpitoutCloudLedgerMember>>(
            <String, SpitoutCloudLedgerMember>{}, (m, mem) {
          m[mem.userId] = mem;
          return m;
        });
        // 加载成功则缓存,供刷新(重新进入 loading)时复用,保持头像/首字母稳定不闪。
        _cachedMemberMap = memberMap;
      } else if (_cachedMemberMap != null) {
        // 刷新/重连期间成员表短暂为 loading:复用上一次快照,避免头像先闪错误首字母再切正确。
        memberMap = _cachedMemberMap!;
      }
    }
    return StreamBuilder<List<({Transaction t, Category? category})>>(
      key: ValueKey('month_${widget.ledgerId}_${month.year}_${month.month}'),
      // 复用缓存的流引用：rebuild 不重新订阅，memberMap 实时刷新但交易流不丢、不灰屏。
      stream: _txStream!,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const [];
        // 过滤成单月：period.start ≤ tx.happenedAt < period.end
        final monthItems = all.where((it) {
          final t = it.t.happenedAt;
          return !t.isBefore(period.start) && t.isBefore(period.end);
        }).toList();

        // 数据流尚未发射时显示骨架屏占位：切月重置后中页重新订阅流，
        // 首帧无数据 → 骨架屏，避免空状态闪烁；数据到达后自动替换为真实列表。
        if (!snapshot.hasData) {
          return const _MonthSkeleton();
        }

        // 空表也走 TransactionList —— useExternalRefresh 模式下
        // 空表返回可滚动容器包裹 AppEmpty，支持"空表下拉刷新"。
        // 直接 return AppEmpty 会绕过下拉刷新,空账本场景下用户无法拉云端数据。
        // 共享账本成员映射(userId→displayName):列表项头像 + 详情 Sheet 协作成员
        // （ledger / memberMap 已上提到 build 外层计算，此处直接复用）
        return TransactionList(
          transactions: monthItems,
          controller: _listCtrl,
          emptyWidget: AppEmpty(
            text: AppLocalizations.of(context).homeNoRecords,
            subtext: AppLocalizations.of(context).homeNoRecordsSubtext,
          ),
          memberDisplayMap: memberMap,
          isShared: ledger?.isShared ?? false,
          // 首页使用外部自定义下拉刷新指示器（Figma 2035:81），
          // 不使用内置 RefreshIndicator；onRefresh 由 HomePage 的 NotificationListener 驱动。
          useExternalRefresh: true,
          // 列表点击 → 打开记录详情 Sheet(非直接编辑);详情内编辑/删除走原子回调
          onEdit: (tx, cat) async {
            await showTransactionDetailSheet(
              context: context,
              transaction: tx,
              category: cat,
              memberDisplayMap: memberMap ?? const {},
              // 本地账本无成员表:传本地昵称供详情页兜底展示(纯本地,不依赖云端登录态)
              localOwnerDisplayName: (ledger?.isShared ?? false)
                  ? null
                  : ref.read(displayNameProvider),
              // 账本是否开启分摊决定底部按钮态(单/双)与右上角删除 icon 布局
              aaEnabled: ledger?.aaEnabled ?? false,
              onEdit: () => widget.onEdit(tx, cat),
              // 编辑分摊入口:仅开启分摊时使用,跳 AaEditPage 直接落库 AA 字段
              onEditAa: () => TransactionAaEditUtils.editTransactionAa(
                context,
                ref,
                tx,
                cat,
              ),
              onDelete: () => widget.onDelete(tx),
            );
          },
          onDelete: widget.onDelete,
          onCategoryTap: widget.onCategoryTap,
        );
      },
    );
  }
}

/// 单月骨架屏：8 条 SkeletonListTile + 暗色 friendly 颜色。
class _MonthSkeleton extends StatelessWidget {
  const _MonthSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: 8,
      itemBuilder: (_, __) => const PulseSkeleton(child: SkeletonListTile()),
    );
  }
}

/// 高阈值翻页物理：松手时仅当偏移量超过屏宽 80% 才切到相邻页，否则回弹至中页。
///
/// 设计意图：三屏 PageView 始终以中页（index 1）为基准，用户拖动跟手，
/// 松手后通过本物理决定落点——避免常规 50% 阈值导致的误触频繁刷新。
/// 判定相对中页的偏移 frac（页单位 = 屏宽）：
///   frac >= 0.8 → 切到下月（page 2）；frac <= -0.8 → 切到上月（page 0）；其余回弹中页。
class _HighThresholdPagePhysics extends PageScrollPhysics {
  const _HighThresholdPagePhysics({super.parent});

  @override
  _HighThresholdPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _HighThresholdPagePhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // overscroll(超出 [minScrollExtent, maxScrollExtent])时弹回中页(page 1),
    // 而非交给父级 PageScrollPhysics 弹回边界页(page 0/2)。
    // 设计意图:三页 PageView 以中页为基准,左/右页仅为滑动占位;用户在边界页
    // 继续同向拖动产生的 overscroll 不应停留在边界页——否则弹回结束的
    // ScrollEndNotification 中 page=0/2,会触发 _onPageScrollSettled 误切月
    // (用户并未真正翻页,只是橡皮筋回弹)。弹回中页则 page=1,不触发切月。
    if (position.pixels < position.minScrollExtent ||
        position.pixels > position.maxScrollExtent) {
      final double dim = position.viewportDimension;
      if (dim <= 0) return null;
      final double target = 1.0 * dim; // 中页
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: toleranceFor(position),
      );
    }
    final tolerance = toleranceFor(position);
    final double dim = position.viewportDimension;
    if (dim <= 0) return null;
    // 相对中页的偏移（页单位 = 屏宽）：正值=向下月方向，负值=向上月方向。
    final double frac = (position.pixels / dim) - 1.0;
    final double targetPage;
    if (frac >= 0.8) {
      targetPage = 2.0;
    } else if (frac <= -0.8) {
      targetPage = 0.0;
    } else {
      targetPage = 1.0;
    }
    final double target = targetPage * dim;
    if ((target - position.pixels).abs() <= tolerance.distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}