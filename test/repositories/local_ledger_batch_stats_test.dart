/// 账本列表批量统计接口（getAllLedgerStats）单元测试。
///
/// 锁定行为：
/// - 单条聚合 SQL 一次返回全部账本的 COUNT + SUM，与逐本 getLedgerStats 口径一致；
/// - 金额按 `COALESCE(native_amount, amount)` 折本位币，输出单位统一为"元"；
/// - 没有交易的账本不出现在返回 Map 中（调用方按 0/0 兜底）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  test('批量统计：多账本一次返回，金额折 nativeAmount 并转元', () async {
    // 账本 1：外币 $12(≈86.4) + 本位币 ¥100，共 2 笔 → 186.4 元
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'A', 'CNY')");
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 1200,
      happenedAt: DateTime(2026, 7, 5),
      currencyCode: 'USD',
      nativeAmount: 8640,
    );
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 10000,
      happenedAt: DateTime(2026, 7, 6),
    );

    // 账本 2：3 笔，合计 80 元
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (2, 'B', 'CNY')");
    await repo.addTransaction(
      ledgerId: 2,
      type: 'expense',
      amount: 3000,
      happenedAt: DateTime(2026, 7, 5),
    );
    await repo.addTransaction(
      ledgerId: 2,
      type: 'expense',
      amount: 5000,
      happenedAt: DateTime(2026, 7, 6),
    );
    await repo.addTransaction(
      ledgerId: 2,
      type: 'expense',
      amount: 0,
      happenedAt: DateTime(2026, 7, 7),
    );

    // 账本 3：无交易，不应出现在批量结果中
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (3, 'C', 'CNY')");

    final stats = await repo.getAllLedgerStats();

    expect(stats.keys, containsAll([1, 2]));
    expect(stats.containsKey(3), isFalse,
        reason: '无交易账本不占位，调用方按 0/0 兜底');
    expect(stats[1]!.expenseTotal, closeTo(186.4, 1e-9),
        reason: '批量口径与 getLedgerStats 一致：折 nativeAmount 后转元');
    expect(stats[1]!.transactionCount, 2);
    expect(stats[2]!.expenseTotal, 80.0);
    expect(stats[2]!.transactionCount, 3);
  });

  test('批量统计与逐本 getLedgerStats 结果一致（回归锁）', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'A', 'CNY')");
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 1234,
      happenedAt: DateTime(2026, 7, 5),
    );
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 8766,
      happenedAt: DateTime(2026, 7, 6),
    );

    final batch = await repo.getAllLedgerStats();
    final single = await repo.getLedgerStats(ledgerId: 1);

    expect(batch[1]!.expenseTotal, single.expenseTotal);
    expect(batch[1]!.transactionCount, single.transactionCount);
  });
}
