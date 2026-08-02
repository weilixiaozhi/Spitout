part of 'sync_engine.dart';

/// 跨设备 ID 解析:syncId(string,跨设备稳定) ↔ 本地 int id(autoIncrement,设
/// 备私有)。apply remote change 时大量用到——server 推下来的 entity 引用都
/// 是 syncId,本地存储用 int id,中间要靠这些函数转换。
extension _SyncEngineResolvers on SyncEngine {
  /// 按 syncId 查 ledger 的本地 int id。用于 apply remote change 时把
  /// server 的 external_id（string）映射成本地 autoIncrement id。
  ///
  /// pull 路径上 [activePullCache] 非空,先查缓存(prime 时全表加载),
  /// miss 才走 DB — 消除 N+1 SELECT。详见 [LookupCache]。
  Future<int?> _resolveLedgerIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final cached = activePullCache?.ledgerId(syncId);
    if (cached != null) return cached;
    final led = await (db.select(db.ledgers)
          ..where((l) => l.syncId.equals(syncId)))
        .getSingleOrNull();
    if (led != null) activePullCache?.putLedger(syncId, led.id);
    return led?.id;
  }

  /// 按 syncId 查 category 的本地 int id。优先级比 name+kind 高：设备间
  /// category.syncId 是稳定的，name 可能被改过 / 有重名。
  ///
  /// 返 null 时调用方应检查 tx 是否有 categorySyncIdOverride
  /// 字段 — 共享账本场景 Editor 选 Owner cat,本地主表没有该 row,需要走
  /// SharedLedgerCategories 表显示。tx UI 应该按 override 优先。
  Future<int?> _resolveCategoryIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final cached = activePullCache?.categoryId(syncId);
    if (cached != null) return cached;
    final cat = await (db.select(db.categories)
          ..where((c) => c.syncId.equals(syncId)))
        .getSingleOrNull();
    if (cat != null) activePullCache?.putCategory(syncId, cat.id);
    return cat?.id;
  }

  /// 根据分类名和类型查找 categoryId
  Future<int?> _resolveCategoryId({
    String? categoryName,
    String? categoryKind,
  }) async {
    if (categoryName == null || categoryName.isEmpty) return null;
    final query = db.select(db.categories)
      ..where((c) => c.name.equals(categoryName));
    if (categoryKind != null) {
      query.where((c) => c.kind.equals(categoryKind));
    }
    // 默认 seed 允许跨父级同名二级分类(如「购物>鞋子」「服装>鞋子」),
    // 按名反查可能命中多行 —— getSingleOrNull 会直接抛 StateError。
    // 这里取 id 最小的一行(seed 插入顺序稳定,结果确定),并记日志便于排查。
    final cats = await query.get();
    if (cats.isEmpty) return null;
    if (cats.length > 1) {
      cats.sort((a, b) => a.id.compareTo(b.id));
      logger.warning('SyncEngine',
          '按名解析分类命中多行: name=$categoryName kind=$categoryKind, 取 id=${cats.first.id}');
    }
    return cats.first.id;
  }

  // server payload 的 accountId 字段不解析(_applyTransactionChange 直接忽略),
  // Accounts 不在当前同步域内。

  Future<String> _getDeviceId() async {
    final user = await provider.auth.currentUser;
    return user?.metadata?['deviceId'] as String? ?? 'unknown';
  }
}
