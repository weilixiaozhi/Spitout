import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 's3_client.dart';

/// S3 认证服务实现
///
/// S3 使用 Access Key 认证，无传统的登录/登出概念
class S3AuthService implements CloudAuthService {
  final S3Client client;
  final String bucket;

  S3AuthService(this.client, this.bucket);

  /// 生成不泄露 Access Key 的用户标识。
  ///
  /// 设计意图：上层可能把 user.id 拼进对象路径或日志，
  /// 直接用 Access Key 会泄露敏感信息，这里取 SHA256 前 8 位。
  String get _userId =>
      's3-${sha256.convert(utf8.encode(client.accessKey)).toString().substring(0, 8)}';

  @override
  String? get currentUserId => _userId;

  Future<CloudUser?> getCurrentUser() async {
    // S3 使用 Access Key 认证，无用户概念
    // 直接返回用户信息，不需要网络验证（类似 WebDAV）
    // 实际的连接验证在 provider.initialize() 时已完成
    return CloudUser(
      id: _userId,
      account: null, // S3 无 account
      metadata: {
        'bucket': bucket,
        'endpoint': client.endpoint,
        'region': client.region,
      },
    );
  }

  @override
  Future<void> signOut() async {
    // S3 无需登出操作
    // 认证信息在 provider dispose 时清除
  }

  @override
  Stream<CloudUser?> get authStateChanges {
    // S3 无状态变化概念，返回固定流
    return Stream.value(CloudUser(
      id: _userId,
      account: null,
      metadata: {
        'bucket': bucket,
        'endpoint': client.endpoint,
        'region': client.region,
      },
    ));
  }

  @override
  Future<CloudUser?> get currentUser async {
    return getCurrentUser();
  }

  @override
  Future<CloudUser> signInWithAccount({
    required String account,
    required String password,
  }) async {
    throw CloudAuthException('S3 does not support account authentication');
  }

  @override
  Future<CloudUser> signUpWithAccount({
    required String account,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    throw CloudAuthException('S3 does not support account registration');
  }

  @override
  Future<void> sendPasswordResetAccount({required String account}) async {
    throw CloudAuthException('S3 does not support password reset');
  }

  @override
  Future<void> resendAccountVerification({required String account}) async {
    throw CloudAuthException('S3 does not support account verification');
  }
}
