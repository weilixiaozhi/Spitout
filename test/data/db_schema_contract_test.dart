// 数据库 schema 契约测试。
//
// 锚点：当前 drift 官方工具生成的 schema 快照
// 与同步/导出/迁移层共同依赖的列名约定。锁定的内容：
//   1. 每张表的**运行时 schema**（生成的 $columns）暴露的列名必须与 schema
//      快照一致——同步 payload、CSV/YAML 导出、存量迁移都依赖这些列名，
//      改名即破坏跨层契约；
//   2. 数据库层面的硬约束（CHECK / 外键 / 复合主键）行为按需求文档断言，
//      防止“约束写进 schema 却没生效”；
//   3. 基类 DSL 列 getter（db.dart 中的表定义）是生成期专用代码：运行时
//      调用必须抛 UnsupportedError 而非静默返回错误列——若生成的 $Table
//      因未重新 build 而失效，应用必须立刻崩在调用点而不是带病运行。
library;

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';

import '../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    // 触发惰性连接，先建好全部表再跑断言。
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async {
    await db.close();
  });

  group('运行时 schema 列名与当前快照一致', () {
    // 无自增 id 的表 drift 会附加 rowid 伪列，断言时剔除。
    List<String> columnNames(d.TableInfo table) =>
        table.$columns.map((c) => c.name).where((n) => n != 'rowid').toList();

    test('ledgers', () {
      expect(
        columnNames(db.ledgers),
        [
          'id', 'name', 'currency', 'type', 'created_at', 'sync_id',
          'my_role', 'member_count', 'is_shared', 'owner_user_id',
          'month_start_day', 'storage_mode', 'aa_enabled',
        ],
      );
    });

    test('exchange_rates（复合主键表）', () {
      expect(
        columnNames(db.exchangeRates),
        ['base_currency', 'quote_currency', 'rate_date', 'rate', 'source',
         'fetched_at'],
      );
    });

    test('exchange_rate_overrides', () {
      expect(
        columnNames(db.exchangeRateOverrides),
        ['id', 'sync_id', 'base_currency', 'quote_currency', 'rate',
         'updated_at'],
      );
    });

    test('categories', () {
      expect(
        columnNames(db.categories),
        ['id', 'name', 'kind', 'icon', 'sort_order', 'parent_id', 'level',
         'sync_id'],
      );
    });

    test('transactions（含 AA / 多币种 / 编辑版本字段）', () {
      expect(
        columnNames(db.transactions),
        [
          'id', 'ledger_id', 'type', 'amount', 'category_id', 'happened_at',
          'note', 'recurring_id', 'sync_id', 'created_by_user_id',
          'last_edited_by_user_id', 'category_sync_id_override',
          'exclude_from_stats', 'currency_code', 'native_amount', 'version',
          'last_edited_at', 'paid_by_user_id', 'aa_mode', 'aa_participants',
          'aa_splits',
        ],
      );
    });

    test('record_edit_histories', () {
      expect(
        columnNames(db.recordEditHistories),
        ['id', 'record_id', 'version', 'operator_user_id', 'summary',
         'created_at'],
      );
    });

    test('recurring_transactions', () {
      expect(
        columnNames(db.recurringTransactions),
        [
          'id', 'ledger_id', 'type', 'amount', 'currency_code',
          'category_id', 'note',
          'frequency', 'interval', 'day_of_month', 'day_of_week',
          'month_of_year', 'start_date', 'end_date', 'last_generated_date',
          'enabled', 'created_at', 'updated_at',
        ],
      );
    });

    test('local_changes', () {
      expect(
        columnNames(db.localChanges),
        ['id', 'entity_type', 'entity_id', 'entity_sync_id', 'ledger_id',
         'action', 'payload_json', 'created_at', 'pushed_at'],
      );
    });

    test('sync_state', () {
      expect(
        columnNames(db.syncState),
        ['id', 'device_id', 'provider_type', 'server_cursor', 'last_push_at',
         'last_pull_at'],
      );
    });

    test('sync_pull_errors', () {
      expect(
        columnNames(db.syncPullErrors),
        [
          'id', 'change_id', 'ledger_external_id', 'entity_type',
          'entity_sync_id', 'action', 'raw_change_json', 'error_class',
          'error_message', 'stack_trace', 'first_seen_at', 'last_attempt_at',
          'attempt_count', 'user_action', 'resolved_at',
        ],
      );
    });

    test('snapshot_dirty_ledgers（复合主键表）', () {
      expect(
        columnNames(db.snapshotDirtyLedgers),
        ['ledger_id', 'dirty_at'],
      );
    });

    test('ledger_members（复合主键表，account 为 v5 改名后列名）', () {
      expect(
        columnNames(db.ledgerMembers),
        ['ledger_sync_id', 'user_id', 'account', 'display_name', 'avatar_url',
         'role', 'joined_at', 'updated_at'],
      );
    });

    test('shared_ledger_categories（复合主键表）', () {
      expect(
        columnNames(db.sharedLedgerCategories),
        [
          'ledger_sync_id', 'sync_id', 'name', 'kind', 'icon', 'color',
          'sort_order', 'level', 'parent_name', 'parent_sync_id', 'updated_at',
        ],
      );
    });

    test('ledger_virtual_users', () {
      expect(
        columnNames(db.ledgerVirtualUsers),
        ['id', 'ledger_id', 'sync_id', 'name', 'created_at', 'updated_at'],
      );
    });
  });

  group('关键列默认值与必填性', () {
    test('ledgers 默认本位币 CNY / 归属 local / 月首日 1', () {
      final cols = {for (final c in db.ledgers.$columns) c.name: c};
      expect(cols['currency']!.defaultValue, const d.Constant('CNY'));
      expect(cols['storage_mode']!.defaultValue, const d.Constant('local'));
      expect(cols['month_start_day']!.defaultValue, const d.Constant(1));
    });

    test('transactions 编辑版本默认 1、排除统计默认 false', () {
      final cols = {
        for (final c in db.transactions.$columns) c.name: c,
      };
      expect(cols['version']!.defaultValue, const d.Constant(1));
      expect(
        cols['exclude_from_stats']!.defaultValue,
        const d.Constant(false),
      );
    });

    test('local_changes 与 sync_state 必填列符合同步契约', () {
      final changeCols = {
        for (final c in db.localChanges.$columns) c.name: c,
      };
      for (final name in [
        'entity_type', 'entity_id', 'entity_sync_id', 'ledger_id', 'action',
      ]) {
        expect(changeCols[name]!.requiredDuringInsert, isTrue,
            reason: 'local_changes.$name 必须随插入写入');
      }
      final stateCols = {
        for (final c in db.syncState.$columns) c.name: c,
      };
      expect(stateCols['device_id']!.requiredDuringInsert, isTrue);
    });
  });

  group('基类 DSL getter 仅限生成期使用', () {
    // drift 的基类列 getter 依赖生成器解析 AST，运行时被 $Table 覆写。
    // 这里断言“调用即抛 UnsupportedError”：生成的代码失效时必须在调用点
    // 立刻失败，而不是静默产生错误列定义。
    test('ledgers 全部列 getter', () {
      final t = Ledgers();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.name, throwsUnsupportedError);
      expect(() => t.currency, throwsUnsupportedError);
      expect(() => t.type, throwsUnsupportedError);
      expect(() => t.createdAt, throwsUnsupportedError);
      expect(() => t.syncId, throwsUnsupportedError);
      expect(() => t.myRole, throwsUnsupportedError);
      expect(() => t.memberCount, throwsUnsupportedError);
      expect(() => t.isShared, throwsUnsupportedError);
      expect(() => t.ownerUserId, throwsUnsupportedError);
      expect(() => t.monthStartDay, throwsUnsupportedError);
      expect(() => t.storageMode, throwsUnsupportedError);
      expect(() => t.aaEnabled, throwsUnsupportedError);
    });

    test('exchange_rates 全部列 getter（含 primaryKey 引用）', () {
      final t = ExchangeRates();
      expect(() => t.baseCurrency, throwsUnsupportedError);
      expect(() => t.quoteCurrency, throwsUnsupportedError);
      expect(() => t.rateDate, throwsUnsupportedError);
      expect(() => t.rate, throwsUnsupportedError);
      expect(() => t.source, throwsUnsupportedError);
      expect(() => t.fetchedAt, throwsUnsupportedError);
      expect(() => t.primaryKey, throwsUnsupportedError);
    });

    test('exchange_rate_overrides 全部列 getter', () {
      final t = ExchangeRateOverrides();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.syncId, throwsUnsupportedError);
      expect(() => t.baseCurrency, throwsUnsupportedError);
      expect(() => t.quoteCurrency, throwsUnsupportedError);
      expect(() => t.rate, throwsUnsupportedError);
      expect(() => t.updatedAt, throwsUnsupportedError);
    });

    test('categories 全部列 getter', () {
      final t = Categories();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.name, throwsUnsupportedError);
      expect(() => t.kind, throwsUnsupportedError);
      expect(() => t.icon, throwsUnsupportedError);
      expect(() => t.sortOrder, throwsUnsupportedError);
      expect(() => t.parentId, throwsUnsupportedError);
      expect(() => t.level, throwsUnsupportedError);
      expect(() => t.syncId, throwsUnsupportedError);
    });

    test('transactions 全部列 getter', () {
      final t = Transactions();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.ledgerId, throwsUnsupportedError);
      expect(() => t.type, throwsUnsupportedError);
      expect(() => t.amount, throwsUnsupportedError);
      expect(() => t.categoryId, throwsUnsupportedError);
      expect(() => t.happenedAt, throwsUnsupportedError);
      expect(() => t.note, throwsUnsupportedError);
      expect(() => t.recurringId, throwsUnsupportedError);
      expect(() => t.syncId, throwsUnsupportedError);
      expect(() => t.createdByUserId, throwsUnsupportedError);
      expect(() => t.lastEditedByUserId, throwsUnsupportedError);
      expect(() => t.categorySyncIdOverride, throwsUnsupportedError);
      expect(() => t.excludeFromStats, throwsUnsupportedError);
      expect(() => t.currencyCode, throwsUnsupportedError);
      expect(() => t.nativeAmount, throwsUnsupportedError);
      expect(() => t.version, throwsUnsupportedError);
      expect(() => t.lastEditedAt, throwsUnsupportedError);
      expect(() => t.paidByUserId, throwsUnsupportedError);
      expect(() => t.aaMode, throwsUnsupportedError);
      expect(() => t.aaParticipants, throwsUnsupportedError);
      expect(() => t.aaSplits, throwsUnsupportedError);
    });

    test('record_edit_histories 全部列 getter', () {
      final t = RecordEditHistories();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.recordId, throwsUnsupportedError);
      expect(() => t.version, throwsUnsupportedError);
      expect(() => t.operatorUserId, throwsUnsupportedError);
      expect(() => t.summary, throwsUnsupportedError);
      expect(() => t.createdAt, throwsUnsupportedError);
    });

    test('recurring_transactions 全部列 getter', () {
      final t = RecurringTransactions();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.ledgerId, throwsUnsupportedError);
      expect(() => t.type, throwsUnsupportedError);
      expect(() => t.amount, throwsUnsupportedError);
      expect(() => t.categoryId, throwsUnsupportedError);
      expect(() => t.note, throwsUnsupportedError);
      expect(() => t.frequency, throwsUnsupportedError);
      expect(() => t.interval, throwsUnsupportedError);
      expect(() => t.dayOfMonth, throwsUnsupportedError);
      expect(() => t.dayOfWeek, throwsUnsupportedError);
      expect(() => t.monthOfYear, throwsUnsupportedError);
      expect(() => t.startDate, throwsUnsupportedError);
      expect(() => t.endDate, throwsUnsupportedError);
      expect(() => t.lastGeneratedDate, throwsUnsupportedError);
      expect(() => t.enabled, throwsUnsupportedError);
      expect(() => t.createdAt, throwsUnsupportedError);
      expect(() => t.updatedAt, throwsUnsupportedError);
    });

    test('local_changes 全部列 getter', () {
      final t = LocalChanges();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.entityType, throwsUnsupportedError);
      expect(() => t.entityId, throwsUnsupportedError);
      expect(() => t.entitySyncId, throwsUnsupportedError);
      expect(() => t.ledgerId, throwsUnsupportedError);
      expect(() => t.action, throwsUnsupportedError);
      expect(() => t.payloadJson, throwsUnsupportedError);
      expect(() => t.createdAt, throwsUnsupportedError);
      expect(() => t.pushedAt, throwsUnsupportedError);
    });

    test('sync_state 全部列 getter', () {
      final t = SyncState();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.deviceId, throwsUnsupportedError);
      expect(() => t.providerType, throwsUnsupportedError);
      expect(() => t.serverCursor, throwsUnsupportedError);
      expect(() => t.lastPushAt, throwsUnsupportedError);
      expect(() => t.lastPullAt, throwsUnsupportedError);
    });

    test('sync_pull_errors 全部列 getter', () {
      final t = SyncPullErrors();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.changeId, throwsUnsupportedError);
      expect(() => t.ledgerExternalId, throwsUnsupportedError);
      expect(() => t.entityType, throwsUnsupportedError);
      expect(() => t.entitySyncId, throwsUnsupportedError);
      expect(() => t.action, throwsUnsupportedError);
      expect(() => t.rawChangeJson, throwsUnsupportedError);
      expect(() => t.errorClass, throwsUnsupportedError);
      expect(() => t.errorMessage, throwsUnsupportedError);
      expect(() => t.stackTrace, throwsUnsupportedError);
      expect(() => t.firstSeenAt, throwsUnsupportedError);
      expect(() => t.lastAttemptAt, throwsUnsupportedError);
      expect(() => t.attemptCount, throwsUnsupportedError);
      expect(() => t.userAction, throwsUnsupportedError);
      expect(() => t.resolvedAt, throwsUnsupportedError);
    });

    test('snapshot_dirty_ledgers 全部列 getter（含 primaryKey 引用）', () {
      final t = SnapshotDirtyLedgers();
      expect(() => t.ledgerId, throwsUnsupportedError);
      expect(() => t.dirtyAt, throwsUnsupportedError);
      expect(() => t.primaryKey, throwsUnsupportedError);
    });

    test('ledger_members 全部列 getter（含 primaryKey 引用）', () {
      final t = LedgerMembers();
      expect(() => t.ledgerSyncId, throwsUnsupportedError);
      expect(() => t.userId, throwsUnsupportedError);
      expect(() => t.account, throwsUnsupportedError);
      expect(() => t.displayName, throwsUnsupportedError);
      expect(() => t.avatarUrl, throwsUnsupportedError);
      expect(() => t.role, throwsUnsupportedError);
      expect(() => t.joinedAt, throwsUnsupportedError);
      expect(() => t.updatedAt, throwsUnsupportedError);
      expect(() => t.primaryKey, throwsUnsupportedError);
    });

    test('shared_ledger_categories 全部列 getter（含 primaryKey 引用）', () {
      final t = SharedLedgerCategories();
      expect(() => t.ledgerSyncId, throwsUnsupportedError);
      expect(() => t.syncId, throwsUnsupportedError);
      expect(() => t.name, throwsUnsupportedError);
      expect(() => t.kind, throwsUnsupportedError);
      expect(() => t.icon, throwsUnsupportedError);
      expect(() => t.color, throwsUnsupportedError);
      expect(() => t.sortOrder, throwsUnsupportedError);
      expect(() => t.level, throwsUnsupportedError);
      expect(() => t.parentName, throwsUnsupportedError);
      expect(() => t.parentSyncId, throwsUnsupportedError);
      expect(() => t.updatedAt, throwsUnsupportedError);
      expect(() => t.primaryKey, throwsUnsupportedError);
    });

    test('ledger_virtual_users 全部列 getter', () {
      final t = LedgerVirtualUsers();
      expect(() => t.id, throwsUnsupportedError);
      expect(() => t.ledgerId, throwsUnsupportedError);
      expect(() => t.syncId, throwsUnsupportedError);
      expect(() => t.name, throwsUnsupportedError);
      expect(() => t.createdAt, throwsUnsupportedError);
      expect(() => t.updatedAt, throwsUnsupportedError);
    });
  });

  group('CHECK 约束在数据库层兜底', () {
    test('month_start_day 越界(0/29)直接拒绝', () async {
      expect(
        () => db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'bad', monthStartDay: d.Value(0)),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'bad', monthStartDay: d.Value(29)),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('categories.level 只允许 1/2', () async {
      expect(
        () => db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: 'bad',
            kind: 'expense',
            level: d.Value(3),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('transactions.aa_mode 只允许 null/0/1/2', () async {
      final ledgerId = await db
          .into(db.ledgers)
          .insert(LedgersCompanion.insert(name: 'aa'));
      expect(
        () => db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 100,
            aaMode: d.Value(9),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('currency_code 与 native_amount 必须成对出现', () async {
      final ledgerId = await db
          .into(db.ledgers)
          .insert(LedgersCompanion.insert(name: 'fx'));
      // 有币种无快照 → 拒绝
      expect(
        () => db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 100,
            currencyCode: d.Value('USD'),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
      // 有快照无币种 → 拒绝
      expect(
        () => db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 100,
            nativeAmount: d.Value(100),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('外键行为', () {
    test('删除账本级联删除交易', () async {
      final ledgerId = await db
          .into(db.ledgers)
          .insert(LedgersCompanion.insert(name: 'cascade'));
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 100,
            ),
          );

      await (db.delete(db.ledgers)..where((l) => l.id.equals(ledgerId))).go();

      final left = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .get();
      expect(left, isEmpty);
    });

    test('删除分类置空交易 category_id（弱引用不误删历史账目）', () async {
      final ledgerId = await db
          .into(db.ledgers)
          .insert(LedgersCompanion.insert(name: 'cat-fk'));
      final catId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(name: '餐饮', kind: 'expense'),
          );
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 100,
              categoryId: d.Value(catId),
            ),
          );

      await (db.delete(db.categories)..where((c) => c.id.equals(catId))).go();

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txId)))
          .getSingle();
      expect(tx.categoryId, isNull);
    });

    test('删除交易级联删除编辑历史', () async {
      final ledgerId = await db
          .into(db.ledgers)
          .insert(LedgersCompanion.insert(name: 'history-fk'));
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 100,
            ),
          );
      await db.into(db.recordEditHistories).insert(
            RecordEditHistoriesCompanion.insert(
              recordId: txId,
              version: 2,
              summary: '改金额',
            ),
          );

      await (db.delete(db.transactions)..where((t) => t.id.equals(txId))).go();

      final left = await (db.select(db.recordEditHistories)
            ..where((h) => h.recordId.equals(txId)))
          .get();
      expect(left, isEmpty);
    });
  });

  group('复合主键 / 唯一约束', () {
    test('exchange_rates 同 (base,quote,date) 重复插入被拒绝', () async {
      final row = ExchangeRatesCompanion.insert(
        baseCurrency: 'CNY',
        quoteCurrency: 'USD',
        rateDate: '2026-08-08',
        rate: '7.2',
        source: 'server',
        fetchedAt: DateTime(2026, 8, 8),
      );
      await db.into(db.exchangeRates).insert(row);
      expect(
        () => db.into(db.exchangeRates).insert(row),
        throwsA(isA<SqliteException>()),
      );
    });

    test('snapshot_dirty_ledgers 同账本只保留一行（INSERT OR IGNORE 语义）', () async {
      await db.into(db.snapshotDirtyLedgers).insert(
            SnapshotDirtyLedgersCompanion(
              ledgerId: d.Value(1),
              dirtyAt: d.Value(DateTime(2026, 8, 8, 10)),
            ),
          );
      // 重复标记沿用首次 dirtyAt（保留最早“脏了多久”信号）
      await db.into(db.snapshotDirtyLedgers).insert(
            SnapshotDirtyLedgersCompanion(
              ledgerId: d.Value(1),
              dirtyAt: d.Value(DateTime(2026, 8, 8, 12)),
            ),
            mode: d.InsertMode.insertOrIgnore,
          );
      final rows = await db.select(db.snapshotDirtyLedgers).get();
      expect(rows.length, 1);
      expect(rows.single.dirtyAt, DateTime(2026, 8, 8, 10));
    });

    test('ledger_members 同 (ledgerSyncId,userId) 重复插入被拒绝', () async {
      final row = LedgerMembersCompanion.insert(
        ledgerSyncId: 'l1',
        userId: 'u1',
        role: 'owner',
        joinedAt: DateTime(2026, 8, 8),
        updatedAt: DateTime(2026, 8, 8),
      );
      await db.into(db.ledgerMembers).insert(row);
      expect(
        () => db.into(db.ledgerMembers).insert(row),
        throwsA(isA<SqliteException>()),
      );
    });

    test('shared_ledger_categories 同 (ledgerSyncId,syncId) 重复插入被拒绝', () async {
      final row = SharedLedgerCategoriesCompanion.insert(
        ledgerSyncId: 'l1',
        syncId: 'cat1',
        name: '餐饮',
        kind: 'expense',
        updatedAt: DateTime(2026, 8, 8),
      );
      await db.into(db.sharedLedgerCategories).insert(row);
      expect(
        () => db.into(db.sharedLedgerCategories).insert(row),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('低频表读写通路（生成查询方法）', () {
    test('sync_state / local_changes / sync_pull_errors 插入与回读', () async {
      await db.into(db.syncState).insert(
            SyncStateCompanion.insert(
              deviceId: 'dev-1',
              serverCursor: d.Value(42),
            ),
          );
      final syncState = await db.select(db.syncState).getSingle();
      expect(syncState.serverCursor, 42);
      expect(syncState.providerType, 'spitout_cloud');

      await db.into(db.localChanges).insert(
            LocalChangesCompanion.insert(
              entityType: 'transaction',
              entityId: 1,
              entitySyncId: 'tx-1',
              ledgerId: 1,
              action: 'create',
            ),
          );
      final change = await db.select(db.localChanges).getSingle();
      expect(change.action, 'create');
      expect(change.pushedAt, isNull);

      final now = DateTime(2026, 8, 8);
      await db.into(db.syncPullErrors).insert(
            SyncPullErrorsCompanion.insert(
              changeId: 7,
              entityType: 'transaction',
              entitySyncId: 'tx-1',
              action: 'upsert',
              rawChangeJson: '{}',
              firstSeenAt: now,
              lastAttemptAt: now,
            ),
          );
      final err = await db.select(db.syncPullErrors).getSingle();
      expect(err.changeId, 7);
      expect(err.attemptCount, 1);
    });

    test('exchange_rate_overrides / ledger_virtual_users 读写与默认值', () async {
      await db.into(db.exchangeRateOverrides).insert(
            ExchangeRateOverridesCompanion.insert(
              syncId: d.Value('ov-1'),
              baseCurrency: 'CNY',
              quoteCurrency: 'USD',
              rate: '7.25',
            ),
          );
      final ov = await db.select(db.exchangeRateOverrides).getSingle();
      expect(ov.rate, '7.25');

      await db.into(db.ledgerVirtualUsers).insert(
            LedgerVirtualUsersCompanion.insert(
              ledgerId: 1,
              syncId: d.Value('vu-1'),
              name: '张三',
            ),
          );
      final vu = await db.select(db.ledgerVirtualUsers).getSingle();
      expect(vu.name, '张三');
      expect(vu.updatedAt, isNull);
    });

    test('recurring_transactions 复合规则字段回读', () async {
      // 外键约束：周期模板必须挂在真实账本下。
      final ledgerId = await db
          .into(db.ledgers)
          .insert(LedgersCompanion.insert(name: 'recurring'));
      await db.into(db.recurringTransactions).insert(
            RecurringTransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 5000,
              frequency: 'monthly',
              interval: d.Value(2),
              dayOfMonth: d.Value(15),
              startDate: DateTime(2026, 1, 1),
            ),
          );
      final rt = await db.select(db.recurringTransactions).getSingle();
      expect(rt.frequency, 'monthly');
      expect(rt.interval, 2);
      expect(rt.dayOfMonth, 15);
      expect(rt.enabled, isTrue);
    });
  });
}
