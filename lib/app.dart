import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/calendar/calendar_page.dart';

import 'pages/main/analytics_page.dart';
import 'pages/main/home_page.dart';
import 'pages/main/mine_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'l10n/app_localizations.dart';
import 'widgets/widgets.dart';
import 'services/security/app_lock_service.dart';
import 'theme/colors.dart';
import 'theme/icons/app_icons.dart';
import 'theme/shadows.dart';

// 中间记账 FAB 凸出底部胶囊顶部的高度(dp)。
// 底部栏总高 = 胶囊高度(64) + 本值 + 安全区 + 浮动间距：把 FAB 凸出量收编进
// 底部栏自身高度，使整个 FAB 落在 Stack bounds 内、全部可命中。
const double _kCenterFabOverflow = 25.0;

// 底部胶囊高度(dp)，扩大 tab 可点击区。
const double _kBarHeight = 64.0;

class SpitoutApp extends ConsumerStatefulWidget {
  const SpitoutApp({super.key});

  @override
  ConsumerState<SpitoutApp> createState() => _SpitoutAppState();
}

class _SpitoutAppState extends ConsumerState<SpitoutApp>
    with WidgetsBindingObserver {
  // 底部四个有效 tab：明细(0) / 统计(1) / 日历(2) / 我的(3)。
  // index 编号保持稳定，login_page / bottomTabIndexProvider 的引用关系无需改动。
  final _pages = const [
    HomePage(), // index 0: 明细
    AnalyticsPage(), // index 1: 统计（新增一级入口）
    CalendarPage(), // index 2: 日历（新增一级入口）
    MinePage(), // index 3: 我的
  ];

  // 双击检测：记录最后一次点击的时间和索引
  DateTime? _lastTapTime;
  int? _lastTappedIndex;

  // 双击返回退出：记录最后一次返回键按下时间
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 后台刷新账本同步状态 / 触发首次同步：经 AppStartupSync 统一触发
    // （TransactionsSyncManager 快照刷新 + SyncEngine 账户级首次同步）。
    ref.read(appStartupSyncProvider).start();

    // 预热记账页分类树缓存：provider 非 autoDispose，读一次即常驻。
    // 让 FAB 打开记账 sheet 时分类区首帧同步命中缓存，避免首帧"从无到有"。
    Future.microtask(() {
      ref.read(categoryPickerTreeProvider('expense'));
    });

    // 冷启动自动本地备份：didChangeAppLifecycleState 冷启动时不回调（初始即
    // resumed，无状态变化），若只挂 resumed 会漏掉"每天首次打开"这个最主要
    // 场景，故此处补挂一次；内部按天去重，与 resumed 触发天然幂等。
    Future.microtask(() => autoBackupOnLaunch(ref.read));

  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive) {
      // 多任务切换时显示隐私模糊屏（仅在应用锁启用时）
      if (ref.read(appLockEnabledProvider)) {
        ref.read(showPrivacyScreenProvider.notifier).set(true);
      }
    } else if (state == AppLifecycleState.paused) {
      // 记录进入后台时间
      AppLockService.recordBackgroundTime();
    } else if (state == AppLifecycleState.resumed) {
      // 移除隐私模糊屏
      ref.read(showPrivacyScreenProvider.notifier).set(false);
      // 检查是否需要锁定
      _checkAppLockOnResume();
      // 切回前台时尝试一次自动本地备份（按天去重：开关关闭或当天已备份则内部直接跳过）
      unawaited(autoBackupOnLaunch(ref.read));
    }
  }

  Future<void> _checkAppLockOnResume() async {
    final shouldLock = await AppLockService.shouldLockOnResume();
    if (shouldLock && mounted) {
      ref.read(isAppLockedProvider.notifier).set(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod 3 起，仅被 read 一次的 provider 会被暂停，其内部 ref.listen 副作用
    // 随之失效（账本持久化/自愈、启动同步监听等）。在常驻根组件持续 watch，
    // 保证这些监听器在整个 App 生命周期内保持活跃。
    ref.watch(currentLedgerPersistProvider);
    ref.watch(ledgerChangeListenerProvider);
    ref.watch(appStartupSyncProvider);
    final idx = ref.watch(bottomTabIndexProvider);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;


    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;

        // 返回手势拦截：非首页 Tab（如"我的"）触发返回时，
        // 强制切回首页 Tab 而非退出应用，避免误退到桌面。
        // 仅当已在首页 Tab 时才保留"再按一次退出"的双击确认逻辑。
        final currentIdx = ref.read(bottomTabIndexProvider);
        if (currentIdx != 0) {
          ref.read(bottomTabIndexProvider.notifier).set(0);
          return;
        }

        final now = DateTime.now();

        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          showToast(context, l10n.commonPressAgainToExit);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            // body 命中盒在底部栏顶部截止，栏下方再无 body widget，消除 body
            // 滚动识别器与底部栏按钮(FAB/明细/我的)的指针竞争。
            extendBody: false,
            // 底部栏已把 FAB 凸出量收编进自身高度，body 无需为 FAB 让位，可用净高度不变。
            body: IndexedStack(
              index: idx,
              children: _pages,
            ),
            bottomNavigationBar: SpitoutBottomBar(
              currentIndex: idx,
              isDark: isDark,
              bottomPadding: bottomPadding,
              l10n: l10n,
              onTabTap: (index) {
                final now = DateTime.now();
                if (_lastTappedIndex == index &&
                    _lastTapTime != null &&
                    now.difference(_lastTapTime!) <
                        const Duration(milliseconds: 300)) {
                  if (index == 0) {
                    ref.read(homeScrollToTopProvider.notifier).tick();
                  }
                  _lastTapTime = null;
                  _lastTappedIndex = null;
                } else {
                  _lastTapTime = now;
                  _lastTappedIndex = index;
                  ref.read(bottomTabIndexProvider.notifier).set(index);
                }
              },
              onCenterTap: () {
                // 记账:弹出单页 BottomSheet(分类 + 金额 + 备注同页)
                showTransactionEditorSheet(
                  context,
                  initialKind: 'expense',
                );
              },
            ),
          ),
          // 开发模式下的主题切换按钮
          if (kDebugMode)
            Positioned(
              right: 16,
              bottom: 100,
              child: FloatingActionButton.small(
                heroTag: 'themeSwitcher',
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                onPressed: () {
                  final current = ref.read(themeModeProvider);
                  final next = current == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                  ref.read(themeModeProvider.notifier).set(next);
                },
                child: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? AppIcons.lightMode
                      : AppIcons.darkMode,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 底部导航栏：左起「明细 / 统计」，右起「日历 / 我的」四个有效 tab，
/// 中间凸起一个永远浮在导航栏中央的圆形黑色记账按钮（不参与选中判定）。
///
/// 结构：栏高 = 胶囊(64) + FAB 凸出量(_kCenterFabOverflow) + 安全区 + 浮动间距，
/// FAB 与胶囊都在 Stack bounds 内绘制，保证 FAB 整个区域（含凸出胶囊的上半截）
/// 都可命中 —— public 以便 widget 测试直接覆盖该命中回归。
class SpitoutBottomBar extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final double bottomPadding;
  final AppLocalizations l10n;
  final ValueChanged<int> onTabTap;
  final VoidCallback onCenterTap;

  const SpitoutBottomBar({
    super.key,
    required this.currentIndex,
    required this.isDark,
    required this.bottomPadding,
    required this.l10n,
    required this.onTabTap,
    required this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    // 颜色统一从 Design Token 系统读取（单一真相源）
    final primaryColor = SpitoutTokens.primary(context);
    final bgColor = SpitoutTokens.tabBarBackground(context);
    final inactiveColor = SpitoutTokens.iconSecondary(context);

    // 底部胶囊栏高，让明细/我的的可点击区更大。
    const barHeight = _kBarHeight;

    return SizedBox(
      // 栏高把 FAB 凸出量(_kCenterFabOverflow)收编进来，整个 FAB(含凸出
      // 胶囊的上半截)都落在可命中区域内，不会凸出 Stack。
      height: barHeight + _kCenterFabOverflow + bottomPadding + 12, // 12dp 浮动间距
      child: Padding(
        padding: EdgeInsets.only(
          left: SpitoutDimens.p16,
          right: SpitoutDimens.p16,
          bottom: bottomPadding + SpitoutDimens.p12,
        ),
        // Stack：下层放贴底、收缩居中的胶囊(含两个 tab)，上层放中心记账按钮
        child: Stack(
          children: [
        // 胶囊贴底、占满可用宽度；四个 tab 用 Expanded 等分整条胶囊。Positioned
        // (left:0,right:0) 给的是紧约束，若内容收缩到最小宽度，英文长标签
        // (Statistics) 会超出屏宽并向右溢出、挤出右侧 tab、把 FAB 压在文字上，
        // 故用等分保证内容永不溢出、FAB 永远居中于缺口。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: Container(
              height: barHeight,
              padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(SpitoutDimens.radius28),
                boxShadow: SpitoutTokens.tabBarShadow,
              ),
              child: Row(
                // 四个 tab 用 Expanded 等分整条胶囊宽度，统计与日历之间留 64dp
                // 固定缺口容纳中央 FAB。等分保证：无论何种语言/屏宽，FAB 永远
                // 居中于缺口、四个 tab 左右对称；英文长标签(Statistics/Calendar)
                // 也能在等分槽内完整显示，根除横向溢出与 FAB 遮挡文字的 bug。
                children: [
                  _buildTab(context, 0, AppIcons.receipt, l10n.tabHome,
                      inactiveColor, primaryColor),
                  _buildTab(context, 1, AppIcons.pieChart, l10n.tabAnalytics,
                      inactiveColor, primaryColor),
                  const SizedBox(width: 64), // 中央 FAB 缺口(FAB 直径 56，留 4dp 余量)
                  _buildTab(context, 2, AppIcons.calendarMonth, l10n.tabCalendar,
                      inactiveColor, primaryColor),
                  _buildTab(context, 3, AppIcons.person, l10n.tabMine,
                      inactiveColor, primaryColor),
                ],
              ),
            ),
          ),
        ),
            // 上层：顶部对齐、凸出胶囊 _kCenterFabOverflow 的圆形记账按钮
            // （不参与 index 判定）。整个 FAB 都在 Stack bounds 内，命中无死区。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _buildCenterFab(context)),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部 tab：图标在上、文字在下（垂直布局）。
  ///
  /// 垂直布局：横向 Icon+Text 时，英文长标签(Statistics/Calendar)会让单个
  /// tab 宽度远超中文 2 字，撑破胶囊(溢出屏幕)或使 FAB 压在 Statistics
  /// 文字上。垂直布局下标签宽度不挤压水平空间，长英文也能在 Expanded 等分槽内
  /// 完整显示；配合等分 Row 保证 FAB 永远居中、四 tab 对称。
  /// 选中仅图标与文字变色；整块 SizedBox 经 GestureDetector 稳定命中。
  Widget _buildTab(BuildContext context, int index, IconData icon, String label,
      Color inactiveColor, Color primaryColor) {
    final isActive = index == currentIndex;
    final color = isActive ? primaryColor : inactiveColor;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabTap(index),
        child: SizedBox(
          height: _kBarHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: SpitoutDimens.icon22),
              const SizedBox(height: SpitoutDimens.p4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: SpitoutTextTokens.caption(context).copyWith(color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 中间凸起的圆形记账按钮。亮色黑底白「+」，暗色白底黑「+」，
  /// 永远不变色（不参与 currentIndex 选中态）。
  Widget _buildCenterFab(BuildContext context) {
    // 反色设计：亮底黑按钮 / 暗底白按钮，统一走 Design Token
    final fabBg = SpitoutTokens.surfaceInverse(context);
    final fabIcon = SpitoutTokens.onSurfaceInverse(context);
    // 用 HitTestBehavior.opaque 让整个 56×56 区域（含圆形 Container 的透明背景）
    // 都参与命中测试，解决默认 deferToChild 下只有 Icon 字形可点的问题
    // （代价是四角死角也会响应）。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCenterTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: fabBg,
          shape: BoxShape.circle,
          boxShadow: SpitoutShadows.fab,
        ),
        child: Icon(AppIcons.add, color: fabIcon, size: SpitoutDimens.icon28),
      ),
    );
  }
}
