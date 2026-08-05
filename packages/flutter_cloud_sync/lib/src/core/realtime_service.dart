/// 云实时服务。
///
/// 实时通信（基于 WebSocket）的抽象接口，
/// 支持数据库变更订阅与自定义事件。
library;

/// 实时连接状态。
enum RealtimeConnectionState {
  /// 连接中。
  connecting,

  /// 已连接并可用。
  connected,

  /// 已断开。
  disconnected,

  /// 连接出错。
  error,
}

/// 实时频道。
///
/// 表示实时通信的发布 / 订阅频道。
///
/// 示例：
/// ```dart
/// final channel = realtimeService.channel('room:123')
///   .onPostgresChanges(
///     event: 'INSERT',
///     schema: 'public',
///     table: 'messages',
///     filter: 'room_id=eq.123',
///     callback: (payload) {
///       print('New message: ${payload['new']}');
///     },
///   )
///   .on('custom-event', (payload) {
///     print('Custom event: $payload');
///   });
///
/// await channel.subscribe();
///
/// // 发送自定义事件
/// await channel.send(
///   event: 'user-typing',
///   payload: {'user': 'John'},
/// );
///
/// // 清理
/// await channel.unsubscribe();
/// ```
abstract class RealtimeChannel {
  /// 订阅 PostgreSQL 数据库变更。
  ///
  /// [event] - 事件类型（INSERT、UPDATE、DELETE，或 * 表示全部）
  /// [schema] - 数据库 schema（通常为 'public'）
  /// [table] - 表名
  /// [filter] - 可选过滤条件（如 'user_id=eq.123'）
  /// [callback] - 事件发生时的回调
  RealtimeChannel onPostgresChanges({
    required String event,
    required String schema,
    required String table,
    String? filter,
    required void Function(Map<String, dynamic> payload) callback,
  });

  /// 订阅自定义事件（广播）。
  ///
  /// [event] - 事件名
  /// [callback] - 事件发生时的回调
  RealtimeChannel on(
    String event,
    void Function(Map<String, dynamic> payload) callback,
  );

  /// 向所有订阅者发送自定义事件。
  ///
  /// [event] - 事件名
  /// [payload] - 事件数据
  Future<void> send({
    required String event,
    required Map<String, dynamic> payload,
  });

  /// 订阅频道。
  ///
  /// 必须在设置好监听器之后调用。
  Future<void> subscribe();

  /// 取消订阅频道。
  ///
  /// 移除全部监听器并关闭频道。
  Future<void> unsubscribe();

  /// 频道名称。
  String get name;

  /// 频道状态。
  String get state;
}

/// 云实时服务接口。
///
/// 基于 WebSocket 提供实时通信能力。
///
/// 示例：
/// ```dart
/// final realtimeService = SupabaseRealtimeProvider(client);
///
/// // 监听连接状态
/// realtimeService.connectionState.listen((state) {
///   print('Realtime connection: $state');
/// });
///
/// // 创建频道
/// final channel = realtimeService.channel('my-channel');
///
/// // 监听数据库变更
/// channel.onPostgresChanges(
///   event: '*',
///   schema: 'public',
///   table: 'transactions',
///   filter: 'ledger_id=eq.${ledgerId}',
///   callback: (payload) {
///     final eventType = payload['eventType']; // INSERT, UPDATE, DELETE
///     final record = payload['new'] ?? payload['old'];
///     print('$eventType: $record');
///   },
/// );
///
/// await channel.subscribe();
/// ```
abstract class CloudRealtimeService {
  /// 连接状态流。
  ///
  /// 发出连接状态变化。
  Stream<RealtimeConnectionState> get connectionState;

  /// 当前连接状态。
  RealtimeConnectionState get currentState;

  /// 创建或获取实时频道。
  ///
  /// 频道按名称缓存；同名多次调用返回同一实例。
  ///
  /// [channelName] - 唯一频道标识
  RealtimeChannel channel(String channelName);

  /// 移除指定频道。
  ///
  /// 取消订阅并从缓存中移除。
  Future<void> removeChannel(String channelName);

  /// 移除全部频道。
  ///
  /// 取消订阅并移除全部频道。
  Future<void> removeAllChannels();

  /// 获取全部活跃频道。
  List<RealtimeChannel> get channels;

  /// 检查频道是否存在。
  bool hasChannel(String channelName);

  /// 连接实时服务器。
  ///
  /// 通常在创建第一个频道时自动调用。
  Future<void> connect();

  /// 断开实时服务器连接。
  ///
  /// 移除全部频道并关闭连接。
  Future<void> disconnect();
}
