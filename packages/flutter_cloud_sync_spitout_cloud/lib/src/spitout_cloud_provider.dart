import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

// ============================================================================
// 2FA(TOTP)
// ============================================================================
// 设计要点:
// - 启用 / 管理 UI 只在 Web 端;App 仅承担"登录时若 server 要 2FA → 弹出输码视图"
// - 两处登录入口(cloud_service_page 配置确认 / spitout_cloud_sync_page 重新登录)
//   不感知 2FA — 只 await `signInWithEmail()`,2FA 流程被封装在 service 内部
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
  final String email;
  final Future<String?> Function(String method, String code) verify;

  const TwoFactorChallengeRequest({
    required this.challengeToken,
    required this.availableMethods,
    required this.email,
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
  const TwoFactorCancelledException([this.message = '2FA verification cancelled']);
  @override
  String toString() => 'TwoFactorCancelledException: $message';
}

class SpitoutCloudProvider implements CloudProvider {
  /// 在 App 启动时设置一次。auth service 处理 signInWithEmail 时,server
  /// 若返回 requires_2fa=true,会调这个 handler 让 App 弹输码 UI。
  /// 不设置 = 老 App / 服务端未启 2FA 行为不变;若 server 要求 2FA 而 App
  /// 没注册 handler,signInWithEmail 会抛 [CloudAuthException]。
  static TwoFactorChallengeHandler? globalTwoFactorHandler;

  SpitoutCloudAuthService? _auth;
  SpitoutCloudStorageService? _storage;
  SpitoutCloudRealtimeClient? _realtime;

  @override
  String get providerId => 'spitout_cloud';

  @override
  String get providerName => 'Spitout Cloud';

  /// 拼接绝对 URL 用 — 头像 / 附件下载等场景。null = 未初始化。
  String? get baseUrl => _auth?.baseUrl;
  String? get apiPrefix => _auth?.apiPrefix;

  /// 转发 [SpitoutCloudAuthService.remainingRecoveryCooldown]：
  /// 上层（sync_engine_status 等）持有的是 provider 实例而非 auth service，
  /// 通过此只读转发即可判断"静默恢复冷却中/需手动登录"，无需向下转型。
  /// 未初始化（_auth 为 null）时返回 null，语义等同"非冷却期"。
  Duration? get remainingRecoveryCooldown => _auth?.remainingRecoveryCooldown;

  @override
  CloudAuthService get auth {
    final auth = _auth;
    if (auth == null) {
      throw CloudConfigurationException(
          'Spitout Cloud provider is not initialized.');
    }
    return auth;
  }

  @override
  CloudStorageService get storage {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud provider is not initialized.');
    }
    return storage;
  }

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    if (!validateConfig(config)) {
      throw CloudConfigurationException(
          'Invalid Spitout Cloud config. Required: baseUrl');
    }

    final rawBaseUrl = (config['baseUrl'] as String).trim();
    final rawApiPrefix = (config['apiPrefix'] as String?)?.trim();
    final baseUrl = rawBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final apiPrefix = _normalizeApiPrefix(rawApiPrefix ?? '/api/v1');

    final authService = SpitoutCloudAuthService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      twoFactorHandler: SpitoutCloudProvider.globalTwoFactorHandler,
    );
    await authService.initialize();

    _auth = authService;
    final storage = SpitoutCloudStorageService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      auth: authService,
    );
    _storage = storage;
    _realtime = SpitoutCloudRealtimeClient(
      baseUrl: baseUrl,
      auth: authService,
    );
  }

  @override
  bool validateConfig(Map<String, dynamic> config) {
    final baseUrl = config['baseUrl'];
    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      return false;
    }
    final apiPrefix = config['apiPrefix'];
    if (apiPrefix != null && apiPrefix is! String) {
      return false;
    }
    return true;
  }

  @override
  Future<void> dispose() async {
    await _realtime?.stop();
    _realtime?.dispose();
    _realtime = null;
    _storage?.dispose();
    _storage = null;
    _auth?.dispose();
    _auth = null;
  }

  Stream<SpitoutCloudRealtimeEvent> get realtimeEvents {
    final realtime = _realtime;
    if (realtime == null) {
      return const Stream.empty();
    }
    return realtime.events;
  }

  Future<void> startRealtime() async {
    final realtime = _realtime;
    if (realtime == null) {
      throw CloudConfigurationException(
          'Spitout Cloud realtime is not initialized.');
    }
    await realtime.start();
  }

  Future<void> stopRealtime() async {
    await _realtime?.stop();
  }

  Future<SpitoutCloudProfile> getMyProfile() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.getMyProfile();
  }

  /// 转发到 SpitoutCloudAuthService.getTwoFactorStatus,云同步页用它展示状态行。
  Future<TwoFactorStatus> getTwoFactorStatus() async {
    final auth = _auth;
    if (auth == null) {
      throw CloudConfigurationException(
          'Spitout Cloud auth is not initialized.');
    }
    return auth.getTwoFactorStatus();
  }

  Future<SpitoutCloudProfile> updateMyProfileDisplayName({
    required String displayName,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.updateMyProfileDisplayName(displayName: displayName);
  }

  /// 更新主币种(ISO code,如 `CNY`)。单向 mobile → server → web,多币种 MVP
  /// user-level 字段。
  Future<SpitoutCloudProfile> updateMyProfileBaseCurrency({
    required String primaryCurrency,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.updateMyProfileBaseCurrency(
        primaryCurrency: primaryCurrency);
  }

  /// 拉取 server 汇率代理(GET /read/exchange-rates?base=XXX)。server 未开
  /// 代理返回 null,调用方下滑公网源链。
  Future<Map<String, dynamic>?> fetchExchangeRates(
      {required String base}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.fetchExchangeRates(base: base);
  }

  Future<SpitoutCloudAvatarUploadResult> uploadMyAvatar({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.uploadMyAvatar(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }


  /// 更新外观类设置(JSON 形式),当前包括
  /// show_transaction_time 等。字体缩放不进来。
  Future<SpitoutCloudProfile> updateMyProfileAppearance({
    required Map<String, dynamic> appearance,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.updateMyProfileAppearance(appearance: appearance);
  }

  /// 更新 AI 配置(providers / binding / custom_prompt / strategy 等)。
  /// 注意:API key 属于敏感字段,这条 API 只在用户自己的 session 走。
  Future<SpitoutCloudProfile> updateMyProfileAiConfig({
    required Map<String, dynamic> aiConfig,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.updateMyProfileAiConfig(aiConfig: aiConfig);
  }

  /// 下载自己的头像字节流。服务端路径是 `/profile/avatar/{user_id}?v=<v>`，
  /// 跟 `/attachments/{fileId}` 不是一回事 —— 头像存储独立于 attachment，
  /// 不能从 avatar_url 里抠 fileId 走 downloadAttachment。这里给一个专用方法。
  Future<Uint8List> downloadMyAvatar({
    required String userId,
    int? version,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.downloadMyAvatar(userId: userId, version: version);
  }

  /// 删除自己在服务端的头像（DELETE /profile/avatar）。
  ///
  /// 用户在 App 内点「删除头像」时必须连服务端一起删——否则服务端
  /// avatar_version 仍 > 0，下次 syncMyProfile 版本比对不一致会重新下载，
  /// 已删除的头像会"复活"。
  Future<void> deleteMyAvatar() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.deleteMyAvatar();
  }

  /// 拉取增量变更。
  ///
  /// [persistCursor] 默认 true 兼容老 caller。传 false 时,本方法返回 cursor
  /// 但**不**持久化到 SharedPreferences,由 caller 自己在 apply 成功后决定何时
  /// 推进。这是为了避免"cursor 已推进但本地 apply 失败"导致这一页 change 永远
  /// 拉不回的经典 bug。
  Future<SpitoutCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
    bool persistCursor = true,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.pullChanges(
      since: since,
      limit: limit,
      persistCursor: persistCursor,
    );
  }

  /// 推送增量变更（个体实体级别，非 ledger_snapshot 包装）
  Future<void> pushChanges({
    required List<Map<String, dynamic>> changes,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.pushEntityChanges(changes: changes);
  }

  Future<List<SpitoutCloudDevice>> listDevices({
    String view = 'deduped',
    int activeWithinDays = 30,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.listDevices(
      view: view,
      activeWithinDays: activeWithinDays,
    );
  }

  Future<void> revokeDevice({required String deviceId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.revokeDevice(deviceId: deviceId);
  }

  Future<List<SpitoutCloudReadLedger>> readLedgers() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.readLedgers();
  }

  Future<SpitoutCloudReadLedgerDetail> readLedgerDetail({
    required String ledgerId,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.readLedgerDetail(ledgerId: ledgerId);
  }

  Future<SpitoutCloudLedgerStats> readLedgerStats({
    required String ledgerId,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.readLedgerStats(ledgerId: ledgerId);
  }

  /// 拉 server 版本号(公开端点,不需要 token)。用在设置页展示
  /// "Spitout Cloud vX.Y.Z"。失败抛,调用方自己 swallow。
  Future<SpitoutCloudServerVersion> fetchServerVersion() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.fetchServerVersion();
  }

  // ===========================================================================
  // 共享账本(Sprint 2.4):invites + members + shared-resources
  // ===========================================================================

  Future<SpitoutCloudInvite> createInvite({
    required String ledgerId,
    String role = 'editor',
    int expiresInHours = 24,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.createInvite(
      ledgerId: ledgerId, role: role, expiresInHours: expiresInHours,
    );
  }

  Future<List<SpitoutCloudInvite>> listInvites({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.listInvites(ledgerId: ledgerId);
  }

  Future<void> revokeInvite({required String ledgerId, required String code}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.revokeInvite(ledgerId: ledgerId, code: code);
  }

  Future<SpitoutCloudInvitePreview> previewInvite({required String code}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.previewInvite(code: code);
  }

  Future<SpitoutCloudInviteAcceptResult> acceptInvite({required String code}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.acceptInvite(code: code);
  }

  Future<List<SpitoutCloudLedgerMember>> listMembers({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.listMembers(ledgerId: ledgerId);
  }

  Future<SpitoutCloudLedgerMember> updateMemberRole({
    required String ledgerId,
    required String userId,
    required String role,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.updateMemberRole(ledgerId: ledgerId, userId: userId, role: role);
  }

  Future<void> removeMember({required String ledgerId, required String userId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.removeMember(ledgerId: ledgerId, userId: userId);
  }

  /// 退出共享账本(协作者主动退出)。
  ///
  /// 走 `DELETE /members/self` 语义:先 listMembers 找到自己(isSelf 标记),
  /// 再 removeMember(self)。云端移除成员后 server 不再返回该账本,
  /// 因此下次 sync 不会再把它重新插回本地。
  Future<void> leaveLedger({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    // 拉成员列表,定位自己(服务端用 is_self 标记)。
    final members = await storage.listMembers(ledgerId: ledgerId);
    String? selfId;
    for (final m in members) {
      if (m.isSelf) {
        selfId = m.userId;
        break;
      }
    }
    // 自己已不在成员列表(被踢 / 已退出)→ 幂等快路径,无需再 remove。
    if (selfId == null) return;
    // 走 DELETE /members/self:云端移除成员 + 不再返回该账本。
    return storage.removeMember(ledgerId: ledgerId, userId: selfId);
  }

  /// 删除整本账本(Owner 全局删除)。
  ///
  /// 云端删除后 server 会级联踢出所有成员并广播,各客户端收到后清本地。
  Future<void> deleteLedger({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.deleteLedger(ledgerId: ledgerId);
  }

  Future<SpitoutCloudSharedResources> fetchSharedResources({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.fetchSharedResources(ledgerId: ledgerId);
  }

  Future<SpitoutCloudMemberStats> fetchMemberStats({
    required String ledgerId,
    String scope = 'month',
    String? period,
    int? tzOffsetMinutes,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException('Spitout Cloud storage is not initialized.');
    }
    return storage.fetchMemberStats(
      ledgerId: ledgerId,
      scope: scope,
      period: period,
      tzOffsetMinutes: tzOffsetMinutes,
    );
  }

  Future<List<SpitoutCloudReadTransaction>> readTransactions({
    required String ledgerId,
    String? txType,
    String? query,
    DateTime? startAt,
    DateTime? endAt,
    int limit = 200,
    int offset = 0,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.readTransactions(
      ledgerId: ledgerId,
      txType: txType,
      query: query,
      startAt: startAt,
      endAt: endAt,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<SpitoutCloudReadCategory>> readCategories({
    required String ledgerId,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.readCategories(ledgerId: ledgerId);
  }

  Future<SpitoutCloudWriteCommitMeta> writeCreateLedger({
    String? ledgerId,
    required String ledgerName,
    String currency = 'CNY',
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.writeCreateLedger(
      ledgerId: ledgerId,
      ledgerName: ledgerName,
      currency: currency,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeLedgerMeta({
    required String ledgerId,
    required int baseChangeId,
    String? ledgerName,
    String? currency,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.writeLedgerMeta(
      ledgerId: ledgerId,
      baseChangeId: baseChangeId,
      ledgerName: ledgerName,
      currency: currency,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeCreateTransaction({
    required String ledgerId,
    required int baseChangeId,
    required String txType,
    required double amount,
    required DateTime happenedAt,
    String? note,
    String? categoryName,
    String? categoryKind,
    String? categoryId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.writeCreateTransaction(
      ledgerId: ledgerId,
      baseChangeId: baseChangeId,
      txType: txType,
      amount: amount,
      happenedAt: happenedAt,
      note: note,
      categoryName: categoryName,
      categoryKind: categoryKind,
      categoryId: categoryId,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeUpdateTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? txType,
    double? amount,
    DateTime? happenedAt,
    String? note,
    String? categoryName,
    String? categoryKind,
    String? categoryId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.writeUpdateTransaction(
      ledgerId: ledgerId,
      txId: txId,
      baseChangeId: baseChangeId,
      txType: txType,
      amount: amount,
      happenedAt: happenedAt,
      note: note,
      categoryName: categoryName,
      categoryKind: categoryKind,
      categoryId: categoryId,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeDeleteTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.writeDeleteTransaction(
      ledgerId: ledgerId,
      txId: txId,
      baseChangeId: baseChangeId,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeCreateCategory({
    required String ledgerId,
    required int baseChangeId,
    required String name,
    required String kind,
    int? level,
    int? sortOrder,
    String? icon,
    String? parentName,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.writeCreateCategory(
      ledgerId: ledgerId,
      baseChangeId: baseChangeId,
      name: name,
      kind: kind,
      level: level,
      sortOrder: sortOrder,
      icon: icon,
      parentName: parentName,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeUpdateCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? name,
    String? kind,
    int? level,
    int? sortOrder,
    String? icon,
    String? parentName,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.writeUpdateCategory(
      ledgerId: ledgerId,
      categoryId: categoryId,
      baseChangeId: baseChangeId,
      name: name,
      kind: kind,
      level: level,
      sortOrder: sortOrder,
      icon: icon,
      parentName: parentName,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeDeleteCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.writeDeleteCategory(
      ledgerId: ledgerId,
      categoryId: categoryId,
      baseChangeId: baseChangeId,
      requestId: requestId,
      idempotencyKey: idempotencyKey,
    );
  }
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

String? _trimOrNull(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String _firstNonEmpty(List<String?> values, {required String fallback}) {
  for (final value in values) {
    final normalized = _trimOrNull(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return fallback;
}

String _joinNonEmpty(List<String?> values) {
  return values
      .map(_trimOrNull)
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .join(' ')
      .trim();
}

/// 带默认建连超时(10s)的 http.Client 工厂。
///
/// 为什么不用裸 `http.Client()`:其内部 `HttpClient.connectionTimeout` 为 null,
/// 在坏网络(TCP 重传黑洞)下建连可 hang 127s+ 甚至永久,是登录/记账卡死的根因。
http.Client _defaultHttpClient() =>
    IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 10));

/// 统一的"带超时发请求"出口 —— 全文件 6 处 HTTP 出口必须走这里,
/// `grep _sendWithTimeout` 即可审计是否有遗漏出口。
///
/// 双层超时设计:
/// - [sendTimeout]:覆盖建连 + 发请求体 + 读响应头(`client.send`);
/// - [bodyTimeout]:覆盖读响应体(`Response.fromStream`)。
/// 超时抛 dart:async 的 [TimeoutException],上层 catch 已能区分
/// 瞬时网络故障与认证失败,不引入自定义异常类型。
Future<http.Response> _sendWithTimeout(
  http.Client client,
  http.BaseRequest request, {
  Duration sendTimeout = const Duration(seconds: 15),
  Duration bodyTimeout = const Duration(seconds: 30),
}) async {
  final streamed = await client.send(request).timeout(sendTimeout);
  return http.Response.fromStream(streamed).timeout(bodyTimeout);
}

/// refresh token 被 server 明确拒绝(401/403)时抛出的内部异常。
///
/// 设计意图:server 用 rotating refresh token,401/403 意味着 refresh token
/// 已被 revoke / 过期 / 认不出来 —— 凭证「彻底失效」,此时清 session 是正确的。
/// 与之相对,网络抖动 / 429 限流 / 5xx 属于「瞬时故障」,refresh token 本身
/// 仍然有效,绝不能清 session(清了会引发 add(null) 连锁误登出 + WS 重连
/// 拿不到 token → UI 显示 "User not authenticated" 断连)。
/// 仅在本文件内部用于 [_doRefreshSession] 分流,不对外暴露。
class _RefreshTokenRejectedException implements Exception {
  _RefreshTokenRejectedException(this.message);

  final String message;

  @override
  String toString() => '_RefreshTokenRejectedException: $message';
}

class SpitoutCloudAuthService implements CloudAuthService {
  SpitoutCloudAuthService({
    required this.baseUrl,
    required this.apiPrefix,
    http.Client? httpClient,
    TwoFactorChallengeHandler? twoFactorHandler,
    // 保留注入优先(测试可注入 MockClient),默认走带 10s 建连超时的 IOClient。
  })  : _httpClient = httpClient ?? _defaultHttpClient(),
        _twoFactorHandler = twoFactorHandler;

  final String baseUrl;
  final String apiPrefix;
  final http.Client _httpClient;
  final TwoFactorChallengeHandler? _twoFactorHandler;

  final StreamController<CloudUser?> _authStateController =
      StreamController<CloudUser?>.broadcast();

  _SpitoutCloudSession? _session;
  _SpitoutDeviceMetadata? _deviceMetadataCache;
  Future<_SpitoutDeviceMetadata>? _deviceMetadataFuture;

  /// 离线恢复凭证:token 全部失效(refresh_token 过期 / server 认不出来)时,
  /// 如果注入了邮密,currentUser/requireAccessToken 会用这对凭证自动再登一次,
  /// 让 API 调用方无感恢复,不用用户手动去配置页点确定。
  String? _recoveryEmail;
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
  static const _silentRecoveryCooldown = Duration(seconds: 30);

  void setRecoveryCredentials({String? email, String? password}) {
    _recoveryEmail = (email != null && email.isNotEmpty) ? email : null;
    _recoveryPassword =
        (password != null && password.isNotEmpty) ? password : null;
    // 凭证更新 = 用户在 cloud 配置页保存了新邮密 / 切回 Spitout,清掉旧冷却,
    // 让下一次 currentUser 立刻尝试一次新凭证的登录。
    _silentRecoveryCooldownUntil = null;
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
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
    } catch (_) {
      // [Route A] 诊断:本地缓存的 session JSON 损坏(解析失败),数据不可信,
      // 清理本地 session,后续由 UI 走静默恢复或手动登录。
      // 注:refresh 失败已在 _doRefreshSession 内部分流处理(瞬时故障保留
      // session),不会抛到这里。
      debugPrint('[SpitoutCloud-Auth] initialize 读取本地 session 失败,清理本地 session');
      await _clearSession();
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
        // [Route A] 诊断:本地根本没有 session,且静默恢复也没成功。
        // 这正是用户看到的 "User not authenticated" 默认消息来源;
        // 打日志便于日后从 flutter logs 确认"session 何时被清 / 恢复为何失败"。
        debugPrint(
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
          // [Route A] 诊断:session 过期且刷新/静默恢复都失败。
          debugPrint(
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
    final email = _recoveryEmail;
    final password = _recoveryPassword;
    if (email == null || password == null) return null;

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
    final future =
        _signInWithEmailSilent(email: email, password: password);
    _recoveryInFlight = future;
    try {
      return await future;
    } catch (_) {
      // 失败 → 启冷却,30 秒内别再敲 server
      _silentRecoveryCooldownUntil =
          DateTime.now().add(_silentRecoveryCooldown);
      // [Route A] 诊断:静默恢复登录失败(网络抖动/5xx/凭证错误等),
      // 进入冷却期后所有鉴权请求都会直接返 null,用户在 UI 上表现为"偶发未认证"。
      debugPrint(
          '[SpitoutCloud-Auth] 静默恢复登录失败,进入 ${_silentRecoveryCooldown.inSeconds}s 冷却期');
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
    } on _RefreshTokenRejectedException catch (error) {
      // [Route A] 凭证彻底失效:server 明确返回 401/403,说明 refresh token
      // 已被 revoke 或过期,继续保留只会反复失败 → 此时才允许清 session。
      // 后续由 UI 走静默恢复或手动登录。
      debugPrint('[SpitoutCloud-Auth] refresh 被 server 拒绝(凭证失效),'
          '清理本地 session: ${error.message}');
      await _clearSession();
      return false;
    } catch (error) {
      // [Route A] 瞬时故障:网络抖动 / DNS 失败 / 429 限流 / 5xx 等。
      // 关键设计:保留旧 _session 兜底,只返回 false 不清理 —— 避免一次
      // 网络抖动就触发 _clearSession() → _authStateController.add(null)
      // 连锁误登出,导致 WS 重连拿不到 token、UI 报 "User not authenticated"。
      // 旧 access_token 若尚未过期仍可继续用;refresh token 依然有效,
      // 下一次调用 tryRefreshSession() 会自动重试。
      debugPrint('[SpitoutCloud-Auth] refresh 瞬时失败(网络/服务端),'
          '保留本地 session 待重试: $error');
      return false;
    }
  }

  Future<Map<String, dynamic>> _buildAuthBody({
    required String email,
    required String password,
  }) async {
    final metadata = await _resolveDeviceMetadata();
    return <String, dynamic>{
      'email': email,
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
      final version = _trimOrNull(packageInfo.version);
      final buildNumber = _trimOrNull(packageInfo.buildNumber);
      appVersion = _trimOrNull(_joinNonEmpty([version, buildNumber]));
      deviceName = _firstNonEmpty(
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
        osVersion = _trimOrNull(web.platform);
        deviceModel = _trimOrNull(web.userAgent);
        deviceName = _firstNonEmpty(
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
            osVersion = _joinNonEmpty(
              ['Android', _trimOrNull(info.version.release)],
            );
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.brand),
              _trimOrNull(info.model),
            ]);
            deviceName = _firstNonEmpty(
              [info.brand, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.iOS:
            final info = await deviceInfo.iosInfo;
            platform = 'ios';
            osVersion = _joinNonEmpty([
              _trimOrNull(info.systemName),
              _trimOrNull(info.systemVersion),
            ]);
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.model),
              _trimOrNull(info.utsname.machine),
            ]);
            deviceName = _firstNonEmpty(
              [info.name, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.macOS:
            final info = await deviceInfo.macOsInfo;
            platform = 'macos';
            osVersion = _joinNonEmpty([
              _trimOrNull(info.osRelease),
              _trimOrNull(info.arch),
            ]);
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.model),
              _trimOrNull(info.hostName),
            ]);
            deviceName = _firstNonEmpty(
              [info.computerName, info.model, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.windows:
            final info = await deviceInfo.windowsInfo;
            platform = 'windows';
            osVersion = _joinNonEmpty([
              _trimOrNull(info.displayVersion),
              _trimOrNull(info.releaseId),
            ]);
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.productName),
              _trimOrNull(info.deviceId),
            ]);
            deviceName = _firstNonEmpty(
              [info.computerName, info.productName, deviceName],
              fallback: deviceName,
            );
            break;
          case TargetPlatform.linux:
            final info = await deviceInfo.linuxInfo;
            platform = 'linux';
            osVersion = _joinNonEmpty([
              _trimOrNull(info.prettyName),
              _trimOrNull(info.version),
            ]);
            deviceModel = _joinNonEmpty([
              _trimOrNull(info.machineId),
              _trimOrNull(info.id),
            ]);
            deviceName = _firstNonEmpty(
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
      appVersion: _trimOrNull(appVersion),
      osVersion: _trimOrNull(osVersion),
      deviceModel: _trimOrNull(deviceModel),
    );
  }

  Future<String> _resolveOrCreateLocalDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _trimOrNull(prefs.getString(_localDeviceIdStorageKey));
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
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final body = await _buildAuthBody(email: email, password: password);
    final session = await _authenticate(
      path: '/auth/login',
      body: body,
      actionName: 'login',
    );
    return _toCloudUser(session);
  }

  /// 内部用:登录但**不弹** 2FA dialog。供后台 token recovery / 自动登录场景调用,
  /// 避免用户没主动操作就被弹出输码框。如果服务端要求 2FA 而我们处于 silent 模式,
  /// 抛 [TwoFactorCancelledException],调用方用 try/catch 当作"恢复失败"处理,
  /// 让 UI 上的「重新登录」按钮继续兜底(那条路径走的是公开 signInWithEmail,会弹)。
  Future<CloudUser> _signInWithEmailSilent({
    required String email,
    required String password,
  }) async {
    final body = await _buildAuthBody(email: email, password: password);
    final session = await _authenticate(
      path: '/auth/login',
      body: body,
      actionName: 'login',
      silent2fa: true,
    );
    return _toCloudUser(session);
  }

  @override
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final body = await _buildAuthBody(email: email, password: password);
    final session = await _authenticate(
      path: '/auth/register',
      body: body,
      actionName: 'register',
    );
    return _toCloudUser(session);
  }

  @override
  Future<void> signOut() async {
    // 无论本地 session 是否仍在,登出都必须清空静默恢复邮密。
    // 若不清,provider 重建 / UI rebuild 后 currentUser 会拿旧邮密
    // 自动 POST /auth/login 把已登出的账号"复活"回来——这就是复活链根因:
    // 用户明明点了登出,下一轮鉴权探测又被静默登录,云端账本也被重新拉回。
    _recoveryEmail = null;
    _recoveryPassword = null;
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
  Future<void> sendPasswordResetEmail({required String email}) async {
    throw CloudAuthException(
        'Spitout Cloud v1 does not support password reset.');
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {
    throw CloudAuthException(
        'Spitout Cloud v1 does not require email verification.');
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAuthException(
          '${actionName[0].toUpperCase()}${actionName.substring(1)} failed: ${_extractErrorMessage(response)}');
    }

    final payload = _decodeJsonObject(response.body);

    // server 返回 requires_2fa=true → 弹 challenge UI 拿 6 位码,POST /auth/2fa/verify
    // 兑换真 token。register 不会要 2FA(新用户尚未启用),仅 login 路径会进这个分支。
    if (payload['requires_2fa'] == true) {
      // 后台 token recovery / 自动恢复登录场景:silent2fa=true,直接跑 cancel 异常,
      // 不弹 dialog。让 UI 上的「重新登录」按钮触发用户感知到的登录,那条路径走的是
      // 公开 signInWithEmail,会正常弹。
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
        ..remove('email')
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
        return _extractErrorMessage(verifyResp);
      }
      final verifyPayload = _decodeJsonObject(verifyResp.body);
      final session = _SpitoutCloudSession.fromAuthResponse(verifyPayload);
      await _saveSession(session);
      successSession = session;
      return null;
    }

    final ok = await handler(TwoFactorChallengeRequest(
      challengeToken: challengeToken,
      availableMethods: methods,
      email: (loginBody['email'] as String?) ?? '',
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
          'Get 2FA status failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
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
      throw _RefreshTokenRejectedException(
          'HTTP ${response.statusCode}: ${_extractErrorMessage(response)}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAuthException(
          'Refresh token failed: ${_extractErrorMessage(response)}');
    }

    final payload = _decodeJsonObject(response.body);
    final refreshed = _SpitoutCloudSession.fromAuthResponse(payload);
    await _saveSession(refreshed);
  }

  Future<void> _saveSession(_SpitoutCloudSession session) async {
    _session = session;
    // 任何成功登录路径都清掉静默恢复冷却,避免之前的失败状态拖到现在。
    _silentRecoveryCooldownUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
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
      email: session.email,
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
    final request = http.Request(method, uri);
    request.headers['Content-Type'] = 'application/json';
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    return _sendWithTimeout(_httpClient, request);
  }
}

class SpitoutCloudStorageService implements CloudStorageService {
  SpitoutCloudStorageService({
    required this.baseUrl,
    required this.apiPrefix,
    required this.auth,
    http.Client? httpClient,
    // 保留注入优先(测试可注入 MockClient),默认走带 10s 建连超时的 IOClient。
  }) : _httpClient = httpClient ?? _defaultHttpClient();

  final String baseUrl;
  final String apiPrefix;
  final SpitoutCloudAuthService auth;
  final http.Client _httpClient;

  void dispose() {
    _httpClient.close();
  }

  String? _normalizeAbsoluteUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed.toString();
    }
    final normalizedBase = baseUrl.trim();
    if (normalizedBase.isEmpty) {
      return trimmed;
    }
    final base = Uri.parse(
      normalizedBase.endsWith('/') ? normalizedBase : '$normalizedBase/',
    );
    if (parsed != null) {
      if (!parsed.hasScheme && parsed.hasAuthority) {
        final fallbackScheme = base.scheme.isNotEmpty ? base.scheme : 'https';
        return parsed.replace(scheme: fallbackScheme).toString();
      }
      return base.resolveUri(parsed).toString();
    }
    return base.resolve(trimmed).toString();
  }

  Map<String, dynamic> _copyWithNormalizedUrl(
    Map<String, dynamic> source,
    String key,
  ) {
    final raw = source[key];
    final normalized = raw is String ? _normalizeAbsoluteUrl(raw) : null;
    if (raw == normalized) {
      return source;
    }
    final out = Map<String, dynamic>.from(source);
    out[key] = normalized;
    return out;
  }

  @override
  Future<void> upload({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    final ledgerId = _ledgerIdFromPath(path);
    // 先确保 session 有效（触发 token refresh），再读 deviceId
    await auth.requireAccessToken();
    final deviceId = auth.currentDeviceId;
    if (deviceId == null || deviceId.isEmpty) {
      throw CloudNotAuthenticatedException(
          'Missing device id, please login again.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _authedRequest(
      method: 'POST',
      path: '/sync/push',
      body: {
        'device_id': deviceId,
        'changes': [
          {
            'ledger_id': ledgerId,
            'entity_type': 'ledger_snapshot',
            'entity_sync_id': ledgerId,
            'action': 'upsert',
            'payload': {
              'content': data,
              'metadata': metadata ?? <String, String>{},
            },
            'updated_at': now,
          }
        ]
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Upload failed: ${_extractErrorMessage(response)}');
    }
  }

  @override
  Future<String?> download({required String path}) async {
    final ledgerId = _ledgerIdFromPath(path);
    final response = await _authedRequest(
      method: 'GET',
      path: '/sync/full',
      query: {'ledger_id': ledgerId},
    );

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Download failed: ${_extractErrorMessage(response)}');
    }

    final payload = _decodeJsonObject(response.body);
    final snapshot = payload['snapshot'];
    if (snapshot == null || snapshot is! Map<String, dynamic>) {
      return null;
    }

    final changePayload = snapshot['payload'];
    if (changePayload is! Map<String, dynamic>) {
      return null;
    }
    final content = changePayload['content'];
    return content is String ? content : null;
  }

  @override
  Future<void> delete({required String path}) async {
    final ledgerId = _ledgerIdFromPath(path);
    // 先确保 session 有效（触发 token refresh），再读 deviceId
    await auth.requireAccessToken();
    final deviceId = auth.currentDeviceId;
    if (deviceId == null || deviceId.isEmpty) {
      throw CloudNotAuthenticatedException(
          'Missing device id, please login again.');
    }

    final response = await _authedRequest(
      method: 'POST',
      path: '/sync/push',
      body: {
        'device_id': deviceId,
        'changes': [
          {
            'ledger_id': ledgerId,
            'entity_type': 'ledger_snapshot',
            'entity_sync_id': ledgerId,
            'action': 'delete',
            'payload': <String, dynamic>{},
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }
        ]
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Delete failed: ${_extractErrorMessage(response)}');
    }
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    final prefix = PathHelper.normalize(path);
    final response = await _authedRequest(method: 'GET', path: '/sync/ledgers');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List failed: ${_extractErrorMessage(response)}');
    }

    final data = jsonDecode(response.body);
    if (data is! List) {
      return const [];
    }

    final files = <CloudFile>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final ledgerId = item['ledger_id'];
      if (ledgerId is! String || ledgerId.isEmpty) continue;

      if (prefix.isNotEmpty && !ledgerId.startsWith(prefix)) {
        continue;
      }

      final updatedAtRaw = item['updated_at'];
      DateTime? updatedAt;
      if (updatedAtRaw is String && updatedAtRaw.isNotEmpty) {
        updatedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();
      }

      final metadata = item['metadata'];
      files.add(
        CloudFile(
          name: ledgerId,
          path: ledgerId,
          size: (item['size'] as num?)?.toInt(),
          lastModified: updatedAt,
          metadata: metadata is Map<String, dynamic> ? metadata : const {},
        ),
      );
    }
    return files;
  }

  @override
  Future<bool> exists({required String path}) async {
    final metadata = await getMetadata(path: path);
    return metadata != null;
  }

  @override
  Future<CloudFile?> getMetadata({required String path}) async {
    final target = PathHelper.normalize(path);
    if (target.isEmpty) return null;

    final files = await list(path: '');
    for (final file in files) {
      if (PathHelper.normalize(file.path) == target ||
          PathHelper.normalize(file.name) == target) {
        return file;
      }
    }
    return null;
  }

  Future<SpitoutCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
    bool persistCursor = true,
  }) async {
    final currentCursor = since ?? await _loadCursor();
    final query = <String, String>{
      'since': '$currentCursor',
      'limit': '$limit',
    };
    final deviceId = auth.currentDeviceId;
    if (deviceId != null && deviceId.isNotEmpty) {
      query['device_id'] = deviceId;
    }

    final response = await _authedRequest(
      method: 'GET',
      path: '/sync/pull',
      query: query,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Pull failed: ${_extractErrorMessage(response)}');
    }

    final payload = _decodeJsonObject(response.body);
    final rawChanges = payload['changes'];
    final nextCursor =
        (payload['server_cursor'] as num?)?.toInt() ?? currentCursor;
    final hasMore = payload['has_more'] == true;

    final changes = <SpitoutCloudSyncChange>[];
    if (rawChanges is List) {
      for (final row in rawChanges) {
        if (row is! Map<String, dynamic>) {
          continue;
        }
        final changeId = (row['change_id'] as num?)?.toInt();
        final ledgerId = row['ledger_id'];
        final entityType = row['entity_type'];
        final entitySyncId = row['entity_sync_id'];
        final action = row['action'];
        if (changeId == null ||
            ledgerId is! String ||
            entityType is! String ||
            entitySyncId is! String ||
            action is! String) {
          continue;
        }
        final rawPayload = row['payload'];
        changes.add(
          SpitoutCloudSyncChange(
            changeId: changeId,
            ledgerId: ledgerId,
            entityType: entityType,
            entitySyncId: entitySyncId,
            action: action,
            updatedByDeviceId: row['updated_by_device_id'] as String?,
            updatedAt: row['updated_at'] as String?,
            payload: rawPayload is Map<String, dynamic> ? rawPayload : null,
          ),
        );
      }
    }

    if (persistCursor) {
      await _saveCursor(nextCursor);
    }
    return SpitoutCloudPullResult(
      changes: changes,
      serverCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  /// 推送增量变更（个体实体级别，非 ledger_snapshot 包装）
  Future<void> pushEntityChanges({
    required List<Map<String, dynamic>> changes,
  }) async {
    if (changes.isEmpty) return;
    // 先确保 session 有效（触发 token refresh），再读 deviceId
    await auth.requireAccessToken();
    final deviceId = auth.currentDeviceId;
    debugPrint('[BCC] pushEntityChanges: ${changes.length} changes, deviceId=$deviceId');
    if (deviceId == null || deviceId.isEmpty) {
      debugPrint('[BCC] pushEntityChanges: deviceId 为空，抛出认证异常');
      throw CloudNotAuthenticatedException(
          'Missing device id, please login again.');
    }
    final response = await _authedRequest(
      method: 'POST',
      path: '/sync/push',
      body: {
        'device_id': deviceId,
        'changes': changes,
      },
    );
    final bodyPreview = response.body.length > 200
        ? response.body.substring(0, 200)
        : response.body;
    debugPrint('[BCC] pushEntityChanges response: ${response.statusCode} $bodyPreview');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Push entity changes failed (${response.statusCode}): ${_extractErrorMessage(response)}');
    }
  }

  Future<SpitoutCloudProfile> getMyProfile() async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/profile/me',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Get profile failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return SpitoutCloudProfile.fromJson(
      _copyWithNormalizedUrl(payload, 'avatar_url'),
    );
  }

  Future<SpitoutCloudProfile> updateMyProfileDisplayName({
    required String displayName,
  }) async {
    final normalized = displayName.trim();
    if (normalized.isEmpty) {
      throw CloudStorageException('Update profile failed: empty display name');
    }
    return _patchMyProfile(body: {'display_name': normalized});
  }

  /// 推送主币种到服务端。`primaryCurrency` 形如 `CNY`(归一为大写)。
  /// 同 display_name:mobile → server → web 单向同步。
  Future<SpitoutCloudProfile> updateMyProfileBaseCurrency({
    required String primaryCurrency,
  }) async {
    final normalized = primaryCurrency.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw CloudStorageException(
          'Update profile failed: empty primary currency');
    }
    return _patchMyProfile(body: {'primary_currency': normalized});
  }

  /// GET /read/exchange-rates?base=XXX(server 汇率代理)。
  /// server 未开代理(404)返回 null,App 源链下滑公网;其它错误按本类惯例抛出。
  /// 返回 body 原样:{base, rate_date, source, fetched_at, stale, rates:{USD:"0.1477"}}。
  Future<Map<String, dynamic>?> fetchExchangeRates(
      {required String base}) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/exchange-rates',
      query: {'base': base.trim().toUpperCase()},
    );
    if (response.statusCode == 404) {
      // server 未开代理,交给调用方下滑公网源链。
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch exchange rates failed: ${_extractErrorMessage(response)}');
    }
    return _decodeJsonObject(response.body);
  }


  /// 推送外观类设置(show_transaction_time 等)到服务端。传整个 dict 整体替换;server 侧
  /// appearance_json 字段会整包写入。空 dict 视为清空。
  Future<SpitoutCloudProfile> updateMyProfileAppearance({
    required Map<String, dynamic> appearance,
  }) async {
    return _patchMyProfile(body: {'appearance': appearance});
  }

  /// 推送 AI 配置(providers 数组 + binding + custom_prompt + strategy 等)
  /// 到 server。整包替换,空 dict 视为清空。
  Future<SpitoutCloudProfile> updateMyProfileAiConfig({
    required Map<String, dynamic> aiConfig,
  }) async {
    return _patchMyProfile(body: {'ai_config': aiConfig});
  }

  /// PATCH /profile/me 通用封装，body 里写哪些字段就更新哪些；server 端会
  /// 忽略 None 值，只 merge 显式给出的键。返回 server 上新的 profile。
  Future<SpitoutCloudProfile> _patchMyProfile({
    required Map<String, dynamic> body,
  }) async {
    final response = await _authedRequest(
      method: 'PATCH',
      path: '/profile/me',
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Update profile failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return SpitoutCloudProfile.fromJson(
      _copyWithNormalizedUrl(payload, 'avatar_url'),
    );
  }

  Future<SpitoutCloudAvatarUploadResult> uploadMyAvatar({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw CloudStorageException('Avatar upload failed: empty file');
    }
    var token = await auth.requireAccessToken();
    var response = await _profileAvatarMultipartRequest(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      token: token,
    );
    if (response.statusCode == 401) {
      final refreshed = await auth.tryRefreshSession();
      if (!refreshed) {
        throw CloudNotAuthenticatedException(
            'Session expired, please login again.');
      }
      token = await auth.requireAccessToken();
      response = await _profileAvatarMultipartRequest(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        token: token,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Avatar upload failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return SpitoutCloudAvatarUploadResult.fromJson(
      _copyWithNormalizedUrl(payload, 'avatar_url'),
    );
  }

  Future<Uint8List> downloadMyAvatar({
    required String userId,
    int? version,
  }) async {
    // 服务端这个 endpoint 不校验 auth（profile.py download_avatar 无
    // Depends(get_current_user)），但复用 _authedRequest 统一走同一套 base
    // URL + header 拼接，auth header 即使带了也无害。
    final response = await _authedRequest(
      method: 'GET',
      path: '/profile/avatar/$userId',
      query: version != null ? {'v': '$version'} : null,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Avatar download failed: ${_extractErrorMessage(response)}');
    }
    return response.bodyBytes;
  }

  /// 删除当前登录用户在服务端的头像（DELETE /profile/avatar）。
  ///
  /// 与上传共用 `/profile/avatar` 端点：server 侧清掉头像文件与
  /// avatar_url / avatar_version（归 0）。删除后 syncMyProfile 拉到
  /// avatar_url=null 会跳过下载，本地已删的头像不会再被"复活"。
  Future<void> deleteMyAvatar() async {
    final response = await _authedRequest(
      method: 'DELETE',
      path: '/profile/avatar',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Avatar delete failed: ${_extractErrorMessage(response)}');
    }
  }

  Future<List<SpitoutCloudDevice>> listDevices({
    String view = 'deduped',
    int activeWithinDays = 30,
  }) async {
    final normalizedView =
        view.trim().toLowerCase() == 'sessions' ? 'sessions' : 'deduped';
    final normalizedDays = activeWithinDays < 0 ? 0 : activeWithinDays;
    final response = await _authedRequest(
      method: 'GET',
      path: '/devices',
      query: {
        'view': normalizedView,
        'active_within_days': '$normalizedDays',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List devices failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <SpitoutCloudDevice>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(SpitoutCloudDevice.fromJson(row));
    }
    return out;
  }

  Future<void> revokeDevice({required String deviceId}) async {
    final response = await _authedRequest(
      method: 'POST',
      path: '/devices/$deviceId/revoke',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Revoke device failed: ${_extractErrorMessage(response)}');
    }
  }

  Future<List<SpitoutCloudReadLedger>> readLedgers() async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 携带 statusCode:让 SyncEngine 区分 404/410(路由确死 → 立即清共享账本)
      // 与 5xx(可能瞬时抖动 → 阈值判定)。originalError 用 null 占位,
      // 保持 statusCode 位于第 3 个位置参数,兼容全仓既有调用。
      throw CloudStorageException(
        'Read ledgers failed: ${_extractErrorMessage(response)}',
        null,
        response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <SpitoutCloudReadLedger>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(SpitoutCloudReadLedger.fromJson(row));
    }
    return out;
  }

  Future<SpitoutCloudReadLedgerDetail> readLedgerDetail({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read ledger detail failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return SpitoutCloudReadLedgerDetail.fromJson(payload);
  }

  /// 读 server 上某账本的实体计数(transaction / category)。给"深度同步检测"
  /// 用,mobile 对比本地 Drift 计数就能判断是否需要触发一次完整 sync。
  Future<SpitoutCloudLedgerStats> readLedgerStats({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId/stats',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 携带 statusCode:checkSyncHealth 的 stats 失败会展示给用户,
      // 404(账本不存在)与 5xx(服务端故障)需要区分,便于定位是"本地
      // syncId 失效"还是"云端问题"。
      throw CloudStorageException(
        'Read ledger stats failed: ${_extractErrorMessage(response)}',
        null,
        response.statusCode,
      );
    }
    final payload = _decodeJsonObject(response.body);
    return SpitoutCloudLedgerStats.fromJson(payload);
  }

  /// 拉 server 公开 /version。绕开 auth token —— 登录页未登录状态下也该能
  /// 显示 server 版本,不需要 token。
  Future<SpitoutCloudServerVersion> fetchServerVersion() async {
    final uri = Uri.parse('$baseUrl$apiPrefix/version');
    // 不用 _httpClient.get():与其他 5 处出口统一走 _sendWithTimeout,
    // 保证 grep 审计时不漏出口。
    final response = await _sendWithTimeout(
      _httpClient,
      http.Request('GET', uri),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch version failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return SpitoutCloudServerVersion.fromJson(payload);
  }

  // ===========================================================================
  // 共享账本(Sprint 2.4)— invites / members / shared-resources HTTP 实现
  // ===========================================================================

  Future<SpitoutCloudInvite> createInvite({
    required String ledgerId,
    required String role,
    required int expiresInHours,
  }) async {
    final response = await _authedRequest(
      method: 'POST',
      path: '/ledgers/$ledgerId/invites',
      body: {'role': role, 'expires_in_hours': expiresInHours},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Create invite failed: ${_extractErrorMessage(response)}');
    }
    return SpitoutCloudInvite.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<SpitoutCloudInvite>> listInvites({required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET', path: '/ledgers/$ledgerId/invites',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List invites failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (row is Map<String, dynamic>) SpitoutCloudInvite.fromJson(row),
    ];
  }

  Future<void> revokeInvite({required String ledgerId, required String code}) async {
    final response = await _authedRequest(
      method: 'DELETE', path: '/ledgers/$ledgerId/invites/$code',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Revoke invite failed: ${_extractErrorMessage(response)}');
    }
  }

  Future<SpitoutCloudInvitePreview> previewInvite({required String code}) async {
    final response = await _authedRequest(
      method: 'POST', path: '/invites/$code/preview',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Preview invite failed: ${_extractErrorMessage(response)}');
    }
    return SpitoutCloudInvitePreview.fromJson(_decodeJsonObject(response.body));
  }

  Future<SpitoutCloudInviteAcceptResult> acceptInvite({required String code}) async {
    final response = await _authedRequest(
      method: 'POST', path: '/invites/$code/accept',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Accept invite failed: ${_extractErrorMessage(response)}');
    }
    return SpitoutCloudInviteAcceptResult.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<SpitoutCloudLedgerMember>> listMembers({required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET', path: '/ledgers/$ledgerId/members',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 透传 statusCode:调用方据此区分「账本尚未就绪」(404,云端账本刚 moveToCloud
      // 但首次 push 未完成,listMembers 会 404,属暂时性,PushCompleted 事件会自动
      // invalidate 重拉)与「真实错误」(5xx/401 等,需展示错误卡片 + 重试)。
      throw CloudStorageException(
        'List members failed: ${_extractErrorMessage(response)}',
        null,
        response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (row is Map<String, dynamic>) SpitoutCloudLedgerMember.fromJson(row),
    ];
  }

  Future<SpitoutCloudLedgerMember> updateMemberRole({
    required String ledgerId,
    required String userId,
    required String role,
  }) async {
    final response = await _authedRequest(
      method: 'PATCH',
      path: '/ledgers/$ledgerId/members/$userId',
      body: {'role': role},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Update member role failed: ${_extractErrorMessage(response)}');
    }
    return SpitoutCloudLedgerMember.fromJson(_decodeJsonObject(response.body));
  }

  Future<void> removeMember({required String ledgerId, required String userId}) async {
    final response = await _authedRequest(
      method: 'DELETE', path: '/ledgers/$ledgerId/members/$userId',
    );
    // 404 视为目标成员已不存在(已被踢 / 已退出)→ 幂等成功,直接吞掉。
    // 与 download 的 404 处理风格一致,避免「list 完到 remove 之间被踢」的竞态报错。
    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Remove member failed: ${_extractErrorMessage(response)}');
    }
  }

  /// 删除整本账本(Owner 全局删除)。
  ///
  /// 走 server 的 `/write/ledgers/{id}`,server 会在事务内级联删掉所有非 owner 成员
  /// 并向各成员广播 `member_change.removed`。客户端无需自己循环踢人。
  Future<void> deleteLedger({required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'DELETE', path: '/write/ledgers/$ledgerId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Delete ledger failed: ${_extractErrorMessage(response)}');
    }
  }

  /// 拉 Owner 的 user-global 资源快照(§7 决策 — Editor 端 picker 用)。
  Future<SpitoutCloudSharedResources> fetchSharedResources({required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET', path: '/ledgers/$ledgerId/shared-resources',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch shared resources failed: ${_extractErrorMessage(response)}');
    }
    return SpitoutCloudSharedResources.fromJson(_decodeJsonObject(response.body));
  }

  /// 共享账本成员收支统计:server `/ledgers/{id}/member-stats`。
  /// scope: month / year / all;period 可选(YYYY-MM 或 YYYY)。
  Future<SpitoutCloudMemberStats> fetchMemberStats({
    required String ledgerId,
    String scope = 'month',
    String? period,
    int? tzOffsetMinutes,
  }) async {
    final qp = <String, String>{
      'scope': scope,
      if (period != null && period.isNotEmpty) 'period': period,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': '$tzOffsetMinutes',
    };
    final response = await _authedRequest(
      method: 'GET',
      path: '/ledgers/$ledgerId/member-stats',
      query: qp,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch member stats failed: ${_extractErrorMessage(response)}');
    }
    return SpitoutCloudMemberStats.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<SpitoutCloudReadTransaction>> readTransactions({
    required String ledgerId,
    String? txType,
    String? query,
    DateTime? startAt,
    DateTime? endAt,
    int limit = 200,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (txType != null && txType.trim().isNotEmpty) 'tx_type': txType.trim(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (startAt != null) 'start_at': startAt.toUtc().toIso8601String(),
      if (endAt != null) 'end_at': endAt.toUtc().toIso8601String(),
    };
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId/transactions',
      query: qp,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read transactions failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <SpitoutCloudReadTransaction>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(
        SpitoutCloudReadTransaction.fromJson(
          _copyWithNormalizedUrl(row, 'created_by_avatar_url'),
        ),
      );
    }
    return out;
  }

  Future<List<SpitoutCloudReadCategory>> readCategories({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/$ledgerId/categories',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read categories failed: ${_extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final out = <SpitoutCloudReadCategory>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      out.add(SpitoutCloudReadCategory.fromJson(row));
    }
    return out;
  }

  Future<SpitoutCloudWriteCommitMeta> writeCreateLedger({
    String? ledgerId,
    required String ledgerName,
    String currency = 'CNY',
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'ledger_name': ledgerName,
      'currency': currency,
      if (ledgerId != null && ledgerId.trim().isNotEmpty)
        'ledger_id': ledgerId.trim(),
    };
    return _writeRequest(
      method: 'POST',
      path: '/write/ledgers',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeLedgerMeta({
    required String ledgerId,
    required int baseChangeId,
    String? ledgerName,
    String? currency,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (ledgerName != null && ledgerName.trim().isNotEmpty)
        'ledger_name': ledgerName.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim(),
    };
    return _writeRequest(
      method: 'PATCH',
      path: '/write/ledgers/$ledgerId/meta',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeCreateTransaction({
    required String ledgerId,
    required int baseChangeId,
    required String txType,
    required double amount,
    required DateTime happenedAt,
    String? note,
    String? categoryName,
    String? categoryKind,
    String? categoryId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      'tx_type': txType,
      'amount': amount,
      'happened_at': happenedAt.toUtc().toIso8601String(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (note != null) 'note': note,
      if (categoryName != null) 'category_name': categoryName,
      if (categoryKind != null) 'category_kind': categoryKind,
      if (categoryId != null) 'category_id': categoryId,
    };
    return _writeRequest(
      method: 'POST',
      path: '/write/ledgers/$ledgerId/transactions',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeUpdateTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? txType,
    double? amount,
    DateTime? happenedAt,
    String? note,
    String? categoryName,
    String? categoryKind,
    String? categoryId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (txType != null) 'tx_type': txType,
      if (amount != null) 'amount': amount,
      if (happenedAt != null)
        'happened_at': happenedAt.toUtc().toIso8601String(),
      if (note != null) 'note': note,
      if (categoryName != null) 'category_name': categoryName,
      if (categoryKind != null) 'category_kind': categoryKind,
      if (categoryId != null) 'category_id': categoryId,
    };
    return _writeRequest(
      method: 'PATCH',
      path: '/write/ledgers/$ledgerId/transactions/$txId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeDeleteTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
    };
    return _writeRequest(
      method: 'DELETE',
      path: '/write/ledgers/$ledgerId/transactions/$txId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeCreateCategory({
    required String ledgerId,
    required int baseChangeId,
    required String name,
    required String kind,
    int? level,
    int? sortOrder,
    String? icon,
    String? parentName,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      'name': name,
      'kind': kind,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (level != null) 'level': level,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (icon != null) 'icon': icon,
      if (parentName != null) 'parent_name': parentName,
    };
    return _writeRequest(
      method: 'POST',
      path: '/write/ledgers/$ledgerId/categories',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeUpdateCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? name,
    String? kind,
    int? level,
    int? sortOrder,
    String? icon,
    String? parentName,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (level != null) 'level': level,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (icon != null) 'icon': icon,
      if (parentName != null) 'parent_name': parentName,
    };
    return _writeRequest(
      method: 'PATCH',
      path: '/write/ledgers/$ledgerId/categories/$categoryId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> writeDeleteCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'base_change_id': baseChangeId,
      if (requestId != null && requestId.trim().isNotEmpty)
        'request_id': requestId.trim(),
    };
    return _writeRequest(
      method: 'DELETE',
      path: '/write/ledgers/$ledgerId/categories/$categoryId',
      body: body,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SpitoutCloudWriteCommitMeta> _writeRequest({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{};
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey.trim();
    }
    final response = await _authedRequest(
      method: method,
      path: path,
      body: body,
      headers: headers.isEmpty ? null : headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Write request failed: ${_extractErrorMessage(response)}');
    }
    final payload = _decodeJsonObject(response.body);
    return SpitoutCloudWriteCommitMeta.fromJson(payload);
  }

  String _ledgerIdFromPath(String path) {
    final normalized = PathHelper.normalize(path);
    if (normalized.isEmpty) {
      throw CloudStorageException('Invalid path: path is empty');
    }
    return PathHelper.basename(normalized);
  }

  String _cursorStorageKey() {
    final userId = auth.currentUserId ?? 'unknown';
    final deviceId = auth.currentDeviceId ?? 'unknown';
    final raw = '$baseUrl|$apiPrefix|$userId|$deviceId';
    final digest = sha1.convert(utf8.encode(raw)).toString();
    return 'spitout_cloud_pull_cursor_$digest';
  }

  Future<int> _loadCursor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cursorStorageKey()) ?? 0;
  }

  Future<void> _saveCursor(int cursor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cursorStorageKey(), cursor);
  }

  Future<http.Response> _authedRequest({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    var token = await auth.requireAccessToken();
    var response = await _request(
      method: method,
      path: path,
      query: query,
      body: body,
      headers: headers,
      token: token,
    );

    if (response.statusCode == 401) {
      final refreshed = await auth.tryRefreshSession();
      if (!refreshed) {
        throw CloudNotAuthenticatedException(
            'Session expired, please login again.');
      }
      token = await auth.requireAccessToken();
      response = await _request(
        method: method,
        path: path,
        query: query,
        body: body,
        headers: headers,
        token: token,
      );
    }

    return response;
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final request = http.Request(method, uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    if (headers != null && headers.isNotEmpty) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _sendWithTimeout(_httpClient, request);
  }

  Future<http.Response> _profileAvatarMultipartRequest({
    required Uint8List bytes,
    required String fileName,
    required String token,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix/profile/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );
    if (mimeType != null && mimeType.trim().isNotEmpty) {
      request.fields['mime_type'] = mimeType.trim();
    }
    // multipart 上传体积大(图片/头像),send 阶段放宽到 60s;响应体仍 30s。
    return _sendWithTimeout(
      _httpClient,
      request,
      sendTimeout: const Duration(seconds: 60),
    );
  }
}

class _SpitoutCloudSession {
  const _SpitoutCloudSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.deviceId,
  });

  final String userId;
  final String? email;
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
      email: user['email'] as String?,
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
      email: json['email'] as String?,
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
      'email': email,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
      'deviceId': deviceId,
    };
  }
}

class SpitoutCloudSyncChange {
  const SpitoutCloudSyncChange({
    required this.changeId,
    required this.ledgerId,
    required this.entityType,
    required this.entitySyncId,
    required this.action,
    this.updatedByDeviceId,
    this.updatedAt,
    this.payload,
  });

  final int changeId;
  final String ledgerId;
  final String entityType;
  final String entitySyncId;
  final String action;
  final String? updatedByDeviceId;
  final String? updatedAt;
  final Map<String, dynamic>? payload;
}

class SpitoutCloudPullResult {
  const SpitoutCloudPullResult({
    required this.changes,
    required this.serverCursor,
    required this.hasMore,
  });

  final List<SpitoutCloudSyncChange> changes;
  final int serverCursor;
  final bool hasMore;
}

class SpitoutCloudDevice {
  const SpitoutCloudDevice({
    required this.id,
    required this.name,
    required this.platform,
    this.appVersion,
    this.osVersion,
    this.deviceModel,
    this.lastIp,
    this.lastSeenAt,
    this.createdAt,
    this.sessionCount = 1,
  });

  final String id;
  final String name;
  final String platform;
  final String? appVersion;
  final String? osVersion;
  final String? deviceModel;
  final String? lastIp;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final int sessionCount;

  factory SpitoutCloudDevice.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      appVersion: _trimOrNull(json['app_version'] as String?),
      osVersion: _trimOrNull(json['os_version'] as String?),
      deviceModel: _trimOrNull(json['device_model'] as String?),
      lastIp: _trimOrNull(json['last_ip'] as String?),
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      sessionCount: (json['session_count'] as num?)?.toInt() ?? 1,
    );
  }
}

class SpitoutCloudReadLedger {
  const SpitoutCloudReadLedger({
    required this.ledgerId,
    required this.ledgerName,
    required this.currency,
    required this.transactionCount,
    required this.expenseTotal,
    required this.balance,
    required this.role,
    this.isShared = false,
    this.memberCount = 1,
    this.monthStartDay,
    this.aaEnabled = false,
    this.hasAaEnabled = false,
    this.exportedAt,
    this.updatedAt,
  });

  final String ledgerId;
  final String ledgerName;
  final String currency;
  final int transactionCount;
  /// v34:移除 incomeTotal 字段(app 只保留支出,不再区分收支)。
  final double expenseTotal;
  final double balance;
  final String role;
  final bool isShared;
  final int memberCount;

  /// server ReadLedgerOut.month_start_day;null = 老 server 未返回该字段
  /// (调用方应保持本地值不动,勿当 1 处理 —— 防版本偏斜时覆盖用户设置)。
  final int? monthStartDay;

  /// AA 分摊开关(server ReadLedgerOut.aa_enabled)。
  /// [hasAaEnabled] 为 false 时表示 server 未显式返回该字段(老版本 server),
  /// 同步引擎必须以 absent 保留本地值,防止把本地已开启的 AA 开关静默重置为 false。
  final bool aaEnabled;
  final bool hasAaEnabled;

  final DateTime? exportedAt;
  final DateTime? updatedAt;

  factory SpitoutCloudReadLedger.fromJson(Map<String, dynamic> json) {
    // 显式区分"server 未返回 aa_enabled"与"server 显式返回 false":
    // containsKey=false 时 hasAaEnabled=false,调用方据此走 absent 保留本地值,
    // 避免老版本 server 把本地已开启的 AA 分摊静默关闭。
    final hasAa = json.containsKey('aa_enabled');
    return SpitoutCloudReadLedger(
      ledgerId: json['ledger_id'] as String? ?? '',
      ledgerName: json['ledger_name'] as String? ?? '',
      currency: json['currency'] as String? ?? 'CNY',
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      expenseTotal: (json['expense_total'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      role: json['role'] as String? ?? 'viewer',
      isShared: json['is_shared'] as bool? ?? false,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      monthStartDay: (json['month_start_day'] as num?)?.toInt(),
      aaEnabled: json['aa_enabled'] as bool? ?? false,
      hasAaEnabled: hasAa,
      exportedAt: DateTime.tryParse(json['exported_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class SpitoutCloudServerVersion {
  const SpitoutCloudServerVersion({
    required this.name,
    required this.version,
  });

  final String name;
  final String version;

  factory SpitoutCloudServerVersion.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudServerVersion(
      name: (json['name'] as String?)?.trim() ?? 'Spitout Cloud',
      version: (json['version'] as String?)?.trim() ?? '',
    );
  }
}

class SpitoutCloudLedgerStats {
  const SpitoutCloudLedgerStats({
    required this.transactionCount,
    required this.transactionTotal,
    required this.categoryCount,
    required this.categoryTotal,
  });

  /// `*Count`:当前账本口径。`*Total`:当前用户全量账本合计。
  /// 一般 total 比 count 大。Server 没返 total 字段时(老版本兼容)回退到 count。
  final int transactionCount;
  final int transactionTotal;
  final int categoryCount;
  final int categoryTotal;

  factory SpitoutCloudLedgerStats.fromJson(Map<String, dynamic> json) {
    int readCount(String key) => (json[key] as num?)?.toInt() ?? 0;
    int readTotalOrFallback(String totalKey, String countKey) {
      final v = (json[totalKey] as num?)?.toInt();
      if (v != null) return v;
      return readCount(countKey);
    }
    return SpitoutCloudLedgerStats(
      transactionCount: readCount('transaction_count'),
      transactionTotal: readTotalOrFallback('transaction_total', 'transaction_count'),
      categoryCount: readCount('category_count'),
      categoryTotal: readTotalOrFallback('category_total', 'category_count'),
    );
  }
}

class SpitoutCloudReadLedgerDetail extends SpitoutCloudReadLedger {
  const SpitoutCloudReadLedgerDetail({
    required super.ledgerId,
    required super.ledgerName,
    required super.currency,
    required super.transactionCount,
    required super.expenseTotal,
    required super.balance,
    required super.role,
    required super.isShared,
    required super.memberCount,
    required this.sourceChangeId,
    super.monthStartDay,
    super.exportedAt,
    super.updatedAt,
  });

  final int sourceChangeId;

  factory SpitoutCloudReadLedgerDetail.fromJson(Map<String, dynamic> json) {
    final base = SpitoutCloudReadLedger.fromJson(json);
    return SpitoutCloudReadLedgerDetail(
      ledgerId: base.ledgerId,
      ledgerName: base.ledgerName,
      currency: base.currency,
      transactionCount: base.transactionCount,
      expenseTotal: base.expenseTotal,
      balance: base.balance,
      role: base.role,
      isShared: base.isShared,
      memberCount: base.memberCount,
      monthStartDay: base.monthStartDay,
      exportedAt: base.exportedAt,
      updatedAt: base.updatedAt,
      sourceChangeId: (json['source_change_id'] as num?)?.toInt() ?? 0,
    );
  }
}

class SpitoutCloudReadTransaction {
  const SpitoutCloudReadTransaction({
    required this.id,
    required this.txIndex,
    required this.txType,
    required this.amount,
    required this.happenedAt,
    required this.lastChangeId,
    this.note,
    this.categoryName,
    this.categoryKind,
    this.accountName,
    this.fromAccountName,
    this.toAccountName,
    this.categoryId,
    this.ledgerId,
    this.ledgerName,
    this.createdByUserId,
    this.createdByEmail,
    this.createdByDisplayName,
    this.createdByAvatarUrl,
    this.createdByAvatarVersion,
  });

  final String id;
  final int txIndex;
  final String txType;
  final double amount;
  final DateTime? happenedAt;
  final String? note;
  final String? categoryName;
  final String? categoryKind;
  final String? accountName;
  final String? fromAccountName;
  final String? toAccountName;
  final String? categoryId;
  final int lastChangeId;
  final String? ledgerId;
  final String? ledgerName;
  final String? createdByUserId;
  final String? createdByEmail;
  final String? createdByDisplayName;
  final String? createdByAvatarUrl;
  final int? createdByAvatarVersion;

  factory SpitoutCloudReadTransaction.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudReadTransaction(
      id: json['id'] as String? ?? '',
      txIndex: (json['tx_index'] as num?)?.toInt() ?? 0,
      txType: json['tx_type'] as String? ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      happenedAt: DateTime.tryParse(json['happened_at'] as String? ?? ''),
      note: json['note'] as String?,
      categoryName: json['category_name'] as String?,
      categoryKind: json['category_kind'] as String?,
      accountName: json['account_name'] as String?,
      fromAccountName: json['from_account_name'] as String?,
      toAccountName: json['to_account_name'] as String?,
      categoryId: json['category_id'] as String?,
      lastChangeId: (json['last_change_id'] as num?)?.toInt() ?? 0,
      ledgerId: json['ledger_id'] as String?,
      ledgerName: json['ledger_name'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByEmail: json['created_by_email'] as String?,
      createdByDisplayName:
          _trimOrNull(json['created_by_display_name'] as String?),
      createdByAvatarUrl: _trimOrNull(json['created_by_avatar_url'] as String?),
      createdByAvatarVersion:
          (json['created_by_avatar_version'] as num?)?.toInt(),
    );
  }
}

class SpitoutCloudProfile {
  const SpitoutCloudProfile({
    required this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.avatarVersion = 0,
    this.appearance,
    this.aiConfig,
    this.primaryCurrency,
  });

  final String userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final int avatarVersion;
  /// 用户主币种(ISO code,如 `CNY`)。多币种 MVP user-level 字段,跨设备同步。
  final String? primaryCurrency;
  /// 外观类设置(show_transaction_time …)的 dict,跨设备同步的 user-level JSON。
  final Map<String, dynamic>? appearance;
  /// AI 配置(providers / binding / custom_prompt / strategy …)的 dict。
  final Map<String, dynamic>? aiConfig;

  factory SpitoutCloudProfile.fromJson(Map<String, dynamic> json) {
    final appearanceRaw = json['appearance'];
    final aiConfigRaw = json['ai_config'];
    return SpitoutCloudProfile(
      userId: json['user_id'] as String? ?? '',
      email: _trimOrNull(json['email'] as String?),
      displayName: _trimOrNull(json['display_name'] as String?),
      avatarUrl: _trimOrNull(json['avatar_url'] as String?),
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
      appearance: appearanceRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(appearanceRaw)
          : null,
      aiConfig: aiConfigRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(aiConfigRaw)
          : null,
      primaryCurrency: _trimOrNull(json['primary_currency'] as String?),
    );
  }
}

class SpitoutCloudAvatarUploadResult {
  const SpitoutCloudAvatarUploadResult({
    this.avatarUrl,
    this.avatarVersion = 0,
  });

  final String? avatarUrl;
  final int avatarVersion;

  factory SpitoutCloudAvatarUploadResult.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudAvatarUploadResult(
      avatarUrl: _trimOrNull(json['avatar_url'] as String?),
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
    );
  }
}

class SpitoutCloudReadCategory {
  const SpitoutCloudReadCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.lastChangeId,
    this.level,
    this.sortOrder,
    this.icon,
    this.parentName,
    this.ledgerId,
    this.ledgerName,
    this.createdByUserId,
    this.createdByEmail,
  });

  final String id;
  final String name;
  final String kind;
  final int? level;
  final int? sortOrder;
  final String? icon;
  final String? parentName;
  final int lastChangeId;
  final String? ledgerId;
  final String? ledgerName;
  final String? createdByUserId;
  final String? createdByEmail;

  factory SpitoutCloudReadCategory.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudReadCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'expense',
      level: (json['level'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      icon: json['icon'] as String?,
      parentName: json['parent_name'] as String?,
      lastChangeId: (json['last_change_id'] as num?)?.toInt() ?? 0,
      ledgerId: json['ledger_id'] as String?,
      ledgerName: json['ledger_name'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByEmail: json['created_by_email'] as String?,
    );
  }
}

class SpitoutCloudWriteCommitMeta {
  const SpitoutCloudWriteCommitMeta({
    required this.ledgerId,
    required this.baseChangeId,
    required this.newChangeId,
    required this.serverTimestamp,
    required this.idempotencyReplayed,
    this.entityId,
  });

  final String ledgerId;
  final int baseChangeId;
  final int newChangeId;
  final DateTime? serverTimestamp;
  final bool idempotencyReplayed;
  final String? entityId;

  factory SpitoutCloudWriteCommitMeta.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudWriteCommitMeta(
      ledgerId: json['ledger_id'] as String? ?? '',
      baseChangeId: (json['base_change_id'] as num?)?.toInt() ?? 0,
      newChangeId: (json['new_change_id'] as num?)?.toInt() ?? 0,
      serverTimestamp:
          DateTime.tryParse(json['server_timestamp'] as String? ?? ''),
      idempotencyReplayed: json['idempotency_replayed'] == true,
      entityId: json['entity_id'] as String?,
    );
  }
}

class SpitoutCloudRealtimeEvent {
  const SpitoutCloudRealtimeEvent({
    required this.type,
    this.ledgerId,
    this.serverCursor,
    this.rawData = const <String, dynamic>{},
  });

  final String type;
  final String? ledgerId;
  final int? serverCursor;
  /// 完整 payload(server 推过来的 dict)。新事件类型(member_change /
  /// shared_resource_change)字段从这里读,避免每加一种事件都改 RealtimeEvent
  /// 类。
  final Map<String, dynamic> rawData;
}

class SpitoutCloudRealtimeClient {
  SpitoutCloudRealtimeClient({
    required this.baseUrl,
    required this.auth,
  });

  final String baseUrl;
  final SpitoutCloudAuthService auth;

  final StreamController<SpitoutCloudRealtimeEvent> _events =
      StreamController<SpitoutCloudRealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _running = false;
  bool _connecting = false;

  /// 连续重连失败次数,用于指数退避(3s → 6s → 12s → 24s → 48s → 60s 封顶)。
  ///
  /// 设计意图:固定 3s 重连在 server 短暂不可用时会形成"重连风暴"——
  /// 每 3s 一次 requireAccessToken + WS 握手,既打爆 server 也耗电。
  /// 收到任意入站帧(证明连接真实存活)后归零。
  int _reconnectAttempts = 0;

  Stream<SpitoutCloudRealtimeEvent> get events => _events.stream;

  Future<void> start() async {
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

  void dispose() {
    _events.close();
  }

  Future<void> _connect() async {
    if (!_running || _connecting) {
      return;
    }
    _connecting = true;

    try {
      final token = await auth.requireAccessToken();
      final uri = _buildWebSocketUri(token);
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

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
          _channel?.sink.add('ping');
        } catch (_) {}
      });

      // 发一条 "connected" 事件给业务层，让 SyncEngine 知道 WS 重连成功 ——
      // 离线累积的 local_changes 可以此时 flush。没有这个通知的话，断网
      // 期间用户改的东西要等下一次交易写入 / PostProcessor.sync() 才推出去。
      _events.add(const SpitoutCloudRealtimeEvent(type: 'connected'));
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Uri _buildWebSocketUri(String token) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'ws',
    ];

    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/${segments.join('/')}',
      queryParameters: {'token': token},
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

String _normalizeApiPrefix(String raw) {
  var prefix = raw.trim();
  if (prefix.isEmpty) {
    return '/api/v1';
  }
  if (!prefix.startsWith('/')) {
    prefix = '/$prefix';
  }
  if (prefix.endsWith('/')) {
    prefix = prefix.substring(0, prefix.length - 1);
  }
  return prefix;
}

Map<String, dynamic> _decodeJsonObject(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid JSON response');
  }
  return decoded;
}

String _extractErrorMessage(http.Response response) {
  try {
    final payload = _decodeJsonObject(response.body);
    final detail = payload['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
  } catch (_) {}
  return 'HTTP ${response.statusCode}';
}

// =============================================================================
// 共享账本数据类(Sprint 2.4 — Phase 1)
// =============================================================================

class SpitoutCloudInvite {
  const SpitoutCloudInvite({
    required this.code,
    required this.formattedCode,
    required this.targetRole,
    required this.expiresAt,
    required this.createdAt,
    required this.shareUrl,
    this.invitedByUserId,
  });

  /// 6 位明文邀请码(`ABC123`)。
  final String code;
  /// 显示用 "ABC 123"(中间空格易读)。
  final String formattedCode;
  final String targetRole;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String shareUrl;
  /// list endpoint 返回时带,create 不带(创建者自己即 caller)。
  final String? invitedByUserId;

  factory SpitoutCloudInvite.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudInvite(
      code: (json['code'] as String?)?.trim() ?? '',
      formattedCode: (json['formatted_code'] as String?)?.trim() ?? '',
      targetRole: (json['target_role'] as String?)?.trim() ?? 'editor',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc()
          ?? DateTime.now().toUtc(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc()
          ?? DateTime.now().toUtc(),
      shareUrl: (json['share_url'] as String?)?.trim() ?? '',
      invitedByUserId: (json['invited_by_user_id'] as String?)?.trim().isEmpty == true
          ? null
          : json['invited_by_user_id'] as String?,
    );
  }
}

class SpitoutCloudInvitePreview {
  const SpitoutCloudInvitePreview({
    required this.code,
    required this.ledgerExternalId,
    required this.ledgerCurrency,
    required this.invitedByDisplay,
    required this.targetRole,
    required this.expiresAt,
    this.ledgerName,
  });

  final String code;
  final String ledgerExternalId;
  final String? ledgerName;
  final String ledgerCurrency;
  final String invitedByDisplay;
  final String targetRole;
  final DateTime expiresAt;

  factory SpitoutCloudInvitePreview.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudInvitePreview(
      code: (json['code'] as String?)?.trim() ?? '',
      ledgerExternalId: (json['ledger_external_id'] as String?)?.trim() ?? '',
      ledgerName: json['ledger_name'] as String?,
      ledgerCurrency: (json['ledger_currency'] as String?)?.trim() ?? 'CNY',
      invitedByDisplay: (json['invited_by_display'] as String?)?.trim() ?? 'Unknown',
      targetRole: (json['target_role'] as String?)?.trim() ?? 'editor',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc()
          ?? DateTime.now().toUtc(),
    );
  }
}

class SpitoutCloudInviteAcceptResult {
  const SpitoutCloudInviteAcceptResult({
    required this.ledgerExternalId,
    required this.ledgerCurrency,
    required this.role,
    required this.memberCount,
    this.ledgerName,
  });

  final String ledgerExternalId;
  final String? ledgerName;
  final String ledgerCurrency;
  final String role;
  final int memberCount;

  factory SpitoutCloudInviteAcceptResult.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudInviteAcceptResult(
      ledgerExternalId: (json['ledger_external_id'] as String?)?.trim() ?? '',
      ledgerName: json['ledger_name'] as String?,
      ledgerCurrency: (json['ledger_currency'] as String?)?.trim() ?? 'CNY',
      role: (json['role'] as String?)?.trim() ?? 'editor',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
    );
  }
}

class SpitoutCloudLedgerMember {
  const SpitoutCloudLedgerMember({
    required this.userId,
    required this.email,
    required this.role,
    required this.joinedAt,
    required this.isSelf,
    this.displayName,
    this.invitedByUserId,
    this.avatarUrl,
    this.avatarVersion = 0,
  });

  final String userId;
  final String email;
  final String? displayName;
  final String role;
  final DateTime joinedAt;
  final String? invitedByUserId;
  final bool isSelf;
  /// server-side relative path,例 "/api/v1/profile/avatar/{uid}?v=N"。null = 用户未上传头像。
  final String? avatarUrl;
  final int avatarVersion;

  factory SpitoutCloudLedgerMember.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudLedgerMember(
      userId: (json['user_id'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      displayName: json['display_name'] as String?,
      role: (json['role'] as String?)?.trim() ?? 'editor',
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '')?.toUtc()
          ?? DateTime.now().toUtc(),
      invitedByUserId: json['invited_by_user_id'] as String?,
      isSelf: json['is_self'] as bool? ?? false,
      avatarUrl: (json['avatar_url'] as String?)?.trim().isEmpty == true
          ? null
          : json['avatar_url'] as String?,
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
    );
  }
}

/// §7 决策 — Editor 接受邀请后拉到的 Owner user-global 资源快照。
/// v34:tags 字段已移除(tags 表已删除)。
class SpitoutCloudSharedResources {
  const SpitoutCloudSharedResources({
    required this.ownerUserId,
    required this.categories,
    required this.accounts,
  });

  final String ownerUserId;
  final List<SpitoutCloudSharedCategory> categories;
  final List<SpitoutCloudSharedAccount> accounts;

  factory SpitoutCloudSharedResources.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'];
    final accts = json['accounts'];
    return SpitoutCloudSharedResources(
      ownerUserId: (json['owner_user_id'] as String?)?.trim() ?? '',
      categories: cats is List
          ? [
              for (final c in cats)
                if (c is Map<String, dynamic>)
                  SpitoutCloudSharedCategory.fromJson(c),
            ]
          : const [],
      accounts: accts is List
          ? [
              for (final a in accts)
                if (a is Map<String, dynamic>)
                  SpitoutCloudSharedAccount.fromJson(a),
            ]
          : const [],
    );
  }
}

class SpitoutCloudSharedCategory {
  const SpitoutCloudSharedCategory({
    required this.syncId,
    required this.name,
    required this.kind,
    this.icon,
    this.sortOrder,
    this.level,
    this.parentName,
    this.parentSyncId,
  });

  final String syncId;
  final String name;
  final String kind; // expense / income
  final String? icon;
  final int? sortOrder;
  final int? level;
  final String? parentName;
  // 共享账本二级分类:parent 的 syncId,client 端用它建稳定父子链。
  final String? parentSyncId;

  factory SpitoutCloudSharedCategory.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudSharedCategory(
      syncId: (json['sync_id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      kind: (json['kind'] as String?)?.trim() ?? 'expense',
      icon: json['icon'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      level: (json['level'] as num?)?.toInt(),
      parentName: json['parent_name'] as String?,
      parentSyncId: json['parent_sync_id'] as String?,
    );
  }
}

class SpitoutCloudSharedAccount {
  const SpitoutCloudSharedAccount({
    required this.syncId,
    required this.name,
    this.accountType,
    this.currency,
    this.initialBalance,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.paymentDueDay,
    this.bankName,
    this.cardLastFour,
  });

  final String syncId;
  final String name;
  final String? accountType;
  final String? currency;
  final double? initialBalance;
  final String? note;
  final double? creditLimit;
  final int? billingDay;
  final int? paymentDueDay;
  final String? bankName;
  final String? cardLastFour;

  factory SpitoutCloudSharedAccount.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudSharedAccount(
      syncId: (json['sync_id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      accountType: json['account_type'] as String?,
      currency: json['currency'] as String?,
      initialBalance: (json['initial_balance'] as num?)?.toDouble(),
      note: json['note'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble(),
      billingDay: (json['billing_day'] as num?)?.toInt(),
      paymentDueDay: (json['payment_due_day'] as num?)?.toInt(),
      bankName: json['bank_name'] as String?,
      cardLastFour: json['card_last_four'] as String?,
    );
  }
}

/// 共享账本成员收支统计单行(对应 server MemberStatItem)。
/// v34:移除 incomeTotal 字段(app 只保留支出,不再区分收支)。
class SpitoutCloudMemberStatItem {
  const SpitoutCloudMemberStatItem({
    required this.userId,
    required this.role,
    required this.expenseTotal,
    required this.txCount,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.avatarVersion = 0,
  });

  final String userId;
  final String? email;
  final String? displayName;
  /// server-side relative path,例 "/api/v1/profile/avatar/{uid}?v=N"。null = 用户未上传头像。
  final String? avatarUrl;
  final int avatarVersion;
  /// 'owner' / 'editor' / 'removed'(被踢成员但 tx 仍有归属)。
  final String role;
  final double expenseTotal;
  final int txCount;

  factory SpitoutCloudMemberStatItem.fromJson(Map<String, dynamic> json) {
    final avatar = (json['avatar_url'] as String?)?.trim();
    return SpitoutCloudMemberStatItem(
      userId: (json['user_id'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim().isEmpty == true
          ? null
          : json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
      role: (json['role'] as String?)?.trim() ?? 'editor',
      expenseTotal: (json['expense_total'] as num?)?.toDouble() ?? 0.0,
      txCount: (json['tx_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 共享账本成员收支统计响应(对应 server MemberStatsResponse)。
class SpitoutCloudMemberStats {
  const SpitoutCloudMemberStats({
    required this.ledgerId,
    required this.ledgerCurrency,
    required this.scope,
    required this.items,
    this.period,
    this.startAt,
    this.endAt,
  });

  final String ledgerId;
  final String ledgerCurrency;
  /// 'month' / 'year' / 'all'。
  final String scope;
  /// month → "YYYY-MM";year → "YYYY";all → null。
  final String? period;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<SpitoutCloudMemberStatItem> items;

  factory SpitoutCloudMemberStats.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <SpitoutCloudMemberStatItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(SpitoutCloudMemberStatItem.fromJson(entry));
        }
      }
    }
    DateTime? parseDate(String key) {
      final raw = json[key];
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw)?.toUtc();
      }
      return null;
    }

    return SpitoutCloudMemberStats(
      ledgerId: (json['ledger_id'] as String?)?.trim() ?? '',
      ledgerCurrency: (json['ledger_currency'] as String?)?.trim() ?? 'CNY',
      scope: (json['scope'] as String?)?.trim() ?? 'month',
      period: (json['period'] as String?)?.trim().isEmpty == true
          ? null
          : json['period'] as String?,
      startAt: parseDate('start_at'),
      endAt: parseDate('end_at'),
      items: items,
    );
  }
}
