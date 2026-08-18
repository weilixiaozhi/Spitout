// applyLedgerCurrencyChange 补充分支测试。
//
// 与 ledger_currency_change_guard_test（共享账本权限守卫）互补，锁定：
//   - 空币种 / 账本不存在 → 直接返回 false；
//   - 有交易时弹确认对话框，取消则整体中止；
//   - 无交易时走完整切换：改币种 → 拉汇率（失败容忍）→ 重算 → 刷新信号
//     → 同步（失败容忍）→ 成功 toast，返回 true。
library;

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/currency/exchange_rate_service.dart';
import 'package:spitout/widgets/ledger_currency_change.dart';

import '../helpers/test_isolation.dart';

/// 固定汇率源，避免换币流程测试依赖公网。
class _FakeRateService implements ExchangeRateService {
  @override
  Future<RateFetchResult> fetch(String base) async => RateFetchResult(
        rateDate: '2026-08-18',
        source: 'test',
        ratesBaseToQuote: base == 'USD'
            ? const {'CNY': '7.142857'}
            : const {'USD': '0.14'},
      );

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

  tearDown(() => db.close());

  Future<int> seedLedger({String currency = 'CNY'}) async {
    return db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: '账本',
            currency: d.Value(currency),
          ),
        );
  }

  Future<({BuildContext context, WidgetRef ref})> pumpHarness(
    WidgetTester tester,
  ) async {
    late BuildContext capturedContext;
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) => repo),
            exchangeRateServiceProvider.overrideWithValue(_FakeRateService()),
            activeCloudConfigProvider.overrideWith(
              (ref) async => const CloudServiceConfig(
                type: CloudBackendType.local,
                name: 'Local',
              ),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              capturedContext = context;
              capturedRef = ref;
              return const Placeholder();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (context: capturedContext, ref: capturedRef);
  }

  testWidgets('空币种 / 账本不存在 → false', (tester) async {
    final h = await pumpHarness(tester);
    final ledgerId = await seedLedger();

    expect(
      await applyLedgerCurrencyChange(
        h.context,
        h.ref,
        ledgerId: ledgerId,
        newCurrency: '   ',
      ),
      isFalse,
    );
    expect(
      await applyLedgerCurrencyChange(
        h.context,
        h.ref,
        ledgerId: 999,
        newCurrency: 'USD',
      ),
      isFalse,
    );
  });

  testWidgets('有交易时确认弹窗取消 → false 且币种不变', (tester) async {
    final h = await pumpHarness(tester);
    final ledgerId = await seedLedger();
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 100,
      happenedAt: DateTime(2026, 8, 8),
    );

    final future = applyLedgerCurrencyChange(
      h.context,
      h.ref,
      ledgerId: ledgerId,
      newCurrency: 'USD',
    );
    await tester.pumpAndSettle();
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await future, isFalse);

    final ledger = await repo.getLedgerById(ledgerId);
    expect(ledger?.currency, 'CNY');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('无交易 happy path：改币种、刷新、成功 toast', (tester) async {
    final h = await pumpHarness(tester);
    final ledgerId = await seedLedger();

    final result = await applyLedgerCurrencyChange(
      h.context,
      h.ref,
      ledgerId: ledgerId,
      newCurrency: 'usd',
    );
    await tester.pumpAndSettle();

    expect(result, isTrue);
    final ledger = await repo.getLedgerById(ledgerId);
    expect(ledger?.currency, 'USD', reason: '小写输入归一化为大写');
    expect(find.textContaining('已切换'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('重算失败时币种、快照与同步变更全部回滚', (tester) async {
    final h = await pumpHarness(tester);
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: '云账本',
            currency: const d.Value('CNY'),
            syncId: const d.Value('ledger-sync'),
            storageMode: const d.Value('cloud'),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 100,
            currencyCode: const d.Value('CNY'),
            nativeAmount: const d.Value(100),
            syncId: const d.Value('tx-sync'),
          ),
        );
    repo.changeTracker = ChangeTracker(db);
    // 在币种元数据写入之后强制让金额重算失败，验证外层事务能撤销前序写入。
    await db.customStatement('''
      CREATE TRIGGER fail_native_recalc
      BEFORE UPDATE OF native_amount ON transactions
      BEGIN
        SELECT RAISE(ABORT, 'forced recalc failure');
      END;
    ''');

    final future = applyLedgerCurrencyChange(
      h.context,
      h.ref,
      ledgerId: ledgerId,
      newCurrency: 'USD',
    );
    await tester.pumpAndSettle();
    expect(find.text('确定'), findsOneWidget);
    final failure = expectLater(future, throwsA(anything));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await failure;

    expect((await repo.getLedgerById(ledgerId))?.currency, 'CNY');
    final tx = await repo.getTransactionById(1);
    expect(tx?.currencyCode, 'CNY');
    expect(tx?.nativeAmount, 100);
    expect(await db.select(db.localChanges).get(), isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });
}
