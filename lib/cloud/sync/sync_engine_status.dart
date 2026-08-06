part of 'sync_engine.dart';

/// 同步健康检查 + 种子数据补登。
///
/// 健康检查拆成两个入口,按"对账口径"分职责:
/// - [checkAccountHealth]:账户级对账面板(云同步页「同步状态」)。以
///   [carrierLedgerId] 为载体账本,输出全量 tx / 用户级实体 / **全局**
///   未推送变更;无云端账本时返回 null。
/// - [checkLedgerHealth]:账本级对账(自愈闸门 / 单账本)。unpushed 按
///   **per-ledger** 口径统计,保证 _selfHealIfMissing 的"无未推送变更"
///   闸门精确到单账本。
///
/// `backfillUntrackedEntities` 给绕过 changeTracker 插入的本地实体
/// (tag / category)补写 create change,让它们能被 push 上去。
///
/// 这些方法都是公开 API,但**不是** `SyncService` 接口方法,所以可以放
/// 在 extension 里。`getStatus` / `markLocalChanged` / `clearStatusCache`
/// 等 @override 接口实现必须留在主类里。
///
/// 注意:extension 名是 **public**(没有 `_` 前缀)——因为方法本身是 public
/// 且会被外部 caller(spitout_cloud_sync_section.dart)调用,private 扩展
/// 在 library 外不可见。命名特意避开顶层 `SyncEngineStatus` enum,叫
/// `SyncEngineHealthChecks` 区分。
extension SyncEngineHealthChecks on SyncEngine {
  /// 账户级健康检查(云同步页「同步状态」面板用)。
  ///
  /// 输出账户级口径:全量交易 / 用户级实体 / **全局**未推送变更;
  /// unpushed 用全局口径才符合用户预期(云同步页是账户级对账面板,
  /// 不是某个账本的私有页面),per-ledger 细分交给 [checkLedgerHealth]。
  ///
  /// [carrierLedgerId] 的两种模式:
  /// - **显式传入**(调用方当前选中的是云端账本):以它为 `/stats` 锚点,
  ///   `ledgerTx` 按它统计、`carrierLedgerId` 原样回填,供 UI 渲染
  ///   「当前账本」组。
  /// - **不传**(调用方当前选中的是本地账本):内部仍按 id 升序自选一本
  ///   云账本去打 `/stats` —— 那是账户级 `totalTx` / `categories` 的唯一
  ///   数据源,不能省;但输出会做**剥离**:`ledgerTx` 置为
  ///   [SyncCountPair.missing]、`carrierLedgerId` 置为 null。
  ///
  /// 剥离的原因:id 升序自选只是内部工程锚点,不承载任何用户语义。一旦把
  /// 它外泄为 `carrierLedgerId`,UI 就会顶着「当前账本」表头显示一本用户
  /// 根本没选中的账本的数据。
  ///
  /// 没有任何云端账本时返回 null,调用方应展示「暂无云端账本」分支,
  /// 不发起任何 stats 请求。
  Future<SyncHealthReport?> checkAccountHealth({int? carrierLedgerId}) async {
    // 区分「显式指定载体」与「内部自选锚点」:前者输出完整的当前账本口径,
    // 后者只借锚点打 stats,输出必须剥离(详见方法文档)。
    final explicitlyPassed = carrierLedgerId != null;

    int effectiveCarrierId;
    if (carrierLedgerId == null) {
      final ledgers = await _queryCloudLedgers();
      if (ledgers.isEmpty) return null;
      // 按 id 升序取第一本:跨刷新最稳定,避免面板数字因锚点漂移而抖动。
      effectiveCarrierId = ledgers.first.id;
    } else {
      effectiveCarrierId = carrierLedgerId;
    }

    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(effectiveCarrierId)))
        .getSingleOrNull();
    if (ledger == null) {
      return SyncHealthReport.error('本地找不到 ledger=$effectiveCarrierId');
    }
    // DEEP:删除 `?? ledger.id.toString()` 兜底 —— 本地账本(从未同步到云端,
    // syncId 为空)用本地自增 id 拼 server 路径必然 404,白白多一次请求还误导
    // UI。syncId 无效直接判定检测失败,提示用户先在云端创建/同步账本。
    final serverLedgerId = ledger.syncId;
    if (serverLedgerId == null || serverLedgerId.isEmpty) {
      return SyncHealthReport.error(
          '本地 ledger=$effectiveCarrierId 无 syncId,尚未同步到云端,无法检测健康状态');
    }

    final counts = await _queryLocalSyncCounts(db, effectiveCarrierId);
    // 账户级面板:unpushed 用全局口径,跨所有账本。
    // 但只统计可同步实体的变更:user-global(ledgerId=0)+ 可同步账本
    // (带非空 syncId)的变更。纯本地账本不上云,即使历史遗留了未推送变更
    // (例如「转本地」前登记的),syncAccount 也永远不会推送它们 —— 计入
    // 会造成「云端账本已同步完仍显示检测到差异」的永久假阳性。
    final syncableIds = await _syncableLedgerIds(db);
    final unpushed = (await changeTracker.getUnpushedChanges())
        .where((c) => c.ledgerId == 0 || syncableIds.contains(c.ledgerId))
        .length;

    // ---------- 远端 /read/ledgers/<id>/stats ----------
    try {
      final stats = await provider.readLedgerStats(ledgerId: serverLedgerId);
      return SyncHealthReport(
        // 剥离:自选锚点模式下不输出当前账本口径(见方法文档)。
        ledgerTx: explicitlyPassed
            ? SyncCountPair(
                local: counts.localLedgerTx, remote: stats.transactionCount)
            : const SyncCountPair.missing(),
        // 账户级口径:无论哪种模式都取真实 stats,面板不降级。
        totalTx:
            SyncCountPair(local: counts.localTotalTx, remote: stats.transactionTotal),
        categories:
            SyncCountPair(local: counts.localCategories, remote: stats.categoryTotal),
        unpushedChanges: unpushed,
        carrierLedgerId: explicitlyPassed ? effectiveCarrierId : null,
      );
    } catch (e, st) {
      // 把"未认证"异常单独摘出来,避免以 raw 字符串(e.toString())原样展示给用户
      // (表现为"检测失败:CloudSyncException:User not authenticated")。
      // 区分两种情形,让 UI 给出更友好的处理(恢复中 / 需手动登录):
      // - 仍在冷却期 → 展示"登录状态恢复中…"并等冷却结束自动重试;
      // - 非冷却期(无凭证 / 2FA / 彻底失败) → 提示用户手动重新登录。
      // 其余真实错误(网络、序列化等)仍按原样上报。
      if (e is CloudNotAuthenticatedException) {
        final remaining = provider.remainingRecoveryCooldown;
        if (remaining != null) {
          return SyncHealthReport.recovering(remaining);
        }
        return SyncHealthReport.needsLogin();
      }
      logger.warning('SyncEngine', 'checkAccountHealth 拉 stats 失败: $e', st);
      return SyncHealthReport(
        // 与正常分支保持一致的剥离规则,避免 error 态泄漏自选锚点。
        ledgerTx: explicitlyPassed
            ? SyncCountPair(local: counts.localLedgerTx, remote: -1)
            : const SyncCountPair.missing(),
        totalTx: SyncCountPair(local: counts.localTotalTx, remote: -1),
        categories: SyncCountPair(local: counts.localCategories, remote: -1),
        unpushedChanges: unpushed,
        carrierLedgerId: explicitlyPassed ? effectiveCarrierId : null,
        error: e.toString(),
      );
    }
  }

  /// 账本级健康检查(自愈闸门 / 单账本对账用)。
  ///
  /// 与 [checkAccountHealth] 的差异:unpushed 按 **per-ledger** 口径统计 ——
  /// _selfHealIfMissing 依赖「该账本无未推送变更」来排除"云端多但本地还没推"
  /// 的假阳性,必须细分到单账本;账户级面板展示全局口径才符合用户预期。
  Future<SyncHealthReport> checkLedgerHealth({required int ledgerId}) async {
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    if (ledger == null) {
      return SyncHealthReport.error('本地找不到 ledger=$ledgerId');
    }
    // DEEP:删除 `?? ledger.id.toString()` 兜底 —— 本地账本(从未同步到云端,
    // syncId 为空)用本地自增 id 拼 server 路径必然 404,白白多一次请求还误导
    // UI。syncId 无效直接判定检测失败,提示用户先在云端创建/同步账本。
    final serverLedgerId = ledger.syncId;
    if (serverLedgerId == null || serverLedgerId.isEmpty) {
      return SyncHealthReport.error(
          '本地 ledger=$ledgerId 无 syncId,尚未同步到云端,无法检测健康状态');
    }

    final counts = await _queryLocalSyncCounts(db, ledgerId);
    final unpushed =
        (await changeTracker.getUnpushedChangesForLedger(ledgerId)).length;

    // ---------- 远端 /read/ledgers/<id>/stats ----------
    try {
      final stats = await provider.readLedgerStats(ledgerId: serverLedgerId);
      return SyncHealthReport(
        ledgerTx:
            SyncCountPair(local: counts.localLedgerTx, remote: stats.transactionCount),
        totalTx:
            SyncCountPair(local: counts.localTotalTx, remote: stats.transactionTotal),
        categories:
            SyncCountPair(local: counts.localCategories, remote: stats.categoryTotal),
        unpushedChanges: unpushed,
      );
    } catch (e, st) {
      // 与 checkAccountHealth 相同:冷却期 → recovering;无凭证 → needsLogin;
      // 其余真实错误(网络、序列化等)仍按原样上报。
      if (e is CloudNotAuthenticatedException) {
        final remaining = provider.remainingRecoveryCooldown;
        if (remaining != null) {
          return SyncHealthReport.recovering(remaining);
        }
        return SyncHealthReport.needsLogin();
      }
      logger.warning('SyncEngine', 'checkLedgerHealth 拉 stats 失败: $e', st);
      return SyncHealthReport(
        ledgerTx: SyncCountPair(local: counts.localLedgerTx, remote: -1),
        totalTx: SyncCountPair(local: counts.localTotalTx, remote: -1),
        categories: SyncCountPair(local: counts.localCategories, remote: -1),
        unpushedChanges: unpushed,
        error: e.toString(),
      );
    }
  }

  /// 为"绕过 changeTracker 插入"的本地 category 补写 `create` 变更记录,
  /// 让后续 push 能把它们推到云端。
  ///
  /// 触发场景:本地直接用 `db.into(...).insert()` 插入的分类不经
  /// `LocalRepository.createCategory` → 这批分类永远不会被 push。
  /// `checkAccountHealth` 检测到 `localCategories > remoteCategories` 且
  /// `unpushed == 0` 时调这个方法 backfill 一次,再触发 sync 就能把分类送上云。
  ///
  /// 幂等:只对没有对应 sync_change 记录的实体补写 create。重复调用是安全的。
  ///
  Future<int> backfillUntrackedEntities({required int ledgerId}) async {
    final allUnpushed =
        await changeTracker.getUnpushedChangesForLedger(ledgerId);
    final allPushedIds =
        <String>{}; // syncId 集合 —— unpushed 的先留着,判断"从未写过 change"用的是下面的专用查询
    for (final c in allUnpushed) {
      allPushedIds.add(c.entitySyncId);
    }
    // 用 change_tracker 的 hasAnyChangeForEntity(若有) / 直接查 local_changes 表。
    // 这里用更稳妥的方式:对每个 entity 调 recordChange,recordChange 自身会
    // 判断"同 entitySyncId + action 是否已经存在",不会造成重复(依赖
    // ChangeTracker 的 upsert 语义,若没有就是直接 insert,重复的会被 unique
    // 约束拦住 —— 重复 insert catch 住 = 无害重复)。
    int backfilled = 0;

    // Categories
    final categories = await db.select(db.categories).get();
    for (final cat in categories) {
      if (cat.syncId == null || cat.syncId!.isEmpty) continue;
      if (allPushedIds.contains(cat.syncId)) continue;
      try {
        await changeTracker.recordUserGlobalChange(
          entityType: 'category',
          entityId: cat.id,
          entitySyncId: cat.syncId!,
          action: 'create',
        );
        backfilled++;
      } catch (e) {
        logger.debug('SyncEngine', 'backfill category ${cat.syncId} skip: $e');
      }
    }

    logger.info('SyncEngine',
        'backfillUntrackedEntities: 共补写 $backfilled 条 sync_change');
    return backfilled;
  }
}

/// 汇总本地三组计数(per-ledger tx / 全量 tx / 用户级实体)。
///
/// 设计意图:checkAccountHealth 与 checkLedgerHealth 的本地计数逻辑
/// 完全一致(都只数有 syncId 的行,跟服务端口径对齐 —— 没 syncId 的行
/// 无法 push,云端不会有对应记录,统计它们会造成永久假阳性"本地比云端多"),
/// 抽成 library 级私有函数避免两处重复漂移。
///
/// 全量口径必须限定在可同步账本(带非空 syncId):纯本地账本不上云,它的
/// 交易虽然也有本地 UUID syncId,但永远不会被推送 —— 若计入 totalTx,
/// 账户级对账面板会一直显示"本地比云端多"的假差异,且 syncAccount 无法
/// 消除它。
///
/// 注意:不能放进 extension —— Dart 不允许私有 extension 成员;
/// 也不能用 SyncEngine 的 `db` 实例字段(顶层函数没有 this),
/// 故由调用方显式传入。
Future<({int localLedgerTx, int localTotalTx, int localCategories})>
    _queryLocalSyncCounts(SpitoutDatabase db, int ledgerId) async {
  // 可同步账本 = 带非空 syncId 的账本(与 push/pull 的判定一致):
  // 纯本地账本创建/移动回本地时 syncId 会被清空,它们的交易虽然也有
  // 本地 UUID syncId,但永远不会被推送 —— 若计入 totalTx,账户级对账
  // 面板会一直显示"本地比云端多"的假差异,且 syncAccount 无法消除它。
  final syncableLedgerIds = await _syncableLedgerIds(db);
  int ledgerTxCount = 0;
  int localTotalTx = 0;
  if (syncableLedgerIds.isNotEmpty) {
    final ledgerTxRows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..where((t) => t.ledgerId.isIn(syncableLedgerIds))
          ..where((t) => t.syncId.isNotNull()))
        .get();
    ledgerTxCount = ledgerTxRows.length;
    localTotalTx = (await (db.select(db.transactions)
              ..where((t) => t.ledgerId.isIn(syncableLedgerIds))
              ..where((t) => t.syncId.isNotNull()))
            .get())
        .length;
  }
  final localCategories = (await (db.select(db.categories)
            ..where((c) => c.syncId.isNotNull()))
          .get())
      .length;
  return (
    localLedgerTx: ledgerTxCount,
    localTotalTx: localTotalTx,
    localCategories: localCategories,
  );
}

/// 可同步账本 = 带非空 syncId 的账本(与 push/pull 的判定一致)。
///
/// 纯本地账本创建/移动回本地时 syncId 会被清空,其交易虽然也有本地 UUID
/// syncId,但永远不会被推送;账户级对账的本地计数与未推送变更统计都必须
/// 以这组账本为口径,否则会制造永久假阳性差异。
Future<Set<int>> _syncableLedgerIds(SpitoutDatabase db) async {
  final rows = await db.select(db.ledgers).get();
  return rows
      .where((l) => (l.syncId ?? '').isNotEmpty)
      .map((l) => l.id)
      .toSet();
}
