import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3, OpenMode, Database;

import '../../data/db.dart';
import '../../core/logging/logger_service.dart';
import '../system/public_export_dir_service.dart';

/// 单个本地备份文件信息（供恢复列表展示）。
class LocalBackupFile {
  const LocalBackupFile({
    required this.file,
    required this.createdAt,
    required this.sizeBytes,
  });

  /// 备份文件本体
  final File file;

  /// 备份创建时间（优先解析自文件名时间戳，失败回退文件修改时间）
  final DateTime createdAt;

  /// 文件大小（字节）
  final int sizeBytes;

  /// 文件名（含扩展名）
  String get fileName => p.basename(file.path);

  /// 人类可读大小（KB/MB），供列表副标题展示
  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
}

/// 恢复执行结果状态。
///
/// 设计意图：恢复是覆盖性不可逆操作，每种失败都对应独立的用户文案与善后策略
/// （紧急备份失败/文件损坏/版本过高均不触碰当前库），故用枚举而非 bool 返回。
enum RestoreStatus {
  /// 覆盖成功，调用方负责 invalidate databaseProvider 热重建
  success,

  /// 恢复前的紧急备份（回滚点）创建失败，已中止，当前库未动
  emergencyFailed,

  /// 备份文件损坏或不是合法 sqlite，已中止，当前库未动
  integrityFailed,

  /// 备份由更新版本应用创建（user_version 更高），已中止，当前库未动
  versionTooNew,

  /// 覆盖复制阶段失败（tmp 未 rename，原库完整）
  copyFailed,
}

/// 恢复执行结果。
class RestoreResult {
  const RestoreResult(this.status, {this.error});

  /// 结果状态
  final RestoreStatus status;

  /// 底层异常（仅记日志用，不向用户展示原始错误）
  final Object? error;

  /// 是否成功
  bool get success => status == RestoreStatus.success;
}

/// 自动本地备份服务：把数据库以"文件快照"形式备份到本地磁盘，并提供枚举与恢复能力。
///
/// 设计要点：
/// - 不依赖任何 Riverpod provider，构造时可注入 [backupDir] / [databaseFile] 覆盖，
///   使单元测试可用临时目录 + `SpitoutDatabase.forTesting` 完整覆盖文件级逻辑；
///   生产环境通过 `localBackupServiceProvider` 以默认构造使用。
/// - 备份前执行 `PRAGMA wal_checkpoint(TRUNCATE)` 把 WAL 合并进主库，
///   使"复制单个 .sqlite"即为完整数据。
/// - 一切写盘均走"临时文件 + rename"原子落盘，杜绝半截文件被恢复流程误读。
class LocalBackupService {
  LocalBackupService({Directory? backupDir, File? databaseFile})
      : _backupDirOverride = backupDir,
        _dbFileOverride = databaseFile;

  final Directory? _backupDirOverride;
  final File? _dbFileOverride;

  /// SharedPreferences key：自动备份开关（默认 true，零干预兜底）
  static const String prefsKeyAutoBackup = 'auto_backup';

  /// SharedPreferences key：上次备份日期（本地时区 YYYY-MM-DD，按天去重）
  static const String prefsKeyLastBackupDate = 'last_backup_date';

  /// 正式备份保留数量
  static const int maxBackups = 10;

  /// 紧急备份保留数量（恢复前的回滚点，独立保留、不进恢复列表）
  static const int maxEmergencyBackups = 3;

  /// 正式备份文件名前缀
  static const String backupPrefix = 'spitout_backup_';

  /// 紧急备份文件名前缀
  static const String emergencyPrefix = 'spitout_emergency_';

  // 防重入锁：备份/恢复各自单飞。自动触发与手动点击并发时，后到者直接失败返回，
  // 避免两个复制任务交叉写同一目录（参照 sync_providers 的 _autoSyncInProgress 模式）。
  static bool _backupInProgress = false;
  static bool _restoreInProgress = false;

  /// 今天日期串（本地时区 YYYY-MM-DD），按天去重的比较基准
  static String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 文件名时间戳（YYYYMMDD_HHMMSS），字典序即时间序，天然支持排序与 prune
  static String formatTimestamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// 解析备份写入目录。
  ///
  /// Android 经 [PublicExportDirService] 解析：已授权「所有文件访问」时落在公共
  /// `Download/Spitout/backups/`（用户文件管理器可见、卸载 App 不清理）；未授权
  /// 自动降级到应用专属外部目录（保证备份不中断）；外部存储整体不可用时退回应用
  /// 文档目录兜底。其他平台固定在应用文档目录 `backups/`。
  Future<Directory> backupDirectory() async {
    if (_backupDirOverride != null) {
      if (!await _backupDirOverride.exists()) {
        await _backupDirOverride.create(recursive: true);
      }
      return _backupDirOverride;
    }
    late final Directory dir;
    if (Platform.isAndroid) {
      final resolved =
          await const PublicExportDirService().resolve(subDir: 'backups');
      if (resolved != null) {
        dir = resolved.dir;
      } else {
        // 外部存储整体不可用（如 SD 卡被卸载）：退回应用文档目录，保证备份能力不丢
        final docs = await getApplicationDocumentsDirectory();
        dir = Directory(p.join(docs.path, 'backups'));
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(docs.path, 'backups'));
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 枚举历史备份可能散落的所有候选目录（仅返回已存在的，不做创建副作用）。
  ///
  /// 设计意图：「所有文件访问」授权可能被用户事后撤销，导致不同时期的备份
  /// 分别落在公共 Download 与应用专属降级目录；读取/清理侧若只看当前写入目录，
  /// 旧备份会从恢复列表「消失」，故必须聚合全部候选位置。
  Future<List<Directory>> _candidateReadDirs() async {
    if (_backupDirOverride != null) {
      return await _backupDirOverride.exists() ? [_backupDirOverride] : [];
    }
    if (Platform.isAndroid) {
      return const PublicExportDirService().candidateDirs(subDir: 'backups');
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    return await dir.exists() ? [dir] : [];
  }

  /// 列出所有候选目录中匹配 [prefix] 的 `.sqlite` 文件（按文件名时间戳倒序）。
  ///
  /// 同名文件在公共目录与降级目录可能各存一份（授权状态切换期产生），内容本是
  /// 同库快照，按文件名去重、保留先出现者（候选顺序公共目录优先）。
  Future<List<File>> _listBackupFiles(String prefix) async {
    final files = <File>[];
    final seenNames = <String>{};
    for (final dir in await _candidateReadDirs()) {
      final entries = await dir
          .list()
          .where((e) =>
              e is File &&
              p.basename(e.path).startsWith(prefix) &&
              e.path.endsWith('.sqlite'))
          .cast<File>()
          .toList();
      for (final f in entries) {
        if (seenNames.add(p.basename(f.path))) files.add(f);
      }
    }
    // 文件名时间戳字典序即时间序，倒序取最新在前
    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files;
  }

  /// 解析数据库主文件路径（与 `db.dart` 的 `_openConnection` 同一路径公式）。
  Future<File> databaseFile() async {
    if (_dbFileOverride != null) return _dbFileOverride;
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, 'spitout.sqlite'));
  }

  /// 执行一次备份：checkpoint 合并 WAL → 原子复制到备份目录 → prune 超量旧备份。
  ///
  /// [filePrefix] 默认正式备份前缀；恢复流程传 [emergencyPrefix] 生成回滚点。
  /// 返回生成的备份文件。并发调用时后到者抛 [StateError]（由调用方决定忽略或提示）。
  Future<File> createBackup({
    required SpitoutDatabase db,
    String filePrefix = backupPrefix,
  }) async {
    if (_backupInProgress) {
      throw StateError('backup already in progress');
    }
    _backupInProgress = true;
    try {
      final dbFile = await databaseFile();
      final dir = await backupDirectory();

      // 把 WAL 合并进主库，使单文件复制即为完整数据。
      // 失败仅降级（快照略旧）不阻断——复制出的主库仍是合法库。
      try {
        await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (e, st) {
        logger.warning('LocalBackup', 'wal_checkpoint 失败，继续复制（数据可能略旧）: $e', st);
      }

      final name = '$filePrefix${formatTimestamp(DateTime.now())}.sqlite';
      final target = File(p.join(dir.path, name));
      await _copyAtomic(dbFile, target);
      logger.info('LocalBackup', '备份完成: ${target.path}');
      await pruneBackups();
      return target;
    } finally {
      _backupInProgress = false;
    }
  }

  /// 枚举恢复列表：仅正式备份（[backupPrefix]），按时间戳倒序。
  ///
  /// 紧急备份（回滚点）刻意不展示——它是系统内部安全网，混进列表会让用户
  /// 分不清"我的快照"与"恢复前自动存的现场"。目录不可读时返回空列表（降级为无备份态）。
  Future<List<LocalBackupFile>> listBackups() async {
    try {
      // 聚合全部候选目录：授权状态切换期产生的散落备份不应从列表消失
      final files = await _listBackupFiles(backupPrefix);
      return [
        for (final f in files)
          LocalBackupFile(
            file: f,
            createdAt:
                _parseTimestamp(p.basename(f.path)) ?? await f.lastModified(),
            sizeBytes: await f.length(),
          ),
      ];
    } catch (e, st) {
      logger.error('LocalBackup', '枚举备份列表失败', e, st);
      return [];
    }
  }

  /// 清理超量旧备份：正式备份保留最近 [maxBackups] 个，紧急备份保留最近 [maxEmergencyBackups] 个。
  Future<void> pruneBackups() async {
    await _pruneByPrefix(backupPrefix, maxBackups);
    await _pruneByPrefix(emergencyPrefix, maxEmergencyBackups);
  }

  /// 从备份恢复：校验 → 紧急备份当前库 → 关闭连接 → 原子覆盖 → 清理 WAL 残留。
  ///
  /// 成功返回 [RestoreStatus.success] 后，**调用方负责 `ref.invalidate(databaseProvider)`**
  /// 触发级联热重建（本服务不感知 Riverpod）。所有失败路径都不破坏当前库：
  /// 校验/紧急备份失败直接中止；覆盖阶段走 tmp+rename，半途失败原库文件完整。
  Future<RestoreResult> restoreFromBackup({
    required SpitoutDatabase db,
    required File backupFile,
  }) async {
    if (_restoreInProgress) {
      return const RestoreResult(RestoreStatus.copyFailed,
          error: 'restore already in progress');
    }
    _restoreInProgress = true;
    try {
      // 1. 完整性 + 版本校验（独立于当前连接，失败零成本）
      final check = await validateBackup(backupFile, db.schemaVersion);
      if (check != null) return RestoreResult(check);

      // 2. 紧急备份当前库（回滚点）：恢复不可逆，先留"恢复前状态"才能在误操作时救回。
      //    失败则中止恢复——没有回滚点的覆盖操作对记账 App 不可接受。
      try {
        await createBackup(db: db, filePrefix: emergencyPrefix);
      } catch (e, st) {
        logger.error('LocalBackup', '恢复前紧急备份失败，已中止恢复', e, st);
        return RestoreResult(RestoreStatus.emergencyFailed, error: e);
      }

      // 3. 关闭当前 Drift 连接释放文件锁（不关闭则覆盖会被系统拒绝）。
      //    已关闭/半关闭状态容错，不阻断后续文件替换。
      try {
        await db.close();
      } catch (e, st) {
        logger.warning('LocalBackup', '关闭数据库连接异常（继续覆盖）: $e', st);
      }

      // 4. 原子覆盖主库 + 清理 WAL/SHM 残留。
      //    残留旧 WAL 会在下次打开时被错误拼回新库，造成数据错乱，必须删除。
      try {
        final dbFile = await databaseFile();
        await _copyAtomic(backupFile, dbFile);
        for (final suffix in ['-wal', '-shm']) {
          final f = File('${dbFile.path}$suffix');
          if (await f.exists()) await f.delete();
        }
      } catch (e, st) {
        logger.error('LocalBackup', '覆盖数据库文件失败', e, st);
        return RestoreResult(RestoreStatus.copyFailed, error: e);
      }

      logger.info('LocalBackup', '恢复完成: ${backupFile.path}');
      return const RestoreResult(RestoreStatus.success);
    } finally {
      _restoreInProgress = false;
    }
  }

  /// 校验备份文件可用性：sqlite 完整性 + schema 版本不高于当前应用。
  ///
  /// 通过返回 null；失败返回对应 [RestoreStatus]。
  /// 用 sqlite3 包以**只读模式**直接执行 PRAGMA——避免在备份目录产生
  /// -wal/-shm 副作用文件，也绕开 drift 裸 executor 需内部接口才能打开的坑。
  Future<RestoreStatus?> validateBackup(
      File backupFile, int currentSchemaVersion) async {
    if (!await backupFile.exists()) return RestoreStatus.integrityFailed;
    Database? database;
    try {
      database = sqlite3.open(backupFile.path, mode: OpenMode.readOnly);
      // integrity_check 单行为 'ok' 才是完好库；损坏文件此处直接抛异常进 catch
      final rows = database.select('PRAGMA integrity_check');
      final ok =
          rows.length == 1 && rows.first.values.first?.toString() == 'ok';
      if (!ok) return RestoreStatus.integrityFailed;

      // 版本守卫：备份来自更新版本应用时 Drift 打开即炸（无向下迁移路径），提前拦截
      final versionRows = database.select('PRAGMA user_version');
      final version = (versionRows.first.values.first as int?) ?? 0;
      if (version > currentSchemaVersion) return RestoreStatus.versionTooNew;
      return null;
    } catch (e, st) {
      logger.error('LocalBackup', '备份文件校验失败', e, st);
      return RestoreStatus.integrityFailed;
    } finally {
      database?.dispose();
    }
  }

  /// 原子复制：先写临时文件，再删目标、rename，保证"要么整体替换成功，要么原文件不动"
  Future<void> _copyAtomic(File source, File target) async {
    final tmp = File('${target.path}.tmp');
    await source.copy(tmp.path);
    if (await target.exists()) await target.delete();
    await tmp.rename(target.path);
  }

  /// 按前缀清理超量备份文件（跨全部候选目录聚合后，全局保留最近 keep 个）
  Future<void> _pruneByPrefix(String prefix, int keep) async {
    try {
      final files = await _listBackupFiles(prefix);
      if (files.length <= keep) return;
      for (final old in files.skip(keep)) {
        try {
          await old.delete();
          logger.info('LocalBackup', '已清理旧备份: ${old.path}');
        } catch (e) {
          logger.warning('LocalBackup', '删除旧备份失败: ${old.path}: $e');
        }
      }
    } catch (e, st) {
      // 清理失败不阻断主流程（最坏结果是多占一点磁盘）
      logger.warning('LocalBackup', 'prune 备份失败: $e', st);
    }
  }

  /// 从文件名解析时间戳（`spitout_backup_YYYYMMDD_HHMMSS.sqlite`），失败返回 null
  DateTime? _parseTimestamp(String fileName) {
    final match =
        RegExp(r'_(\d{8})_(\d{6})\.sqlite$').firstMatch(fileName);
    if (match == null) return null;
    final d = match.group(1)!;
    final t = match.group(2)!;
    return DateTime(
      int.parse(d.substring(0, 4)),
      int.parse(d.substring(4, 6)),
      int.parse(d.substring(6, 8)),
      int.parse(t.substring(0, 2)),
      int.parse(t.substring(2, 4)),
      int.parse(t.substring(4, 6)),
    );
  }
}
