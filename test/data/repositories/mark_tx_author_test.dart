// markTxAuthor 回填交易作者字段测试。
//
// 覆盖核心契约:
//   1. 新建 + cloud userId 不可用 → paidByUserId 回填 'me' 兜底,
//      createdByUserId / lastEditedByUserId 保持 null(头像非关键路径)
//   2. 新建 + cloud userId 可用 → 三字段统一回填操作者
//   3. 新建 + 编辑器已显式写入 paidBy → paidBy 不被覆盖,作者字段照常回填
//   4. 编辑 + 既有 paidBy 为空 → paidBy 回填操作者(与新建一致)
//   5. 编辑 + 既有 paidBy 非空(用户手改) → paidBy 保留手改值,仅写 lastEditedBy

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'test');
  });

  tearDown(() => db.close());

  /// 插入一条无 paidBy 的交易,模拟本地账本新建后尚未回填作者的状态。
  Future<int> createTx({String? paidByUserId}) async {
    return repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 100.0,
      happenedAt: DateTime(2026, 1, 1),
      paidByUserId: paidByUserId,
    );
  }

  group('markTxAuthor(isCreate=true)', () {
    test('cloud userId 不可用时,paidBy 用 me 兜底,头像字段保持 null', () async {
      final id = await createTx();
      // userId 传空串 + fallbackUserId='me',模拟 cloud 不可用场景。
      await repo.markTxAuthor(
        txId: id,
        userId: '',
        isCreate: true,
        fallbackUserId: 'me',
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      expect(tx!.paidByUserId, 'me');
      expect(tx.createdByUserId, isNull);
      expect(tx.lastEditedByUserId, isNull);
    });

    test('cloud userId 可用时,三字段统一回填操作者', () async {
      final id = await createTx();
      await repo.markTxAuthor(
        txId: id,
        userId: 'u-alice',
        isCreate: true,
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      expect(tx!.paidByUserId, 'u-alice');
      expect(tx.createdByUserId, 'u-alice');
      expect(tx.lastEditedByUserId, 'u-alice');
    });

    test('编辑器已显式写入 paidBy 时,markTxAuthor 不覆盖', () async {
      final id = await createTx(paidByUserId: 'explicit-payer');
      await repo.markTxAuthor(
        txId: id,
        userId: 'u-alice',
        isCreate: true,
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      // paidBy 保留编辑器显式写入的值,不被操作者覆盖。
      expect(tx!.paidByUserId, 'explicit-payer');
      expect(tx.createdByUserId, 'u-alice');
      expect(tx.lastEditedByUserId, 'u-alice');
    });
  });

  group('markTxAuthor(isCreate=false)', () {
    test('既有 paidBy 为空时,回填操作者 + 写 lastEditedBy', () async {
      final id = await createTx();
      // 先模拟首次创建回填。
      await repo.markTxAuthor(
        txId: id,
        userId: 'u-alice',
        isCreate: true,
      );
      // 编辑场景:换操作者。
      await repo.markTxAuthor(
        txId: id,
        userId: 'u-bob',
        isCreate: false,
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      // 创建人 first-write-wins,不被编辑覆盖。
      expect(tx!.createdByUserId, 'u-alice');
      expect(tx.lastEditedByUserId, 'u-bob');
      // 既有 paidBy 已被首次回填为 'u-alice',编辑时非空 → 保留。
      expect(tx.paidByUserId, 'u-alice');
    });

    test('既有 paidBy 为空(本地账本从未回填)时,编辑回填操作者', () async {
      // 极端场景:旧数据从未走 markTxAuthor,paidBy 为 null,直接编辑。
      final id = await createTx();
      await repo.markTxAuthor(
        txId: id,
        userId: 'u-bob',
        isCreate: false,
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      expect(tx!.paidByUserId, 'u-bob');
      expect(tx.lastEditedByUserId, 'u-bob');
      // 编辑场景不写 createdByUserId。
      expect(tx.createdByUserId, isNull);
    });

    test('既有 paidBy 为用户手改值时,编辑不覆盖', () async {
      final id = await createTx(paidByUserId: 'hand-picked');
      await repo.markTxAuthor(
        txId: id,
        userId: 'u-bob',
        isCreate: false,
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      expect(tx!.paidByUserId, 'hand-picked');
      expect(tx.lastEditedByUserId, 'u-bob');
    });

    test('cloud 不可用时,编辑路径 paidBy 为空则用 me 兜底', () async {
      final id = await createTx();
      await repo.markTxAuthor(
        txId: id,
        userId: '',
        isCreate: false,
        fallbackUserId: 'me',
      );
      final tx = await repo.getTransactionById(id);
      expect(tx, isNotNull);
      expect(tx!.paidByUserId, 'me');
      expect(tx.lastEditedByUserId, isNull);
    });
  });
}
