import 'dart:async';

import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/models/category_node.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';
import 'package:spitout/data/models/category_picker_tree.dart';
import 'package:spitout/data/repositories/support/exceptions.dart';

/// 本地分类Repository实现
/// 基于 Drift 数据库实现
class LocalCategoryRepository {
  static const _uuid = Uuid();
  final SpitoutDatabase db;

  LocalCategoryRepository(this.db);

  Future<T> runInTransaction<T>(Future<T> Function() action) =>
      db.transaction(action);

  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    int level = 1,
    int? parentId,
    String? syncId,
  }) async {
    // 撞同名抛 DuplicateNameException。判重按「作用域唯一」契约:
    // 只在同一父级作用域内判重(parentId 为 null → 一级分类之间;非 null →
    // 同父的二级之间)。跨父级/跨层级允许同名(默认 seed 即有「购物>鞋子」
    // 「服装>鞋子」)。caller 显式 handle:
    //   - UI 主动建 → 先过 isCategoryNameDuplicate 警告;真冲突 try/catch 弹 toast
    //   - import / 自动记账等静默路径 → 使用 upsertCategory(get-or-create)
    // 静默复用会吞掉 caller 传的 icon/sortOrder。
    final dupQuery = db.select(db.categories)
      ..where((c) => c.name.equals(name) & c.kind.equals(kind));
    if (parentId == null) {
      dupQuery.where((c) => c.parentId.isNull());
    } else {
      final pid = parentId;
      dupQuery.where((c) => c.parentId.equals(pid));
    }
    final existing = await dupQuery.get();
    if (existing.isNotEmpty) {
      throw DuplicateNameException(
        entityType: 'category',
        name: name,
        existingId: existing.first.id,
      );
    }
    return await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            kind: kind,
            icon: d.Value(icon),
            sortOrder: d.Value(sortOrder ?? 0),
            level: d.Value(level),
            parentId: d.Value(parentId),
            syncId: d.Value(syncId ?? _uuid.v4()),
          ),
        );
  }

  Future<int> createSubCategory({
    required int parentId,
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    String? syncId,
  }) async {
    // 作用域唯一:仅在同一 parentId 下判重,跨父级允许同名二级分类
    final existing =
        await (db.select(db.categories)..where(
              (c) =>
                  c.name.equals(name) &
                  c.kind.equals(kind) &
                  c.parentId.equals(parentId),
            ))
            .get();
    if (existing.isNotEmpty) {
      throw DuplicateNameException(
        entityType: 'category',
        name: name,
        existingId: existing.first.id,
      );
    }
    return await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            kind: kind,
            icon: d.Value(icon),
            parentId: d.Value(parentId),
            level: d.Value(2),
            sortOrder: d.Value(sortOrder ?? 0),
            syncId: d.Value(syncId ?? _uuid.v4()),
          ),
        );
  }

  Future<void> updateCategory(
    int id, {
    String? name,
    String? icon,
    int? parentId,
    int? level,
  }) async {
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name != null ? d.Value(name) : const d.Value.absent(),
        icon: icon != null ? d.Value(icon) : const d.Value.absent(),
        // parentId: -1 表示清空父分类，其他值表示设置父分类
        parentId: parentId != null
            ? (parentId == -1 ? const d.Value(null) : d.Value(parentId))
            : const d.Value.absent(),
        level: level != null ? d.Value(level) : const d.Value.absent(),
      ),
    );
  }

  Future<void> deleteCategory(int id) async {
    // 直接删分类必须 fail-loud:有子分类或交易时静默删分类会让交易 category_id
    // 指向已删除行,统计里变成“未分类”。调用方应先显式编排删除交易/提升子分类。
    final hasSub =
        await (db.select(db.categories)
              ..where((c) => c.parentId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    final hasTx =
        await (db.select(db.transactions)
              ..where((t) => t.categoryId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (hasSub != null || hasTx != null) {
      throw StateError(
        '分类(id=$id)存在子分类或关联交易,禁止直接删除;'
        '请先调用 deleteTransactionsByCategoryIds / promoteSubCategoriesToTopLevel / '
        'deleteCategoriesByIds 显式编排。',
      );
    }
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
  }

  Future<void> deleteCategoriesByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    await (db.delete(db.categories)..where((c) => c.parentId.isIn(ids))).go();
    await (db.delete(db.categories)..where((c) => c.id.isIn(ids))).go();
  }

  Future<int> deleteTransactionsByCategoryIds(List<int> categoryIds) async {
    if (categoryIds.isEmpty) return 0;
    // 批量删除指定分类 ID 关联的所有交易记录
    // 设计意图：与 deleteCategoriesByIds 分离，让 UI 层能灵活组合
    // "先删交易 → 再删分类"或"先删交易 → 提升子分类 → 再删分类"的流程
    return await (db.delete(
      db.transactions,
    )..where((t) => t.categoryId.isIn(categoryIds))).go();
  }

  Future<int> promoteSubCategoriesToTopLevel(int parentId) async {
    return await db.transaction(() async {
      // 获取所有需要提升的二级分类
      final subCategories = await getSubCategories(parentId);
      if (subCategories.isEmpty) return 0;

      // 查当前一级分类的最大 sortOrder，确保提升后的分类排在已有分类之后
      final topLevel =
          await (db.select(db.categories)
                ..where((c) => c.parentId.isNull() & c.level.equals(1))
                ..orderBy([
                  (c) => d.OrderingTerm(
                    expression: c.sortOrder,
                    mode: d.OrderingMode.desc,
                  ),
                ]))
              .get();
      // 从最大 sortOrder + 1 开始递增分配
      int nextSortOrder = topLevel.isEmpty ? 0 : topLevel.first.sortOrder + 1;

      int promoted = 0;
      for (final sub in subCategories) {
        await (db.update(
          db.categories,
        )..where((c) => c.id.equals(sub.id))).write(
          CategoriesCompanion(
            parentId: const d.Value(null),
            level: const d.Value(1),
            sortOrder: d.Value(nextSortOrder++),
          ),
        );
        promoted++;
      }
      return promoted;
    });
  }

  Future<({int id, bool created})> upsertCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  }) async {
    // 按 (name,kind) 找;有则复用,无则用给定 icon/sortOrder 建。
    // 作用域唯一契约下可能命中多行(跨父级同名,如两个「鞋子」),
    // 取 id 最小的一行保证结果确定 —— import 等按名调用方本就无法区分同名。
    final existing =
        await (db.select(db.categories)
              ..where((c) => c.name.equals(name) & c.kind.equals(kind))
              ..orderBy([(c) => d.OrderingTerm.asc(c.id)]))
            .get();
    if (existing.isNotEmpty) {
      return (id: existing.first.id, created: false);
    }
    final id = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            kind: kind,
            icon: d.Value(icon),
            sortOrder: d.Value(sortOrder ?? 0),
            syncId: d.Value(_uuid.v4()),
          ),
        );
    return (id: id, created: true);
  }

  Future<Category?> getCategoryById(int categoryId) async {
    return await (db.select(
      db.categories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
  }

  // 共享账本 synthetic 反查 / picker 过滤:直接委托 SpitoutDatabase 扩展
  // (SharedLedgerPickerFilter),扩展内部已按 id 正负 / ledger 角色分派,
  // 此处只做透传——分层上属于数据层内部实现细节,不泄漏到 UI。

  Future<Category?> findCategoryBySyntheticId(int id, {String? ledgerSyncId}) =>
      db.findCategoryBySyntheticId(id, ledgerSyncId: ledgerSyncId);

  Future<List<Category>> filterCategoriesForLedgerPicker(
    List<Category> all, {
    int? ledgerId,
    String? kind,
    bool topLevelOnly = true,
  }) async {
    final ctx = await db.loadLedgerPickerContext(ledgerId);
    return db.filterCategoriesForLedger(
      all,
      ctx,
      kind: kind,
      topLevelOnly: topLevelOnly,
    );
  }

  Future<Map<int, Category>> getCategoriesByIds(Iterable<int> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return const {};
    // 批量查询避免 N+1：单次 SELECT ... WHERE id IN (...) 取回全部
    final rows = await (db.select(
      db.categories,
    )..where((c) => c.id.isIn(idList))).get();
    return {for (final r in rows) r.id: r};
  }

  Future<List<Category>> getTopLevelCategories(String kind) async {
    return await (db.select(db.categories)
          ..where(
            (c) =>
                c.kind.equals(kind) & c.level.equals(1) & c.parentId.isNull(),
          )
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  Future<List<Category>> getSubCategories(int parentId) async {
    return await (db.select(db.categories)
          ..where((c) => c.parentId.equals(parentId) & c.level.equals(2))
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  Future<CategoryPickerTree> getCategoryTree(String kind) async {
    // 一次查询取回该 kind 的全部 level 1+2 记录，按 sortOrder 排序后内存
    // 拆分一级/二级分组，避免 N+1 查询。
    final rows =
        await (db.select(db.categories)
              ..where((c) => c.kind.equals(kind))
              ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
            .get();
    final topLevel = <Category>[];
    final children = <int, List<Category>>{};
    for (final row in rows) {
      if (row.level == 1 && row.parentId == null) {
        topLevel.add(row);
      } else if (row.level == 2 && row.parentId != null) {
        (children[row.parentId!] ??= []).add(row);
      }
    }
    return CategoryPickerTree(topLevel: topLevel, children: children);
  }

  Future<List<Category>> getUsableCategories(String kind) async {
    final allCategories =
        await (db.select(db.categories)
              ..where((c) => c.kind.equals(kind))
              ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
            .get();
    return CategoryHierarchy.getUsableCategories(allCategories);
  }

  Future<bool> isCategoryNameDuplicate({
    required String name,
    required String kind,
    int? excludeId,
    int? parentId,
  }) async {
    var expression =
        db.categories.name.equals(name) & db.categories.kind.equals(kind);

    // 作用域判重:parentId 为 null → 只和一级分类比;非 null → 只和同父的二级比。
    // 跨父级/跨层级同名是合法设计(见 createCategory 契约注释)。
    if (parentId == null) {
      expression = expression & db.categories.parentId.isNull();
    } else {
      expression = expression & db.categories.parentId.equals(parentId);
    }

    if (excludeId != null) {
      expression = expression & db.categories.id.equals(excludeId).not();
    }

    final query = db.select(db.categories)..where((c) => expression);
    final results = await query.get();
    return results.isNotEmpty;
  }

  Future<bool> hasSubCategories(int categoryId) async {
    final count = await db
        .customSelect(
          'SELECT COUNT(*) as count FROM categories WHERE parent_id = ?',
          variables: [d.Variable.withInt(categoryId)],
          readsFrom: {db.categories},
        )
        .getSingle();

    final c = count.data['count'];
    if (c is int) return c > 0;
    if (c is BigInt) return c > BigInt.zero;
    if (c is num) return c > 0;
    return false;
  }

  Future<int> getSubCategoryCount(int categoryId) async {
    final result = await db
        .customSelect(
          'SELECT COUNT(*) as count FROM categories WHERE parent_id = ?',
          variables: [d.Variable.withInt(categoryId)],
          readsFrom: {db.categories},
        )
        .getSingle();

    final count = result.data['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  Future<int> getTransactionCountByCategory(int categoryId) async {
    final result = await db
        .customSelect(
          'SELECT COUNT(*) AS count FROM transactions WHERE category_id = ?1',
          variables: [d.Variable.withInt(categoryId)],
          readsFrom: {db.transactions},
        )
        .getSingle();

    final count = result.data['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  Future<Map<int, int>> getAllCategoryTransactionCounts() async {
    final result = await db
        .customSelect(
          '''
      SELECT
        c.id as category_id,
        COALESCE(COUNT(t.id), 0) as transaction_count
      FROM categories c
      LEFT JOIN transactions t ON c.id = t.category_id
      GROUP BY c.id
      ''',
          readsFrom: {db.categories, db.transactions},
        )
        .get();

    final Map<int, int> counts = {};
    for (final row in result) {
      final categoryId = row.data['category_id'];
      final count = row.data['transaction_count'];

      if (categoryId is int) {
        int countInt = 0;
        if (count is int) {
          countInt = count;
        } else if (count is BigInt) {
          countInt = count.toInt();
        } else if (count is num) {
          countInt = count.toInt();
        }

        counts[categoryId] = countInt;
      }
    }

    return counts;
  }

  Future<({int totalCount, double totalAmount, double averageAmount})>
  getCategorySummary(int categoryId) async {
    final result = await db
        .customSelect(
          '''
      SELECT
        COUNT(*) as count,
        SUM(CASE WHEN exclude_from_stats = 0 THEN COALESCE(native_amount, amount) ELSE 0 END) as total,
        AVG(CASE WHEN exclude_from_stats = 0 THEN COALESCE(native_amount, amount) END) as average
      FROM transactions
      WHERE category_id = ?1
      ''',
          variables: [d.Variable.withInt(categoryId)],
          readsFrom: {db.transactions},
        )
        .getSingle();

    int parseCount(dynamic v) {
      if (v is int) return v;
      if (v is BigInt) return v.toInt();
      if (v is num) return v.toInt();
      return 0;
    }

    double parseAmount(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is BigInt) return v.toDouble();
      if (v is num) return v.toDouble();
      return 0.0;
    }

    final count = parseCount(result.data['count']);
    // SQL 聚合结果为整数分,转"元"返回(与统计仓库口径一致)。
    final total = parseAmount(result.data['total']) / 100;
    final average = parseAmount(result.data['average']) / 100;

    return (totalCount: count, totalAmount: total, averageAmount: average);
  }

  Future<List<Transaction>> getTransactionsByCategory(int categoryId) async {
    return await (db.select(db.transactions)
          ..where((t) => t.categoryId.equals(categoryId))
          ..orderBy([
            (t) => d.OrderingTerm(
              expression: t.happenedAt,
              mode: d.OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<List<Transaction>> getTransactionsByCategoryWithSort(
    int categoryId, {
    String sortBy = 'time',
    bool ascending = false,
  }) async {
    final query = db.select(db.transactions)
      ..where((t) => t.categoryId.equals(categoryId));

    if (sortBy == 'amount') {
      query.orderBy([
        (t) => d.OrderingTerm(
          // 账本维度「金额排序」按折算值:多币种下 5000 JPY(≈250 CNY)不应
          // 因原币面值大而排在 300 CNY 之前(与年报 largest 比较同口径)。
          expression: d.coalesce([t.nativeAmount, t.amount]),
          mode: ascending ? d.OrderingMode.asc : d.OrderingMode.desc,
        ),
      ]);
    } else {
      query.orderBy([
        (t) => d.OrderingTerm(
          expression: t.happenedAt,
          mode: ascending ? d.OrderingMode.asc : d.OrderingMode.desc,
        ),
      ]);
    }

    return await query.get();
  }

  Future<int> migrateCategory({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    final beforeCount = await getTransactionCountByCategory(fromCategoryId);

    await (db.update(db.transactions)
          ..where((t) => t.categoryId.equals(fromCategoryId)))
        .write(TransactionsCompanion(categoryId: d.Value(toCategoryId)));

    return beforeCount;
  }

  Future<({int migratedTransactions, int migratedSubCategories})>
  migrateCategoryTransactions({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    return await db.transaction(() async {
      final fromCategory = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(fromCategoryId))).getSingle();

      int migratedTransactions = 0;
      int migratedSubCategories = 0;

      if (fromCategory.level == 1) {
        // 一级分类：处理子分类
        final subCategories = await getSubCategories(fromCategoryId);

        if (subCategories.isNotEmpty) {
          for (final sub in subCategories) {
            // 检查目标分类是否已有同名子分类
            final existingSub =
                await (db.select(db.categories)..where(
                      (c) =>
                          c.parentId.equals(toCategoryId) &
                          c.name.equals(sub.name) &
                          c.kind.equals(sub.kind),
                    ))
                    .getSingleOrNull();

            if (existingSub != null) {
              // 合并到已有的同名子分类
              final count =
                  await (db.update(
                    db.transactions,
                  )..where((t) => t.categoryId.equals(sub.id))).write(
                    TransactionsCompanion(categoryId: d.Value(existingSub.id)),
                  );
              migratedTransactions += count;

              // 删除源子分类
              await (db.delete(
                db.categories,
              )..where((c) => c.id.equals(sub.id))).go();
            } else {
              // 将子分类移动到新的父分类下
              await (db.update(db.categories)
                    ..where((c) => c.id.equals(sub.id)))
                  .write(CategoriesCompanion(parentId: d.Value(toCategoryId)));
              migratedSubCategories++;
            }
          }
        }

        // 迁移一级分类自身的交易
        final directCount =
            await (db.update(
              db.transactions,
            )..where((t) => t.categoryId.equals(fromCategoryId))).write(
              TransactionsCompanion(categoryId: d.Value(toCategoryId)),
            );
        migratedTransactions += directCount;
      } else {
        // 二级分类：直接迁移交易
        final count =
            await (db.update(
              db.transactions,
            )..where((t) => t.categoryId.equals(fromCategoryId))).write(
              TransactionsCompanion(categoryId: d.Value(toCategoryId)),
            );
        migratedTransactions = count;
      }

      return (
        migratedTransactions: migratedTransactions,
        migratedSubCategories: migratedSubCategories,
      );
    });
  }

  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    final transactionCount = await getTransactionCountByCategory(
      fromCategoryId,
    );

    final targetCategory = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(toCategoryId))).getSingleOrNull();

    final canMigrate =
        transactionCount > 0 &&
        targetCategory != null &&
        fromCategoryId != toCategoryId;

    return (transactionCount: transactionCount, canMigrate: canMigrate);
  }

  Future<void> updateCategorySortOrders(
    List<({int id, int sortOrder})> updates,
  ) async {
    await db.transaction(() async {
      for (final update in updates) {
        await (db.update(db.categories)..where((c) => c.id.equals(update.id)))
            .write(CategoriesCompanion(sortOrder: d.Value(update.sortOrder)));
      }
    });
  }

  Future<String> getCategoryFullName(int categoryId) async {
    final category = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    if (category == null) return '';

    if (category.level == 1 || category.parentId == null) {
      return category.name;
    }

    final parent = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(category.parentId!))).getSingleOrNull();
    if (parent == null) {
      // 父分类缺失时降级返回子分类名,避免直接抛 StateError。
      return category.name;
    }

    return '${parent.name} / ${category.name}';
  }

  Stream<Category?> watchCategory(int categoryId, {String? ledgerSyncId}) {
    // 负 id 是 SharedLedgerCategories 的 synthetic id
    // (syntheticIdForSyncId 派生)。分类详情页传过来时,要去 shared 表反查
    // 转 synthetic Category 返回,跟 picker / 洞察 路径一致。
    if (categoryId < 0) {
      return _watchSharedCategoryBySyntheticId(categoryId, ledgerSyncId);
    }
    return (db.select(
      db.categories,
    )..where((c) => c.id.equals(categoryId))).watchSingleOrNull();
  }

  /// SharedLedgerCategories 表变化时 re-emit。用 tableUpdates 监听 + 每次
  /// 重查找匹配的 syncId(synthetic id 是 hashCode 派生,反查只能扫表)。
  Stream<Category?> _watchSharedCategoryBySyntheticId(
    int syntheticId,
    String? ledgerSyncId,
  ) {
    final ctrl = StreamController<Category?>();
    StreamSubscription? sub;

    Future<void> emit() async {
      final q = db.select(db.sharedLedgerCategories);
      if (ledgerSyncId != null && ledgerSyncId.isNotEmpty) {
        q.where((t) => t.ledgerSyncId.equals(ledgerSyncId));
      }
      final rows = await q.get();
      for (final s in rows) {
        if (syntheticIdForSyncId(s.syncId) == syntheticId) {
          if (!ctrl.isClosed) {
            // 跟 statistics / picker / synthetic builder 保持一致:有 parentSyncId
            // 就转 synthetic 父 id 写入 parentId,L2 → L1 链路可正确导航。
            final pSyncId = s.parentSyncId;
            final parentSyntheticId = (pSyncId != null && pSyncId.isNotEmpty)
                ? syntheticIdForSyncId(pSyncId)
                : null;
            ctrl.add(
              Category(
                id: syntheticId,
                name: s.name,
                kind: s.kind,
                icon: s.icon,
                sortOrder: s.sortOrder,
                parentId: parentSyntheticId,
                level: s.level,
                syncId: s.syncId,
              ),
            );
          }
          return;
        }
      }
      if (!ctrl.isClosed) ctrl.add(null);
    }

    ctrl.onListen = () {
      emit();
      sub = db
          .tableUpdates(d.TableUpdateQuery.onTable(db.sharedLedgerCategories))
          .listen((_) => emit());
    };
    ctrl.onCancel = () async {
      await sub?.cancel();
    };
    return ctrl.stream;
  }

  Stream<List<Transaction>> watchTransactionsByCategory(
    int categoryId, {
    int? ledgerId,
    bool includeSubCategories = false,
  }) {
    // 负 id 表 SharedLedger 分类 — 走 categorySyncIdOverride 过滤。
    if (categoryId < 0) {
      if (includeSubCategories) {
        // 一级 synthetic 分类需含其子分类交易：查 SharedLedgerCategories
        // 找到父 syncId 及其子分类 syncId，按 categorySyncIdOverride.isIn 查询
        return _watchTxByCategorySyntheticIdWithSubs(categoryId, ledgerId);
      }
      return _watchTxByCategorySyntheticId(categoryId, ledgerId);
    }
    if (includeSubCategories) {
      // 一级分类需含其所有二级分类交易：先查子分类 id 列表，
      // 再按 categoryId.isIn([自身, ...子分类]) 查询交易
      return _watchTxByCategoryWithSubs(categoryId, ledgerId);
    }
    final query = db.select(db.transactions)
      ..where((t) => t.categoryId.equals(categoryId));

    if (ledgerId != null) {
      query.where((t) => t.ledgerId.equals(ledgerId));
    }

    query.orderBy([
      (t) =>
          d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc),
    ]);

    return query.watch();
  }

  Stream<List<Transaction>> _watchTxByCategorySyntheticId(
    int syntheticId,
    int? ledgerId,
  ) {
    final ctrl = StreamController<List<Transaction>>();
    StreamSubscription? sub;
    String? matchedSyncId;

    Future<void> resolveSyncId() async {
      if (matchedSyncId != null) return;
      final rows = await db.select(db.sharedLedgerCategories).get();
      for (final s in rows) {
        if (syntheticIdForSyncId(s.syncId) == syntheticId) {
          matchedSyncId = s.syncId;
          return;
        }
      }
    }

    Future<void> emit() async {
      await resolveSyncId();
      if (matchedSyncId == null) {
        if (!ctrl.isClosed) ctrl.add(const []);
        return;
      }
      final q = db.select(db.transactions)
        ..where((t) => t.categorySyncIdOverride.equals(matchedSyncId!))
        ..orderBy([
          (t) => d.OrderingTerm(
            expression: t.happenedAt,
            mode: d.OrderingMode.desc,
          ),
        ]);
      if (ledgerId != null) {
        q.where((t) => t.ledgerId.equals(ledgerId));
      }
      final list = await q.get();
      if (!ctrl.isClosed) ctrl.add(list);
    }

    ctrl.onListen = () {
      emit();
      // 监听 tx 表变化(新增/删除 tx)+ SharedLedgerCategories(分类被删/重命名)
      sub = db
          .tableUpdates(
            d.TableUpdateQuery.onAllTables([
              db.transactions,
              db.sharedLedgerCategories,
            ]),
          )
          .listen((_) => emit());
    };
    ctrl.onCancel = () async {
      await sub?.cancel();
    };
    return ctrl.stream;
  }

  /// 监听本地一级分类及其所有二级分类的交易。
  ///
  /// 设计意图：分类汇总页进入一级分类时，需展示该一级分类下全部交易（含
  /// 直接挂在一级分类上的 + 挂在二级分类上的）。每次 emit 先查子分类 id
  /// 列表（categories 表变化时重查），再用 `categoryId.isIn(ids)` 查交易，
  /// 监听 transactions + categories 表保证子分类增删后列表实时刷新。
  Stream<List<Transaction>> _watchTxByCategoryWithSubs(
    int categoryId,
    int? ledgerId,
  ) {
    final ctrl = StreamController<List<Transaction>>();
    StreamSubscription? sub;

    Future<void> emit() async {
      // 查询该一级分类的所有二级分类 id
      final subCats = await (db.select(
        db.categories,
      )..where((c) => c.parentId.equals(categoryId) & c.level.equals(2))).get();
      // 聚合 id 集合：自身 + 所有子分类
      final ids = <int>[categoryId, ...subCats.map((c) => c.id)];

      final q = db.select(db.transactions)
        ..where((t) => t.categoryId.isIn(ids))
        ..orderBy([
          (t) => d.OrderingTerm(
            expression: t.happenedAt,
            mode: d.OrderingMode.desc,
          ),
        ]);
      if (ledgerId != null) {
        q.where((t) => t.ledgerId.equals(ledgerId));
      }
      final list = await q.get();
      if (!ctrl.isClosed) ctrl.add(list);
    }

    ctrl.onListen = () {
      emit();
      // 监听 tx 表(交易增删改)+ categories 表(子分类增删，需重算 id 列表)
      sub = db
          .tableUpdates(
            d.TableUpdateQuery.onAllTables([db.transactions, db.categories]),
          )
          .listen((_) => emit());
    };
    ctrl.onCancel = () async {
      await sub?.cancel();
    };
    return ctrl.stream;
  }

  /// 监听共享账本 synthetic 一级分类及其所有二级分类的交易。
  ///
  /// 设计意图：共享账本的交易通过 categorySyncIdOverride 关联分类，一级分类
  /// 汇总需含其子分类交易。每次 emit 扫 SharedLedgerCategories 找到父 syncId
  /// 及其子分类 syncId 列表，按 `categorySyncIdOverride.isIn(syncIds)` 查交易。
  /// 监听 transactions + sharedLedgerCategories 表保证实时刷新。
  Stream<List<Transaction>> _watchTxByCategorySyntheticIdWithSubs(
    int syntheticId,
    int? ledgerId,
  ) {
    final ctrl = StreamController<List<Transaction>>();
    StreamSubscription? sub;

    Future<void> emit() async {
      final rows = await db.select(db.sharedLedgerCategories).get();
      // 先找到 syntheticId 对应的父分类 syncId
      String? parentSyncId;
      for (final s in rows) {
        if (syntheticIdForSyncId(s.syncId) == syntheticId) {
          parentSyncId = s.syncId;
          break;
        }
      }
      if (parentSyncId == null) {
        if (!ctrl.isClosed) ctrl.add(const []);
        return;
      }
      // 收集所有子分类的 syncId（parentSyncId 匹配的行）
      final subSyncIds = rows
          .where((s) => s.parentSyncId == parentSyncId)
          .map((s) => s.syncId)
          .toList();
      // 聚合 syncId 集合：父分类自身 + 所有子分类
      final allSyncIds = <String>[parentSyncId, ...subSyncIds];

      final q = db.select(db.transactions)
        ..where((t) => t.categorySyncIdOverride.isIn(allSyncIds))
        ..orderBy([
          (t) => d.OrderingTerm(
            expression: t.happenedAt,
            mode: d.OrderingMode.desc,
          ),
        ]);
      if (ledgerId != null) {
        q.where((t) => t.ledgerId.equals(ledgerId));
      }
      final list = await q.get();
      if (!ctrl.isClosed) ctrl.add(list);
    }

    ctrl.onListen = () {
      emit();
      // 监听 tx 表(交易增删改)+ SharedLedgerCategories(分类增删，需重算 syncId 列表)
      sub = db
          .tableUpdates(
            d.TableUpdateQuery.onAllTables([
              db.transactions,
              db.sharedLedgerCategories,
            ]),
          )
          .listen((_) => emit());
    };
    ctrl.onCancel = () async {
      await sub?.cancel();
    };
    return ctrl.stream;
  }

  Stream<List<Category>> watchCategoryWithSubs(int categoryId) {
    // 负数 id 是 SharedLedgerCategories 的 synthetic 分类：
    // 共享分类不在主表，需走镜像表构造父+子分类树，供分类汇总页渲染。
    if (categoryId < 0) {
      return _watchSharedCategoryWithSubs(categoryId);
    }
    return db
        .customSelect(
          '''
      SELECT * FROM categories
      WHERE id = ? OR parent_id = ?
      ORDER BY level, sort_order
      ''',
          variables: [
            d.Variable.withInt(categoryId),
            d.Variable.withInt(categoryId),
          ],
          readsFrom: {db.categories},
        )
        .watch()
        .map((rows) {
          return rows.map((row) {
            return Category(
              id: row.read<int>('id'),
              name: row.read<String>('name'),
              kind: row.read<String>('kind'),
              icon: row.read<String?>('icon'),
              sortOrder: row.read<int>('sort_order'),
              parentId: row.read<int?>('parent_id'),
              level: row.read<int>('level'),
              syncId: row.read<String?>('sync_id'),
            );
          }).toList();
        });
  }

  /// 监听共享账本 synthetic 一级分类及其所有二级分类。
  ///
  /// 设计意图：分类汇总页需要「一级 + 全部二级」的分类 map 才能给每笔交易
  /// 渲染 icon/名称；共享分类只存在于 SharedLedgerCategories 镜像表，因此
  /// 这里按 syntheticIdForSyncId 反查父分类，并把同一账本下 parentSyncId
  /// 指向父分类的行一起返回。表变化时 re-emit，保证增删改实时刷新。
  Stream<List<Category>> _watchSharedCategoryWithSubs(int syntheticId) {
    final ctrl = StreamController<List<Category>>();
    StreamSubscription? sub;

    Future<void> emit() async {
      final rows = await db.select(db.sharedLedgerCategories).get();
      SharedLedgerCategory? parent;
      for (final s in rows) {
        if (syntheticIdForSyncId(s.syncId) == syntheticId) {
          parent = s;
          break;
        }
      }
      if (parent == null) {
        if (!ctrl.isClosed) ctrl.add(const []);
        return;
      }
      // 闭包内捕获会阻止可空变量的类型提升，先收窄为 final 非空引用
      final matchedParent = parent;
      final parentSyntheticId = syntheticIdForSyncId(matchedParent.syncId);
      final matchedParentSyncId = matchedParent.parentSyncId;
      final parentCategory = _sharedCategoryAsSynthetic(
        matchedParent,
        parentId:
            (matchedParentSyncId != null && matchedParentSyncId.isNotEmpty)
            ? syntheticIdForSyncId(matchedParentSyncId)
            : null,
      );
      final children = rows
          .where((s) => s.parentSyncId == matchedParent.syncId)
          .map(
            (s) => _sharedCategoryAsSynthetic(s, parentId: parentSyntheticId),
          )
          .toList();
      if (!ctrl.isClosed) ctrl.add([parentCategory, ...children]);
    }

    ctrl.onListen = () {
      emit();
      sub = db
          .tableUpdates(d.TableUpdateQuery.onTable(db.sharedLedgerCategories))
          .listen((_) => emit());
    };
    ctrl.onCancel = () async {
      await sub?.cancel();
    };
    return ctrl.stream;
  }

  /// SharedLedgerCategory → synthetic Category。
  /// parentId 显式传入，保证二级分类的父子链在 map 里可导航。
  Category _sharedCategoryAsSynthetic(
    SharedLedgerCategory s, {
    required int? parentId,
  }) {
    return Category(
      id: syntheticIdForSyncId(s.syncId),
      name: s.name,
      kind: s.kind,
      icon: s.icon,
      sortOrder: s.sortOrder,
      parentId: parentId,
      level: s.level,
      syncId: s.syncId,
    );
  }

  Stream<List<({Category category, int transactionCount})>>
  watchCategoriesWithCount() async* {
    await for (final rows
        in db
            .customSelect(
              '''
      SELECT
        c.id as category_id,
        c.name as category_name,
        c.kind as category_kind,
        c.icon as category_icon,
        c.sort_order as category_sort_order,
        c.parent_id as category_parent_id,
        c.level as category_level,
        c.sync_id as category_sync_id,
        COUNT(t.id) as direct_count,
        (
          SELECT COUNT(t2.id)
          FROM transactions t2
          JOIN categories child ON child.id = t2.category_id
          WHERE child.parent_id = c.id
        ) as child_count
      FROM categories c
      LEFT JOIN transactions t ON t.category_id = c.id
      WHERE c.kind != 'transfer'
      GROUP BY c.id, c.name, c.kind, c.icon, c.sort_order, c.parent_id, c.level, c.sync_id
      ORDER BY c.sort_order
      ''',
              readsFrom: {db.categories, db.transactions},
            )
            .watch()) {
      yield [
        for (final row in rows)
          (
            category: Category(
              id: row.read<int>('category_id'),
              name: row.read<String>('category_name'),
              kind: row.read<String>('category_kind'),
              icon: row.read<String?>('category_icon'),
              sortOrder: row.read<int>('category_sort_order'),
              parentId: row.read<int?>('category_parent_id'),
              level: row.read<int>('category_level'),
              syncId: row.read<String?>('category_sync_id'),
            ),
            transactionCount:
                row.read<int>('direct_count') + row.read<int>('child_count'),
          ),
      ];
    }
  }

  Future<List<Category>> getAllCategories() async {
    return await (db.select(
      db.categories,
    )..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)])).get();
  }

  Future<List<Category>> getAllCategoriesIncludingShared() async {
    final result = [...await getAllCategories()];
    // 并入 SharedLedgerCategories 的 synthetic 分类(按 synthetic id 去重，
    // 同一 owner 分类可能镜像到多个账本)。供跨账本列表按 categoryId 映射。
    final seen = <int>{};
    final shared = await db.select(db.sharedLedgerCategories).get();
    for (final s in shared) {
      final synthId = syntheticIdForSyncId(s.syncId);
      if (!seen.add(synthId)) continue;
      final pSyncId = s.parentSyncId;
      final parentSyntheticId = (pSyncId != null && pSyncId.isNotEmpty)
          ? syntheticIdForSyncId(pSyncId)
          : null;
      result.add(
        Category(
          id: synthId,
          name: s.name,
          kind: s.kind,
          icon: s.icon,
          sortOrder: s.sortOrder,
          parentId: parentSyntheticId,
          level: s.level,
          syncId: s.syncId,
        ),
      );
    }
    return result;
  }

  Future<void> batchInsertCategories(
    List<CategoriesCompanion> categories,
  ) async {
    await db.batch((batch) {
      batch.insertAll(db.categories, categories);
    });
  }

  Future<int> insertCategory(CategoriesCompanion category) async {
    return await db.into(db.categories).insert(category);
  }
}
