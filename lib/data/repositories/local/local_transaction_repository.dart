import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/utils/date/month_range.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';

/// 批量按 syncId 更新交易时的单条 update payload。
class TransactionUpdateBySyncIdData {
  final String syncId;
  final String type;
  final int amount; // 单位:分
  final int? categoryId;
  final DateTime happenedAt;
  final String? note;
  // 全字段快照契约:云端恢复/下载预览把远端交易完整落本地,
  // 这些字段 null 表示"清空/未设置"，非 null 表示显式覆盖。
  final String? currencyCode;
  final int? nativeAmount; // 单位:分
  final bool? excludeFromStats;
  final String? paidByUserId;
  final int? aaMode;
  final String? aaParticipants;
  final String? aaSplits;
  /// 是否按"云端快照全字段覆盖"语义写入。
  /// true 时上述扩展字段 null = 清空、非 null = 覆盖；
  /// false 时保持旧语义（只更新 5 个基础字段）。
  final bool overwriteSnapshot;

  const TransactionUpdateBySyncIdData({
    required this.syncId,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.happenedAt,
    this.note,
    this.currencyCode,
    this.nativeAmount,
    this.excludeFromStats,
    this.paidByUserId,
    this.aaMode,
    this.aaParticipants,
    this.aaSplits,
    this.overwriteSnapshot = false,
  });
}

/// 统一删除交易及其编辑历史。
///
/// 为什么需要单独收敛：各删除入口（单条删除、按 syncId 批量删除、按账本清空/删除）如果各自
/// 直接删除 transactions，record_edit_histories 会留下永远匹配不到交易的孤儿行；SQLite 的
/// 外键级联依赖 PRAGMA foreign_keys 开关，显式先删编辑历史更稳妥，且能让所有入口行为一致。
Future<int> deleteTransactionsWithEditHistories(
  SpitoutDatabase db,
  Iterable<int> transactionIds,
) async {
  final ids = transactionIds.toList();
  if (ids.isEmpty) return 0;

  // 先清编辑历史，再删交易主表；顺序保证即使外键未开启也不会残留孤儿历史。
  await (db.delete(
    db.recordEditHistories,
  )..where((h) => h.recordId.isIn(ids))).go();
  return (db.delete(db.transactions)..where((t) => t.id.isIn(ids))).go();
}

/// 本地交易Repository实现
/// 基于 Drift 数据库实现
class LocalTransactionRepository {
  final SpitoutDatabase db;

  LocalTransactionRepository(this.db);

  /// 校验 AA 分摊 JSON 字段可解析(审计问题 7 的仓储层守卫)。
  ///
  /// aaParticipants 必须是 JSON 数组、aaSplits 必须是 JSON 对象;
  /// 空串/null 视为未配置,跳过。导入/同步/UI 任何写入路径都先过这里,
  /// 非法 JSON 在落库前抛出 ArgumentError,不让脏数据进入统计解析路径。
  void _validateAaJson(String? participants, String? splits) {
    for (final entry in [
      ('aaParticipants', participants),
      ('aaSplits', splits),
    ]) {
      final value = entry.$2;
      if (value == null || value.isEmpty) continue;
      try {
        jsonDecode(value);
      } catch (e) {
        throw ArgumentError('${entry.$1} 不是合法 JSON: $value');
      }
    }
  }

  /// 从 Companion 取值校验(absent 视为 null)。
  void _validateAaJsonInCompanion(TransactionsCompanion c) {
    _validateAaJson(
      c.aaParticipants.present ? c.aaParticipants.value : null,
      c.aaSplits.present ? c.aaSplits.value : null,
    );
  }

  Stream<List<Transaction>> watchRecentTransactions({
    required int ledgerId,
    int limit = 20,
  }) {
    return (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) => d.OrderingTerm(
              expression: t.happenedAt,
              mode: d.OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .watch();
  }

  /// 读取账本的自定义每月起始日(1-28);账本缺失或查询异常时按 1(自然月)降级
  /// —— watch 流经 Stream.fromFuture 包裹,这里抛错会让流永久进 error 态。
  Future<int> _monthStartDayOf(int ledgerId) async {
    try {
      final row = await (db.select(
        db.ledgers,
      )..where((l) => l.id.equals(ledgerId))).getSingleOrNull();
      return (row?.monthStartDay ?? 1).clamp(1, 28);
    } catch (_) {
      return 1;
    }
  }

  Stream<List<Transaction>> watchTransactionsInMonth({
    required int ledgerId,
    required DateTime month,
  }) {
    return Stream.fromFuture(_monthStartDayOf(ledgerId)).asyncExpand((sd) {
      final range = periodForLabel(month.year, month.month, sd);
      return (db.select(db.transactions)
            ..where(
              (t) =>
                  t.ledgerId.equals(ledgerId) &
                  t.happenedAt.isBiggerOrEqualValue(range.start) &
                  t.happenedAt.isSmallerThanValue(range.end),
            )
            ..orderBy([
              (t) => d.OrderingTerm(
                expression: t.happenedAt,
                mode: d.OrderingMode.desc,
              ),
            ]))
          .watch();
    });
  }

  /// 标准 tx + category LEFT JOIN。所有 list 风格的
  /// watch 都走这个,避免重复写 join 表。
  List<d.Join<d.HasResultSet, dynamic>> _txJoins() => [
    d.leftOuterJoin(
      db.categories,
      db.categories.id.equalsExp(db.transactions.categoryId),
    ),
  ];

  Stream<List<({Transaction t, Category? category})>>
  watchTransactionsWithCategoryAll({int? ledgerId}) {
    final select = db.select(db.transactions);
    if (ledgerId != null) {
      select.where((t) => t.ledgerId.equals(ledgerId));
    }
    select.orderBy([
      (t) =>
          d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc),
    ]);
    final q = select.join(_txJoins());
    return _watchTxJoinWithSharedHydration(q);
  }

  Stream<List<({Transaction t, Category? category})>>
  watchExcludedAaTransactions(int ledgerId) {
    // 只取 aaMode=1(不分摊)的交易,过滤下沉到 SQL,避免客户端全量过滤。
    final select = db.select(db.transactions)
      ..where((t) => t.ledgerId.equals(ledgerId) & t.aaMode.equals(1))
      ..orderBy([
        (t) =>
            d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc),
      ]);
    final q = select.join(_txJoins());
    return _watchTxJoinWithSharedHydration(q);
  }

  /// 把 Drift 主表 stream 跟 SharedLedgerCategories 表更新合流,
  /// 任一变化都重跑 hydration 并 emit。
  ///
  /// 单纯用 q.watch() 时,Drift 只 track query 里 join 到的表(transactions /
  /// categories)。SharedLedgerCategories 行被 WS handler 改了,stream 不会
  /// re-emit → tx tile 显示旧名字/图标,跟 picker 不一致。这里手动加一路
  /// db.tableUpdates(SharedLedgerCategories) 监听,触发时拿上一次
  /// Drift 结果重 hydrate 再 emit。
  Stream<List<({Transaction t, Category? category})>>
  _watchTxJoinWithSharedHydration(d.JoinedSelectStatement q) {
    late StreamController<List<({Transaction t, Category? category})>> ctrl;
    StreamSubscription? txSub;
    StreamSubscription? sharedCatSub;
    List<d.TypedResult>? lastRows;

    Future<void> rehydrate() async {
      if (lastRows == null) return;
      final out = lastRows!
          .map(
            (r) => (
              t: r.readTable(db.transactions),
              category: r.readTableOrNull(db.categories),
            ),
          )
          .toList();
      final hydrated = await _hydrateSharedOverrides(out);
      if (!ctrl.isClosed) ctrl.add(hydrated);
    }

    ctrl = StreamController<List<({Transaction t, Category? category})>>(
      onListen: () {
        txSub = q.watch().listen((rows) {
          lastRows = rows;
          rehydrate();
        });
        sharedCatSub = db
            .tableUpdates(d.TableUpdateQuery.onTable(db.sharedLedgerCategories))
            .listen((_) => rehydrate());
      },
      onCancel: () async {
        await txSub?.cancel();
        await sharedCatSub?.cancel();
      },
    );
    return ctrl.stream;
  }

  /// Editor 在共享账本下记的 tx,主表 JOIN 不到 category 行,
  /// 字段是 null。这里二次查 SharedLedgerCategories 按 syncId 找,
  /// 转 synthetic 实体回填,UI 不用区分。
  Future<
    ({
      Map<int, String> ledgerSyncByLocalId,
      Map<String, SharedLedgerCategory> sharedByLedgerAndSync,
    })
  >
  _loadSharedHydrationContext(
    Iterable<({Transaction t, Category? category})> rows,
    Set<String> catSyncIds,
  ) async {
    final ledgerIds = rows.map((r) => r.t.ledgerId).toSet().toList();
    final ledgers = await (db.select(
      db.ledgers,
    )..where((l) => l.id.isIn(ledgerIds))).get();
    final ledgerSyncByLocalId = <int, String>{
      for (final l in ledgers)
        if (l.syncId != null) l.id: l.syncId!,
    };
    final validLedgerSyncIds = ledgerSyncByLocalId.values.toList();
    if (validLedgerSyncIds.isEmpty) {
      return (
        ledgerSyncByLocalId: ledgerSyncByLocalId,
        sharedByLedgerAndSync: <String, SharedLedgerCategory>{},
      );
    }
    final shared =
        await (db.select(db.sharedLedgerCategories)..where(
              (t) =>
                  t.syncId.isIn(catSyncIds.toList()) &
                  t.ledgerSyncId.isIn(validLedgerSyncIds),
            ))
            .get();
    return (
      ledgerSyncByLocalId: ledgerSyncByLocalId,
      sharedByLedgerAndSync: {
        for (final s in shared) '${s.ledgerSyncId}|${s.syncId}': s,
      },
    );
  }

  Future<List<({Transaction t, Category? category})>> _hydrateSharedOverrides(
    List<({Transaction t, Category? category})> rows,
  ) async {
    // 收集所有需要反查的 syncId(分类)
    final catSyncIds = <String>{};
    for (final r in rows) {
      final cOv = r.t.categorySyncIdOverride;
      if (r.category == null && cOv != null && cOv.isNotEmpty) {
        catSyncIds.add(cOv);
      }
    }
    if (catSyncIds.isEmpty) return rows;

    // 按交易所属账本的 ledgerSyncId 过滤,避免跨账本 synthetic id 碰撞取错分类。
    final ctx = await _loadSharedHydrationContext(rows, catSyncIds);

    // 回填到每行
    return rows.map((r) {
      Category? category = r.category;

      final cOv = r.t.categorySyncIdOverride;
      if (category == null && cOv != null && cOv.isNotEmpty) {
        final ledgerSyncId = ctx.ledgerSyncByLocalId[r.t.ledgerId];
        final s = ledgerSyncId == null
            ? null
            : ctx.sharedByLedgerAndSync['$ledgerSyncId|$cOv'];
        if (s != null) category = _syntheticCategoryFromShared(s);
      }

      return (t: r.t, category: category);
    }).toList();
  }

  /// SharedLedgerCategory → synthetic Category。用 syntheticIdForSyncId 而不
  /// 是 -1 — 否则所有共享分类都拿到同一个 id,首页点击分类详情时反查不到
  /// 目标 syncId,详情页 0 笔交易。hash 派生的 id 与 picker / watchCategory
  /// 路径保持一致。
  Category _syntheticCategoryFromShared(SharedLedgerCategory s) {
    final parentSyncId = s.parentSyncId;
    return Category(
      id: syntheticIdForSyncId(s.syncId),
      name: s.name,
      kind: s.kind,
      icon: s.icon,
      sortOrder: s.sortOrder,
      // 二级分类的父子链必须保留：详情页拼「父 / 子」全名、导出拆
      // 「分类 / 二级分类」两列都依赖 parentId，不能像主表 join 那样丢成 null。
      parentId: (parentSyncId != null && parentSyncId.isNotEmpty)
          ? syntheticIdForSyncId(parentSyncId)
          : null,
      level: s.level,
      syncId: s.syncId,
    );
  }

  Stream<List<({Transaction t, Category? category})>>
  watchTransactionsWithCategoryInMonth({
    required int ledgerId,
    required DateTime month,
  }) {
    return Stream.fromFuture(_monthStartDayOf(ledgerId)).asyncExpand((sd) {
      final range = periodForLabel(month.year, month.month, sd);
      final q =
          (db.select(db.transactions)
                ..where(
                  (t) =>
                      t.ledgerId.equals(ledgerId) &
                      t.happenedAt.isBiggerOrEqualValue(range.start) &
                      t.happenedAt.isSmallerThanValue(range.end),
                )
                ..orderBy([
                  (t) => d.OrderingTerm(
                    expression: t.happenedAt,
                    mode: d.OrderingMode.desc,
                  ),
                ]))
              .join(_txJoins());
      return _watchTxJoinWithSharedHydration(q);
    });
  }

  Stream<List<({Transaction t, Category? category})>>
  watchTransactionsWithCategoryInYear({
    required int ledgerId,
    required int year,
  }) {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final q =
        (db.select(db.transactions)
              ..where(
                (t) =>
                    t.ledgerId.equals(ledgerId) &
                    t.happenedAt.isBiggerOrEqualValue(start) &
                    t.happenedAt.isSmallerThanValue(end),
              )
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: t.happenedAt,
                  mode: d.OrderingMode.desc,
                ),
              ]))
            .join(_txJoins());
    return _watchTxJoinWithSharedHydration(q);
  }

  Stream<List<({Transaction t, Category? category})>>
  watchTransactionsForCategoryInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
    int? categoryId,
    required String type,
  }) {
    final base =
        (db.select(db.transactions)
              ..where(
                (t) =>
                    t.ledgerId.equals(ledgerId) &
                    t.type.equals(type) &
                    t.happenedAt.isBiggerOrEqualValue(start) &
                    t.happenedAt.isSmallerThanValue(end),
              )
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: t.happenedAt,
                  mode: d.OrderingMode.desc,
                ),
              ]))
            .join(_txJoins());
    if (categoryId == null) {
      base.where(db.transactions.categoryId.isNull());
    } else {
      base.where(db.transactions.categoryId.equals(categoryId));
    }
    return _watchTxJoinWithSharedHydration(base);
  }

  static const _uuid = Uuid();

  Future<int> addTransaction({
    required int ledgerId,
    required String type,
    required int amount,
    int? categoryId,
    required DateTime happenedAt,
    String? note,
    String? syncId,
    String? categorySyncIdOverride,
    bool excludeFromStats = false,
    String? currencyCode,
    int? nativeAmount,
    // AA 分摊字段:由调用方显式传入,子仓收"已定值"直写
    String? paidByUserId,
    int? aaMode,
    String? aaParticipants,
    String? aaSplits,
  }) async {
    // 子仓收「已定值」直写;带折算的兜底(查汇率)在聚合
    // LocalRepository 包装层(子仓拿不到汇率)。
    _validateAaJson(aaParticipants, aaSplits);
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: type,
            amount: amount,
            categoryId: d.Value(categoryId),
            happenedAt: d.Value(happenedAt),
            note: d.Value(note),
            syncId: d.Value(syncId ?? _uuid.v4()),
            categorySyncIdOverride: d.Value(categorySyncIdOverride),
            excludeFromStats: d.Value(excludeFromStats),
            currencyCode: d.Value(currencyCode),
            nativeAmount: d.Value(nativeAmount),
            // AA 字段:nullable,非 AA 交易传 null(列存 NULL)
            paidByUserId: d.Value(paidByUserId),
            aaMode: d.Value(aaMode),
            aaParticipants: d.Value(aaParticipants),
            aaSplits: d.Value(aaSplits),
          ),
        );
  }

  Future<int> insertTransactionsBatch(
    List<TransactionsCompanion> items, {
    bool recordChanges = true,
  }) async {
    // 子仓库不挂 changeTracker,recordChanges 参数对它无作用 — 真正的 record
    // 在 LocalRepository wrapper 那一层。这里保留参数只是为了接口一致。
    if (items.isEmpty) return 0;
    for (final item in items) {
      _validateAaJsonInCompanion(item);
    }
    final effectiveItems = items.map((item) {
      if (item.syncId == const d.Value.absent() || item.syncId.value == null) {
        return item.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return item;
    }).toList();
    return db.transaction(() async {
      await db.batch((b) => b.insertAll(db.transactions, effectiveItems));
      return effectiveItems.length;
    });
  }

  // 批量插入交易(无标签/附件关联)
  Future<List<int>> insertTransactionsBatchWithRelations({
    required List<TransactionsCompanion> transactions,
    bool recordChanges = true,
  }) async {
    if (transactions.isEmpty) return const [];
    for (final tx in transactions) {
      _validateAaJsonInCompanion(tx);
    }
    // 预填充 syncId — batch insertAll 不返回 row id,必须靠 syncId 反查。
    final effective = transactions.map((tx) {
      if (tx.syncId == const d.Value.absent() || tx.syncId.value == null) {
        return tx.copyWith(syncId: d.Value(_uuid.v4()));
      }
      return tx;
    }).toList();

    return db.transaction(() async {
      // 1. 一次性 batch insert 所有 tx
      await db.batch((b) => b.insertAll(db.transactions, effective));

      // 2. SELECT 回拿 (id, syncId) 映射,按 effective 顺序对齐
      final syncIds = effective.map((c) => c.syncId.value!).toList();
      final inserted = await (db.select(
        db.transactions,
      )..where((t) => t.syncId.isIn(syncIds))).get();
      final idBySyncId = <String, int>{
        for (final tx in inserted)
          if (tx.syncId != null) tx.syncId!: tx.id,
      };
      final ids = syncIds.map((s) => idBySyncId[s]!).toList();

      return ids;
    });
  }

  Future<int> updateTransaction({
    required int id,
    required String type,
    required int amount,
    int? categoryId,
    String? note,
    DateTime? happenedAt,
    String? categorySyncIdOverride,
    bool? excludeFromStats,
    String? currencyCode,
    int? nativeAmount,
    // AA 分摊字段:null = 不更新保持原值
    String? paidByUserId,
    int? aaMode,
    String? aaParticipants,
    String? aaSplits,
  }) async {
    // 本地编辑路径 version+1 + lastEditedAt,支撑编辑历史与列表项 HH:mm 展示。
    // 同步路径(updateTransactionBySyncId 等)不走此方法,不会误增版本号。
    // 先读旧 version 再 +1:本地单用户/共享账本 LWW 场景并发风险低,先读后写可接受。
    _validateAaJson(aaParticipants, aaSplits);
    final existing = await getTransactionById(id);
    if (existing == null) {
      throw StateError('交易不存在，无法更新: $id');
    }
    final newVersion = existing.version + 1;
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        type: d.Value(type),
        amount: d.Value(amount),
        categoryId: d.Value(categoryId),
        note: d.Value(note),
        happenedAt: happenedAt != null
            ? d.Value(happenedAt)
            : const d.Value.absent(),
        categorySyncIdOverride: d.Value(categorySyncIdOverride),
        // null = 不更新(保持原值);非 null = 显式写入
        excludeFromStats: excludeFromStats == null
            ? const d.Value.absent()
            : d.Value(excludeFromStats),
        // null = 不更新(保持原快照);非 null = 显式写入
        currencyCode: currencyCode == null
            ? const d.Value.absent()
            : d.Value(currencyCode),
        nativeAmount: nativeAmount == null
            ? const d.Value.absent()
            : d.Value(nativeAmount),
        // AA 分摊字段:null = 不更新(absent);非 null = 显式写入。
        // 对 nullable 列,传入显式 null(空串)用于清空场景由调用方决定,
        // 这里按"传了就写"语义处理。
        paidByUserId: paidByUserId == null
            ? const d.Value.absent()
            : d.Value(paidByUserId),
        aaMode: aaMode == null ? const d.Value.absent() : d.Value(aaMode),
        aaParticipants: aaParticipants == null
            ? const d.Value.absent()
            : d.Value(aaParticipants),
        aaSplits: aaSplits == null ? const d.Value.absent() : d.Value(aaSplits),
        // 版本号自增 + 最后编辑时间戳
        version: d.Value(newVersion),
        lastEditedAt: d.Value(DateTime.now()),
      ),
    );
    // 返回自增后的版本号:供 UI 层调用 appendEditHistory 时传入,
    // 让 transactions.version 与 record_edit_histories.version 保持一致,
    // 详情页"vN"标签才能正确对应本次编辑。
    return newVersion;
  }

  /// 回填交易作者字段(createdByUserId / lastEditedByUserId / paidByUserId)。
  ///
  /// 本地写入路径(addTransaction / updateTransaction)无法感知当前操作者,
  /// 由 UI 层写完交易后调用本方法补齐作者字段。paidByUserId 的兜底规则:
  /// - 新建:为空时回填操作者(默认支出人 = 创建人);编辑器已显式写入的值
  ///   (指定分摊场景)不覆盖。
  /// - 编辑:paidByUserId 为空时同样回填操作者(覆盖旧数据从未回填的极端场景,
  ///   保证支出人全局必填);非空则视为用户手改值保留,支出人不随编辑人变化。
  ///   仅更新 lastEditedByUserId(createdByUserId 维持 first-write-wins)。
  ///
  /// [userId] 为当前操作者(已登录为云 userId,未登录为 localSelfId,
  /// 由 TxAuthorService 解析后传入,始终非空)。三字段统一写该值,
  /// 不再用 'me' 占位,头像字段(createdByUserId / lastEditedByUserId)
  /// 也会在未登录时写入 localSelfId,保证作者信息完整。
  Future<void> markTxAuthor({
    required int txId,
    required String userId,
    required bool isCreate,
  }) async {
    if (isCreate) {
      // 新建:写 createdByUserId + lastEditedByUserId;
      // paidByUserId 为空时回填操作者(默认支出人 = 创建人),已显式写入不覆盖。
      final existing = await getTransactionById(txId);
      final shouldBackfillPaidBy =
          existing == null ||
          existing.paidByUserId == null ||
          existing.paidByUserId!.isEmpty;
      final companion = TransactionsCompanion(
        createdByUserId: d.Value(userId),
        lastEditedByUserId: d.Value(userId),
        paidByUserId: shouldBackfillPaidBy
            ? d.Value(userId)
            : const d.Value.absent(),
      );
      await (db.update(
        db.transactions,
      )..where((t) => t.id.equals(txId))).write(companion);
    } else {
      // 编辑:写 lastEditedByUserId;paidByUserId 为空时回填操作者
      // (旧数据从未回填的极端场景,支出人全局必填),非空视为手改值保留。
      final existing = await getTransactionById(txId);
      final shouldBackfillPaidBy =
          existing == null ||
          existing.paidByUserId == null ||
          existing.paidByUserId!.isEmpty;
      final companion = TransactionsCompanion(
        lastEditedByUserId: d.Value(userId),
        paidByUserId: shouldBackfillPaidBy
            ? d.Value(userId)
            : const d.Value.absent(),
      );
      await (db.update(
        db.transactions,
      )..where((t) => t.id.equals(txId))).write(companion);
    }
  }

  Future<void> deleteTransaction(int id) async {
    // 删除交易记录及其编辑历史，避免详情页按 recordId 反查时“复活”孤儿历史。
    await db.transaction(() async {
      await deleteTransactionsWithEditHistories(db, [id]);
    });
  }

  // ==================== 编辑历史 ====================

  Future<List<RecordEditHistory>> getEditHistories(int recordId) async {
    // 按版本号倒序:最新版本在前,详情区块从新到旧展示
    return (db.select(db.recordEditHistories)
          ..where((t) => t.recordId.equals(recordId))
          ..orderBy([
            (t) => d.OrderingTerm(
              expression: t.version,
              mode: d.OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<int> appendEditHistory({
    required int recordId,
    required int version,
    String? operatorUserId,
    required String summary,
  }) async {
    // 追加历史前校验交易仍存在,避免竞态/脏引用把历史写成一个孤儿行。
    final tx = await getTransactionById(recordId);
    if (tx == null) {
      throw StateError('交易不存在，无法追加编辑历史: $recordId');
    }
    return db
        .into(db.recordEditHistories)
        .insert(
          RecordEditHistoriesCompanion.insert(
            recordId: recordId,
            version: version,
            operatorUserId: d.Value(operatorUserId),
            summary: summary,
          ),
        );
  }

  Future<Transaction?> getTransactionById(int id) async {
    return await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTransactionCompanion(
    TransactionsCompanion item, {
    bool recordChanges = true,
  }) async {
    // 子仓库不挂 changeTracker,recordChanges 仅为接口一致保留。
    _validateAaJsonInCompanion(item);
    final effective =
        item.syncId == const d.Value.absent() || item.syncId.value == null
        ? item.copyWith(syncId: d.Value(_uuid.v4()))
        : item;
    return await db.into(db.transactions).insert(effective);
  }

  Future<List<({Transaction t, Category? category})>>
  transactionsWithCategoryAll({int? ledgerId}) async {
    final select = db.select(db.transactions);
    if (ledgerId != null) {
      select.where((t) => t.ledgerId.equals(ledgerId));
    }
    select.orderBy([
      (t) =>
          d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc),
    ]);
    final rows = await select.join(_txJoins()).get();
    final out = rows
        .map(
          (r) => (
            t: r.readTable(db.transactions),
            category: r.readTableOrNull(db.categories),
          ),
        )
        .toList();
    return _hydrateSharedOverrides(out);
  }

  Future<List<({Transaction t, Category? category})>>
  getRecentTransactionsWithCategory({
    required int ledgerId,
    required int limit,
  }) async {
    final q =
        (db.select(db.transactions)
              ..where((t) => t.ledgerId.equals(ledgerId))
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: t.happenedAt,
                  mode: d.OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .join(_txJoins());
    final rows = await q.get();
    final out = rows
        .map(
          (r) => (
            t: r.readTable(db.transactions),
            category: r.readTableOrNull(db.categories),
          ),
        )
        .toList();
    return _hydrateSharedOverrides(out);
  }

  Future<int> countByTypeInRange({
    required int ledgerId,
    required String type,
    required DateTime start,
    required DateTime end,
  }) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM transactions WHERE ledger_id = ?1 AND type = ?2 AND happened_at >= ?3 AND happened_at < ?4',
          variables: [
            d.Variable<int>(ledgerId),
            d.Variable<String>(type),
            d.Variable<DateTime>(start),
            d.Variable<DateTime>(end),
          ],
          readsFrom: {db.transactions},
        )
        .getSingle();
    final v = row.data['c'];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  Future<List<Transaction>> getTransactionsByLedger(int ledgerId) async {
    return await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) => d.OrderingTerm(
              expression: t.happenedAt,
              mode: d.OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<List<Transaction>> getAaTransactionsByLedger(int ledgerId) async {
    // AA 分摊统计:过滤出 aaMode != 1 的交易。
    // aaMode=null/0(人均)和 aaMode=2(指定)都纳入;"不分摊"(aaMode=1)跳过。
    // 用 isNull() | isNotValue(1) 兼容 null 和非 1 两种"参与分摊"的情况。
    return await (db.select(db.transactions)
          ..where(
            (t) =>
                t.ledgerId.equals(ledgerId) &
                (t.aaMode.isNull() | t.aaMode.isNotValue(1)),
          )
          ..orderBy([
            (t) => d.OrderingTerm(
              expression: t.happenedAt,
              mode: d.OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<List<Transaction>> getTransactionsByLedgerInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    return await (db.select(db.transactions)
          ..where(
            (t) =>
                t.ledgerId.equals(ledgerId) &
                t.happenedAt.isBiggerOrEqualValue(start) &
                t.happenedAt.isSmallerThanValue(end),
          )
          ..orderBy([
            (t) => d.OrderingTerm(
              expression: t.happenedAt,
              mode: d.OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<void> updateTransactionLedger({
    required int id,
    required int ledgerId,
  }) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(ledgerId: d.Value(ledgerId)),
    );
  }

  // ==================== 日历功能相关 ====================

  Future<Map<String, double>> getDailyTotalsByMonth({
    required int ledgerId,
    required DateTime month,
  }) async {
    final startDate = DateTime(month.year, month.month, 1);
    // 半开区间 [月初, 下月1日):避免 23:59:59 边界漏掉带毫秒的交易。
    final endDate = DateTime(month.year, month.month + 1, 1);

    // 全局仅支出模式，SQL 简化只聚合支出
    final query = '''
      SELECT
        strftime('%Y-%m-%d', happened_at, 'unixepoch', 'localtime') as date,
        SUM(CASE WHEN type = 'expense' AND exclude_from_stats = 0 THEN COALESCE(native_amount, amount) ELSE 0 END) as expense
      FROM transactions
      WHERE ledger_id = ?
        AND happened_at >= ?
        AND happened_at < ?
      GROUP BY date
      ORDER BY date DESC
    ''';

    final results = await db
        .customSelect(
          query,
          variables: [
            d.Variable.withInt(ledgerId),
            d.Variable.withDateTime(startDate),
            d.Variable.withDateTime(endDate),
          ],
        )
        .get();

    final map = <String, double>{};
    for (final row in results) {
      final date = row.read<String?>('date');
      if (date == null) continue; // 跳过null日期
      // SQL 聚合的是整数分,除以 100 转成"元"供日历展示。
      final rawExpense = row.data['expense'];
      if (rawExpense is num) {
        map[date] = rawExpense.toDouble() / 100;
      } else if (rawExpense is BigInt) {
        map[date] = rawExpense.toDouble() / 100;
      } else {
        map[date] = 0;
      }
    }

    return map;
  }

  // 返回单日交易及其关联分类
  Future<List<({Transaction t, Category? category})>> getTransactionsByDate({
    required int ledgerId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    // 半开区间 [当天0点, 次日0点):包含 23:59:59.xxx 的毫秒交易。
    final endOfDay = DateTime(date.year, date.month, date.day + 1);

    // 查询当天的所有交易
    final transactions =
        await (db.select(db.transactions)
              ..where(
                (t) =>
                    t.ledgerId.equals(ledgerId) &
                    t.happenedAt.isBiggerOrEqualValue(startOfDay) &
                    t.happenedAt.isSmallerThanValue(endOfDay),
              )
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: t.happenedAt,
                  mode: d.OrderingMode.desc,
                ),
              ]))
            .get();

    if (transactions.isEmpty) return [];

    // 批量查询分类
    final categoryIds = transactions
        .map((t) => t.categoryId)
        .whereType<int>()
        .toSet();
    final categoriesMap = <int, Category>{};
    if (categoryIds.isNotEmpty) {
      final cats = await (db.select(
        db.categories,
      )..where((c) => c.id.isIn(categoryIds.toList()))).get();
      for (final c in cats) {
        categoriesMap[c.id] = c;
      }
    }

    // 组装结果
    final raw = transactions
        .map(
          (tx) => (
            t: tx,
            category: tx.categoryId != null
                ? categoriesMap[tx.categoryId]
                : null,
          ),
        )
        .toList();
    // 共享账本 category hydration
    return _hydrateSharedCategoryOverrides(raw);
  }

  /// 共享账本 category hydration：
  /// tx.categoryId 为空 + categorySyncIdOverride 非空 → 查 SharedLedgerCategories
  /// 构造 synthetic Category
  ///
  /// 日历页 / 详情页等返回 tx + category tuple 的查询都用这个 helper 兜底。
  Future<List<({Transaction t, Category? category})>>
  _hydrateSharedCategoryOverrides(
    List<({Transaction t, Category? category})> rows,
  ) async {
    if (rows.isEmpty) return rows;

    // 收集需要 hydrate 的 syncId
    final catSyncIds = <String>{};
    for (final r in rows) {
      final cov = r.t.categorySyncIdOverride;
      if (r.category == null && cov != null && cov.isNotEmpty) {
        catSyncIds.add(cov);
      }
    }
    if (catSyncIds.isEmpty) return rows;

    // 按交易所属账本的 ledgerSyncId 过滤,避免跨账本 synthetic id 碰撞取错分类。
    final ctx = await _loadSharedHydrationContext(rows, catSyncIds);

    return rows.map((r) {
      Category? category = r.category;
      if (category == null) {
        final cov = r.t.categorySyncIdOverride;
        if (cov != null && cov.isNotEmpty) {
          final ledgerSyncId = ctx.ledgerSyncByLocalId[r.t.ledgerId];
          final s = ledgerSyncId == null
              ? null
              : ctx.sharedByLedgerAndSync['$ledgerSyncId|$cov'];
          if (s != null) {
            category = _syntheticCategoryFromShared(s);
          }
        }
      }
      return (t: r.t, category: category);
    }).toList();
  }

  // ==================== syncId 相关 ====================

  Future<Transaction?> getTransactionBySyncId(String syncId) async {
    return await (db.select(
      db.transactions,
    )..where((t) => t.syncId.equals(syncId))).getSingleOrNull();
  }

  Future<void> updateTransactionBySyncId({
    required String syncId,
    required String type,
    required int amount,
    int? categoryId,
    required DateTime happenedAt,
    String? note,
  }) async {
    await (db.update(
      db.transactions,
    )..where((t) => t.syncId.equals(syncId))).write(
      TransactionsCompanion(
        type: d.Value(type),
        amount: d.Value(amount),
        categoryId: d.Value(categoryId),
        happenedAt: d.Value(happenedAt),
        note: d.Value(note),
      ),
    );
  }

  Future<void> deleteTransactionBySyncId(String syncId) async {
    // 先查找交易ID，以便删除关联数据
    final tx = await getTransactionBySyncId(syncId);
    if (tx != null) {
      await deleteTransaction(tx.id);
    }
  }

  Future<Map<String, int>> updateTransactionsBatchBySyncId(
    List<TransactionUpdateBySyncIdData> updates, {
    bool recordChanges = true,
  }) async {
    if (updates.isEmpty) return const {};
    return db.transaction(() async {
      await db.batch((b) {
        for (final u in updates) {
          // currency/native 成对约束：币种为空时折算快照必须一并清空；
          // 币种非空且云端缺 nativeAmount 时按 1:1 兜底，避免 CHECK 拒绝。
          final effectiveCurrency =
              u.overwriteSnapshot ? u.currencyCode : null;
          final effectiveNative = u.overwriteSnapshot
              ? (effectiveCurrency != null
                  ? (u.nativeAmount ?? u.amount)
                  : null)
              : null;
          b.update(
            db.transactions,
            TransactionsCompanion(
              type: d.Value(u.type),
              amount: d.Value(u.amount),
              categoryId: d.Value(u.categoryId),
              happenedAt: d.Value(u.happenedAt),
              note: d.Value(u.note),
              currencyCode: u.overwriteSnapshot
                  ? d.Value(effectiveCurrency)
                  : const d.Value.absent(),
              nativeAmount: u.overwriteSnapshot
                  ? d.Value(effectiveNative)
                  : const d.Value.absent(),
              excludeFromStats: u.overwriteSnapshot
                  ? d.Value(u.excludeFromStats ?? false)
                  : const d.Value.absent(),
              paidByUserId: u.overwriteSnapshot
                  ? d.Value(u.paidByUserId)
                  : const d.Value.absent(),
              aaMode: u.overwriteSnapshot
                  ? d.Value(u.aaMode)
                  : const d.Value.absent(),
              aaParticipants: u.overwriteSnapshot
                  ? d.Value(u.aaParticipants)
                  : const d.Value.absent(),
              aaSplits: u.overwriteSnapshot
                  ? d.Value(u.aaSplits)
                  : const d.Value.absent(),
            ),
            where: (t) => t.syncId.equals(u.syncId),
          );
        }
      });
      // 反查 (syncId, txId) 映射,caller 用它批量更新 tag 关联
      final syncIds = updates.map((u) => u.syncId).toList();
      final rows = await (db.select(
        db.transactions,
      )..where((t) => t.syncId.isIn(syncIds))).get();
      return {
        for (final tx in rows)
          if (tx.syncId != null) tx.syncId!: tx.id,
      };
    });
  }

  Future<int> deleteTransactionsBatchBySyncIds(
    List<String> syncIds, {
    bool recordChanges = true,
  }) async {
    // recordChanges 由 LocalRepository wrapper 处理(子仓库无 changeTracker)。
    if (syncIds.isEmpty) return 0;
    return db.transaction(() async {
      // SELECT 拿到 tx id 列表
      final rows = await (db.select(
        db.transactions,
      )..where((t) => t.syncId.isIn(syncIds))).get();
      final txIds = rows.map((r) => r.id).toList();
      if (txIds.isEmpty) return 0;
      // 统一入口同时清掉这些交易的编辑历史，避免批量删除产生孤儿行。
      final deleted = await deleteTransactionsWithEditHistories(db, txIds);
      return deleted;
    });
  }
}
