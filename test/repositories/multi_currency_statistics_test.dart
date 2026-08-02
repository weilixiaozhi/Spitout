/// 账本维度统计折本位币:
///   - builder 路径(totalsByMonth 代表)与 SQL 路径(monthlyTotals/totalsInRange
///     代表)均按 nativeAmount ?? amount 汇总
///   - 单币种账本(native==amount)结果与旧口径一致(回归锁)
///   - NULL native(绕过 repo 的历史写入)COALESCE 回退 amount
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import '../helpers/test_isolation.dart';

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

  /// CNY 账本;7 月两笔支出:外币 $12(≈86.4)+ 本位币 ¥100。
  Future<int> seedMixed() async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await repo.addTransaction(
      ledgerId: 1, type: 'expense', amount: 12,
      happenedAt: DateTime(2026, 7, 5),
      currencyCode: 'USD', nativeAmount: 86.4,
    );
    await repo.addTransaction(
      ledgerId: 1, type: 'expense', amount: 100,
      happenedAt: DateTime(2026, 7, 6),
    );
    return 1;
  }

  test('builder 路径(totalsByMonth):多币种账本按 nativeAmount 汇总', () async {
    final lid = await seedMixed();
    final rows = await repo.totalsByMonth(
        ledgerId: lid, year: 2026, type: 'expense');
    final july = rows.firstWhere((r) => r.month.month == 7);
    expect(july.total, closeTo(186.4, 1e-9)); // 86.4 + 100,非 112
  });

  test('SQL 路径(monthlyTotals/totalsInRange):按 COALESCE(native,amount)', () async {
    final lid = await seedMixed();
    // monthlyTotals 现在只返回支出金额（double）
    final me = await repo.monthlyTotals(
        ledgerId: lid, month: DateTime(2026, 7, 1));
    expect(me, closeTo(186.4, 1e-9));

    // totalsInRange 现在只返回支出金额（double）
    final re = await repo.totalsInRange(
        ledgerId: lid,
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1));
    expect(re, closeTo(186.4, 1e-9));
  });

  test('单币种账本:统计与旧口径一致(回归锁)', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (2, 'S', 'CNY')");
    // 全局仅支出模式：两笔均为支出，合计 80
    await repo.addTransaction(
        ledgerId: 2, type: 'expense', amount: 30,
        happenedAt: DateTime(2026, 7, 5));
    await repo.addTransaction(
        ledgerId: 2, type: 'expense', amount: 50,
        happenedAt: DateTime(2026, 7, 6));
    // monthlyTotals 现在只返回支出金额（double）
    final expense =
        await repo.monthlyTotals(ledgerId: 2, month: DateTime(2026, 7, 1));
    expect(expense, 80);
  });

  test('NULL native(绕过 repo 写入的历史行)COALESCE 回退 amount', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (3, 'N', 'CNY')");
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, happened_at) "
        "VALUES (300, 3, 'expense', 42.0, ${DateTime(2026, 7, 5).millisecondsSinceEpoch ~/ 1000})");
    // monthlyTotals 现在只返回支出金额（double）
    final expense =
        await repo.monthlyTotals(ledgerId: 3, month: DateTime(2026, 7, 1));
    expect(expense, 42.0);
  });

  test('getLedgerStats 账本支出总额折 nativeAmount(账本维度,反馈:改主币种要更新)', () async {
    final lid = await seedMixed();
    // CNY 账本 + USD $12(native 86.4) + 本位币支出 100 → 支出总额 = 86.4+100
    final stats = await repo.getLedgerStats(ledgerId: lid);
    expect(stats.expenseTotal, closeTo(186.4, 1e-9),
        reason: '支出总额是账本维度,须折本位币;裸加原币会得 112');
  });
}
