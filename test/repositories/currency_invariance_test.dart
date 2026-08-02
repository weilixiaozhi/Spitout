/// 交易级多币种 — 币种切换不变性测试:
///
/// 核心验证点(对应 bug 修复):
///   1. 账本主币种变更后,recalcNativeAmountsForLedger 只重算 nativeAmount,
///      绝不修改交易的 currencyCode(交易原币种是用户记账时选的,不随主币种变更)
///   2. currencyCode 为 null 的历史数据:重算后仍为 null(不填充新主币种)
///   3. 显式 currencyCode='CNY' 的交易:主币种改为 USD 后仍为 'CNY'
///   4. nativeAmount 按新主币种重算(有汇率)或退化=amount(无汇率)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

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

  /// 创建账本并返回 ID
  Future<int> seedLedger({String currency = 'CNY'}) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency, storage_mode) VALUES (1, 'L', '$currency', 'cloud')");
    return 1;
  }

  /// 插入汇率(1 quote = rate base)
  Future<void> seedRates({
    required String base,
    required Map<String, String> rates,
  }) async {
    await repo.upsertAutoRates(
      base: base,
      rateDate: '2026-07-20',
      rates: rates,
      source: 'test',
      fetchedAt: DateTime.utc(2026, 7, 20),
    );
  }

  /// 直接用 SQL 插入交易(绕过 _resolveTxCurrency 兜底),
  /// 用于精确模拟历史数据(currencyCode=null)
  Future<int> seedTxRaw({
    required int ledgerId,
    required double amount,
    String? currencyCode,
    double? nativeAmount,
    String syncId = 'tx-001',
  }) async {
    final id = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: amount,
            happenedAt: Value(DateTime(2026, 7, 15)),
            syncId: Value(syncId),
            currencyCode: currencyCode == null
                ? const Value.absent()
                : Value(currencyCode),
            nativeAmount: nativeAmount == null
                ? const Value.absent()
                : Value(nativeAmount),
          ),
        );
    return id;
  }

  group('recalcNativeAmountsForLedger 币种不变性', () {
    test('显式 currencyCode 的交易:主币种变更后 currencyCode 不变', () async {
      final lid = await seedLedger(currency: 'CNY');

      // 插入汇率:改主币种为 USD 后需要 CNY→USD 的汇率
      await seedRates(base: 'USD', rates: {'CNY': '0.14'});

      // 创建一笔 CNY 交易(主币种为 CNY 时, nativeAmount = amount)
      final txId = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 100,
        happenedAt: DateTime(2026, 7, 15),
        currencyCode: 'CNY',
        nativeAmount: 100,
      );

      // 修改账本主币种为 USD 并全量重算
      await repo.updateLedger(id: lid, currency: 'USD');
      await repo.recalcNativeAmountsForLedger(lid, 'USD');

      final tx = await repo.getTransactionById(txId);
      // 核心断言:currencyCode 不变,仍是 CNY
      expect(tx!.currencyCode, 'CNY',
          reason: '交易原币种不应随账本主币种变更而改变');
      // nativeAmount 按新主币种 USD 重算:100 × 0.14 = 14
      expect(tx.nativeAmount, closeTo(14.0, 1e-9),
          reason: 'nativeAmount 应按新主币种重算');
    });

    test('currencyCode=null 的历史数据:主币种变更后仍为 null', () async {
      final lid = await seedLedger(currency: 'CNY');

      await seedRates(base: 'USD', rates: {'CNY': '0.14'});

      // 用 SQL 直接插入 currencyCode=null 的历史数据
      final txId = await seedTxRaw(
        ledgerId: lid,
        amount: 50,
        currencyCode: null,
        nativeAmount: 50,
        syncId: 'legacy-tx',
      );

      // 修改账本主币种为 USD 并全量重算
      await repo.updateLedger(id: lid, currency: 'USD');
      await repo.recalcNativeAmountsForLedger(lid, 'USD');

      final tx = await repo.getTransactionById(txId);
      // 核心断言:currencyCode 仍为 null(不被填充为新主币种 USD)
      expect(tx!.currencyCode, isNull,
          reason: '历史 NULL currencyCode 不应被填充为新主币种');
      // nativeAmount:currencyCode=null → cc=baseUp(USD) → 同币种 → nativeAmount=amount
      expect(tx.nativeAmount, 50,
          reason: 'null currencyCode 按新主币种兜底,nativeAmount=amount');
    });

    test('多笔交易混合币种:主币种变更后各自 currencyCode 均不变', () async {
      final lid = await seedLedger(currency: 'CNY');

      await seedRates(base: 'USD', rates: {'CNY': '0.14', 'EUR': '1.08'});

      // CNY 交易(原主币种)
      final cnyTx = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 100,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'CNY', nativeAmount: 100,
      );
      // USD 交易(外币)
      final usdTx = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 20,
        happenedAt: DateTime(2026, 7, 2),
        currencyCode: 'USD', nativeAmount: 144, // 20 × 7.2(旧汇率)
      );
      // EUR 交易(外币)
      final eurTx = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 30,
        happenedAt: DateTime(2026, 7, 3),
        currencyCode: 'EUR', nativeAmount: 216, // 30 × 7.2(旧汇率)
      );

      // 修改账本主币种为 USD 并全量重算
      await repo.updateLedger(id: lid, currency: 'USD');
      await repo.recalcNativeAmountsForLedger(lid, 'USD');

      // 全部 currencyCode 不变
      expect((await repo.getTransactionById(cnyTx))!.currencyCode, 'CNY');
      expect((await repo.getTransactionById(usdTx))!.currencyCode, 'USD');
      expect((await repo.getTransactionById(eurTx))!.currencyCode, 'EUR');

      // nativeAmount 按新主币种 USD 重算
      expect((await repo.getTransactionById(cnyTx))!.nativeAmount,
          closeTo(14.0, 1e-9)); // 100 × 0.14
      expect((await repo.getTransactionById(usdTx))!.nativeAmount,
          20); // 同币种 = amount
      expect((await repo.getTransactionById(eurTx))!.nativeAmount,
          closeTo(32.4, 1e-9)); // 30 × 1.08
    });

    test('无汇率时:currencyCode 不变,nativeAmount 退化=amount', () async {
      final lid = await seedLedger(currency: 'CNY');

      // 不插入任何汇率
      final txId = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 100,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'CNY', nativeAmount: 100,
      );

      // 修改账本主币种为 USD 并全量重算(无 CNY→USD 汇率)
      await repo.updateLedger(id: lid, currency: 'USD');
      await repo.recalcNativeAmountsForLedger(lid, 'USD');

      final tx = await repo.getTransactionById(txId);
      expect(tx!.currencyCode, 'CNY', reason: '无汇率时 currencyCode 也不变');
      expect(tx.nativeAmount, 100,
          reason: '无汇率时 nativeAmount 退化=amount,由 L11 横幅兜底');
    });

    test('逐笔记 change(L13):重算后 local_changes 有对应条数', () async {
      db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      final tracker = ChangeTracker(db);
      repo = LocalRepository(db, changeTracker: tracker);
      final lid = await seedLedger(currency: 'CNY');

      await seedRates(base: 'USD', rates: {'CNY': '0.14'});

      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 100,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'CNY', nativeAmount: 100,
      );
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 2),
        currencyCode: 'CNY', nativeAmount: 50,
      );

      final before = (await db.select(db.localChanges).get()).length;
      final n = await repo.recalcNativeAmountsForLedger(lid, 'USD');
      final after = (await db.select(db.localChanges).get()).length;

      expect(n, 2);
      expect(after - before, 2,
          reason: '重算必须逐笔记 change,否则云端投影不更新');
    });
  });

  group('recomputeForeignTxForLedger 币种不变性', () {
    test('补折算模式:currencyCode 不变,只补 nativeAmount', () async {
      final lid = await seedLedger(currency: 'CNY');

      await seedRates(base: 'CNY', rates: {'USD': '7.2'});

      // 未折算外币(native==amount,模拟迁移回填态)
      final txId = await seedTxRaw(
        ledgerId: lid,
        amount: 10,
        currencyCode: 'USD',
        nativeAmount: 10, // == amount → 未折算
        syncId: 'unconverted',
      );

      final n = await repo.recomputeForeignTxForLedger(lid);
      expect(n, 1);

      final tx = await repo.getTransactionById(txId);
      expect(tx!.currencyCode, 'USD', reason: '补折算不改 currencyCode');
      expect(tx.nativeAmount, closeTo(72.0, 1e-9)); // 10 × 7.2
    });
  });

  group('updateTransactionLedger 跨账本移动后币种不变性', () {
    test('跨账本移动:currencyCode 不变,nativeAmount 按新账本重算', () async {
      // 账本1: CNY
      await db.customStatement(
          "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L1', 'CNY')");
      // 账本2: USD
      await db.customStatement(
          "INSERT INTO ledgers (id, name, currency) VALUES (2, 'L2', 'USD')");

      await seedRates(base: 'USD', rates: {'CNY': '0.14'});

      // 在账本1(CNY)下创建一笔 CNY 交易
      final txId = await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 100,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'CNY', nativeAmount: 100,
      );

      // 移动到账本2(USD)
      await repo.updateTransactionLedger(id: txId, ledgerId: 2);

      final tx = await repo.getTransactionById(txId);
      expect(tx!.ledgerId, 2);
      expect(tx.currencyCode, 'CNY', reason: '跨账本移动不改 currencyCode');
      expect(tx.nativeAmount, closeTo(14.0, 1e-9),
          reason: 'nativeAmount 按新账本本位币 USD 重算');
    });
  });

  group('add/update 交易折算兜底', () {
    test('add 不传两字段+本位币 → currencyCode=本位币, nativeAmount=amount', () async {
      final lid = await seedLedger();

      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 100,
        happenedAt: DateTime(2026, 7, 12),
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.currencyCode, 'CNY');
      expect(tx.nativeAmount, 100);
    });

    test('add 不传 nativeAmount+外币+有汇率 → nativeAmount=折算值', () async {
      final lid = await seedLedger();

      await seedRates(base: 'CNY', rates: {'USD': '7.2'});
      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        happenedAt: DateTime(2026, 7, 12),
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.currencyCode, 'USD');
      expect(tx.nativeAmount, closeTo(86.4, 1e-9));
    });

    test('update 不传两字段只改金额 → 外币按隐含汇率缩放, currencyCode 不变', () async {
      final lid = await seedLedger();

      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 86.4,
      );
      await repo.updateTransaction(id: id, type: 'expense', amount: 24);
      final tx = await repo.getTransactionById(id);
      expect(tx!.amount, 24);
      expect(tx.currencyCode, 'USD', reason: '更新不改 currencyCode');
      expect(tx.nativeAmount, closeTo(172.8, 1e-9));
    });

    test('update 改备注不改金额 → 快照不动, currencyCode 不变', () async {
      final lid = await seedLedger();

      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 86.4,
      );
      await repo.updateTransaction(
          id: id, type: 'expense', amount: 12, note: '改备注');
      final tx = await repo.getTransactionById(id);
      expect(tx!.note, '改备注');
      expect(tx.currencyCode, 'USD');
      expect(tx.nativeAmount, 86.4);
    });

    test('update 显式传 currencyCode+nativeAmount → 以传入为准', () async {
      final lid = await seedLedger();

      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 86.4,
      );
      // 编辑:改币种为 EUR,金额改为 30,折算快照 32.4
      await repo.updateTransaction(
          id: id,
          type: 'expense',
          amount: 30,
          currencyCode: 'EUR',
          nativeAmount: 32.4);
      final tx = await repo.getTransactionById(id);
      expect(tx!.currencyCode, 'EUR');
      expect(tx.amount, 30);
      expect(tx.nativeAmount, 32.4);
    });
  });

  group('countUnconvertedForeignTx / countForeignCurrencyTx', () {
    test('空账本:两者均返回 0', () async {
      final lid = await seedLedger();
      expect(await repo.countUnconvertedForeignTx(lid), 0);
      expect(await repo.countForeignCurrencyTx(lid), 0);
    });

    test('仅本位币交易:两者均返回 0', () async {
      final lid = await seedLedger();
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 1),
      );
      expect(await repo.countUnconvertedForeignTx(lid), 0);
      expect(await repo.countForeignCurrencyTx(lid), 0);
    });

    test('未折算外币:unconverted=1, foreignTotal=1', () async {
      final lid = await seedLedger();
      await seedTxRaw(
        ledgerId: lid, amount: 10,
        currencyCode: 'USD', nativeAmount: 10,
      );
      expect(await repo.countUnconvertedForeignTx(lid), 1);
      expect(await repo.countForeignCurrencyTx(lid), 1);
    });

    test('已折算外币:unconverted=0, foreignTotal=1', () async {
      final lid = await seedLedger();
      await seedTxRaw(
        ledgerId: lid, amount: 10,
        currencyCode: 'USD', nativeAmount: 72,
      );
      expect(await repo.countUnconvertedForeignTx(lid), 0);
      expect(await repo.countForeignCurrencyTx(lid), 1);
    });

    test('混合:未折算+已折算+本位币', () async {
      final lid = await seedLedger();
      await seedTxRaw(
          ledgerId: lid, amount: 10, currencyCode: 'USD', nativeAmount: 10);
      await seedTxRaw(
          ledgerId: lid, amount: 20, currencyCode: 'EUR', nativeAmount: 144);
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 1),
      );
      expect(await repo.countUnconvertedForeignTx(lid), 1); // 仅 USD
      expect(await repo.countForeignCurrencyTx(lid), 2); // USD + EUR
    });
  });

  group('getLedgerForeignCurrencies / getUsedCurrencies', () {
    test('空账本:返回空集合', () async {
      final lid = await seedLedger();
      expect(await repo.getLedgerForeignCurrencies(lid), isEmpty);
      expect(await repo.getUsedCurrencies(), isEmpty);
    });

    test('仅本位币:foreignCurrencies 为空, usedCurrencies 包含本位币', () async {
      final lid = await seedLedger();
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 1),
      );
      expect(await repo.getLedgerForeignCurrencies(lid), isEmpty);
      expect(await repo.getUsedCurrencies(), {'CNY'});
    });

    test('混合币种:foreignCurrencies 排除本位币, usedCurrencies 全部', () async {
      final lid = await seedLedger();
      await seedTxRaw(
          ledgerId: lid, amount: 10, currencyCode: 'USD', nativeAmount: 72);
      await seedTxRaw(
          ledgerId: lid, amount: 20, currencyCode: 'EUR', nativeAmount: 144);
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 1),
      );
      expect(await repo.getLedgerForeignCurrencies(lid), {'USD', 'EUR'});
      expect(await repo.getUsedCurrencies(), {'CNY', 'USD', 'EUR'});
    });
  });
}
