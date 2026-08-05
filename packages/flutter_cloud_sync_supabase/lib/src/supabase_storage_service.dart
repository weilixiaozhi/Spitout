library;

import 'dart:convert';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Supabase implementation of [CloudStorageService].
class SupabaseStorageService implements CloudStorageService {
  final supabase.SupabaseClient _client;
  final String _bucketName;
  final String? _pathPrefix;
  final CloudSyncLogger? _logger;

  SupabaseStorageService(
    this._client,
    this._bucketName, [
    this._pathPrefix,
    CloudSyncLogger? logger,
  ]) : _logger = logger;

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    try {
      // Check if user is authenticated
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build full path with user ID prefix
      final fullPath = _buildUserPath(user.id, path);

      // Upload file with metadata
      // Use UTF-8 encoding to properly handle multi-byte characters (e.g., Chinese)
      final bytes = utf8.encode(data);
      await _client.storage.from(_bucketName).uploadBinary(
            fullPath,
            bytes,
            fileOptions: const supabase.FileOptions(
              upsert: true,
              contentType: 'application/json',
              cacheControl: '3600',
            ),
          );

      // Store metadata separately if provided
      if (metadata != null && metadata.isNotEmpty) {
        await _storeMetadata(fullPath, metadata);
      }
    } on supabase.StorageException catch (e) {
      throw CloudStorageException('Upload failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Upload failed: $e', e);
    }
  }

  @override
  Future<String?> download({required String path}) async {
    try {
      // Check if user is authenticated
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build full path with user ID prefix
      final fullPath = _buildUserPath(user.id, path);

      // Download file
      final bytes = await _client.storage.from(_bucketName).download(fullPath);

      // Convert bytes to string using UTF-8 decoding
      return utf8.decode(bytes);
    } on supabase.StorageException catch (e) {
      // Return null if file not found
      if (e.statusCode == '404' || e.message.contains('not found')) {
        return null;
      }
      throw CloudStorageException('Download failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Download failed: $e', e);
    }
  }

  @override
  Future<void> delete({required String path}) async {
    try {
      // Check if user is authenticated
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build full path with user ID prefix
      final fullPath = _buildUserPath(user.id, path);

      // Delete file
      await _client.storage.from(_bucketName).remove([fullPath]);

      // Delete metadata
      await _deleteMetadata(fullPath);
    } on supabase.StorageException catch (e) {
      throw CloudStorageException('Delete failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Delete failed: $e', e);
    }
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    try {
      // Check if user is authenticated
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build full path with user ID prefix
      final fullPath = _buildUserPath(user.id, path);

      // List files
      final files = await _client.storage.from(_bucketName).list(
            path: fullPath,
          );

      // Convert to CloudFile objects
      return files
          .map((file) => CloudFile(
                name: file.name,
                path: '$fullPath/${file.name}',
                size: file.metadata?['size'] as int?,
                lastModified: file.updatedAt != null
                    ? DateTime.parse(file.updatedAt!)
                    : null,
                metadata: file.metadata,
              ))
          .toList();
    } on supabase.StorageException catch (e) {
      throw CloudStorageException('List failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('List failed: $e', e);
    }
  }

  @override
  Future<bool> exists({required String path}) async {
    try {
      // Check if user is authenticated
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build full path with user ID prefix
      final fullPath = _buildUserPath(user.id, path);

      // Try to get file info - if it doesn't throw, file exists
      final files = await _client.storage.from(_bucketName).list(
            path: PathHelper.dirname(fullPath),
          );

      final fileName = PathHelper.basename(fullPath);
      return files.any((file) => file.name == fileName);
    } on supabase.StorageException catch (e) {
      // If path not found, file doesn't exist
      if (e.statusCode == '404' || e.message.contains('not found')) {
        return false;
      }
      throw CloudStorageException('Exists check failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Exists check failed: $e', e);
    }
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    try {
      // Check if user is authenticated
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build full path with user ID prefix
      final fullPath = _buildUserPath(user.id, path);

      // Get file list to retrieve metadata
      final files = await _client.storage.from(_bucketName).list(
            path: PathHelper.dirname(fullPath),
          );

      final fileName = PathHelper.basename(fullPath);
      supabase.FileObject? file;
      for (final candidate in files) {
        if (candidate.name == fileName) {
          file = candidate;
          break;
        }
      }
      // 文件不存在属于正常情况，返回 null；不要包装成 CloudStorageException，
      // 否则调用方无法区分“无文件”与“元数据损坏”。
      if (file == null) return null;

      // Get stored custom metadata
      final customMetadata = await _getMetadata(fullPath);

      return CloudFile(
        name: file.name,
        path: fullPath,
        size: file.metadata?['size'] as int?,
        lastModified:
            file.updatedAt != null ? DateTime.parse(file.updatedAt!) : null,
        metadata: {
          ...?file.metadata,
          ...customMetadata,
        },
      );
    } on supabase.StorageException catch (e) {
      if (e.statusCode == '404' || e.message.contains('not found')) {
        return null;
      }
      throw CloudStorageException('Get metadata failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      if (e is CloudStorageException) rethrow;
      throw CloudStorageException('Get metadata failed: $e', e);
    }
  }

  /// Builds a user-specific path.
  ///
  /// If pathPrefix is provided, it will be used as the prefix (supports {userId} placeholder).
  /// Otherwise, defaults to 'users/{userId}/' for backward compatibility.
  String _buildUserPath(String userId, String path) {
    // 拒绝绝对路径与 .. 段，防止拼接用户前缀后逃逸到其他目录。
    if (!PathHelper.isSafeRelativePath(path)) {
      throw CloudStorageException('Invalid path: $path');
    }

    // If no prefix configured, use default 'users/{userId}/' pattern
    final prefix = _pathPrefix ?? 'users/{userId}';

    // Replace {userId} placeholder with actual user ID
    final expandedPrefix = prefix.replaceAll('{userId}', userId);

    // Join prefix with path
    return PathHelper.join([expandedPrefix, path]);
  }

  /// Stores custom metadata in a separate database table.
  /// Since Supabase Storage doesn't support custom metadata directly,
  /// we store it in a metadata table.
  Future<void> _storeMetadata(String path, Map<String, String> metadata) async {
    try {
      await _client.from('file_metadata').upsert({
        'path': path,
        'metadata': metadata,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // 元数据表缺失 / 权限不足会导致指纹等元数据永久缺失，
      // 必须记录 warning，避免静默吞错放大 getStatus 全量下载问题。
      _logger?.error('SupabaseStorageService 元数据写入失败（path=$path）: $e');
      // 元数据是同步状态判断的依据，写失败不能让上传“假装成功”。
      rethrow;
    }
  }

  /// Retrieves custom metadata from database.
  Future<Map<String, dynamic>> _getMetadata(String path) async {
    try {
      final response = await _client
          .from('file_metadata')
          .select('metadata')
          .eq('path', path)
          .maybeSingle();

      if (response == null) return {};

      return response['metadata'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      _logger?.error('SupabaseStorageService 元数据读取失败（path=$path）: $e');
      rethrow;
    }
  }

  /// Deletes custom metadata from database.
  Future<void> _deleteMetadata(String path) async {
    try {
      await _client.from('file_metadata').delete().eq('path', path);
    } catch (e) {
      _logger?.error('SupabaseStorageService 元数据删除失败（path=$path）: $e');
      rethrow;
    }
  }
}
