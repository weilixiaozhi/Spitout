// OrphanScanner 契约测试 — 各类孤儿场景的检测命中。
//
// 用 in-memory Drift db,setUp 里手动插入"破坏完整性"的行(绕过级联删除路径),
// scan 后检查命中条数。

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/services/maintenance/orphan_record.dart';
import 'package:spitout/services/maintenance/orphan_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late OrphanScanner scanner;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    scanner = OrphanScanner(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertLedger({String name = 'L1', String? syncId}) async {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: name, syncId: d.Value(syncId)));
  }

  Future<int> insertCategory({
    String name = 'cat',
    String kind = 'expense',
    int? parentId,
    int level = 1,
  }) async {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          name: name,
          kind: kind,
          parentId: d.Value(parentId),
          level: d.Value(level),
        ));
  }

  Future<int> insertTransaction({
    required int ledgerId,
    int? categoryId,
    String type = 'expense',
    String? syncId,
  }) async {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: type,
          amount: 1000,
          categoryId: d.Value(categoryId),
          happenedAt: d.Value(DateTime.now()),
          syncId: d.Value(syncId ?? 'tx-sync'),
        ));
  }

  group('A 类 — DB 孤儿', () {
    test('A6 tx 失主 category 被外键 SET NULL 兜底', () async {
      final lid = await insertLedger();
      final cid = await insertCategory();
      await insertTransaction(ledgerId: lid, categoryId: cid);
      await (db.delete(db.categories)..where((t) => t.id.equals(cid))).go();

      final tx = (await db.select(db.transactions).get()).single;
      expect(tx.categoryId, isNull,
          reason: 'FK SET NULL:删分类不删交易,也不留失主引用');
      final report = await scanner.scanAll();
      expect(report.dbOrphans.where((r) => r.type == OrphanType.txMissingCategory)
          .length, 0);
    });

    test('A7 二级分类失父', () async {
      final parent = await insertCategory(name: 'food', level: 1);
      await insertCategory(name: 'lunch', level: 2, parentId: parent);
      await (db.delete(db.categories)..where((t) => t.id.equals(parent))).go();

      final report = await scanner.scanAll();
      expect(report.dbOrphans
          .where((r) => r.type == OrphanType.categoryMissingParent)
          .length, 1);
    });


  });

  group('C 类 — 同步孤儿', () {
    test('C1 local_changes 失主实体', () async {
      // unpushed update change,实体不存在
      await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
            entityType: 'transaction',
            entityId: 999,
            entitySyncId: 'ghost-tx',
            ledgerId: 1,
            action: 'update',
          ));

      final report = await scanner.scanAll();
      expect(report.syncOrphans
          .where((r) => r.type == OrphanType.localChangeMissingEntity)
          .length, 1);
    });

    test('delete action 不算孤儿', () async {
      await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
            entityType: 'transaction',
            entityId: 999,
            entitySyncId: 'ghost-tx',
            ledgerId: 1,
            action: 'delete',
          ));

      final report = await scanner.scanAll();
      expect(report.syncOrphans.length, 0);
    });

    test('已 pushed 不算孤儿', () async {
      await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
            entityType: 'transaction',
            entityId: 999,
            entitySyncId: 'pushed-tx',
            ledgerId: 1,
            action: 'update',
            pushedAt: d.Value(DateTime.now()),
          ));

      final report = await scanner.scanAll();
      expect(report.syncOrphans.length, 0);
    });

    test('A_dup 同账本 syncId 重复被唯一索引拒绝(数据库层兜底)', () async {
      final lid = await insertLedger(syncId: 'ledger-1');
      await insertTransaction(ledgerId: lid, syncId: 'dup-sync');
      // 同 syncId 第二行会被 UNIQUE 索引直接拒绝。
      await expectLater(
        insertTransaction(ledgerId: lid, syncId: 'dup-sync'),
        throwsA(isA<SqliteException>()),
      );

      final report = await scanner.scanAll();
      expect(
        report.dbOrphans
            .where((r) => r.type == OrphanType.txDuplicateSyncId),
        isEmpty,
        reason: '唯一索引已兜底,重复交易无法写入',
      );
    });
  });
}
