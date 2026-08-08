// currency_providers 层测试。
//
// 需求锚点（以行为为准）：
//   1. visibleCurrenciesInitProvider：无 key 时用「13 常用 ∪ 本位币」初始化并落盘；
//      有 key 时载入；无账本落 fallback key；切账本重载目标集合；
//   2. toggleCurrencyVisibility：增/删可见币种并立即落盘；本位币锁定；空值跳过；
//   3. ensureCurrencyVisibleForCurrentLedger：已存在跳过，缺失补入并落盘；
//   4. currencyPickerRatesProvider：公网汇率取倒数 + 手动 override 覆盖；拉取失败仅用 override；
//   5. 未折算/外币交易计数 provider：有账本查库、无账本归 0；
//   6. refreshExchangeRatesImpl：无账本直接成功；24h 节流跳过拉取；强制拉取；
//      拉取失败返回 false。

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/currency/exchange_rate_service.dart';
import 'package:spitout/utils/currency/currencies.dart';

class _MockRepo extends Mock implements BaseRepository {}

/// 假汇率服务：固定返回 CNY base 汇率，可注入失败。
class _FakeRateService implements ExchangeRateService {
  bool shouldThrow = false;
  int fetchCount = 0;

  @override
  Future<RateFetchResult> fetch(String base) async {
    fetchCount++;
    if (shouldThrow) throw Exception('network down');
    return const RateFetchResult(
      rateDate: '2026-07-12',
      source: 'fake',
      ratesBaseToQuote: {'USD': '0.139', 'JPY': '20.5'},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  Ledger ledgerWith(String currency, {int id = 1}) => Ledger(
        id: id,
        name: 'L$id',
        currency: currency,
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        monthStartDay: 1,
        storageMode: 'local',
        aaEnabled: false,
      );

  /// 构建 ProviderContainer：注入仓库与当前账本流。
  ProviderContainer makeContainer({
    required Stream<Ledger?> ledgerStream,
    BaseRepository? repository,
  }) {
    return ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repository ?? repo),
        currentLedgerProvider.overrideWith((ref) => ledgerStream),
      ],
    );
  }

  /// 通过 Consumer 捕获与 ProviderScope 绑定的 WidgetRef（供 toggle/ensure 调用）。
  Future<WidgetRef> captureRef(
    WidgetTester tester, {
    required Stream<Ledger?> ledgerStream,
    Set<String>? visible,
  }) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          currentLedgerProvider.overrideWith((ref) => ledgerStream),
          currentLedgerCurrencyProvider.overrideWith((ref) => 'CNY'),
          if (visible != null)
            visibleCurrenciesProvider.overrideWithBuild(
              (ref, notifier) => visible,
            ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            // 保持当前账本流订阅活跃：仅 ref.read 不会触发 StreamProvider 首帧，
            // 导致 .value 恒为 null、落盘误走 fallback key。
            ref.watch(currentLedgerProvider);
            return const Placeholder();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return captured;
  }

  group('visibleCurrenciesInitProvider', () {
    test('无 key：13 常用 ∪ 本位币初始化并落盘到账本 key', () async {
      final container = makeContainer(
        ledgerStream: Stream<Ledger?>.value(ledgerWith('CNY')),
      );
      addTearDown(container.dispose);

      await readProviderFutureFromContainer(
        container,
        visibleCurrenciesInitProvider.future,
      );

      final set = container.read(visibleCurrenciesProvider);
      expect(kCommonCurrencyCodes.every(set.contains), isTrue);
      expect(set.contains('CNY'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(visibleCurrenciesKeyFor(1)), isNotNull,
          reason: '首次初始化必须立即落盘');
    });

    test('有 key：载入已保存集合', () async {
      SharedPreferences.setMockInitialValues({
        visibleCurrenciesKeyFor(1): 'CNY,USD',
      });
      final container = makeContainer(
        ledgerStream: Stream<Ledger?>.value(ledgerWith('CNY')),
      );
      addTearDown(container.dispose);

      await readProviderFutureFromContainer(
        container,
        visibleCurrenciesInitProvider.future,
      );
      expect(container.read(visibleCurrenciesProvider), {'CNY', 'USD'});
    });

    test('无账本：落 fallback key', () async {
      final container = makeContainer(
        ledgerStream: Stream<Ledger?>.value(null),
      );
      addTearDown(container.dispose);

      await readProviderFutureFromContainer(
        container,
        visibleCurrenciesInitProvider.future,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('visibleCurrencies._none'), isNotNull);
    });

    test('切账本：重载目标账本集合并落盘', () async {
      final container = makeContainer(
        ledgerStream: Stream<Ledger?>.fromIterable([
          ledgerWith('CNY', id: 1),
          ledgerWith('JPY', id: 2),
        ]),
      );
      addTearDown(container.dispose);

      await readProviderFutureFromContainer(
        container,
        visibleCurrenciesInitProvider.future,
      );
      expect(container.read(visibleCurrenciesProvider).contains('CNY'), isTrue);

      await pumpEventQueue();
      // 账本 2 无 key → 默认 13 常用 ∪ JPY
      expect(container.read(visibleCurrenciesProvider).contains('JPY'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(visibleCurrenciesKeyFor(2)), contains('JPY'));
    });
  });

  group('toggleCurrencyVisibility', () {
    testWidgets('增/删可见币种并立即落盘；本位币锁定；空值跳过', (tester) async {
      final ref = await captureRef(
        tester,
        ledgerStream: Stream<Ledger?>.value(ledgerWith('CNY')),
        visible: const {'CNY', 'USD'},
      );

      await toggleCurrencyVisibility(ref, 'EUR');
      expect(ref.read(visibleCurrenciesProvider).contains('EUR'), isTrue);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(visibleCurrenciesKeyFor(1)), contains('EUR'));

      await toggleCurrencyVisibility(ref, 'EUR');
      expect(ref.read(visibleCurrenciesProvider).contains('EUR'), isFalse);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(visibleCurrenciesKeyFor(1)), isNot(contains('EUR')));

      // 本位币锁定：移除 CNY 不生效
      await toggleCurrencyVisibility(ref, 'CNY');
      expect(ref.read(visibleCurrenciesProvider).contains('CNY'), isTrue);

      // 空值/空白跳过
      await toggleCurrencyVisibility(ref, '  ');
      expect(ref.read(visibleCurrenciesProvider).length, 2);
    });
  });

  group('ensureCurrencyVisibleForCurrentLedger', () {
    testWidgets('已存在跳过；缺失补入并落盘', (tester) async {
      final ref = await captureRef(
        tester,
        ledgerStream: Stream<Ledger?>.value(ledgerWith('CNY')),
        visible: const {'CNY', 'USD'},
      );

      await ensureCurrencyVisibleForCurrentLedger(ref, 'USD');
      expect(ref.read(visibleCurrenciesProvider), {'CNY', 'USD'},
          reason: '已在集合中不应重复写盘');

      await ensureCurrencyVisibleForCurrentLedger(ref, 'JPY');
      expect(ref.read(visibleCurrenciesProvider).contains('JPY'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(visibleCurrenciesKeyFor(1)), contains('JPY'));
    });
  });

  group('currencyPickerRatesProvider', () {
    test('公网汇率取倒数 + 手动 override 合并', () async {
      final fake = _FakeRateService();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          exchangeRateServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      await repo.setOverride(base: 'CNY', quote: 'JPY', rate: '0.048');

      final rates = await readProviderFutureFromContainer(
        container,
        currencyPickerRatesProvider('CNY').future,
      );
      // 1 USD = 0.139 CNY → 1 JPY? 不对：0.139 是 1 CNY = 0.139 USD → 1 USD = 1/0.139 CNY
      expect(rates['USD'], closeTo(1 / 0.139, 1e-9));
      expect(rates['JPY'], 0.048, reason: '手动 override 覆盖公网值');
    });

    test('公网拉取失败：仅剩手动 override', () async {
      final fake = _FakeRateService()..shouldThrow = true;
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          exchangeRateServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      await repo.setOverride(base: 'CNY', quote: 'JPY', rate: '0.048');

      final rates = await readProviderFutureFromContainer(
        container,
        currencyPickerRatesProvider('CNY').future,
      );
      expect(rates, {'JPY': 0.048});
    });
  });

  group('外币交易计数 provider', () {
    test('有账本查库、无账本归 0', () async {
      final mock = _MockRepo();
      when(() => mock.countUnconvertedForeignTx(1))
          .thenAnswer((_) async => 3);
      when(() => mock.countForeignCurrencyTx(1))
          .thenAnswer((_) async => 5);

      final container = makeContainer(
        ledgerStream: Stream<Ledger?>.value(ledgerWith('CNY')),
        repository: mock,
      );
      addTearDown(container.dispose);
      expect(
        await readProviderFutureFromContainer(
          container,
          ledgerUnconvertedForeignTxCountProvider.future,
        ),
        3,
      );
      expect(
        await readProviderFutureFromContainer(
          container,
          ledgerForeignTxCountProvider.future,
        ),
        5,
      );

      final empty = makeContainer(
        ledgerStream: Stream<Ledger?>.value(null),
        repository: mock,
      );
      addTearDown(empty.dispose);
      expect(
        await readProviderFutureFromContainer(
          empty,
          ledgerUnconvertedForeignTxCountProvider.future,
        ),
        0,
        reason: '无账本时不查库直接归 0',
      );
      expect(
        await readProviderFutureFromContainer(
          empty,
          ledgerForeignTxCountProvider.future,
        ),
        0,
      );
    });
  });

  group('refreshExchangeRatesImpl', () {
    test('无账本：直接成功且不拉取', () async {
      final fake = _FakeRateService();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          exchangeRateServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);

      final ok = await refreshExchangeRatesImpl(
        read: <T>(p) => container.read(p),
        force: true,
      );
      expect(ok, isTrue);
      expect(fake.fetchCount, 0, reason: '无账本无折算需求，跳过拉取');
    });

    test('24h 节流跳过；force 强制拉取', () async {
      final fake = _FakeRateService();
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          exchangeRateServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      await repo.createLedger(name: 'L', currency: 'CNY');
      await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-07-12',
        rates: const {'USD': '7.2'},
        source: 'fake',
        fetchedAt: DateTime.now().toUtc(),
      );
      final fakeBefore = fake.fetchCount;

      final throttled = await refreshExchangeRatesImpl(
        read: <T>(p) => container.read(p),
        force: false,
      );
      expect(throttled, isTrue);
      expect(fake.fetchCount, fakeBefore, reason: '24h 内不重复拉取');

      final forced = await refreshExchangeRatesImpl(
        read: <T>(p) => container.read(p),
        force: true,
      );
      expect(forced, isTrue);
      expect(fake.fetchCount, greaterThan(fakeBefore), reason: 'force 绕过节流');
    });

    test('拉取失败返回 false', () async {
      final fake = _FakeRateService()..shouldThrow = true;
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          exchangeRateServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      await repo.createLedger(name: 'L', currency: 'CNY');

      final ok = await refreshExchangeRatesImpl(
        read: <T>(p) => container.read(p),
        force: true,
      );
      expect(ok, isFalse);
    });
  });
}
