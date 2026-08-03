/// 记账页手选币种的汇率拉取:
/// 手选币种不在账本已落库的 quote 集合里,常规 refresh 拉回的组永远没有它
/// —— refreshExchangeRatesFromUi 的 extraQuotes 参数把它并入拉取集合。
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/services/currency/exchange_rate_service.dart';

/// 假汇率源:固定返回 CNY 基准的几个币种(不打网络)。
class _FakeRateService implements ExchangeRateService {
  int fetchCount = 0;
  @override
  Future<RateFetchResult> fetch(String base) async {
    fetchCount++;
    return const RateFetchResult(
      rateDate: '2026-07-12',
      source: 'fake',
      ratesBaseToQuote: {'USD': '0.139', 'JPY': '20.5', 'EUR': '0.127'},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  test('extraQuotes:手选币种(JPY)不在已落库集合里,refresh 后其汇率被落库', () async {
    // 单账本环境:仅 CNY 账本(拉取 base 集合 = {CNY})。账本没有 JPY 交易时
    // 常规拉取不会带 JPY —— extraQuotes 把 JPY 并入拉取集合。
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    final fake = _FakeRateService();
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      exchangeRateServiceProvider.overrideWithValue(fake),
      // spitoutCloudProviderInstance 走真实 provider 链会因未配置返回 null →
      // 下滑到 exchangeRateServiceProvider(fake),正好覆盖公网链路径。
    ]);
    addTearDown(container.dispose);

    final ok = await refreshExchangeRatesImpl(
      read: <T>(p) => container.read(p),
      readFuture: <T>(p) => container.read(p.future),
      force: true,
      extraQuotes: {'JPY'},
    );
    expect(ok, isTrue);
    expect(fake.fetchCount, greaterThan(0));

    final rates = await repo.getLatestAutoRates('CNY');
    final quotes = rates.map((r) => r.quoteCurrency).toSet();
    expect(quotes, contains('JPY'),
        reason: 'extraQuotes 的币种必须进入拉取并落库');
  });
}

