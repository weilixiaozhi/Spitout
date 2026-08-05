library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Supabase implementation of [CloudDatabaseService].
///
/// Provides CRUD operations and realtime subscriptions for Supabase PostgreSQL database.
///
/// Example:
/// ```dart
/// final client = supabase.Supabase.instance.client;
/// final dbService = SupabaseDatabaseService(client);
///
/// // Insert
/// final record = await dbService.insert(
///   table: 'transactions',
///   data: {'amount': 100, 'note': 'Test'},
/// );
///
/// // Query
/// final records = await dbService.query(
///   table: 'transactions',
///   filters: [QueryFilter.eq('user_id', userId)],
/// );
/// ```
class SupabaseDatabaseService implements CloudDatabaseService {
  final supabase.SupabaseClient _client;

  SupabaseDatabaseService(this._client);

  @override
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> data,
    bool autoInjectUserId = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // 自动注入 user_id
      final insertData = Map<String, dynamic>.from(data);
      if (autoInjectUserId && !insertData.containsKey('user_id')) {
        insertData['user_id'] = user.id;
      }

      // Insert and return the created record
      final response =
          await _client.from(table).insert(insertData).select().single();

      return response;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Insert failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Insert failed: $e', e);
    }
  }

  @override
  Future<Map<String, dynamic>> update({
    required String table,
    required String id,
    required Map<String, dynamic> data,
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build query
      var query = _client.from(table).update(data).eq('id', id);

      // 自动添加用户过滤
      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      // Update and return the updated record
      final response = await query.select().single();

      return response;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Update failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Update failed: $e', e);
    }
  }

  @override
  Future<void> delete({
    required String table,
    required String id,
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build query
      var query = _client.from(table).delete().eq('id', id);

      // 自动添加用户过滤
      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      // Delete record
      await query;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Delete failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Delete failed: $e', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query({
    required String table,
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
    int? offset,
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Build query
      dynamic query = _client.from(table).select();

      // 自动添加用户过滤
      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      // Apply filters
      if (filters != null) {
        for (final filter in filters) {
          query = _applyFilter(query, filter);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: !descending);
      }

      // Apply pagination
      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 1000) - 1);
      }

      // Execute query
      final response = await query;

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Query failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Query failed: $e', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getById({
    required String table,
    required String id,
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // 构建单条查询：默认按当前用户过滤，防止跨用户按 id 读取（IDOR）。
      var query = _client.from(table).select().eq('id', id);
      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }
      final response = await query.maybeSingle();

      return response;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Get by ID failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Get by ID failed: $e', e);
    }
  }

  @override
  Stream<DatabaseEvent> subscribe({
    required String table,
    List<QueryFilter>? filters,
    String event = '*',
    bool autoFilterByUser = true,
  }) {
    // 实时订阅统一由 SupabaseRealtimeService 负责，本方法仅为接口兼容占位。
    // 实现方必须遵守 autoFilterByUser 语义：只推送当前用户的数据变更。
    throw CloudSyncException(
      '实时订阅请使用 SupabaseRealtimeService，本接口不直接提供订阅能力',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> batchInsert({
    required String table,
    required List<Map<String, dynamic>> data,
    bool autoInjectUserId = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // 批量注入 user_id：与单条 insert 保持一致的越权防御语义。
      final insertData = autoInjectUserId
          ? data.map((record) {
              if (record.containsKey('user_id')) return record;
              return <String, dynamic>{...record, 'user_id': user.id};
            }).toList()
          : data;

      final response = await _client.from(table).insert(insertData).select();

      return List<Map<String, dynamic>>.from(response as List);
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch insert failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch insert failed: $e', e);
    }
  }

  @override
  Future<void> batchUpdate({
    required String table,
    required List<Map<String, dynamic>> data,
    String idField = 'id',
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // Supabase 不支持批量更新，逐条执行；每条都按 id + 用户过滤。
      for (final record in data) {
        final id = record[idField];
        if (id == null) {
          throw CloudStorageException('Record missing $idField field');
        }

        var query = _client.from(table).update(record).eq(idField, id);
        if (autoFilterByUser) {
          query = query.eq('user_id', user.id);
        }
        await query;
      }
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch update failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch update failed: $e', e);
    }
  }

  @override
  Future<void> batchDelete({
    required String table,
    required List<QueryFilter> filters,
    bool autoFilterByUser = true,
  }) async {
    try {
      // Check authentication
      final user = _client.auth.currentUser;
      if (user == null) {
        throw CloudNotAuthenticatedException('User not authenticated');
      }

      // 先追加用户过滤，再叠加调用方过滤器，防止误删其他用户记录。
      var query = _client.from(table).delete();
      if (autoFilterByUser) {
        query = query.eq('user_id', user.id);
      }

      for (final filter in filters) {
        query = _applyFilter(query, filter);
      }

      await query;
    } on supabase.PostgrestException catch (e) {
      throw CloudStorageException('Batch delete failed: ${e.message}', e);
    } catch (e) {
      if (e is CloudNotAuthenticatedException) rethrow;
      throw CloudStorageException('Batch delete failed: $e', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String query) async {
    // 客户端透传任意 SQL 属于高危设计面：即使有 anon key 也无法保证服务端
    // RPC 的权限收敛，因此本实现一律拒绝执行。需要自定义查询时，
    // 请在服务端提供白名单 RPC（只允许预设操作）后再扩展本方法。
    throw CloudSyncException(
      'rawQuery 已禁用：客户端不透传任意 SQL，请改用服务端白名单 RPC',
    );
  }

  /// Apply filter to query
  dynamic _applyFilter(dynamic query, QueryFilter filter) {
    switch (filter.operator) {
      case 'eq':
        return query.eq(filter.column, filter.value);
      case 'neq':
        return query.neq(filter.column, filter.value);
      case 'gt':
        return query.gt(filter.column, filter.value);
      case 'gte':
        return query.gte(filter.column, filter.value);
      case 'lt':
        return query.lt(filter.column, filter.value);
      case 'lte':
        return query.lte(filter.column, filter.value);
      case 'like':
        return query.like(filter.column, filter.value);
      case 'ilike':
        return query.ilike(filter.column, filter.value);
      case 'in':
        return query.inFilter(filter.column, filter.value as List);
      case 'is':
        return query.isFilter(filter.column, filter.value);
      case 'contains':
        return query.contains(filter.column, filter.value);
      case 'containedBy':
        return query.containedBy(filter.column, filter.value);
      case 'overlaps':
        return query.overlaps(filter.column, filter.value as List);
      default:
        throw CloudStorageException(
            'Unsupported filter operator: ${filter.operator}');
    }
  }
}
