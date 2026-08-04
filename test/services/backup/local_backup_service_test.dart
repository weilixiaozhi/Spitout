/// LocalBackupService 单元测试。
///
/// 用临时目录 + `SpitoutDatabase.forTesting(NativeDatabase(File))` 真实文件库，
/// 覆盖：快照生成、列表枚举、保留策略、恢复成功回滚、损坏/高版本拒绝、WAL 清理。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3, OpenMode;

import 'package:spitout/data/db.dart';
import 'package:spitout/services/backup/local_backup_service.dart';
import '../../helpers/test_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例重置 prefs mock / 平台 TestValue，消除跨用例残留
  setUp(() => resetGlobalTestState());

  late Directory tmp;
  late File dbFile;
  late Directory backupDir;
  late SpitoutDatabase db;
  late LocalBackupService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('local_backup_test_');
    dbFile = File(p.join(tmp.path, 'spitout.sqlite'));
    backupDir = Directory(p.join(tmp.path, 'backups'));
    // 真实文件库：备份/恢复本质是文件级操作，内存库无法覆盖 checkpoint 与复制路径
    db = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    service = LocalBackupService(backupDir: backupDir, databaseFile: dbFile);
  });

  tearDown(() async {
    // 恢复用例会手动 close 过连接，二次 close 容错
    try {
      await db.close();
    } catch (_) {}
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('createBackup 生成快照且数据完整（checkpoint 后单文件即全量）', () async {
    await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'food', kind: 'expense'));

    final backup = await service.createBackup(db: db);

    expect(await backup.exists(), isTrue);
    expect(p.basename(backup.path), startsWith(LocalBackupService.backupPrefix));
    expect(p.basename(backup.path), endsWith('.sqlite'));

    // 用独立只读连接打开备份文件，验证内容就是当前库数据
    final checkDb = sqlite3.open(backup.path, mode: OpenMode.readOnly);
    final rows = checkDb.select('SELECT name FROM categories');
    checkDb.close();
    expect(rows.map((r) => r['name']), contains('food'));
  });

  test('listBackups 仅列正式备份、过滤半截 tmp、按时间戳倒序', () async {
    await backupDir.create(recursive: true);
    for (final name in [
      'spitout_backup_20260701_090000.sqlite',
      'spitout_backup_20260703_090000.sqlite',
      'spitout_backup_20260702_090000.sqlite',
      // 紧急备份是系统回滚点，不应出现在用户恢复列表
      'spitout_emergency_20260704_090000.sqlite',
      // 原子写入半途的临时文件不应被当作可恢复快照
      'spitout_backup_20260705_090000.sqlite.tmp',
    ]) {
      await File(p.join(backupDir.path, name)).writeAsBytes([0]);
    }

    final list = await service.listBackups();

    expect(list.map((b) => b.fileName), [
      'spitout_backup_20260703_090000.sqlite',
      'spitout_backup_20260702_090000.sqlite',
      'spitout_backup_20260701_090000.sqlite',
    ]);
  });

  test('pruneBackups 正式保留10个/紧急保留3个，删最旧保最新', () async {
    await backupDir.create(recursive: true);
    for (var i = 1; i <= 12; i++) {
      final ts = '202607${i.toString().padLeft(2, '0')}_090000';
      await File(p.join(backupDir.path, 'spitout_backup_$ts.sqlite'))
          .writeAsBytes([0]);
    }
    for (var i = 1; i <= 5; i++) {
      final ts = '202607${i.toString().padLeft(2, '0')}_100000';
      await File(p.join(backupDir.path, 'spitout_emergency_$ts.sqlite'))
          .writeAsBytes([0]);
    }

    await service.pruneBackups();

    final remaining = (await backupDir.list().toList())
        .map((e) => p.basename(e.path))
        .toList();
    expect(remaining.where((n) => n.startsWith('spitout_backup_')).length, 10);
    expect(
        remaining.where((n) => n.startsWith('spitout_emergency_')).length, 3);
    // 最旧被删、最新保留
    expect(remaining.contains('spitout_backup_20260701_090000.sqlite'), isFalse);
    expect(remaining.contains('spitout_backup_20260712_090000.sqlite'), isTrue);
    expect(remaining.contains('spitout_emergency_20260701_100000.sqlite'),
        isFalse);
  });

  test('restoreFromBackup 成功：数据回到备份点、WAL无残留、生成紧急备份', () async {
    // 备份点：仅 food
    await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'food', kind: 'expense'));
    final backup = await service.createBackup(db: db);

    // 备份后变更：删 food、增 travel——恢复后这些变更应被回滚
    await db.delete(db.categories).go();
    await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'travel', kind: 'expense'));

    final result = await service.restoreFromBackup(db: db, backupFile: backup);
    expect(result.status, RestoreStatus.success);

    // 重新打开主库文件验证数据回滚
    final reopened = SpitoutDatabase.forTesting(NativeDatabase(dbFile));
    final names =
        (await reopened.select(reopened.categories).get()).map((c) => c.name);
    expect(names, contains('food'));
    expect(names, isNot(contains('travel')));
    await reopened.close();

    // 覆盖后 WAL/SHM 必须清理，否则旧事务可能被拼回新库造成错乱
    expect(await File('${dbFile.path}-wal').exists(), isFalse);
    expect(await File('${dbFile.path}-shm').exists(), isFalse);

    // 恢复前的当前库现场已被存为紧急备份（回滚点）
    final emergencyCount = (await backupDir.list().toList())
        .where((e) =>
            p.basename(e.path).startsWith(LocalBackupService.emergencyPrefix))
        .length;
    expect(emergencyCount, 1);
  });

  test('restoreFromBackup 拒绝损坏文件：中止且当前库保持可用', () async {
    await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'food', kind: 'expense'));
    await backupDir.create(recursive: true);
    final badFile =
        File(p.join(backupDir.path, 'spitout_backup_20260701_090000.sqlite'));
    await badFile.writeAsString('this is not a sqlite file');

    final result = await service.restoreFromBackup(db: db, backupFile: badFile);
    expect(result.status, RestoreStatus.integrityFailed);

    // 校验失败在第一步即中止：连接未关闭、数据未动，当前库仍可查询
    final names =
        (await db.select(db.categories).get()).map((c) => c.name);
    expect(names, contains('food'));
  });

  test('restoreFromBackup 拒绝更高版本备份（user_version 守卫）', () async {
    // 构造一个合法但来自"更新版本应用"的备份文件
    await backupDir.create(recursive: true);
    final futureFile =
        File(p.join(backupDir.path, 'spitout_backup_20260701_090000.sqlite'));
    final src = SpitoutDatabase.forTesting(NativeDatabase(futureFile));
    await src.customSelect('SELECT 1').get(); // 触发建库
    await src.customStatement('PRAGMA user_version = 999');
    await src.close();

    final result =
        await service.restoreFromBackup(db: db, backupFile: futureFile);
    expect(result.status, RestoreStatus.versionTooNew);
  });

  test('validateBackup 对不存在的文件返回 integrityFailed', () async {
    final status = await service.validateBackup(
        File(p.join(tmp.path, 'nope.sqlite')), db.schemaVersion);
    expect(status, RestoreStatus.integrityFailed);
  });

  test('todayString 输出本地时区 YYYY-MM-DD（按天去重基准）', () {
    expect(LocalBackupService.todayString(),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });
}
