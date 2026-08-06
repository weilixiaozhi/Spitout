import '../internal.dart';

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
      id: requireNonEmptyString(json, 'id', 'SpitoutCloudDevice'),
      name: json['name'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      appVersion: trimOrNull(json['app_version'] as String?),
      osVersion: trimOrNull(json['os_version'] as String?),
      deviceModel: trimOrNull(json['device_model'] as String?),
      lastIp: trimOrNull(json['last_ip'] as String?),
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

  /// 支出总额(incomeTotal 已从协议移除,不再区分收支)。
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
      ledgerId:
          requireNonEmptyString(json, 'ledger_id', 'SpitoutCloudReadLedger'),
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
      transactionTotal:
          readTotalOrFallback('transaction_total', 'transaction_count'),
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
      sourceChangeId:
          requireInt(json, 'source_change_id', 'SpitoutCloudReadLedgerDetail'),
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
    this.createdByAccount,
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
  final String? createdByAccount;
  final String? createdByDisplayName;
  final String? createdByAvatarUrl;
  final int? createdByAvatarVersion;

  factory SpitoutCloudReadTransaction.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudReadTransaction(
      id: requireNonEmptyString(json, 'id', 'SpitoutCloudReadTransaction'),
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
      lastChangeId:
          requireInt(json, 'last_change_id', 'SpitoutCloudReadTransaction'),
      ledgerId: json['ledger_id'] as String?,
      ledgerName: json['ledger_name'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByAccount: json['created_by_account'] as String?,
      createdByDisplayName:
          trimOrNull(json['created_by_display_name'] as String?),
      createdByAvatarUrl: trimOrNull(json['created_by_avatar_url'] as String?),
      createdByAvatarVersion:
          (json['created_by_avatar_version'] as num?)?.toInt(),
    );
  }
}

class SpitoutCloudProfile {
  const SpitoutCloudProfile({
    required this.userId,
    this.account,
    this.displayName,
    this.avatarUrl,
    this.avatarVersion = 0,
    this.appearance,
    this.aiConfig,
    this.primaryCurrency,
  });

  final String userId;
  final String? account;
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
      userId: requireNonEmptyString(json, 'user_id', 'SpitoutCloudProfile'),
      account: trimOrNull(json['account'] as String?),
      displayName: trimOrNull(json['display_name'] as String?),
      avatarUrl: trimOrNull(json['avatar_url'] as String?),
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
      appearance: appearanceRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(appearanceRaw)
          : null,
      aiConfig: aiConfigRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(aiConfigRaw)
          : null,
      primaryCurrency: trimOrNull(json['primary_currency'] as String?),
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
      avatarUrl: trimOrNull(json['avatar_url'] as String?),
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
    this.createdByAccount,
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
  final String? createdByAccount;

  factory SpitoutCloudReadCategory.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudReadCategory(
      id: requireNonEmptyString(json, 'id', 'SpitoutCloudReadCategory'),
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'expense',
      level: (json['level'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      icon: json['icon'] as String?,
      parentName: json['parent_name'] as String?,
      lastChangeId:
          requireInt(json, 'last_change_id', 'SpitoutCloudReadCategory'),
      ledgerId: json['ledger_id'] as String?,
      ledgerName: json['ledger_name'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByAccount: json['created_by_account'] as String?,
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
      ledgerId: requireNonEmptyString(
          json, 'ledger_id', 'SpitoutCloudWriteCommitMeta'),
      baseChangeId:
          requireInt(json, 'base_change_id', 'SpitoutCloudWriteCommitMeta'),
      newChangeId:
          requireInt(json, 'new_change_id', 'SpitoutCloudWriteCommitMeta'),
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

// =============================================================================
// 共享账本数据类:邀请 / 成员 / 共享资源 / 成员统计。
// =============================================================================

class SpitoutCloudInvite {
  const SpitoutCloudInvite({
    required this.id,
    required this.formattedCode,
    required this.targetRole,
    this.expiresAt,
    this.createdAt,
    this.code,
    this.codePrefix,
    this.shareUrl,
    this.invitedByUserId,
  });

  /// 邀请唯一 id:创建与列表响应都有,撤销时传这个值。
  final String id;

  /// 6 位明文邀请码(`ABC123`),仅创建响应返回;列表接口出于安全不再返回完整码,为 null。
  final String? code;

  /// 列表掩码前缀(`ABC1`),仅列表响应返回;创建响应为 null。
  final String? codePrefix;

  /// 显示用格式化码:创建响应 "ABC 123"(中间空格易读),列表响应 "ABC1 ••"(掩码)。
  final String formattedCode;
  final String targetRole;

  /// 失效 / 创建时间;server 缺字段或格式异常时为 null,由 UI 决定兜底展示。
  final DateTime? expiresAt;
  final DateTime? createdAt;

  /// 分享短链,仅创建响应返回;列表响应为 null。
  final String? shareUrl;

  /// list endpoint 返回时带,create 不带(创建者自己即 caller)。
  final String? invitedByUserId;

  factory SpitoutCloudInvite.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudInvite(
      id: requireNonEmptyString(json, 'id', 'SpitoutCloudInvite'),
      code: (json['code'] as String?)?.trim(),
      codePrefix: (json['code_prefix'] as String?)?.trim(),
      formattedCode: (json['formatted_code'] as String?)?.trim() ?? '',
      targetRole: (json['target_role'] as String?)?.trim() ?? 'editor',
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc(),
      shareUrl: (json['share_url'] as String?)?.trim(),
      invitedByUserId:
          (json['invited_by_user_id'] as String?)?.trim().isEmpty == true
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
  final DateTime? expiresAt;

  factory SpitoutCloudInvitePreview.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudInvitePreview(
      code: requireNonEmptyString(json, 'code', 'SpitoutCloudInvitePreview'),
      ledgerExternalId: requireNonEmptyString(
          json, 'ledger_external_id', 'SpitoutCloudInvitePreview'),
      ledgerName: json['ledger_name'] as String?,
      ledgerCurrency: (json['ledger_currency'] as String?)?.trim() ?? 'CNY',
      invitedByDisplay:
          (json['invited_by_display'] as String?)?.trim() ?? 'Unknown',
      targetRole: (json['target_role'] as String?)?.trim() ?? 'editor',
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc(),
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
      ledgerExternalId: requireNonEmptyString(
          json, 'ledger_external_id', 'SpitoutCloudInviteAcceptResult'),
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
    required this.account,
    required this.role,
    required this.joinedAt,
    required this.isSelf,
    this.displayName,
    this.invitedByUserId,
    this.avatarUrl,
    this.avatarVersion = 0,
  });

  final String userId;
  final String account;
  final String? displayName;
  final String role;
  final DateTime? joinedAt;
  final String? invitedByUserId;
  final bool isSelf;

  /// server-side relative path,例 "/api/v1/profile/avatar/{uid}?v=N"。null = 用户未上传头像。
  final String? avatarUrl;
  final int avatarVersion;

  factory SpitoutCloudLedgerMember.fromJson(Map<String, dynamic> json) {
    return SpitoutCloudLedgerMember(
      userId:
          requireNonEmptyString(json, 'user_id', 'SpitoutCloudLedgerMember'),
      account: requireNonEmptyString(json, 'account', 'SpitoutCloudLedgerMember'),
      displayName: json['display_name'] as String?,
      role: (json['role'] as String?)?.trim() ?? 'editor',
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '')?.toUtc(),
      invitedByUserId: json['invited_by_user_id'] as String?,
      isSelf: json['is_self'] as bool? ?? false,
      avatarUrl: (json['avatar_url'] as String?)?.trim().isEmpty == true
          ? null
          : json['avatar_url'] as String?,
      avatarVersion: (json['avatar_version'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Editor 接受邀请后拉到的 Owner user-global 资源快照。
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
      ownerUserId: requireNonEmptyString(
          json, 'owner_user_id', 'SpitoutCloudSharedResources'),
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
      syncId:
          requireNonEmptyString(json, 'sync_id', 'SpitoutCloudSharedCategory'),
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
      syncId:
          requireNonEmptyString(json, 'sync_id', 'SpitoutCloudSharedAccount'),
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
class SpitoutCloudMemberStatItem {
  const SpitoutCloudMemberStatItem({
    required this.userId,
    required this.role,
    required this.expenseTotal,
    required this.txCount,
    this.account,
    this.displayName,
    this.avatarUrl,
    this.avatarVersion = 0,
  });

  final String userId;
  final String? account;
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
      userId:
          requireNonEmptyString(json, 'user_id', 'SpitoutCloudMemberStatItem'),
      account: (json['account'] as String?)?.trim().isEmpty == true
          ? null
          : json['account'] as String?,
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
      ledgerId:
          requireNonEmptyString(json, 'ledger_id', 'SpitoutCloudMemberStats'),
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
