import 'package:meta/meta.dart';

/// 云端存储中的文件。
@immutable
class CloudFile {
  /// 文件名。
  final String name;

  /// 完整文件路径。
  final String path;

  /// 文件大小（字节，可选）。
  final int? size;

  /// 最后修改时间（可选）。
  final DateTime? lastModified;

  /// 自定义元数据（可选）。
  ///
  /// 用于存放指纹、版本等信息。
  final Map<String, dynamic>? metadata;

  const CloudFile({
    required this.name,
    required this.path,
    this.size,
    this.lastModified,
    this.metadata,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudFile &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'CloudFile(name: $name, path: $path, size: $size)';
}

/// 云存储服务抽象接口。
abstract class CloudStorageService {
  /// 上传数据到云端存储。
  ///
  /// [path] - 文件路径（如 'users/123/data.json'）
  /// [data] - 文件内容字符串
  /// [metadata] - 可选元数据
  ///
  /// 上传失败时抛出 [CloudStorageException]。
  /// 文件已存在时将被覆盖（upsert 语义）。
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  });

  /// 从云端存储下载数据。
  ///
  /// [path] - 文件路径。
  ///
  /// 返回文件内容字符串；文件不存在时返回 null。
  /// 下载失败时抛出 [CloudStorageException]（404 除外）。
  Future<String?> download({required String path});

  /// 从云端存储删除文件。
  ///
  /// [path] - 文件路径。
  ///
  /// 删除失败时抛出 [CloudStorageException]。
  /// 应具备幂等性（文件不存在时不报错）。
  Future<void> delete({required String path});

  /// 列出目录下的文件。
  ///
  /// [path] - 目录路径（如 'users/123/'）。
  ///
  /// 返回目录内文件列表。
  /// 失败时抛出 [CloudStorageException]。
  Future<List<CloudFile>> list({required String path});

  /// 检查文件是否存在。
  ///
  /// [path] - 文件路径。
  ///
  /// 存在返回 true，否则返回 false。
  /// 失败时抛出 [CloudStorageException]。
  Future<bool> exists({required String path});

  /// 获取文件元数据。
  ///
  /// [path] - 文件路径。
  ///
  /// 返回文件元数据；文件不存在时返回 null。
  /// 失败时抛出 [CloudStorageException]。
  Future<CloudFile?> getMetadata({required String path});
}
