import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/spitout_cloud_auth_service.dart';
import '../internal.dart';
import '../models/spitout_cloud_models.dart';

class SpitoutCloudStorageService implements CloudStorageService {
  SpitoutCloudStorageService({
    required this.baseUrl,
    required this.apiPrefix,
    required this.auth,
    http.Client? httpClient,
    CloudSyncLogger? logger,
  })  : _httpClient = httpClient ?? defaultHttpClient(),
        _logger = logger ?? defaultCloudLogger;

  final String baseUrl;
  final String apiPrefix;
  final SpitoutCloudAuthService auth;
  final http.Client _httpClient;
  final CloudSyncLogger _logger;

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
          'Upload failed: ${extractErrorMessage(response)}');
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
          'Download failed: ${extractErrorMessage(response)}');
    }

    final payload = decodeJsonObject(response.body);
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
          'Delete failed: ${extractErrorMessage(response)}');
    }
  }

  @override
  Future<List<CloudFile>> list({required String path}) async {
    final prefix = PathHelper.normalize(path);
    final response = await _authedRequest(method: 'GET', path: '/sync/ledgers');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List failed: ${extractErrorMessage(response)}');
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
          'Pull failed: ${extractErrorMessage(response)}');
    }

    final payload = decodeJsonObject(response.body);
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
    if (deviceId == null || deviceId.isEmpty) {
      _logger.warning(
          '[SpitoutCloud-Storage] pushEntityChanges: deviceId 为空,抛出认证异常');
      throw CloudNotAuthenticatedException(
          'Missing device id, please login again.');
    }
    _logger.debug(
        '[SpitoutCloud-Storage] pushEntityChanges: ${changes.length} changes');
    final response = await _authedRequest(
      method: 'POST',
      path: '/sync/push',
      body: {
        'device_id': deviceId,
        'changes': changes,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Push entity changes failed (${response.statusCode}): ${extractErrorMessage(response)}');
    }
  }

  Future<SpitoutCloudProfile> getMyProfile() async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/profile/me',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Get profile failed: ${extractErrorMessage(response)}');
    }
    final payload = decodeJsonObject(response.body);
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
          'Fetch exchange rates failed: ${extractErrorMessage(response)}');
    }
    return decodeJsonObject(response.body);
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
          'Update profile failed: ${extractErrorMessage(response)}');
    }
    final payload = decodeJsonObject(response.body);
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
        // 刷新失败分两种:session 仍在 = 瞬时故障(网络/5xx),抛可重试错误;
        // session 已被清 = 凭证确认失效(401/403),才抛未认证。
        if (auth.currentUserId != null) {
          throw CloudStorageException(
              'Cloud unavailable, session preserved.');
        }
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
    // 刷新后仍被拒 = 会话彻底失效,抛未认证异常而不是存储异常,
    // 让上层走重新登录分支而不是误判为存储故障。
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CloudNotAuthenticatedException(
          'Session expired, please login again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Avatar upload failed: ${extractErrorMessage(response)}');
    }
    final payload = decodeJsonObject(response.body);
    return SpitoutCloudAvatarUploadResult.fromJson(
      _copyWithNormalizedUrl(payload, 'avatar_url'),
    );
  }

  Future<Uint8List> downloadMyAvatar({
    required String userId,
    int? version,
  }) async {
    // 已知风险:服务端 avatar GET 端点当前不校验 auth(为 Web <img> 无头
    // 加载而设计,仅校验 user_id 为 UUID),按用户 id 可枚举下载公开头像。
    // 客户端仍带 Authorization 头请求;服务端补鉴权 / 签名 URL 属于独立的
    // 服务端改造项,不在本包内处理。
    final response = await _authedRequest(
      method: 'GET',
      path: '/profile/avatar/${encodePathSegment(userId)}',
      query: version != null ? {'v': '$version'} : null,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Avatar download failed: ${extractErrorMessage(response)}');
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
          'Avatar delete failed: ${extractErrorMessage(response)}');
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
          'List devices failed: ${extractErrorMessage(response)}');
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
      path: '/devices/${encodePathSegment(deviceId)}/revoke',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Revoke device failed: ${extractErrorMessage(response)}');
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
        'Read ledgers failed: ${extractErrorMessage(response)}',
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
      path: '/read/ledgers/${encodePathSegment(ledgerId)}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read ledger detail failed: ${extractErrorMessage(response)}');
    }
    final payload = decodeJsonObject(response.body);
    return SpitoutCloudReadLedgerDetail.fromJson(payload);
  }

  /// 读 server 上某账本的实体计数(transaction / category)。给"深度同步检测"
  /// 用,mobile 对比本地 Drift 计数就能判断是否需要触发一次完整 sync。
  Future<SpitoutCloudLedgerStats> readLedgerStats({
    required String ledgerId,
  }) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/read/ledgers/${encodePathSegment(ledgerId)}/stats',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 携带 statusCode:checkSyncHealth 的 stats 失败会展示给用户,
      // 404(账本不存在)与 5xx(服务端故障)需要区分,便于定位是"本地
      // syncId 失效"还是"云端问题"。
      throw CloudStorageException(
        'Read ledger stats failed: ${extractErrorMessage(response)}',
        null,
        response.statusCode,
      );
    }
    final payload = decodeJsonObject(response.body);
    return SpitoutCloudLedgerStats.fromJson(payload);
  }

  /// 拉 server 公开 /version。绕开 auth token —— 登录页未登录状态下也该能
  /// 显示 server 版本,不需要 token。
  Future<SpitoutCloudServerVersion> fetchServerVersion() async {
    final uri = Uri.parse('$baseUrl$apiPrefix/version');
    // 不用 _httpClient.get():与其他 5 处出口统一走 sendWithTimeout,
    // 保证 grep 审计时不漏出口。
    final response = await sendWithTimeout(
      _httpClient,
      http.Request('GET', uri),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch version failed: ${extractErrorMessage(response)}');
    }
    final payload = decodeJsonObject(response.body);
    return SpitoutCloudServerVersion.fromJson(payload);
  }

  // ===========================================================================
  // 共享账本 — invites / members / shared-resources HTTP 实现
  // ===========================================================================

  Future<SpitoutCloudInvite> createInvite({
    required String ledgerId,
    required String role,
    required int expiresInHours,
  }) async {
    final response = await _authedRequest(
      method: 'POST',
      path: '/ledgers/${encodePathSegment(ledgerId)}/invites',
      body: {'role': role, 'expires_in_hours': expiresInHours},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Create invite failed: ${extractErrorMessage(response)}');
    }
    return SpitoutCloudInvite.fromJson(decodeJsonObject(response.body));
  }

  Future<List<SpitoutCloudInvite>> listInvites(
      {required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/ledgers/${encodePathSegment(ledgerId)}/invites',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'List invites failed: ${extractErrorMessage(response)}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (row is Map<String, dynamic>) SpitoutCloudInvite.fromJson(row),
    ];
  }

  /// 撤销邀请:优先用邀请 id,未传时回退到完整明文码(兼容旧调用)。
  ///
  /// 列表接口不返回完整码,UI 撤销必须用列表里的 id;创建响应里拿到的
  /// 完整码仍可撤销,故保留 [code] 分支,server 对两种 key 都接受。
  Future<void> revokeInvite({
    required String ledgerId,
    String? inviteId,
    String? code,
  }) async {
    final key = inviteId ?? code;
    if (key == null || key.isEmpty) {
      throw ArgumentError('revokeInvite 需要 inviteId 或 code 其中之一');
    }
    final response = await _authedRequest(
      method: 'DELETE',
      path:
          '/ledgers/${encodePathSegment(ledgerId)}/invites/${encodePathSegment(key)}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Revoke invite failed: ${extractErrorMessage(response)}');
    }
  }

  Future<SpitoutCloudInvitePreview> previewInvite(
      {required String code}) async {
    final response = await _authedRequest(
      method: 'POST',
      path: '/invites/${encodePathSegment(code)}/preview',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Preview invite failed: ${extractErrorMessage(response)}');
    }
    return SpitoutCloudInvitePreview.fromJson(decodeJsonObject(response.body));
  }

  Future<SpitoutCloudInviteAcceptResult> acceptInvite(
      {required String code}) async {
    final response = await _authedRequest(
      method: 'POST',
      path: '/invites/${encodePathSegment(code)}/accept',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Accept invite failed: ${extractErrorMessage(response)}');
    }
    return SpitoutCloudInviteAcceptResult.fromJson(
        decodeJsonObject(response.body));
  }

  Future<List<SpitoutCloudLedgerMember>> listMembers(
      {required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/ledgers/${encodePathSegment(ledgerId)}/members',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 透传 statusCode:调用方据此区分「账本尚未就绪」(404,云端账本刚 moveToCloud
      // 但首次 push 未完成,listMembers 会 404,属暂时性,PushCompleted 事件会自动
      // invalidate 重拉)与「真实错误」(5xx/401 等,需展示错误卡片 + 重试)。
      throw CloudStorageException(
        'List members failed: ${extractErrorMessage(response)}',
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
      path:
          '/ledgers/${encodePathSegment(ledgerId)}/members/${encodePathSegment(userId)}',
      body: {'role': role},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Update member role failed: ${extractErrorMessage(response)}');
    }
    return SpitoutCloudLedgerMember.fromJson(decodeJsonObject(response.body));
  }

  Future<void> removeMember(
      {required String ledgerId, required String userId}) async {
    final response = await _authedRequest(
      method: 'DELETE',
      path:
          '/ledgers/${encodePathSegment(ledgerId)}/members/${encodePathSegment(userId)}',
    );
    // 404 视为目标成员已不存在(已被踢 / 已退出)→ 幂等成功,直接吞掉。
    // 与 download 的 404 处理风格一致,避免「list 完到 remove 之间被踢」的竞态报错。
    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Remove member failed: ${extractErrorMessage(response)}');
    }
  }

  /// 删除整本账本(Owner 全局删除)。
  ///
  /// 走 server 的 `/write/ledgers/{id}`,server 会在事务内级联删掉所有非 owner 成员
  /// 并向各成员广播 `member_change.removed`。客户端无需自己循环踢人。
  Future<void> deleteLedger({required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'DELETE',
      path: '/write/ledgers/${encodePathSegment(ledgerId)}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Delete ledger failed: ${extractErrorMessage(response)}');
    }
  }

  /// 拉 Owner 的 user-global 资源快照(Editor 端 picker 用)。
  Future<SpitoutCloudSharedResources> fetchSharedResources(
      {required String ledgerId}) async {
    final response = await _authedRequest(
      method: 'GET',
      path: '/ledgers/${encodePathSegment(ledgerId)}/shared-resources',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch shared resources failed: ${extractErrorMessage(response)}');
    }
    return SpitoutCloudSharedResources.fromJson(
        decodeJsonObject(response.body));
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
      path: '/ledgers/${encodePathSegment(ledgerId)}/member-stats',
      query: qp,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Fetch member stats failed: ${extractErrorMessage(response)}');
    }
    return SpitoutCloudMemberStats.fromJson(decodeJsonObject(response.body));
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
      path: '/read/ledgers/${encodePathSegment(ledgerId)}/transactions',
      query: qp,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read transactions failed: ${extractErrorMessage(response)}');
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
      path: '/read/ledgers/${encodePathSegment(ledgerId)}/categories',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudStorageException(
          'Read categories failed: ${extractErrorMessage(response)}');
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
      path: '/write/ledgers/${encodePathSegment(ledgerId)}/meta',
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
      path: '/write/ledgers/${encodePathSegment(ledgerId)}/transactions',
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
      path:
          '/write/ledgers/${encodePathSegment(ledgerId)}/transactions/${encodePathSegment(txId)}',
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
      path: '/write/ledgers/${encodePathSegment(ledgerId)}/categories',
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
      path:
          '/write/ledgers/${encodePathSegment(ledgerId)}/categories/${encodePathSegment(categoryId)}',
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
          'Write request failed: ${extractErrorMessage(response)}');
    }
    final payload = decodeJsonObject(response.body);
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
        // 刷新失败分两种:session 仍在 = 瞬时故障(网络/5xx),抛可重试错误;
        // session 已被清 = 凭证确认失效(401/403),才抛未认证。
        if (auth.currentUserId != null) {
          throw CloudStorageException(
              'Cloud unavailable, session preserved.');
        }
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

    // 刷新后重试仍返回 401/403 = 会话彻底失效,必须抛未认证异常而不是
    // 存储异常,让上层走重新登录分支而不是误判为存储故障。
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CloudNotAuthenticatedException(
          'Session expired, please login again.');
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
    if (!isHttpTransportAllowed(uri)) {
      throw CloudConfigurationException(
        'Insecure HTTP transport is not allowed for remote Spitout Cloud '
        'servers. Use https:// (http is only allowed for localhost or '
        'private-network testing).',
      );
    }
    final request = http.Request(method, uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    if (headers != null && headers.isNotEmpty) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return sendWithTimeout(_httpClient, request);
  }

  Future<http.Response> _profileAvatarMultipartRequest({
    required Uint8List bytes,
    required String fileName,
    required String token,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl$apiPrefix/profile/avatar');
    if (!isHttpTransportAllowed(uri)) {
      throw CloudConfigurationException(
        'Insecure HTTP transport is not allowed for remote Spitout Cloud '
        'servers. Use https:// (http is only allowed for localhost or '
        'private-network testing).',
      );
    }
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
    return sendWithTimeout(
      _httpClient,
      request,
      sendTimeout: const Duration(seconds: 60),
    );
  }
}
