import 'package:spitout/data/db.dart' show Category;

/// 统计Repository接口
/// 定义统计相关的所有数据操作
abstract class StatisticsRepository {
  /// 按分类统计（指定时间范围和类型）
  Future<List<({int? id, String name, String? icon, double total})>> totalsByCategory({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  });

  /// 按分类统计（支持二级分类展开）
  Future<List<({int? id, String name, String? icon, int? parentId, int level, double total})>>
      totalsByCategoryWithHierarchy({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  });

  /// 按天统计（指定时间范围和类型）
  Future<List<({DateTime day, double total})>> totalsByDay({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  });

  /// 按月统计（指定年份和类型）
  ///
  /// [month] 为周期标签,约定传 DateTime(year, month, 1);实际范围由账本
  /// monthStartDay 决定:[y-m-起始日, y-(m+1)-起始日)。
  /// 返回的 12 桶为周期标签月,范围 = 账本起始日定义的
  /// [当年1月周期起点, 次年1月周期起点)。
  Future<List<({DateTime month, double total})>> totalsByMonth({
    required int ledgerId,
    required String type,
    required int year,
  });

  /// 按年统计（所有年份，指定类型）
  Future<List<({int year, double total})>> totalsByYearSeries({
    required int ledgerId,
    required String type,
  });

  /// 获取该账本最早一笔支出交易的 happened_at（本地时区）。
  /// 无数据返回 null。用于统计页子 Tab 按真实数据范围生成。
  Future<DateTime?> earliestExpenseDate({required int ledgerId});

  /// 获取该账本最晚一笔支出交易的 happened_at（本地时区）。
  /// 无数据返回 null。用于统计页子 Tab 默认定位最新数据。
  Future<DateTime?> latestExpenseDate({required int ledgerId});

  /// 获取该账本是否存在任意支出交易（excludeFromStats=false）。
  /// 用于统计页区分「全局空数据」与「局部空数据」。
  Future<bool> hasAnyExpenseTx({required int ledgerId});

  /// 获取指定时间范围的支出总额（全局仅支出模式）
  Future<double> totalsInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  });

  /// 获取指定月份的支出总额
  ///
  /// [month] 为周期标签,约定传 DateTime(year, month, 1);实际范围由账本
  /// monthStartDay 决定:[y-m-起始日, y-(m+1)-起始日)。
  Future<double> monthlyTotals({
    required int ledgerId,
    required DateTime month,
  });

  /// 获取今日(本地时区自然日 0:00 - 次日 0:00)的支出总额。
  /// 不依赖账本 monthStartDay —— 今日/本周是固定自然日/自然周语义,
  /// 复用 totalsInRange 的聚合逻辑(nativeAmount ?? amount,仅支出,排除 excludeFromStats)。
  /// 对应设计稿首页"本月支出汇总卡"的"今日"列。
  Future<double> todayExpense({
    required int ledgerId,
    required DateTime now,
  });

  /// 获取本周(周一 0:00 - 下周一 0:00)的支出总额。
  /// 周一为一周起始(weekday=1),与设计稿"本周"语义一致。
  /// 对应设计稿首页"本月支出汇总卡"的"本周"列。
  Future<double> weekExpense({
    required int ledgerId,
    required DateTime now,
  });

  /// 获取指定年份的支出总额
  Future<double> yearlyTotals({
    required int ledgerId,
    required int year,
  });

  /// 返回该账本的 SharedLedgerCategories 行转 synthetic
  /// db.Category 索引(key = syntheticIdForSyncId(syncId))。统计页拿
  /// 这个 map 给 totalsByCategory 返回的 negative id 配上图标 / 自定义
  /// 图标路径。单人账本返回空 map。
  Future<Map<int, Category>> getSharedSyntheticCategoriesForLedger(
      int ledgerId);
}
