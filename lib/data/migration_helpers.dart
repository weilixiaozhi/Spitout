import 'package:drift/drift.dart';

/// 数据库迁移幂等工具箱（Layer 1）。
/// 将迁移 DDL 抽为扩展方法，使单元测试可直接覆盖生产代码，
/// 避免 onUpgrade 私有方法无法被单测覆盖的问题。
///
/// 为什么每条迁移 DDL 都要做存在性检查：
/// drift 会把 onUpgrade 包在事务里执行、SQLite 的 DDL 本身也是事务性的，
/// 但如果迁移进行到一半时进程被杀死 / 设备断电，下次启动同一段迁移会重跑。
/// 不做存在性检查就直接 ALTER / CREATE，重跑时会报 "duplicate column" /
/// "table already exists"，把启动卡死——老用户升级即崩溃。
/// 因此这里所有 helper 都先查 PRAGMA / sqlite_master，存在则跳过，保证可幂等重跑。
///
/// 使用纪律：onUpgrade 内的一切 DDL 必须经本扩展的 helper，不得直接 customStatement ALTER。
extension IdempotentMigrationHelpers on GeneratedDatabase {
  /// 幂等加列：列不存在才执行 [alterSql]，已存在则跳过。
  ///
  /// [alterSql] 必须是完整的 `ALTER TABLE ... ADD COLUMN ...` 语句。
  Future<void> addColumnIfMissing(
    String table,
    String column,
    String alterSql,
  ) async {
    if (await _hasColumn(table, column)) return;
    await customStatement(alterSql);
  }

  /// 幂等重命名列：旧列存在且新列不存在时才执行 [renameSql]。
  ///
  /// 用于“字段语义改名但数据不变”的迁移（如 email → account），
  /// 避免升级中断重跑时因列已改名而报 duplicate column。
  Future<void> renameColumnIfExists(
    String table,
    String oldName,
    String newName,
    String renameSql,
  ) async {
    if (!await _hasColumn(table, oldName)) return;
    if (await _hasColumn(table, newName)) return;
    await customStatement(renameSql);
  }

  /// 幂等建表：表不存在才调 `m.createTable`，已存在则跳过。
  ///
  /// 表名查询走参数化（Variable）而非字符串拼接，防止注入。
  Future<void> createTableIfMissing(
    Migrator m,
    String tableName,
    TableInfo<Table, dynamic> table,
  ) async {
    if (await _tableExists(tableName)) return;
    await m.createTable(table);
  }

  /// 幂等删列：低版本 SQLite（< 3.35）不支持 DROP COLUMN，统一用"重建表"法。
  ///
  /// [keepColumns] 保留列的「列名 -> SQL 类型定义」，用于建新表；
  /// [copyColumns] 需要从旧表拷贝数据的列名；[primaryKey] 新表主键列名。
  ///
  /// 断点续跑守卫：重建流程（RENAME → CREATE → INSERT → DROP）不是原子的，
  /// 上次迁移若在半途被杀会留下残留现场，这里先恢复再走正常流程：
  /// - 现场 A：死在 RENAME 之后、CREATE 之前（`table` 缺失、`table_old` 残留，
  ///   数据完整地在 `_old` 里）→ 先改回原名，避免数据孤儿；
  /// - 现场 B：死在收尾 DROP 之前（两表并存、列已删）→ 清掉 `_old` 即完成；
  /// - 现场 C（防御，理论上不出现）：两表并存、列仍在 → `_old` 是陈旧快照，
  ///   数据以 `table` 为准，清掉后重新执行完整流程。
  Future<void> dropColumnIfExists(
    String table,
    String column, {
    required Map<String, String> keepColumns,
    required List<String> copyColumns,
    required String primaryKey,
  }) async {
    // 当前尚未被任何迁移调用，作为未来删列工具保留（含单测覆盖）。
    //
    // 入口参数校验（assert 防的是开发期传错参数）：
    // - copyColumns 为空 → 生成 `INSERT INTO ... () SELECT`，SQLite 直接报错；
    // - copyColumns 含 keepColumns 之外的列 → 建新表后 SELECT 引用不存在的列；
    // - primaryKey 不在 keepColumns → 新表主键列不存在；
    // - 被删列残留在 keep/copy 中 → 重建后该列仍在，“删列”实际不生效。
    assert(copyColumns.isNotEmpty, 'copyColumns 不能为空');
    assert(
      copyColumns.every(keepColumns.containsKey),
      'copyColumns 中的列必须全部存在于 keepColumns',
    );
    assert(
      keepColumns.containsKey(primaryKey),
      'primaryKey 必须存在于 keepColumns',
    );
    assert(!keepColumns.containsKey(column), '被删除列不能出现在 keepColumns 中');
    assert(!copyColumns.contains(column), '被删除列不能出现在 copyColumns 中');

    final oldTable = '${table}_old';

    var hasTable = await _tableExists(table);
    final hasOld = await _tableExists(oldTable);
    if (!hasTable && hasOld) {
      // 现场 A：恢复现场
      await customStatement('ALTER TABLE $oldTable RENAME TO $table');
      hasTable = true;
    } else if (hasTable && hasOld) {
      // 现场 B/C：`_old` 均为可丢弃的副本（列已删 = 废弃副本；列仍在 = 陈旧快照）
      await customStatement('DROP TABLE IF EXISTS $oldTable');
      if (!await _hasColumn(table, column)) return; // 现场 B：收尾即完成
    }

    // 幂等主路径：列已不存在则跳过
    if (!hasTable || !await _hasColumn(table, column)) return;

    final colsDef =
        keepColumns.entries.map((e) => '${e.key} ${e.value}').join(', ');
    final cols = copyColumns.join(', ');
    await customStatement('ALTER TABLE $table RENAME TO $oldTable');
    await customStatement(
        'CREATE TABLE $table ($colsDef, PRIMARY KEY ($primaryKey))');
    await customStatement(
        'INSERT INTO $table ($cols) SELECT $cols FROM $oldTable');
    await customStatement('DROP TABLE $oldTable');
  }

  /// 幂等重建表：旧表结构不满足 [migratedCheckSql] 时，按「RENAME → CREATE →
  /// 拷贝 → DROP」重建，并处理中断残留现场。
  ///
  /// [migratedCheckSql] 返回任意一行即视为新结构已就位（跳过重建）；
  /// [copySql] 必须是 `INSERT INTO <table> (...) SELECT ... FROM <table>_old`
  /// 的完整语句，旧→新列类型转换（如 REAL 金额 → INTEGER 分）在 SELECT 里做。
  ///
  /// 断点续跑守卫与 [dropColumnIfExists] 一致：
  /// - 现场 A：RENAME 后、CREATE 前被杀 → 把 `_old` 改回原名再走主流程；
  /// - 现场 B：新表已建成、`_old` 残留 → 新表已迁移则只清 `_old` 收尾，
  ///   否则丢弃陈旧 `_old` 后重新走完整流程。
  Future<void> rebuildTableIfNeeded(
    Migrator m,
    String table,
    TableInfo<Table, dynamic> newTable, {
    required String migratedCheckSql,
    required String copySql,
  }) async {
    final oldTable = '${table}_old';
    var hasTable = await _tableExists(table);
    final hasOld = await _tableExists(oldTable);

    if (!hasTable && hasOld) {
      // 现场 A：恢复现场后继续正常流程。
      await customStatement('ALTER TABLE $oldTable RENAME TO $table');
      hasTable = true;
    } else if (hasTable && hasOld) {
      final newTableMigrated = await _isMigrated(migratedCheckSql);
      // `_old` 均为可丢弃副本：新表已迁移 → 清旧表即完成；未迁移 → 陈旧快照，
      // 同样清掉后按当前表（未迁移原表）重新走完整流程。
      await customStatement('DROP TABLE IF EXISTS $oldTable');
      if (newTableMigrated) return;
    }

    if (!hasTable) return;
    if (await _isMigrated(migratedCheckSql)) return;

    await customStatement('ALTER TABLE $table RENAME TO $oldTable');
    await m.createTable(newTable);
    await customStatement(copySql);
    await customStatement('DROP TABLE $oldTable');
  }

  /// 判断当前表结构是否已是目标结构（[migratedCheckSql] 有结果即 true）。
  Future<bool> _isMigrated(String migratedCheckSql) async {
    final row = await customSelect(migratedCheckSql).getSingleOrNull();
    return row != null;
  }

  /// 表是否存在（查 sqlite_master，参数化防注入）。
  Future<bool> _tableExists(String name) async {
    final row = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      variables: [Variable<String>(name)],
    ).getSingleOrNull();
    return row != null;
  }

  /// 列是否存在（PRAGMA table_info；表不存在时返回空结果集，自然得到 false）。
  Future<bool> _hasColumn(String table, String column) async {
    // PRAGMA 不支持参数绑定，表名只能字符串拼接；这里用标识符白名单兜底，
    // 与 _tableExists 的参数化查询达到同等的防注入效果。
    if (!_isSafeIdentifier(table) || !_isSafeIdentifier(column)) {
      throw ArgumentError('非法的表名/列名: $table.$column');
    }
    final info = await customSelect('PRAGMA table_info($table)').get();
    return info.any((r) => r.read<String>('name') == column);
  }
}

/// 判断名称是否为合法的 SQLite 标识符（表名/列名），用于拼接前的白名单校验。
bool _isSafeIdentifier(String name) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name);
