/// 日志级别枚举。
enum LogLevel {
  /// 调试级别 - 详细信息。
  debug,

  /// 信息级别 - 常规信息。
  info,

  /// 警告级别 - 潜在问题。
  warning,

  /// 错误级别 - 异常与错误。
  error,
}

/// 云同步日志器。
///
/// 提供简单的日志接口，可接入任意日志框架
/// （如 logger、firebase_crashlytics 等）。
class CloudSyncLogger {
  /// 日志回调函数。
  final void Function(LogLevel level, String message) onLog;

  const CloudSyncLogger({required this.onLog});

  /// 记录调试日志。
  void debug(String message) => onLog(LogLevel.debug, message);

  /// 记录信息日志。
  void info(String message) => onLog(LogLevel.info, message);

  /// 记录警告日志。
  void warning(String message) => onLog(LogLevel.warning, message);

  /// 记录错误日志。
  void error(String message) => onLog(LogLevel.error, message);
}
