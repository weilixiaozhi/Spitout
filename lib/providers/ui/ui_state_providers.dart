import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';

import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/maintenance/maintenance_providers.dart';
import 'package:spitout/providers/ui/theme_providers.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/providers/statistics/statistics_providers.dart';
import '../../data/db.dart';
import '../../utils/date/month_range.dart';
import '../../services/data/recurring_transaction_service.dart';
import 'package:spitout/providers/core/post_processor.dart';
import '../../core/logging/logger_service.dart';
import 'package:spitout/providers/security/security_providers.dart';
import 'package:spitout/providers/core/refresh_ticks.dart';

// homeSwitchToStreamProvider / TransactionDisplayItem / cachedTransactionsProvider
// 定义于叶子模块 refresh_ticks.dart（sync_providers 的同步编排也要写它们），
// 此处 re-export 供消费方（transaction_list / home_page 等）统一引用。
export 'package:spitout/providers/core/refresh_ticks.dart';

// 底部导航索引（0: 明细, 3: 我的；1/2 为占位）
final bottomTabIndexProvider =
    NotifierProvider<SimpleStateNotifier<int>, int>(
  () => SimpleStateNotifier((ref) => 0),
);

// 首页滚动到顶部触发器（每次改变值时触发滚动）
final homeScrollToTopProvider =
    NotifierProvider<TickStateNotifier, int>(() => TickStateNotifier((ref) => 0));

// Currently selected month (first day), default to now
final selectedMonthProvider =
    NotifierProvider<SimpleStateNotifier<DateTime>, DateTime>(() {
  return SimpleStateNotifier((ref) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  });
});

// 应用初始化状态
enum AppInitState {
  splash, // 显示启屏页
  loading, // 正在初始化
  ready // 初始化完成，显示主应用
}

// 应用初始化状态Provider
final appInitStateProvider =
    NotifierProvider<SimpleStateNotifier<AppInitState>, AppInitState>(
  () => SimpleStateNotifier((ref) => AppInitState.splash),
);

// 应用初始化Provider - 管理数据预加载
final appSplashInitProvider = FutureProvider<void>((ref) async {
  const tag = 'Splash';
  logger.info(tag, '开始启屏页预加载');
  final startTime = DateTime.now();
  var stepTime = startTime;

  try {
    // 确保基础providers已初始化
    logger.info(tag, '初始化基础配置...');
    await Future.wait([
      ref.watch(themeModeInitProvider.future),
      ref.watch(appInitProvider.future),
      ref.watch(expenseColorSchemeInitProvider.future),

      ref.watch(displayNameInitProvider.future),
      ref.watch(securityInitProvider.future),
      // 可见币种集合初始化(内部等待当前账本就绪后加载其专属集合,
      // 与此处并行安全)
      ref.watch(visibleCurrenciesInitProvider.future),
    ]);
    logger.info(tag, '基础配置初始化完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms');
    stepTime = DateTime.now();

    // 一次性修复共享账本历史脏数据（旧版 pull 把 Owner 分类错绑到成员本地分类）
    try {
      await ref.watch(sharedLedgerCategoryRepairRunProvider.future);
    } catch (e, st) {
      logger.error(tag, '共享账本分类历史修复执行失败', e, st);
    }

    // 获取 repository
    final repo = ref.read(repositoryProvider);

    // 预加载当前账本的关键数据
    final ledgerId = ref.read(currentLedgerIdProvider);
    final now = DateTime.now();
    // 月份周期标签:startDay>1 时今天可能属于「上个标签月」(如 6月5日属 5月周期)
    final ledgerRow = await repo.getLedgerById(ledgerId);
    final startDay = (ledgerRow?.monthStartDay ?? 1).clamp(1, 28);
    final currentMonth = labelForDate(now, startDay);
    ref.read(selectedMonthProvider.notifier).set(currentMonth);

    // 并行预加载：月度统计 + 交易列表（分别计时）
    final monthlyParams = (ledgerId: ledgerId, month: currentMonth);

    // 包装每个任务以记录各自耗时
    Future<T> timed<T>(String name, Future<T> future) async {
      final start = DateTime.now();
      final result = await future;
      logger.info(tag, '$name: ${DateTime.now().difference(start).inMilliseconds}ms');
      return result;
    }

    // 首屏预加载条数限制（只加载前 N 条，加快启动速度）
    const preloadLimit = 20;

    final results = await Future.wait([
      timed('月度统计', ref.read(monthlyTotalsProvider(monthlyParams).future)),
      // 只查询前 N 条，而非全部
      timed('交易列表(前$preloadLimit条)', repo.getRecentTransactionsWithCategory(ledgerId: ledgerId, limit: preloadLimit)),
    ]);

    final monthlyResult = results[0] as double;
    final transactionsWithCategory = results[1] as List<({Transaction t, Category? category})>;

    ref.read(lastMonthlyTotalsProvider(monthlyParams).notifier).set(monthlyResult);
    // 不预加载完整列表，让 Stream 自己加载
    logger.info(tag, '并行预加载完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms, 首屏${transactionsWithCategory.length}条');

    // 组装完整的交易展示数据
    final fullTransactions = transactionsWithCategory.map((item) {
      return (t: item.t, category: item.category);
    }).toList();

    ref.read(cachedTransactionsProvider.notifier).set(fullTransactions);

    // 账本统计异步加载（不阻塞启动）
    Future.microtask(() async {
      final start = DateTime.now();
      await ref.read(countsForLedgerProvider(ledgerId).future);
      logger.info(tag, '账本统计(异步): ${DateTime.now().difference(start).inMilliseconds}ms');
    });

    // 周期交易生成放到启动后异步执行：内部是「账本×模板×每笔」的 N+1 查询，
    // 同步等待会拖长首屏。改为 fire-and-forget，完成后统一走 PostProcessor
    // 刷新 + 触发同步（同步本身由数据变更驱动的 Coordinator 下沉，不依赖 UI）。
    unawaited(Future.microtask(() async {
      try {
        // 微任务执行时重新解析仓库，避免捕获到启动阶段可能已失效的旧实例。
        final freshRepo = ref.read(repositoryProvider);
        final generatedLedgerIds =
            await RecurringTransactionService.generatePendingTransactionsStatic(
          repository: freshRepo,
          verbose: false,
        );
        if (generatedLedgerIds.isNotEmpty) {
          logger.info(tag,
              '周期交易生成完成(启动后异步): ${generatedLedgerIds.length} 本账本');
        }

        // 统一后处理：刷新UI + 触发云同步（如果有生成交易）
        for (final genLedgerId in generatedLedgerIds) {
          await PostProcessor.runR(ref, ledgerId: genLedgerId);
        }
      } catch (e, stackTrace) {
        logger.error(tag, '周期交易生成失败', e, stackTrace);
      }
    }));
  } catch (e, stackTrace) {
    logger.error(tag, '预加载数据失败', e, stackTrace);
  }

  // 计算数据预加载耗时
  final dataLoadTime = DateTime.now().difference(startTime);
  logger.info(tag, '预加载总耗时: ${dataLoadTime.inMilliseconds}ms，切换到主应用');
  ref.read(appInitStateProvider.notifier).set(AppInitState.ready);
});

// 是否应该显示欢迎页面的Provider
final shouldShowWelcomeProvider =
    NotifierProvider<SimpleStateNotifier<bool>, bool>(
  () => SimpleStateNotifier((ref) => false),
);

// 初始化检查是否需要显示欢迎页面
final welcomeCheckProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final welcomeShown = prefs.getBool('welcome_shown') ?? false;
  if (!welcomeShown) {
    debugPrint('👋 首次启动，需要展示欢迎页面');
    ref.read(shouldShowWelcomeProvider.notifier).set(true);
    return true;
  }
  return false;
});
