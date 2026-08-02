/// createLedger 变更登记单元测试（规则 4：同步由 local_changes 数据变更驱动）。
///
/// 验证核心不变量：
///   1. 云端账本(storage_mode='cloud')创建时,数据层自动向 local_changes
///      登记一条 ledger:upsert —— SyncCoordinator 由此感知新账本并触发同步,
///      UI 不再需要手动判断后端类型 / 手动触发（消除 mounted 竞态的根因）;
///   2. 纯本地账本(storage_mode='local')创建时不登记任何变更（不上云）;
///   3. 未注入 ChangeRecorder（非 Spitout Cloud 模式）时 createLedger 行为不变。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  group('createLedger 变更登记（Spitout Cloud 模式:注入 ChangeTracker）', () {
    late ChangeTracker tracker;
    late LocalRepository repo;

    setUp(() {
      tracker = ChangeTracker(db);
      repo = LocalRepository(db, changeTracker: tracker);
    });

    test('cloud 账本:创建后 local_changes 登记一条 ledger:upsert', () async {
      final id = await repo.createLedger(name: '云账本', storageMode: 'cloud');

      final changes = await tracker.getUnpushedChangesForLedger(id);
      expect(changes, hasLength(1),
          reason: '新建云端账本必须登记变更,SyncCoordinator 才能感知并自动同步');

      final change = changes.single;
      expect(change.entityType, 'ledger');
      expect(change.action, 'upsert');
      expect(change.entityId, id);
      expect(change.ledgerId, id, reason: 'ledger 是 ledger-scoped 实体,挂自身 id');

      // entitySyncId 必须与账本行的 syncId 一致,push 时才能对上云端实体。
      final ledger = await repo.getLedgerById(id);
      expect(ledger, isNotNull);
      expect(ledger!.syncId, isNotNull);
      expect(change.entitySyncId, ledger.syncId);
    });

    test('local 账本:创建后不登记任何变更(syncId 为 null,永不上云)', () async {
      final id = await repo.createLedger(name: '本地账本', storageMode: 'local');

      final changes = await tracker.getUnpushedChangesForLedger(id);
      expect(changes, isEmpty,
          reason: '本地账本 syncId 为 null,不应产生 local_changes 记录');

      final ledger = await repo.getLedgerById(id);
      expect(ledger!.syncId, isNull);
    });
  });

  group('createLedger 无 ChangeRecorder（快照后端 / 未登录模式）', () {
    test('不注入 tracker 时创建成功且 local_changes 为空', () async {
      final repo = LocalRepository(db); // changeTracker 缺省 null
      final id = await repo.createLedger(name: '普通账本', storageMode: 'cloud');

      final ledger = await repo.getLedgerById(id);
      expect(ledger, isNotNull);
      expect(ledger!.name, '普通账本');

      final rows = await db.select(db.localChanges).get();
      expect(rows, isEmpty, reason: '无 ChangeRecorder 时不应写 local_changes');
    });
  });
}
