import 'dart:async';
import 'dart:convert';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show CloudSyncLogger;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/spitout_cloud_auth_service.dart';
import '../internal.dart';
import '../models/spitout_cloud_models.dart';

class SpitoutCloudRealtimeClient {
  SpitoutCloudRealtimeClient({
    required this.baseUrl,
    required this.auth,
    CloudSyncLogger? logger,
  }) : _logger = logger ?? defaultCloudLogger;

  final String baseUrl;
  final SpitoutCloudAuthService auth;
  final CloudSyncLogger _logger;

  final StreamController<SpitoutCloudRealtimeEvent> _events =
      StreamController<SpitoutCloudRealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _running = false;
  bool _connecting = false;
  bool _disposed = false;

  /// 连续重连失败次数,用于指数退避(3s → 6s → 12s → 24s → 48s → 60s 封顶)。
  ///
  /// 设计意图:固定 3s 重连在 server 短暂不可用时会形成"重连风暴"——
  /// 每 3s 一次 requireAccessToken + WS 握手,既打爆 server 也耗电。
  /// 收到任意入站帧(证明连接真实存活)后归零。
  int _reconnectAttempts = 0;

  Stream<SpitoutCloudRealtimeEvent> get events => _events.stream;

  Future<void> start() async {
    if (_disposed) {
      throw StateError('SpitoutCloudRealtimeClient has been disposed.');
    }
    if (_running) {
      return;
    }
    _running = true;
    await _connect();
  }

  Future<void> stop() async {
    _running = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer = null;
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  /// 释放客户端:幂等,重复调用安全。
  ///
  /// 与 [stop] 职责不同:stop 只停连接(之后可再次 start),
  /// dispose 是终态(关闭事件流,之后 start 会抛 [StateError])。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer = null;
    final sub = _channelSub;
    _channelSub = null;
    unawaited(sub?.cancel());
    final channel = _channel;
    _channel = null;
    unawaited(channel?.sink.close());
    _events.close();
  }

  Future<void> _connect() async {
    if (!_running || _connecting || _disposed) {
      return;
    }
    _connecting = true;

    try {
      final token = await auth.requireAccessToken();
      final uri = _buildWebSocketUri();
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      // token 不拼进 URL query(会进代理 / 访问日志),改为握手后首帧
      // 鉴权消息;server 在注册到 manager 前会先等待并校验这条消息。
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));

      _channelSub = channel.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_, __) => _scheduleReconnect(),
        // 设为 false:onError 后不立即取消订阅,让流自然走到 onDone。
        // cancelOnError: true 会把偶发的单帧错误放大成整条连接被掐断,
        // 加剧"总是断连"的观感;重连统一由 _scheduleReconnect 幂等调度。
        cancelOnError: false,
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        try {
          // server 只认 JSON 心跳({type: ping}),裸字符串会被当作无效消息。
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });

      // 发一条 "connected" 事件给业务层，让 SyncEngine 知道 WS 重连成功 ——
      // 离线累积的 local_changes 可以此时 flush。没有这个通知的话，断网
      // 期间用户改的东西要等下一次交易写入 / PostProcessor.sync() 才推出去。
      _events.add(const SpitoutCloudRealtimeEvent(type: 'connected'));
      _logger.debug('[SpitoutCloud-Realtime] WS connected');
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Uri _buildWebSocketUri() {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    // server 的 WS 挂在根路径 /ws(不在 apiPrefix 下),见 server main.py
    // `app.include_router(ws.router, tags=["ws"])`,无需拼接 apiPrefix。
    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'ws',
    ];

    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/${segments.join('/')}',
    );
  }

  void _onMessage(dynamic message) {
    // 收到任意入站帧(包括 pong)即证明连接真实存活,重置重连退避计数,
    // 让下一次意外断开后能以最短间隔(3s)开始重连。
    _reconnectAttempts = 0;
    if (message is! String || message.trim().isEmpty || message == 'pong') {
      return;
    }

    try {
      final payload = jsonDecode(message);
      if (payload is! Map<String, dynamic>) {
        return;
      }
      final type = payload['type'];
      if (type is! String || type.isEmpty) {
        return;
      }
      // server 心跳应答 {"type":"pong"} 只用于确认存活,不向业务层透传。
      if (type == 'pong') return;
      final serverCursor = (payload['serverCursor'] as num?)?.toInt();
      _events.add(
        SpitoutCloudRealtimeEvent(
          type: type,
          ledgerId: payload['ledgerId'] as String?,
          serverCursor: serverCursor,
          rawData: payload,
        ),
      );
    } catch (_) {}
  }

  void _scheduleReconnect([Object? _, StackTrace? __]) {
    if (!_running) {
      return;
    }

    // cancelOnError: false 后,同一次断开可能先后触发 onError 与 onDone;
    // 若已有待执行的重连定时器,直接复用,避免退避计数被重复累加。
    final pending = _reconnectTimer;
    if (pending != null && pending.isActive) {
      return;
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;

    // 指数退避:3 << n 秒,封顶 60s;连接活跃(_onMessage)时归零。
    final delaySeconds = (3 << _reconnectAttempts).clamp(3, 60);
    if (_reconnectAttempts < 5) {
      _reconnectAttempts++;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!_running) {
        return;
      }
      // 重连前确认 session 可用:仅当 access_token 缺失/已过期才发起 refresh,
      // 避免每次重连都无条件旋转 refresh token(rotating token 机制下会
      // 频繁 revoke 老 token,放大并发失效风险,也给 server 增压)。
      if (!auth.hasUsableAccessToken) {
        await auth.tryRefreshSession();
      }
      await _connect();
    });
  }
}
