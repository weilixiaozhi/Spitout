import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import '../auth/spitout_cloud_auth_service.dart';
import '../internal.dart';
import '../models/spitout_cloud_models.dart';
import '../realtime/spitout_cloud_realtime_client.dart';
import '../storage/spitout_cloud_storage_service.dart';

/// Spitout Cloud 同步门面接口。
///
/// 设计意图:把 SyncEngine / providers 依赖的同步能力从具体实现中解耦,
/// 真实 provider 与测试替身(FakeSpitoutCloudProvider)都实现本接口;
/// 接口新增方法时测试替身必须同步实现(编译期强制),避免继承真类后
/// 悄悄继承到会抛 CloudConfigurationException 的占位实现。
abstract interface class SpitoutCloudSyncBackend implements CloudProvider {
  /// 拼接绝对 URL 用 — 头像 / 附件下载等场景。null = 未初始化。
  String? get baseUrl;

  String? get apiPrefix;

  /// 静默恢复冷却剩余时间;非冷却期返回 null。
  Duration? get remainingRecoveryCooldown;

  Stream<SpitoutCloudRealtimeEvent> get realtimeEvents;

  Future<void> startRealtime();

  Future<void> stopRealtime();

  Future<SpitoutCloudProfile> getMyProfile();

  Future<TwoFactorStatus> getTwoFactorStatus();

  Future<SpitoutCloudProfile> updateMyProfileDisplayName({
    required String displayName,
  });

  Future<SpitoutCloudProfile> updateMyProfileBaseCurrency({
    required String primaryCurrency,
  });

  Future<Map<String, dynamic>?> fetchExchangeRates({required String base});

  Future<SpitoutCloudAvatarUploadResult> uploadMyAvatar({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  });

  Future<SpitoutCloudProfile> updateMyProfileAppearance({
    required Map<String, dynamic> appearance,
  });

  Future<SpitoutCloudProfile> updateMyProfileAiConfig({
    required Map<String, dynamic> aiConfig,
  });

  Future<Uint8List> downloadMyAvatar({
    required String userId,
    int? version,
  });

  Future<void> deleteMyAvatar();

  Future<SpitoutCloudPullResult> pullChanges({
    int? since,
    int limit,
    bool persistCursor,
  });

  Future<void> pushChanges({
    required List<Map<String, dynamic>> changes,
  });

  Future<List<SpitoutCloudDevice>> listDevices({
    String view,
    int activeWithinDays,
  });

  Future<void> revokeDevice({required String deviceId});

  Future<List<SpitoutCloudReadLedger>> readLedgers();

  Future<SpitoutCloudReadLedgerDetail> readLedgerDetail({
    required String ledgerId,
  });

  Future<SpitoutCloudLedgerStats> readLedgerStats({
    required String ledgerId,
  });

  Future<SpitoutCloudServerVersion> fetchServerVersion();

  Future<SpitoutCloudInvite> createInvite({
    required String ledgerId,
    String role,
    int expiresInHours,
  });

  Future<List<SpitoutCloudInvite>> listInvites({required String ledgerId});

  Future<void> revokeInvite({
    required String ledgerId,
    String? inviteId,
    String? code,
  });

  Future<SpitoutCloudInvitePreview> previewInvite({required String code});

  Future<SpitoutCloudInviteAcceptResult> acceptInvite({required String code});

  Future<List<SpitoutCloudLedgerMember>> listMembers({
    required String ledgerId,
  });

  Future<SpitoutCloudLedgerMember> updateMemberRole({
    required String ledgerId,
    required String userId,
    required String role,
  });

  Future<void> removeMember({
    required String ledgerId,
    required String userId,
  });

  Future<void> leaveLedger({required String ledgerId});

  Future<void> deleteLedger({required String ledgerId});

  Future<SpitoutCloudSharedResources> fetchSharedResources({
    required String ledgerId,
  });

  Future<SpitoutCloudMemberStats> fetchMemberStats({
    required String ledgerId,
    String scope,
    String? period,
    int? tzOffsetMinutes,
  });

  Future<List<SpitoutCloudReadTransaction>> readTransactions({
    required String ledgerId,
    String? txType,
    String? query,
    DateTime? startAt,
    DateTime? endAt,
    int limit,
    int offset,
  });

  Future<List<SpitoutCloudReadCategory>> readCategories({
    required String ledgerId,
  });

  Future<SpitoutCloudWriteCommitMeta> writeCreateLedger({
    String? ledgerId,
    required String ledgerName,
    String currency,
    String? idempotencyKey,
  });

  Future<SpitoutCloudWriteCommitMeta> writeLedgerMeta({
    required String ledgerId,
    required int baseChangeId,
    String? ledgerName,
    String? currency,
    String? requestId,
    String? idempotencyKey,
  });

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
  });

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
  });

  Future<SpitoutCloudWriteCommitMeta> writeDeleteTransaction({
    required String ledgerId,
    required String txId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  });

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
  });

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
  });

  Future<SpitoutCloudWriteCommitMeta> writeDeleteCategory({
    required String ledgerId,
    required String categoryId,
    required int baseChangeId,
    String? requestId,
    String? idempotencyKey,
  });
}

class SpitoutCloudProvider implements SpitoutCloudSyncBackend {
  SpitoutCloudProvider({CloudSyncLogger? logger})
      : _logger = logger ?? defaultCloudLogger;

  final CloudSyncLogger _logger;

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
  @override
  String? get baseUrl => _auth?.baseUrl;
  @override
  String? get apiPrefix => _auth?.apiPrefix;

  /// 转发 [SpitoutCloudAuthService.remainingRecoveryCooldown]：
  /// 上层（sync_engine_status 等）持有的是 provider 实例而非 auth service，
  /// 通过此只读转发即可判断"静默恢复冷却中/需手动登录"，无需向下转型。
  /// 未初始化（_auth 为 null）时返回 null，语义等同"非冷却期"。
  @override
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
    final apiPrefix = normalizeApiPrefix(rawApiPrefix ?? '/api/v1');
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null ||
        !baseUri.hasScheme ||
        !isHttpTransportAllowed(baseUri)) {
      throw CloudConfigurationException(
        'Invalid or insecure Spitout Cloud baseUrl. Use https:// '
        '(http is only allowed for localhost or private-network testing).',
      );
    }

    final authService = SpitoutCloudAuthService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      twoFactorHandler: SpitoutCloudProvider.globalTwoFactorHandler,
      logger: _logger,
    );
    await authService.initialize();

    _auth = authService;
    final storage = SpitoutCloudStorageService(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix,
      auth: authService,
      logger: _logger,
    );
    _storage = storage;
    _realtime = SpitoutCloudRealtimeClient(
      baseUrl: baseUrl,
      auth: authService,
      logger: _logger,
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

  @override
  Stream<SpitoutCloudRealtimeEvent> get realtimeEvents {
    final realtime = _realtime;
    if (realtime == null) {
      return const Stream.empty();
    }
    return realtime.events;
  }

  @override
  Future<void> startRealtime() async {
    final realtime = _realtime;
    if (realtime == null) {
      throw CloudConfigurationException(
          'Spitout Cloud realtime is not initialized.');
    }
    await realtime.start();
  }

  @override
  Future<void> stopRealtime() async {
    await _realtime?.stop();
  }

  @override
  Future<SpitoutCloudProfile> getMyProfile() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.getMyProfile();
  }

  /// 转发到 SpitoutCloudAuthService.getTwoFactorStatus,云同步页用它展示状态行。
  @override
  Future<TwoFactorStatus> getTwoFactorStatus() async {
    final auth = _auth;
    if (auth == null) {
      throw CloudConfigurationException(
          'Spitout Cloud auth is not initialized.');
    }
    return auth.getTwoFactorStatus();
  }

  @override
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
  @override
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
  @override
  Future<Map<String, dynamic>?> fetchExchangeRates(
      {required String base}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.fetchExchangeRates(base: base);
  }

  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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

  @override
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

  @override
  Future<void> revokeDevice({required String deviceId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.revokeDevice(deviceId: deviceId);
  }

  @override
  Future<List<SpitoutCloudReadLedger>> readLedgers() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.readLedgers();
  }

  @override
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

  @override
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
  @override
  Future<SpitoutCloudServerVersion> fetchServerVersion() async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.fetchServerVersion();
  }

  // ===========================================================================
  // 共享账本:invites + members + shared-resources
  // ===========================================================================

  @override
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
      ledgerId: ledgerId,
      role: role,
      expiresInHours: expiresInHours,
    );
  }

  @override
  Future<List<SpitoutCloudInvite>> listInvites(
      {required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.listInvites(ledgerId: ledgerId);
  }

  /// 撤销邀请。
  ///
  /// 新协议以 [inviteId] 为准,路径为
  /// `DELETE /ledgers/{ledgerId}/invites/{inviteId}`;server 兼容把完整明文码
  /// 作为 key 传入,因此旧调用方继续传 [code] 也能工作,无需改调用点。
  @override
  Future<void> revokeInvite({
    required String ledgerId,
    String? inviteId,
    String? code,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.revokeInvite(
      ledgerId: ledgerId,
      inviteId: inviteId,
      code: code,
    );
  }

  @override
  Future<SpitoutCloudInvitePreview> previewInvite(
      {required String code}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.previewInvite(code: code);
  }

  @override
  Future<SpitoutCloudInviteAcceptResult> acceptInvite(
      {required String code}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.acceptInvite(code: code);
  }

  @override
  Future<List<SpitoutCloudLedgerMember>> listMembers(
      {required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.listMembers(ledgerId: ledgerId);
  }

  @override
  Future<SpitoutCloudLedgerMember> updateMemberRole({
    required String ledgerId,
    required String userId,
    required String role,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.updateMemberRole(
        ledgerId: ledgerId, userId: userId, role: role);
  }

  @override
  Future<void> removeMember(
      {required String ledgerId, required String userId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.removeMember(ledgerId: ledgerId, userId: userId);
  }

  /// 退出共享账本(协作者主动退出)。
  ///
  /// 走 `DELETE /members/self` 语义:先 listMembers 找到自己(isSelf 标记),
  /// 再 removeMember(self)。云端移除成员后 server 不再返回该账本,
  /// 因此下次 sync 不会再把它重新插回本地。
  @override
  Future<void> leaveLedger({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
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
  @override
  Future<void> deleteLedger({required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.deleteLedger(ledgerId: ledgerId);
  }

  @override
  Future<SpitoutCloudSharedResources> fetchSharedResources(
      {required String ledgerId}) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.fetchSharedResources(ledgerId: ledgerId);
  }

  @override
  Future<SpitoutCloudMemberStats> fetchMemberStats({
    required String ledgerId,
    String scope = 'month',
    String? period,
    int? tzOffsetMinutes,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw CloudConfigurationException(
          'Spitout Cloud storage is not initialized.');
    }
    return storage.fetchMemberStats(
      ledgerId: ledgerId,
      scope: scope,
      period: period,
      tzOffsetMinutes: tzOffsetMinutes,
    );
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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
