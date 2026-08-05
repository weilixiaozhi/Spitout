import 'dart:convert';

import '../core/cloud_provider.dart';
import '../core/data_serializer.dart';
import '../core/exceptions.dart';
import '../core/sync_status.dart';
import '../utils/logger.dart';

/// 同步状态缓存条目。
class _CachedStatus {
  final SyncStatus status;
  final DateTime cachedAt;

  _CachedStatus(this.status, this.cachedAt);

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

/// 云同步管理器。
///
/// 编排本地与云端之间的同步操作（上传 / 下载 / 状态查询 / 删除）。
/// 泛型 [T] 表示业务数据类型（例如账本 ID）。
///
/// 示例：
/// ```dart
/// final manager = CloudSyncManager<int>(
///   provider: supabaseProvider,
///   serializer: LedgerDataSerializer(db),
///   logger: CloudSyncLogger(onLog: (level, msg) => print('[$level] $msg')),
/// );
///
/// // 上传本地数据到云端
/// await manager.upload(data: 123, path: 'ledgers/123.json');
///
/// // 查询同步状态
/// final status = await manager.getStatus(data: 123, path: 'ledgers/123.json');
/// ```
class CloudSyncManager<T> {
  /// 云服务提供方。
  final CloudProvider provider;

  /// 业务数据序列化器。
  final DataSerializer<T> serializer;

  /// 日志器（可注入）。
  final CloudSyncLogger? logger;

  /// 状态缓存有效期（TTL）。
  final Duration cacheTTL;

  /// 状态缓存上限，防止多账号 × 多路径下无限增长。
  static const int _maxCacheEntries = 64;

  /// 内部状态缓存。
  ///
  /// key 为 `userId|path`：账号切换后不会命中上一账号的缓存；
  /// 使用 LinkedHashMap 保持插入顺序，便于超限时淘汰最久未更新的条目。
  // Dart 默认 Map 字面量即 LinkedHashMap，可保持插入顺序用于 LRU 淘汰。
  final Map<String, _CachedStatus> _statusCache = {};

  /// 最近一次查询所属用户，用于账号切换时整体清空旧缓存。
  String? _lastUserId;

  /// 创建云同步管理器。
  ///
  /// [provider] - 云服务提供方（Supabase、WebDAV 等）
  /// [serializer] - 业务数据序列化器
  /// [logger] - 可选日志器
  /// [cacheTTL] - 状态缓存有效期（默认 30 秒）
  CloudSyncManager({
    required this.provider,
    required this.serializer,
    this.logger,
    this.cacheTTL = const Duration(seconds: 30),
  });

  /// 上传本地数据到云端。
  ///
  /// [data] - 业务数据
  /// [path] - 云端存储路径（例如 'ledgers/123.json'）
  /// [metadata] - 附加元数据
  ///
  /// 抛出 [CloudNotAuthenticatedException]（未登录）、
  /// [CloudSerializationException]（序列化阶段失败）或
  /// [CloudStorageException]（存储失败）。
  ///
  /// 示例：
  /// ```dart
  /// await manager.upload(
  ///   data: 123,
  ///   path: 'ledgers/123.json',
  ///   metadata: {'version': '1.0'},
  /// );
  /// ```
  Future<void> upload({
    required T data,
    required String path,
    Map<String, String>? metadata,
  }) async {
    logger?.info('开始上传: $path');

    // 1. 检查登录态。
    final user = await provider.auth.currentUser;
    if (user == null) {
      logger?.error('上传失败：用户未登录');
      throw CloudNotAuthenticatedException();
    }

    // 2. 序列化与指纹属于数据准备阶段，失败按序列化异常抛出，便于上层区分。
    final String serializedData;
    try {
      serializedData = await serializer.serialize(data);
    } catch (e) {
      logger?.error('上传失败：数据序列化错误: $e');
      throw CloudSerializationException('Failed to serialize data', e);
    }
    logger?.debug('数据序列化完成: ${serializedData.length} bytes');

    final String fingerprint;
    try {
      fingerprint = serializer.fingerprint(serializedData);
    } catch (e) {
      logger?.error('上传失败：指纹计算错误: $e');
      throw CloudSerializationException('Failed to compute fingerprint', e);
    }
    logger?.debug('指纹: $fingerprint');

    // 3. 准备元数据：指纹 + 上传时间 + 用户 + 载荷摘要，
    //    后续 getStatus 可直接用 metadata 判断，无需全量下载。
    final summary = _extractPayloadSummary(serializedData);
    final fullMetadata = <String, String>{
      'fingerprint': fingerprint,
      'uploadedAt': DateTime.now().toIso8601String(),
      'userId': user.id,
      if (summary.count != null) 'count': '${summary.count}',
      if (summary.exportedAt != null)
        'exportedAt': summary.exportedAt!.toIso8601String(),
      ...?metadata,
    };

    // 4. 上传到云端存储。
    try {
      await provider.storage.upload(
        path: path,
        data: serializedData,
        metadata: fullMetadata,
      );
    } catch (e) {
      logger?.error('上传失败: $e');
      if (e is CloudSyncException) {
        rethrow;
      }
      throw CloudStorageException('Upload failed', e);
    }

    // 5. 使当前用户的该路径缓存失效。
    _statusCache.remove(_cacheKey(path, user.id));
    logger?.info('上传完成: $path');
  }

  /// 从云端下载数据。
  ///
  /// [path] - 云端存储路径。
  ///
  /// 返回反序列化后的业务数据；文件不存在时返回 null。
  /// 抛出 [CloudNotAuthenticatedException]（未登录）、
  /// [CloudSerializationException]（反序列化失败）或
  /// [CloudStorageException]（存储失败）。
  ///
  /// 示例：
  /// ```dart
  /// final ledgerId = await manager.download(path: 'ledgers/123.json');
  /// if (ledgerId != null) {
  ///   // 处理下载到的数据
  /// }
  /// ```
  Future<T?> download({required String path}) async {
    logger?.info('开始下载: $path');

    // 1. 检查登录态。
    final user = await provider.auth.currentUser;
    if (user == null) {
      logger?.error('下载失败：用户未登录');
      throw CloudNotAuthenticatedException();
    }

    // 2. 从云端下载。
    final String? serializedData;
    try {
      serializedData = await provider.storage.download(path: path);
    } catch (e) {
      logger?.error('下载失败: $e');
      if (e is CloudSyncException) {
        rethrow;
      }
      throw CloudStorageException('Download failed', e);
    }

    if (serializedData == null) {
      logger?.info('下载完成：文件不存在');
      return null;
    }
    logger?.debug('数据下载完成: ${serializedData.length} bytes');

    // 3. 反序列化失败属于数据格式问题，与存储失败区分开。
    final T data;
    try {
      data = await serializer.deserialize(serializedData);
    } catch (e) {
      logger?.error('下载失败：数据反序列化错误: $e');
      throw CloudSerializationException('Failed to deserialize data', e);
    }

    // 4. 使当前用户的该路径缓存失效。
    _statusCache.remove(_cacheKey(path, user.id));
    logger?.info('下载完成: $path');
    return data;
  }

  /// 获取同步状态。
  ///
  /// [data] - 本地业务数据（用于指纹比较；缺省时无法判断同步关系）
  /// [path] - 云端存储路径
  /// [localUpdatedAt] - 本地数据更新时间（可选，用于方向判断）
  /// [forceRefresh] - 绕过缓存强制刷新
  ///
  /// 返回 [SyncStatus]。
  ///
  /// 示例：
  /// ```dart
  /// final status = await manager.getStatus(
  ///   data: 123,
  ///   path: 'ledgers/123.json',
  ///   localUpdatedAt: DateTime.now(),
  /// );
  ///
  /// if (status.isLocalNewer) {
  ///   // 显示「上传」按钮
  /// } else if (status.isCloudNewer) {
  ///   // 显示「下载」按钮
  /// }
  /// ```
  Future<SyncStatus> getStatus({
    T? data,
    required String path,
    DateTime? localUpdatedAt,
    bool forceRefresh = false,
  }) async {
    logger?.debug('获取同步状态: $path (forceRefresh: $forceRefresh)');

    // 1. 先取用户：缓存按用户隔离，登录 / 切换账号后旧缓存立即失效。
    final user = await provider.auth.currentUser;
    if (user == null) {
      _onUserChanged(null);
      const status = SyncStatus(
        state: SyncState.notAuthenticated,
        message: 'User not authenticated',
      );
      _cacheStatus(path, null, status);
      return status;
    }
    _onUserChanged(user.id);

    // 2. 命中未过期的缓存则直接返回。
    final cacheKey = _cacheKey(path, user.id);
    if (!forceRefresh) {
      final cached = _statusCache[cacheKey];
      if (cached != null && !cached.isExpired(cacheTTL)) {
        logger?.debug('命中缓存: $path');
        return cached.status;
      }
    }

    try {
      // 3. 计算本地指纹；本地数据缺失时跳过比较。
      String? localFingerprint;
      int? localCount;
      String? localData;

      if (data != null) {
        localData = await serializer.serialize(data);
        localFingerprint = serializer.fingerprint(localData);
        localCount = _extractPayloadSummary(localData).count;
        logger?.debug('本地指纹: $localFingerprint, count: $localCount');
      }

      // 4. 检查云端文件是否存在。
      final cloudFile = await provider.storage.getMetadata(path: path);

      if (cloudFile == null) {
        final status = SyncStatus(
          state: SyncState.localOnly,
          localFingerprint: localFingerprint,
          message: 'No cloud backup found',
        );
        _cacheStatus(path, user.id, status);
        return status;
      }

      // 5. 优先使用 metadata 中的指纹 / 计数 / 导出时间，避免每次全量下载。
      String? cloudFingerprint = cloudFile.metadata?['fingerprint'] as String?;
      int? cloudCount = _parseInt(cloudFile.metadata?['count']);
      DateTime? cloudUpdatedAt =
          _parseDateTime(cloudFile.metadata?['exportedAt']);

      // 仅当需要判断方向、但 metadata 信息不全（或没有指纹）时才下载正文。
      final needDetails = localFingerprint != null &&
          cloudFingerprint != null &&
          localFingerprint != cloudFingerprint &&
          (cloudCount == null || cloudUpdatedAt == null);
      if (cloudFingerprint == null || needDetails) {
        final cloudData = await provider.storage.download(path: path);
        if (cloudData != null) {
          cloudFingerprint ??= serializer.fingerprint(cloudData);
          final summary = _extractPayloadSummary(cloudData);
          cloudCount ??= summary.count;
          cloudUpdatedAt ??= summary.exportedAt;
        }
      }

      logger?.debug(
          '云端指纹: $cloudFingerprint, count: $cloudCount, updatedAt: $cloudUpdatedAt');

      // 6. 取最近一次同步时间（优先 metadata.uploadedAt，兜底 lastModified）。
      final lastSyncedAtStr = cloudFile.metadata?['uploadedAt'] as String?;
      final lastSyncedAt = lastSyncedAtStr != null
          ? DateTime.tryParse(lastSyncedAtStr)
          : cloudFile.lastModified;

      // 7. 比较指纹并确定状态 / 方向。
      SyncState state;
      SyncDirection? direction;
      String? message;

      if (localFingerprint == null) {
        // 无本地数据时无法判断同步关系，明确返回 unknown，避免误报「已同步」。
        state = SyncState.unknown;
        message = 'No local data to compare';
      } else if (cloudFingerprint == null) {
        state = SyncState.localOnly;
        direction = SyncDirection.localNewer;
        message = 'No cloud backup';
      } else if (localFingerprint == cloudFingerprint) {
        state = SyncState.synced;
        message = 'Local and cloud data match';
      } else {
        state = SyncState.outOfSync;

        if (localUpdatedAt != null && cloudUpdatedAt != null) {
          if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
            direction = SyncDirection.localNewer;
            message = 'Local data is newer (timestamp)';
          } else if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
            direction = SyncDirection.cloudNewer;
            message = 'Cloud data is newer (timestamp)';
          } else {
            direction = SyncDirection.unknown;
            message = 'Data differs but same timestamp';
          }
        } else if (localCount != null && cloudCount != null) {
          if (localCount > cloudCount) {
            direction = SyncDirection.localNewer;
            message = 'Local has more items ($localCount vs $cloudCount)';
          } else if (cloudCount > localCount) {
            direction = SyncDirection.cloudNewer;
            message = 'Cloud has more items ($cloudCount vs $localCount)';
          } else {
            direction = SyncDirection.unknown;
            message = 'Data differs but same count';
          }
        } else {
          direction = SyncDirection.unknown;
          message = 'Local and cloud data differ';
        }
      }

      final status = SyncStatus(
        state: state,
        localFingerprint: localFingerprint,
        cloudFingerprint: cloudFingerprint,
        lastSyncedAt: lastSyncedAt,
        localUpdatedAt: localUpdatedAt,
        cloudUpdatedAt: cloudUpdatedAt,
        direction: direction,
        localCount: localCount,
        cloudCount: cloudCount,
        message: message,
      );

      _cacheStatus(path, user.id, status);
      logger?.info('同步状态: $state');
      return status;
    } catch (e, st) {
      // 基础设施 / 编程异常统一转为 error 状态；
      // message 只保留友好文案，原始异常走日志，避免异常文本直接上 UI。
      logger?.error('获取同步状态失败: $e\n$st');
      final status = SyncStatus(
        state: SyncState.error,
        message: 'Failed to get sync status',
      );
      return status;
    }
  }

  /// 删除云端文件。
  ///
  /// [path] - 云端存储路径。
  ///
  /// 抛出 [CloudNotAuthenticatedException]（未登录）或
  /// [CloudStorageException]（删除失败）。
  ///
  /// 示例：
  /// ```dart
  /// await manager.deleteRemote(path: 'ledgers/123.json');
  /// ```
  Future<void> deleteRemote({required String path}) async {
    logger?.info('删除云端文件: $path');

    // 1. 检查登录态。
    final user = await provider.auth.currentUser;
    if (user == null) {
      logger?.error('删除失败：用户未登录');
      throw CloudNotAuthenticatedException();
    }

    try {
      // 2. 删除云端文件。
      await provider.storage.delete(path: path);

      // 3. 使当前用户的该路径缓存失效。
      _statusCache.remove(_cacheKey(path, user.id));
      logger?.info('删除完成: $path');
    } catch (e) {
      logger?.error('删除失败: $e');
      if (e is CloudSyncException) {
        rethrow;
      }
      throw CloudStorageException('Delete failed', e);
    }
  }

  /// 清空全部状态缓存。
  void clearCache() {
    _statusCache.clear();
    _lastUserId = null;
    logger?.debug('已清空状态缓存');
  }

  /// 释放内部缓存。
  ///
  /// 管理器本身不持有外部资源，dispose 仅用于主动清理缓存。
  void dispose() {
    clearCache();
  }

  /// 缓存同步状态。
  ///
  /// 先清理过期条目，超限时再淘汰最久未更新的条目，避免无上限增长。
  void _cacheStatus(String path, String? userId, SyncStatus status) {
    final key = _cacheKey(path, userId);
    _statusCache.remove(key); // 先移除再插入，刷新 LRU 顺序。
    _evictExpired();
    if (_statusCache.length >= _maxCacheEntries) {
      _evictExpired();
    }
    if (_statusCache.length >= _maxCacheEntries) {
      _statusCache.remove(_statusCache.keys.first);
    }
    _statusCache[key] = _CachedStatus(status, DateTime.now());
  }

  /// 惰性清理所有已过期的缓存条目。
  void _evictExpired() {
    final expired = _statusCache.keys
        .where((key) => _statusCache[key]!.isExpired(cacheTTL))
        .toList();
    for (final key in expired) {
      _statusCache.remove(key);
    }
  }

  /// 生成按用户隔离的缓存 key。
  String _cacheKey(String path, String? userId) => '$userId|$path';

  /// 用户发生变化时清空旧缓存，避免跨账号状态串扰。
  void _onUserChanged(String? userId) {
    if (_lastUserId != userId) {
      _statusCache.clear();
      _lastUserId = userId;
    }
  }

  /// 从序列化 JSON 中提取 count / exportedAt（业务快照摘要）。
  ///
  /// 非 JSON 或字段缺失时返回 null，调用方自行降级。
  ({int? count, DateTime? exportedAt}) _extractPayloadSummary(String data) {
    int? count;
    DateTime? exportedAt;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>?;
      if (json != null) {
        final countValue = json['count'];
        if (countValue is num) {
          count = countValue.toInt();
        }
        final exportedAtStr = json['exportedAt'] as String?;
        if (exportedAtStr != null) {
          exportedAt = DateTime.tryParse(exportedAtStr);
        }
      }
    } catch (_) {
      // 非 JSON 或字段缺失：忽略，调用方走下载兜底。
    }
    return (count: count, exportedAt: exportedAt);
  }

  /// 将 metadata 中的数值字段安全转为 int。
  int? _parseInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// 将 metadata 中的时间字段安全转为 DateTime。
  DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
