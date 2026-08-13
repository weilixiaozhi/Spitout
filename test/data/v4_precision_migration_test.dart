import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:spitout/data/db.dart';

import '../helpers/test_isolation.dart';

/// v3 → v4 迁移「端到端升级」测试。
///
/// v4 是本轮审计修复的核心 schema 版本(当前 head 为 v5,新增列名统一迁移):
///   1. 金额列 REAL → INTEGER(分),存量金额按 100 倍取整迁移;
///   2. currencyCode/nativeAmount 成对约束(同时空或同时非空)归一化;
///   3. syncId 唯一索引前先对非空重复值去重(本地未同步的 NULL 行不受影响);
///   4. 孤儿数据清理(编辑历史/悬空交易/孤儿分类)与强引用外键落地;
///   5. CHECK 约束(monthStartDay/aaMode/level/周期规则/币种成对);
///   6. 高频查询二级索引 + SyncState 唯一约束。
///
/// 与 aa_migration_upgrade_test 不同,这里用 sqlite3 直接构造「真实 v3 结构」
/// (amount/native_amount 为 REAL、无外键/CHECK/新索引),再交给当前
/// SpitoutDatabase 触发真实的 onUpgrade(3→5),验证数据转换与约束落地。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late Directory tmpDir;
  late File dbFile;
  final List<SpitoutDatabase> openedDbs = [];

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('spitout_v4_upgrade_');
    dbFile = File(p.join(tmpDir.path, 'old_v3.sqlite'));
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

  /// 构造 v3 结构旧库(仅含 v4 迁移会触及的表)。
  void buildV3OldDb() {
    final db = sqlite3.open(dbFile.path);
    try {
      db.execute('''
        CREATE TABLE ledgers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          currency TEXT NOT NULL DEFAULT 'CNY',
          type TEXT NOT NULL DEFAULT 'personal',
          created_at INTEGER NOT NULL,
          sync_id TEXT,
          my_role TEXT NOT NULL DEFAULT 'owner',
          member_count INTEGER NOT NULL DEFAULT 1,
          is_shared INTEGER NOT NULL DEFAULT 0,
          owner_user_id TEXT,
          month_start_day INTEGER NOT NULL DEFAULT 1,
          storage_mode TEXT NOT NULL DEFAULT 'local',
          aa_enabled INTEGER NOT NULL DEFAULT 0
        );
      ''');
      db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          kind TEXT NOT NULL,
          icon TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          parent_id INTEGER,
          level INTEGER NOT NULL DEFAULT 1,
          sync_id TEXT
        );
      ''');
      db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ledger_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          category_id INTEGER,
          happened_at INTEGER NOT NULL,
          note TEXT,
          recurring_id INTEGER,
          sync_id TEXT,
          created_by_user_id TEXT,
          last_edited_by_user_id TEXT,
          category_sync_id_override TEXT,
          exclude_from_stats INTEGER NOT NULL DEFAULT 0,
          currency_code TEXT,
          native_amount REAL,
          version INTEGER NOT NULL DEFAULT 1,
          last_edited_at INTEGER,
          paid_by_user_id TEXT,
          aa_mode INTEGER,
          aa_participants TEXT,
          aa_splits TEXT
        );
      ''');
      db.execute('''
        CREATE TABLE record_edit_histories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          record_id INTEGER NOT NULL,
          version INTEGER NOT NULL,
          operator_user_id TEXT,
          summary TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
      db.execute('''
        CREATE TABLE recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ledger_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
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
          enabled INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      db.execute('''
        CREATE TABLE local_changes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id INTEGER NOT NULL,
          entity_sync_id TEXT NOT NULL,
          ledger_id INTEGER NOT NULL,
          action TEXT NOT NULL,
          payload_json TEXT,
          created_at INTEGER NOT NULL,
          pushed_at INTEGER
        );
      ''');
      db.execute('''
        CREATE TABLE sync_state (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          provider_type TEXT NOT NULL DEFAULT 'spitout_cloud',
          server_cursor INTEGER NOT NULL DEFAULT 0,
          last_push_at INTEGER,
          last_pull_at INTEGER
        );
      ''');
      db.execute('''
        CREATE TABLE exchange_rate_overrides (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT,
          base_currency TEXT NOT NULL,
          quote_currency TEXT NOT NULL,
          rate TEXT NOT NULL,
          updated_at INTEGER
        );
      ''');
      db.execute('''
        CREATE TABLE ledger_virtual_users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ledger_id INTEGER NOT NULL,
          sync_id TEXT,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        );
      ''');

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      db.execute(
        "INSERT INTO ledgers (id, name, currency, created_at, sync_id) "
        "VALUES (1, 'L1', 'CNY', $now, 'led-1'), "
        "(2, 'L2', 'CNY', $now, NULL)",
      );
      db.execute(
        "INSERT INTO categories (id, name, kind, level, parent_id, sync_id) "
        "VALUES (1, '父', 'expense', 1, NULL, 'cat-1'), "
        "(2, '子', 'expense', 2, 1, 'cat-2'), "
        "(3, '孤儿', 'expense', 2, 999, 'cat-orphan')",
      );
      db.execute(
        "INSERT INTO transactions "
        "(id, ledger_id, type, amount, happened_at, sync_id, currency_code, native_amount) "
        "VALUES "
        "(1, 1, 'expense', 12.34, $now, 'tx-1', 'CNY', 12.34), "
        "(2, 1, 'expense', 0.30000000000000004, $now, 'tx-2', NULL, NULL), "
        "(3, 1, 'expense', 35.5, $now, 'tx-3', NULL, 35.5), "
        "(4, 1, 'expense', 100.0, $now, 'tx-4', 'USD', NULL), "
        "(5, 2, 'expense', 5.55, $now, NULL, NULL, NULL), "
        "(6, 1, 'expense', 6.66, $now, 'tx-1', 'CNY', 6.66), "
        "(7, 999, 'expense', 7.77, $now, 'tx-7', NULL, NULL)",
      );
      db.execute(
        "INSERT INTO record_edit_histories (id, record_id, version, summary, created_at) "
        "VALUES (1, 1, 2, 'edit tx1', $now), (2, 999, 2, 'orphan history', $now)",
      );
      db.execute(
        "INSERT INTO recurring_transactions "
        "(id, ledger_id, type, amount, frequency, interval, start_date, created_at, updated_at) "
        "VALUES (1, 1, 'expense', 20.5, 'monthly', 1, $now, $now, $now)",
      );
      db.execute(
        "INSERT INTO exchange_rate_overrides "
        "(id, sync_id, base_currency, quote_currency, rate, updated_at) "
        "VALUES (1, 'ero-dup', 'CNY', 'USD', '7.2', $now), "
        "(2, 'ero-dup', 'CNY', 'JPY', '0.048', $now), "
        "(3, NULL, 'CNY', 'EUR', '7.8', $now)",
      );
      db.execute(
        "INSERT INTO ledger_virtual_users (id, ledger_id, sync_id, name, created_at) "
        "VALUES (1, 1, 'vu-1', '室友', $now)",
      );
      db.execute(
        "INSERT INTO sync_state (id, device_id, provider_type, server_cursor) "
        "VALUES (1, 'dev-1', 'spitout_cloud', 10), "
        "(2, 'dev-1', 'spitout_cloud', 11)",
      );
      db.execute('PRAGMA user_version = 3');
    } finally {
      db.close();
    }
  }

  Future<SpitoutDatabase> openCurrent() async {
    final db = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    openedDbs.add(db);
    return db;
  }

  Future<List<Map<String, Object?>>> query(
    SpitoutDatabase db,
    String sql,
  ) async {
    final rows = await db.customSelect(sql).get();
    return [for (final r in rows) r.data];
  }

  test('端到端:v3 旧库升级到 v4,金额转分、成对约束、去重、孤儿清理、索引与 CHECK 落地',
      () async {
    buildV3OldDb();
    final db = await openCurrent();

    // 升级后版本号推进到 4。
    final versionRow =
        await db.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), 5);

    // 1) REAL 金额 → INTEGER 分(0.1+0.2 尾差被规整为 30 分)。
    final txs = await query(db, 'SELECT id, amount, native_amount, '
        'currency_code, sync_id FROM transactions ORDER BY id');
    final byId = {for (final t in txs) t['id']: t};
    expect(byId[1]!['amount'], 1234);
    expect(byId[1]!['native_amount'], 1234);
    expect(byId[1]!['currency_code'], 'CNY');
    expect(byId[2]!['amount'], 30);
    expect(byId[2]!['native_amount'], isNull);
    // currency 为空 → native 清空(成对约束);currency 非空 → native 补 amount。
    expect(byId[3]!['native_amount'], isNull);
    expect(byId[4]!['amount'], 10000);
    expect(byId[4]!['native_amount'], 10000);
    expect(byId[4]!['currency_code'], 'USD');
    // 本地未同步(NULL syncId)行不被去重误删。
    expect(byId[5]!['amount'], 555);
    // 同 syncId 重复行只保留 id 最小者。
    expect(byId.containsKey(6), isFalse);
    // 悬空 ledger 的孤儿交易被清理。
    expect(byId.containsKey(7), isFalse);

    // 2) 编辑历史:保留有效行,清掉孤儿行。
    final histories =
        await query(db, 'SELECT record_id FROM record_edit_histories');
    expect(histories.map((h) => h['record_id']), [1]);

    // 3) 孤儿分类提升为一级。
    final orphan = (await query(
      db,
      "SELECT parent_id, level FROM categories WHERE id = 3",
    ))
        .single;
    expect(orphan['parent_id'], isNull);
    expect(orphan['level'], 1);

    // 4) 非空 syncId 去重(ERO / 虚拟用户),SyncState 按 (device, provider) 去重。
    final ero =
        await query(db, "SELECT COUNT(*) AS c FROM exchange_rate_overrides "
            "WHERE sync_id = 'ero-dup'");
    expect(ero.single['c'], 1);
    final vu = await query(db,
        "SELECT COUNT(*) AS c FROM ledger_virtual_users WHERE sync_id = 'vu-1'");
    expect(vu.single['c'], 1);
    final syncState = await query(db,
        "SELECT COUNT(*) AS c FROM sync_state WHERE device_id = 'dev-1'");
    expect(syncState.single['c'], 1);

    // 5) 外键落地:强引用表带 REFERENCES,外键开关开启后非法引用被拒绝。
    final txFks = await query(
        db, "SELECT \"table\" FROM pragma_foreign_key_list('transactions')");
    expect(txFks.map((r) => r['table']),
        containsAll(['ledgers', 'categories', 'recurring_transactions']));
    final histFks = await query(db,
        "SELECT \"table\" FROM pragma_foreign_key_list('record_edit_histories')");
    expect(histFks.map((r) => r['table']), contains('transactions'));
    await expectLater(
      db.customStatement(
          "INSERT INTO transactions (ledger_id, type, amount, happened_at) "
          "VALUES (999, 'expense', 1, 1)"),
      throwsA(isA<SqliteException>()),
    );

    // 6) CHECK 约束生效。
    await expectLater(
      db.customStatement(
          "INSERT INTO ledgers (name, currency, month_start_day) "
          "VALUES ('X', 'CNY', 0)"),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
          "INSERT INTO transactions (ledger_id, type, amount, happened_at, aa_mode) "
          "VALUES (1, 'expense', 1, 1, 3)"),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
          "INSERT INTO transactions (ledger_id, type, amount, happened_at, "
          "currency_code, native_amount) "
          "VALUES (1, 'expense', 1, 1, 'USD', NULL)"),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
          "INSERT INTO categories (name, kind, level) VALUES ('X', 'expense', 3)"),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
          "INSERT INTO recurring_transactions "
          "(ledger_id, type, amount, frequency, interval, start_date, created_at, updated_at) "
          "VALUES (1, 'expense', 1, 'daily', 0, 1, 1, 1)"),
      throwsA(isA<SqliteException>()),
    );

    // 7) 唯一索引与二级索引落地。
    final indexes = await query(
      db,
      "SELECT name FROM sqlite_master WHERE type='index' "
      "AND name IN ('idx_transactions_sync_id', 'idx_transactions_ledger_happened', "
      "'idx_record_edit_histories_record_id', 'idx_local_changes_pushed_at', "
      "'idx_recurring_transactions_ledger_id', 'idx_sync_state_device_provider', "
      "'idx_ledgers_sync_id', 'idx_categories_sync_id')",
    );
    expect(indexes, hasLength(8));

    // 8) 唯一索引兜底:同 syncId 第二行被拒。
    await expectLater(
      db.customStatement(
          "INSERT INTO transactions (ledger_id, type, amount, happened_at, sync_id) "
          "VALUES (1, 'expense', 1, 1, 'tx-1')"),
      throwsA(isA<SqliteException>()),
    );
  });

  test('端到端:重复升级(v3→v4 二次触发)不崩溃且数据稳定', () async {
    buildV3OldDb();
    final db1 = await openCurrent();
    await db1.close();

    // 手动把版本降回 3,再次触发 onUpgrade(3→5)。
    final revert = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    openedDbs.add(revert);
    await revert.customStatement('PRAGMA user_version = 3;');
    await revert.close();

    final db2 = await openCurrent();
    final txs =
        await query(db2, 'SELECT id, amount FROM transactions ORDER BY id');
    expect(txs.first['amount'], 1234, reason: '二次升级不得重复换算金额');
    expect(txs, hasLength(5), reason: '二次升级不得重复去重/误删');
  });
}
