import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';

/// 纯本地模式同步服务的测试。
///
/// 覆盖目标：[LocalOnlySyncService] 的能力边界：
/// - 所有云同步能力（上传/下载/拉取/预览/远端删除/账本搬移）显式抛
///   [UnsupportedError]，明确区分"未配置"而非"网络错误"；
/// - getStatus 返回 notConfigured 且带 UI 层可识别的特殊标记；
/// - 唯一真正可用的能力是"删除账本"（本地行删除，需注入仓库解析器）；
/// - markLocalChanged/clearStatusCache 为空操作且可安全调用。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() async {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalOnlySyncService', () {
    test('getStatus 返回 notConfigured 与 UI 标记', () async {
      final service = LocalOnlySyncService();
      final status = await service.getStatus(ledgerId: 1);
      expect(status.diff, SyncDiff.notConfigured);
      expect(status.message, '__SYNC_NOT_CONFIGURED__');
    });

    test('所有云同步能力显式抛 UnsupportedError', () async {
      final service = LocalOnlySyncService();
      await expectLater(
        service.uploadCurrentLedger(ledgerId: 1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.downloadAndRestoreToCurrentLedger(ledgerId: 1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.pullIncremental(ledgerId: 1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.pullIncrementalWithHeal(ledgerId: 1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.refreshCloudFingerprint(ledgerId: 1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.deleteRemoteBackup(ledgerId: 1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.moveToCloud(1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.moveToLocal(1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.copyToLocal(1),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('markLocalChanged/clearStatusCache 是安全的空操作', () async {
      final service = LocalOnlySyncService();
      expect(() => service.markLocalChanged(ledgerId: 1), returnsNormally);
      expect(() => service.clearStatusCache(), returnsNormally);
    });

    test('未注入仓库时删除账本抛 UnsupportedError', () async {
      final service = LocalOnlySyncService();
      await expectLater(
        service.deleteLedgerGlobally(1),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('注入仓库后删除账本真实落库', () async {
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(name: '本地账本'),
          );
      final service = LocalOnlySyncService(repoResolver: () => repo);
      await service.deleteLedgerGlobally(ledgerId);
      final rows = await db.select(db.ledgers).get();
      expect(rows, isEmpty);
    });

    test('删除不存在账本不抛错（幂等）', () async {
      final service = LocalOnlySyncService(repoResolver: () => repo);
      await expectLater(service.deleteLedgerGlobally(999), completes);
    });
  });
}
