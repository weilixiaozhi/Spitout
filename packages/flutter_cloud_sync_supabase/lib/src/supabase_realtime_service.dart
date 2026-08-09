library;

import 'dart:async';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Supabase implementation of [RealtimeChannel].
class SupabaseRealtimeChannel implements RealtimeChannel {
  final supabase.RealtimeChannel _channel;
  final String _channelName;
  final void Function(RealtimeConnectionState state)? _onStateChanged;

  SupabaseRealtimeChannel(
    this._channel,
    this._channelName, {
    void Function(RealtimeConnectionState state)? onStateChanged,
  }) : _onStateChanged = onStateChanged;

  @override
  RealtimeChannel onPostgresChanges({
    required String event,
    required String schema,
    required String table,
    String? filter,
    required void Function(Map<String, dynamic> payload) callback,
  }) {
    _channel.onPostgresChanges(
      event: _parsePostgresEvent(event),
      schema: schema,
      table: table,
      filter: parsePostgresFilter(filter),
      callback: (payload) {
        // Convert Supabase payload to our format
        final data = <String, dynamic>{
          'eventType': payload.eventType.name.toUpperCase(),
          'new': payload.newRecord,
          'old': payload.oldRecord,
          'table': payload.table,
          'schema': payload.schema,
          'commitTimestamp': payload.commitTimestamp,
        };
        callback(data);
      },
    );

    return this;
  }

  @override
  RealtimeChannel on(
    String event,
    void Function(Map<String, dynamic> payload) callback,
  ) {
    _channel.onBroadcast(
      event: event,
      callback: (payload) {
        callback(payload);
      },
    );

    return this;
  }

  @override
  Future<void> send({
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    await _channel.sendBroadcastMessage(
      event: event,
      payload: payload,
    );
  }

  @override
  Future<void> subscribe() async {
    // 通过订阅状态回调等待真正就绪（SUBSCRIBED / 失败），
    // 避免调用方在连接建立前就继续执行。
    final completer = Completer<void>();
    void fail(Object error) {
      _onStateChanged?.call(RealtimeConnectionState.error);
      if (!completer.isCompleted) {
        completer.completeError(
          error is CloudSyncException
              ? error
              : CloudSyncException('Realtime 频道订阅失败: $error', error),
        );
      }
    }

    try {
      _channel.subscribe((status, error) {
        switch (status) {
          case supabase.RealtimeSubscribeStatus.subscribed:
            _onStateChanged?.call(RealtimeConnectionState.connected);
            if (!completer.isCompleted) completer.complete();
            break;
          case supabase.RealtimeSubscribeStatus.closed:
            _onStateChanged?.call(RealtimeConnectionState.disconnected);
            if (!completer.isCompleted) {
              completer.completeError(
                CloudSyncException('Realtime 频道已关闭', error),
              );
            }
            break;
          case supabase.RealtimeSubscribeStatus.timedOut:
          case supabase.RealtimeSubscribeStatus.channelError:
            fail(error ?? CloudSyncException('订阅失败: ${status.name}'));
            break;
        }
      }, const Duration(seconds: 15));
    } catch (e) {
      fail(e);
    }
    await completer.future;
  }

  @override
  Future<void> unsubscribe() async {
    await supabase.Supabase.instance.client.removeChannel(_channel);
    _onStateChanged?.call(RealtimeConnectionState.disconnected);
  }

  @override
  String get name => _channelName;

  @override
  String get state {
    // 使用全局 realtime 连接状态，避免访问 internal 的 _channel.socket
    if (supabase.Supabase.instance.client.realtime.isConnected) {
      return 'subscribed';
    }
    return 'closed';
  }

  /// 解析 Postgres 变更过滤器（`column=op.value` 三段格式）。
  ///
  /// 支持 `eq` / `neq` / `gt` / `gte` / `lt` / `lte` / `in` / `is` /
  /// `like` / `ilike` 等操作符，以及 `not.` 取反前缀。
  /// 旧实现用 `split('=')` 会把 `eq.123` 整体当作 value，导致过滤恒不匹配。
  static supabase.PostgresChangeFilter? parsePostgresFilter(String? filter) {
    if (filter == null || filter.isEmpty) return null;

    final eqIndex = filter.indexOf('=');
    if (eqIndex <= 0 || eqIndex == filter.length - 1) {
      throw ArgumentError('无效的 Realtime 过滤器: $filter');
    }
    final column = filter.substring(0, eqIndex);
    var rest = filter.substring(eqIndex + 1);

    // 支持 not. 取反前缀。
    var negate = false;
    if (rest.startsWith('not.')) {
      negate = true;
      rest = rest.substring(4);
    }

    final dotIndex = rest.indexOf('.');
    if (dotIndex <= 0 || dotIndex == rest.length - 1) {
      throw ArgumentError('无效的 Realtime 过滤器（缺少操作符或值）: $filter');
    }
    final op = rest.substring(0, dotIndex);
    final value = rest.substring(dotIndex + 1);

    // 操作符白名单：优先精确匹配，其次匹配 inFilter / isFilter 这类带后缀枚举。
    supabase.PostgresChangeFilterType? type;
    for (final candidate in supabase.PostgresChangeFilterType.values) {
      if (candidate.name == op || candidate.name == '${op}Filter') {
        type = candidate;
        break;
      }
    }
    if (type == null) {
      throw ArgumentError('不支持的 Realtime 过滤操作符: $op');
    }

    return supabase.PostgresChangeFilter(
      type: type,
      column: column,
      value: value,
      negate: negate,
    );
  }

  /// Parse event string to Supabase event type
  supabase.PostgresChangeEvent _parsePostgresEvent(String event) {
    switch (event.toUpperCase()) {
      case 'INSERT':
        return supabase.PostgresChangeEvent.insert;
      case 'UPDATE':
        return supabase.PostgresChangeEvent.update;
      case 'DELETE':
        return supabase.PostgresChangeEvent.delete;
      case '*':
      case 'ALL':
        return supabase.PostgresChangeEvent.all;
      default:
        return supabase.PostgresChangeEvent.all;
    }
  }
}

/// Supabase implementation of [CloudRealtimeService].
///
/// Provides WebSocket-based realtime communication for Supabase.
///
/// Example:
/// ```dart
/// final client = supabase.Supabase.instance.client;
/// final realtimeService = SupabaseRealtimeService(client);
///
/// // Monitor connection state
/// realtimeService.connectionState.listen((state) {
///   print('Connection: $state');
/// });
///
/// // Create a channel
/// final channel = realtimeService.channel('transactions:123');
///
/// // Listen to database changes
/// channel.onPostgresChanges(
///   event: '*',
///   schema: 'public',
///   table: 'transactions',
///   filter: 'ledger_id=eq.123',
///   callback: (payload) {
///     print('Change: ${payload['eventType']}');
///   },
/// );
///
/// await channel.subscribe();
/// ```
class SupabaseRealtimeService implements CloudRealtimeService {
  final supabase.SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final StreamController<RealtimeConnectionState> _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();

  RealtimeConnectionState _currentState = RealtimeConnectionState.disconnected;

  SupabaseRealtimeService(this._client) {
    _initializeConnectionMonitoring();
  }

  /// Initialize connection state monitoring
  void _initializeConnectionMonitoring() {
    // Monitor Supabase realtime connection status
    // Note: Supabase doesn't expose a direct connection state stream
    // We infer state from channel subscriptions and socket events
    _updateConnectionState(
      _client.realtime.isConnected
          ? RealtimeConnectionState.connected
          : RealtimeConnectionState.disconnected,
    );
  }

  @override
  Stream<RealtimeConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  RealtimeConnectionState get currentState => _currentState;

  @override
  RealtimeChannel channel(String channelName) {
    // Return existing channel if already created
    if (_channels.containsKey(channelName)) {
      return _channels[channelName]!;
    }

    // Create new Supabase channel
    final supabaseChannel = _client.channel(channelName);

    // Wrap in our interface，并把频道状态联动到服务级连接状态。
    final channel = SupabaseRealtimeChannel(
      supabaseChannel,
      channelName,
      onStateChanged: (state) => _updateConnectionState(state),
    );

    // Cache channel
    _channels[channelName] = channel;

    return channel;
  }

  @override
  Future<void> removeChannel(String channelName) async {
    final channel = _channels.remove(channelName);
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  @override
  Future<void> removeAllChannels() async {
    for (final channel in _channels.values) {
      await channel.unsubscribe();
    }
    _channels.clear();
  }

  @override
  List<RealtimeChannel> get channels => _channels.values.toList();

  @override
  bool hasChannel(String channelName) => _channels.containsKey(channelName);

  @override
  Future<void> connect() async {
    _updateConnectionState(RealtimeConnectionState.connecting);

    try {
      // Supabase realtime connection is automatic
      // Just ensure client is initialized
      if (!_client.realtime.isConnected) {
        // Connection will be established when first channel subscribes
        _updateConnectionState(RealtimeConnectionState.connected);
      } else {
        _updateConnectionState(RealtimeConnectionState.connected);
      }
    } catch (e) {
      _updateConnectionState(RealtimeConnectionState.error);
      throw CloudSyncException('Failed to connect to realtime server: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      // Remove all channels
      await removeAllChannels();

      // Disconnect realtime
      // Note: Supabase doesn't provide explicit disconnect
      // Channels are automatically cleaned up

      _updateConnectionState(RealtimeConnectionState.disconnected);
    } catch (e) {
      _updateConnectionState(RealtimeConnectionState.error);
      throw CloudSyncException('Failed to disconnect from realtime server: $e');
    }
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(RealtimeConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(_currentState);
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionStateController.close();
  }
}
