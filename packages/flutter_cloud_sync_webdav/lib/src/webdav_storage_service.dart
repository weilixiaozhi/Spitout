library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// WebDAV implementation of [CloudStorageService].
class WebDAVStorageService implements CloudStorageService {
  final webdav.Client _client;
  final String _remotePath;

  WebDAVStorageService(this._client, this._remotePath);

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Ensure parent directories exist
      await _ensureDirectory(PathHelper.dirname(fullPath));

      // Convert string to bytes
      final bytes = utf8.encode(data);

      // Upload file
      await _client.write(fullPath, bytes);

      // Store metadata as custom properties if provided
      if (metadata != null && metadata.isNotEmpty) {
        await _storeMetadata(fullPath, metadata);
      }
    } catch (e) {
      throw CloudStorageException('Upload failed: $e', e);
    }
  }

  @override
  Future<String?> download({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Download file
      final bytes = await _client.read(fullPath);

      // Convert bytes to string
      return utf8.decode(bytes);
    } catch (e) {
      // 优先按 HTTP 状态码判断 404；无法取到状态码时再回退字符串匹配。
      if (_isNotFound(e)) {
        return null;
      }
      throw CloudStorageException('Download failed: $e', e);
    }
  }

  @override
  Future<void> delete({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Delete file
      await _client.remove(fullPath);

      // Delete metadata file if exists
      await _deleteMetadata(fullPath);
    } catch (e) {
      throw CloudStorageException('Delete failed: $e', e);
    }
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // List files
      final files = await _client.readDir(fullPath);

      // Convert to CloudFile objects, excluding directories and metadata files
      return files
          .where((file) =>
              !(file.isDir ?? true) &&
              !(file.name?.endsWith('.metadata.json') ?? false))
          .map((file) => CloudFile(
                name: file.name ?? '',
                path: file.path ?? fullPath,
                size: file.size,
                lastModified: file.mTime,
                metadata: const {},
              ))
          .toList();
    } catch (e) {
      throw CloudStorageException('List failed: $e', e);
    }
  }

  @override
  Future<bool> exists({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Check if file exists by trying to read its directory listing
      final parentDir = PathHelper.dirname(fullPath);
      final fileName = PathHelper.basename(fullPath);

      final files = await _client.readDir(parentDir);
      return files.any((f) => f.name == fileName);
    } catch (e) {
      // 目录不存在 / 文件不存在视为 false；鉴权等真实错误必须上抛。
      if (_isNotFound(e)) return false;
      throw CloudStorageException('Exists check failed: $e', e);
    }
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    try {
      // Build full path
      final fullPath = _buildPath(path);

      // Get file list to find the file
      final parentDir = PathHelper.dirname(fullPath);
      final fileName = PathHelper.basename(fullPath);

      final files = await _client.readDir(parentDir);
      final file = files.firstWhere(
        (f) => f.name == fileName,
        orElse: () => throw CloudStorageException('File not found: $path'),
      );

      // Try to load custom metadata
      final customMetadata = await _getMetadata(fullPath);

      return CloudFile(
        name: file.name!,
        path: file.path!,
        size: file.size,
        lastModified: file.mTime,
        metadata: customMetadata,
      );
    } catch (e) {
      if (_isNotFound(e) || e is CloudStorageException) {
        return null;
      }
      throw CloudStorageException('Get metadata failed: $e', e);
    }
  }

  /// Builds the full path with remote path prefix.
  String _buildPath(String path) {
    // 拒绝绝对路径与 .. 段，防止拼接 remotePath 后逃逸到其他目录。
    if (!PathHelper.isSafeRelativePath(path)) {
      throw CloudStorageException('Invalid path: $path');
    }
    return PathHelper.join([_remotePath, path]);
  }

  /// 判断异常是否为 404（优先取 HTTP 状态码，兜底字符串匹配）。
  bool _isNotFound(Object error) {
    final statusCode = _statusCodeOf(error);
    if (statusCode != null) return statusCode == 404;
    final text = error.toString().toLowerCase();
    return text.contains('404') || text.contains('not found');
  }

  /// 从 webdav_client 的异常（基于 dio）中读取状态码。
  ///
  /// 通过 dynamic 读取，避免本包直接依赖 dio。
  int? _statusCodeOf(Object error) {
    try {
      final response = (error as dynamic).response;
      if (response != null) {
        return (response as dynamic).statusCode as int?;
      }
    } catch (_) {
      // 非 dio 异常，返回 null 走字符串兜底。
    }
    return null;
  }

  /// Ensures a directory exists, creating it if necessary.
  Future<void> _ensureDirectory(String dirPath) async {
    try {
      await _client.readDir(dirPath);
      // If readDir succeeds, directory exists
      return;
    } catch (e) {
      // Directory doesn't exist, create it
      await _createDirectoryRecursively(dirPath);
    }
  }

  /// Creates a directory recursively.
  Future<void> _createDirectoryRecursively(String dirPath) async {
    final parts = dirPath.split('/').where((p) => p.isNotEmpty).toList();
    var currentPath = '';

    for (final part in parts) {
      currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
      try {
        await _client.readDir(currentPath);
        // Directory exists
      } catch (e) {
        // Directory doesn't exist, create it
        try {
          await _client.mkdir(currentPath);
        } catch (createError) {
          // Ignore error if directory was created by another process
        }
      }
    }
  }

  /// Stores custom metadata as a separate JSON file.
  Future<void> _storeMetadata(
      String filePath, Map<String, String> metadata) async {
    try {
      final metadataPath = '$filePath.metadata.json';
      final metadataJson = jsonEncode({
        'metadata': metadata,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      final bytes = utf8.encode(metadataJson);
      await _client.write(metadataPath, bytes);
    } catch (e) {
      // 指纹等元数据写入失败会导致 getStatus 信息缺失，必须可见。
      debugPrint('WebDAVStorageService 元数据写入失败（$filePath）: $e');
    }
  }

  /// Retrieves custom metadata from JSON file.
  Future<Map<String, dynamic>> _getMetadata(String filePath) async {
    try {
      final metadataPath = '$filePath.metadata.json';
      final bytes = await _client.read(metadataPath);
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return json['metadata'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      // 旧文件没有元数据文件是正常情况；其他错误（JSON 损坏等）需要可见。
      if (!_isNotFound(e)) {
        debugPrint('WebDAVStorageService 元数据读取失败（$filePath）: $e');
      }
      return {};
    }
  }

  /// Deletes custom metadata file.
  Future<void> _deleteMetadata(String filePath) async {
    try {
      final metadataPath = '$filePath.metadata.json';
      await _client.remove(metadataPath);
    } catch (e) {
      // 元数据文件不存在属于正常情况；其他错误需要可见。
      if (!_isNotFound(e)) {
        debugPrint('WebDAVStorageService 元数据删除失败（$filePath）: $e');
      }
    }
  }
}
