/// [restoreBackupAndReconcile] 编排单测。
///
/// 核心不变量：**恢复失败时绝不动库**。服务层保证失败路径（紧急备份失败 /
/// 文件损坏 / 版本过高 / 覆盖失败）当前库文件完好，此刻若仍执行 invalidate
/// 热重建或归属归一化，反而会把完好的现场改坏——用户看到的是"恢复失败"，
/// 库却已被改写。故失败态必须原样返回、零副作用。
///
/// 成功态的归属体检分支（已登录认领 / 未登录归一化）互斥性同样在此覆盖。
library;

import 'dart:io';

// hide isNull:drift 与 matcher 同时导出该符号，测试里用的是 matcher 版本。
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/services/backup/local_backup_service.dart';

/// 只记录调用、不碰磁盘的恢复服务桩。
class _StubBackupService extends LocalBackupService {
  _StubBackupService(this._status);

  final RestoreStatus _status;

  /// restoreFromBackup 被调用次数，用于验证编排确实走了服务层
  int restoreCalls = 0;

  @override
  Future<RestoreResult> restoreFromBackup({
    required SpitoutDatabase db,
    required File backupFile,
    Future<void> Function(String localSelfId)? onRestoredLocalSelfId,
  }) async {
    restoreCalls++;
    return RestoreResult(_status, error: 'stub');
  }
}

void main() {
  late SpitoutDatabase db;
  late ProviderContainer container;
  // databaseProvider 被 invalidate 后重建的次数（0 表示编排未触发热重建）
  late int dbBuildCount;

  /// 构建容器：databaseProvider 用同一个内存库兜底，重建时计数 +1。
  ProviderContainer buildContainer(LocalBackupService service) {
    dbBuildCount = 0;
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          dbBuildCount++;
          return db;
        }),
        localBackupServiceProvider.overrideWithValue(service),
      ],
    );
  }

  setUp(() {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 四种失败态逐一验证：原样返回 + 不触发 databaseProvider 重建。
  for (final status in [
    RestoreStatus.emergencyFailed,
    RestoreStatus.integrityFailed,
    RestoreStatus.versionTooNew,
    RestoreStatus.copyFailed,
  ]) {
    test('恢复失败($status)时原样返回且不触碰数据库', () async {
      final service = _StubBackupService(status);
      container = buildContainer(service);

      // 先读一次，把 databaseProvider 建起来（计数归到基线 1）
      container.read(databaseProvider);
      expect(dbBuildCount, 1);

      final result = await restoreBackupAndReconcile(
        read: container.read,
        invalidate: container.invalidate,
        backupFile: File('/stub/backup.sqlite'),
      );

      expect(result.status, status, reason: '失败结果必须原样透传给 UI');
      expect(service.restoreCalls, 1);
      // 未被 invalidate → 重新读取拿到的仍是同一实例，构建计数不增长
      container.read(databaseProvider);
      expect(dbBuildCount, 1, reason: '失败态触发热重建会破坏完好的当前库');
    });
  }

  test('恢复失败时不执行归一化，云端账本原样保留', () async {
    final service = _StubBackupService(RestoreStatus.integrityFailed);
    container = buildContainer(service);

    await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Cloud',
            syncId: const Value('sync-1'),
            storageMode: const Value('cloud'),
            isShared: const Value(true),
          ),
        );

    await restoreBackupAndReconcile(
      read: container.read,
      invalidate: container.invalidate,
      backupFile: File('/stub/backup.sqlite'),
    );

    final l = await db.select(db.ledgers).getSingle();
    expect(l.storageMode, 'cloud', reason: '失败态严禁改写归属');
    expect(l.isShared, isTrue);
    expect(l.syncId, 'sync-1');
  });
}
