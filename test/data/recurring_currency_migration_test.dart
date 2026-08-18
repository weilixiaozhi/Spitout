import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart' show VerifySelf;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:spitout/data/db.dart';

import '../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  test('v5 周期模板升级后按原账本本位币回填 currencyCode', () async {
    final dir = Directory.systemTemp.createTempSync(
      'spitout_recurring_currency_',
    );
    final file = File(p.join(dir.path, 'v5.sqlite'));
    SpitoutDatabase? oldDb;
    SpitoutDatabase? upgradedDb;

    try {
      // 先用当前建表器构造完整数据库，再移除 v6 新列并回退版本号，
      // 这样测试覆盖真实 onUpgrade，且不会用手写 SQL 漏掉无关表结构。
      oldDb = SpitoutDatabase.forTesting(NativeDatabase(file));
      await oldDb.customSelect('SELECT 1').get();
      await oldDb.customStatement(
        'ALTER TABLE recurring_transactions DROP COLUMN currency_code;',
      );
      await oldDb.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, '旧账本', 'cny');",
      );
      await oldDb.customStatement(
        'INSERT INTO recurring_transactions '
        '(ledger_id, type, amount, frequency, start_date) '
        "VALUES (1, 'expense', 12345, 'monthly', 1767225600);",
      );
      await oldDb.customStatement('PRAGMA user_version = 5;');
      await oldDb.close();
      oldDb = null;

      upgradedDb = SpitoutDatabase.forTesting(NativeDatabase(file));
      final recurring = await upgradedDb.select(
        upgradedDb.recurringTransactions,
      ).getSingle();
      final version = await upgradedDb
          .customSelect('PRAGMA user_version;')
          .getSingle();

      expect(recurring.currencyCode, 'CNY');
      expect(version.read<int>('user_version'), 6);
      await upgradedDb.validateDatabaseSchema();
    } finally {
      await oldDb?.close();
      await upgradedDb?.close();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Windows 可能延迟释放 SQLite 句柄，测试结果不应受临时文件清理影响。
      }
    }
  });
}
