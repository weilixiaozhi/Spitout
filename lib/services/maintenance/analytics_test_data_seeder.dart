import 'dart:math';

import '../../data/repositories/base_repository.dart';

/// 测试数据填充范围：按年 / 月 / 周 / 日生成支出交易（debug 包专用）。
enum TestDataScope {
  /// 全年 12 个月
  year,

  /// 当前整月
  month,

  /// 当前所在周（周一对齐）
  week,

  /// 当日
  day,
}

/// 统计页调试用测试数据填充器。
///
/// 仅用于 debug 构建，在首页「一键填充」按钮触发，便于在无真实账单时
/// 验证统计页各周期（年/月/周/日）的图表、环图、列表渲染。
///
/// 设计要点：
/// - 随机币种（含本位币与外币）与随机金额，覆盖多币种统计路径；
/// - 随机分配到账本可用支出分类，保证分类排行有数据；
/// - 直接走 BaseRepository.addTransaction，复用既有写入/变更追踪逻辑。
class AnalyticsTestDataSeeder {
  final BaseRepository repo;

  AnalyticsTestDataSeeder(this.repo);

  final Random _rand = Random();

  // 覆盖本位币 CNY 与若干常见外币，确保统计聚合进入多币种分支
  static const List<String> _currencies = [
    'CNY',
    'USD',
    'JPY',
    'EUR',
    'GBP',
    'HKD',
  ];

  /// 按指定范围填充测试支出交易，返回实际插入条数。
  Future<int> fill({
    required int ledgerId,
    required String baseCurrency,
    required TestDataScope scope,
  }) async {
    // 取账本可用支出分类；为空时自建一个兜底分类，避免插入因 categoryId 缺失失败
    final cats = await repo.getUsableCategories('expense');
    var catIds = cats.map((c) => c.id).toList();
    if (catIds.isEmpty) {
      final id =
          await repo.upsertCategory(name: '测试填充', kind: 'expense');
      catIds = [id];
    }

    final now = DateTime.now();
    final List<_Plan> plan = [];

    switch (scope) {
      case TestDataScope.year:
        // 全年 12 个月，每月随机 8 笔，分散在不同日
        for (int m = 1; m <= 12; m++) {
          final daysInMonth = DateTime(now.year, m + 1, 1)
              .difference(DateTime(now.year, m, 1))
              .inDays;
          for (int i = 0; i < 8; i++) {
            final day = 1 + _rand.nextInt(daysInMonth);
            plan.add(_gen(
              DateTime(now.year, m, day, _rand.nextInt(24), _rand.nextInt(60)),
              baseCurrency,
            ));
          }
        }
      case TestDataScope.month:
        final daysInMonth = DateTime(now.year, now.month + 1, 1)
            .difference(DateTime(now.year, now.month, 1))
            .inDays;
        for (int i = 0; i < 40; i++) {
          final day = 1 + _rand.nextInt(daysInMonth);
          plan.add(_gen(
            DateTime(now.year, now.month, day, _rand.nextInt(24), _rand.nextInt(60)),
            baseCurrency,
          ));
        }
      case TestDataScope.week:
        // 以周一为一周起点，覆盖 7 天
        final ws = _mondayOf(now);
        for (int d = 0; d < 7; d++) {
          for (int i = 0; i < 4; i++) {
            plan.add(_gen(
              DateTime(ws.year, ws.month, ws.day + d, _rand.nextInt(24),
                  _rand.nextInt(60)),
              baseCurrency,
            ));
          }
        }
      case TestDataScope.day:
        for (int i = 0; i < 12; i++) {
          plan.add(_gen(
            DateTime(now.year, now.month, now.day, _rand.nextInt(24),
                _rand.nextInt(60)),
            baseCurrency,
          ));
        }
    }

    var inserted = 0;
    for (final p in plan) {
      final catId = catIds[_rand.nextInt(catIds.length)];
      final isForeign = p.currency != baseCurrency;
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: p.amount,
        categoryId: catId,
        happenedAt: p.when,
        note: '测试填充',
        // 外币：带上币种与原始金额，命中统计多币种聚合路径
        currencyCode: isForeign ? p.currency : null,
        nativeAmount: isForeign ? p.amount : null,
      );
      inserted++;
    }
    return inserted;
  }

  /// 生成一条随机金额 / 随机币种的计划项
  _Plan _gen(DateTime when, String base) {
    final currency = _currencies[_rand.nextInt(_currencies.length)];
    // 金额量级相近即可，统计聚合按 amount 求和
    final amount = (10 + _rand.nextInt(990)) + _rand.nextDouble();
    return _Plan(when: when, amount: amount, currency: currency);
  }

  /// 取某日期所在周的周一（周一为一周起点）
  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
}

class _Plan {
  final DateTime when;
  final double amount;
  final String currency;

  _Plan({
    required this.when,
    required this.amount,
    required this.currency,
  });
}
