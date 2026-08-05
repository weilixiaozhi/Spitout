import 'package:meta/meta.dart';

/// 已认证的云用户。
@immutable
class CloudUser {
  /// 用户唯一标识。
  final String id;

  /// 用户邮箱（可选，取决于提供方）。
  final String? email;

  /// 附加用户元数据（提供方特有）。
  final Map<String, dynamic>? metadata;

  const CloudUser({
    required this.id,
    this.email,
    this.metadata,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CloudUser(id: $id, email: $email)';
}

/// 云认证服务抽象接口。
abstract class CloudAuthService {
  /// 认证状态变更流。
  ///
  /// 已登录时发出当前用户，未登录时发出 null；
  /// 适合配合 Riverpod StreamProvider 使用。
  Stream<CloudUser?> get authStateChanges;

  /// 获取当前已认证用户。
  ///
  /// 未登录时返回 null。
  Future<CloudUser?> get currentUser;

  /// 使用邮箱 + 密码登录。
  ///
  /// 登录失败时抛出 [CloudAuthException]。
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// 使用邮箱 + 密码注册。
  ///
  /// 注册失败时抛出 [CloudAuthException]。
  /// 注意：部分提供方（如 Supabase）要求邮箱验证。
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  });

  /// 退出当前用户。
  ///
  /// 失败时抛出 [CloudAuthException]。
  Future<void> signOut();

  /// 发送密码重置邮件。
  ///
  /// 失败时抛出 [CloudAuthException]。
  Future<void> sendPasswordResetEmail({required String email});

  /// 重新发送邮箱验证邮件。
  ///
  /// 失败时抛出 [CloudAuthException]。
  Future<void> resendEmailVerification({required String email});
}

/// 无需认证的提供方使用的空实现。
class NoopAuthService implements CloudAuthService {
  @override
  Stream<CloudUser?> get authStateChanges => Stream.value(null);

  @override
  Future<CloudUser?> get currentUser async => null;

  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {
    throw UnsupportedError('Auth is not configured');
  }
}
