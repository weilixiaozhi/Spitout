import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../internal.dart';
import 'session_store.dart';

// ============================================================================
// 2FA(TOTP)
// ============================================================================
// 设计要点:
// - 启用 / 管理 UI 只在 Web 端;App 仅承担"登录时若 server 要 2FA → 弹出输码视图"
// - 两处登录入口(cloud_service_page 配置确认 / spitout_cloud_sync_page 重新登录)
//   不感知 2FA — 只 await `signInWithAccount()`,2FA 流程被封装在 service 内部
// - service 通过 `SpitoutCloudProvider.globalTwoFactorHandler` 拿到回调,
//   handler 由 App 在启动时注册(典型实现:用全局 navigator key push 一个
//   `Login2FAChallengeView`,等用户输完码后 resolve)

/// 当 server 返回 requires_2fa=true 时,通过 [TwoFactorChallengeHandler] 传给 App。
///
/// `verify` 由 service 注入:UI 在用户输完码点验证后调它,
/// 返回 null = 验证通过(UI 应关闭对话框并让 handler 返回 true),
/// 返回非 null 字符串 = 错误信息(UI 就地展示,让用户重试)。
///
/// 这样 view 留在原地,失败可重试,不再"输错就跳走没提示"。
class TwoFactorChallengeRequest {
  final String challengeToken;
  final List<String> availableMethods; // ['totp', 'recovery_code']
  final String account;
  final Future<String?> Function(String method, String code) verify;

  const TwoFactorChallengeRequest({
    required this.challengeToken,
    required this.availableMethods,
    required this.account,
    required this.verify,
  });
}

/// 处理 2FA challenge 的回调。返回 true = 验证已通过(view 内调 verify 返回 null),
/// false = 用户取消 / 关闭对话框。
typedef TwoFactorChallengeHandler = Future<bool> Function(
  TwoFactorChallengeRequest request,
);

/// `/auth/2fa/status` 响应。
class TwoFactorStatus {
  final bool enabled;
  final DateTime? enabledAt;

  const TwoFactorStatus({required this.enabled, this.enabledAt});
}

/// 用户在 2FA 输码视图取消了流程 — 把它当成普通登录失败抛出去。
class TwoFactorCancelledException implements Exception {
  final String message;
  const TwoFactorCancelledException(
      [this.message = '2FA verification cancelled']);
  @override
  String toString() => 'TwoFactorCancelledException: $message';
}

class _SpitoutDeviceMetadata {
  const _SpitoutDeviceMetadata({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.appVersion,
    this.osVersion,
    this.deviceModel,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String? appVersion;
  final String? osVersion;
  final String? deviceModel;
}

class SpitoutCloudAuthService implements CloudAuthService {
  SpitoutCloudAuthService({
    required this.baseUrl,
    required this.apiPrefix,
    http.Client? httpClient,
    TwoFactorChallengeHandler? twoFactorHandler,
    SpitoutCloudSessionStore? sessionStore,
    CloudSyncLogger? logger,
    Duration silentRecoveryCooldown = const Duration(seconds: 30),
  })  : _httpClient = httpClient ?? defaultHttpClient(),
        _twoFactorHandler = twoFactorHandler,
        _sessionStore = sessionStore ?? _defaultSessionStore(),
        _logger = logger ?? defaultCloudLogger,
        _silentRecoveryCooldown = silentRecoveryCooldown;

  final String baseUrl;
  final String apiPrefix;
  final http.Client _httpClient;
  final TwoFactorChallengeHandler? _twoFactorHandler;
  final SpitoutCloudSessionStore _sessionStore;
  final CloudSyncLogger _logger;

  /// 默认会话存储:生产走系统安全存储;`flutter test` 环境没有平台通道,
  /// 自动回退到 SharedPreferences 测试实现,避免每个测试都手动注入。
  ///
  /// 仅当未显式注入 [sessionStore] 时生效;显式注入优先级最高。
  static SpitoutCloudSessionStore _defaultSessionStore() {
    // flutter test 会向测试进程注入 FLUTTER_TEST=true 环境变量
    // (非编译期 dart-define),运行时判断即可区分测试与生产。
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      return SharedPreferencesSessionStore();
    }
    return FlutterSecureStorageSessionStore();
  }

  final StreamController<CloudUser?> _authStateController =
      StreamController<CloudUser?>.broadcast();

  _SpitoutCloudSession? _session;
  _SpitoutDeviceMetadata? _deviceMetadataCache;
  Future<_SpitoutDeviceMetadata>? _deviceMetadataFuture;

  /// 离线恢复凭证:token 全部失效(refresh_token 过期 / server 认不出来)时,
  /// 如果注入了邮密,currentUser/requireAccessToken 会用这对凭证自动再登一次,
  /// 让 API 调用方无感恢复,不用用户手动去配置页点确定。
  String? _recoveryAccount;
  String? _recoveryPassword;
  Future<CloudUser>? _recoveryInFlight;

  /// 静默恢复失败后冷却到这个时间点,期间所有 currentUser / requireAccessToken
  /// 调用都直接返 null,**不再发新的 /auth/login 请求**。
  /// 防止 UI 频繁 rebuild 导致 silent recovery 狂打 login 撞上 server 30/min 限流,
  /// 后果是用户主动点「重新登录」时反而被 429 挡掉。
  /// 触发场景:
  ///   - 服务端开了 2FA,silent 模式拿到 requires_2fa=true 后立即 cancel
  ///   - 邮密被改了 / 账号被禁
  ///   - server 暂时 5xx
  /// 登录成功后会清掉(见 _saveSession)。
  DateTime? _silentRecoveryCooldownUntil;
  final Duration _silentRecoveryCooldown;

  /// 连续被 server 明确拒绝(401/403)的次数;达到阈值后停用恢复凭证,
  /// 避免密码被改后每次冷却结束都自动打一次注定失败的 /auth/login。
  int _consecutiveCredentialRejections = 0;

  /// 连续拒绝阈值:达到后清空恢复邮密,仅保留手动登录入口。
  static const _maxCredentialRejectionsBeforeDisableRecovery = 3;

  void setRecoveryCredentials({String? account, String? password}) {
    _recoveryAccount = (account != null && account.isNotEmpty) ? account : null;
    _recoveryPassword =
        (password != null && password.isNotEmpty) ? password : null;
    // 凭证更新 = 用户在 cloud 配置页保存了新邮密 / 切回 Spitout,清掉旧冷却,
    // 让下一次 currentUser 立刻尝试一次新凭证的登录。
    _silentRecoveryCooldownUntil = null;
    // 新凭证重新计数,给新邮密完整的尝试机会。
    _consecutiveCredentialRejections = 0;
  }

  String get _sessionStorageKey {
    final raw = '$baseUrl|$apiPrefix';
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'spitout_cloud_session_$digest';
  }

  String get _localDeviceIdStorageKey {
    final raw = '$baseUrl|$apiPrefix';
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'spitout_cloud_local_device_id_$digest';
  }

  Future<void> initialize() async {
    var raw = await _sessionStore.read(_sessionStorageKey);
    if (raw == null || raw.isEmpty) {
      raw = await _migrateLegacySession();
      if (raw == null || raw.isEmpty) return;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _session = _SpitoutCloudSession.fromJson(json);
      if (_isAccessTokenExpired(_session!)) {
        // fire-and-forget:refresh 走网络,坏网络下可能耗到 15s 超时,
        // 不能阻塞 App 启动链路。失败分流已在 _doRefreshSession 内部处理
        // (瞬时故障保留 session,401/403 才清),_refreshInFlight 保证去重。
        unawaited(_refreshSessionOrClear());
      } else {
        _emitCurrentUser();
      }
    } catch (error) {
      // 本地缓存的 session JSON 损坏(解析失败),数据不可信,清理本地 session,
      // 后续由 UI 走静默恢复或手动登录。
      _logger.warning('[SpitoutCloud-Auth] 读取本地 session 失败,已清理: $error');
      await _clearSession();
    }
  }

  /// 把旧版本落在 SharedPreferences 的明文 session 迁移到安全存储。
  ///
  /// 返回迁移后的 JSON;无旧数据或旧数据损坏时返回 null。
  Future<String?> _migrateLegacySession() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_sessionStorageKey);
    if (legacy == null || legacy.isEmpty) return null;
    try {
      // 先验证可解析,避免把损坏数据搬进安全存储。
      jsonDecode(legacy);
      await _sessionStore.write(_sessionStorageKey, legacy);
      await prefs.remove(_sessionStorageKey);
      _logger.info('[SpitoutCloud-Auth] 已把旧版 session 迁移到安全存储');
      return legacy;
    } catch (error) {
      _logger.warning('[SpitoutCloud-Auth] 旧版 session 数据损坏,清理: $error');
      await prefs.remove(_sessionStorageKey);
      return null;
    }
  }

  @override
  Stream<CloudUser?> get authStateChanges => _authStateController.stream;

  @override
  Future<CloudUser?> get currentUser async {
    final session = _session;
    if (session == null) {
      // 完全没 session(从没登过 / session 被清了):只有带了恢复凭证才尝试
      // 自动重登,否则按未登录返回 null 让 UI 显示登录入口。
      return _tryRecoveryLogin();
    }
    if (_isAccessTokenExpired(session)) {
      final refreshed = await tryRefreshSession();
      if (!refreshed) {
        // refresh 失败 → 凭证兜底。
        return _tryRecoveryLogin();
      }
    }
    final latest = _session;
    if (latest == null) return null;
    return _toCloudUser(latest);
  }

  Future<String> requireAccessToken() async {
    final session = _session;
    if (session == null) {
      final recovered = await _tryRecoveryLogin();
      if (recovered == null || _session == null) {
        // 本地没有 session 且静默恢复失败,按未认证处理;记录日志便于排查
        // "session 何时被清 / 恢复为何失败"。
        _logger.warning(
            '[SpitoutCloud-Auth] requireAccessToken: 本地无 session 且静默恢复失败,抛出未认证');
        throw CloudNotAuthenticatedException();
      }
      return _session!.accessToken;
    }
    if (_isAccessTokenExpired(session)) {
      final refreshed = await tryRefreshSession();
      if (!refreshed || _session == null) {
        final recovered = await _tryRecoveryLogin();
        if (recovered == null || _session == null) {
          _logger.warning(
              '[SpitoutCloud-Auth] requireAccessToken: session 已过期且恢复失败,抛出未认证');
          throw CloudNotAuthenticatedException(
              'Session expired, please login again.');
        }
        return _session!.accessToken;
      }
    }
    return _session!.accessToken;
  }

  /// 凭恢复邮密自动重登一次。并发多次调用只跑一个请求,其他调用方共享结果。
  /// 没邮密 / 登录失败都返回 null(不抛),让上层按"未登录"路径处理。
  ///
  /// 失败后进 30 秒冷却期(见 [_silentRecoveryCooldownUntil] 注释):
  /// 防止 UI 频繁 rebuild 导致每次都 POST /auth/login,撞 server 30/min 限流,
  /// 让用户主动点「重新登录」时反而被 429 挡掉。
  Future<CloudUser?> _tryRecoveryLogin() async {
    final account = _recoveryAccount;
    final password = _recoveryPassword;
    if (account == null || password == null) return null;

    // 冷却期内直接返 null,不打网络请求
    final cooldown = _silentRecoveryCooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      return null;
    }

    final existing = _recoveryInFlight;
    if (existing != null) {
      try {
        return await existing;
      } catch (_) {
        return null;
      }
    }
    // 后台恢复用 silent 模式:遇到 2FA 不弹 dialog,直接当登录失败处理,
    // 让用户在 sync page 主动点「重新登录」时再触发。
    final future = _signInWithAccountSilent(account: account, password: password);
    _recoveryInFlight = future;
    try {
      return await future;
    } on CredentialsRejectedException catch (error) {
      // 失败 → 启冷却,30 秒内别再敲 server
      _silentRecoveryCooldownUntil =
          DateTime.now().add(_silentRecoveryCooldown);
      // 凭证被明确拒绝:累计计数,达到阈值后停用恢复邮密,避免无限重试
      // 注定失败的登录请求(例如密码已被修改)。
      _consecutiveCredentialRejections++;
      if (_consecutiveCredentialRejections >=
          _maxCredentialRejectionsBeforeDisableRecovery) {
        _recoveryAccount = null;
        _recoveryPassword = null;
        _logger.warning('[SpitoutCloud-Auth] 恢复凭证连续被拒 '
            '$_maxCredentialRejectionsBeforeDisableRecovery 次,已停用静默恢复,请手动登录');
      } else {
        _logger.warning('[SpitoutCloud-Auth] 静默恢复登录被拒(${error.message}),'
            '进入 ${_silentRecoveryCooldown.inSeconds}s 冷却期');
      }
      return null;
    } catch (error) {
      // 瞬时故障(网络 / 5xx / 2FA 取消):只启冷却,不动恢复凭证。
      _silentRecoveryCooldownUntil =
          DateTime.now().add(_silentRecoveryCooldown);
      _logger.warning('[SpitoutCloud-Auth] 静默恢复登录瞬时失败,进入 '
          '${_silentRecoveryCooldown.inSeconds}s 冷却期: $error');
      return null;
    } finally {
      _recoveryInFlight = null;
    }
  }

  String? get currentDeviceId => _session?.deviceId;
  String? get currentUserId => _session?.userId;

  /// 静默恢复冷却剩余时间;非冷却期(包括未登录首页、恢复成功、2FA 取消等)返回 null。
  ///
  /// 设计意图(依赖方向:core ← 主工程):把"是否正在静默恢复"这个内部状态
  /// 以只读 getter 暴露给上层,让健康检测 / UI 在收到未认证异常时,能区分
  /// "冷却中(稍后自动重试)"与"彻底失败(需手动登录)",从而给出友好提示而非
  /// 把 raw 异常丢给用户。核心包不反向依赖任何 adapter / 主工程。
  Duration? get remainingRecoveryCooldown {
    final cooldown = _silentRecoveryCooldownUntil;
    if (cooldown == null) return null;
    final diff = cooldown.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// access_token 是否仍然可用(存在且未过期)。
  ///
  /// 设计意图(依赖方向:core 包内部):供 realtime client 在 WS 重连前判断
  /// 是否需要 refresh —— token 还有效就直接复用,避免每次重连都无条件旋转
  /// refresh token。只读、不产生副作用,不破坏 auth 内部状态封装。
  bool get hasUsableAccessToken {
    final session = _session;
    return session != null && !_isAccessTokenExpired(session);
  }

  /// Refresh 请求去重的 in-flight future。
  ///
  /// server 用 rotating refresh token:每次 /auth/refresh 都旋转 — 老 token 立刻
  /// revoke,返回新 token。如果 cold start 时 initialize() 看到 access_token 过期
  /// 同步触发一次 refresh,UI 又同时调 currentUser/requireAccessToken 触发另一次,
  /// 两个 POST 用的是 SAME 老 refresh_token → 第一个成功(新 token 入库,老 token
  /// revoke)→ 第二个用已 revoke 的老 token → 401 → _clearSession() 把刚保存的
  /// 新 session 也清掉。下次启动就回到"silent recovery 撞 2FA"的循环。
  ///
  /// 用 in-flight dedup 让并发调用共享同一个 refresh future,只发一次 server 请求。
  Future<bool>? _refreshInFlight;

  Future<bool> tryRefreshSession() async {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }
    final future = _doRefreshSession();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _doRefreshSession() async {
    try {
      await _refreshSession();
      return true;
    } on CredentialsRejectedException catch (error) {
      // 凭证彻底失效:server 明确返回 401/403,说明 refresh token
      // 已被 revoke 或过期,继续保留只会反复失败 → 此时才允许清 session。
      // 后续由 UI 走静默恢复或手动登录。
      _consecutiveCredentialRejections++;
      if (_consecutiveCredentialRejections >=
          _maxCredentialRejectionsBeforeDisableRecovery) {
        _recoveryAccount = null;
        _recoveryPassword = null;
        _logger.warning('[SpitoutCloud-Auth] refresh 连续被拒 '
            '$_maxCredentialRejectionsBeforeDisableRecovery 次,'
            '已停用静默恢复,请手动登录');
      }
      _logger.warning('[SpitoutCloud-Auth] refresh 被 server 拒绝(凭证失效),'
          '清理本地 session: ${error.message}');
      await _clearSession();
      return false;
    } catch (error) {
      // 瞬时故障:网络抖动 / DNS 失败 / 429 限流 / 5xx 等。
      // 关键设计:保留旧 _session 兜底,只返回 false 不清理 —— 避免一次
      // 网络抖动就触发 _clearSession() → _authStateController.add(null)
      // 连锁误登出,导致 WS 重连拿不到 token、UI 报 "User not authenticated"。
      // 旧 access_token 若尚未过期仍可继续用;refresh token 依然有效,
      // 下一次调用 tryRefreshSession() 会自动重试。
      _logger.warning('[SpitoutCloud-Auth] refresh 瞬时失败(网络/服务端),'
          '保留本地 session 待重试: $error');
      return false;
    }
  }

  Future<Map<String, dynamic>> _buildAuthBody({
    required String account,
    required String password,
  }) async {
    final metadata = await _resolveDeviceMetadata();
    return <String, dynamic>{
      'account': account,
      'password': password,
      'device_id': metadata.deviceId,
      'device_name': metadata.deviceName,
      'platform': metadata.platform,
      if (metadata.appVersion != null) 'app_version': metadata.appVersion,
      if (metadata.osVersion != null) 'os_version': metadata.osVersion,
      if (metadata.deviceModel != null) 'device_model': metadata.deviceModel,
    };
  }

  Future<_SpitoutDeviceMetadata> _resolveDeviceMetadata() {
    final cached = _deviceMetadataCache;
    if (cached != null) {
      return Future.value(cached);
    }
    final inflight = _deviceMetadataFuture;
    if (inflight != null) {
      return inflight;
    }
    final future = _loadDeviceMetadata();
    _deviceMetadataFuture = future;
    return future.then((value) {
      _deviceMetadataCache = value;
      _deviceMetadataFuture = null;
      return value;
    }).catchError((error) {
      _deviceMetadataFuture = null;
      throw error;
    });
  }

  Future<_SpitoutDeviceMetadata> _loadDeviceMetadata() async {
    final localDeviceId = await _resolveOrCreateLocalDeviceId();
    String deviceName = 'Spitout App';
    String platform = 'flutter';
    String? appVersion;
    String? osVersion;
    String? deviceModel;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = trimOrNull(packageInfo.version);
      final buildNumber = trimOrNull(packageInfo.buildNumber);
      appVersion = trimOrNull(joinNonEmpty([version, buildNumber]));
      deviceName = firstNonEmpty(
        [packageInfo.appName, deviceName],
        fallback: deviceName,
      );
    } catch (_) {
      // Ignore package info failure and fall back to defaults.
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await deviceInfo.webBrowserInfo;
        platform = 'web';
        osVersion = trimOrNull(web.platform);
        deviceModel = trimOrNull(web.userAgent);
        deviceName = firstNonEmpty(
          [
            web.browserName.name,
            deviceName,
          ],
          fallback: deviceName,
        );
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await deviceInfo.androidInfo;
            platform = 'android';
            osVersion = joinNonEmpty(
              ['Android', trimOrNull(info.version.release)],
            );
            deviceModel = joinNonEmpty([
              trimOrNull(info.brand),
              trimOrNull(info.model),
            ]);
            deviceName = firstNonEmpty(
              [info.brand, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.iOS:
            final info = await deviceInfo.iosInfo;
            platform = 'ios';
            osVersion = joinNonEmpty([
              trimOrNull(info.systemName),
              trimOrNull(info.systemVersion),
            ]);
            deviceModel = joinNonEmpty([
              trimOrNull(info.model),
              trimOrNull(info.utsname.machine),
            ]);
            deviceName = firstNonEmpty(
              [info.name, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.macOS:
            final info = await deviceInfo.macOsInfo;
            platform = 'macos';
            osVersion = joinNonEmpty([
              trimOrNull(info.osRelease),
              trimOrNull(info.arch),
            ]);
            deviceModel = joinNonEmpty([
              trimOrNull(info.model),
              trimOrNull(info.hostName),
            ]);
            deviceName = firstNonEmpty(
              [info.computerName, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.windows:
            final info = await deviceInfo.windowsInfo;
            platform = 'windows';
            osVersion = joinNonEmpty([
              trimOrNull(info.displayVersion),
              trimOrNull(info.releaseId),
            ]);
            deviceModel = joinNonEmpty([
              trimOrNull(info.productName),
              trimOrNull(info.deviceId),
            ]);
            deviceName = firstNonEmpty(
              [info.computerName, info.productName, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.linux:
            final info = await deviceInfo.linuxInfo;
            platform = 'linux';
            osVersion = joinNonEmpty([
              trimOrNull(info.prettyName),
              trimOrNull(info.version),
            ]);
            deviceModel = joinNonEmpty([
              trimOrNull(info.machineId),
              trimOrNull(info.id),
            ]);
            deviceName = firstNonEmpty(
              [info.name, info.prettyName, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.fuchsia:
            platform = 'fuchsia';
            break;
        }
      }
    } catch (_) {
      // Ignore device info failure and keep fallback values.
    }

    return _SpitoutDeviceMetadata(
      deviceId: localDeviceId,
      deviceName: deviceName,
      platform: platform,
      appVersion: trimOrNull(appVersion),
      osVersion: trimOrNull(osVersion),
      deviceModel: trimOrNull(deviceModel),
    );
  }

  Future<String> _resolveOrCreateLocalDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = trimOrNull(prefs.getString(_localDeviceIdStorageKey));
    if (existing != null) {
      return existing;
    }
    final next = _generateLocalDeviceId();
    await prefs.setString(_localDeviceIdStorageKey, next);
    return next;
  }

  String _generateLocalDeviceId() {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final digest = sha1
        .convert(utf8.encode(
            '$baseUrl|$apiPrefix|$now|${DateTime.now().millisecondsSinceEpoch}'))
        .toString();
    return 'dev_${digest.substring(0, 32)}';
  }

  @override
  Future<CloudUser> signInWithAccount({
    required String account,
    required String password,
  }) async {
    final body = await _buildAuthBody(account: account, password: password);
    try {
      final session = await _authenticate(
        path: '/auth/login',
        body: body,
        actionName: 'login',
      );
      return _toCloudUser(session);
    } on CredentialsRejectedException catch (error) {
      // 公开登录入口面向 UI,必须抛 CloudAuthException;
      // 内部异常只用于静默恢复的失败计数分流。
      throw CloudAuthException(error.message);
    }
  }

  /// 内部用:登录但**不弹** 2FA dialog。供后台 token recovery / 自动登录场景调用,
  /// 避免用户没主动操作就被弹出输码框。如果服务端要求 2FA 而我们处于 silent 模式,
  /// 抛 [TwoFactorCancelledException],调用方用 try/catch 当作"恢复失败"处理,
  /// 让 UI 上的「重新登录」按钮继续兜底(那条路径走的是公开 signInWithAccount,会弹)。
  Future<CloudUser> _signInWithAccountSilent({
    required String account,
    required String password,
  }) async {
    final body = await _buildAuthBody(account: account, password: password);
    final session = await _authenticate(
      path: '/auth/login',
      body: body,
      actionName: 'login',
      silent2fa: true,
    );
    return _toCloudUser(session);
  }

  @override
  Future<CloudUser> signUpWithAccount({
    required String account,
    required String password,
  }) async {
    final body = await _buildAuthBody(account: account, password: password);
    try {
      final session = await _authenticate(
        path: '/auth/register',
        body: body,
        actionName: 'register',
      );
      return _toCloudUser(session);
    } on CredentialsRejectedException catch (error) {
      throw CloudAuthException(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    // 无论本地 session 是否仍在,登出都必须清空静默恢复邮密。
    // 若不清,provider 重建 / UI rebuild 后 currentUser 会拿旧邮密
    // 自动 POST /auth/login 把已登出的账号"复活"回来——这就是复活链根因:
    // 用户明明点了登出,下一轮鉴权探测又被静默登录,云端账本也被重新拉回。
    _recoveryAccount = null;
    _recoveryPassword = null;
    _consecutiveCredentialRejections = 0;
    final session = _session;
    if (session == null) {
      return;
    }

    try {
      await _request(
        method: 'POST',
        path: '/auth/logout',
        body: {'refresh_token': session.refreshToken},
        accessToken: session.accessToken,
      );
    } catch (_) {
      // Ignore network/logout errors and clear local session directly.
    } finally {
      await _clearSession();
    }
  }

  @override
  Future<void> sendPasswordResetAccount({required String account}) async {
    throw CloudAuthException(
        'Spitout Cloud v1 does not support password reset.');
  }

  @override
  Future<void> resendAccountVerification({required String account}) async {
    throw CloudAuthException(
        'Spitout Cloud v1 does not require account verification.');
  }

  void dispose() {
    _authStateController.close();
    _httpClient.close();
  }

  Future<_SpitoutCloudSession> _authenticate({
    required String path,
    required Map<String, dynamic> body,
    required String actionName,
    bool silent2fa = false,
  }) async {
    final response = await _request(method: 'POST', path: path, body: body);
    // 401/403 视为凭证被 server 明确拒绝(密码错 / 账号禁用 / 登录限流前失效),
    // 用内部异常分流:公开入口转 CloudAuthException,静默恢复入口做失败计数。
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CredentialsRejectedException(
          '${actionName[0].toUpperCase()}${actionName.substring(1)} failed: '
          '${extractErrorMessage(response)}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAuthException(
          '${actionName[0].toUpperCase()}${actionName.substring(1)} failed: ${extractErrorMessage(response)}');
    }

    final payload = decodeJsonObject(response.body);

    // server 返回 requires_2fa=true → 弹 challenge UI 拿 6 位码,POST /auth/2fa/verify
    // 兑换真 token。register 不会要 2FA(新用户尚未启用),仅 login 路径会进这个分支。
    if (payload['requires_2fa'] == true) {
      // 后台 token recovery / 自动恢复登录场景:silent2fa=true,直接跑 cancel 异常,
      // 不弹 dialog。让 UI 上的「重新登录」按钮触发用户感知到的登录,那条路径走的是
      // 公开 signInWithAccount,会正常弹。
      if (silent2fa) {
        throw const TwoFactorCancelledException(
            '2FA required but skipped in silent recovery mode');
      }
      return _handleTwoFactorChallenge(
        loginBody: body,
        challengePayload: payload,
      );
    }

    final session = _SpitoutCloudSession.fromAuthResponse(payload);
    await _saveSession(session);
    return session;
  }

  Future<_SpitoutCloudSession> _handleTwoFactorChallenge({
    required Map<String, dynamic> loginBody,
    required Map<String, dynamic> challengePayload,
  }) async {
    final challengeToken = challengePayload['challenge_token'];
    if (challengeToken is! String || challengeToken.isEmpty) {
      throw CloudAuthException(
          'Login response advertised requires_2fa but no challenge_token.');
    }
    final rawMethods = challengePayload['available_methods'];
    final methods = (rawMethods is List)
        ? rawMethods.whereType<String>().toList()
        : <String>['totp', 'recovery_code'];

    final handler = _twoFactorHandler;
    if (handler == null) {
      throw CloudAuthException(
          'Server requires 2FA but no TwoFactorChallengeHandler is registered. '
          'Set SpitoutCloudProvider.globalTwoFactorHandler at app startup.');
    }

    // verify callback:UI 输完码点验证 → 调这个 → 命中就保存 session,
    // 返回 null,UI 关闭;失败返回 server 错误消息,UI 就地展示让用户重试。
    _SpitoutCloudSession? successSession;

    Future<String?> verify(String method, String code) async {
      final verifyBody = Map<String, dynamic>.of(loginBody)
        ..remove('account')
        ..remove('password');
      verifyBody['challenge_token'] = challengeToken;
      verifyBody['method'] = method;
      verifyBody['code'] = code;
      verifyBody['client_type'] ??= 'app';

      final verifyResp = await _request(
        method: 'POST',
        path: '/auth/2fa/verify',
        body: verifyBody,
      );
      if (verifyResp.statusCode < 200 || verifyResp.statusCode >= 300) {
        return extractErrorMessage(verifyResp);
      }
      final verifyPayload = decodeJsonObject(verifyResp.body);
      final session = _SpitoutCloudSession.fromAuthResponse(verifyPayload);
      await _saveSession(session);
      successSession = session;
      return null;
    }

    final ok = await handler(TwoFactorChallengeRequest(
      challengeToken: challengeToken,
      availableMethods: methods,
      account: (loginBody['account'] as String?) ?? '',
      verify: verify,
    ));
    if (!ok || successSession == null) {
      throw const TwoFactorCancelledException();
    }
    return successSession!;
  }

  /// GET /auth/2fa/status — UI 用来在云同步页展示「已启用 ✓ / 未启用」状态行。
  Future<TwoFactorStatus> getTwoFactorStatus() async {
    final accessToken = await requireAccessToken();
    final response = await _request(
      method: 'GET',
      path: '/auth/2fa/status',
      accessToken: accessToken,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAuthException(
          'Get 2FA status failed: ${extractErrorMessage(response)}');
    }
    final payload = decodeJsonObject(response.body);
    final enabledAtRaw = payload['enabled_at'];
    DateTime? enabledAt;
    if (enabledAtRaw is String && enabledAtRaw.isNotEmpty) {
      enabledAt = DateTime.tryParse(enabledAtRaw)?.toLocal();
    }
    return TwoFactorStatus(
      enabled: payload['enabled'] == true,
      enabledAt: enabledAt,
    );
  }

  Future<void> _refreshSessionOrClear() async {
    // 走 tryRefreshSession 拿到 in-flight 去重保护,避免跟 currentUser/requireAccessToken
    // 并发的 refresh 撞 server 的 rotating refresh token 机制。
    await tryRefreshSession();
  }

  Future<void> _refreshSession() async {
    final session = _session;
    if (session == null) {
      throw CloudNotAuthenticatedException();
    }

    final response = await _request(
      method: 'POST',
      path: '/auth/refresh',
      body: {'refresh_token': session.refreshToken},
    );
    // 401/403 = server 明确拒绝该 refresh token(已 revoke/过期),属于凭证
    // 彻底失效;其余非 2xx(429/5xx 等)视为瞬时故障,由上层保留 session 重试。
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CredentialsRejectedException(
          'HTTP ${response.statusCode}: ${extractErrorMessage(response)}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAuthException(
          'Refresh token failed: ${extractErrorMessage(response)}');
    }

    final payload = decodeJsonObject(response.body);
    final refreshed = _SpitoutCloudSession.fromAuthResponse(payload);
    await _saveSession(refreshed);
  }

  Future<void> _saveSession(_SpitoutCloudSession session) async {
    _session = session;
    // 任何成功登录路径都清掉静默恢复冷却与失败计数,避免之前的失败状态拖到现在。
    _silentRecoveryCooldownUntil = null;
    _consecutiveCredentialRejections = 0;
    final encoded = jsonEncode(session.toJson());
    await _sessionStore.write(_sessionStorageKey, encoded);
    // 同步清理旧版本可能残留在 SharedPreferences 的明文 session。
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
    await prefs.setString(_localDeviceIdStorageKey, session.deviceId);
    final metadata = _deviceMetadataCache;
    if (metadata != null && metadata.deviceId != session.deviceId) {
      _deviceMetadataCache = _SpitoutDeviceMetadata(
        deviceId: session.deviceId,
        deviceName: metadata.deviceName,
        platform: metadata.platform,
        appVersion: metadata.appVersion,
        osVersion: metadata.osVersion,
        deviceModel: metadata.deviceModel,
      );
    }
    _emitCurrentUser();
  }

  Future<void> _clearSession() async {
    _session = null;
    await _sessionStore.remove(_sessionStorageKey);
    // 顺带清理旧版本明文残留,避免安全存储被清后老数据又"复活"。
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
    _authStateController.add(null);
  }

  void _emitCurrentUser() {
    final session = _session;
    if (session == null) {
      _authStateController.add(null);
      return;
    }
    _authStateController.add(_toCloudUser(session));
  }

  CloudUser _toCloudUser(_SpitoutCloudSession session) {
    return CloudUser(
      id: session.userId,
      account: session.account,
      metadata: {
        'provider': 'spitout_cloud',
        'deviceId': session.deviceId,
      },
    );
  }

  bool _isAccessTokenExpired(_SpitoutCloudSession session) {
    final now = DateTime.now().toUtc();
    return now.isAfter(
        session.accessTokenExpiresAt.subtract(const Duration(seconds: 30)));
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix$path');
    if (!isHttpTransportAllowed(uri)) {
      // 远程地址强制 https:防止账号 + 密码 / token 明文走网络。
      // localhost 与私网段测试地址除外。
      throw CloudConfigurationException(
        'Insecure HTTP transport is not allowed for remote Spitout Cloud '
        'servers. Use https:// (http is only allowed for localhost or '
        'private-network testing).',
      );
    }
    final request = http.Request(method, uri);
    request.headers['Content-Type'] = 'application/json';
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    return sendWithTimeout(_httpClient, request);
  }
}

class _SpitoutCloudSession {
  const _SpitoutCloudSession({
    required this.userId,
    required this.account,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.deviceId,
  });

  final String userId;
  final String? account;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final String deviceId;

  factory _SpitoutCloudSession.fromAuthResponse(Map<String, dynamic> payload) {
    final user = payload['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth response: user missing');
    }

    final userId = user['id'];
    final accessToken = payload['access_token'];
    final refreshToken = payload['refresh_token'];
    final expiresIn = payload['expires_in'];
    final deviceId = payload['device_id'];

    if (userId is! String ||
        accessToken is! String ||
        refreshToken is! String ||
        expiresIn is! num ||
        deviceId is! String) {
      throw const FormatException('Invalid auth response payload');
    }

    return _SpitoutCloudSession(
      userId: userId,
      account:
          (user['account'] as String?) ?? user['email'] as String?,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt:
          DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt())),
      deviceId: deviceId,
    );
  }

  factory _SpitoutCloudSession.fromJson(Map<String, dynamic> json) {
    return _SpitoutCloudSession(
      userId: json['userId'] as String,
      account: (json['account'] as String?) ?? json['email'] as String?,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessTokenExpiresAt:
          DateTime.parse(json['accessTokenExpiresAt'] as String).toUtc(),
      deviceId: json['deviceId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'account': account,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
      'deviceId': deviceId,
    };
  }
}
