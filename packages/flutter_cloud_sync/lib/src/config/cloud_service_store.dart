import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_service_config.dart';

/// 云服务配置持久化存储
/// 支持类型: 本地存储、Spitout Cloud、自定义 Supabase、自定义 WebDAV、S3
class CloudServiceStore {
  static const _kActiveType =
      'cloud_active_type'; // local | spitout_cloud | supabase | webdav | s3
  static const _kSpitoutCloudCfg = 'cloud_spitout_cloud_cfg';
  static const _kSupabaseCfg = 'cloud_supabase_cfg';
  static const _kWebdavCfg = 'cloud_webdav_cfg';
  static const _kS3Cfg = 'cloud_s3_cfg';

  /// 加载当前激活的云服务配置
  Future<CloudServiceConfig> loadActive() async {
    final sp = await SharedPreferences.getInstance();
    final activeType = sp.getString(_kActiveType) ?? 'local';

    switch (activeType) {
      case 'local':
        return CloudServiceConfig.localStorage();

      case 'spitout_cloud':
        final raw = sp.getString(_kSpitoutCloudCfg);
        if (raw != null) {
          try {
            return await _decodeAndMigrate(sp, _kSpitoutCloudCfg, raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        return CloudServiceConfig.localStorage();

      case 'supabase':
        final raw = sp.getString(_kSupabaseCfg);
        if (raw != null) {
          try {
            return await _decodeAndMigrate(sp, _kSupabaseCfg, raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      case 'webdav':
        final raw = sp.getString(_kWebdavCfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      case 's3':
        final raw = sp.getString(_kS3Cfg);
        if (raw != null) {
          try {
            return decodeCloudConfig(raw);
          } catch (e) {
            // 解析失败，静默回退到本地存储
          }
        }
        // 回退到本地存储
        return CloudServiceConfig.localStorage();

      default:
        return CloudServiceConfig.localStorage();
    }
  }

  /// 加载 Spitout Cloud 配置(不管是否激活)
  Future<CloudServiceConfig?> loadSpitoutCloud() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSpitoutCloudCfg);
    if (raw == null) return null;
    try {
      return await _decodeAndMigrate(sp, _kSpitoutCloudCfg, raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载Supabase配置(不管是否激活)
  Future<CloudServiceConfig?> loadSupabase() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSupabaseCfg);
    if (raw == null) return null;
    try {
      return await _decodeAndMigrate(sp, _kSupabaseCfg, raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载WebDAV配置(不管是否激活)
  Future<CloudServiceConfig?> loadWebdav() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kWebdavCfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 加载S3配置(不管是否激活)
  Future<CloudServiceConfig?> loadS3() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kS3Cfg);
    if (raw == null) return null;
    try {
      return decodeCloudConfig(raw);
    } catch (e) {
      return null;
    }
  }

  /// 保存并激活配置
  Future<void> saveAndActivate(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();
    // 登录账号密码仅作一次性输入，落盘前剥离（见 _stripAccountPasswords）。
    cfg = _stripAccountPasswords(cfg);

    switch (cfg.type) {
      case CloudBackendType.local:
        await sp.setString(_kActiveType, 'local');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.spitoutCloud:
        await sp.setString(_kSpitoutCloudCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'spitout_cloud');
        break;

      case CloudBackendType.supabase:
        await sp.setString(_kSupabaseCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'supabase');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.webdav:
        await sp.setString(_kWebdavCfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 'webdav');
        // Provider 会在下次使用时自动初始化
        break;

      case CloudBackendType.s3:
        await sp.setString(_kS3Cfg, encodeCloudConfig(cfg));
        await sp.setString(_kActiveType, 's3');
        // Provider 会在下次使用时自动初始化
        break;
    }
  }

  /// 仅保存配置,不激活
  Future<void> saveOnly(CloudServiceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();
    // 与 saveAndActivate 同策略：登录账号密码不落盘。
    cfg = _stripAccountPasswords(cfg);

    switch (cfg.type) {
      case CloudBackendType.local:
        // 本地存储无需保存
        break;

      case CloudBackendType.spitoutCloud:
        await sp.setString(_kSpitoutCloudCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.supabase:
        await sp.setString(_kSupabaseCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.webdav:
        await sp.setString(_kWebdavCfg, encodeCloudConfig(cfg));
        break;

      case CloudBackendType.s3:
        await sp.setString(_kS3Cfg, encodeCloudConfig(cfg));
        break;
    }
  }

  /// 剥离 Spitout Cloud / Supabase 的登录密码，仅保留邮箱等非敏感配置。
  ///
  /// 设计意图：登录密码只作为一次性输入使用，不写入 SharedPreferences
  /// （Android 侧为明文 XML，且可能随系统备份带走）。WebDAV / S3 的
  /// 访问凭据属于同步必需配置，不在剥离范围内。
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

  /// 解码存量配置并迁移：若历史版本残留了明文密码，读取时立即剥离并回写。
  ///
  /// 返回的配置不再包含密码，后续所有消费方（云客户端 / UI）拿到的都是
  /// 安全形态，无需各自再判空。
  Future<CloudServiceConfig> _decodeAndMigrate(
    SharedPreferences sp,
    String key,
    String raw,
  ) async {
    final cfg = decodeCloudConfig(raw);
    final sanitized = _stripAccountPasswords(cfg);
    if (cfg.spitoutCloudPassword != null || cfg.supabasePassword != null) {
      await sp.setString(key, encodeCloudConfig(sanitized));
    }
    return sanitized;
  }

  /// 清空指定后端的配置,使其回到「未配置」状态。
  /// 注意:无需调用 activate(local) —— loadActive() 在对应配置缺失时会自动回退本地存储。
  Future<void> clearConfig(CloudBackendType type) async {
    final sp = await SharedPreferences.getInstance();
    switch (type) {
      case CloudBackendType.spitoutCloud:
        await sp.remove(_kSpitoutCloudCfg);
      case CloudBackendType.supabase:
        await sp.remove(_kSupabaseCfg);
      case CloudBackendType.webdav:
        await sp.remove(_kWebdavCfg);
      case CloudBackendType.s3:
        await sp.remove(_kS3Cfg);
      case CloudBackendType.local:
        break; // 本地存储无配置,无需清空
    }

    // 独立1:若清掉的正是当前激活的云类型(非 local),把激活标记复位为 'local'。
    // 仅 loadActive 的配置缺失回退是不够的 —— _kActiveType 会残留僵尸脏值
    // (如 'webdav'),持久化状态与真实状态不一致,可能被"当前激活的云类型"
    // 类逻辑误读。仅复位「被清类型==当前激活」的场景:清非激活配置、
    // 或 clearConfig(local) 均不得影响现有激活状态。
    if (type != CloudBackendType.local &&
        sp.getString(_kActiveType) == _typeKey(type)) {
      await sp.setString(_kActiveType, 'local');
    }
  }

  /// 后端类型 → 持久化激活 key 字符串(与 activate/saveAndActivate 保持一致)。
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

  /// 激活指定类型的配置
  Future<bool> activate(CloudBackendType type) async {
    final sp = await SharedPreferences.getInstance();

    switch (type) {
      case CloudBackendType.local:
        await sp.setString(_kActiveType, 'local');
        return true;

      case CloudBackendType.spitoutCloud:
        final raw = sp.getString(_kSpitoutCloudCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'spitout_cloud');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.supabase:
        final raw = sp.getString(_kSupabaseCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'supabase');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.webdav:
        final raw = sp.getString(_kWebdavCfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 'webdav');
          return true;
        } catch (e) {
          return false;
        }

      case CloudBackendType.s3:
        final raw = sp.getString(_kS3Cfg);
        if (raw == null) return false;
        try {
          final cfg = decodeCloudConfig(raw);
          if (!cfg.valid) return false;
          await sp.setString(_kActiveType, 's3');
          return true;
        } catch (e) {
          return false;
        }
    }
  }
}
