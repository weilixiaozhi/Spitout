import 'dart:async';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

/// WebDAV authentication service
///
/// WebDAV uses HTTP Basic Authentication. Once configured with username/password,
/// the user is considered "logged in". This service creates a virtual user
/// based on the username.
class WebDAVAuthService implements CloudAuthService {
  final String username;
  late final StreamController<CloudUser?> _authStateController;
  CloudUser? _currentUser;

  WebDAVAuthService(this.username) {
    // Create virtual user from username
    _currentUser = CloudUser(
      id: username,
      account: '$username@webdav',
    );

    // Create broadcast stream that sends current state on listen
    _authStateController = StreamController<CloudUser?>.broadcast(
      onListen: () {
        if (_currentUser != null) {
          _authStateController.add(_currentUser);
        }
      },
    );
  }

  @override
  Stream<CloudUser?> get authStateChanges {
    return _authStateController.stream;
  }

  @override
  String? get currentUserId => _currentUser?.id;

  @override
  Future<CloudUser?> get currentUser async {
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<CloudUser> signInWithAccount({
    required String account,
    required String password,
  }) async {
    throw CloudAuthException('WebDAV does not support account sign in');
  }

  @override
  Future<CloudUser> signUpWithAccount({
    required String account,
    required String password,
  }) async {
    throw CloudAuthException('WebDAV does not support sign up');
  }

  @override
  Future<void> sendPasswordResetAccount({required String account}) async {
    throw CloudAuthException('WebDAV does not support password reset');
  }

  @override
  Future<void> resendAccountVerification({required String account}) async {
    throw CloudAuthException('WebDAV does not support account verification');
  }

  void dispose() {
    _authStateController.close();
  }
}
