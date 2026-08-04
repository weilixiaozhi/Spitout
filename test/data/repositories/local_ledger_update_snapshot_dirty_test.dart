/// 快照型后端下 updateLedger 同步信号登记的单元测试。
///
/// updateLedger 必须与 createLedger 一样,在同一事务内把"账本元数据变更"
/// 落成同步信号,否则云端快照里的账本元数据永远是旧值,任何一次快照拉取
/// 都会把本地刚改的值覆盖回去(如 AA 开关"建完自动关闭"、改币种/起始日
/// 跨设备不同步)。
///
/// 覆盖三类后端组合:
///   1. 快照型后端(注入 SnapshotDirtyMarker):updateLedger 后快照脏标记
///      重新出现,等待整本快照重传;
///   2. Spitout Cloud 增量(注入 ChangeTracker,无 marker):syncId 为 null 的
///      本地账本不写 local_changes,保持"本地账本不上云"边界;
///   3. 全空参数调用:不触发空 UPDATE,也不登记任何同步信号。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/snapshot_dirty_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;

  Future<int> createLocalLedger() =>
      repo.createLedger(name: '快照本', storageMode: 'local');

  Future<List<dynamic>> dirtyRowsFor(int ledgerId) =>
      (db.select(db.snapshotDirtyLedgers)
            ..where((t) => t.ledgerId.equals(ledgerId)))
          .get();

  group('快照型后端:updateLedger 重新标脏整本快照', () {
    setUp(() {
      db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      repo = LocalRepository(
        db,
        snapshotDirtyMarker: SnapshotDirtyTracker(db),
      );
    });

    tearDown(() async => db.close());

    test('更新 AA 开关、起始日、名称、币种后,脏标记重新出现', () async {
      final id = await createLocalLedger();
      // 新建时已标记一次;模拟首次快照已上传消费,脏标记被清掉。
      await db.delete(db.snapshotDirtyLedgers).go();

      // updateLedger 支持的每个字段都验证一遍:任意一个变更漏标,云端快照
      // 就停留在旧元数据,下次拉取会把本地新值覆盖回去。
      await repo.updateLedger(id: id, aaEnabled: true);
      await repo.updateLedger(id: id, monthStartDay: 15);
      await repo.updateLedger(id: id, name: '改名后的账本');
      await repo.updateLedger(id: id, currency: 'USD');

      // marker 为 UPSERT 语义,重复标脏只留一行。
      final rows = await dirtyRowsFor(id);
      expect(rows, hasLength(1),
          reason: 'updateLedger 必须重新标记脏,否则整本快照不会重传');
    });

    test('全空参数调用不触发空 UPDATE,也不新增标脏', () async {
      final id = await createLocalLedger();
      await db.delete(db.snapshotDirtyLedgers).go();

      await repo.updateLedger(id: id);

      expect(await dirtyRowsFor(id), isEmpty,
          reason: '全空调用不登记任何同步信号');
      final row = await (db.select(db.ledgers)..where((l) => l.id.equals(id)))
          .getSingle();
      expect(row.name, '快照本', reason: '全空调用不应改变任何字段');
    });
  });

  group('Spitout Cloud 增量:本地账本不写 local_changes', () {
    setUp(() {
      db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      repo = LocalRepository(db, changeTracker: ChangeTracker(db));
    });

    tearDown(() async => db.close());

    test('syncId 为 null 的本地账本 updateLedger 不登记增量变更', () async {
      final id = await createLocalLedger();
      await repo.updateLedger(id: id, aaEnabled: true);

      final changes = await db.select(db.localChanges).get();
      expect(changes, isEmpty,
          reason: '本地账本属于这台设备,不参与云增量同步');
    });
  });
}
