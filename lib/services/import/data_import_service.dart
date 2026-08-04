import 'package:drift/drift.dart' as d;
import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/models/import_models.dart';
import '../currency/exchange_rate_service.dart';
import '../../utils/currency/rate_math.dart';
import '../../core/logging/logger_service.dart';

/// 统一的数据导入服务（落库编排引擎）
///
/// 定位说明（共享服务，不随 DTO 下沉）：
/// - 被两条业务路径共同消费：CSV 导入（UI 层）与云端恢复（cloud/sync 层，
///   全量恢复 sync_diff_service / transactions_json），保证两条路径使用
///   完全相同的导入逻辑（分类创建、批量落库、syncId 幂等去重、汇率补拉）。
/// - 依赖 services/currency/exchange_rate_service.dart 做导入补拉汇率，
///   故**不能**下沉到 data/（否则制造 data → services 反向依赖），
///   保留在 services/ 层作为共享服务，上层经本文件引用。
/// - 数据模型（ImportCategory/ImportTransaction/ImportData/ImportResult）
///   定义于 data/models/import_models.dart，经 data/models.dart 门面出口；
///   UI 层统一从门面取类型，不直连本文件。

// --- 数据导入服务 ---

/// 通用数据导入服务
///
/// 提供统一的导入逻辑，支持：
/// - 分类创建（先一级后二级）
/// - 标签创建
/// - 交易插入（批量写入）
/// - 标签关联
class DataImportService {
  /// 导入数据到指定账本
  ///
  /// [repo] - 数据仓库
  /// [ledgerId] - 目标账本ID
  /// [data] - 导入数据
  /// [defaultCurrency] - 默认货币
  /// [onProgress] - 进度回调 (done, total)
  /// [recordChanges] - 默认 true,会调 repo.insertTransactionsBatch 时登记
  ///   changeTracker。FullPull 路径传 false,避免"从云端拉下来的数据又反向推
  ///   回去"。
  Future<ImportResult> importData(
    BaseRepository repo,
    int ledgerId,
    ImportData data, {
    String defaultCurrency = 'CNY',
    void Function(int done, int total)? onProgress,
    bool recordChanges = true,
  }) async {
    // 1. 更新账本信息（如果提供）
    if (data.ledgerName != null || data.currency != null || data.aaEnabled != null) {
      // 币种变更前先记下旧币种,用于变更后重算 nativeAmount。
      // 导入数据中可能携带不同于当前账本的 currency 字段(如从另一个币种
      // 的备份恢复),不重算会导致副行换算显示错误的旧口径金额。
      final String? oldCurrency = data.currency != null
          ? (await repo.getLedgerById(ledgerId))?.currency
          : null;
      try {
        await repo.updateLedger(
          id: ledgerId,
          name: data.ledgerName,
          currency: data.currency,
          aaEnabled: data.aaEnabled,
        );
      } catch (_) {}
      // 币种确实变更(忽略大小写差异)后全量重算 nativeAmount
      if (data.currency != null &&
          oldCurrency != null &&
          data.currency!.toUpperCase() != oldCurrency.toUpperCase()) {
        await repo.recalcNativeAmountsForLedger(ledgerId, data.currency!);
      }
    }

    // 2. 导入分类
    final categoryCache = await importCategories(repo, data.categories);

    // 3. 导入虚拟用户(在交易之前,避免交易 aaParticipants 引用悬空)
    // 仅云端全量恢复 / v7 备份携带 virtualUsers;CSV 路径为空列表跳过。
    await importVirtualUsers(repo, ledgerId, data.virtualUsers);

    // 4. 导入交易（不含标签/附件关联步骤）
    final result = await importTransactions(
      repo,
      ledgerId,
      data.transactions,
      categoryCache: categoryCache,
      onProgress: onProgress,
      recordChanges: recordChanges,
    );

    return result;
  }

  /// 导入虚拟用户(ledger-scoped),按 syncId 幂等 upsert。
  ///
  /// public — 供 transactions_json 导入路径与 importData 复用。
  /// recordChanges 由调用方(repo 层)决定是否登记 change log,
  /// 本方法只管数据层写入。
  Future<void> importVirtualUsers(
    BaseRepository repo,
    int ledgerId,
    List<ImportVirtualUser> virtualUsers,
  ) async {
    if (virtualUsers.isEmpty) return;
    logger.info('VirtualUserImport', '开始导入虚拟用户: ${virtualUsers.length} 个');
    int inserted = 0;
    int skipped = 0;
    try {
      // 幂等:预取已存在的 syncId 集合,避免重复导入产生重复行。
      final existing = await repo.getByLedger(ledgerId);
      final existingSyncIds = <String>{
        for (final u in existing)
          if (u.syncId != null && u.syncId!.isNotEmpty) u.syncId!,
      };
      for (final vu in virtualUsers) {
        final sid = vu.syncId;
        // 已存在(按 syncId 命中)跳过;无 syncId 的导入项不在此路径处理。
        if (sid != null && sid.isNotEmpty && existingSyncIds.contains(sid)) {
          skipped++;
          continue;
        }
        await repo.create(
          ledgerId: ledgerId,
          name: vu.name,
          syncId: sid,
        );
        if (sid != null && sid.isNotEmpty) existingSyncIds.add(sid);
        inserted++;
      }
      logger.info('VirtualUserImport',
          '虚拟用户导入完成: 新增=$inserted 跳过重复=$skipped');
    } catch (e, st) {
      logger.error('VirtualUserImport', '虚拟用户导入失败', e, st);
    }
  }

  /// 导入分类(先一级后二级)。public — sync_diff_service 复用。
  ///
  /// 唯一契约：父级作用域内唯一。
  /// - 一级 cache key = `kind|name`（根作用域内唯一）
  /// - 二级 cache key = `kind|parentName|name`（同父内唯一，跨父允许同名）
  ///
  /// 重要：返回的 categoryCache 给 importTransactions 用。旧 CSV 如果只提供
  /// categoryName（不带 parentName）将走 `kind|name` 退化 lookup，命中第一个
  /// 匹配的二级同名行（多个同名时无法精确区分）；新 CSV 应携带 categoryId
  /// 或在解析侧补 parentName，否则跨父同名叶子无法正确归类。
  Future<Map<String, int>> importCategories(
    BaseRepository repo,
    List<ImportCategory> categories,
  ) async {
    final categoryCache = <String, int>{}; // key: kind|name 或 kind|parentName|name

    if (categories.isEmpty) return categoryCache;
    logger.info('CategoryImport', '开始导入分类: ${categories.length} 个');
    final sw = Stopwatch()..start();
    int created = 0;

    try {
      // 获取所有现有分类
      // 全局仅支出模式，只查 expense 分类。
      final existingExpense = await repo.getTopLevelCategories('expense');
      final existingCategoryMap = <String, int>{};

      // 一级 key = kind|name；二级 key = kind|parentName|name，跨父同名不互相覆盖。
      // 否则「购物>鞋子」「服装>鞋子」会扁平进同一 key 互相覆盖，CSV 导入
      // 「服装>鞋子」时命中「购物>鞋子」的 id，整批交易静默挂错分类。
      for (final cat in existingExpense) {
        existingCategoryMap['${cat.kind}|${cat.name}'] = cat.id;
        // 获取子分类
        final subCats = await repo.getSubCategories(cat.id);
        for (final sub in subCats) {
          existingCategoryMap['${sub.kind}|${cat.name}|${sub.name}'] = sub.id;
        }
      }

      // 分离一级和二级分类
      final level1 = categories.where((c) => c.level == 1 || c.parentName == null).toList();
      final level2 = categories.where((c) => c.level == 2 && c.parentName != null).toList();

      // 导入一级分类
      for (final cat in level1) {
        final key = '${cat.kind}|${cat.name}';
        if (existingCategoryMap.containsKey(key)) {
          categoryCache[key] = existingCategoryMap[key]!;
        } else {
          final id = await repo.createCategory(
            name: cat.name,
            kind: cat.kind,
            icon: cat.icon,
            sortOrder: cat.sortOrder,
          );
          categoryCache[key] = id;
          created++;
        }
      }

      // 导入二级分类
      // 主 key = kind|parentName|name（区分父作用域，避免误杀跨父同名）。
      for (final cat in level2) {
        final key = '${cat.kind}|${cat.parentName}|${cat.name}';
        if (existingCategoryMap.containsKey(key)) {
          categoryCache[key] = existingCategoryMap[key]!;
        } else {
          // 查找父分类ID（父为一级，cache key = kind|parentName）
          final parentKey = '${cat.kind}|${cat.parentName}';
          final parentId = categoryCache[parentKey];
          if (parentId != null) {
            final id = await repo.createSubCategory(
              parentId: parentId,
              name: cat.name,
              kind: cat.kind,
              icon: cat.icon,
              sortOrder: cat.sortOrder,
            );
            categoryCache[key] = id;
          }
        }
      }
      logger.info('CategoryImport',
          '分类导入完成: 新增=$created 已存在=${categories.length - created} 耗时=${sw.elapsedMilliseconds}ms');
    } catch (e, st) {
      logger.error('CategoryImport', '分类导入失败', e, st);
    }

    return categoryCache;
  }

  /// 导入交易（统一 batch 路径）
  ///
  /// 全部走 `insertTransactionsBatchWithRelations` 统一批处理路径,500 条 / 批,
  /// 一个 db.transaction 内 batch insert tx + local_changes,
  /// 把 N 次 BEGIN/COMMIT/fsync 折叠成 1 次。
  ///
  /// public — sync_diff_service 复用。
  Future<ImportResult> importTransactions(
    BaseRepository repo,
    int ledgerId,
    List<ImportTransaction> transactions, {
    required Map<String, int> categoryCache,
    void Function(int done, int total)? onProgress,
    bool recordChanges = true,
  }) async {
    int inserted = 0;
    int failed = 0;
    int processed = 0;
    int skippedDup = 0;
    final total = transactions.length;
    logger.info('TxImport',
        '开始导入交易: $total 条 (recordChanges=$recordChanges)');

    // 幂等防线：预取目标账本已存在的 syncId 集合。
    //
    // 为什么必须做：transactions.syncId 列没有 UNIQUE 约束，云端全量恢复
    // (runFullPull / 快照下载) 若对"已有数据的账本"重复执行，同一条云端
    // 交易会被再次 INSERT 而不报错，直接产生重复行（"下拉刷新数据翻倍" bug）。
    // 这里用一次全量查询建 Set（O(N) 内存换掉 N 次逐条查库），导入循环中
    // 命中的记录直接跳过，保证同一份数据重复导入天然幂等。
    //
    // 说明：无 syncId 的记录（如 CSV 导入）不受影响，保持普通插入行为。
    final existingSyncIds = <String>{};
    try {
      final existingTxs = await repo.getTransactionsByLedger(ledgerId);
      for (final t in existingTxs) {
        final sid = t.syncId;
        if (sid != null && sid.isNotEmpty) {
          existingSyncIds.add(sid);
        }
      }
    } catch (e, st) {
      // 预取失败不阻断导入：本次导入跳过 syncId 去重，仅记录日志。
      logger.warning('TxImport', '预取已有 syncId 失败,本次导入不做去重: $e', st);
    }

    // 交易级多币种:批量预取本位币/有效汇率,
    // 逐条填 currencyCode + nativeAmount,不落 NULL(NULL 行补折算检测
    // 需 join 兜底)。
    final ledger = await repo.getLedgerById(ledgerId);
    final ledgerBase = ((ledger?.currency.isNotEmpty ?? false)
            ? ledger!.currency
            : 'CNY')
        .toUpperCase();
    Map<String, EffectiveRate> importRates = const {};
    try {
      final autos = await repo.getLatestAutoRates(ledgerBase);
      final overrides = await repo.getOverrides(ledgerBase);
      importRates = mergeEffectiveRates(
        autoRates: [
          for (final r in autos)
            (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
        ],
        overrides: [
          for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
        ],
      );
    } catch (e) {
      logger.warning('TxImport', '导入取汇率失败,外币交易将按 1:1 待补折算捞回: $e');
    }

    // 导入补拉汇率：扫描交易中出现但本地汇率表缺失的外币币种，
    // 从公网拉取并缓存，避免外币交易按 1:1 入账导致统计失真
    // （如：导入美元100但账本币种是人民币，无汇率时直接按100入账，
    //   列表和统计全部显示 ¥100，数据严重失真）。
    final missingCurrencies = <String>{};
    for (final tx in transactions) {
      final cur = ((tx.currencyCode?.isNotEmpty ?? false)
              ? tx.currencyCode!
              : null)
          ?.toUpperCase();
      if (cur != null && cur != ledgerBase && !importRates.containsKey(cur)) {
        missingCurrencies.add(cur);
      }
    }
    if (missingCurrencies.isNotEmpty) {
      try {
        // fetch(base) 返回「1 base = x quote」全量汇率表
        final result = await ExchangeRateService().fetch(ledgerBase);
        // 倒数成「1 quote = x base」方向，与 computeNativeAmount 口径一致
        final inverted = <String, String>{};
        for (final e in result.ratesBaseToQuote.entries) {
          final raw = double.tryParse(e.value);
          if (raw != null && raw > 0) {
            inverted[e.key.toUpperCase()] = invertRate(raw);
          }
        }
        // 只补齐本地缺失的币种，不覆盖已有的手动覆盖汇率
        var filled = 0;
        for (final cur in missingCurrencies) {
          if (inverted.containsKey(cur) && !importRates.containsKey(cur)) {
            importRates[cur] = EffectiveRate(
              rate: inverted[cur]!,
              manual: false,
              rateDate: result.rateDate,
            );
            filled++;
          }
        }
        // 缓存到本地汇率表，后续导入/记账可直接复用
        if (inverted.isNotEmpty) {
          await repo.upsertAutoRates(
            base: ledgerBase,
            rateDate: result.rateDate,
            rates: inverted,
            source: result.source,
            fetchedAt: DateTime.now().toUtc(),
          );
        }
        logger.info('TxImport',
            '导入补拉汇率: base=$ledgerBase 缺失=${missingCurrencies.length} 补齐=$filled source=${result.source}');
      } catch (e) {
        logger.warning('TxImport',
            '导入补拉汇率失败,缺失币种(${missingCurrencies.join(",")})将按 1:1 入账待补折算捞回: $e');
      }
    }

    final overallSw = Stopwatch()..start();

    const batchSize = 500;
    // 批次缓冲:tx 列表
    final batchTx = <TransactionsCompanion>[];

    final localCategoryCache = Map<String, int>.from(categoryCache);

    // 把当前缓冲 flush 到 repo。捕获异常时整批算 failed,继续下一批。
    Future<void> flush() async {
      if (batchTx.isEmpty) return;
      final size = batchTx.length;
      final batchSw = Stopwatch()..start();
      try {
        final ids = await repo.insertTransactionsBatchWithRelations(
          transactions: List.of(batchTx),
          recordChanges: recordChanges,
        );
        inserted += ids.length;
        logger.info('TxImport',
            'flush 批次: size=$size 耗时=${batchSw.elapsedMilliseconds}ms 累计=${processed + size}/$total');
      } catch (e, st) {
        logger.error('TxImport', '批次 flush 失败,本批 $size 条算 failed', e, st);
        failed += size;
      }
      processed += size;
      batchTx.clear();
      if (onProgress != null) onProgress(processed, total);
    }

    for (final tx in transactions) {
      // 按 syncId 幂等去重：本地已存在、或本批次内重复出现的 syncId 一律跳过，
      // 避免全量恢复把云端快照重复插入本地（修复下拉刷新数据翻倍 bug）。
      // 跳过的记录计入 processed 以保证进度回调准确，但不计入 inserted/failed。
      final sid = tx.syncId;
      if (sid != null && sid.isNotEmpty) {
        if (existingSyncIds.contains(sid)) {
          skippedDup++;
          processed++;
          if (onProgress != null) onProgress(processed, total);
          continue;
        }
        // 记入集合，同一批数据内部出现重复 syncId 时也只插一条。
        existingSyncIds.add(sid);
      }

      // 解析分类ID
      int? categoryId;
      if (tx.categoryId != null) {
        categoryId = tx.categoryId;
      } else if (tx.categoryName != null && tx.categoryKind != null) {
        // cache 主 key：一级为 `kind|name`，二级为 `kind|parentName|name`。
        // 旧 CSV 若只提供 categoryName 没带 parentName，这里只能走 `kind|name`
        // 退化 lookup——能精确命中一级；命中二级同名行时取第一个匹配，跨父
        // 同名叶子无法区分。这是 CSV 格式本身的局限，新解析器应输出 categoryId
        // 或携带 categoryParentName 字段以便按主 key 精确匹配。
        final key = '${tx.categoryKind}|${tx.categoryName}';
        categoryId = localCategoryCache[key];
        // 命中失败时直接 upsertCategory 兜底创建。
        if (categoryId == null) {
          try {
            categoryId = await repo.upsertCategory(
              name: tx.categoryName!,
              kind: tx.categoryKind!,
            );
            localCategoryCache[key] = categoryId;
          } catch (_) {}
        }
      }

      // 交易币种 = CSV 币种列(显式) ?? 本位币;
      // 折算快照同币种 = amount,外币按有效汇率,取不到 = amount。
      final txCurrency = ((tx.currencyCode?.isNotEmpty ?? false)
              ? tx.currencyCode!
              : null) ??
          ledgerBase;
      // 云端全量恢复保真:源端 nativeAmount 快照是源设备记账时的真实折算结果,
      // 本地重算会因汇率时点不同而失真,故快照有值时优先采用;
      // 缺键(CSV 导入/无该字段的备份)才走本地重算路径。
      final txNative = tx.nativeAmount ??
          (txCurrency == ledgerBase
              ? tx.amount
              : (computeNativeAmount(
                      amount: tx.amount,
                      txCurrency: txCurrency,
                      ledgerBase: ledgerBase,
                      rates: importRates) ??
                  tx.amount));

      // 构建交易记录
      final txCompanion = TransactionsCompanion.insert(
        ledgerId: ledgerId,
        type: tx.type,
        amount: tx.amount,
        categoryId: d.Value(categoryId),
        happenedAt: d.Value(tx.happenedAt),
        note: d.Value(tx.note),
        syncId: d.Value(tx.syncId),
        currencyCode: d.Value(txCurrency),
        nativeAmount: d.Value(txNative),
        // 缺键(JSON/CSV)落默认 false,与 server snapshot「缺键 = false」语义对齐。
        excludeFromStats: d.Value(tx.excludeFromStats ?? false),
        // AA 分摊字段:JSON 缺键落 null(列默认值),有值显式写入。
        // 与 server snapshot「缺键 = 未启用 AA」语义对齐。
        // 支出人兜底:备份未携带(旧 v6/CSV)时默认与创建人一致(用户数据修复
        // 约定),双缺失落空串,展示层降级"未知"、计算层跳过。
        paidByUserId: d.Value(tx.paidByUserId ?? tx.createdByUserId ?? ''),
        aaMode: d.Value(tx.aaMode),
        aaParticipants: d.Value(tx.aaParticipants),
        aaSplits: d.Value(tx.aaSplits),
      );

      batchTx.add(txCompanion);

      if (batchTx.length >= batchSize) {
        await flush();
      }
    }

    // 刷剩余
    await flush();

    logger.info('TxImport',
        '交易导入完成: 总数=$total 成功=$inserted 失败=$failed '
        '跳过重复(syncId)=$skippedDup 总耗时=${overallSw.elapsedMilliseconds}ms');
    return ImportResult(inserted: inserted, failed: failed);
  }
}

/// 全局单例
final dataImportService = DataImportService();
