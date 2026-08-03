// AA 分摊:虚拟用户 Repository CRUD + 删除约束测试。
//
// 本测试验证 [LocalLedgerVirtualUserRepository] 的:
//   1. CRUD 基本操作(create/getByLedger/getBySyncId/rename/delete)
//   2. watchByLedger stream 正常
//   3. 删除约束:被交易的 aaParticipants 引用时不允许删除(R7 硬约束)
//   4. 未被引用时正常硬删

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_ledger_virtual_user_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalLedgerVirtualUserRepository repo;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalLedgerVirtualUserRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CRUD', () {
    test('create: 新建虚拟用户,自动填 syncId', () async {
      final id = await repo.create(
        ledgerId: 1,
        name: '室友A',
      );
      final user = await (db.select(db.ledgerVirtualUsers)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(user.name, '室友A');
      expect(user.ledgerId, 1);
      expect(user.syncId, isNotNull);
      expect(user.createdAt, isNotNull);
      expect(user.updatedAt, isNull);
    });

    test('create: 显式传 syncId 时用传入值', () async {
      final id = await repo.create(
        ledgerId: 1,
        name: '室友B',
        syncId: 'custom-uuid-123',
      );
      final user = await (db.select(db.ledgerVirtualUsers)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(user.syncId, 'custom-uuid-123');
    });

    test('getByLedger: 只返回指定账本的虚拟用户', () async {
      await repo.create(ledgerId: 1, name: '用户1');
      await repo.create(ledgerId: 1, name: '用户2');
      await repo.create(ledgerId: 2, name: '用户3');

      final ledger1Users = await repo.getByLedger(1);
      final ledger2Users = await repo.getByLedger(2);

      expect(ledger1Users.length, 2);
      expect(ledger2Users.length, 1);
      expect(ledger2Users.first.name, '用户3');
    });

    test('getBySyncId: 按 syncId 精确匹配', () async {
      await repo.create(ledgerId: 1, name: '用户', syncId: 'sync-abc');
      final user = await repo.getBySyncId('sync-abc');
      expect(user, isNotNull);
      expect(user!.name, '用户');

      final notFound = await repo.getBySyncId('non-existent');
      expect(notFound, isNull);
    });

    test('rename: 更新名称并写入 updatedAt', () async {
      final id = await repo.create(ledgerId: 1, name: '旧名');
      await repo.rename(id: id, name: '新名');
      final user = await (db.select(db.ledgerVirtualUsers)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(user.name, '新名');
      expect(user.updatedAt, isNotNull);
    });

    test('delete: 未被引用时正常硬删', () async {
      final id = await repo.create(ledgerId: 1, name: '待删');
      final deleted = await repo.delete(id);
      expect(deleted, isTrue);
      final remaining = await repo.getByLedger(1);
      expect(remaining, isEmpty);
    });

    test('delete: 不存在的 id 返回 false', () async {
      final deleted = await repo.delete(9999);
      expect(deleted, isFalse);
    });
  });

  group('watchByLedger', () {
    test('监听指定账本的虚拟用户列表,数据变化时自动 emit', () async {
      final stream = repo.watchByLedger(1);
      final emitted = <List<LedgerVirtualUser>>[];
      final sub = stream.listen(emitted.add);

      // 等待初始 emit
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emitted, isNotEmpty);
      expect(emitted.last, isEmpty);

      // 插入一条
      await repo.create(ledgerId: 1, name: '用户1');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emitted.last.length, 1);
      expect(emitted.last.first.name, '用户1');

      // 插入第二条
      await repo.create(ledgerId: 1, name: '用户2');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emitted.last.length, 2);

      // 删除一条
      await repo.delete(emitted.last.first.id);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emitted.last.length, 1);

      await sub.cancel();
    });

    test('只监听指定账本,其他账本变化不触发', () async {
      await repo.create(ledgerId: 2, name: '其他账本用户');

      final stream = repo.watchByLedger(1);
      final emitted = <List<LedgerVirtualUser>>[];
      final sub = stream.listen(emitted.add);

      await Future.delayed(const Duration(milliseconds: 50));
      // 账本 1 没有用户
      expect(emitted.last, isEmpty);

      // 在账本 2 插入,不应触发账本 1 的 stream
      await repo.create(ledgerId: 2, name: '又一个');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emitted.last, isEmpty);

      await sub.cancel();
    });
  });

  group('删除约束 R7: 名下有账不可删', () {
    test('被交易的 aaParticipants 引用时抛 StateError', () async {
      final vUserId = await repo.create(
        ledgerId: 1,
        name: '被引用用户',
        syncId: 'ref-sync-id',
      );
      // 插入一笔交易,aaParticipants 包含该虚拟用户 syncId
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: 1,
              type: 'expense',
              amount: 30.0,
              happenedAt: d.Value(DateTime.now()),
              aaParticipants:
                  const d.Value('["user-alice","ref-sync-id"]'),
              aaMode: const d.Value(2),
            ),
          );

      // 校验引用检测
      final referenced = await repo.isReferencedByAnyTransaction(vUserId);
      expect(referenced, isTrue,
          reason: '被 aaParticipants 引用时应返回 true');

      // 尝试删除应抛错
      expect(
        () => repo.delete(vUserId),
        throwsA(isA<StateError>()),
        reason: '名下有账不可删(R7 硬约束)',
      );

      // 验证行仍在
      final stillExists = await (db.select(db.ledgerVirtualUsers)
            ..where((t) => t.id.equals(vUserId)))
          .getSingleOrNull();
      expect(stillExists, isNotNull);
    });

    test('未被引用时正常删除', () async {
      final vUserId = await repo.create(
        ledgerId: 1,
        name: '未引用用户',
        syncId: 'unref-sync-id',
      );
      // 插入一笔不含该虚拟用户 syncId 的交易
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: 1,
              type: 'expense',
              amount: 20.0,
              happenedAt: d.Value(DateTime.now()),
              aaParticipants: const d.Value('["user-alice"]'),
              aaMode: const d.Value(2),
            ),
          );

      final referenced = await repo.isReferencedByAnyTransaction(vUserId);
      expect(referenced, isFalse);

      final deleted = await repo.delete(vUserId);
      expect(deleted, isTrue);
    });

    test('syncId 为 null 的虚拟用户不算被引用', () async {
      // 直接插入一个 syncId 为 null 的虚拟用户(异常数据)
      final id = await db.into(db.ledgerVirtualUsers).insert(
            LedgerVirtualUsersCompanion.insert(
              ledgerId: 1,
              name: '无 syncId 用户',
              // syncId 不传 → 列存 NULL
            ),
          );
      final referenced = await repo.isReferencedByAnyTransaction(id);
      expect(referenced, isFalse,
          reason: 'syncId 为 null 的虚拟用户不会被交易引用');
    });
  });
}
