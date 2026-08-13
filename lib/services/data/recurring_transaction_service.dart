import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/core/logging/logger_service.dart';

/// 重复交易服务
///
/// 注意：此服务主要用于生成待处理的周期交易记录
/// 基础的 CRUD 操作请使用 LocalRepository
///
class RecurringTransactionService {
  static const _tag = 'Recurring';

  final LocalRepository repository;

  RecurringTransactionService(this.repository);

  /// 静态方法：生成待处理的重复交易（供启动时和初始化时调用）
  ///
  /// [verbose] 是否打印详细日志
  ///
  /// 返回：生成了交易的账本ID集合（用于触发同步）
  static Future<Set<int>> generatePendingTransactionsStatic({
    required LocalRepository repository,
    bool verbose = false,
  }) async {
    try {
      logger.info(_tag,
          '开始生成待处理的重复交易 (Repository=${repository.runtimeType}, verbose=$verbose)');

      final service = RecurringTransactionService(repository);
      final generatedTransactions = await service.generatePendingTransactions();

      if (generatedTransactions.isNotEmpty) {
        final ledgerIds = generatedTransactions.map((t) => t.ledgerId).toSet();
        logger.info(_tag,
            '本次共生成 ${generatedTransactions.length} 条重复交易,涉及账本 $ledgerIds');
        return ledgerIds;
      } else {
        logger.info(_tag, '本次没有需要生成的重复交易');
        return {};
      }
    } catch (e, stackTrace) {
      // 不抛出异常，避免影响应用启动
      logger.error(_tag, '生成重复交易失败', e, stackTrace);
      return {};
    }
  }

  /// 计算下一次应该生成交易的日期。返回 null 表示本次无需生成。
  ///
  /// [now] 仅用于测试注入"当前时间";正常调用走 `DateTime.now()`。
  ///
  /// 关键口径:
  /// - **包含今天**:`nextDate <= now`(当天 00:00 <= 此刻)即生成;若用
  ///   `base + interval` 会把首笔推到明天,导致从未生成过的 daily 不触发。
  /// - **从未生成(lastGenerated==null)→ 首笔就落在基准日本身**(不加 interval),
  ///   基准日受 issue #135 保护不早于今天零点 → 既"包含今天"又不回溯补历史。
  /// - **已生成过 → 上次生成日 + interval**(月/年按目标日推进)。
  DateTime? calculateNextDate(RecurringTransaction recurring, {DateTime? now}) {
    final nowTs = now ?? DateTime.now();
    final lastGenerated = recurring.lastGeneratedDate;
    final frequency = RecurringFrequency.fromString(recurring.frequency);
    final interval = recurring.interval;
    final firstGen = lastGenerated == null;

    // 如果有结束日期且已过期，返回null
    if (recurring.endDate != null && nowTs.isAfter(recurring.endDate!)) {
      logger.info(_tag,
          'calc id=${recurring.id} 跳过:已过结束日期 endDate=${recurring.endDate}');
      return null;
    }

    // 基准日期：最后生成日期 或 开始日期。
    // 防止历史开始日期回溯补生成脏数据(issue #135):从未生成过(lastGenerated
    // 为 null)的周期账单,基准不早于今天零点,只生成"今天"这一笔,不补历史。
    final todayStart = DateTime(nowTs.year, nowTs.month, nowTs.day);
    final rawBase = lastGenerated ?? recurring.startDate;
    final baseDate =
        firstGen && rawBase.isBefore(todayStart) ? todayStart : rawBase;

    DateTime nextDate;
    switch (frequency) {
      case RecurringFrequency.daily:
        // 首笔=基准日(含今天);之后=上次+interval 天
        nextDate =
            firstGen ? baseDate : baseDate.add(Duration(days: interval));
        break;

      case RecurringFrequency.weekly:
        nextDate =
            firstGen ? baseDate : baseDate.add(Duration(days: 7 * interval));
        break;

      case RecurringFrequency.monthly:
        // 月度重复：落在指定的"几号"。首笔取基准月当月,之后推进 interval 个月。
        final targetDay = recurring.dayOfMonth ?? baseDate.day;
        DateTime buildMonthly(int year, int month) {
          while (month > 12) {
            month -= 12;
            year += 1;
          }
          // 处理不存在的日期（如2月30日）
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final day = targetDay > daysInMonth ? daysInMonth : targetDay;
          return DateTime(year, month, day);
        }

        nextDate = buildMonthly(baseDate.year, baseDate.month + (firstGen ? 0 : interval));
        // 首笔:若当月目标日早于基准(本月已过)→ 顺延一个 interval 月,避免回溯
        if (firstGen && nextDate.isBefore(baseDate)) {
          nextDate = buildMonthly(baseDate.year, baseDate.month + interval);
        }
        break;

      case RecurringFrequency.yearly:
        // 年度重复
        final targetMonth = recurring.monthOfYear ?? baseDate.month;
        final targetDay = recurring.dayOfMonth ?? baseDate.day;
        DateTime buildYearly(int year) {
          // 处理闰年2月29日
          final daysInMonth = DateTime(year, targetMonth + 1, 0).day;
          final day = targetDay > daysInMonth ? daysInMonth : targetDay;
          return DateTime(year, targetMonth, day);
        }

        nextDate = buildYearly(baseDate.year + (firstGen ? 0 : interval));
        // 首笔:若当年目标日早于基准(今年已过)→ 顺延 interval 年
        if (firstGen && nextDate.isBefore(baseDate)) {
          nextDate = buildYearly(baseDate.year + interval);
        }
        break;
    }

    // 如果下一次日期还没到，返回null(注意:当天 00:00 <= now,故"今天"会通过)
    if (nextDate.isAfter(nowTs)) {
      logger.info(_tag,
          'calc id=${recurring.id} freq=${frequency.value} interval=$interval firstGen=$firstGen base=$baseDate → next=$nextDate 尚未到期(>now=$nowTs),本次不生成');
      return null;
    }

    // 如果超过结束日期，返回null
    if (recurring.endDate != null && nextDate.isAfter(recurring.endDate!)) {
      logger.info(_tag,
          'calc id=${recurring.id} next=$nextDate 超过结束日期 ${recurring.endDate},不生成');
      return null;
    }

    logger.info(_tag,
        'calc id=${recurring.id} freq=${frequency.value} interval=$interval firstGen=$firstGen base=$baseDate lastGen=$lastGenerated → 生成 next=$nextDate');
    return nextDate;
  }

  /// 生成待处理的交易记录
  Future<List<Transaction>> generatePendingTransactions() async {
    final nowStr = DateTime.now().toString();
    logger.info(_tag, '开始扫描周期交易 (now=$nowStr)');

    final ledgers = await repository.getAllLedgers();
    logger.info(_tag, '获取到 ${ledgers.length} 个账本');

    final generatedTransactions = <Transaction>[];

    for (final ledger in ledgers) {
      // 只加载当前账本的模板，避免每次循环全表扫描。
      final recurringList = (await repository.getRecurringTransactionsByLedger(
        ledger.id,
      ))
          .where((r) => r.enabled)
          .toList();
      if (recurringList.isEmpty) continue;
      logger.info(_tag,
          '账本「${ledger.name}」(id=${ledger.id}) 有 ${recurringList.length} 个启用的周期交易');

      for (final recurring in recurringList) {
        logger.info(_tag,
            '处理周期交易 id=${recurring.id} freq=${recurring.frequency} interval=${recurring.interval} start=${recurring.startDate} end=${recurring.endDate} lastGen=${recurring.lastGeneratedDate}');
        // 循环生成所有缺失的交易记录
        var currentRecurring = recurring;
        var loopGuard = 0;
        while (true) {
          // 防御:任何情况下单条周期交易一次扫描不应生成上千笔 —— 拦截死循环
          if (++loopGuard > 1000) {
            logger.warning(_tag,
                '周期交易 id=${recurring.id} 单次生成超过 1000 笔,强制中止以防死循环');
            break;
          }
          final nextDate = calculateNextDate(currentRecurring);
          if (nextDate == null) break;

          logger.info(_tag,
              '周期交易 id=${currentRecurring.id} 生成一笔: happenedAt=$nextDate amount=${currentRecurring.amount / 100} type=${currentRecurring.type}');

          // 写交易 + 推进锚点在同一事务内完成，防止锚点更新失败导致重复生成。
          final transactionId = await repository.generateRecurringTransaction(
            recurring: currentRecurring,
            happenedAt: nextDate,
          );

          // 单条反查新交易，不再订阅整个账本交易流。
          final transaction = await repository.getTransactionById(transactionId);

          if (transaction != null) {
            generatedTransactions.add(transaction);
          }

          // 重新读取当前账本更新后的模板，用于下一次循环。
          final updatedList =
              await repository.getRecurringTransactionsByLedger(ledger.id);
          final matchedRecurring =
              updatedList.where((r) => r.id == currentRecurring.id).toList();
          if (matchedRecurring.isEmpty) break;
          final updatedRecurring = matchedRecurring.first;
          currentRecurring = updatedRecurring;
        }
      }
    }

    return generatedTransactions;
  }

  /// 获取重复交易的描述文字
  String getFrequencyDescription(
    RecurringTransaction recurring,
    String Function(RecurringFrequency, int) translator,
  ) {
    final frequency = RecurringFrequency.fromString(recurring.frequency);
    return translator(frequency, recurring.interval);
  }

  /// 获取下一次生成时间的描述
  String? getNextGenerationDescription(
    RecurringTransaction recurring,
    String Function(DateTime) formatter,
  ) {
    final nextDate = calculateNextDate(recurring);
    if (nextDate == null) return null;
    return formatter(nextDate);
  }
}
