// OrphanCleaner 契约测试 — 验证孤儿被清理 + tx 失主时只清 FK 不删 tx。

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/services/maintenance/orphan_cleaner.dart';
import 'package:spitout/services/maintenance/orphan_record.dart';
import 'package:spitout/services/maintenance/orphan_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late OrphanScanner scanner;
  late OrphanCleaner cleaner;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    scanner = OrphanScanner(db: db);
    cleaner = OrphanCleaner(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('扫到 → 清理 → 重扫为空(A7)', () async {
    // A7 — 孤儿二级分类
    final parent = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'food', kind: 'expense'),
        );
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'lunch',
          kind: 'expense',
          parentId: d.Value(parent),
          level: const d.Value(2),
        ));
    await (db.delete(db.categories)..where((t) => t.id.equals(parent))).go();

    final before = await scanner.scanAll();
    expect(before.dbOrphans.length, 1);

    final result = await cleaner.clean(before.dbOrphans);
    expect(result.successCount, 1);
    expect(result.failures, isEmpty);

    final after = await scanner.scanAll();
    expect(after.dbOrphans, isEmpty);
  });

  test('C1 local_changes 清理 — 删行', () async {
    await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
          entityType: 'transaction',
          entityId: 999,
          entitySyncId: 'ghost-tx',
          ledgerId: 1,
          action: 'update',
        ));

    final before = await scanner.scanAll();
    expect(before.syncOrphans.length, 1);

    final result = await cleaner.clean(before.syncOrphans);
    expect(result.successCount, 1);

    final after = await scanner.scanAll();
    expect(after.syncOrphans, isEmpty);
  });

  test('空 records 调用 → empty result', () async {
    final result = await cleaner.clean(const []);
    expect(result.successCount, 0);
    expect(result.failures, isEmpty);
  });

  group('A_dup syncId 重复交易清理 (P4)', () {
    test('唯一索引拒绝同 syncId 重复行,清理器无重复可清', () async {
      final lid = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(name: 'L', syncId: d.Value('ledger-1')));
      final id1 = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: lid,
              type: 'expense',
              amount: 1000,
              syncId: const d.Value('dup-sync'),
              happenedAt: d.Value(DateTime(2026, 7, 1)),
            ),
          );
      // 同 syncId 第二行会被 UNIQUE 索引直接拒绝。
      await expectLater(
        db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 1000,
            syncId: const d.Value('dup-sync'),
            happenedAt: d.Value(DateTime(2026, 7, 1)),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // 扫描与清理均无重复可处理。
      final before = await scanner.scanAll();
      expect(
        before.dbOrphans
            .where((r) => r.type == OrphanType.txDuplicateSyncId),
        isEmpty,
      );
      final result = await cleaner.clean(const []);
      expect(result.successCount, 0);
      expect(result.failures, isEmpty);

      // 唯一行仍在。
      final remaining = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(lid)))
          .get();
      expect(remaining, hasLength(1));
      expect(remaining.first.id, id1);
    });
  });

  group('交易删除与迁移', () {
    test('删除失主交易时一并清理编辑历史', () async {
      final lid = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(name: 'L', syncId: d.Value('ledger-1')));
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: lid,
              type: 'expense',
              amount: 1000,
              syncId: const d.Value('tx-1'),
              happenedAt: d.Value(DateTime(2026, 7, 1)),
            ),
          );
      await db.into(db.recordEditHistories).insert(
            RecordEditHistoriesCompanion.insert(
              recordId: txId,
              version: 1,
              operatorUserId: const d.Value('u1'),
              summary: '初始创建',
            ),
          );

      final record = OrphanRecord(
        type: OrphanType.txMissingLedger,
        localId: txId,
        title: '交易 #$txId',
        subtitle: '',
      );
      final result = await cleaner.clean([record]);
      expect(result.successCount, 1);

      final remainingTx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .get();
      final remainingHistory = await (db.select(db.recordEditHistories)
            ..where((h) => h.recordId.equals(txId)))
          .get();
      expect(remainingTx, isEmpty);
      expect(remainingHistory, isEmpty,
          reason: '删除交易必须同步清理编辑历史，避免孤儿历史残留');
    });

    test('迁移交易到账本走统一重算并登记同步变更', () async {
      // 目标账本位币 CNY；交易 currencyCode=null 按本位币兜底，
      // 旧 nativeAmount 故意写错，迁移后应被重算为 amount。
      final sourceLedgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(name: '源', syncId: d.Value('ledger-source')),
          );
      final targetLedgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: '目标',
              currency: const d.Value('CNY'),
              storageMode: const d.Value('cloud'),
              syncId: d.Value('ledger-target'),
            ),
          );
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: sourceLedgerId,
              type: 'expense',
              amount: 12345,
              currencyCode: const d.Value('USD'),
              nativeAmount: const d.Value(9999),
              syncId: const d.Value('tx-move'),
              happenedAt: d.Value(DateTime(2026, 7, 1)),
            ),
          );
      final tracker = ChangeTracker(db);
      final repo = LocalRepository(db, changeTracker: tracker);
      final movingCleaner = OrphanCleaner(db: db, repository: repo);

      await movingCleaner.moveTxToLedger(txId, targetLedgerId);

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .getSingle();
      expect(tx.ledgerId, targetLedgerId);
      expect(tx.nativeAmount, 12345,
          reason: '迁入 CNY 账本后 nativeAmount 应重算为 amount，而非保留旧值');

      final changes = await (db.select(db.localChanges)
            ..where((c) => c.entitySyncId.equals('tx-move')))
          .get();
      expect(changes, hasLength(1));
      expect(changes.single.action, 'update');
      expect(changes.single.ledgerId, targetLedgerId);
    });
  });
}
