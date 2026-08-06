import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:spitout/data/db.dart';

import '../helpers/test_isolation.dart';

/// v2 → v5 迁移「端到端升级」测试(v3 数据回填 + v4 完整性加固 + v5 列名统一)。
///
/// 与 `aa_statistics_schema_test.dart`（在新建库上手动执行迁移 SQL 副本）不同，
/// 本文件验证的是真实升级路径：
///   1. 构造一个「停留在 v2 版本」的旧库（含 v2 存量数据）；
///   2. 用当前 `SpitoutDatabase`（schemaVersion=5）重新打开同一数据库文件，
///      由 drift 自动检测 `user_version=2 < 5` 并触发真实的 `onUpgrade(2→5)`；
///   3. 验证 v3 回填语义（空支出人按 创建人→编辑人→空串 回填）与重复升级幂等。
///
/// 构造方式说明：v3 迁移块只包含数据回填 UPDATE、无任何 DDL（见
/// `test('v2 与 v3 schema 快照无结构差异')` 的断言），因此「当前表结构建库 +
/// 手动把 user_version 降为 2」构造出的库，其结构与本应存在的真实 v2 库完全
/// 等价，再用真实迁移逻辑升级，即为可靠的端到端验证。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late Directory tmpDir;
  late File dbFile;

  // 记录本用例打开过的数据库连接，统一在 tearDown 关闭：
  // 断言失败提前退出时，靠它避免连接未关闭导致 Windows 下文件被占用无法删除。
  final List<SpitoutDatabase> openedDbs = [];

  setUp(() {
    // 每个用例独立的临时目录/数据库文件，避免用例间串扰；位于系统临时目录，
    // 用例结束由 tearDown 清理。
    tmpDir = Directory.systemTemp.createTempSync('spitout_upgrade_test_');
    dbFile = File(p.join(tmpDir.path, 'old_v2.sqlite'));
    openedDbs.clear();
  });

  tearDown(() async {
    // 先关闭所有连接，再删除文件；各自容错，避免清理逻辑本身引发新的失败。
    for (final db in openedDbs) {
      try {
        await db.close();
      } catch (_) {
        // 连接可能已被测试手动关闭，关闭操作幂等失败时忽略。
      }
    }
    // SQLite 处于 WAL 模式时会生成 -wal / -shm 伴生文件，必须一并删除，
    // 否则下次 `Directory.delete(recursive: true)` 会因残留文件而失败。
    for (final f in [
      dbFile,
      File('${dbFile.path}-wal'),
      File('${dbFile.path}-shm'),
    ]) {
      try {
        if (f.existsSync()) {
          await f.delete();
        }
      } catch (_) {
        // 极端情况下文件仍被外部占用，忽略，交由系统临时目录回收。
      }
    }
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {
      // 同上，忽略清理失败。
    }
  });

  /// 构造「停留在 v2 版本」的旧库：
  /// 1. 用当前 `SpitoutDatabase` 建出全量表结构（v2/v3 无结构差异，见下方结构断言）；
  /// 2. 手动把 `user_version` 降为 2，模拟一个刚完成 v2 迁移、未升级到 v3 的旧库；
  /// 3. 写入 [insertSql] 指定的 v2 存量数据。
  ///
  /// 返回已打开的数据库实例；连接统一由 tearDown 关闭。
  Future<SpitoutDatabase> buildV2OldDb(String insertSql) async {
    final db = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    openedDbs.add(db);
    await db.customStatement('PRAGMA user_version = 2;');
    await db.customStatement(insertSql);
    return db;
  }

  /// 解析 [name] 表的列名集合（快照 JSON 中 `entities[].data` 为表定义）。
  Set<String> tableColumnNames(Map<String, dynamic> schema, String name) {
    final entities = (schema['entities'] as List<dynamic>).cast<Map<String, dynamic>>();
    final table = entities.firstWhere(
      (e) => e['data']?['name'] == name,
      orElse: () => throw StateError('schema 快照中找不到表: $name'),
    );
    final columns = (table['data']?['columns'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return columns.map((c) => c['name'] as String).toSet();
  }

  test('v2 与 v3 schema 快照无结构差异（v3 迁移纯数据回填）', () {
    // 设计意图：端到端升级测试用「当前结构 + user_version=2」构造 v2 旧库，
    // 其前提是 v2→v3 不改变任何表结构。这里直接对比官方快照佐证该前提，
    // 若未来 v3 引入 DDL，本断言会先行失败，提醒更新构造方式。
    final v2 = jsonDecode(
      File('drift_schemas/drift_schema_v2.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final v3 = jsonDecode(
      File('drift_schemas/drift_schema_v3.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    for (final table in ['transactions', 'ledgers', 'ledger_virtual_users']) {
      expect(
        tableColumnNames(v2, table),
        tableColumnNames(v3, table),
        reason: '表 $table 在 v2→v3 不应有结构变化（本次迁移仅数据回填）',
      );
    }
  });

  test('端到端：v2 旧库升级到 v3，存量空支出人按「创建人→编辑人→空串」回填', () async {
    // v2 存量数据覆盖五种典型场景，用于验证 v3 回填语义与"不覆盖已有手选值"：
    //  A. paid_by_user_id 为 NULL、创建人存在      → 回填创建人 u-a
    //  B. paid_by_user_id 为空串、创建人存在      → 空串同样视为"未知"，回填 u-a
    //  C. paid_by_user_id 为 NULL、仅编辑人存在   → 回填编辑人 u-b
    //  D. paid_by_user_id 为空串、创建/编辑双缺失 → 落空串（唯一无法恢复的极端数据）
    //  E. paid_by_user_id 已有非空手选值 u-x      → 保持不变，不被回填覆盖
    final db1 = await buildV2OldDb(
      '''
      INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY');
      INSERT INTO transactions
        (ledger_id, type, amount, happened_at, note,
         created_by_user_id, last_edited_by_user_id, paid_by_user_id)
      VALUES
        (1, 'expense', 10.0, 1704067200, 'A-null有创建人',  'u-a', 'u-b', NULL),
        (1, 'expense', 11.0, 1704067200, 'B-空串有创建人',  'u-a', 'u-b', ''),
        (1, 'expense', 12.0, 1704067200, 'C-null无创建人',  NULL,  'u-b', NULL),
        (1, 'expense', 13.0, 1704067200, 'D-空串双缺失',    NULL,  NULL,  ''),
        (1, 'expense', 14.0, 1704067200, 'E-已有手选值',    'u-a', 'u-b', 'u-x');
      ''',
    );
    await db1.close();

    // 重新打开同一文件：drift 检测到 user_version=2 < schemaVersion=5，
    // 触发真实的 onUpgrade(2→3)，执行 v3 回填迁移。
    final db2 = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    openedDbs.add(db2);
    final rows = await db2.customSelect(
      'SELECT note, paid_by_user_id FROM transactions ORDER BY id;',
    ).get();

    // 迁移后 user_version 应推进到 5（drift 在 onUpgrade 成功后写入）。
    final versionRow = await db2.customSelect('PRAGMA user_version;').getSingle();
    expect(versionRow.read<int>('user_version'), 5, reason: '升级后 user_version 应为 5');

    // 断言五种场景的回填结果。
    final byNote = {
      for (final r in rows) r.read<String>('note'): r.read<String>('paid_by_user_id'),
    };
    expect(byNote['A-null有创建人'], 'u-a');
    expect(byNote['B-空串有创建人'], 'u-a');
    expect(byNote['C-null无创建人'], 'u-b');
    expect(byNote['D-空串双缺失'], '');
    expect(byNote['E-已有手选值'], 'u-x');
  });

  test('端到端：重复升级（v2→v3 二次触发）不崩溃且不改写已回填数据', () async {
    // 设计意图：验证 v3 迁移的 WHERE 守卫幂等性。真实场景下 onUpgrade 不会
    // 重复执行，但若升级中断后重试、或数据库版本异常回退，迁移 SQL 会被再次
    // 执行；必须保证二次执行不报错、也不覆盖用户已修正的支出人。
    final db1 = await buildV2OldDb(
      '''
      INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY');
      INSERT INTO transactions
        (ledger_id, type, amount, happened_at, note,
         created_by_user_id, last_edited_by_user_id, paid_by_user_id)
      VALUES
        (1, 'expense', 10.0, 1704067200, 'A-null有创建人', 'u-a', 'u-b', NULL),
        (1, 'expense', 14.0, 1704067200, 'E-已有手选值',   'u-a', 'u-b', 'u-x');
      ''',
    );
    await db1.close();

    // 第一次升级。
    final db2 = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    openedDbs.add(db2);
    await db2.close();

    // 手动把版本降回 2 并再次打开 → 触发第二次 onUpgrade(2→3)。
    final revert = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    openedDbs.add(revert);
    await revert.customStatement('PRAGMA user_version = 2;');
    await revert.close();

    final db3 = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    openedDbs.add(db3);
    final rows = await db3.customSelect(
      'SELECT note, paid_by_user_id FROM transactions ORDER BY id;',
    ).get();
    final byNote = {
      for (final r in rows) r.read<String>('note'): r.read<String>('paid_by_user_id'),
    };
    expect(byNote['A-null有创建人'], 'u-a', reason: '二次升级后回填结果不变');
    expect(byNote['E-已有手选值'], 'u-x', reason: '二次升级不得覆盖已有手选值');
  });
}
