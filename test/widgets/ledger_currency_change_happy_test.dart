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

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/ledger_currency_change.dart';

import '../helpers/test_isolation.dart';

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
}
