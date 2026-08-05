import '../db.dart';

/// 记账页分类树：一级分类列表 + 父分类ID → 二级分类列表的映射。
///
/// 设计意图：记账编辑页分类网格需要「全部一级 + 各一级的全部二级」，
/// 由 [CategoryRepository.getCategoryTree]（主表）或共享账本等效查询
/// （SharedLedgerCategories，synthetic id）一次性构建。
class CategoryPickerTree {
  const CategoryPickerTree({required this.topLevel, required this.children});

  /// 一级分类（按 sortOrder 升序）
  final List<Category> topLevel;

  /// 父分类 ID → 其子分类列表（仅含有子分类的父项；子列表按 sortOrder 升序）。
  /// 共享账本 Editor 视角下键与值均为 synthetic id（负数）。
  final Map<int, List<Category>> children;

  /// 空树（无分类场景）
  static const empty = CategoryPickerTree(topLevel: [], children: {});
}

/// 分类Repository接口
/// 定义分类相关的所有数据操作
abstract class CategoryRepository {
  /// 在单个事务中执行分类写入动作。
  ///
  /// 模板批量写入等「父+子必须整体成功」的场景使用:任一步失败整体回滚,
  /// 不会留下只有父没有子的半套数据。实现方用底层数据库事务包装 [action]。
  Future<T> runInTransaction<T>(Future<T> Function() action);

  /// 创建分类。撞同名抛 [DuplicateNameException]。
  ///
  /// 唯一性契约(作用域内唯一):
  ///   - 同一父级作用域内 (name,kind) 不重名(一级分类之间 / 同父的二级之间);
  ///   - 跨父级的二级分类允许同名(如「购物>鞋子」「服装>鞋子」);
  ///   - 一级与二级允许同名(如「服装」父分类 vs「购物>服装」子分类)。
  /// UI 主动建应已先过 [isCategoryNameDuplicate];import / 自动记账等静默路径
  /// 要 get-or-create 语义请用 [upsertCategory]。
  ///
  /// 可选 [syncId] / [level] / [parentId]:给 seed 这种需要显式塞确定性
  /// syncId / 指定层级和父级的路径用;UI 主动建一般不传(走默认 L1 + auto v4 id)。
  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    int level = 1,
    int? parentId,
    String? syncId,
  });

  /// 创建二级分类。同一 [parentId] 下撞同名抛 [DuplicateNameException]
  /// (跨父级允许同名,见 [createCategory] 的作用域唯一契约)。
  /// [syncId] 同 [createCategory]:可选,seed 显式传,UI 不传走 auto v4。
  Future<int> createSubCategory({
    required int parentId,
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    String? syncId,
  });

  /// 更新分类
  /// [parentId] 传入具体值表示设置父分类，传入 -1 表示清空父分类（变为一级分类）
  /// [level] 传入 1 或 2 表示修改分类层级
  Future<void> updateCategory(
    int id, {
    String? name,
    String? icon,
    int? parentId,
    int? level,
  });

  /// 删除分类。
  ///
  /// 仅允许删除“无子分类且无关联交易”的空分类;否则抛 [StateError],调用方
  /// 必须先通过 [deleteTransactionsByCategoryIds] / [promoteSubCategoriesToTopLevel]
  /// 或 [deleteCategoriesByIds] 显式编排,避免静默留下孤儿交易/子分类。
  Future<void> deleteCategory(int id);

  /// 批量删除分类
  Future<void> deleteCategoriesByIds(List<int> ids);

  /// 批量删除指定分类下的所有交易记录（仅删交易，不删分类本身）
  /// 用于"删除分类和分类下的所有数据"场景：先清交易再删分类。
  Future<int> deleteTransactionsByCategoryIds(List<int> categoryIds);

  /// 将指定父分类下的所有二级分类提升为一级分类（parentId=null, level=1）
  /// 用于"删除分类但保留二级分类"场景：提升子分类后再删除父分类。
  /// 返回被提升的分类数量。
  Future<int> promoteSubCategoriesToTopLevel(int parentId);

  /// 按 (name,kind) 取分类;不存在则按给定 kind/icon/sortOrder 建一条(L1)。
  /// 命中已存在时,icon/sortOrder 参数被忽略 —— 保留已有那条的元数据。
  ///
  /// 注意:作用域唯一契约下 (name,kind) 可能命中多行(跨父级同名),此时取
  /// id 最小的一行(seed 插入顺序稳定,结果确定)。import 等按名匹配的调用方
  /// 天然无法区分同名分类,该歧义可接受。
  Future<({int id, bool created})> upsertCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  });

  /// 根据ID获取分类
  Future<Category?> getCategoryById(int categoryId);

  /// 按 synthetic id 反查分类 — 给交易编辑器 "initial selected" 用。
  /// 正数 id → 主表 Categories(等价 [getCategoryById]);负数 id →
  /// SharedLedgerCategories 找 syntheticIdForSyncId 命中(共享账本
  /// Editor 视角的 synthetic 分类)。
  ///
  /// 放在接口的原因:UI 统一走 `repo.findCategoryBySyntheticId`,
  /// 不依赖 LocalRepository 的 Drift 具体实现,遵循
  /// 「查询一律走 repositoryProvider」的分层约定。
  Future<Category?> findCategoryBySyntheticId(int id, {String? ledgerSyncId});

  /// 共享账本 picker 过滤:Editor + 共享账本 → 用 SharedLedger* 表数据
  /// 替换主表结果(synthetic id < 0);单人账本 / Owner → 原样返回 [all]。
  ///
  /// 把「解析 ledger picker 上下文 + 过滤」两步编排封装在数据层内部,
  /// UI 一次调用到位,无需感知 LocalRepository / SpitoutDatabase 扩展。
  /// [topLevelOnly] true 时 SharedLedger* 数据只返 level=1。
  Future<List<Category>> filterCategoriesForLedgerPicker(
    List<Category> all, {
    int? ledgerId,
    String? kind,
    bool topLevelOnly = true,
  });

  /// 批量根据 ID 获取分类。未命中返回不包含。
  /// 用于统计页聚合分类树时一次性取回所有 Category，避免 N+1 查询。
  Future<Map<int, Category>> getCategoriesByIds(Iterable<int> ids);

  /// 获取所有分类
  Future<List<Category>> getAllCategories();

  /// 获取所有分类(本地 + 共享账本的 synthetic 分类)，用于跨账本列表按 id 映射分类
  Future<List<Category>> getAllCategoriesIncludingShared();

  /// 获取所有一级分类
  Future<List<Category>> getTopLevelCategories(String kind);

  /// 获取指定一级分类下的所有二级分类
  Future<List<Category>> getSubCategories(int parentId);

  /// 一次性获取指定类型的分类树（一级列表 + 二级按父ID分组）。
  ///
  /// 单条查询取回该 kind 的 level 1+2 全部记录后按 parentId 内存分组，
  /// 避免「先查一级、再逐父查子」的 N+1 模式，供记账页分类网格使用。
  Future<CategoryPickerTree> getCategoryTree(String kind);

  /// 获取可用于记账的分类（叶子分类）
  Future<List<Category>> getUsableCategories(String kind);

  /// 检查分类名称是否重复(按「作用域」判重,跨 kind 允许同名):
  ///   - [parentId] 为 null → 在一级分类(根作用域)内判重;
  ///   - [parentId] 非 null → 在该父级的二级分类之间判重。
  Future<bool> isCategoryNameDuplicate({
    required String name,
    required String kind,
    int? excludeId,
    int? parentId,
  });

  /// 检查分类是否有子分类
  Future<bool> hasSubCategories(int categoryId);

  /// 获取分类的子分类数量
  Future<int> getSubCategoryCount(int categoryId);

  /// 获取分类下的交易数量
  Future<int> getTransactionCountByCategory(int categoryId);

  /// 批量获取所有分类的交易数量
  Future<Map<int, int>> getAllCategoryTransactionCounts();

  /// 获取分类汇总信息（总笔数、总金额、平均金额）
  Future<({int totalCount, double totalAmount, double averageAmount})>
  getCategorySummary(int categoryId);

  /// 获取分类下的所有交易记录
  Future<List<Transaction>> getTransactionsByCategory(int categoryId);

  /// 获取分类下的所有交易记录（支持自定义排序）
  Future<List<Transaction>> getTransactionsByCategoryWithSort(
    int categoryId, {
    String sortBy = 'time',
    bool ascending = false,
  });

  /// 分类迁移（将fromCategoryId的所有交易迁移到toCategoryId）
  Future<int> migrateCategory({
    required int fromCategoryId,
    required int toCategoryId,
  });

  /// 迁移分类下的所有交易和子分类
  Future<({int migratedTransactions, int migratedSubCategories})>
  migrateCategoryTransactions({
    required int fromCategoryId,
    required int toCategoryId,
  });

  /// 获取分类迁移信息
  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo({
    required int fromCategoryId,
    required int toCategoryId,
  });

  /// 批量更新分类排序
  Future<void> updateCategorySortOrders(
    List<({int id, int sortOrder})> updates,
  );

  /// 获取分类的完整路径名称（一级/二级）
  Future<String> getCategoryFullName(int categoryId);

  /// 响应式监听分类信息变化
  Stream<Category?> watchCategory(int categoryId, {String? ledgerSyncId});

  /// 响应式监听分类下的交易变化
  ///
  /// [includeSubCategories] 为 true 时，若 [categoryId] 是一级分类，则同时
  /// 包含其所有二级分类的交易 —— 用于分类汇总页展示一级分类的全量数据。
  /// 默认 false，仅查该分类直接交易。
  Stream<List<Transaction>> watchTransactionsByCategory(
    int categoryId, {
    int? ledgerId,
    bool includeSubCategories = false,
  });

  /// 响应式监听分类及其子分类的变化
  Stream<List<Category>> watchCategoryWithSubs(int categoryId);

  /// 响应式监听所有分类及其交易数量变化
  Stream<List<({Category category, int transactionCount})>>
  watchCategoriesWithCount();

  /// 批量插入分类
  Future<void> batchInsertCategories(List<CategoriesCompanion> categories);

  /// 插入单个分类（返回新ID）
  Future<int> insertCategory(CategoriesCompanion category);
}
