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
          amount: 10.0,
          categoryId: d.Value(categoryId),
          happenedAt: d.Value(DateTime.now()),
          syncId: d.Value(syncId ?? 'tx-sync'),
        ));
  }

  group('A 类 — DB 孤儿', () {
    test('A6 tx 失主 category', () async {
      final lid = await insertLedger();
      final cid = await insertCategory();
      await insertTransaction(ledgerId: lid, categoryId: cid);
      await (db.delete(db.categories)..where((t) => t.id.equals(cid))).go();

      final report = await scanner.scanAll();
      expect(report.dbOrphans.where((r) => r.type == OrphanType.txMissingCategory)
          .length, 1);
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

    test('A_dup 同账本 syncId 重复 → 报孤儿(保留最早一条)', () async {
      final lid = await insertLedger(syncId: 'ledger-1');
      // 插入 3 条同 syncId 的重复交易
      final id1 = await insertTransaction(ledgerId: lid, syncId: 'dup-sync');
      final id2 = await insertTransaction(ledgerId: lid, syncId: 'dup-sync');
      final id3 = await insertTransaction(ledgerId: lid, syncId: 'dup-sync');
      // 一条唯一 syncId，不应被报
      await insertTransaction(ledgerId: lid, syncId: 'unique-sync');

      final report = await scanner.scanAll();
      final dups = report.dbOrphans
          .where((r) => r.type == OrphanType.txDuplicateSyncId)
          .toList();
      // 保留 MIN(id)=id1，其余 2 条报孤儿
      expect(dups, hasLength(2), reason: '3 条重复只应报 2 条孤儿');
      final dupIds = dups.map((r) => r.localId).toList();
      expect(dupIds, containsAll([id2, id3]));
      expect(dupIds, isNot(contains(id1)), reason: '最早插入的条应被保留');
    });
  });
}
