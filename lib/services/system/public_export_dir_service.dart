import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/logging/logger_service.dart';

/// 公共导出目录解析结果。
class PublicExportDir {
  const PublicExportDir({
    required this.dir,
    required this.displayPath,
    required this.isPublicDownload,
  });

  /// 实际写入目录
  final Directory dir;

  /// 展示用路径：落在公共 Download 时为 `Download/Spitout[/子目录]`
  /// （与系统文件管理器所见一致）；降级目录时为完整绝对路径，如实告知用户。
  final String displayPath;

  /// 是否落在公共 Download；false 表示降级到应用专属外部目录
  /// （文件管理器不可见，且卸载 App 会被清除），UI 应据此提示用户。
  final bool isPublicDownload;
}

/// 公共导出目录解析服务：统一「写入公共 Download/Spitout」的目录决策。
///
/// 设计要点：
/// - Android 11+（API 30+）作用域存储下，写公共 Download 必须持有「所有文件访问」
///   （MANAGE_EXTERNAL_STORAGE）授权，否则 create/write 直接抛 errno 13；
///   本服务统一管理 `/storage/emulated/0/Download/Spitout` 的写入路径。
/// - 不做权限状态查询，采用**能力探测**（试建目录 + 试写探针文件）：权限 API 在
///   各版本上语义割裂（storage 权限 33+ 恒 granted、manageExternalStorage ≤29
///   恒 granted、30-32 上 manifest 未声明恒 denied），直接探测「能不能写」最可靠，
///   也无需为此引入 device_info 依赖。
/// - 探测失败降级到 `getExternalStorageDirectory()`（应用专属外部目录，无需任何
///   权限），保证导出/备份功能始终可用，由 [PublicExportDir.isPublicDownload]
///   标记供 UI 如实提示。
class PublicExportDirService {
  const PublicExportDirService();

  /// 公共 Download 下的应用专属子目录名
  static const String appDirName = 'Spitout';

  /// 解析导出写入目录。仅 Android 返回结果；其他平台返回 null
  /// （由调用方走各自平台分支，如 iOS 分享、文档目录等）。
  Future<PublicExportDir?> resolve({String? subDir}) async {
    if (!Platform.isAndroid) return null;

    // 1) 优先公共 Download/Spitout：用户文件管理器可见、卸载 App 不清理
    final publicDir = await _publicDownloadDir(subDir: subDir);
    if (publicDir != null && await _canWrite(publicDir)) {
      return PublicExportDir(
        dir: publicDir,
        displayPath: subDir == null
            ? 'Download/$appDirName'
            : 'Download/$appDirName/$subDir',
        isPublicDownload: true,
      );
    }

    // 2) 降级应用专属外部目录：无需任何权限，但卸载会被清除
    final extDir = await getExternalStorageDirectory();
    if (extDir == null) {
      // 外部存储整体不可用（如 SD 卡被卸载），返回 null 由调用方报错
      logger.error('PublicExportDir', '外部存储不可用，无法解析导出目录');
      return null;
    }
    final fallback =
        subDir == null ? extDir : Directory(p.join(extDir.path, subDir));
    await fallback.create(recursive: true);
    logger.warning(
        'PublicExportDir', '公共 Download 不可写，降级到应用专属目录: ${fallback.path}');
    return PublicExportDir(
      dir: fallback,
      displayPath: fallback.path,
      isPublicDownload: false,
    );
  }

  /// 枚举「可能存有历史导出文件」的候选目录（仅返回已存在的，供读取侧聚合）。
  ///
  /// 设计意图：「所有文件访问」授权可能被用户事后撤销，导致不同时期的文件
  /// 分别散落在公共目录与降级目录；只读当前 [resolve] 结果会让旧文件
  /// 「消失」（如恢复列表丢备份），故读取侧需聚合全部候选位置。
  Future<List<Directory>> candidateDirs({String? subDir}) async {
    if (!Platform.isAndroid) return [];
    final dirs = <Directory>[];
    // 公共目录优先：同名文件冲突时以公共目录版本为准
    final publicDir = await _publicDownloadDir(subDir: subDir);
    if (publicDir != null && await publicDir.exists()) dirs.add(publicDir);
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      final fallback =
          subDir == null ? extDir : Directory(p.join(extDir.path, subDir));
      if (await fallback.exists()) dirs.add(fallback);
    }
    return dirs;
  }

  /// 引导用户授予公共 Download 写权限。
  ///
  /// - API ≤ 29：弹系统旧式存储权限框（WRITE_EXTERNAL_STORAGE，Manifest 已声明）；
  /// - API 30+：跳系统「所有文件访问」设置页（permission_handler 在 ≤29 上
  ///   对 manageExternalStorage 恒 granted，不会误跳）。
  /// 用户从设置页返回后需重新 [resolve] 探测。
  Future<void> requestAccess() async {
    if (!Platform.isAndroid) return;
    try {
      await Permission.storage.request();
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    } catch (e, st) {
      // 权限流程异常不阻断主流程：调用方后续 resolve 会自然走降级目录
      logger.warning('PublicExportDir', '请求存储权限异常: $e', st);
    }
  }

  /// 推导公共 `Download/Spitout` 目录。
  ///
  /// 设计意图：不硬编码 `/storage/emulated/0`——借助 path_provider 返回的
  /// 应用专属外部目录（`<root>/Android/data/<pkg>/files`）反推外部存储根，
  /// 兼容多用户与厂商定制路径。
  Future<Directory?> _publicDownloadDir({String? subDir}) async {
    final extDir = await getExternalStorageDirectory();
    if (extDir == null) return null;
    final segments = p.split(extDir.path);
    final androidIdx = segments.indexOf('Android');
    // 路径形态异常（不含 Android/data 层级）时放弃公共目录，走降级
    if (androidIdx <= 0) return null;
    final root = p.joinAll(segments.sublist(0, androidIdx));
    return Directory(subDir == null
        ? p.join(root, 'Download', appDirName)
        : p.join(root, 'Download', appDirName, subDir));
  }

  /// 能力探测：目标目录是否真实可写（试建目录 + 试写探针文件后立即删除）。
  ///
  /// 注意：目录已存在时 `create` 不会抛异常，仅靠 create 无法区分
  /// 「已授权」与「目录早就存在但当前无写权限」，故必须试写文件验证。
  Future<bool> _canWrite(Directory dir) async {
    File? probe;
    try {
      await dir.create(recursive: true);
      probe = File(p.join(dir.path, '.spitout_probe'));
      await probe.writeAsBytes([0], flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      // 未授权时 create/write 抛 FileSystemException(errno 13)；
      // 探针删除失败残留无害（0 字节隐藏文件）
      try {
        if (probe != null && await probe.exists()) await probe.delete();
      } catch (_) {}
      return false;
    }
  }
}
