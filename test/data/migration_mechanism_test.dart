/// 数据库迁移机制（Layer 1）测试：直接对 `lib/data/migration_helpers.dart` 的
/// 幂等 helper 生产代码做单测，锁定"老用户升级不崩溃"的底层安全网。
///
/// 覆盖：
///   1. addColumnIfMissing —— 加列 + 二次调用幂等跳过（不抛 duplicate column）
///   2. createTableIfMissing —— 已存在跳过 / 缺失时按 drift 表定义重建
///   3. dropColumnIfExists —— 删列保数据 + 幂等 + 断点续跑守卫（现场 A/B）
///
/// 设计说明：本文件测的是 helper 的真实实现，而非"与 onUpgrade 一字不差的 SQL
/// 副本"（本测试直接测 helper 的真实实现，而非私有 onUpgrade 的 SQL 副本）。未来首个真实迁移块
/// （1 → 2）落地时，再用 drift schema 快照补端到端升级测试。
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/migration_helpers.dart';

import '../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// 读指定表的全部列名（PRAGMA table_info）。
  Future<Set<String>> columnNames(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  /// 建一个与业务表隔离的探针表，避免 helper 测试污染 onCreate 建好的真实表。
  Future<void> createProbe({String name = 'probe'}) async {
    await db.customStatement(
        'CREATE TABLE $name (id INTEGER PRIMARY KEY, keep_me TEXT, drop_me TEXT)');
    await db.customStatement(
        "INSERT INTO $name (id, keep_me, drop_me) VALUES (1, 'a', 'x')");
  }

  group('addColumnIfMissing', () {
    test('列不存在时加列成功，二次调用幂等跳过', () async {
      await createProbe();
      const alterSql =
          "ALTER TABLE probe ADD COLUMN extra TEXT NOT NULL DEFAULT ''";

      await db.addColumnIfMissing('probe', 'extra', alterSql);
      expect(await columnNames('probe'), contains('extra'));

      // 模拟"迁移跑到一半被杀后重跑"：同一条 ALTER 再执行，不抛 duplicate column
      await db.addColumnIfMissing('probe', 'extra', alterSql);
      final names = await columnNames('probe');
      expect(names.where((n) => n == 'extra').length, 1);
    });

    test('对已存在列直接跳过，不执行 ALTER', () async {
      await createProbe();
      // keep_me 已存在；若真执行 ALTER 会抛 duplicate column，测试通过即证明已跳过
      await db.addColumnIfMissing(
          'probe', 'keep_me', 'ALTER TABLE probe ADD COLUMN keep_me TEXT');
      expect(await columnNames('probe'), contains('keep_me'));
    });
  });

  group('createTableIfMissing', () {
    test('表已存在时跳过（不抛 table already exists）', () async {
      final m = Migrator(db);
      // exchange_rates 由 onCreate 的 createAll() 建好；重复 create 会抛错，
      // 测试通过即证明 helper 正确跳过
      await db.createTableIfMissing(m, 'exchange_rates', db.exchangeRates);
      expect(await columnNames('exchange_rates'), contains('base_currency'));
    });

    test('表缺失时按 drift 表定义重建', () async {
      await db.customSelect('SELECT 1').get(); // 触发 onCreate
      await db.customStatement('DROP TABLE exchange_rates');
      expect(await columnNames('exchange_rates'), isEmpty);

      final m = Migrator(db);
      await db.createTableIfMissing(m, 'exchange_rates', db.exchangeRates);

      final names = await columnNames('exchange_rates');
      expect(names, containsAll(
          ['base_currency', 'quote_currency', 'rate_date', 'rate', 'source']));
    });
  });

  group('dropColumnIfExists', () {
    /// probe 表的重建参数（与 createProbe 的结构对应，去掉 drop_me）。
    const keepColumns = {'id': 'INTEGER', 'keep_me': 'TEXT'};
    const copyColumns = ['id', 'keep_me'];

    test('删列成功且保留列数据不丢', () async {
      await createProbe();

      await db.dropColumnIfExists('probe', 'drop_me',
          keepColumns: keepColumns, copyColumns: copyColumns, primaryKey: 'id');

      final names = await columnNames('probe');
      expect(names, isNot(contains('drop_me')));
      expect(names, containsAll(['id', 'keep_me']));
      final row = await db
          .customSelect('SELECT keep_me FROM probe WHERE id = 1')
          .getSingle();
      expect(row.read<String>('keep_me'), 'a', reason: '重建表后保留列数据必须不丢');
    });

    test('二次调用幂等跳过（列已不存在）', () async {
      await createProbe();
      await db.dropColumnIfExists('probe', 'drop_me',
          keepColumns: keepColumns, copyColumns: copyColumns, primaryKey: 'id');

      // 重跑同一次迁移：不抛错、结构不变
      await db.dropColumnIfExists('probe', 'drop_me',
          keepColumns: keepColumns, copyColumns: copyColumns, primaryKey: 'id');
      expect(await columnNames('probe'), isNot(contains('drop_me')));
    });

    test('断点续跑-现场A：table 缺失但 _old 残留，先恢复现场再完成删列', () async {
      await createProbe();
      // 模拟上次迁移死在 RENAME 之后、CREATE 之前的现场
      await db.customStatement('ALTER TABLE probe RENAME TO probe_old');

      await db.dropColumnIfExists('probe', 'drop_me',
          keepColumns: keepColumns, copyColumns: copyColumns, primaryKey: 'id');

      final names = await columnNames('probe');
      expect(names, isNot(contains('drop_me')));
      expect(names, containsAll(['id', 'keep_me']));
      // 数据不能成孤儿：_old 里的行必须完整迁移回来
      final row = await db
          .customSelect('SELECT keep_me FROM probe WHERE id = 1')
          .getSingle();
      expect(row.read<String>('keep_me'), 'a');
    });

    test('断点续跑-现场B：两表并存且列已删，清掉 _old 即完成', () async {
      await createProbe();
      // 先完整跑一遍删列，再手工造一个 _old 残留，
      // 模拟上次死在收尾 DROP 之前的现场
      await db.dropColumnIfExists('probe', 'drop_me',
          keepColumns: keepColumns, copyColumns: copyColumns, primaryKey: 'id');
      await db.customStatement(
          'CREATE TABLE probe_old (id INTEGER PRIMARY KEY, keep_me TEXT, drop_me TEXT)');

      await db.dropColumnIfExists('probe', 'drop_me',
          keepColumns: keepColumns, copyColumns: copyColumns, primaryKey: 'id');

      // _old 残留被清理，probe 结构/数据不受影响
      final oldRows = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name = 'probe_old'")
          .get();
      expect(oldRows, isEmpty);
      final row = await db
          .customSelect('SELECT keep_me FROM probe WHERE id = 1')
          .getSingle();
      expect(row.read<String>('keep_me'), 'a');
    });
  });
}
