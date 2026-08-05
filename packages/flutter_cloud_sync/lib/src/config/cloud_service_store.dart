import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'cloud_credential_storage.dart';
import 'cloud_service_config.dart';

/// 云服务配置持久化存储（唯一的配置写入口）。
///
/// 设计意图：
/// 1. 登录密码（Spitout Cloud / Supabase）只作为一次性输入，写入前剥离，
///    永不清真落盘（Android 侧 SharedPreferences 是明文 XML，且可能随系统备份带走）；
/// 2. WebDAV / S3 的访问凭据是同步运行所必需的，通过可插拔
///    [CloudCredentialStorage] 存放；默认实现仍是 SharedPreferences（明文取舍），
///    生产环境可替换为 Keychain / Keystore 实现；
/// 3. 业务层不得直接 `setString` 云配置键，导入 / 修改统一走本类的受控方法，
///    由本类内部完成剥离、占位符合并与迁移。
class CloudServiceStore {
  /// 激活后端类型标记键（取值见 [_typeKey]）。
  static const activeTypeKey = 'cloud_active_type';

  /// Spitout Cloud 配置键。
  static const spitoutCloudCfgKey = 'cloud_spitout_cloud_cfg';

  /// Supabase 配置键。
  static const supabaseCfgKey = 'cloud_supabase_cfg';

  /// WebDAV 配置键。
  static const webdavCfgKey = 'cloud_webdav_cfg';

  /// S3 配置键。
  static const s3CfgKey = 'cloud_s3_cfg';

  /// 脱敏导出使用的占位符，导入时不得视为真实凭据。
  static const maskedPlaceholder = '***';

  final CloudCredentialStorage _credentialStorage;
  final CloudSyncLogger? _logger;

  CloudServiceStore({
    CloudCredentialStorage? credentialStorage,
    CloudSyncLogger? logger,
  })  : _credentialStorage =
            credentialStorage ?? SharedPreferencesCredentialStorage(),
        _logger = logger;

  /// 加载当前激活的云服务配置。
  ///
  /// 配置缺失或解析失败时回退本地存储，并记录 warning 日志便于排查。
  Future<CloudServiceConfig> loadActive() async {
    final sp = await SharedPreferences.getInstance();
    final activeType = sp.getString(activeTypeKey) ?? 'local';

    switch (activeType) {
      case 'local':
        return CloudServiceConfig.localStorage();
      case 'spitout_cloud':
        return (await _loadConfig(sp, CloudBackendType.spitoutCloud)) ??
            CloudServiceConfig.localStorage();
      case 'supabase':
        return (await _loadConfig(sp, CloudBackendType.supabase)) ??
            CloudServiceConfig.localStorage();
      case 'webdav':
        return (await _loadConfig(sp, CloudBackendType.webdav)) ??
            CloudServiceConfig.localStorage();
      case 's3':
        return (await _loadConfig(sp, CloudBackendType.s3)) ??
            CloudServiceConfig.localStorage();
      default:
        return CloudServiceConfig.localStorage();
    }
  }

  /// 加载 Spitout Cloud 配置（不管是否激活）。
  Future<CloudServiceConfig?> loadSpitoutCloud() async {
    final sp = await SharedPreferences.getInstance();
    return _loadConfig(sp, CloudBackendType.spitoutCloud);
  }

  /// 加载 Supabase 配置（不管是否激活）。
  Future<CloudServiceConfig?> loadSupabase() async {
    final sp = await SharedPreferences.getInstance();
    return _loadConfig(sp, CloudBackendType.supabase);
  }

  /// 加载 WebDAV 配置（不管是否激活）。
  Future<CloudServiceConfig?> loadWebdav() async {
    final sp = await SharedPreferences.getInstance();
    return _loadConfig(sp, CloudBackendType.webdav);
  }

  /// 加载 S3 配置（不管是否激活）。
  Future<CloudServiceConfig?> loadS3() async {
    final sp = await SharedPreferences.getInstance();
    return _loadConfig(sp, CloudBackendType.s3);
  }

  /// 保存并激活配置。
  ///
  /// 写入前统一剥离登录密码；WebDAV / S3 凭据转入凭据存储。
  Future<void> saveAndActivate(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();
    await _writeConfig(sp, cfg.type, cfg);
    await sp.setString(activeTypeKey, _typeKey(cfg.type));
  }

  /// 仅保存配置，不激活。
  Future<void> saveOnly(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();
    await _writeConfig(sp, cfg.type, cfg);
  }

  /// 从外部配置（YAML 导入等）写入云服务配置，唯一受控的导入入口。
  ///
  /// [includeCredentials] 表示导入源是否显式携带凭据。为 false，或字段值为
  /// 脱敏占位符 `***` 时，保留本机现有凭据，避免用占位符覆盖真实密钥；
  /// 登录密码（Spitout Cloud / Supabase）无论是否携带都按策略剥离。
  Future<void> saveImported(
    CloudServiceConfig cfg, {
    bool includeCredentials = false,
  }) async {
    final sp = await SharedPreferences.getInstance();

    // 读取本机现有配置，用于合并 WebDAV / S3 凭据。
    CloudServiceConfig? existing;
    final existingKey = _configKey(cfg.type);
    final existingRaw = existingKey != null ? sp.getString(existingKey) : null;
    if (existingRaw != null) {
      try {
        existing = await _decodeAndMigrate(
          sp,
          existingKey!,
          cfg.type,
          existingRaw,
        );
      } catch (e) {
        _warn('读取现有云配置失败，导入时按无配置处理（${cfg.type.name}）', e);
      }
    }

    final merged = _mergeImportedCredentials(cfg, existing,
        includeCredentials: includeCredentials);
    await _writeConfig(sp, cfg.type, merged);
  }

  /// 剥离 Spitout Cloud / Supabase 的登录密码，仅保留邮箱等非敏感配置。
  ///
  /// 设计意图：登录密码只作为一次性输入使用，不写入 SharedPreferences
  /// （Android 侧为明文 XML，且可能随系统备份带走）。WebDAV / S3 的
  /// 访问凭据属于同步必需配置，不在剥离范围内，由凭据存储统一保管。
  CloudServiceConfig _stripAccountPasswords(CloudServiceConfig cfg) {
    if (cfg.type != CloudBackendType.spitoutCloud &&
        cfg.type != CloudBackendType.supabase) {
      return cfg;
    }
    return CloudServiceConfig(
      type: cfg.type,
      name: cfg.name,
      spitoutCloudBaseUrl: cfg.spitoutCloudBaseUrl,
      spitoutCloudApiPrefix: cfg.spitoutCloudApiPrefix,
      spitoutCloudEmail: cfg.spitoutCloudEmail,
      supabaseUrl: cfg.supabaseUrl,
      supabaseAnonKey: cfg.supabaseAnonKey,
      supabaseBucket: cfg.supabaseBucket,
      supabaseEmail: cfg.supabaseEmail,
    );
  }

  /// 合并导入配置与本机现有凭据。
  ///
  /// 规则：仅当显式包含凭据且值不是脱敏占位符时才采用导入值，否则保留本机值；
  /// S3 的 accessKey 历史上总是明文导出，因此只要非占位符就直接采用。
  CloudServiceConfig _mergeImportedCredentials(
    CloudServiceConfig incoming,
    CloudServiceConfig? existing, {
    required bool includeCredentials,
  }) {
    String? merge(String? incomingValue, String? current) {
      if (includeCredentials &&
          incomingValue != null &&
          incomingValue != maskedPlaceholder) {
        return incomingValue;
      }
      return current;
    }

    return CloudServiceConfig(
      type: incoming.type,
      name: incoming.name,
      spitoutCloudBaseUrl: incoming.spitoutCloudBaseUrl,
      spitoutCloudApiPrefix: incoming.spitoutCloudApiPrefix,
      spitoutCloudEmail: incoming.spitoutCloudEmail,
      // 登录密码永不清真存储，导入后由用户在下一次登录时输入。
      spitoutCloudPassword: null,
      supabaseUrl: incoming.supabaseUrl,
      supabaseAnonKey: incoming.supabaseAnonKey,
      supabaseBucket: incoming.supabaseBucket,
      supabaseEmail: incoming.supabaseEmail,
      supabasePassword: null,
      webdavUrl: incoming.webdavUrl,
      webdavUsername: incoming.webdavUsername,
      webdavPassword: merge(incoming.webdavPassword, existing?.webdavPassword),
      webdavRemotePath: incoming.webdavRemotePath,
      s3Endpoint: incoming.s3Endpoint,
      s3Region: incoming.s3Region,
      s3AccessKey: (incoming.s3AccessKey != null &&
              incoming.s3AccessKey != maskedPlaceholder)
          ? incoming.s3AccessKey
          : existing?.s3AccessKey,
      s3SecretKey: merge(incoming.s3SecretKey, existing?.s3SecretKey),
      s3Bucket: incoming.s3Bucket,
      s3UseSSL: incoming.s3UseSSL,
      s3Port: incoming.s3Port,
    );
  }

  /// 统一读取并迁移指定后端的配置。
  ///
  /// 返回的配置已合并凭据存储中的 WebDAV / S3 凭据，且不含登录密码；
  /// 若旧数据残留明文密码 / 凭据，读取时立即回写为安全形态。
  Future<CloudServiceConfig?> _loadConfig(
    SharedPreferences sp,
    CloudBackendType type,
  ) async {
    final key = _configKey(type);
    if (key == null) return null;
    final raw = sp.getString(key);
    if (raw == null) return null;
    try {
      return await _decodeAndMigrate(sp, key, type, raw);
    } catch (e) {
      _warn('解析 ${type.name} 配置失败，按未配置处理', e);
      return null;
    }
  }

  /// 解码存量配置并执行迁移。
  Future<CloudServiceConfig> _decodeAndMigrate(
    SharedPreferences sp,
    String key,
    CloudBackendType type,
    String raw,
  ) async {
    final cfg = decodeCloudConfig(raw);

    // 合并凭据存储中的 WebDAV / S3 凭据（若存在）。
    var merged = cfg;
    final storedSecrets = await _credentialStorage.read(type);
    if (storedSecrets != null && storedSecrets.isNotEmpty) {
      merged = _withSecrets(cfg, storedSecrets);
    }

    final sanitized = _stripAccountPasswords(merged);

    // 旧数据迁移：JSON 中仍残留登录密码或 WebDAV / S3 明文凭据时，
    // 回写为“JSON 不含敏感字段 + 凭据入凭据存储”的安全形态。
    if (_hasLegacySecrets(cfg)) {
      await _writeConfig(sp, type, sanitized);
    }
    return sanitized;
  }

  /// 判断存量 JSON 是否仍内嵌敏感字段（需要迁移）。
  bool _hasLegacySecrets(CloudServiceConfig cfg) {
    return cfg.spitoutCloudPassword != null ||
        cfg.supabasePassword != null ||
        cfg.webdavPassword != null ||
        cfg.s3AccessKey != null ||
        cfg.s3SecretKey != null;
  }

  /// 将凭据 JSON 合并回配置对象；解析失败时保留配置内旧值。
  CloudServiceConfig _withSecrets(CloudServiceConfig cfg, String rawSecrets) {
    try {
      final secrets = jsonDecode(rawSecrets) as Map<String, dynamic>;
      return CloudServiceConfig(
        type: cfg.type,
        name: cfg.name,
        spitoutCloudBaseUrl: cfg.spitoutCloudBaseUrl,
        spitoutCloudApiPrefix: cfg.spitoutCloudApiPrefix,
        spitoutCloudEmail: cfg.spitoutCloudEmail,
        supabaseUrl: cfg.supabaseUrl,
        supabaseAnonKey: cfg.supabaseAnonKey,
        supabaseBucket: cfg.supabaseBucket,
        supabaseEmail: cfg.supabaseEmail,
        webdavUrl: cfg.webdavUrl,
        webdavUsername: cfg.webdavUsername,
        webdavPassword:
            (secrets['webdavPassword'] as String?) ?? cfg.webdavPassword,
        webdavRemotePath: cfg.webdavRemotePath,
        s3Endpoint: cfg.s3Endpoint,
        s3Region: cfg.s3Region,
        s3AccessKey: (secrets['s3AccessKey'] as String?) ?? cfg.s3AccessKey,
        s3SecretKey: (secrets['s3SecretKey'] as String?) ?? cfg.s3SecretKey,
        s3Bucket: cfg.s3Bucket,
        s3UseSSL: cfg.s3UseSSL,
        s3Port: cfg.s3Port,
      );
    } catch (e) {
      _warn('解析凭据存储失败，使用配置内旧值（${cfg.type.name}）', e);
      return cfg;
    }
  }

  /// 统一写配置：敏感字段进凭据存储，SharedPreferences 只保存非敏感 JSON。
  Future<void> _writeConfig(
    SharedPreferences sp,
    CloudBackendType type,
    CloudServiceConfig cfg,
  ) async {
    final key = _configKey(type);
    if (key == null) return;

    // 先剥离登录密码，再抽取 WebDAV / S3 凭据。
    final sanitized = _stripAccountPasswords(cfg);
    final secrets = <String, String>{
      if (sanitized.webdavPassword != null)
        'webdavPassword': sanitized.webdavPassword!,
      if (sanitized.s3AccessKey != null) 's3AccessKey': sanitized.s3AccessKey!,
      if (sanitized.s3SecretKey != null) 's3SecretKey': sanitized.s3SecretKey!,
    };
    await _credentialStorage.write(type, jsonEncode(secrets));
    await sp.setString(
      key,
      encodeCloudConfig(_withoutSecrets(sanitized)),
    );
  }

  /// 移除 WebDAV / S3 凭据字段，生成可安全写入 SharedPreferences 的配置。
  CloudServiceConfig _withoutSecrets(CloudServiceConfig cfg) {
    return CloudServiceConfig(
      type: cfg.type,
      name: cfg.name,
      spitoutCloudBaseUrl: cfg.spitoutCloudBaseUrl,
      spitoutCloudApiPrefix: cfg.spitoutCloudApiPrefix,
      spitoutCloudEmail: cfg.spitoutCloudEmail,
      supabaseUrl: cfg.supabaseUrl,
      supabaseAnonKey: cfg.supabaseAnonKey,
      supabaseBucket: cfg.supabaseBucket,
      supabaseEmail: cfg.supabaseEmail,
      webdavUrl: cfg.webdavUrl,
      webdavUsername: cfg.webdavUsername,
      webdavRemotePath: cfg.webdavRemotePath,
      s3Endpoint: cfg.s3Endpoint,
      s3Region: cfg.s3Region,
      s3Bucket: cfg.s3Bucket,
      s3UseSSL: cfg.s3UseSSL,
      s3Port: cfg.s3Port,
    );
  }

  /// 清空指定后端的配置，使其回到「未配置」状态。
  ///
  /// 注意：无需调用 activate(local) —— loadActive() 在对应配置缺失时会自动回退
  /// 本地存储。若清掉的正是不活跃类型，不得影响现有激活状态。
  Future<void> clearConfig(CloudBackendType type) async {
    final sp = await SharedPreferences.getInstance();
    final key = _configKey(type);
    if (key != null) {
      await sp.remove(key);
      await _credentialStorage.delete(type);
    }

    // 独立1：若清掉的正是当前激活的云类型（非 local），把激活标记复位为 'local'。
    // 仅 loadActive 的配置缺失回退是不够的 —— activeTypeKey 会残留僵尸脏值
    // （如 'webdav'），持久化状态与真实状态不一致，可能被「当前激活的云类型」
    // 类逻辑误读。仅复位「被清类型 == 当前激活」的场景：清非激活配置、
    // 或 clearConfig(local) 均不得影响现有激活状态。
    if (type != CloudBackendType.local &&
        sp.getString(activeTypeKey) == _typeKey(type)) {
      await sp.setString(activeTypeKey, 'local');
    }
  }

  /// 后端类型 → 持久化配置 key（local 无独立配置，返回 null）。
  static String? _configKey(CloudBackendType type) {
    switch (type) {
      case CloudBackendType.local:
        return null;
      case CloudBackendType.spitoutCloud:
        return spitoutCloudCfgKey;
      case CloudBackendType.supabase:
        return supabaseCfgKey;
      case CloudBackendType.webdav:
        return webdavCfgKey;
      case CloudBackendType.s3:
        return s3CfgKey;
    }
  }

  /// 后端类型 → 持久化激活 key 字符串（与 saveAndActivate 保持一致）。
  static String _typeKey(CloudBackendType type) {
    switch (type) {
      case CloudBackendType.local:
        return 'local';
      case CloudBackendType.spitoutCloud:
        return 'spitout_cloud';
      case CloudBackendType.supabase:
        return 'supabase';
      case CloudBackendType.webdav:
        return 'webdav';
      case CloudBackendType.s3:
        return 's3';
    }
  }

  /// 激活指定类型的配置。
  ///
  /// 仅当配置存在且完整时才激活；激活前会先执行读取迁移，
  /// 确保 WebDAV / S3 凭据已从凭据存储合并回来再校验。
  Future<bool> activate(CloudBackendType type) async {
    final sp = await SharedPreferences.getInstance();

    if (type == CloudBackendType.local) {
      await sp.setString(activeTypeKey, 'local');
      return true;
    }

    final cfg = await _loadConfig(sp, type);
    if (cfg == null || !cfg.valid) return false;
    await sp.setString(activeTypeKey, _typeKey(type));
    return true;
  }

  /// 记录 warning 日志（配置解析 / 迁移失败必须可见，避免静默吞错）。
  void _warn(String message, Object? error) {
    _logger?.warning(error == null ? message : '$message: $error');
  }
}
