// v1 → v5 迁移「端到端升级」测试。
//
// 锚点：drift_schemas/drift_schema_v1.json（v1 官方 schema 快照）与各版本
// 迁移语义。现有测试已覆盖 v2→v5（aa_migration_upgrade_test）与 v3→v5
// （v4_precision_migration_test），唯独缺少从 v1 起步的路径——onUpgrade
// 中 `from < 2` 的 v2 块（AA 列 + 虚拟用户表 + 支出人回填）始终没有真实
// 执行过。
//
// 本文件用 sqlite3 按 v1 快照构造真实 v1 结构（amount/native_amount 为
// TEXT、无 AA 字段、无外键/CHECK/索引、ledger_members 为 email 列），
// 写入 v1 存量数据后交由当前 SpitoutDatabase 触发 onUpgrade(1→5)，验证
// 完整升级链：
//   1. v2：补 AA 列 + 建 ledger_virtual_users + 按创建人回填支出人；
//   2. v3：空字符串支出人回退到编辑人/空串；
//   3. v4：金额 TEXT→INTEGER(分)、孤儿数据清理、CHECK/外键/索引落地；
//   4. v5：ledger_members.email → account 列名统一。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:spitout/data/db.dart';

import '../helpers/test_isolation.dart';

/// drift_schema_v1.json 导出的 v1 建表 DDL（金额列为 TEXT）。
const _v1Ddl = r'''
CREATE TABLE ledgers (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CNY',
  type TEXT NOT NULL DEFAULT 'personal',
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
  sync_id TEXT,
  my_role TEXT NOT NULL DEFAULT 'owner',
  member_count INTEGER NOT NULL DEFAULT 1,
  is_shared INTEGER NOT NULL CHECK ("is_shared" IN (0, 1)) DEFAULT 0,
  owner_user_id TEXT,
  month_start_day INTEGER NOT NULL DEFAULT 1,
  storage_mode TEXT NOT NULL DEFAULT 'local'
);
CREATE TABLE categories (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  icon TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  parent_id INTEGER,
  level INTEGER NOT NULL DEFAULT 1,
  sync_id TEXT
);
CREATE TABLE transactions (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  ledger_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  amount TEXT NOT NULL,
  category_id INTEGER,
  happened_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
  note TEXT,
  recurring_id INTEGER,
  sync_id TEXT,
  created_by_user_id TEXT,
  last_edited_by_user_id TEXT,
  category_sync_id_override TEXT,
  exclude_from_stats INTEGER NOT NULL CHECK ("exclude_from_stats" IN (0, 1)) DEFAULT 0,
  currency_code TEXT,
  native_amount TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  last_edited_at INTEGER
);
CREATE TABLE record_edit_histories (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  record_id INTEGER NOT NULL,
  version INTEGER NOT NULL,
  operator_user_id TEXT,
  summary TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE TABLE recurring_transactions (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  ledger_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  amount TEXT NOT NULL,
  category_id INTEGER,
  note TEXT,
  frequency TEXT NOT NULL,
  interval INTEGER NOT NULL DEFAULT 1,
  day_of_month INTEGER,
  day_of_week INTEGER,
  month_of_year INTEGER,
  start_date INTEGER NOT NULL,
  end_date INTEGER,
  last_generated_date INTEGER,
  enabled INTEGER NOT NULL CHECK ("enabled" IN (0, 1)) DEFAULT 1,
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
  updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE TABLE local_changes (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,
  entity_id INTEGER NOT NULL,
  entity_sync_id TEXT NOT NULL,
  ledger_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  payload_json TEXT,
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
  pushed_at INTEGER
);
CREATE TABLE sync_state (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  provider_type TEXT NOT NULL DEFAULT 'spitout_cloud',
  server_cursor INTEGER NOT NULL DEFAULT 0,
  last_push_at INTEGER,
  last_pull_at INTEGER
);
CREATE TABLE ledger_members (
  ledger_sync_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  email TEXT,
  display_name TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL,
  joined_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE shared_ledger_categories (
  ledger_sync_id TEXT NOT NULL,
  sync_id TEXT NOT NULL,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  icon TEXT,
  color TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  parent_name TEXT,
  parent_sync_id TEXT,
  updated_at INTEGER NOT NULL
);
CREATE TABLE sync_pull_errors (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  change_id INTEGER NOT NULL UNIQUE,
  ledger_external_id TEXT,
  entity_type TEXT NOT NULL,
  entity_sync_id TEXT NOT NULL,
  action TEXT NOT NULL,
  raw_change_json TEXT NOT NULL,
  error_class TEXT,
  error_message TEXT,
  stack_trace TEXT,
  first_seen_at INTEGER NOT NULL,
  last_attempt_at INTEGER NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 1,
  user_action TEXT,
  resolved_at INTEGER
);
CREATE TABLE exchange_rates (
  base_currency TEXT NOT NULL,
  quote_currency TEXT NOT NULL,
  rate_date TEXT NOT NULL,
  rate TEXT NOT NULL,
  source TEXT NOT NULL,
  fetched_at INTEGER NOT NULL
);
CREATE TABLE exchange_rate_overrides (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  sync_id TEXT,
  base_currency TEXT NOT NULL,
  quote_currency TEXT NOT NULL,
  rate TEXT NOT NULL,
  updated_at INTEGER
);
CREATE TABLE snapshot_dirty_ledgers (
  ledger_id INTEGER NOT NULL,
  dirty_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late Directory tmpDir;
  late File dbFile;
  final List<SpitoutDatabase> openedDbs = [];

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('spitout_v1_upgrade_');
    dbFile = File(p.join(tmpDir.path, 'old_v1.sqlite'));
    openedDbs.clear();
  });

  tearDown(() async {
    for (final db in openedDbs) {
      try {
        await db.close();
      } catch (_) {}
    }
    for (final f in [
      dbFile,
      File('${dbFile.path}-wal'),
      File('${dbFile.path}-shm'),
    ]) {
      try {
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  /// 按 v1 快照构造旧库：13 张表 + 代表性存量数据，user_version=1。
  void buildV1OldDb() {
    final db = sqlite3.open(dbFile.path);
    try {
      db.execute(_v1Ddl);
      db.execute(
        "INSERT INTO ledgers (id, name, sync_id, month_start_day) VALUES "
        "(1, '旧账本', 'led-1', 15), "
        "(2, '纯本地', NULL, 1);",
      );
      db.execute(
        "INSERT INTO categories (id, name, kind, parent_id, level, sync_id) VALUES "
        "(1, '餐饮', 'expense', NULL, 1, 'cat-1'), "
        "(2, '外卖', 'expense', 1, 2, 'cat-2'), "
        "(3, '孤儿二级', 'expense', 99, 2, 'cat-3');",
      );
      // 金额为 v1 TEXT（元）；覆盖各迁移分支：
      //  - t1: 外币缺快照 → v4 按 amount 补快照
      //  - t2: 本位币但快照脏(非空) → v4 清空快照
      //  - t3: 有创建人 → v2 回填创建人
      //  - t4: 无创建人但有过编辑人 → v2 空串、v3 回退编辑人
      //  - t5: 双缺 → 空串兜底
      db.execute(
        "INSERT INTO transactions "
        "(id, ledger_id, type, amount, category_id, happened_at, note, sync_id, "
        "created_by_user_id, last_edited_by_user_id, currency_code, native_amount, version) "
        "VALUES "
        "(1, 1, 'expense', '12.34', 1, 1783516800, '外币', 'tx-1', 'u-owner', NULL, 'USD', NULL, 1), "
        "(2, 1, 'expense', '5.00', NULL, 1783516801, '脏快照', NULL, NULL, NULL, NULL, '5.50', 1), "
        "(3, 1, 'expense', '8.00', 2, 1783516802, NULL, 'tx-3', 'u-owner', NULL, NULL, NULL, 3), "
        "(4, 2, 'expense', '3.00', NULL, 1783516803, NULL, NULL, NULL, 'u-editor', NULL, NULL, 1), "
        "(5, 2, 'expense', '1.00', NULL, 1783516804, NULL, NULL, NULL, NULL, NULL, NULL, 1), "
        "(6, 1, 'expense', '9.99', NULL, 1783516805, '重复syncId', 'tx-dup', NULL, NULL, NULL, NULL, 1), "
        "(7, 1, 'expense', '0.50', NULL, 1783516806, '重复syncId2', 'tx-dup', NULL, NULL, NULL, NULL, 1);",
      );
      db.execute(
        "INSERT INTO record_edit_histories (id, record_id, version, operator_user_id, summary) VALUES "
        "(1, 3, 2, 'u-owner', '改金额'), "
        "(2, 999, 2, 'u-ghost', '孤儿历史');",
      );
      db.execute(
        "INSERT INTO recurring_transactions "
        "(id, ledger_id, type, amount, frequency, interval, day_of_month, start_date) VALUES "
        "(1, 1, 'expense', '30.00', 'monthly', 1, 5, 1783000000);",
      );
      db.execute(
        "INSERT INTO local_changes "
        "(id, entity_type, entity_id, entity_sync_id, ledger_id, action, payload_json) VALUES "
        "(1, 'transaction', 1, 'tx-1', 1, 'create', '{}');",
      );
      db.execute(
        "INSERT INTO sync_state (id, device_id, provider_type, server_cursor) VALUES "
        "(1, 'dev-a', 'spitout_cloud', 10), "
        "(2, 'dev-a', 'spitout_cloud', 20);",
      );
      db.execute(
        "INSERT INTO ledger_members (ledger_sync_id, user_id, email, display_name, role, joined_at, updated_at) "
        "VALUES ('led-1', 'u-owner', 'owner@example.com', 'Owner', 'owner', 1783000000, 1783000000);",
      );
      db.execute(
        "INSERT INTO shared_ledger_categories "
        "(ledger_sync_id, sync_id, name, kind, sort_order, level, updated_at) VALUES "
        "('led-1', 'shcat-1', '共享餐饮', 'expense', 0, 1, 1783000000);",
      );
      db.execute(
        "INSERT INTO sync_pull_errors "
        "(change_id, entity_type, entity_sync_id, action, raw_change_json, first_seen_at, last_attempt_at) "
        "VALUES (7, 'transaction', 'tx-1', 'upsert', '{}', 1783000000, 1783000000);",
      );
      db.execute(
        "INSERT INTO exchange_rates "
        "(base_currency, quote_currency, rate_date, rate, source, fetched_at) VALUES "
        "('CNY', 'USD', '2026-08-08', '7.2', 'server', 1783000000);",
      );
      db.execute(
        "INSERT INTO exchange_rate_overrides (id, sync_id, base_currency, quote_currency, rate) VALUES "
        "(1, 'ov-1', 'CNY', 'USD', '7.25');",
      );
      db.execute(
        "INSERT INTO snapshot_dirty_ledgers (ledger_id, dirty_at) VALUES (1, 1783000000);",
      );
      db.execute('PRAGMA user_version = 1;');
    } finally {
      db.close();
    }
  }

  /// 用当前 SpitoutDatabase 打开旧库，触发真实 onUpgrade(1→5)。
  Future<SpitoutDatabase> openMigrated() async {
    final db = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    openedDbs.add(db);
    await db.customSelect('SELECT 1').get();
    return db;
  }

  Future<Map<String, dynamic>> rowBySql(String sql) async {
    final db = openedDbs.last;
    return (await db.customSelect(sql).getSingle()).data;
  }

  Future<List<Map<String, dynamic>>> rowsBySql(String sql) async {
    final db = openedDbs.last;
    return (await db.customSelect(sql).get()).map((r) => r.data).toList();
  }

  test('v1 库升级到 v5：版本号与 v2 结构落地', () async {
    buildV1OldDb();
    await openMigrated();

    final version =
        (await rowBySql('PRAGMA user_version'))['user_version'];
    expect(version, 5);

    // v2：ledgers.aa_enabled + transactions AA 列 + ledger_virtual_users 表
    final aaCols =
        await rowsBySql("SELECT name FROM pragma_table_info('transactions')");
    final txNames = aaCols.map((r) => r['name']).toSet();
    expect(txNames, containsAll([
      'paid_by_user_id', 'aa_mode', 'aa_participants', 'aa_splits',
    ]));
    final ledgerCols =
        await rowsBySql("SELECT name FROM pragma_table_info('ledgers')");
    expect(ledgerCols.map((r) => r['name']), contains('aa_enabled'));
    final virtualTables =
        await rowsBySql("SELECT name FROM sqlite_master WHERE type='table'");
    expect(virtualTables.map((r) => r['name']), contains('ledger_virtual_users'));
  });

  test('v1 金额 TEXT → v4 INTEGER(分) 换算与成对约束落地', () async {
    buildV1OldDb();
    await openMigrated();

    final t1 = await rowBySql('SELECT amount, native_amount, currency_code '
        'FROM transactions WHERE id = 1');
    expect(t1['amount'], 1234); // 12.34 元 → 1234 分
    expect(t1['native_amount'], 1234); // 外币缺快照 → 按 amount 补
    expect(t1['currency_code'], 'USD');

    final t2 = await rowBySql('SELECT amount, native_amount, currency_code '
        'FROM transactions WHERE id = 2');
    expect(t2['amount'], 500);
    expect(t2['native_amount'], isNull); // 本位币脏快照被清空

    final recurring =
        await rowBySql('SELECT amount FROM recurring_transactions WHERE id = 1');
    expect(recurring['amount'], 3000);
  });

  test('v2/v3 支出人回填：创建人 → 编辑人 → 空串', () async {
    buildV1OldDb();
    await openMigrated();

    final t3 = await rowBySql('SELECT paid_by_user_id FROM transactions WHERE id = 3');
    expect(t3['paid_by_user_id'], 'u-owner');

    final t4 = await rowBySql('SELECT paid_by_user_id FROM transactions WHERE id = 4');
    expect(t4['paid_by_user_id'], 'u-editor');

    final t5 = await rowBySql('SELECT paid_by_user_id FROM transactions WHERE id = 5');
    expect(t5['paid_by_user_id'], '');
  });

  test('v4 孤儿清理与索引落地', () async {
    buildV1OldDb();
    await openMigrated();

    // 孤儿编辑历史被删除
    final histories =
        await rowsBySql('SELECT record_id FROM record_edit_histories');
    expect(histories.map((r) => r['record_id']), [3]);

    // 孤儿二级分类提升为一级
    final orphan = await rowBySql('SELECT parent_id, level FROM categories WHERE id = 3');
    expect(orphan['parent_id'], isNull);
    expect(orphan['level'], 1);

    // 重复 syncId 交易只保留本地 id 最小行
    final dups = await rowsBySql(
        "SELECT id FROM transactions WHERE sync_id = 'tx-dup'");
    expect(dups.map((r) => r['id']), [6]);

    // 同 device+provider 的 sync_state 只保留一行
    final states = await rowsBySql(
        "SELECT id FROM sync_state WHERE device_id = 'dev-a'");
    expect(states.map((r) => r['id']), [1]);

    // v4 唯一/二级索引全部存在
    final indexes = (await rowsBySql(
            "SELECT name FROM sqlite_master WHERE type='index'"))
        .map((r) => r['name'])
        .toSet();
    expect(indexes, containsAll([
      'idx_ledgers_sync_id',
      'idx_categories_sync_id',
      'idx_transactions_sync_id',
      'idx_sync_state_device_provider',
      'idx_transactions_ledger_happened',
      'idx_record_edit_histories_record_id',
      'idx_local_changes_pushed_at',
      'idx_recurring_transactions_ledger_id',
      'idx_rate_override_pair',
    ]));
  });

  test('v4 外键与 CHECK 约束落地', () async {
    buildV1OldDb();
    await openMigrated();

    // record_edit_histories 重建后带指向 transactions 的外键
    final fks = await rowsBySql(
        "SELECT \"table\" FROM pragma_foreign_key_list('record_edit_histories')");
    expect(fks.map((r) => r['table']), contains('transactions'));

    // transactions 重建后带币种成对 CHECK
    final txSql = await rowBySql(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='transactions'");
    expect(txSql['sql'].toString(), contains('aa_mode'));
    expect(txSql['sql'].toString(), contains('currency_code'));

    // ledgers 重建后带月首日 CHECK
    final ledgerSql = await rowBySql(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='ledgers'");
    expect(ledgerSql['sql'].toString(), contains('BETWEEN 1 AND 28'));
  });

  test('v5 ledger_members.email 列改名为 account，数据保留', () async {
    buildV1OldDb();
    await openMigrated();

    final cols =
        await rowsBySql("SELECT name FROM pragma_table_info('ledger_members')");
    expect(cols.map((r) => r['name']), contains('account'));
    expect(cols.map((r) => r['name']), isNot(contains('email')));

    final member = await rowBySql(
        "SELECT account FROM ledger_members WHERE user_id = 'u-owner'");
    expect(member['account'], 'owner@example.com');
  });

  test('未触及的表数据完整保留', () async {
    buildV1OldDb();
    await openMigrated();

    expect((await rowBySql('SELECT COUNT(*) AS c FROM local_changes'))['c'], 1);
    expect((await rowBySql(
            'SELECT COUNT(*) AS c FROM sync_pull_errors'))['c'],
        1);
    expect((await rowBySql(
            'SELECT COUNT(*) AS c FROM exchange_rates'))['c'],
        1);
    expect((await rowBySql(
            'SELECT COUNT(*) AS c FROM exchange_rate_overrides'))['c'],
        1);
    expect((await rowBySql(
            'SELECT COUNT(*) AS c FROM snapshot_dirty_ledgers'))['c'],
        1);
    expect((await rowBySql(
            'SELECT COUNT(*) AS c FROM shared_ledger_categories'))['c'],
        1);
    expect((await rowBySql('SELECT COUNT(*) AS c FROM ledgers'))['c'], 2);
    expect((await rowBySql('SELECT COUNT(*) AS c FROM categories'))['c'], 3);
    expect((await rowBySql('SELECT COUNT(*) AS c FROM transactions'))['c'], 6);
  });
}
