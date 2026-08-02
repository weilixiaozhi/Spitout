import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db.dart' show Ledger;
import '../../data/repositories/base_repository.dart';
import '../../core/logging/logger_service.dart';
import '../../utils/currency/rate_math.dart';
import '../../services/currency/exchange_rate_service.dart';
import '../../utils/currency/currencies.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/statistics/statistics_providers.dart';
// 只依赖叶子模块拿云客户端实例（server 汇率源），不 import 编排器
// sync_providers.dart，避免「域 → 编排」反向边成环。
import 'package:spitout/providers/sync/cloud_client_providers.dart';

/// 多币种 provider 层。
///
/// 折算基准 = 账本本位币(`ledger.currency`),[currentLedgerCurrencyProvider]
/// 为唯一来源;无「全局主币种(baseCurrency)」双轨制。

/// 汇率数据变更信号:拉取成功 / 手动编辑后 bump,触发 effectiveRates 重算。
final rateRefreshTickProvider = StateProvider<int>((ref) => 0);

final exchangeRateServiceProvider =
    Provider<ExchangeRateService>((ref) => ExchangeRateService());

/// 可见币种集合(用户在「管理展示币种」页勾选的币种,大写 ISO code)。
///
/// 设计意图:全量 146 个币种在选择列表里过长,用户只需维护一个「常用子集」,
/// 该集合仅影响 UI 展示范围(汇率列表、各币种选择弹窗),不影响 API 拉取与
/// 交易数据——API 全量拉取全量存储,交易保留原币种码。
///
/// 语义(账本维度化后):**当前账本**的可见集合——每账本一套,纯本地偏好,
/// 不走云同步(决策 P3);默认值 = [kCommonCurrencyCodes](13 个常用币种)
/// ∪ {该账本本位币},由 [visibleCurrenciesInitProvider] 初始化并即时落盘。
final visibleCurrenciesProvider = StateProvider<Set<String>>(
  (ref) => kCommonCurrencyCodes.toSet(),
);

/// 可见币种持久化 key:每账本一套(`visibleCurrencies.<ledgerId>`),
/// 值为逗号分隔的大写币种码,如 "CNY,USD,EUR,JPY,..."。
/// 用本地 ledgerId(纯本地偏好,无需跨设备稳定;删账本时同步清理该 key)。
String visibleCurrenciesKeyFor(int ledgerId) => 'visibleCurrencies.$ledgerId';

/// 无账本时的兜底持久化 key:保持「toggle 即落盘」行为一致,
/// 避免无账本态的勾选在重启后丢失。
const _kVisibleCurrenciesFallbackKey = 'visibleCurrencies._none';

/// 启动初始化:等当前账本就绪 → 加载其 key(无则默认 13 常用 ∪ 本位币并
/// 落盘) → listen 当前账本 id 变化重新加载目标账本的集合。
///
/// 设计要点:
/// - 必须先等当前账本就绪再读 key,否则先渲染默认集合再被真值覆盖,
///   会造成可见列表闪烁(参照原 baseCurrencyInit 的 await 模式)。
/// - toggle 即时写当前账本 key,切账本时内存态必然已落盘,无丢失窗口。
/// - 同一账本的字段更新(如改本位币)不触发重载——仅 id 变化才切集合;
///   新本位币由公共函数 applyLedgerCurrencyChange 负责补入集合。
final visibleCurrenciesInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  // 加载目标账本的可见集合:无 key 时用「13 常用 ∪ 账本本位币」初始化并落盘。
  Future<void> loadFor(int? ledgerId, String? ledgerCurrency) async {
    final key = ledgerId == null
        ? _kVisibleCurrenciesFallbackKey
        : visibleCurrenciesKeyFor(ledgerId);
    final saved = prefs.getString(key);
    Set<String> initial;
    if (saved == null || saved.isEmpty) {
      // 首次访问该账本:常用币种 + 账本本位币(本位币可能不在常用列表里)
      initial = {
        ...kCommonCurrencyCodes.map((c) => c.toUpperCase()),
        if (ledgerCurrency != null && ledgerCurrency.isNotEmpty)
          ledgerCurrency.toUpperCase(),
      };
      // 立即落盘:固定初始化结果,避免该账本每次启动都重走默认初始化
      await prefs.setString(key, initial.join(','));
    } else {
      initial = saved
          .split(',')
          .map((s) => s.trim().toUpperCase())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    // 始终创建新 Set 赋值以触发 Riverpod 重建(Set 的可变性不触发通知)
    ref.read(visibleCurrenciesProvider.notifier).state = initial;
  }

  // 等当前账本就绪(StreamProvider 首次发射)再加载,避免默认集合闪烁
  final ledger = await ref.watch(currentLedgerProvider.future);
  await loadFor(ledger?.id, ledger?.currency);

  // 切账本 → 加载目标账本 key(无则初始化);无账本 → 兜底 key
  ref.listen<AsyncValue<Ledger?>>(currentLedgerProvider, (prev, next) {
    final nextLedger = next.valueOrNull;
    if (nextLedger?.id == prev?.valueOrNull?.id) return;
    unawaited(loadFor(nextLedger?.id, nextLedger?.currency));
  });
});

/// 切换某币种的可见性(增/删)。
///
/// 当前账本本位币(折算基准)不可隐藏——静默忽略,保证折算基准始终可见;
/// 其他账本的本位币在当前账本集合里是普通币种,可隐藏。
/// 始终创建新 Set 赋值以触发 Riverpod 重建(原地 add/remove 不通知)。
/// 改动后立即持久化到当前账本 key(无账本时落兜底 key)。
Future<void> toggleCurrencyVisibility(WidgetRef ref, String code) async {
  final codeUp = code.trim().toUpperCase();
  if (codeUp.isEmpty) return;
  final base = ref.read(currentLedgerCurrencyProvider);
  // 本位币锁定:不允许隐藏,静默忽略
  if (codeUp == base) return;

  final cur = ref.read(visibleCurrenciesProvider);
  final next = Set<String>.from(cur);
  if (next.contains(codeUp)) {
    next.remove(codeUp);
  } else {
    next.add(codeUp);
  }
  ref.read(visibleCurrenciesProvider.notifier).state = next;

  try {
    final prefs = await SharedPreferences.getInstance();
    final ledgerId = ref.read(currentLedgerProvider).valueOrNull?.id;
    await prefs.setString(
        ledgerId == null
            ? _kVisibleCurrenciesFallbackKey
            : visibleCurrenciesKeyFor(ledgerId),
        next.join(','));
  } catch (e, st) {
    // 持久化失败不回滚内存状态:用户选择已生效,下次启动会从内存重新初始化
    logger.warning('currency_providers',
        '持久化可见币种失败(非阻断): $e', st);
  }
}

/// 把指定币种补入当前账本可见集合并持久化(已在集合则跳过)。
///
/// 供切本位币公共函数(applyLedgerCurrencyChange)调用:新本位币必须在
/// 当前账本的各选择列表中可见。
Future<void> ensureCurrencyVisibleForCurrentLedger(
    WidgetRef ref, String code) async {
  final codeUp = code.trim().toUpperCase();
  if (codeUp.isEmpty) return;
  final cur = ref.read(visibleCurrenciesProvider);
  if (cur.contains(codeUp)) return;
  // 始终创建新 Set 赋值以触发 Riverpod 重建(Set 的可变性不触发通知)
  final next = {...cur, codeUp};
  ref.read(visibleCurrenciesProvider.notifier).state = next;
  try {
    final prefs = await SharedPreferences.getInstance();
    final ledgerId = ref.read(currentLedgerProvider).valueOrNull?.id;
    await prefs.setString(
        ledgerId == null
            ? _kVisibleCurrenciesFallbackKey
            : visibleCurrenciesKeyFor(ledgerId),
        next.join(','));
  } catch (e, st) {
    logger.warning('currency_providers', '补入可见币种失败(非阻断): $e', st);
  }
}

/// 币种选择弹窗的展示汇率:1 该币种 ≈ ? base。拉一次全量(fawaz base→quote
/// 全量返回),手动 override 优先。仅展示用,不落库。family key = base(大写)。
/// 值 = 「1 quote 币种 = value base」(便于 UI 显示 1 JPY ≈ 0.048 CNY)。
final currencyPickerRatesProvider =
    FutureProvider.family<Map<String, double>, String>((ref, base) async {
  ref.watch(rateRefreshTickProvider);
  final baseUp = base.toUpperCase();
  final repo = ref.watch(repositoryProvider);
  final out = <String, double>{};
  // 先公网/服务端全量(1 base = y quote → 1 quote = 1/y base)
  try {
    final result = await ref.read(exchangeRateServiceProvider).fetch(baseUp);
    for (final e in result.ratesBaseToQuote.entries) {
      final y = double.tryParse(e.value);
      if (y != null && y > 0) out[e.key.toUpperCase()] = 1 / y;
    }
  } catch (_) {/* 拉不到就只用本地 override,下方覆盖 */}
  // 手动 override 覆盖(1 quote = rate base,直接用)
  try {
    for (final o in await repo.getOverrides(baseUp)) {
      final r = double.tryParse(o.rate);
      if (r != null && r > 0) out[o.quoteCurrency.toUpperCase()] = r;
    }
  } catch (_) {}
  return out;
});

/// 当前账本本位币(ISO 大写)。`ledger.currency` 的语义化别名——交易级多币种后
/// 它的语义是「账本统计折算的目标币种」。
final currentLedgerCurrencyProvider = Provider<String>((ref) {
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  final c = ledger?.currency;
  return (c == null || c.isEmpty) ? 'CNY' : c.toUpperCase();
});

/// 以**账本本位币**为 base 的有效汇率(交易币种 → 账本本位币),手动 >
/// 最新自动,缺失显式缺失。折算基准的唯一来源;切账本自动重算。
/// 记账折算(computeNativeAmount)与汇率页展示都用这组。
final effectiveRatesForLedgerProvider =
    FutureProvider<Map<String, EffectiveRate>>((ref) async {
  ref.watch(rateRefreshTickProvider);
  ref.watch(statsRefreshProvider);
  final base = ref.watch(currentLedgerCurrencyProvider);
  final repo = ref.watch(repositoryProvider);
  final autos = await repo.getLatestAutoRates(base);
  final overrides = await repo.getOverrides(base);
  return mergeEffectiveRates(
    autoRates: [
      for (final r in autos)
        (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
    ],
    overrides: [
      for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
    ],
  );
});

/// 当前账本「未折算外币交易」条数(L11 检测):>0 时统计页显示补折算横幅。
/// watch statsRefresh(重算完成/交易变动后重查)。
final ledgerUnconvertedForeignTxCountProvider = FutureProvider<int>((ref) async {
  ref.watch(statsRefreshProvider);
  ref.watch(rateRefreshTickProvider);
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  if (ledger == null) return 0;
  final repo = ref.watch(repositoryProvider);
  return repo.countUnconvertedForeignTx(ledger.id);
});

/// 当前账本外币交易条数(含已折算):>0 时账本统计页显示折算脚注。
final ledgerForeignTxCountProvider = FutureProvider<int>((ref) async {
  ref.watch(statsRefreshProvider);
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  if (ledger == null) return 0;
  final repo = ref.watch(repositoryProvider);
  return repo.countForeignCurrencyTx(ledger.id);
});



/// 拉取协调:server 源(云模式)→ 公网链;倒数后只落「使用中币种」;成功 bump tick。
/// force=false 时 24h 节流 + 多币种总闸。失败返回 false(资产页静默、汇率页 Toast)。
///
/// Ref 版入口当前无调用方,保留给后台/provider 语境的未来调用
/// (如周期刷新、启动预拉);UI 层用 [refreshExchangeRatesFromUi]。
Future<bool> refreshExchangeRates(Ref ref,
        {bool force = false, Set<String>? extraQuotes}) =>
    _refreshExchangeRatesImpl(
      read: ref.read,
      readFuture: <T>(p) => ref.read(p.future),
      force: force,
      extraQuotes: extraQuotes,
    );

/// UI 层薄封装:`WidgetRef` 与 `Ref` 的 read 能力等价,直接转发到同一实现。
/// ConsumerState 里只有 `WidgetRef`,无法 cast 成 `Ref`,故单开此入口。
Future<bool> refreshExchangeRatesFromUi(WidgetRef ref,
        {bool force = false, Set<String>? extraQuotes}) =>
    _refreshExchangeRatesImpl(
      read: ref.read,
      readFuture: <T>(p) => ref.read(p.future),
      force: force,
      extraQuotes: extraQuotes,
    );

/// 真正的实现:只依赖 read / readFuture 两个能力,与 Ref / WidgetRef 解耦。
///
/// base 集合 = {各账本本位币}——折算基准 = 账本本位币,每个不同本位币的账本
/// 都需要以它为 base 的汇率组;无账本时无折算需求,直接跳过拉取。
/// [extraQuotes]:额外要拉的币种(记账页手选币种)——手选币种不在
/// 已落库的 quote 集合里,不带上它拉回来的组里永远没有它。
Future<bool> _refreshExchangeRatesImpl({
  required T Function<T>(ProviderListenable<T>) read,
  required Future<T> Function<T>(FutureProvider<T>) readFuture,
  required bool force,
  Set<String>? extraQuotes,
}) async {
  try {
    final repo = read(repositoryProvider);

    // base 集合:各账本本位币(大写);无账本(或读账本失败)时跳过拉取
    final bases = <String>{};
    try {
      final ledgers = await repo.getAllLedgers();
      bases.addAll(ledgers
          .map((l) => l.currency.toUpperCase())
          .where((c) => c.isNotEmpty));
    } catch (e) {
      logger.warning('currency_providers', '读取账本本位币集合失败(跳过拉取): $e');
    }
    if (bases.isEmpty) {
      logger.info('currency_providers', '无账本本位币,跳过汇率拉取');
      return true;
    }

    // 注意:不需 guards—汇率页需求展示全部币种(非仅使用中币种),
    // 即使只有基准币种也必须拉取 API 获取全部汇率。
    // extraQuotes 参数保留但不消费:API 一次返回全部币种数据,已在
    // _fetchAndStoreRatesForBase 中全量存储,额外指定币种无实际增益。
    var anySuccess = false;
    for (final base in bases) {
      if (!force) {
        final last = await repo.getLastFetchedAt(base);
        if (last != null &&
            DateTime.now().toUtc().difference(last) <
                const Duration(hours: 24)) {
          anySuccess = true; // 未过期视作成功,无需拉取
          continue;
        }
      }
      if (await _fetchAndStoreRatesForBase(
          read: read,
          readFuture: readFuture,
          repo: repo,
          base: base)) {
        anySuccess = true;
      }
    }
    if (anySuccess) read(rateRefreshTickProvider.notifier).state++;
    return anySuccess;
  } catch (e, st) {
    logger.warning('currency_providers', '汇率刷新失败: $e', st);
    return false;
  }
}

/// 拉取并落库单个 base 的汇率。
/// 汇率页展示除基准币种外的全部币种,因此此函数存储 API 返回的全部汇率,
/// 不按 "quotes" 集合过滤——一次 API 调用已返回所有币种数据,过滤掉纯属浪费。
Future<bool> _fetchAndStoreRatesForBase({
  required T Function<T>(ProviderListenable<T>) read,
  required Future<T> Function<T>(FutureProvider<T>) readFuture,
  required BaseRepository repo,
  required String base,
}) async {
  try {
    String rateDate, source;
    Map<String, String> baseToQuote;
    Map<String, dynamic>? serverBody;
    try {
      final cloudProvider = await readFuture(spitoutCloudProviderInstance);
      serverBody = cloudProvider == null
          ? null
          : await cloudProvider.fetchExchangeRates(base: base);
    } catch (e) {
      logger.warning('currency_providers', 'server 汇率源失败,下滑公网: $e');
      serverBody = null;
    }
    // serverBody['stale'] 有意不消费:rateDate 如实落库(UI 日期不撒谎),代价是
    // stale 数据会被 24h 节流当新鲜缓存一天;有 force 刷新兜底,MVP 接受。
    final rawRateDate = serverBody?['rate_date']?.toString() ?? '';
    if (serverBody != null &&
        serverBody['rates'] is Map &&
        rawRateDate.isNotEmpty) {
      rateDate = rawRateDate;
      source = 'server';
      baseToQuote = {
        for (final e in (serverBody['rates'] as Map).entries)
          e.key.toString().toUpperCase(): e.value.toString(),
      };
    } else {
      final result = await read(exchangeRateServiceProvider).fetch(base);
      rateDate = result.rateDate;
      source = result.source;
      baseToQuote = result.ratesBaseToQuote;
    }

    // 倒数成「1 quote = x base」,存储 API 返回的全部币种汇率
    // 需求:汇率页展示除基准币种外的全部币种——一次网络调用已拿回全部数据,
    // 二次过滤纯属浪费;此处存储全量,UI 侧按需展示即可。
    final inverted = <String, String>{};
    for (final e in baseToQuote.entries) {
      final raw = double.tryParse(e.value);
      if (raw != null && raw > 0) {
        inverted[e.key.toUpperCase()] = invertRate(raw);
      }
    }
    if (inverted.isEmpty) return false;
    await repo.upsertAutoRates(
      base: base,
      rateDate: rateDate,
      rates: inverted,
      source: source,
      fetchedAt: DateTime.now().toUtc(),
    );
    return true;
  } catch (e, st) {
    logger.warning('currency_providers', 'base=$base 汇率拉取失败: $e', st);
    return false;
  }
}
