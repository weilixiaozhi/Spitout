import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as s;

/// Supabase implementation of CloudAuthService
class SupabaseAuthService implements CloudAuthService {
  final s.SupabaseClient client;

  SupabaseAuthService(this.client);

  /// 把 Supabase SDK 的鉴权异常归一化为核心包 [CloudAuthException]，
  /// 上层只依赖核心包类型，不感知具体后端 SDK。
  Future<T> _normalizeAuth<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on s.AuthApiException catch (e) {
      throw CloudAuthException(e.message, e, e.code);
    }
  }

  @override
  Stream<CloudUser?> get authStateChanges {
    return client.auth.onAuthStateChange.map((event) {
      final u = event.session?.user;
      return u != null ? CloudUser(id: u.id, account: u.email) : null;
    });
  }

  @override
  Future<CloudUser?> get currentUser async {
    final u = client.auth.currentUser;
    if (u == null) return null;
    return CloudUser(id: u.id, account: u.email);
  }

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<CloudUser> signInWithAccount({
    required String account,
    required String password,
  }) async {
    final res = await _normalizeAuth(
      () => client.auth.signInWithPassword(
        email: account,
        password: password,
      ),
    );
    final u = res.user;
    if (u == null) {
      // 账号验证未完成或服务端未返回会话时 user 为 null，不能强解包。
      throw CloudAuthException(
        '登录成功但未返回用户会话，请检查验证状态或稍后重试',
      );
    }
    return CloudUser(id: u.id, account: u.email);
  }

  @override
  Future<CloudUser> signUpWithAccount({
    required String account,
    required String password,
  }) async {
    final res = await _normalizeAuth(
      () => client.auth.signUp(email: account, password: password),
    );
    final u = res.user;
    if (u == null) {
      // 账号验证未完成或服务端未返回会话时 user 为 null，不能强解包。
      throw CloudAuthException(
        '注册成功但未返回用户会话，请先完成验证后再登录',
      );
    }
    return CloudUser(id: u.id, account: u.email);
  }

  @override
  Future<void> sendPasswordResetAccount({required String account}) async {
    await _normalizeAuth(() => client.auth.resetPasswordForEmail(account));
  }

  @override
  Future<void> resendAccountVerification({required String account}) async {
    await _normalizeAuth(
      () => client.auth.resend(
        type: s.OtpType.signup,
        email: account,
      ),
    );
  }
}
