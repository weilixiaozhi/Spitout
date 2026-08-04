import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' as fcs;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/cloud/sync/transactions_sync_manager.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart' show SyncDiff;
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';

/// 账本交易云同步管理器的测试。
///
/// 覆盖目标：[TransactionsSyncManager] 在"云服务不可用"（provider 初始化
/// 失败，例如 SpitoutCloud 缺 baseUrl）时的全部降级分支：getStatus 返回
/// 未登录、上传/下载/预览/增量拉取/远端删除均抛 [fcs.CloudSyncException]、
/// 账本移动/复制抛 [UnsupportedError]，以及 clearStatusCache/markLocalChanged
/// 等轻量操作的幂等性。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late TransactionsSyncManager manager;

  setUp(() async {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    // SpitoutCloud 缺 baseUrl → config.valid == false → provider 创建失败
    manager = TransactionsSyncManager(
      config: fcs.CloudServiceConfig(
        type: fcs.CloudBackendType.spitoutCloud,
        name: '测试',
      ),
      db: db,
      repo: repo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('云服务不可用时的降级行为', () {
    test('getStatus 返回未登录状态', () async {
      final status = await manager.getStatus(ledgerId: 1);
      expect(status.diff, SyncDiff.notLoggedIn);
      expect(status.localCount, 0);
      expect(status.message, isNotNull);
    });

    test('uploadCurrentLedger 抛 CloudSyncException', () async {
      await expectLater(
        manager.uploadCurrentLedger(ledgerId: 1),
        throwsA(isA<fcs.CloudSyncException>()),
      );
    });

    test('downloadAndRestoreToCurrentLedger 抛 CloudSyncException', () async {
      await expectLater(
        manager.downloadAndRestoreToCurrentLedger(ledgerId: 1),
        throwsA(isA<fcs.CloudSyncException>()),
      );
    });

    test('downloadAndPreview 抛 CloudSyncException', () async {
      await expectLater(
        manager.downloadAndPreview(ledgerId: 1),
        throwsA(isA<fcs.CloudSyncException>()),
      );
    });

    test('pullIncremental 抛 CloudSyncException（退化快照下载）', () async {
      await expectLater(
        manager.pullIncremental(ledgerId: 1),
        throwsA(isA<fcs.CloudSyncException>()),
      );
    });

    test('pullIncrementalWithHeal 抛 CloudSyncException（委托 pull）', () async {
      await expectLater(
        manager.pullIncrementalWithHeal(ledgerId: 1),
        throwsA(isA<fcs.CloudSyncException>()),
      );
    });

    test('deleteRemoteBackup 抛 CloudSyncException', () async {
      await expectLater(
        manager.deleteRemoteBackup(ledgerId: 1),
        throwsA(isA<fcs.CloudSyncException>()),
      );
    });

    test('deleteLedgerGlobally 在远端删除失败时中断', () async {
      // 远端删不掉 → 本地账本不能被删（防止云端残留复活）
      await expectLater(
        manager.deleteLedgerGlobally(1),
        throwsA(isA<fcs.CloudSyncException>()),
      );
    });

    test('moveToCloud/moveToLocal/copyToLocal 抛 UnsupportedError', () async {
      await expectLater(
        manager.moveToCloud(1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        manager.moveToLocal(1),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        manager.copyToLocal(1),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('clearStatusCache 与 markLocalChanged 可安全调用', () async {
      expect(() => manager.clearStatusCache(), returnsNormally);
      expect(() => manager.markLocalChanged(ledgerId: 1), returnsNormally);
      // 状态缓存被清理后，getStatus 仍走"未登录"降级
      final status = await manager.getStatus(ledgerId: 1);
      expect(status.diff, SyncDiff.notLoggedIn);
    });

    test('refreshCloudFingerprint 返回全空元组（失败降级）', () async {
      final result = await manager.refreshCloudFingerprint(ledgerId: 1);
      expect(result.fingerprint, isNull);
      expect(result.count, isNull);
      expect(result.exportedAt, isNull);
    });

    test('refreshAllLedgersStatus 空账本不抛错', () async {
      await expectLater(
        manager.refreshAllLedgersStatus(),
        completes,
      );
    });
  });
}
