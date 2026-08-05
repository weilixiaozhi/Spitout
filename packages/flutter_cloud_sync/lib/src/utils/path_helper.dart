/// 云存储路径工具。
class PathHelper {
  /// 规范化云存储路径。
  ///
  /// - 移除开头斜杠
  /// - 合并重复斜杠
  /// - 移除结尾斜杠
  ///
  /// 示例：
  /// ```dart
  /// PathHelper.normalize('//users/123/data.json/') // 'users/123/data.json'
  /// PathHelper.normalize('users//123///data.json') // 'users/123/data.json'
  /// ```
  static String normalize(String path) {
    if (path.isEmpty) return path;

    // 移除开头斜杠
    path = path.replaceFirst(RegExp(r'^/+'), '');

    // 移除结尾斜杠
    path = path.replaceFirst(RegExp(r'/+$'), '');

    // 合并多个连续斜杠为单个
    path = path.replaceAll(RegExp(r'/+'), '/');

    return path;
  }

  /// 拼接多个路径段。
  ///
  /// 自动规范化结果。
  ///
  /// 示例：
  /// ```dart
  /// PathHelper.join('users', '123', 'data.json') // 'users/123/data.json'
  /// PathHelper.join('users/', '/123/', '/data.json') // 'users/123/data.json'
  /// ```
  static String join(List<String> segments) {
    if (segments.isEmpty) return '';
    return normalize(segments.join('/'));
  }

  /// 获取文件路径的目录部分。
  ///
  /// 返回父目录路径；无父目录时返回空字符串。
  ///
  /// 示例：
  /// ```dart
  /// PathHelper.dirname('users/123/data.json') // 'users/123'
  /// PathHelper.dirname('data.json') // ''
  /// ```
  static String dirname(String path) {
    path = normalize(path);
    if (path.isEmpty) return '';

    final lastSlashIndex = path.lastIndexOf('/');
    if (lastSlashIndex == -1) return '';

    return path.substring(0, lastSlashIndex);
  }

  /// 获取文件路径的文件名部分。
  ///
  /// 返回路径的最后一个段。
  ///
  /// 示例：
  /// ```dart
  /// PathHelper.basename('users/123/data.json') // 'data.json'
  /// PathHelper.basename('data.json') // 'data.json'
  /// ```
  static String basename(String path) {
    path = normalize(path);
    if (path.isEmpty) return '';

    final lastSlashIndex = path.lastIndexOf('/');
    if (lastSlashIndex == -1) return path;

    return path.substring(lastSlashIndex + 1);
  }

  /// 获取文件扩展名。
  ///
  /// 返回包含点号的扩展名；无扩展名时返回空字符串。
  ///
  /// 示例：
  /// ```dart
  /// PathHelper.extension('data.json') // '.json'
  /// PathHelper.extension('archive.tar.gz') // '.gz'
  /// PathHelper.extension('noextension') // ''
  /// ```
  static String extension(String path) {
    final filename = basename(path);
    final lastDotIndex = filename.lastIndexOf('.');

    if (lastDotIndex == -1 || lastDotIndex == 0) return '';
    return filename.substring(lastDotIndex);
  }

  /// 构建用户专属路径。
  ///
  /// 便捷方法：在用户目录下创建路径。
  ///
  /// 示例：
  /// ```dart
  /// PathHelper.userPath('user123', ['ledgers', '456.json'])
  /// // 'users/user123/ledgers/456.json'
  /// ```
  static String userPath(String userId, List<String> segments) {
    return join(['users', userId, ...segments]);
  }

  /// 判断路径是否为绝对路径（以 / 开头）。
  static bool isAbsolute(String path) {
    return path.startsWith('/');
  }

  /// 为路径添加开头斜杠，使其成为绝对路径。
  static String makeAbsolute(String path) {
    if (isAbsolute(path)) return path;
    return '/$path';
  }

  /// 移除开头斜杠，使路径成为相对路径。
  static String makeRelative(String path) {
    return normalize(path);
  }

  /// 校验业务层传入的相对路径是否安全。
  ///
  /// 拒绝绝对路径以及包含 `..` / `.` 段（或反斜杠分隔）的路径，
  /// 防止拼接用户前缀后逃逸到其他目录（路径穿越）。
  ///
  /// 示例：
  /// ```dart
  /// PathHelper.isSafeRelativePath('ledgers/123.json') // true
  /// PathHelper.isSafeRelativePath('/ledgers/123.json') // false
  /// PathHelper.isSafeRelativePath('../secret.json') // false
  /// ```
  static bool isSafeRelativePath(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('/') || path.startsWith('\\')) return false;
    final segments = path.split(RegExp(r'[/\\]'));
    return !segments.any((segment) => segment == '..' || segment == '.');
  }
}
