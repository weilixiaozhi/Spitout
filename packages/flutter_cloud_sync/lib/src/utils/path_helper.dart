import 'package:path/path.dart' as p;

/// 云存储路径工具：统一 POSIX 语义（云端对象 key 与宿主平台无关）。
///
/// 折叠斜杠、解析 . / .. 等复杂规则委托 package:path 的 posix context，
/// 本类只保留两条业务约定：对象 key 一律为无前导斜杠的相对路径，
/// 并对用户输入做路径穿越校验。
class PathHelper {
  /// 规范化云存储路径：折叠重复斜杠、解析 . 与 ..、去除首尾斜杠。
  ///
  /// 示例：
  /// ```dart
  /// PathHelper.normalize('//users/123/data.json/') // 'users/123/data.json'
  /// PathHelper.normalize('users//123///data.json') // 'users/123/data.json'
  /// ```
  static String normalize(String path) {
    if (path.isEmpty) return path;
    // posix.normalize 会保留前导斜杠；云对象 key 约定为相对路径，显式去除。
    return p.posix.normalize(path).replaceFirst(RegExp(r'^/+'), '');
  }

  /// 拼接多个路径段并规范化结果。
  static String join(List<String> segments) {
    if (segments.isEmpty) return '';
    return normalize(segments.join('/'));
  }

  /// 返回父目录；无父目录时返回空字符串。
  static String dirname(String path) {
    final normalized = normalize(path);
    if (normalized.isEmpty || !normalized.contains('/')) return '';
    return p.posix.dirname(normalized);
  }

  /// 返回路径的最后一个段。
  static String basename(String path) {
    return p.posix.basename(normalize(path));
  }

  /// 返回带点号的扩展名；无扩展名时返回空字符串。
  static String extension(String path) {
    return p.posix.extension(basename(path));
  }

  /// 在用户目录下构建路径。
  static String userPath(String userId, List<String> segments) {
    return join(['users', userId, ...segments]);
  }

  /// 是否为以 / 开头的绝对路径。
  static bool isAbsolute(String path) => p.posix.isAbsolute(path);

  /// 补前导斜杠成为绝对路径。
  static String makeAbsolute(String path) =>
      isAbsolute(path) ? path : '/$path';

  /// 移除前导斜杠成为相对路径。
  static String makeRelative(String path) => normalize(path);

  /// 校验业务层传入的相对路径是否安全。
  ///
  /// 拒绝绝对路径以及包含 `..` / `.` 段（或反斜杠分隔）的路径，
  /// 防止拼接用户前缀后逃逸到其他目录（路径穿越）。
  static bool isSafeRelativePath(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('/') || path.startsWith('\\')) return false;
    final segments = path.split(RegExp(r'[/\\]'));
    return !segments.any((segment) => segment == '..' || segment == '.');
  }
}
