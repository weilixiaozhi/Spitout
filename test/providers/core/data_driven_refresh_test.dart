/// 数据驱动刷新契约测试。
///
/// 需求期望：无论从哪条路径写入数据（UI 记账、导入、云端同步、后台任务等），
/// 首页/统计/日历/分类汇总/成员汇总/AA 汇总都必须自动刷新。
/// 本测试刻意绕过 PostProcessor 与任何手动 tick，直接调用 repository 写库，
/// 验证汇总 provider 仅凭“数据库变更信号”即可重算。
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/providers/statistics/aa_statistics_providers.dart';
import 'package:spitout/providers/statistics/calendar_providers.dart';
import 'package:spitout/providers/statistics/statistics_providers.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/ui/avatar_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await repo.createLedger(
      name: '测试账本',
      storageMode: 'local',
      ownerUserId: 'u1',
      aaEnabled: true,
    );
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      spitoutCloudProviderInstance.overrideWith((ref) async => null),
      avatarPathProvider.overrideWith((ref) async => null),
      localSelfIdProvider.overrideWith((ref) async => 'local-self'),
    ]);
    container.read(currentLedgerIdProvider.notifier).set(1);
    addTearDown(container.dispose);
  });

  tearDown(() async => db.close());

  /// 轮询等待条件成立，消除异步流推送与重算的时序抖动。
  Future<void> waitUntil(
    bool Function() predicate, {
    String reason = '等待数据驱动刷新超时',
    // 全量随机顺序跑批时多个测试文件并发执行，真实时间等待可能被调度挤压；
    // 放宽到 15s 只影响超时判定，不断言内容，避免并行负载下的偶发误报。
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        fail(reason);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('直接写库（绕过手动 tick）后，首页/统计/日历/分类/成员/AA 汇总全部自动刷新', () async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 先种一个分类，供分类汇总断言使用（未分类交易不会产生分类行）。
    final categoryId =
        await repo.createCategory(name: '餐饮', kind: 'expense');

    // 保持各汇总 provider 存活，模拟页面持续订阅（autoDispose 下仅 read 会被回收）。
    final subscriptions = <ProviderSubscription<dynamic>>[];
    void keepAlive(ProviderListenable<dynamic> provider) {
      subscriptions.add(container.listen(provider, (_, _) {}));
    }

    keepAlive(monthlyTotalsProvider((ledgerId: 1, month: month)));
    keepAlive(countsForLedgerProvider(1));
    keepAlive(dailyTotalsByMonthProvider((ledgerId: 1, month: month)));
    keepAlive(memberExpenseStatsProvider(1));
    keepAlive(aaStatisticsProvider(1));
    keepAlive(categoriesWithCountProvider);
    addTearDown(() {
      for (final sub in subscriptions) {
        sub.close();
      }
    });

    // 基线：各汇总先加载旧值（0 / 空）。
    await waitUntil(
      () =>
          container
              .read(monthlyTotalsProvider((ledgerId: 1, month: month)))
              .hasValue,
      reason: '月度汇总基线未就绪',
    );
    await waitUntil(
      () => container.read(dailyTotalsByMonthProvider((ledgerId: 1, month: month))).hasValue,
      reason: '日历汇总基线未就绪',
    );
    await waitUntil(
      () => container.read(memberExpenseStatsProvider(1)).hasValue,
      reason: '成员汇总基线未就绪',
    );
    await waitUntil(
      () => container.read(aaStatisticsProvider(1)).hasValue,
      reason: 'AA 汇总基线未就绪',
    );
    await waitUntil(
      () => container.read(categoriesWithCountProvider).hasValue,
      reason: '分类汇总基线未就绪',
    );

    expect(
      container.read(monthlyTotalsProvider((ledgerId: 1, month: month))).value,
      0,
    );
    expect(
      container.read(countsForLedgerProvider(1)).value!.txCount,
      0,
    );
    expect(
      container.read(dailyTotalsByMonthProvider((ledgerId: 1, month: month))).value,
      isEmpty,
    );
    expect(container.read(memberExpenseStatsProvider(1)).value, isEmpty);
    expect(
      container
          .read(aaStatisticsProvider(1))
          .value!
          .participants
          .firstWhere((p) => p.participantId == 'u1')
          .totalPaid,
      0,
    );

    // 关键步骤：绕过 PostProcessor / statsRefresh / calendarRefresh 等一切手动信号，
    // 直接写库——只有“数据库变更信号”能驱动刷新。
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 1234,
      categoryId: categoryId,
      happenedAt: now,
      note: '直接写库',
      paidByUserId: 'u1',
    );

    // 首页月度汇总与账本笔数自动重算。
    await waitUntil(
      () =>
          (container
                  .read(monthlyTotalsProvider((ledgerId: 1, month: month)))
                  .value ??
              0) ==
          12.34,
      reason: '月度汇总未跟随直接写库刷新',
    );
    expect(container.read(countsForLedgerProvider(1)).value!.txCount, 1);
    expect(
      container.read(countsForLedgerProvider(1)).value!.dayCount,
      1,
    );

    // 日历每日金额自动重算。
    await waitUntil(
      () =>
          container
              .read(dailyTotalsByMonthProvider((ledgerId: 1, month: month)))
              .value![dateKey] ==
          12.34,
      reason: '日历每日金额未跟随直接写库刷新',
    );

    // 成员汇总自动重算。
    await waitUntil(
      () =>
          container
              .read(memberExpenseStatsProvider(1))
              .value!
              .any((s) => s.participantId == 'u1' && s.txCount == 1),
      reason: '成员汇总未跟随直接写库刷新',
    );

    // AA 汇总自动重算：实付金额从 0 变为 12.34。
    await waitUntil(
      () =>
          container
              .read(aaStatisticsProvider(1))
              .value!
              .participants
              .firstWhere((p) => p.participantId == 'u1')
              .totalPaid ==
          12.34,
      reason: 'AA 汇总未跟随直接写库刷新',
    );

    // 分类汇总流自动重算：交易笔数从 0 变为 1。
    await waitUntil(
      () {
        final value = container.read(categoriesWithCountProvider).value;
        return value != null &&
            value.any((c) => c.category.id == categoryId && c.transactionCount == 1);
      },
      reason: '分类汇总未跟随直接写库刷新',
    );
  });
}
