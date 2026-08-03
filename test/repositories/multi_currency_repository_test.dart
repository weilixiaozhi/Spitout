/// 交易级多币种 — Repository 层契约:
///   - addTransaction 带折算兜底:同币种=amount;外币先查有效汇率,
///     取不到才 =amount
///   - updateTransaction 联动(与 Cloud merge/mutator 同规则):不传两字段
///     且 amount 变了 → 按隐含汇率联动;改备注不动快照
///   - recompute/recalc/count:补折算/全量重算/检测,逐笔记 change
library;

import 'package:flutter_test/flutter_test.dart';
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

  Future<int> seedLedger({String currency = 'CNY'}) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency, storage_mode) VALUES (1, 'L', '$currency', 'cloud')");
    return 1;
  }

  Future<void> seedUsdRates() => repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-07-10',
        rates: {'USD': '7.2'},
        source: 'test',
        fetchedAt: DateTime.utc(2026, 7, 10),
      );

  group('addTransaction 带折算兜底', () {
    test('不传两字段+本位币 → currencyCode=本位币, nativeAmount=amount', () async {
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

    test('不传 nativeAmount+外币+有汇率 → nativeAmount=折算值', () async {
      final lid = await seedLedger();

      await seedUsdRates();
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

    test('不传 nativeAmount+外币+无汇率 → nativeAmount=amount(命中补折算检测)', () async {
      final lid = await seedLedger();

      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        happenedAt: DateTime(2026, 7, 12),
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.currencyCode, 'USD');
      expect(tx.nativeAmount, 12);
      expect(await repo.countUnconvertedForeignTx(lid), 1);
    });

    test('显式传外币两字段 → 原样写入(UI 手改汇率快照)', () async {
      final lid = await seedLedger();

      final id = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,

        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 87.0, // 用户手改的汇率快照
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.nativeAmount, 87.0);
    });

    test('无账户交易显式传币种 → 写入所选;不传 → 本位币', () async {
      final lid = await seedLedger();
      await seedUsdRates();
      final id1 = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime(2026, 7, 12),
        currencyCode: 'USD',
        nativeAmount: 86.4,
      );
      expect((await repo.getTransactionById(id1))!.currencyCode, 'USD');

      final id2 = await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 5,
        happenedAt: DateTime(2026, 7, 12),
      );
      final tx2 = await repo.getTransactionById(id2);
      expect(tx2!.currencyCode, 'CNY');
      expect(tx2.nativeAmount, 5);
    });
  });

  group('updateTransaction 联动兜底(App 侧镜像)', () {
    test('不传两字段只改金额 → 外币按隐含汇率缩放', () async {
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
      expect(tx.nativeAmount, closeTo(172.8, 1e-9));
    });

    test('金额未变(改备注)→ 快照不动', () async {
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
      expect(tx.nativeAmount, 86.4);
    });

    test('显式传 nativeAmount → 以传入为准(不联动)', () async {
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
          id: id,
          type: 'expense',
          amount: 24,
          currencyCode: 'USD',
          nativeAmount: 170.0);
      expect((await repo.getTransactionById(id))!.nativeAmount, 170.0);
    });
  });

  group('补折算 / 全量重算 / 检测', () {
    test('recompute 只补「未折算外币」;已折算/本位币不动;返回条数', () async {
      final lid = await seedLedger();

      await seedUsdRates();
      // 未折算外币(native==amount,模拟迁移回填态)
      final unconverted = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 10,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'USD', nativeAmount: 10,
      );
      // 已折算外币(不许覆盖)
      final converted = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 12,
        happenedAt: DateTime(2026, 7, 2),
        currencyCode: 'USD', nativeAmount: 86.4,
      );
      // 本位币(不动)
      final cny = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 3),
      );

      final n = await repo.recomputeForeignTxForLedger(lid);
      expect(n, 1);
      expect((await repo.getTransactionById(unconverted))!.nativeAmount,
          closeTo(72.0, 1e-9)); // 10 × 7.2
      expect((await repo.getTransactionById(converted))!.nativeAmount, 86.4);
      expect((await repo.getTransactionById(cny))!.nativeAmount, 50);
      expect(await repo.countUnconvertedForeignTx(lid), 0); // 横幅消失
    });

    test('纯本位币账本 recompute 返回 0、无改动', () async {
      final lid = await seedLedger();
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 3),
      );
      expect(await repo.recomputeForeignTxForLedger(lid), 0);
    });

    test('recalc 全量按新本位币重算', () async {
      final lid = await seedLedger(); // 本位币 CNY

      // 改本位币为 USD 后:CNY 交易要折 USD、USD 交易对齐 =amount
      await repo.upsertAutoRates(
        base: 'USD',
        rateDate: '2026-07-10',
        rates: {'CNY': '0.14'},
        source: 'test',
        fetchedAt: DateTime.utc(2026, 7, 10),
      );
      final usdTx = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 12,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'USD', nativeAmount: 86.4, // 旧本位币 CNY 的快照
      );
      final cnyTx = await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 100,
        happenedAt: DateTime(2026, 7, 2),
        currencyCode: 'CNY', nativeAmount: 100,
      );

      final n = await repo.recalcNativeAmountsForLedger(lid, 'USD');
      expect(n, 2);
      expect((await repo.getTransactionById(usdTx))!.nativeAmount, 12); // 对齐原币
      expect((await repo.getTransactionById(cnyTx))!.nativeAmount,
          closeTo(14.0, 1e-9)); // 100 × 0.14
    });

    test('重算逐笔记 change:pending 条数 == 改动笔数', () async {
      db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      final tracker = ChangeTracker(db);
      repo = LocalRepository(db, changeTracker: tracker);
      final lid = await seedLedger();

      await seedUsdRates();
      await repo.addTransaction(
        ledgerId: lid, type: 'expense', amount: 10,
        happenedAt: DateTime(2026, 7, 1),
        currencyCode: 'USD', nativeAmount: 10,
      );
      final before = (await db.select(db.localChanges).get()).length;
      final n = await repo.recomputeForeignTxForLedger(lid);
      expect(n, 1);
      final after = (await db.select(db.localChanges).get()).length;
      expect(after - before, 1, reason: '重算必须逐笔记 change,否则云端投影不更新');
    });
  });
}
