import 'dart:convert';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 's3_client.dart';
import 's3_exceptions.dart';

/// S3 存储服务实现
class S3StorageService implements CloudStorageService {
  final S3Client client;
  final String bucket;

  S3StorageService(this.client, this.bucket);

  Future<void> deleteFile(String remotePath) async {
    try {
      await client.deleteObject(
        bucket: bucket,
        key: _normalizePath(remotePath),
      );
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to delete file: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to delete file: $e');
    }
  }

  Future<bool> fileExists(String remotePath) async {
    try {
      return await client.headObject(
            bucket: bucket,
            key: _normalizePath(remotePath),
          ) !=
          null;
    } on S3Exception catch (e) {
      throw CloudStorageException(
          'Failed to check file existence: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to check file existence: $e');
    }
  }

  Future<List<S3ObjectInfo>> listFiles(String remotePath) async {
    try {
      final prefix = _normalizePath(remotePath);
      return await client.listObjects(
        bucket: bucket,
        prefix: prefix.isEmpty ? null : prefix,
      );
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to list files: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to list files: $e');
    }
  }

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    try {
      // 将字符串数据转为字节
      final bytes = utf8.encode(data);

      // 上传到 S3，并把指纹等元数据写入 x-amz-meta-* 请求头，
      // 供 HEAD 真实读取，支撑核心包 getStatus 免下载判断。
      await client.putObject(
        bucket: bucket,
        key: _normalizePath(path),
        data: bytes,
        metadata: metadata,
      );
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to upload file: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to upload file: $e');
    }
  }

  @override
  Future<String?> download({required String path}) async {
    try {
      // 从 S3 下载
      final bytes = await client.getObject(
        bucket: bucket,
        key: _normalizePath(path),
      );

      // 将字节转为字符串
      return utf8.decode(bytes);
    } on S3ObjectNotFoundException {
      return null;
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to download file: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to download file: $e');
    }
  }

  @override
  Future<void> delete({required String path}) async {
    return deleteFile(path);
  }

  @override
  Future<bool> exists({required String path}) async {
    return fileExists(path);
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    final files = await listFiles(path);
    return files
        .map((info) => CloudFile(
              name: info.key,
              path: info.key,
              size: info.size,
              lastModified: info.lastModified,
            ))
        .toList();
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    try {
      // HEAD 返回真实 size / lastModified / 自定义元数据；
      // 只有 404 返回 null，鉴权 / 网络错误向上抛出。
      final head = await client.headObject(
        bucket: bucket,
        key: _normalizePath(path),
      );
      if (head == null) return null;

      return CloudFile(
        name: path.split('/').last,
        path: path,
        size: head.size,
        lastModified: head.lastModified,
        metadata: head.metadata,
      );
    } on S3Exception catch (e) {
      throw CloudStorageException('Failed to get metadata: ${e.message}');
    } catch (e) {
      throw CloudStorageException('Failed to get metadata: $e');
    }
  }

  /// 标准化路径：去除开头的斜杠，并拒绝路径穿越。
  ///
  /// S3 的 Key 不应该以 / 开头，也不得包含 `..` / `.` 段，
  /// 防止业务层误传越权路径。
  String _normalizePath(String path) {
    if (!PathHelper.isSafeRelativePath(path)) {
      throw CloudStorageException('Invalid path: $path');
    }
    return path;
  }
}
