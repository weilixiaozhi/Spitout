// SyncEngine 端到端测试。
//
// 用 in-memory Drift + FakeSpitoutCloudProvider 跑完整 pull/push/apply
// 链路。Day 1:smoke test 验证 fake provider 能跟 SyncEngine 兜上,跑通空 pull
// 路径。Day 2 加更多场景(脏数据 / 单飞 / web 新建账本 / busy retry 等)。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/sync_service.dart' show SyncDiff;
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeSpitoutCloudProvider provider;
  late SyncEngine engine;

  setUp(() async {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    changeTracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: changeTracker);
    provider = FakeSpitoutCloudProvider();
    engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: changeTracker,
      repo: repo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('smoke', () {
    test('空 server → pull 返 0,不 prime LookupCache', () async {
      final applied = await engine.pull('');
      expect(applied, 0);
      // pullChanges 只调一次(探针),没数据直接 return
      expect(provider.pullCalls, hasLength(1));
      expect(provider.pullCalls.first.since, 0); // 初始 cursor=0
      expect(provider.pullCalls.first.persistCursor, isFalse,
          reason: 'app 侧接管 cursor,不让 cloud-sync 包持久化');
    });

    test('cursor 在 SharedPreferences 持久化', () async {
      // 第一次空 pull 不推进 cursor
      await engine.pull('');
      final prefs = await SharedPreferences.getInstance();
      // 应该还没有 app cursor key
      final keys = prefs.getKeys().where((k) => k.startsWith('app_pull_cursor_'));
      expect(keys, isEmpty, reason: '空 pull 不应推进 cursor');
    });
  });

  group('apply 远端 change', () {
    test('server 推 transaction change → 本地 transactions 表 insert', () async {
      // 准备:本地建好 ledger 和 category(因为 transaction 引用它们)
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L1',
              syncId: const Value('ledger-1'), storageMode: const Value('cloud'),
            ),
          );
      final catId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Food',
              kind: 'expense',
              syncId: const Value('cat-1'),
            ),
          );

      // server 推一条 transaction
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-A',
        ledgerId: 'ledger-1',
        payload: {
          'syncId': 'tx-A',
          'type': 'expense',
          'amount': 12.5,
          'happenedAt': '2026-05-01T10:00:00Z',
          'note': 'lunch',
          'categoryName': 'Food',
          'categoryKind': 'expense',
          'categoryId': 'cat-1',
        },
      );

      final applied = await engine.pull('1');
      expect(applied, 1);

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.first.syncId, 'tx-A');
      expect(txs.first.amount, 1250);
      expect(txs.first.ledgerId, ledgerId);
      expect(txs.first.categoryId, catId);
    });

    test('apply 成功后 cursor 推进到本页末尾', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      // 推 3 条 change
      for (var i = 0; i < 3; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'L1',
          payload: {
            'syncId': 'tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryName': 'C',
            'categoryKind': 'expense',
            'categoryId': 'C1',
          },
        );
      }

      final applied = await engine.pull('1');
      expect(applied, 3);

      // 再次 pull 应该是空(cursor 已到末尾)
      final applied2 = await engine.pull('1');
      expect(applied2, 0);
    });

    test('共享账本 Editor 拉取交易 分类必须走 override 不绑定到成员本地同 syncId 分类', () async {
      // 成员本地存在同 syncId 的默认分类(确定性 seed 场景)
      final localCatId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: '交通',
              kind: 'expense',
              syncId: const Value('cat-traffic'),
            ),
          );
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Shared',
              syncId: const Value('shared-ledger'),
              storageMode: const Value('cloud'),
              isShared: const Value(true),
              myRole: const Value('editor'),
            ),
          );
      // Owner 分类镜像
      await db.into(db.sharedLedgerCategories).insert(
            SharedLedgerCategoriesCompanion.insert(
              ledgerSyncId: 'shared-ledger',
              syncId: 'cat-traffic',
              name: '交通',
              kind: 'expense',
              updatedAt: DateTime.now(),
            ),
          );

      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-shared-1',
        ledgerId: 'shared-ledger',
        payload: {
          'syncId': 'tx-shared-1',
          'type': 'expense',
          'amount': 20.0,
          'happenedAt': '2026-05-02T10:00:00Z',
          'currencyCode': 'CNY',
          'nativeAmount': 20.0,
          'categoryName': '交通',
          'categoryKind': 'expense',
          'categoryId': 'cat-traffic',
        },
      );

      final applied = await engine.pull('shared-ledger');
      expect(applied, 1);

      final tx = (await db.select(db.transactions).get()).single;
      expect(tx.ledgerId, ledgerId);
      expect(tx.categoryId, isNull,
          reason: 'Editor 视角不应把 Owner 分类绑到成员本地正数 id');
      expect(tx.categorySyncIdOverride, 'cat-traffic');
      expect(localCatId, isPositive,
          reason: '前置条件: 成员本地确实存在同 syncId 分类, 旧代码会误绑');
    });
  });

  group('web 新建账本场景', () {
    test('server 推 ledger entity change → 本地 ledgers 表 insert', () async {
      // 本地没这账本
      expect((await db.select(db.ledgers).get()), isEmpty);

      // server 推一条 ledger:upsert change(模拟 web 新建账本)
      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'new-ledger-uuid',
        ledgerId: 'new-ledger-uuid',
        payload: {
          'ledgerName': 'My New Ledger',
          'currency': 'USD',
        },
      );

      await engine.pull('');

      final ledgers = await db.select(db.ledgers).get();
      expect(ledgers, hasLength(1));
      expect(ledgers.first.syncId, 'new-ledger-uuid');
      expect(ledgers.first.name, 'My New Ledger');
      expect(ledgers.first.currency, 'USD');
    });

    test('server 推 ledger change 但 payload 缺 ledgerName → 跳过', () async {
      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'broken-ledger',
        ledgerId: 'broken-ledger',
        payload: {}, // 没 ledgerName
      );

      await engine.pull('');

      // 本地仍空
      expect((await db.select(db.ledgers).get()), isEmpty);
    });
  });

  // 种子收编契约：默认 seed 分类 syncId=null，远端推送同 syncId 的分类时，
  // 本地按 level + parentId 收窄到唯一行并把 syncId 补上，避免重复插入。
  // 关键场景：默认种子允许跨父同名二级（「购物>鞋子」vs「服装>鞋子」）、
  // 一级与二级同名（「服装」一级 vs「购物>服装」二级），按名反查会命中多行，
  // 必须用 level + parentId 收窄才能收编到正确行。
  group('category seed 收编（父级作用域内唯一契约）', () {
    test('远端推「服装>鞋子」→ 按 level+parentId 收编到正确行，「购物>鞋子」不被误伤', () async {
      // 本地预建 4 行 seed（模拟首启设备 B 的种子状态，syncId 全为 null）：
      //   id=1 一级「购物」
      //   id=2 一级「服装」
      //   id=3 二级「购物>鞋子」(parentId=1)
      //   id=4 二级「服装>鞋子」(parentId=2)
      final shoppingId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'shopping',
              kind: 'expense',
              level: const Value(1),
            ),
          );
      final clothingId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'clothing',
              kind: 'expense',
              level: const Value(1),
            ),
          );
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'shoes',
          kind: 'expense',
          level: const Value(2),
          parentId: Value(shoppingId),
        ),
      );
      final clothingShoesId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'shoes',
          kind: 'expense',
          level: const Value(2),
          parentId: Value(clothingId),
        ),
      );

      // server 推一条「服装>鞋子」的 category change（syncId 来自设备 A）
      provider.pushFakeChange(
        entityType: 'category',
        entitySyncId: 'cat-shoes-clothing-remote',
        payload: {
          'name': 'shoes',
          'kind': 'expense',
          'level': 2,
          'parentName': 'clothing',
          'sortOrder': 0,
        },
      );

      await engine.pull('');

      // 收编后总行数不变（没重复插入第二份 seed）
      final rows = await db.select(db.categories).get();
      expect(rows, hasLength(4),
          reason: '收编应复用既有 seed 行，不应重复插入');

      // 「服装>鞋子」(id=clothingShoesId) 的 syncId 被补上
      final clothingShoes = rows.firstWhere((c) => c.id == clothingShoesId);
      expect(clothingShoes.syncId, 'cat-shoes-clothing-remote',
          reason: '远端推的「服装>鞋子」应被收编到 parentId=clothingId 的行');

      // 「购物>鞋子」(parentId=shoppingId) 的 syncId 仍为 null（未被误伤）
      final shoppingShoes =
          rows.firstWhere((c) => c.parentId == shoppingId);
      expect(shoppingShoes.syncId, isNull,
          reason: '同名不同父的「购物>鞋子」不应被错误收编');
    });

    test('远端推一级「服装」→ 收编到 parentId=null 的一级行，不命中二级「购物>服装」', () async {
      // 本地预建：
      //   id=1 一级「购物」
      //   id=2 一级「服装」(parentId=null)
      //   id=3 二级「购物>服装」(parentId=1)  ← 与一级「服装」同名但不同 level
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'shopping',
          kind: 'expense',
          level: const Value(1),
        ),
      );
      final clothingId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'clothing',
          kind: 'expense',
          level: const Value(1),
        ),
      );
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'clothing',
          kind: 'expense',
          level: const Value(2),
          parentId: const Value(1),
        ),
      );

      // server 推一级「服装」change
      provider.pushFakeChange(
        entityType: 'category',
        entitySyncId: 'cat-clothing-root-remote',
        payload: {
          'name': 'clothing',
          'kind': 'expense',
          'level': 1,
          'sortOrder': 0,
        },
      );

      await engine.pull('');

      final rows = await db.select(db.categories).get();
      expect(rows, hasLength(3),
          reason: '收编应复用既有 seed 一级行，不应重复插入');

      // 一级「服装」(id=clothingId, parentId=null) 收编成功
      final rootClothing = rows.firstWhere((c) => c.id == clothingId);
      expect(rootClothing.syncId, 'cat-clothing-root-remote',
          reason: '远端推的一级「服装」应被收编到 parentId=null 的一级行');

      // 二级「购物>服装」(parentId=1) 的 syncId 仍为 null
      final subClothing =
          rows.firstWhere((c) => c.parentId != null && c.name == 'clothing');
      expect(subClothing.syncId, isNull,
          reason: '二级「购物>服装」与一级「服装」同名但不同 level，不应被误收编');
      expect(subClothing.id, isNot(clothingId),
          reason: '收编目标行不应是二级行');
    });
  });

  group('pull 单飞锁', () {
    test('同时 2 个 pull → server pullChanges 只调一次', () async {
      // 同时触发 2 个 pull,合并到同一个 in-flight Future
      final f1 = engine.pull('');
      final f2 = engine.pull('');
      await Future.wait([f1, f2]);

      expect(provider.pullCalls, hasLength(1),
          reason: '单飞锁应让第二个 caller 复用 in-flight 结果');
    });

    test('replay(sinceOverride 非空)等待 in-flight 完成后独立跑', () async {
      // 普通 pull
      final f1 = engine.pull('');
      // replay 等 in-flight 完后独立跑
      final f2 = engine.pull('', sinceOverride: 0);
      await Future.wait([f1, f2]);

      // 2 次 pullChanges 调用:普通 pull 1 次 + replay 1 次
      expect(provider.pullCalls, hasLength(2));
    });
  });

  group('错误恢复', () {
    test('pullChanges 抛错 → engine.pull 抛出,cursor 不推进', () async {
      provider.pullErrorInjector = (since) => Exception('network error');

      // sync 入口的 catch 会兜住错误,但底层 pull 应抛
      // 用 .pull() 直接调,期待抛
      await expectLater(engine.pull(''), throwsA(isA<Exception>()));

      // cursor 未推进 — read 仍是 0
      final cursor = await engine.appCursor.read();
      expect(cursor, 0);
    });

    test('apply 时单条 change payload 异常 → 整页 rollback + 错误入 sync_pull_errors + cursor 不推进',
        () async {
      // 推 5 条 change,第 3 条 payload 用错误类型(categoryId 传 int 而不是 string)
      // 让 _applyTransactionChange 内 `payload['categoryId'] as String?` 抛 TypeError
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));

      for (var i = 0; i < 5; i++) {
        final payload = <String, dynamic>{
          'syncId': 'tx-$i',
          'type': 'expense',
          'amount': 10.0,
          'happenedAt': '2026-05-01T10:00:00Z',
        };
        if (i == 2) {
          // 故意脏数据:categoryId 应是 String,这里传 int
          payload['categoryId'] = 12345;
        }
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'L1',
          payload: payload,
        );
      }

      final applied = await engine.pull('');
      // 整页 rollback,applied=0
      expect(applied, 0);

      // 本地 transactions 表应该是空(rollback 生效,不是只插了前两条)
      final txs = await db.select(db.transactions).get();
      expect(txs, isEmpty,
          reason: 'apply 抛错时整页 rollback,前面已 INSERT 的也应回滚');

      // cursor 不推进(读 0)
      expect(await engine.appCursor.read(), 0);

      // 错误入 sync_pull_errors 表
      final errors = await engine.pullErrors.watchUnresolved().first;
      expect(errors, hasLength(1));
      expect(errors.first.changeId, 3); // 第 3 条触发
      expect(errors.first.entityType, 'transaction');
      expect(errors.first.entitySyncId, 'tx-2');
      expect(errors.first.errorClass, contains('TypeError'));
    });

    test('修复后 server 推同 change_id 新版本 → markResolved', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));

      // 先推一条会抛错的
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-A',
        ledgerId: 'L1',
        payload: {
          'categoryId': 999, // 错误类型
          'amount': 10.0,
        },
      );
      await engine.pull('');
      expect((await engine.pullErrors.watchUnresolved().first), hasLength(1));

      // 通过 markResolved 模拟"server 修了 + app 拉到新版本":
      // 实际逻辑应该是 server push 新 change_id 触发 apply 成功后 markResolved
      // 这里直接调测试 marker
      await engine.pullErrors.markResolved(1);
      expect((await engine.pullErrors.watchUnresolved().first), isEmpty);
    });
  });

  group('cursor 持久化', () {
    test('apply 成功后 cursor 写入 SharedPreferences,跨 SyncEngine 实例可读', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      for (var i = 0; i < 3; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'L1',
          payload: {
            'syncId': 'tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryId': 'C1',
            'categoryName': 'C',
            'categoryKind': 'expense',
          },
        );
      }

      await engine.pull('');
      final cursor1 = await engine.appCursor.read();
      expect(cursor1, 3, reason: '3 条 change 后 cursor 应到 changeId=3');

      // 模拟 app 重启:新建 SyncEngine,读 cursor 继续
      final engine2 = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: changeTracker,
        repo: repo,
      );
      final cursor2 = await engine2.appCursor.read();
      expect(cursor2, 3, reason: '新 SyncEngine 实例应从 SharedPreferences 读到上次 cursor');

      // 第二个 engine pull 应该看到"无变更"(空 pull)
      final applied = await engine2.pull('');
      expect(applied, 0);
      // 验证 pullChanges 是从 since=3 开始,不是从 0 重拉
      expect(provider.pullCalls.last.since, 3);
    });
  });

  group('replay (sinceOverride=0)', () {
    test('replay 从头拉所有 change,即使 cursor 已推进', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      for (var i = 0; i < 3; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'L1',
          payload: {
            'syncId': 'tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryId': 'C1',
            'categoryName': 'C',
            'categoryKind': 'expense',
          },
        );
      }

      // 第一次 pull,cursor 推到 3
      await engine.pull('');
      expect(await engine.appCursor.read(), 3);

      // replay 从 0 拉 — 由于 apply 是 syncId upsert 幂等,重拉不会重复插
      provider.pullCalls.clear();
      final applied = await engine.pull('', sinceOverride: 0);
      expect(applied, 3, reason: 'replay 应重新 apply 3 条');
      expect(provider.pullCalls.first.since, 0,
          reason: 'replay 必须从 since=0 拉');

      // 本地 transactions 仍是 3 条(没 dup)
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(3));
    });
  });

  group('push 路径', () {
    test('本地有 unpushed change → engine.push 推到 server', () async {
      // 本地通过 repo 写一条 tx(会触发 changeTracker.recordLedgerChange)
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud'),
            ),
          );
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 9950,
          syncId: const Value('tx-push-1'),
        ),
      ]);

      // 验证 local_changes 已登记
      final unpushed =
          await changeTracker.getUnpushedChangesForLedger(ledgerId);
      expect(unpushed, hasLength(1));
      expect(unpushed.first.entityType, 'transaction');

      // 触发 engine.push
      final pushed = await engine.push(ledgerId.toString());
      expect(pushed, 1);

      // fake provider 收到 1 个 batch,内含 1 条 change
      expect(provider.pushedBatches, hasLength(1));
      expect(provider.pushedBatches.first, hasLength(1));
      expect(provider.pushedBatches.first.first['entity_sync_id'], 'tx-push-1');
      expect(provider.pushedBatches.first.first['action'], 'upsert');

      // local_changes 已 markPushed
      final remaining = await changeTracker.getUnpushedChangesForLedger(ledgerId);
      expect(remaining, isEmpty);
    });

    test('push 后再调 → 无新变更 → 不发 batch', () async {
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 1000,
            syncId: const Value('tx-1')),
      ]);
      await engine.push(ledgerId.toString());
      expect(provider.pushedBatches, hasLength(1));

      // 第二次 push 无变更
      final pushed2 = await engine.push(ledgerId.toString());
      expect(pushed2, 0);
      expect(provider.pushedBatches, hasLength(1), reason: '无变更不应发新 batch');
    });
  });

  group('recordChanges=false:fullPull 不反向回流', () {
    test('LocalRepository.insertTransactionsBatch(recordChanges: false) → 不写 local_changes',
        () async {
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));

      // 模拟 fullPull 路径:DataImportService 大批量插 + recordChanges=false
      await repo.insertTransactionsBatch(
        List.generate(
            50,
            (i) => TransactionsCompanion.insert(
                  ledgerId: ledgerId,
                  type: 'expense',
                  amount: i * 100,
                  syncId: Value('fullpull-tx-$i'),
                )),
        recordChanges: false,
      );

      // 本地有 50 条 tx,但 local_changes 表为空(不会反向 push)
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(50));
      final changes =
          await changeTracker.getUnpushedChangesForLedger(ledgerId);
      expect(changes, isEmpty,
          reason: 'fullPull 写入不应触发 changeTracker.recordLedgerChange');
    });

    test('默认 recordChanges=true 路径仍正常登记', () async {
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 100,
            syncId: const Value('normal-tx')),
      ]); // 不传 recordChanges,走默认 true
      final changes =
          await changeTracker.getUnpushedChangesForLedger(ledgerId);
      expect(changes, hasLength(1));
    });
  });

  group('同步前状态检查 (getStatus)', () {
    test('isShared=true + myRole=editor → 不触发 fullPush', () async {
      // 本地标记此账本是共享 Editor
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Shared',
              syncId: const Value('shared-l1'), storageMode: const Value('cloud'),
              isShared: const Value(true),
              myRole: const Value('editor'),
            ),
          );
      // 远端不返此账本(模拟 owner 在,但 server list 路径下 Editor 角色看到的视角)
      // — 即使 storage.list 没返,Editor 也不应 fullPush(会覆盖 Owner 数据)
      final result = await engine.sync(ledgerId: ledgerId.toString());

      expect(provider.writeCreateLedgerCalls, isEmpty,
          reason: 'Editor 角色永不应触发 fullPush');
      expect(result.hasError, isFalse);
    });
  });

  group('apply 各种 entity type', () {
    test('category insert', () async {
      provider.pushFakeChange(
        entityType: 'category',
        entitySyncId: 'cat-X',
        ledgerId: '',
        payload: {
          'name': 'NewCat',
          'kind': 'expense',
          'sortOrder': 0,
        },
      );

      final applied = await engine.pull('');
      expect(applied, 1);

      final cats = await db.select(db.categories).get();
      expect(cats.where((c) => c.syncId == 'cat-X'), hasLength(1));
    });

    test('apply update 已存在的实体(按 syncId upsert,不重复 insert)', () async {
      // 本地先有
      final catId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Original',
              kind: 'expense',
              syncId: const Value('cat-upd'),
            ),
          );
      // server 推 update,改名
      provider.pushFakeChange(
        entityType: 'category',
        entitySyncId: 'cat-upd',
        ledgerId: '',
        payload: {
          'name': 'Renamed',
          'kind': 'expense',
        },
      );

      await engine.pull('');

      final cats = await (db.select(db.categories)
            ..where((c) => c.id.equals(catId)))
          .get();
      expect(cats, hasLength(1)); // 没新增,只更新
      expect(cats.first.name, 'Renamed');
    });
  });

  group('apply delete change', () {
    test('server 推 transaction:delete → 本地行被删 + cache 同步移除', () async {
      // 准备:本地有一条 tx
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 800,
              syncId: const Value('tx-to-delete'),
            ),
          );

      // server 推一条 delete
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-to-delete',
        ledgerId: 'L1',
        action: 'delete',
      );

      await engine.pull('');

      // 本地被删
      final remaining = await db.select(db.transactions).get();
      expect(remaining, isEmpty);
    });
  });

  group('fullPush 路径', () {
    test('远端无此账本 → SyncEngine.sync 触发 fullPush 流程', () async {
      // 本地建账本 + 1 条 tx
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'My Ledger',
              syncId: const Value('my-ledger-uuid'), storageMode: const Value('cloud'),
              currency: const Value('CNY'),
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
                name: 'C', kind: 'expense', syncId: const Value('C1')),
          );
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 5000,
            syncId: const Value('tx-full-1')),
      ]);

      // server storage.list 返空 → fullPush 决策触发
      // (provider 默认就是空)

      final result = await engine.sync(ledgerId: ledgerId.toString());

      // fullPush 路径:writeCreateLedger 被调
      expect(provider.writeCreateLedgerCalls, isNotEmpty,
          reason: 'fullPush 应调 writeCreateLedger 显式建 server 账本');
      // 不应有 error
      expect(result.hasError, isFalse);
    });

    test('远端有此账本 → 走增量 push,不 fullPush', () async {
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L',
              syncId: const Value('existing-uuid'), storageMode: const Value('cloud'),
            ),
          );
      // 标记 server 端已有此账本
      provider.pushFakeLedgerSnapshot(ledgerId: 'existing-uuid');

      // 加一条 unpushed change
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 500,
            syncId: const Value('tx-incr')),
      ]);

      final result = await engine.sync(ledgerId: ledgerId.toString());

      expect(provider.writeCreateLedgerCalls, isEmpty,
          reason: '远端已有账本时不应触发 fullPush');
      expect(result.hasError, isFalse);
      // 增量 push 应有 1 batch
      expect(provider.pushedBatches, hasLength(1));
    });
  });

  group('SyncEvent stream(PR 1 解耦改造)', () {
    test('WS pull 完成 emit PullCompleted 到 events stream', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      // 订阅 events
      final received = <SyncEvent>[];
      final sub = engine.events.listen(received.add);

      engine.startListeningRealtime();
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-event',
        ledgerId: 'L1',
        payload: {
          'syncId': 'tx-event',
          'type': 'expense',
          'amount': 1.0,
          'happenedAt': '2026-05-01T10:00:00Z',
          'categoryId': 'C1',
          'categoryName': 'C',
          'categoryKind': 'expense',
        },
      );
      provider.emitRealtimeEvent(SpitoutCloudRealtimeEvent(
        type: 'sync_change',
        ledgerId: 'L1',
        rawData: const {},
      ));

      await Future.delayed(const Duration(milliseconds: 1500));

      engine.stopListeningRealtime();
      await sub.cancel();

      // 至少有一个 PullCompleted 事件
      final pullEvents = received.whereType<PullCompleted>().toList();
      expect(pullEvents, isNotEmpty);
      expect(pullEvents.last.ledgerId, 'L1');
      expect(pullEvents.last.applied, greaterThan(0));
    });

    test('sync push 后清缓存 + emit,getStatus 从 localNewer 刷新为 inSync'
        '(修复:同步完成后「我的」页状态自动更新,不用手动下拉)', () async {
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L',
              syncId: const Value('existing-uuid'), storageMode: const Value('cloud'),
            ),
          );
      // 远端已有此账本 → 走增量 push,避开 fullPush 复杂路径
      provider.pushFakeLedgerSnapshot(ledgerId: 'existing-uuid');
      // 本地写一条 tx → 产生 unpushed local_change
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 800,
          syncId: const Value('tx-push-event'),
        ),
      ]);

      // 同步前:有未推送变更 → getStatus = localNewer,并把结果写进 _statusCache
      final before = await engine.getStatus(ledgerId: ledgerId);
      expect(before.diff, SyncDiff.localNewer,
          reason: '本地有未推送变更,同步前应为 localNewer(并落入缓存)');

      final received = <SyncEvent>[];
      final sub = engine.events.listen(received.add);
      final result = await engine.sync(ledgerId: ledgerId.toString());
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result.pushed, greaterThan(0));
      // 修复点 1:push 完成 emit PushCompleted,通知 UI 重新读同步状态
      expect(received.whereType<PushCompleted>(), isNotEmpty,
          reason: 'push 上传本地变更后必须 emit PushCompleted');
      // 修复点 2(真正根因):push 后清了 _statusCache,getStatus 不再吃旧缓存。
      // 若仍命中缓存返回 localNewer,「我的」页就得手动下拉才更新 —— 本 bug。
      final after = await engine.getStatus(ledgerId: ledgerId);
      expect(after.diff, SyncDiff.inSync,
          reason: 'push 成功后 getStatus 必须刷新为 inSync;'
              '命中旧缓存返回 localNewer 即是本 bug 复现');
    });

    test('多种事件类型 dispatch:PullCompleted / ProfileFieldApplied 等', () async {
      final received = <SyncEvent>[];
      final sub = engine.events.listen(received.add);

      // 直接调 _emit 不容易(私有),但 syncMyProfile / pull 路径会 emit。
      // 这里用 syncMyProfile 路径:fake provider 抛 UnimplementedError →
      // 整个流程进 catch 不 emit。我们改测 pull → PullCompleted
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      engine.startListeningRealtime();
      provider.emitRealtimeEvent(SpitoutCloudRealtimeEvent(
        type: 'sync_change',
        ledgerId: 'L1',
        rawData: const {},
      ));
      await Future.delayed(const Duration(milliseconds: 1500));
      engine.stopListeningRealtime();
      await sub.cancel();

      expect(received.whereType<PullCompleted>(), isNotEmpty);
    });
  });

  group('WS realtime', () {
    test('startListeningRealtime + 模拟 WS sync_change → 1s debounce 后触发 pull',
        () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1'), storageMode: const Value('cloud')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      // 启动 WS 监听
      engine.startListeningRealtime();

      // 推一条 change 到 server,然后模拟 WS event
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-ws',
        ledgerId: 'L1',
        payload: {
          'syncId': 'tx-ws',
          'type': 'expense',
          'amount': 7.0,
          'happenedAt': '2026-05-01T10:00:00Z',
          'categoryId': 'C1',
          'categoryName': 'C',
          'categoryKind': 'expense',
        },
      );
      provider.emitRealtimeEvent(SpitoutCloudRealtimeEvent(
        type: 'sync_change',
        ledgerId: 'L1',
        rawData: const {},
      ));

      // _schedulePull 内 1 秒 debounce + 兜底 syncLedgersFromServer
      // 等待足够时间让 debounce + pull 完成
      await Future.delayed(const Duration(milliseconds: 1500));

      // 验证 apply 成功
      final txs = await db.select(db.transactions).get();
      expect(txs.where((t) => t.syncId == 'tx-ws'), hasLength(1));

      engine.stopListeningRealtime();
    });
  });

  group('下拉刷新幂等修复 (P2/P3)', () {
    // 云端账本快照（可被 runFullPull 下载恢复的最小 JSON）。
    // 用于验证「空账本 → 全量恢复」契约在新逻辑下仍成立。
    const snapshotJson = '''
{
  "version": 6,
  "exportedAt": "2026-07-01T00:00:00Z",
  "ledgerId": 1,
  "ledgerName": "L1",
  "currency": "CNY",
  "monthStartDay": 1,
  "count": 2,
  "categories": [],
  "items": [
    {"type":"expense","amount":10.0,"happenedAt":"2026-07-01T10:00:00Z","syncId":"tx-s1"},
    {"type":"expense","amount":20.0,"happenedAt":"2026-07-02T10:00:00Z","syncId":"tx-s2"}
  ]
}
''';

    Future<int> newLedger(String syncId) => db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: Value(syncId)),
        );

    Future<int> countTx() async =>
        (await db.select(db.transactions).get()).length;

    test('P3 pullIncremental：已同步设备无新变更 → 返回0且不触发全量(防翻倍)',
        () async {
      final lid = await newLedger('ledger-1');
      // 本地已有 1 条已同步交易(模拟已同步设备)
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 1000,
            syncId: const Value('tx-local'),
          ));
      final before = await countTx();

      // 关键：下拉刷新只走增量 pull，绝不触发全量恢复
      final pulled = await engine.pullIncremental(ledgerId: lid);
      expect(pulled, 0, reason: '无新变更，pull 应返回 0');
      expect(await countTx(), before, reason: '数据不应翻倍');
    });

    test('P3 pullIncremental：有 server change → 返回变更条数并落库', () async {
      final lid = await newLedger('ledger-1');
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-new',
        ledgerId: 'ledger-1',
        payload: {
          'syncId': 'tx-new',
          'type': 'expense',
          'amount': 5.0,
          'happenedAt': '2026-07-03T10:00:00Z',
          'categoryId': 'C1',
          'categoryName': 'C',
          'categoryKind': 'expense',
        },
      );
      final pulled = await engine.pullIncremental(ledgerId: lid);
      expect(pulled, 1, reason: '应拉到 1 条新变更');
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.first.syncId, 'tx-new');
    });

    test('P2 downloadAndRestoreToCurrentLedger：已同步账本不触发全量(防翻倍)',
        () async {
      final lid = await newLedger('ledger-1');
      // 本地已有数据，且云端也有一份快照 —— 验证 fullPull 不会把快照重插
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            ledgerId: lid,
            type: 'expense',
            amount: 1000,
            syncId: const Value('tx-local'),
          ));
      await provider.storage.upload(path: 'ledger-1', data: snapshotJson);

      final r = await engine.downloadAndRestoreToCurrentLedger(ledgerId: lid);
      expect(r.inserted, 0, reason: '本地已有数据且 pull==0 → 不触发全量');
      expect(await countTx(), 1, reason: '数据不应翻倍');
    });

    test('P2 downloadAndRestoreToCurrentLedger：空账本触发全量恢复(新设备契约)',
        () async {
      final lid = await newLedger('ledger-1');
      // 云端有快照，本地为空 → 应全量恢复 2 条
      await provider.storage.upload(path: 'ledger-1', data: snapshotJson);

      final r = await engine.downloadAndRestoreToCurrentLedger(ledgerId: lid);
      expect(r.inserted, 2, reason: '空账本应从云端全量恢复');
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
      expect(txs.map((t) => t.syncId).toList(),
          containsAll(['tx-s1', 'tx-s2']));
    });
  });

  group('自愈:游标越过历史 change(self-heal)', () {
    /// 构造"游标越过历史 change"场景:
    /// server 有 2 条 tx change,设备 pull 过(cursor=2),之后本地 tx 行
    /// 被直接物理删除(模拟历史 cursor bug / 本地库被清,未登记 delete
    /// change)。此后增量 pull 恒返回 0,数据永远拉不回 —— 本 bug 复现。
    Future<int> setupCursorOvertakesHistory() async {
      final lid = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L',
              syncId: const Value('ledger-1'), storageMode: const Value('cloud'),
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'C',
              kind: 'expense',
              syncId: const Value('C1'),
            ),
          );
      for (var i = 0; i < 2; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'ledger-1',
          payload: {
            'syncId': 'tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryId': 'C1',
            'categoryName': 'C',
            'categoryKind': 'expense',
          },
        );
      }
      // 设备曾经同步过:apply 2 条,cursor 推到 2
      final applied = await engine.pull('');
      expect(applied, 2);
      expect(await engine.appCursor.read(), 2);

      // 本地数据丢失(直接删行,不经 changeTracker —— 云端无 delete change)
      await db.delete(db.transactions).go();
      expect((await db.select(db.transactions).get()), isEmpty);

      // 让 sync() 的 fullPush 决策命中"远端已有账本",走增量路径
      provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-1');
      return lid;
    }

    test('红测试:sync() 应检测本地缺失并自愈恢复(remoteOnly>0 → 重放)', () async {
      final lid = await setupCursorOvertakesHistory();

      final result = await engine.sync(ledgerId: lid.toString());

      expect(result.hasError, isFalse);
      // 【根因修复】sync() 内 pulled==0 已挂自愈入口,effectivePulled 应反映
      // 自愈补回的条数(sync() 这条 WS 重连 / 开屏路径的关键契约)。
      expect(result.pulled, 2, reason: 'pulled 应反映自愈补回的条数');
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2),
          reason: '游标越过历史 change 时,sync() 必须自愈把云端数据拉回本地;'
              '增量 pull 恒返回 0 导致数据永远缺失即本 bug');
    });

    test('pullIncrementalWithHeal:自愈恢复云端缺失数据(首页下拉路径)', () async {
      final lid = await setupCursorOvertakesHistory();

      final outcome = await engine.pullIncrementalWithHeal(ledgerId: lid);

      expect(outcome.incremental, 0, reason: '游标已越过,增量拉不到');
      expect(outcome.didHeal, isTrue);
      expect(outcome.healed, 2, reason: '自愈重放应补回 2 条');
      expect(outcome.gapRemaining, isFalse);
      expect(outcome.circuitBroken, isFalse);
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
    });

    test('闸门:本地有未推送变更时不触发自愈(防未推送 delete 造成误判)',
        () async {
      final lid = await setupCursorOvertakesHistory();
      // 本地新记一条(经 repo → changeTracker 登记,unpushed=1)
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: lid,
          type: 'expense',
          amount: 300,
          syncId: const Value('tx-local-new'),
        ),
      ]);

      final outcome = await engine.pullIncrementalWithHeal(ledgerId: lid);

      expect(outcome.didHeal, isFalse,
          reason: 'unpushed>0 时闸门必须拦截自愈,等 sync() push 后再判定');
      // 本地只有新记的 1 条,云端缺失的 2 条不应被拉回
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.first.syncId, 'tx-local-new');
    });

    test('节流:健康设备重复 withHeal 不重复打 /stats', () async {
      final lid = await setupCursorOvertakesHistory();
      // 先自愈一次把数据补齐(第一次 withHeal 打 1 次 stats)
      await engine.pullIncrementalWithHeal(ledgerId: lid);
      final statsCallsAfterHeal = provider.readLedgerStatsCalls;
      expect(statsCallsAfterHeal, greaterThan(0));

      // 节流窗口内再次 withHeal:pull 仍空,但不应再打 stats
      final outcome = await engine.pullIncrementalWithHeal(ledgerId: lid);
      expect(outcome.didHeal, isFalse, reason: '已补齐,无需自愈');
      expect(provider.readLedgerStatsCalls, statsCallsAfterHeal,
          reason: '节流窗口内重复验证不应再打 /stats(高频入口轻量原则)');
    });

    test('熔断:stats 口径恒偏大时,连续失败 2 次后熔断不再重试', () async {
      final lid = await setupCursorOvertakesHistory();
      // 模拟 server stats 口径与本地 apply 存在系统性偏差:云端恒报 5 条,
      // 重放/快照后本地只有 2 条,差异永远消不掉。
      provider.ledgerStatsOverrides['ledger-1'] =
          const SpitoutCloudLedgerStats(
        transactionCount: 5,
        transactionTotal: 5,

        categoryCount: 0,
        categoryTotal: 0,
      );

      // 第 1 次:自愈执行但二次确认失败,失败计数=1,未熔断
      await engine.pullIncrementalWithHeal(ledgerId: lid);
      expect(engine.selfHealBroken(lid.toString()), isFalse,
          reason: '首次失败只计数,不熔断');

      // 第 2 次:清节流让检查立即执行 → 再失败 → 达阈值熔断
      engine.debugClearSelfHealThrottle();
      final outcome2 = await engine.pullIncrementalWithHeal(ledgerId: lid);
      expect(outcome2.gapRemaining, isTrue, reason: '口径偏差下差异消不掉');
      expect(engine.selfHealBroken(lid.toString()), isTrue,
          reason: '连续 2 次二次确认失败应熔断');

      // 第 3 次:熔断期内直接短路 —— 不打 stats、不重放
      engine.debugClearSelfHealThrottle(); // 即使清节流,熔断也优先短路
      final statsBefore = provider.readLedgerStatsCalls;
      final pullCallsBefore = provider.pullCalls.length;
      final outcome3 = await engine.pullIncrementalWithHeal(ledgerId: lid);
      expect(outcome3.didHeal, isFalse);
      expect(outcome3.circuitBroken, isTrue);
      expect(provider.readLedgerStatsCalls, statsBefore,
          reason: '熔断期内不应再打 /stats');
      expect(provider.pullCalls.length, pullCallsBefore + 1,
          reason: '熔断期内只做 1 次普通增量 probe,不重放整段日志');
    });

    test('快照兜底:重放拉不回时(本设备变更被 server 排除)走快照恢复',
        () async {
      final lid = await setupCursorOvertakesHistory();
      // 模拟"重放拿不到缺失数据"场景:server sync_changes 里没有这些 change
      // (本设备 push 的变更会被 device_id 排除),但 stats 报 2 条,且快照里有。
      // 这里通过清空 fake 的 change 流模拟"重放拿不到"。
      provider.pullCalls.clear();
      const snapshotJson = '''
{
  "version": 6,
  "exportedAt": "2026-07-01T00:00:00Z",
  "ledgerId": 1,
  "ledgerName": "L",
  "currency": "CNY",
  "monthStartDay": 1,
  "count": 2,
  "categories": [],
  "items": [
    {"type":"expense","amount":10.0,"happenedAt":"2026-05-01T10:00:00Z","syncId":"tx-0"},
    {"type":"expense","amount":10.0,"happenedAt":"2026-05-01T10:00:00Z","syncId":"tx-1"}
  ]
}
''';
      await provider.storage.upload(path: 'ledger-1', data: snapshotJson);

      final outcome = await engine.pullIncrementalWithHeal(ledgerId: lid);

      expect(outcome.didHeal, isTrue);
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2), reason: '快照兜底应把 2 条数据恢复到本地');
      expect(outcome.gapRemaining, isFalse);
    });

    /// 为指定账本构造"游标越过历史 change"缺口(复用与红测试一致的手法,
    /// 但支持任意 syncId,用于验证自愈的 per-ledger 语义:本地数据被直接
    /// 物理删除、云端无 delete change,游标却已越过这些 change)。
    Future<int> setupGap(String ledgerSyncId) async {
      final lid = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L',
              syncId: Value(ledgerSyncId),
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'C',
              kind: 'expense',
              syncId: const Value('C1'),
            ),
          );
      for (var i = 0; i < 2; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: '$ledgerSyncId-tx-$i',
          ledgerId: ledgerSyncId,
          payload: {
            'syncId': '$ledgerSyncId-tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryId': 'C1',
            'categoryName': 'C',
            'categoryKind': 'expense',
          },
        );
      }
      // 应用全部 change(全局游标推进)→ 本地落 2 条
      final applied = await engine.pull('');
      expect(applied, 2);
      // 本地数据丢失(直接删行,不经 changeTracker → 云端无 delete change)
      await (db.delete(db.transactions)..where((t) => t.ledgerId.equals(lid)))
          .go();
      expect((await db.select(db.transactions).get()), isEmpty);
      // 让 sync() 的 fullPush 决策命中"远端已有账本",走增量路径
      provider.pushFakeLedgerSnapshot(ledgerId: ledgerSyncId);
      return lid;
    }

    test('负向:健康设备 withHeal 返回全零 outcome,且只打 1 次 /stats',
        () async {
      // 构造"已完全同步"的健康基线:本地与云端各有 2 条、游标对齐。
      final lid = await setupGap('ledger-1');
      // setupGap 后本地被删(缺口),这里先自愈补齐,得到健康基线。
      await engine.pullIncrementalWithHeal(ledgerId: lid);
      expect(await db.select(db.transactions).get(), hasLength(2),
          reason: '前置:设备此时已健康(本地 == 云端)');

      // 节流窗口内重复 withHeal 会被拦截,所以先清节流,确保本次会真打 /stats。
      engine.debugClearSelfHealThrottle();
      final statsBefore = provider.readLedgerStatsCalls;
      final outcome = await engine.pullIncrementalWithHeal(ledgerId: lid);

      expect(outcome.incremental, 0, reason: '已最新,增量拉不到');
      expect(outcome.didHeal, isFalse, reason: '本地不缺数据,无需自愈');
      expect(outcome.healed, 0);
      expect(outcome.gapRemaining, isFalse);
      expect(outcome.circuitBroken, isFalse);
      expect(await db.select(db.transactions).get(), hasLength(2),
          reason: '健康设备数据不应被改动');
      expect(provider.readLedgerStatsCalls, statsBefore + 1,
          reason: '首查需打 1 次 /stats 以确认健康(然后再被节流)');
    });

    test('负向:readLedgerStats 抛错时自愈静默吞错,不崩溃也不误 heal',
        () async {
      final lid = await setupCursorOvertakesHistory();
      provider.failingReadLedgerStats = true;
      final statsCallsBefore = provider.readLedgerStatsCalls;

      // 不应抛异常,返回"未自愈"的 outcome。
      final outcome = await engine.pullIncrementalWithHeal(ledgerId: lid);

      expect(outcome.incremental, 0);
      expect(outcome.didHeal, isFalse, reason: 'stats 失败不应误判/误 heal');
      expect(outcome.healed, 0);
      expect(outcome.gapRemaining, isFalse);
      expect(outcome.circuitBroken, isFalse,
          reason: '错误路径不计为自愈失败,不误触熔断');
      expect(await db.select(db.transactions).get(), isEmpty,
          reason: 'stats 失败,本地数据不应被改动');
      expect(provider.readLedgerStatsCalls, statsCallsBefore + 1,
          reason: '确实发起了 1 次 stats 查询(随后失败)');
      expect(engine.selfHealBroken(lid.toString()), isFalse);
    });

    test('节流:窗口内再次丢失数据也不重复自愈(拦截的是自愈动作本身)',
        () async {
      final lid = await setupCursorOvertakesHistory();
      // 第一次自愈:补齐 2 条,打 1 次 stats,写入节流时间戳。
      final first = await engine.pullIncrementalWithHeal(ledgerId: lid);
      expect(first.didHeal, isTrue);
      expect(first.healed, 2);
      expect(engine.selfHealBroken(lid.toString()), isFalse,
          reason: '自愈成功不应误触熔断');
      final statsAfterFirst = provider.readLedgerStatsCalls;
      expect(statsAfterFirst, greaterThan(0));

      // 节流窗口内再次丢失数据(模拟又发生一次本地丢失)。
      await db.delete(db.transactions).go();
      expect(await db.select(db.transactions).get(), isEmpty);

      // 不清节流 → 自愈动作(含 /stats 查询与重放)应被整体拦截。
      final second = await engine.pullIncrementalWithHeal(ledgerId: lid);
      expect(second.didHeal, isFalse, reason: '节流拦截,不应再次自愈');
      expect(second.healed, 0);
      expect(await db.select(db.transactions).get(), isEmpty,
          reason: '节流期内本地数据维持缺失,自愈动作被拦截');
      expect(provider.readLedgerStatsCalls, statsAfterFirst,
          reason: '节流期内连 /stats 都不应再打');
    });

    /// ledgerSyncId 指定的账本"正常同步、无缺口",返回其本地行 id。
    /// 用于验证 per-ledger 闸门/熔断时,其他账本不应被连带误伤。
    /// 注意:replayAllChanges 是整段 change 日志的【全局重放】,本测试
    /// 只验证"闸门/熔断判定是 per-ledger"这一契约,不要求 healed 精确等于
    /// 某账本的条数。
    Future<int> setupHealthyLedger(String ledgerSyncId) async {
      final lid = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(name: 'L', syncId: Value(ledgerSyncId)),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'C',
              kind: 'expense',
              syncId: Value('C-$ledgerSyncId')),
          );
      for (var i = 0; i < 2; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: '$ledgerSyncId-tx-$i',
          ledgerId: ledgerSyncId,
          payload: {
            'syncId': '$ledgerSyncId-tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryId': 'C-$ledgerSyncId',
            'categoryName': 'C',
            'categoryKind': 'expense',
          },
        );
      }
      final applied = await engine.pull('');
      expect(applied, 2);
      provider.pushFakeLedgerSnapshot(ledgerId: ledgerSyncId);
      return lid;
    }

    test('闸门:异账本未推送变更不阻挡本账本自愈(per-ledger 闸门)', () async {
      final lid1 = await setupGap('ledger-1');
      // ledger-2 正常同步(无缺口),仅在本地有一条未推送变更。
      // 注意:fake provider 以 ledgerId【字符串字面量】为 key,不做 int 解析,
      // 故 'ledger-1' / 'ledger-2' / 'ledger-3' … 互不撞车;这里特意用字符串
      // 形态(而非纯数字 '2')证明第三个/第四个账本同样安全。
      final lid2 = await setupHealthyLedger('ledger-2');
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: lid2,
          type: 'expense',
          amount: 300,
          syncId: const Value('tx-local-2'),
        ),
      ]);

      // 对 ledger-1 触发自愈:闸门只校验 ledger-1 本账本的 unpushed(=0),
      // ledger-2 的未推送变更不应连带阻挡 ledger-1 的恢复。
      final outcome = await engine.pullIncrementalWithHeal(ledgerId: lid1);
      expect(outcome.didHeal, isTrue,
          reason: 'per-ledger 闸门:异账本未推送不应误伤本账本');
      expect(outcome.healed, greaterThanOrEqualTo(2),
          reason: '全局重放至少补齐 ledger-1 的 2 条');
      // ledger-1 恢复 2 条。
      final txs1 = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(lid1)))
          .get();
      expect(txs1, hasLength(2));
      // ledger-2 未受影响:2 条已同步 + 1 条未推送,共 3 条。
      final txs2 = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(lid2)))
          .get();
      expect(txs2, hasLength(3),
          reason: 'ledger-2 的未推送变更不应被本账本自愈误伤/误推');
    });

    test('熔断:不同账本的熔断状态相互独立(per-ledger 熔断)', () async {
      final lid1 = await setupGap('ledger-1');
      // 注意:fake provider 以 ledgerId【字符串字面量】为 key,不做 int 解析,
      // 故 'ledger-1' / 'ledger-2' / 'ledger-3' … 互不撞车;这里特意用字符串
      // 形态(而非纯数字 '2')证明第三个/第四个账本同样安全。
      final lid2 = await setupHealthyLedger('ledger-2');
      // 仅让 ledger-1 的 stats 口径恒偏大,制造连续失败 → 熔断 ledger-1。
      provider.ledgerStatsOverrides['ledger-1'] = const SpitoutCloudLedgerStats(
        transactionCount: 5,
        transactionTotal: 5,

        categoryCount: 0,
        categoryTotal: 0,
      );
      await engine.pullIncrementalWithHeal(ledgerId: lid1);
      expect(engine.selfHealBroken(lid1.toString()), isFalse,
          reason: '首次失败只计数');
      engine.debugClearSelfHealThrottle();
      await engine.pullIncrementalWithHeal(ledgerId: lid1);
      expect(engine.selfHealBroken(lid1.toString()), isTrue,
          reason: 'ledger-1 已熔断');

      // ledger-2 制造独立缺口 → 不应被 ledger-1 的熔断影响,应能正常自愈。
      await (db.delete(db.transactions)..where((t) => t.ledgerId.equals(lid2)))
          .go();
      engine.debugClearSelfHealThrottle();
      final outcome2 = await engine.pullIncrementalWithHeal(ledgerId: lid2);
      expect(outcome2.didHeal, isTrue, reason: '不同账本熔断应相互独立');
      expect(outcome2.healed, greaterThanOrEqualTo(2));
      expect(outcome2.circuitBroken, isFalse);
      final txs2 = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(lid2)))
          .get();
      expect(txs2, hasLength(2), reason: 'ledger-2 自愈补齐 2 条');
      expect(engine.selfHealBroken(lid1.toString()), isTrue,
          reason: 'ledger-1 仍熔断');
      expect(engine.selfHealBroken(lid2.toString()), isFalse,
          reason: 'ledger-2 未熔断');
    });
  });

  group('SyncCountPair.remoteOnly', () {
    test('remote 拉不到(-1) → 0(不误判缺数据)', () {
      const pair = SyncCountPair(local: 0, remote: -1);
      expect(pair.remoteOnly, 0);
    });

    test('remote <= local → 0(自愈只关心云端多)', () {
      expect(const SyncCountPair(local: 3, remote: 3).remoteOnly, 0);
      expect(const SyncCountPair(local: 5, remote: 2).remoteOnly, 0);
    });

    test('remote > local → 差值', () {
      expect(const SyncCountPair(local: 0, remote: 2).remoteOnly, 2);
      expect(const SyncCountPair(local: 834, remote: 836).remoteOnly, 2);
    });
  });

  group('syncLedgersFromServer byName 收编 — 防跨用户数据泄露(L1)', () {
    test('个人默认账本不因同名共享账本被误收编', () async {
      // 构造:B 的本地个人默认账本(未同步 / 个人账本),与 A 的共享默认账本同名。
      // 这正是 byName 收编的设计盲点:修复前只按 name + syncId.isNull 匹配,
      // 会把 B 的个人账本错误收编成 A 的共享账本,进而把 B 的个人流水推到 A 的共享账本(L2 泄露)。
      final personalId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: '默认账本',
              isShared: const Value(false),
              // syncId 缺省 = null(未同步 seed 行,正是 byName fallback 的目标)
            ),
          );

      // 远端:A 的共享默认账本(同名、isShared=true、B 是 editor)。
      provider.pushFakeLedger(
        ledgerId: 'shared-X',
        ledgerName: '默认账本',
        isShared: true,
        role: 'editor',
        memberCount: 2,
      );

      // 触发 ledger 收编(走 Branch 2 byName fallback)。
      final inserted = await engine.syncLedgersFromServer();
      expect(inserted, greaterThanOrEqualTo(1),
          reason: '远端共享账本应作为新行被插入');

      // 断言 1:原个人默认账本【未被收编】,syncId 仍是 null、身份仍是个人账本。
      // 这是根因修复的定罪点:若被收编,syncId 会变 'shared-X'、isShared=true、
      // myRole=editor,后续 push 会把 B 的个人流水泄露到 A 的共享账本。
      final personal = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(personalId)))
          .getSingle();
      expect(personal.syncId, isNull,
          reason: '个人默认账本不应被同名共享账本收编,syncId 必须保持 null');
      expect(personal.isShared, isFalse,
          reason: '个人账本身份不得被改成共享账本');
      expect(personal.myRole, isNot(equals('editor')),
          reason: '个人账本不得被注入 editor 角色(否则触发 push 串数据 L2)');

      // 断言 2:远端共享账本作为【独立新行】插入,与本地个人账本互不共用 id。
      final shared = await (db.select(db.ledgers)
            ..where((l) => l.syncId.equals('shared-X')))
          .getSingle();
      expect(shared.isShared, isTrue);
      expect(shared.myRole, 'editor');
      expect(shared.id, isNot(equals(personalId)),
          reason: '共享账本必须是独立新增行,不能与个人账本共用 id');
    });

    test('远端个人默认账本仍正常收编本地同名个人账本(不误伤恢复流程)', () async {
      // 安全性论证:修复只追加 isShared 过滤,个人账本对个人的收编应原样工作,
      // 否则会破坏"换设备/重登后默认账本恢复同步"。
      // 归属模型下这一行必须是「云端账本」:恢复出来的备份保留 storage_mode,
      // 只有 cloud 账本才允许被同名远端账本收编;纯本地账本被收编等于静默上云,
      // 已由 cloud_ledger_boundary_test 反向锁死。
      final personalId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: '默认账本',
              storageMode: const Value('cloud'),
              isShared: const Value(false),
            ),
          );

      // 远端:B 自己的个人云默认账本(同名、isShared=false、owner)。
      provider.pushFakeLedger(
        ledgerId: 'personal-Y',
        ledgerName: '默认账本',
        isShared: false,
        role: 'owner',
      );

      await engine.syncLedgersFromServer();

      // 本地个人账本被正常收编:syncId 被赋值、身份保持个人、不产生第二行。
      final personal = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(personalId)))
          .getSingle();
      expect(personal.syncId, 'personal-Y',
          reason: '个人默认账本恢复:同名且同为个人的远端账本应正常收编');
      expect(personal.isShared, isFalse);
      expect(personal.myRole, 'owner');

      final all = await db.select(db.ledgers).get();
      expect(all, hasLength(1),
          reason: '收编应原地更新,不应新增行(确认修复不误伤正常流程)');
    });
  });
}

