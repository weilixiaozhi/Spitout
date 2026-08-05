// AA 分摊功能 schema v1→v4 迁移端到端测试。
//
// 本测试验证:
//   1. schemaVersion 为 4(v2/v3/v4 迁移已生效)
//   2. Transactions 表新增 4 字段(paid_by_user_id/aa_mode/aa_participants/
//      aa_splits)就位且均 nullable
//   3. Ledgers 表新增 aa_enabled 字段就位,默认 false
//   4. LedgerVirtualUsers 表存在且所有列就位
//   5. v1→v2 迁移:存量交易 paid_by_user_id 从 created_by_user_id 回填
//   6. v2→v3 迁移:空支出人按「创建人 → 编辑人 → 空串」兜底回填
//   7. 迁移幂等:重复触发 onUpgrade 不崩

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/migration_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    // 外键约束要求 transactions/ledger_virtual_users 引用的账本先存在。
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
  });

  tearDown(() async {
    await db.close();
  });

  /// 读指定表的全部列名(PRAGMA table_info)。
  Future<Set<String>> columnNames(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('schemaVersion 为 3(v2/v3 迁移已生效)', () {
    expect(db.schemaVersion, 4);
  });

  test('Transactions 表新增 4 个 AA 字段就位且均 nullable', () async {
    final cols = await columnNames('transactions');
    expect(cols, containsAll([
      'paid_by_user_id',
      'aa_mode',
      'aa_participants',
      'aa_splits',
    ]));
    // 验证 nullable:插入一笔不带 AA 字段的交易应成功
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 1000,
            happenedAt: d.Value(DateTime.now()),
          ),
        );
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(tx.paidByUserId, isNull);
    expect(tx.aaMode, isNull);
    expect(tx.aaParticipants, isNull);
    expect(tx.aaSplits, isNull);
  });

  test('Ledgers 表新增 aa_enabled 字段就位且默认 false', () async {
    final cols = await columnNames('ledgers');
    expect(cols, contains('aa_enabled'));
    // 验证默认值:false
    final id = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'test'),
        );
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(id)))
        .getSingle();
    expect(ledger.aaEnabled, false);
  });

  test('LedgerVirtualUsers 表存在且所有列就位', () async {
    final cols = await columnNames('ledger_virtual_users');
    expect(cols, containsAll([
      'id',
      'ledger_id',
      'sync_id',
      'name',
      'created_at',
      'updated_at',
    ]));
  });

  test('LedgerVirtualUsers 表 CRUD 正常', () async {
    // 插入
    final id = await db.into(db.ledgerVirtualUsers).insert(
          LedgerVirtualUsersCompanion.insert(
            ledgerId: 1,
            syncId: const d.Value('virtual-user-uuid-1'),
            name: '室友A',
          ),
        );
    // 查询
    final user = await (db.select(db.ledgerVirtualUsers)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(user.name, '室友A');
    expect(user.syncId, 'virtual-user-uuid-1');
    expect(user.ledgerId, 1);
    expect(user.createdAt, isNotNull);
    expect(user.updatedAt, isNull);

    // 更新
    await (db.update(db.ledgerVirtualUsers)..where((t) => t.id.equals(id)))
        .write(LedgerVirtualUsersCompanion(
      name: const d.Value('室友B'),
      updatedAt: d.Value(DateTime.now()),
    ));
    final updated = await (db.select(db.ledgerVirtualUsers)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(updated.name, '室友B');
    expect(updated.updatedAt, isNotNull);

    // 删除
    final n = await (db.delete(db.ledgerVirtualUsers)
          ..where((t) => t.id.equals(id)))
        .go();
    expect(n, 1);
  });

  test('v1→v2 迁移:存量交易 paid_by_user_id 从 created_by_user_id 回填',
      () async {
    // 模拟 v1 交易:created_by_user_id 有值,paid_by_user_id 为 NULL
    // 先插入一笔带 created_by_user_id 的交易(新 schema 下 paid_by_user_id 可空)
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 5000,
            happenedAt: d.Value(DateTime.now()),
            createdByUserId: const d.Value('user-alice'),
            // 不传 paidByUserId → 列存 NULL
          ),
        );
    // 手动触发 v2 迁移的回填语句(模拟 onUpgrade 第二步)
    await db.customStatement(
      'UPDATE transactions SET paid_by_user_id = '
      "COALESCE(created_by_user_id, '') "
      'WHERE paid_by_user_id IS NULL;',
    );
    // 验证回填
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(tx.paidByUserId, 'user-alice',
        reason: 'paid_by_user_id 应从 created_by_user_id 回填');
  });

  test('v1→v2 迁移回填幂等:重复执行不改变已有值', () async {
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 5000,
            happenedAt: d.Value(DateTime.now()),
            createdByUserId: const d.Value('user-bob'),
          ),
        );
    // 第一次回填
    await db.customStatement(
      'UPDATE transactions SET paid_by_user_id = '
      "COALESCE(created_by_user_id, '') "
      'WHERE paid_by_user_id IS NULL;',
    );
    // 第二次回填(WHERE 守卫:paid_by_user_id IS NULL 已不满足,不执行)
    await db.customStatement(
      'UPDATE transactions SET paid_by_user_id = '
      "COALESCE(created_by_user_id, '') "
      'WHERE paid_by_user_id IS NULL;',
    );
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(tx.paidByUserId, 'user-bob',
        reason: '幂等回填不应改变已有值');
  });

  test('v2→v3 迁移:空支出人回填创建人,优先于编辑人', () async {
    // 模拟 v2 存量:paid_by_user_id 为空串(或 NULL),created/lastEdited 有值
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 5000,
            happenedAt: d.Value(DateTime.now()),
            createdByUserId: const d.Value('user-alice'),
            lastEditedByUserId: const d.Value('user-bob'),
            paidByUserId: const d.Value(''),
          ),
        );
    // 手动触发 v3 迁移的回填语句(模拟 onUpgrade 第三步)
    await db.customStatement(
      'UPDATE transactions SET paid_by_user_id = '
      "COALESCE(NULLIF(paid_by_user_id, ''), "
      "created_by_user_id, last_edited_by_user_id, '') "
      "WHERE paid_by_user_id IS NULL OR paid_by_user_id = '';",
    );
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(tx.paidByUserId, 'user-alice',
        reason: '空支出人应按「默认支出人 = 创建人」回填为创建人');
  });

  test('v2→v3 迁移:创建人缺失时回填编辑人', () async {
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 5000,
            happenedAt: d.Value(DateTime.now()),
            // 不传 createdByUserId → NULL
            lastEditedByUserId: const d.Value('user-bob'),
            paidByUserId: const d.Value(''),
          ),
        );
    await db.customStatement(
      'UPDATE transactions SET paid_by_user_id = '
      "COALESCE(NULLIF(paid_by_user_id, ''), "
      "created_by_user_id, last_edited_by_user_id, '') "
      "WHERE paid_by_user_id IS NULL OR paid_by_user_id = '';",
    );
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(tx.paidByUserId, 'user-bob',
        reason: '创建人缺失时应退编辑人');
  });

  test('v2→v3 迁移:创建人/编辑人双缺失落空串(不伪造身份)', () async {
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 5000,
            happenedAt: d.Value(DateTime.now()),
            paidByUserId: const d.Value(''),
          ),
        );
    await db.customStatement(
      'UPDATE transactions SET paid_by_user_id = '
      "COALESCE(NULLIF(paid_by_user_id, ''), "
      "created_by_user_id, last_edited_by_user_id, '') "
      "WHERE paid_by_user_id IS NULL OR paid_by_user_id = '';",
    );
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(tx.paidByUserId, '',
        reason: '创建人/编辑人均缺失时落空串,展示层降级"未知"而非伪造身份');
  });

  test('v2→v3 迁移回填幂等:已回填的非空值不被重写', () async {
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 5000,
            happenedAt: d.Value(DateTime.now()),
            createdByUserId: const d.Value('user-alice'),
            // 手选过支出人,与创建人不同 → 非空值
            paidByUserId: const d.Value('user-carol'),
          ),
        );
    // 连续执行两次 v3 回填(WHERE 守卫:非空值不满足条件,不执行)
    for (var i = 0; i < 2; i++) {
      await db.customStatement(
        'UPDATE transactions SET paid_by_user_id = '
        "COALESCE(NULLIF(paid_by_user_id, ''), "
        "created_by_user_id, last_edited_by_user_id, '') "
        "WHERE paid_by_user_id IS NULL OR paid_by_user_id = '';",
      );
    }
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(tx.paidByUserId, 'user-carol',
        reason: '幂等回填不得覆盖手选的非空支出人');
  });

  test('迁移幂等:addColumnIfMissing 重复调用不崩', () async {
    // 模拟迁移中断重跑:对新库再次执行 v2 迁移的 DDL,不应抛错
    await db.addColumnIfMissing(
      'transactions',
      'paid_by_user_id',
      'ALTER TABLE transactions ADD COLUMN paid_by_user_id TEXT;',
    );
    await db.addColumnIfMissing(
      'ledgers',
      'aa_enabled',
      'ALTER TABLE ledgers ADD COLUMN aa_enabled INTEGER NOT NULL DEFAULT 0;',
    );
    // 列仍存在,不重复
    final txCols = await columnNames('transactions');
    expect(txCols.where((c) => c == 'paid_by_user_id').length, 1);
    final ledgerCols = await columnNames('ledgers');
    expect(ledgerCols.where((c) => c == 'aa_enabled').length, 1);
  });
}
