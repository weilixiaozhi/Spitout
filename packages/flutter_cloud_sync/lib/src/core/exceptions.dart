/// 云同步异常基类。
///
/// [originalError] 保留原始异常，便于日志排查；上层可按类型区分失败阶段。
class CloudSyncException implements Exception {
  final String message;
  final dynamic originalError;

  CloudSyncException(this.message, [this.originalError]);

  @override
  String toString() {
    if (originalError != null) {
      return 'CloudSyncException: $message (Original error: $originalError)';
    }
    return 'CloudSyncException: $message';
  }
}

/// 用户未登录时抛出。
class CloudNotAuthenticatedException extends CloudSyncException {
  CloudNotAuthenticatedException([String? message])
      : super(message ?? 'User not authenticated');
}

/// 云服务配置无效时抛出。
class CloudConfigurationException extends CloudSyncException {
  CloudConfigurationException(super.message, [super.originalError]);
}

/// 存储操作失败时抛出。
class CloudStorageException extends CloudSyncException {
  /// HTTP 状态码（可选）。用于调用方区分「资源确死」（404/410，可立即执行本地
  /// 清理）与「可能瞬时」（5xx，应走阈值判定防误删）。
  /// 作为第 3 个可选位置参数追加，保持既有 `CloudStorageException(msg, e)`
  /// 调用（originalError 在第 2 位）全部兼容，不破坏现有调用点。
  final int? statusCode;

  CloudStorageException(super.message, [super.originalError, this.statusCode]);
}

/// 数据序列化 / 反序列化或指纹计算失败时抛出。
///
/// 设计意图：序列化属于数据准备阶段，与存储失败（[CloudStorageException]）
/// 是两类问题；上层需要区分「业务数据格式错误」与「云存储不可用」。
class CloudSerializationException extends CloudSyncException {
  CloudSerializationException(super.message, [super.originalError]);
}

/// 认证操作失败时抛出。
class CloudAuthException extends CloudSyncException {
  /// 服务端结构化错误码（如 Supabase 的 `invalid_credentials`），
  /// 供上层按语义映射文案；非结构化来源为 null。
  final String? code;

  CloudAuthException(super.message, [super.originalError, this.code]);
}
