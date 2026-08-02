/// Base exception for all cloud sync errors
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

/// Thrown when user is not authenticated
class CloudNotAuthenticatedException extends CloudSyncException {
  CloudNotAuthenticatedException([String? message])
      : super(message ?? 'User not authenticated');
}

/// Thrown when cloud service configuration is invalid
class CloudConfigurationException extends CloudSyncException {
  CloudConfigurationException(super.message, [super.originalError]);
}

/// Thrown when storage operations fail
class CloudStorageException extends CloudSyncException {
  /// HTTP 状态码(可选)。用于调用方区分「资源确死」(404/410,可立即执行本地
  /// 清理)与「可能瞬时」(5xx,应走阈值判定防误清)。
  /// 作为第 3 个可选位置参数追加,保持既有 `CloudStorageException(msg, e)`
  /// 调用(originalError 在第 2 位)全部兼容,不破坏现有调用点。
  final int? statusCode;

  CloudStorageException(super.message, [super.originalError, this.statusCode]);
}

/// Thrown when authentication operations fail
class CloudAuthException extends CloudSyncException {
  CloudAuthException(super.message, [super.originalError]);
}
