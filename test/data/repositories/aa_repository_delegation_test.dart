// AA 分摊:LocalRepository(聚合层) AA 字段透传 + 虚拟用户 CRUD 测试。
//
// 本测试验证:
//   1. addTransaction: AA 字段(paidByUserId/aaMode/aaParticipants/aaSplits)
//      透传到子仓并落库
//   2. updateTransaction: AA 字段透传(null=不更新,非 null=写入)
//   3. getAaTransactionsByLedger: 按 aaMode 过滤(排除 aaMode=1)
//   4. updateLedger: aaEnabled 透传并写入
//   5. 虚拟用户 CRUD 经 LocalRepository 委托后登记 change log

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    // createLedger 默认 storageMode='cloud',syncId 会被分配,change 会被记录
    ledgerId = await repo.createLedger(name: 'test');
  });

  tearDown(() async {
    await db.close();
  });

  group('addTransaction AA 字段透传', () {
    test('AA 字段全部传入并落库', () async {
      final id = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 10000,
        happenedAt: DateTime.now(),
        paidByUserId: 'user-alice',
        aaMode: 2,
        aaParticipants: '["user-alice","vuser-1"]',
        aaSplits: '{"user-alice":"60.00","vuser-1":"40.00"}',
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      expect(tx!.paidByUserId, 'user-alice');
      expect(tx.aaMode, 2);
      expect(tx.aaParticipants, '["user-alice","vuser-1"]');
      expect(tx.aaSplits, '{"user-alice":"60.00","vuser-1":"40.00"}');
    });

    test('AA 字段不传时落 NULL', () async {
      final id = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 5000,
        happenedAt: DateTime.now(),
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      expect(tx!.paidByUserId, isNull);
      expect(tx.aaMode, isNull);
      expect(tx.aaParticipants, isNull);
      expect(tx.aaSplits, isNull);
    });

    test('AA 交易 create 登记 transaction:create change', () async {
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 3000,
        happenedAt: DateTime.now(),
        paidByUserId: 'user-alice',
        aaMode: 0,
        aaParticipants: '["user-alice"]',
      );
      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final txChanges = changes
          .where((c) => c.entityType == 'transaction' && c.action == 'create')
          .toList();
      expect(txChanges, isNotEmpty);
    });
  });

  group('updateTransaction AA 字段透传', () {
    test('AA 字段更新写入', () async {
      final id = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 10000,
        happenedAt: DateTime.now(),
      );
      await repo.updateTransaction(
        id: id,
        type: 'expense',
        amount: 10000,
        paidByUserId: 'user-bob',
        aaMode: 2,
        aaParticipants: '["user-bob"]',
        aaSplits: '{"user-bob":"100.00"}',
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.paidByUserId, 'user-bob');
      expect(tx.aaMode, 2);
      expect(tx.aaParticipants, '["user-bob"]');
      expect(tx.aaSplits, '{"user-bob":"100.00"}');
    });

    test('AA 字段不传时保持原值(absent)', () async {
      final id = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 10000,
        happenedAt: DateTime.now(),
        paidByUserId: 'user-alice',
        aaMode: 2,
        aaParticipants: '["user-alice"]',
        aaSplits: '{"user-alice":"100.00"}',
      );
      // 只更新金额,不传 AA 字段 → AA 字段保持原值
      await repo.updateTransaction(
        id: id,
        type: 'expense',
        amount: 12000,
      );
      final tx = await repo.getTransactionById(id);
      expect(tx!.amount, 12000);
      expect(tx.paidByUserId, 'user-alice',
          reason: '未传 paidByUserId 时应保持原值');
      expect(tx.aaMode, 2);
      expect(tx.aaParticipants, '["user-alice"]');
      expect(tx.aaSplits, '{"user-alice":"100.00"}');
    });
  });

  group('getAaTransactionsByLedger', () {
    test('排除 aaMode=1(不分摊),包含 null/0/2', () async {
      // 人均(null)
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 3000,
        happenedAt: DateTime.now(),
        // aaMode 不传 → null
      );
      // 不分摊(aaMode=1)
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 2000,
        happenedAt: DateTime.now(),
        aaMode: 1,
      );
      // 指定(aaMode=2)
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 5000,
        happenedAt: DateTime.now(),
        aaMode: 2,
      );
      // 人均(aaMode=0)
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 4000,
        happenedAt: DateTime.now(),
        aaMode: 0,
      );

      final aaTxs = await repo.getAaTransactionsByLedger(ledgerId);
      // 应包含 null/0/2 三笔,排除 aaMode=1 那笔
      expect(aaTxs.length, 3);
      final modes = aaTxs.map((t) => t.aaMode).toSet();
      expect(modes, containsAll([null, 0, 2]));
      expect(modes, isNot(contains(1)));
    });
  });

  group('updateLedger aaEnabled', () {
    test('aaEnabled 写入并跨设备同步登记 change', () async {
      await repo.updateLedger(id: ledgerId, aaEnabled: true);
      final ledger = await repo.getLedgerById(ledgerId);
      expect(ledger!.aaEnabled, true);

      // changeTracker 已登记 ledger:update
      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final ledgerChanges = changes
          .where((c) => c.entityType == 'ledger' && c.action == 'update')
          .toList();
      expect(ledgerChanges, isNotEmpty);
    });

    test('aaEnabled 不传时保持原值', () async {
      // 先设为 true
      await repo.updateLedger(id: ledgerId, aaEnabled: true);
      // 再更新名称,不传 aaEnabled
      await repo.updateLedger(id: ledgerId, name: '新名称');
      final ledger = await repo.getLedgerById(ledgerId);
      expect(ledger!.aaEnabled, true,
          reason: '未传 aaEnabled 时应保持原值');
      expect(ledger.name, '新名称');
    });
  });

  group('虚拟用户 CRUD 经 LocalRepository 委托', () {
    test('create: 新建并登记 virtual_user:create change', () async {
      final id = await repo.create(
        ledgerId: ledgerId,
        name: '室友A',
      );
      expect(id, greaterThan(0));

      // 验证 change log 登记
      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final vuserCreates = changes
          .where((c) => c.entityType == 'virtual_user' && c.action == 'create')
          .toList();
      expect(vuserCreates, isNotEmpty);
      expect(vuserCreates.first.ledgerId, ledgerId);
    });

    test('rename: 更新并登记 virtual_user:update change', () async {
      final id = await repo.create(ledgerId: ledgerId, name: '旧名');
      await repo.rename(id: id, name: '新名');

      final user = await (db.select(db.ledgerVirtualUsers)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(user.name, '新名');

      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final vuserUpdates = changes
          .where((c) => c.entityType == 'virtual_user' && c.action == 'update')
          .toList();
      expect(vuserUpdates, isNotEmpty);
    });

    test('delete: 硬删并登记 virtual_user:delete change', () async {
      final id = await repo.create(ledgerId: ledgerId, name: '待删');
      final deleted = await repo.delete(id);
      expect(deleted, isTrue);

      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final vuserDeletes = changes
          .where((c) => c.entityType == 'virtual_user' && c.action == 'delete')
          .toList();
      expect(vuserDeletes, isNotEmpty);
      expect(vuserDeletes.first.ledgerId, ledgerId);
    });

    test('delete: 名下有账不可删(抛错,不登记 change)', () async {
      final id = await repo.create(
        ledgerId: ledgerId,
        name: '被引用',
        syncId: 'ref-vuser',
      );
      // 插入引用该虚拟用户的交易
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 3000,
        happenedAt: DateTime.now(),
        aaMode: 2,
        aaParticipants: '["ref-vuser"]',
      );

      // 删除应抛错
      expect(
        () => repo.delete(id),
        throwsA(isA<StateError>()),
      );

      // 不应登记 delete change
      final changes = await tracker.getUnpushedChangesForLedger(ledgerId);
      final vuserDeletes = changes
          .where((c) => c.entityType == 'virtual_user' && c.action == 'delete')
          .toList();
      expect(vuserDeletes, isEmpty);
    });
  });
}
