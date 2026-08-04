import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/cloud/sync/snapshot_dirty_tracker.dart';
import 'package:spitout/data/db.dart';

import '../../helpers/test_isolation.dart';

/// 快照型后端脏账本标记器的测试。
///
/// 覆盖目标：[SnapshotDirtyTracker.markLedgerDirty] 的 INSERT OR IGNORE
/// 语义：标记账本后表内出现且仅出现一行；重复标记同一账本不会新增行
/// （"脏"是布尔语义，保留首次 dirtyAt）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late SnapshotDirtyTracker tracker;

  setUp(() async {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    tracker = SnapshotDirtyTracker(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('markLedgerDirty', () {
    test('标记后表内出现该账本行', () async {
      await tracker.markLedgerDirty(7);
      final rows = await db.select(db.snapshotDirtyLedgers).get();
      expect(rows, hasLength(1));
      expect(rows.single.ledgerId, 7);
      expect(rows.single.dirtyAt, isNotNull);
    });

    test('重复标记同一账本 → 仍只有一行', () async {
      await tracker.markLedgerDirty(7);
      await tracker.markLedgerDirty(7);
      final rows = await db.select(db.snapshotDirtyLedgers).get();
      expect(rows, hasLength(1));
      expect(rows.single.ledgerId, 7);
    });

    test('不同账本各自独立标记', () async {
      await tracker.markLedgerDirty(1);
      await tracker.markLedgerDirty(2);
      final rows = await db.select(db.snapshotDirtyLedgers).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.ledgerId).toSet(), {1, 2});
    });
  });
}
