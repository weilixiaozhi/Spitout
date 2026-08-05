import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error;

  String get displayName {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String get emoji {
    switch (this) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }
}

/// 日志来源平台
enum LogPlatform {
  flutter,
  android,
  ios;

  String get displayName {
    switch (this) {
      case LogPlatform.flutter:
        return 'Flutter';
      case LogPlatform.android:
        return 'Android';
      case LogPlatform.ios:
        return 'iOS';
    }
  }
}

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogPlatform platform;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.platform,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'level': level.index,
      'platform': platform.index,
      'tag': tag,
      'message': message,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
    };
  }

  /// 从 JSON 反序列化
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    final timestampValue = json['timestamp'];
    if (timestampValue is! int) {
      throw FormatException('timestamp 必须是 int: $timestampValue');
    }

    final levelValue = json['level'];
    if (levelValue is! int ||
        levelValue < 0 ||
        levelValue >= LogLevel.values.length) {
      throw FormatException('level 索引越界: $levelValue');
    }

    final platformValue = json['platform'];
    if (platformValue is! int ||
        platformValue < 0 ||
        platformValue >= LogPlatform.values.length) {
      throw FormatException('platform 索引越界: $platformValue');
    }

    final tagValue = json['tag'];
    if (tagValue is! String) {
      throw FormatException('tag 必须是 String: $tagValue');
    }

    final messageValue = json['message'];
    if (messageValue is! String) {
      throw FormatException('message 必须是 String: $messageValue');
    }

    final errorValue = json['error'];
    final stackTraceValue = json['stackTrace'];
    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampValue),
      level: LogLevel.values[levelValue],
      platform: LogPlatform.values[platformValue],
      tag: tagValue,
      message: messageValue,
      error: errorValue is String ? errorValue : null,
      stackTrace: stackTraceValue is String
          ? StackTrace.fromString(stackTraceValue)
          : null,
    );
  }

  /// 格式化为文本
  String toFormattedString() {
    final buffer = StringBuffer();

    // 时间戳
    final time = '${_twoDigits(timestamp.hour)}:'
        '${_twoDigits(timestamp.minute)}:'
        '${_twoDigits(timestamp.second)}.'
        '${_threeDigits(timestamp.millisecond)}';

    buffer.write('[$time] ');
    buffer.write('[${level.displayName}] ');
    buffer.write('[${platform.displayName}] ');
    buffer.write('[$tag] ');
    buffer.writeln(message);

    if (error != null) {
      buffer.writeln('  Error: $error');
    }

    if (stackTrace != null) {
      buffer.writeln('  Stack Trace:');
      buffer.writeln('  ${stackTrace.toString().replaceAll('\n', '\n  ')}');
    }

    return buffer.toString();
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
  static String _threeDigits(int n) => n.toString().padLeft(3, '0');
}

/// 日志服务
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal() {
    _setupNativeBridge();
  }

  static const _channel = MethodChannel('com.spitout.logger');
  static const _storageKey = 'app_logs';
  static const _maxStorageHours = 48; // 保留48小时

  // 使用循环缓冲区存储日志，最多保留最近的 2000 条
  static const int _maxLogs = 2000;
  /// 单条日志各字段的最大字符数，防止堆栈/消息把内存与序列化体积撑大。
  static const int _maxEntryChars = 2000;
  /// 内存日志总字符数上限，控制 SharedPreferences 全量写入的体积。
  static const int _maxTotalChars = 200 * 1024;
  final _logs = Queue<LogEntry>();
  /// 当前内存日志总字符数，用于快速判断是否触发容量清理。
  int _totalChars = 0;

  // 日志监听器
  final _listeners = <VoidCallback>[];

  /// 是否已完成持久化日志加载
  bool _isLoaded = false;

  /// 是否正在加载持久化日志，避免并发重复读取
  bool _isLoading = false;

  /// 当前加载任务，供后续调用复用同一个 Future
  Future<void>? _loadFuture;

  /// 加载代际编号：清空日志时递增，使进行中的加载结果失效
  int _loadGeneration = 0;

  /// 是否有尚未落盘的新日志
  bool _isDirty = false;

  Timer? _saveTimer;
  Future<void>? _saveFuture;
  bool _isSaving = false;

  /// 获取所有日志（自动加载持久化的日志）
  List<LogEntry> get logs {
    _ensureLoaded();
    _removeExpiredLogs(DateTime.now());
    return _logs.toList();
  }

  /// 添加监听器
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// 通知监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e, stackTrace) {
        // 单个监听器异常不能影响其他监听器，也不能冒泡到日志调用方
        debugPrint('日志监听器回调异常: $e');
        debugPrint('堆栈: $stackTrace');
      }
    }
  }

  static String _truncate(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    const suffix = '…[截断]';
    return '${value.substring(0, maxChars - suffix.length)}$suffix';
  }

  /// 对单条日志做长度限制，避免错误堆栈把内存和持久化体积撑大。
  LogEntry _sanitizeEntry(LogEntry entry) {
    return LogEntry(
      timestamp: entry.timestamp,
      level: entry.level,
      platform: entry.platform,
      tag: _truncate(entry.tag, 100),
      message: _truncate(entry.message, _maxEntryChars),
      error: entry.error == null
          ? null
          : _truncate(entry.error.toString(), _maxEntryChars),
      stackTrace: entry.stackTrace == null
          ? null
          : StackTrace.fromString(
              _truncate(entry.stackTrace.toString(), _maxEntryChars * 2),
            ),
    );
  }

  int _entryChars(LogEntry entry) {
    return entry.tag.length +
        entry.message.length +
        (entry.error?.toString().length ?? 0) +
        (entry.stackTrace?.toString().length ?? 0);
  }

  /// 清理超过 48 小时的日志，保证内存展示/导出与保留策略一致。
  void _removeExpiredLogs(DateTime now) {
    while (_logs.isNotEmpty &&
        now.difference(_logs.first.timestamp).inHours >= _maxStorageHours) {
      final removed = _logs.removeFirst();
      _totalChars -= _entryChars(removed);
    }
  }

  /// 按条数与总字符数双重限制裁剪内存队列。
  void _trimMemory(DateTime now) {
    _removeExpiredLogs(now);
    while (_logs.isNotEmpty &&
        (_logs.length > _maxLogs || _totalChars > _maxTotalChars)) {
      final removed = _logs.removeFirst();
      _totalChars -= _entryChars(removed);
    }
  }

  /// 添加日志
  void _addLog(LogEntry entry) {
    // 确保已加载
    if (!_isLoaded) {
      _ensureLoaded();
    }

    // 先做长度限制和过期清理，再追加，最后按条数/总字符数统一裁剪
    final sanitized = _sanitizeEntry(entry);
    final now = DateTime.now();
    _removeExpiredLogs(now);
    _logs.add(sanitized);
    _totalChars += _entryChars(sanitized);
    _trimMemory(now);

    // 同时打印到控制台（开发模式）
    if (kDebugMode) {
      debugPrint(sanitized.toFormattedString());
    }

    // 通知监听器
    _notifyListeners();

    // 异步保存到持久化存储
    _saveLogs();
  }

  /// 确保持久化日志已加载；加载中时复用同一个加载 Future，避免重复读取。
  Future<void> _ensureLoaded() {
    if (_isLoaded) return Future.value();

    final loading = _loadFuture;
    if (loading != null) return loading;

    final future = _loadLogs();
    _loadFuture = future;
    return future;
  }

  /// 加载持久化日志，加载完成后统一通知监听器刷新页面。
  Future<void> _loadLogs() async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;

    // 记录当前代际；若加载期间用户清空了日志，则丢弃本次读取结果，
    // 避免已经“清空”的旧日志在加载完成后重新复活。
    final generation = _loadGeneration;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _loadGeneration) return;

      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return;

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final now = DateTime.now();
      final persisted = <LogEntry>[];
      var skippedCount = 0;

      // 逐条反序列化并过滤超过 48 小时的日志，单条损坏不影响其余日志
      for (final json in jsonList) {
        try {
          final entry = LogEntry.fromJson(json as Map<String, dynamic>);
          final age = now.difference(entry.timestamp);
          if (age.inHours < _maxStorageHours) {
            persisted.add(entry);
          }
        } catch (e) {
          skippedCount++;
          debugPrint('加载日志条目失败: $e');
        }
      }
      if (skippedCount > 0) {
        debugPrint('本次加载共跳过 $skippedCount 条损坏日志');
      }

      if (generation != _loadGeneration) return;
      _mergePersistedLogs(persisted);
      debugPrint('从持久化存储加载了 ${persisted.length} 条日志');
    } catch (e, stackTrace) {
      debugPrint('加载日志失败: $e');
      debugPrint('堆栈: $stackTrace');
    } finally {
      _isLoading = false;
      _loadFuture = null;
      _isLoaded = true;
      // 加载期间如果有新日志待保存，加载完成后再启动保存，
      // 避免在旧日志读出前就覆盖持久化存储。
      if (_isDirty) {
        _scheduleSaveIfNeeded();
      }
      _notifyListeners();
    }
  }

  /// 将持久化日志与内存中新产生的日志按时间升序合并，
  /// 保证历史日志始终排在新日志之前。
  void _mergePersistedLogs(List<LogEntry> persisted) {
    final current = _logs.toList();
    final merged = <LogEntry>[
      ...persisted.map(_sanitizeEntry),
      ...current,
    ]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _logs
      ..clear()
      ..addAll(merged);

    _totalChars = _logs.fold(0, (sum, entry) => sum + _entryChars(entry));
    // 合并后仍按条数与总字符数双重限制裁剪
    _trimMemory(DateTime.now());
  }

  /// 标记有待保存日志，并按固定间隔触发保存；
  /// 不采用“每次取消重建 timer”的方式，避免高频日志导致保存被无限推迟。
  void _saveLogs() {
    _isDirty = true;
    _scheduleSaveIfNeeded();
  }

  /// 仅在没有进行中的定时器或保存时调度下一次保存。
  void _scheduleSaveIfNeeded() {
    // 持久化日志加载完成前不落盘，避免覆盖尚未读取的旧日志
    if (!_isLoaded || _saveTimer != null || _isSaving) return;

    _saveTimer = Timer(const Duration(seconds: 2), () {
      _saveTimer = null;
      _saveFuture = _doSaveLogs();
    });
  }

  /// 将内存日志写入持久化存储；
  /// 保存失败或保存期间产生新日志时，会在 finally 中重新调度补写。
  Future<void> _doSaveLogs() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      // 保存开始时先清空脏标记；保存期间新增的日志会重新置脏并触发补写，
      // 因此这里不能在写完后再次无条件清空脏标记。
      _isDirty = false;

      final now = DateTime.now();
      _removeExpiredLogs(now);
      final validLogs = _logs.where((log) {
        final age = now.difference(log.timestamp);
        return age.inHours < _maxStorageHours;
      }).toList();

      final jsonList = validLogs.map((log) => log.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonStr);
    } catch (e, stackTrace) {
      // 保存失败保留脏标记，后续自动重试，避免日志丢失
      _isDirty = true;
      debugPrint('保存日志失败: $e');
      debugPrint('堆栈: $stackTrace');
    } finally {
      _isSaving = false;
      _saveFuture = null;
      if (_isDirty) {
        _scheduleSaveIfNeeded();
      }
    }
  }

  /// Debug 日志
  void debug(String tag, String message, [dynamic data]) {
    final msg = data != null ? '$message | Data: $data' : message;
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.debug,
      platform: LogPlatform.flutter,
      tag: tag,
      message: msg,
    ));
  }

  /// Info 日志
  void info(String tag, String message, [dynamic data]) {
    final msg = data != null ? '$message | Data: $data' : message;
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      platform: LogPlatform.flutter,
      tag: tag,
      message: msg,
    ));
  }

  /// Warning 日志
  void warning(String tag, String message, [dynamic data]) {
    final msg = data != null ? '$message | Data: $data' : message;
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.warning,
      platform: LogPlatform.flutter,
      tag: tag,
      message: msg,
    ));
  }

  /// Error 日志
  void error(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.error,
      platform: LogPlatform.flutter,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  /// 清空日志
  Future<void> clear() async {
    // 取消尚未触发的保存，避免清空后旧日志再次落盘
    _saveTimer?.cancel();
    _saveTimer = null;

    // 递增代际使进行中的加载结果失效，并阻止后续再次读取旧日志
    _loadGeneration++;
    _isLoaded = true;
    _isDirty = false;
    _logs.clear();
    _totalChars = 0;
    _notifyListeners();

    // 等待正在进行的保存结束，避免旧内容在清空后覆盖空存储
    final inFlightSave = _saveFuture;
    if (inFlightSave != null) {
      try {
        await inFlightSave;
      } catch (_) {
        // 保存失败已在 _doSaveLogs 内记录并处理，这里无需重复处理
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e, stackTrace) {
      debugPrint('清空日志持久化失败: $e');
      debugPrint('堆栈: $stackTrace');
    } finally {
      _notifyListeners();
    }
  }

  /// 导出所有日志为文本
  Future<String> exportAsText() async {
    // 导出前等待持久化日志加载完成，避免首次打开时导出为空
    await _ensureLoaded();
    _removeExpiredLogs(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('=== Spitout 日志导出 ===');
    buffer.writeln('导出时间: ${DateTime.now()}');
    buffer.writeln('日志数量: ${_logs.length}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final log in _logs) {
      buffer.write(log.toFormattedString());
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 设置原生日志桥接
  void _setupNativeBridge() {
    _channel.setMethodCallHandler((call) async {
      try {
        if (call.method != 'onNativeLog') return;
        final args = call.arguments;
        if (args is! Map) {
          debugPrint('收到非 Map 的原生日志参数: ${args.runtimeType}');
          return;
        }
        _handleNativeLog(args);
      } catch (e, stackTrace) {
        debugPrint('处理原生日志失败: $e');
        debugPrint('堆栈: $stackTrace');
      }
    });
  }

  /// 处理原生日志
  void _handleNativeLog(Map args) {
    try {
      debugPrint('📱 收到原生日志: $args');

      final platformStr = args['platform'] as String;
      final levelStr = args['level'] as String;
      final tag = args['tag'] as String;
      final message = args['message'] as String;
      final timestamp = args['timestamp'] as int;

      // 解析平台
      final platform = platformStr == 'android'
          ? LogPlatform.android
          : platformStr == 'ios'
              ? LogPlatform.ios
              : LogPlatform.flutter;

      // 解析日志级别
      final level = _parseLogLevel(levelStr);

      debugPrint('📝 添加原生日志到队列: [$platformStr] [$levelStr] [$tag] $message');

      _addLog(LogEntry(
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
        level: level,
        platform: platform,
        tag: tag,
        message: message,
      ));
    } catch (e, stackTrace) {
      debugPrint('处理原生日志失败: $e');
      debugPrint('堆栈: $stackTrace');
    }
  }

  LogLevel _parseLogLevel(String levelStr) {
    switch (levelStr.toUpperCase()) {
      case 'DEBUG':
      case 'D':
        return LogLevel.debug;
      case 'INFO':
      case 'I':
        return LogLevel.info;
      case 'WARNING':
      case 'WARN':
      case 'W':
        return LogLevel.warning;
      case 'ERROR':
      case 'E':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

/// 全局日志实例
final logger = LoggerService();
