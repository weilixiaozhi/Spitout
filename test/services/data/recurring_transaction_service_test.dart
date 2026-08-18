// RecurringTransactionService 生成逻辑回归测试。
//
// 锁死两件事:
//  1. issue #135:历史开始日期不回溯补生成脏数据(从未生成只产出"今天"一笔)。
//  2. 2026-06「每天周期不生效」修复:从未生成过的周期账单首笔落在"今天"(含今天),
//     而非被推到明天导致永远不触发。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/services/data/recurring_transaction_service.dart';

class _MockRepo extends Mock implements LocalRepository {}

/// 构造一个便于注入 now 的周期模板（lastGeneratedDate 非空，绕开 #135 今天钳制）。
RecurringTransaction recurringRow({
  int id = 1,
  int ledgerId = 1,
  int amount = 1000,
  String frequency = 'daily',
  int interval = 1,
  int? dayOfMonth,
  int? monthOfYear,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? lastGeneratedDate,
  bool enabled = true,
}) {
  return RecurringTransaction(
    id: id,
    ledgerId: ledgerId,
    type: 'expense',
    amount: amount,
    categoryId: null,
    frequency: frequency,
    interval: interval,
    dayOfMonth: dayOfMonth,
    monthOfYear: monthOfYear,
    startDate: startDate ?? DateTime(2025, 1, 1),
    endDate: endDate,
    lastGeneratedDate: lastGeneratedDate,
    enabled: enabled,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    // LoggerService(被周期服务调用)内部走 SharedPreferences,单测需提供 mock,
    // 否则 logger.info 触发 MissingPluginException 让测试在完成后异步失败。
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'test', currency: 'CNY');
  });

  tearDown(() async {
    await db.close();
  });

  test('账本换币或模板跨币种账本后，生成交易仍按模板原币种折算', () async {
    await repo.upsertAutoRates(
      base: 'USD',
      rateDate: '2026-08-18',
      rates: const {'CNY': '0.14'},
      source: 'test',
      fetchedAt: DateTime.utc(2026, 8, 18),
    );

    // 场景一：账本本位币从 CNY 改成 USD，模板金额仍是创建时的 CNY。
    final switchedId = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 10000,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime(2026, 8, 1),
    );
    await repo.updateLedger(id: ledgerId, currency: 'USD');
    final switched = (await repo.getAllRecurringTransactions()).singleWhere(
      (r) => r.id == switchedId,
    );
    final switchedTxId = await repo.generateRecurringTransaction(
      recurring: switched,
      happenedAt: DateTime(2026, 8, 18),
    );
    final switchedTx = await repo.getTransactionById(switchedTxId);
    expect(switched.currencyCode, 'CNY');
    expect(switchedTx?.currencyCode, 'CNY');
    expect(switchedTx?.nativeAmount, 1400);

    // 场景二：把 CNY 模板移到 USD 账本，未显式改币种时必须保留 CNY。
    final sourceLedgerId = await repo.createLedger(
      name: 'source-cny',
      currency: 'CNY',
    );
    final targetLedgerId = await repo.createLedger(
      name: 'target-usd',
      currency: 'USD',
    );
    final movedId = await repo.addRecurringTransaction(
      ledgerId: sourceLedgerId,
      type: 'expense',
      amount: 20000,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime(2026, 8, 1),
    );
    await repo.updateRecurringTransaction(
      id: movedId,
      ledgerId: targetLedgerId,
      type: 'expense',
      amount: 20000,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime(2026, 8, 1),
    );
    final moved = (await repo.getAllRecurringTransactions()).singleWhere(
      (r) => r.id == movedId,
    );
    final movedTxId = await repo.generateRecurringTransaction(
      recurring: moved,
      happenedAt: DateTime(2026, 8, 18),
    );
    final movedTx = await repo.getTransactionById(movedTxId);
    expect(moved.currencyCode, 'CNY');
    expect(movedTx?.ledgerId, targetLedgerId);
    expect(movedTx?.currencyCode, 'CNY');
    expect(movedTx?.nativeAmount, 2800);
  });

  group('calculateNextDate 频率与边界', () {
    final service = RecurringTransactionService(_MockRepo());

    test('weekly：上次生成 + 7*interval 天，未到期返回 null', () {
      final due = service.calculateNextDate(
        recurringRow(
          frequency: 'weekly',
          lastGeneratedDate: DateTime(2026, 1, 1),
        ),
        now: DateTime(2026, 1, 9),
      );
      expect(due, DateTime(2026, 1, 8), reason: '上周三后应在周三生成');

      final notDue = service.calculateNextDate(
        recurringRow(
          frequency: 'weekly',
          lastGeneratedDate: DateTime(2026, 1, 1),
        ),
        now: DateTime(2026, 1, 7),
      );
      expect(notDue, isNull, reason: '尚未到下个周期日不生成');
    });

    test('weekly：interval=2 推 14 天', () {
      final due = service.calculateNextDate(
        recurringRow(
          frequency: 'weekly',
          interval: 2,
          lastGeneratedDate: DateTime(2026, 1, 1),
        ),
        now: DateTime(2026, 1, 20),
      );
      expect(due, DateTime(2026, 1, 15));
    });

    test('monthly：上次生成后按目标日推进；interval=2 推两个月', () {
      final due = service.calculateNextDate(
        recurringRow(
          frequency: 'monthly',
          interval: 2,
          dayOfMonth: 20,
          lastGeneratedDate: DateTime(2026, 1, 20),
        ),
        now: DateTime(2026, 3, 20),
      );
      expect(due, DateTime(2026, 3, 20), reason: '每 2 个月 → 1/20 后为 3/20');
    });

    test('monthly：目标日不存在时夹到月末（2月无 31 日 → 2/28）', () {
      final due = service.calculateNextDate(
        recurringRow(
          frequency: 'monthly',
          dayOfMonth: 31,
          lastGeneratedDate: DateTime(2026, 1, 31),
        ),
        now: DateTime(2026, 3, 1),
      );
      expect(due, DateTime(2026, 2, 28), reason: '2026 非闰年，2 月夹到 28 日');
    });

    test('yearly：按年推进；闰年 2/29 夹到平年 2/28', () {
      final due = service.calculateNextDate(
        recurringRow(
          frequency: 'yearly',
          dayOfMonth: 5,
          monthOfYear: 5,
          lastGeneratedDate: DateTime(2025, 5, 5),
        ),
        now: DateTime(2026, 5, 5),
      );
      expect(due, DateTime(2026, 5, 5));

      final leapClamped = service.calculateNextDate(
        recurringRow(
          frequency: 'yearly',
          dayOfMonth: 29,
          monthOfYear: 2,
          lastGeneratedDate: DateTime(2024, 2, 29),
        ),
        now: DateTime(2025, 3, 1),
      );
      expect(leapClamped, DateTime(2025, 2, 28),
          reason: '平年无 2/29，夹到 2/28');
    });

    test('已过结束日期直接跳过；下个周期日超过结束日期也跳过', () {
      final expired = service.calculateNextDate(
        recurringRow(
          endDate: DateTime(2026, 1, 1),
          lastGeneratedDate: DateTime(2025, 12, 1),
        ),
        now: DateTime(2026, 1, 2),
      );
      expect(expired, isNull);

      final overEnd = service.calculateNextDate(
        recurringRow(
          endDate: DateTime(2026, 1, 1, 23),
          lastGeneratedDate: DateTime(2026, 1, 1),
        ),
        now: DateTime(2026, 1, 1, 22),
      );
      expect(overEnd, isNull,
          reason: '结束日期未过期但下一个周期日 1/2 已晚于 1/1 23:00');
    });
  });

  group('generatePendingTransactionsStatic 静态入口', () {
    test('无待生成时返回空集合', () async {
      final result = await RecurringTransactionService
          .generatePendingTransactionsStatic(repository: repo);
      expect(result, isEmpty);
    });

    test('有生成时返回涉及账本 ID 集合', () async {
      await repo.addRecurringTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 1000,
        frequency: 'daily',
        interval: 1,
        startDate: DateTime.now(),
      );
      final result = await RecurringTransactionService
          .generatePendingTransactionsStatic(repository: repo);
      expect(result, {ledgerId});
    });

    test('repository 抛错时吞掉异常并返回空集合', () async {
      final broken = _MockRepo();
      when(() => broken.getAllLedgers()).thenThrow(Exception('db down'));
      final result = await RecurringTransactionService
          .generatePendingTransactionsStatic(repository: broken);
      expect(result, isEmpty, reason: '启动扫描不允许把异常抛到上层');
    });
  });

  group('generatePendingTransactions 扫描行为', () {
    test('禁用模板不生成', () async {
      await repo.addRecurringTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 1000,
        frequency: 'daily',
        interval: 1,
        startDate: DateTime.now(),
        enabled: false,
      );
      final generated =
          await RecurringTransactionService(repo).generatePendingTransactions();
      expect(generated, isEmpty);
    });

    test('多账本分别生成', () async {
      final secondLedgerId = await repo.createLedger(name: 'test2', currency: 'CNY');
      await repo.addRecurringTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 1000,
        frequency: 'daily',
        interval: 1,
        startDate: DateTime.now(),
      );
      await repo.addRecurringTransaction(
        ledgerId: secondLedgerId,
        type: 'expense',
        amount: 2000,
        frequency: 'daily',
        interval: 1,
        startDate: DateTime.now(),
      );
      final generated =
          await RecurringTransactionService(repo).generatePendingTransactions();
      expect(generated, hasLength(2));
      expect(generated.map((t) => t.ledgerId).toSet(),
          {ledgerId, secondLedgerId});
    });
  });

  group('描述工具方法', () {
    final service = RecurringTransactionService(_MockRepo());

    test('getFrequencyDescription 透传翻译器', () {
      final text = service.getFrequencyDescription(
        recurringRow(frequency: 'weekly', interval: 2),
        (freq, interval) => '${freq.value}/$interval',
      );
      expect(text, 'weekly/2');
    });

    test('getNextGenerationDescription：到期格式化，未到期返回 null', () {
      final due = service.getNextGenerationDescription(
        recurringRow(
          frequency: 'daily',
          lastGeneratedDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
        (date) => date.toIso8601String(),
      );
      expect(due, isNotNull);

      final notDue = service.getNextGenerationDescription(
        recurringRow(
          frequency: 'daily',
          lastGeneratedDate: DateTime.now().subtract(const Duration(days: 2)),
          endDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
        (date) => date.toIso8601String(),
      );
      expect(notDue, isNull);
    });
  });

  // 断言某 DateTime 是"今天"(本地零点)。
  void expectIsToday(DateTime d) {
    final now = DateTime.now();
    expect(d.year, now.year);
    expect(d.month, now.month);
    expect(d.day, now.day);
  }

  test('历史开始日期(30天前)+ 从未生成 → 只产出今天一笔,不回溯补历史(#135 + 含今天)', () async {
    // 修复前(老 bug):base 锁今天、daily 首笔=明天 → isAfter(now) → 一笔都不生成,
    // 且 lastGeneratedDate 永远为 null → 永久卡死("每天周期不生效")。
    // 修复后:首笔=基准日(今天),生成且仅生成"今天"这一笔,不补 30 天历史。
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1000,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, hasLength(1)); // 仅今天,不是 30 笔,也不是 0 笔
    expectIsToday(generated.first.happenedAt);
  });

  test('开始日期=昨天 + 从未生成 → 今天打开生成今天一笔(用户反馈场景)', () async {
    // 用户反馈:起始时间设为昨天,今天打开无法生成 —— 同一根因。
    // 修复后:生成"今天"这一笔(昨天那笔按 #135 不回溯)。
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1000,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, hasLength(1));
    expectIsToday(generated.first.happenedAt);
  });

  test('已生成过(lastGeneratedDate=昨天)→ 正常补出今天一笔', () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1000,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    await repo.updateLastGeneratedDate(id, yesterday);

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    // 昨天 → 今天一笔(daily);明天还没到,停在这。
    expect(generated, hasLength(1));
    expectIsToday(generated.first.happenedAt);
  });

  test('今天已生成过(lastGeneratedDate=今天)→ 不重复生成', () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1000,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await repo.updateLastGeneratedDate(id, today);

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, isEmpty); // 今天已生成,明天才下一笔
  });

  test('开始日期在未来(明天)→ 今天不生成', () async {
    await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1000,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().add(const Duration(days: 1)),
    );

    final service = RecurringTransactionService(repo);
    final generated = await service.generatePendingTransactions();

    expect(generated, isEmpty); // 未来开始,首笔在明天
  });

  test('编辑周期模板不清空 lastGeneratedDate,仅显式重置时清空', () async {
    final id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1000,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    await repo.updateLastGeneratedDate(id, yesterday);

    // 普通编辑不传 clearLastGeneratedDate:锚点必须保留,否则下次扫描会重生成。
    await repo.updateRecurringTransaction(
      id: id,
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1200,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    var row = await (db.select(
      db.recurringTransactions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.lastGeneratedDate, yesterday);

    // 仅当页面判定需要重置(如开始日期早于最后生成日期)时显式清空。
    await repo.updateRecurringTransaction(
      id: id,
      ledgerId: ledgerId,
      type: 'expense',
      amount: 1200,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      clearLastGeneratedDate: true,
    );
    row = await (db.select(
      db.recurringTransactions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.lastGeneratedDate, isNull);
  });
}
