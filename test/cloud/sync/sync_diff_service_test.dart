import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:spitout/utils/currency/money_cents.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/cloud/sync/sync_diff_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/models/import_models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/services/import/data_import_service.dart';

import '../../helpers/test_isolation.dart';

/// 内存数据库的同步 diff 服务测试。
///
/// 覆盖目标：[SyncDiffService] 的 diff 计算与变更应用两个核心流程，
/// 尤其是云端无 syncId 退化为 null、排序（added→modified→deleted）、
/// 金额/时间/备注/类型的差异判定，以及 deleted 的 syncId 路径与
/// fallback id 兜底路径。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late SyncDiffService service;

  setUp(() async {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    service = SyncDiffService(dataImportPort: dataImportService);
  });

  tearDown(() async {
    await db.close();
  });

  /// 建一个云端账本，返回 ledgerId。
  Future<int> createLedger({String syncId = 'ledger-1'}) async {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          syncId: Value(syncId),
        ));
  }

  /// 插入一条本地交易，返回 Transaction 行。
  Future<Transaction> insertLocalTx(
    int ledgerId, {
    String syncId = 'tx-1',
    Decimal? amount,
    String type = 'expense',
    DateTime? happenedAt,
    String? note,
    String? currencyCode,
    int? nativeAmount,
    bool excludeFromStats = false,
    String? paidByUserId,
    int? aaMode,
    String? aaParticipants,
    String? aaSplits,
  }) async {
    final effectiveAmount = amount ?? Decimal.parse('100');
    final id = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: type,
            amount: yuanToCents(effectiveAmount),
            happenedAt: Value(happenedAt ?? DateTime(2024, 1, 1, 12, 0, 0)),
            note: Value(note),
            syncId: Value(syncId),
            currencyCode: Value(currencyCode),
            nativeAmount: Value(nativeAmount),
            excludeFromStats: Value(excludeFromStats),
            paidByUserId: Value(paidByUserId),
            aaMode: Value(aaMode),
            aaParticipants: Value(aaParticipants),
            aaSplits: Value(aaSplits),
          ),
        );
    return (await repo.getTransactionsByLedger(ledgerId)).firstWhere((t) => t.id == id);
  }

  group('computeDiff', () {
    test('云端与本地都为空 → 返回空预览而非 null', () async {
      final ledgerId = await createLedger();
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: const [],
      );
      expect(preview, isNotNull);
      expect(preview!.isEmpty, isTrue);
      expect(preview.addedCount, 0);
      expect(preview.modifiedCount, 0);
      expect(preview.deletedCount, 0);
    });

    test('云端非空但全部无 syncId → 返回 null（无法安全 diff）', () async {
      final ledgerId = await createLedger();
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('10'),
            happenedAt: _t(2024, 1, 1),
          ),
        ],
      );
      expect(preview, isNull);
    });

    test('云端新增一条（本地无）→ added，且字段完整', () async {
      final ledgerId = await createLedger();
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('12.5'),
            happenedAt: _t(2024, 1, 1),
            note: '午餐',
            syncId: 'tx-new-1',
          ),
        ],
      );
      expect(preview!.addedCount, 1);
      final change = preview.changes.single;
      expect(change.type, SyncChangeType.added);
      expect(change.cloudTransaction!.syncId, 'tx-new-1');
      expect(change.localTransaction, isNull);
    });

    test('云端与本地内容完全一致 → 无任何变更', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(ledgerId, amount: Decimal.parse('50.5'), note: '通勤');
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('50.5'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            note: '通勤',
            syncId: 'tx-1',
          ),
        ],
      );
      expect(preview!.isEmpty, isTrue);
    });

    test('金额不同 → modified，diffDetails 含金额说明', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(ledgerId, amount: Decimal.parse('50.5'), note: '通勤');
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('60.0'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            note: '通勤',
            syncId: 'tx-1',
          ),
        ],
      );
      expect(preview!.modifiedCount, 1);
      final change = preview.changes.single;
      expect(change.diffDetails.join(), contains('金额'));
      expect(change.cloudTransaction!.syncId, 'tx-1');
      expect(change.localTransaction!.syncId, 'tx-1');
    });

    test('金额亚分差异（<0.001）不判定为变更', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(ledgerId, amount: Decimal.parse('50.501'), note: '通勤');
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('50.5'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            note: '通勤',
            syncId: 'tx-1',
          ),
        ],
      );
      expect(preview!.isEmpty, isTrue);
    });

    test('时间不同（跨秒）→ modified；亚秒差异不触发', () async {
      final ledgerId = await createLedger();
      // 本地 12:00:00，云端 12:00:01 → 秒级差异触发
      await insertLocalTx(ledgerId, happenedAt: DateTime(2024, 1, 1, 12, 0, 0));
      final preview1 = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('100.0'),
            happenedAt: DateTime(2024, 1, 1, 12, 0, 1),
            syncId: 'tx-1',
          ),
        ],
      );
      expect(preview1!.modifiedCount, 1);

      // 亚秒差异（毫秒不同）不触发
      await db.update(db.transactions).write(TransactionsCompanion(
            happenedAt: Value(_t(2024, 1, 1, 12, 0, 0)),
          ));
      final preview2 = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('100.0'),
            // 毫秒不同但秒相同
            happenedAt: DateTime(2024, 1, 1, 12, 0, 0, 500),
            syncId: 'tx-1',
          ),
        ],
      );
      expect(preview2!.isEmpty, isTrue);
    });

    test('备注不同 → modified', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(ledgerId, note: '旧备注');
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('100.0'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            note: '新备注',
            syncId: 'tx-1',
          ),
        ],
      );
      expect(preview!.modifiedCount, 1);
      expect(preview.changes.single.diffDetails.join(), contains('备注'));
    });

    test('类型不同 → modified', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(ledgerId, type: 'expense');
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'income',
            amount: Decimal.parse('100.0'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            syncId: 'tx-1',
          ),
        ],
      );
      expect(preview!.modifiedCount, 1);
      expect(preview.changes.single.diffDetails.join(), contains('类型'));
    });

    test('仅币种/折算/统计标记不同 → modified（全字段快照契约）', () async {
      final ledgerId = await createLedger(); // CNY 账本
      await insertLocalTx(
        ledgerId,
        amount: Decimal.parse('100'),
        currencyCode: 'CNY',
        nativeAmount: 10000,
        paidByUserId: 'u1',
        aaMode: 2,
        aaParticipants: '["u1","u2"]',
        aaSplits: '{"u1":"50.00","u2":"50.00"}',
      );
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('100'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            syncId: 'tx-1',
            currencyCode: 'USD',
            nativeAmount: Decimal.parse('80'),
            excludeFromStats: true,
            paidByUserId: 'u1',
            aaMode: 2,
            aaParticipants: '["u1","u2"]',
            aaSplits: '{"u1":"50.00","u2":"50.00"}',
          ),
        ],
      );
      expect(preview!.modifiedCount, 1);
      final details = preview.changes.single.diffDetails.join();
      expect(details, contains('币种'));
      expect(details, contains('折算金额'));
      expect(details, contains('统计排除'));
    });

    test('本地有、云端无 → deleted', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(ledgerId, syncId: 'tx-ghost');
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: const [],
      );
      expect(preview!.deletedCount, 1);
      expect(preview.changes.single.type, SyncChangeType.deleted);
      expect(preview.changes.single.localTransaction!.syncId, 'tx-ghost');
    });

    test('混合场景 → 排序为 added → modified → deleted', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(ledgerId, syncId: 'tx-mod', amount: Decimal.parse('1'));
      await insertLocalTx(ledgerId, syncId: 'tx-del', amount: Decimal.parse('2'));
      final preview = await service.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: [
          // 新增两条 + 修改一条
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('10'),
            happenedAt: _t(2024, 1, 1),
            syncId: 'tx-add-1',
          ),
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('11'),
            happenedAt: _t(2024, 1, 2),
            syncId: 'tx-add-2',
          ),
          ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('99'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            syncId: 'tx-mod',
          ),
        ],
      );
      expect(preview!.addedCount, 2);
      expect(preview.modifiedCount, 1);
      expect(preview.deletedCount, 1);
      final types = preview.changes.map((c) => c.type).toList();
      expect(types, [
        SyncChangeType.added,
        SyncChangeType.added,
        SyncChangeType.modified,
        SyncChangeType.deleted,
      ]);
    });
  });

  group('applySyncChanges', () {
    test('空变更列表 → 全零结果', () async {
      final ledgerId = await createLedger();
      final result = await service.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: const [],
        importData: const ImportData(),
      );
      expect(result.addedCount, 0);
      expect(result.modifiedCount, 0);
      expect(result.deletedCount, 0);
    });

    test('批量 added → 全部落库，计数正确', () async {
      final ledgerId = await createLedger();
      final changes = [
        SyncChange(
          type: SyncChangeType.added,
          cloudTransaction: ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('10'),
            happenedAt: _t(2024, 1, 1),
            note: 'A',
            syncId: 'tx-a',
          ),
        ),
        SyncChange(
          type: SyncChangeType.added,
          cloudTransaction: ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('20'),
            happenedAt: _t(2024, 1, 2),
            note: 'B',
            syncId: 'tx-b',
          ),
        ),
      ];
      final result = await service.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: changes,
        importData: const ImportData(),
      );
      expect(result.addedCount, 2);
      expect((await repo.getTransactionsByLedger(ledgerId)).length, 2);
    });

    test('modified → 本地行被批量更新', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(ledgerId, amount: Decimal.parse('1'), note: '旧');
      final changes = [
        SyncChange(
          type: SyncChangeType.modified,
          cloudTransaction: ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('88'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            note: '新',
            syncId: 'tx-1',
          ),
          localTransaction: null,
        ),
      ];
      final result = await service.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: changes,
        importData: const ImportData(),
      );
      expect(result.modifiedCount, 1);
      final local = await repo.getTransactionsByLedger(ledgerId);
      expect(local.single.amount, 8800);
      expect(local.single.note, '新');
    });

    test('modified 全字段覆盖：币种/折算/统计/AA 与云端对齐', () async {
      final ledgerId = await createLedger();
      await insertLocalTx(
        ledgerId,
        amount: Decimal.parse('100'),
        currencyCode: 'CNY',
        nativeAmount: 10000,
        paidByUserId: 'u1',
        aaMode: 2,
        aaParticipants: '["u1","u2"]',
        aaSplits: '{"u1":"50.00","u2":"50.00"}',
      );
      final changes = [
        SyncChange(
          type: SyncChangeType.modified,
          cloudTransaction: ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('100'),
            happenedAt: _t(2024, 1, 1, 12, 0, 0),
            syncId: 'tx-1',
            currencyCode: 'USD',
            nativeAmount: Decimal.parse('80'),
            excludeFromStats: true,
            paidByUserId: 'u1',
            aaMode: 2,
            aaParticipants: '["u1","u2"]',
            aaSplits: '{"u1":"50.00","u2":"50.00"}',
          ),
        ),
      ];

      final result = await service.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: changes,
        importData: const ImportData(),
      );
      expect(result.modifiedCount, 1);

      final local = (await repo.getTransactionsByLedger(ledgerId)).single;
      expect(local.currencyCode, 'USD');
      expect(local.nativeAmount, 8000);
      expect(local.excludeFromStats, isTrue);
      expect(local.aaMode, 2);
      expect(local.aaParticipants, '["u1","u2"]');
      expect(local.aaSplits, '{"u1":"50.00","u2":"50.00"}');
    });

    test('deleted（有 syncId）→ 批量删除', () async {
      final ledgerId = await createLedger();
      final tx = await insertLocalTx(ledgerId, syncId: 'tx-del');
      final changes = [
        SyncChange(
          type: SyncChangeType.deleted,
          localTransaction: tx,
        ),
      ];
      final result = await service.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: changes,
        importData: const ImportData(),
      );
      expect(result.deletedCount, 1);
      expect((await repo.getTransactionsByLedger(ledgerId)), isEmpty);
    });

    test('deleted（无 syncId 老数据）→ fallback 单条删除', () async {
      final ledgerId = await createLedger();
      // 无 syncId 的本地老数据
      final tx = await insertLocalTx(ledgerId, syncId: '');
      final changes = [
        SyncChange(
          type: SyncChangeType.deleted,
          localTransaction: tx,
        ),
      ];
      final result = await service.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: changes,
        importData: const ImportData(),
      );
      expect(result.deletedCount, 1);
      expect((await repo.getTransactionsByLedger(ledgerId)), isEmpty);
    });

    test('混合 → added 与 deleted 同时生效', () async {
      final ledgerId = await createLedger();
      final delTx = await insertLocalTx(ledgerId, syncId: 'tx-old');
      final changes = [
        SyncChange(
          type: SyncChangeType.added,
          cloudTransaction: ImportTransaction(
            type: 'expense',
            amount: Decimal.parse('5'),
            happenedAt: _t(2024, 1, 3),
            syncId: 'tx-new',
          ),
        ),
        SyncChange(
          type: SyncChangeType.deleted,
          localTransaction: delTx,
        ),
      ];
      final result = await service.applySyncChanges(
        repo: repo,
        ledgerId: ledgerId,
        selectedChanges: changes,
        importData: const ImportData(),
      );
      expect(result.addedCount, 1);
      expect(result.deletedCount, 1);
      final local = await repo.getTransactionsByLedger(ledgerId);
      expect(local.single.syncId, 'tx-new');
    });
  });
}

DateTime _t(int y, int m, int d, [int h = 12, int min = 0, int s = 0]) =>
    DateTime(y, m, d, h, min, s);
