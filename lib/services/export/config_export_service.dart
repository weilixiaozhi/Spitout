import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/services/notification/reminder_constants.dart';

// 导入 OrderingTerm
typedef OrderingTerm = d.OrderingTerm;

/// 导出选项 - 控制导出哪些内容
class ExportOptions {
  final bool ledgers;
  final bool categories;
  final bool recurringTransactions;
  final bool appSettings; // 包含云服务配置等
  final bool includeCredentials; // 是否在导出文件中写入密码/密钥

  const ExportOptions({
    this.ledgers = true,
    this.categories = true,
    this.recurringTransactions = true,
    this.appSettings = true,
    this.includeCredentials = false,
  });

  /// 全选
  static const all = ExportOptions();

  /// 全不选
  static const none = ExportOptions(
    ledgers: false,
    categories: false,
    recurringTransactions: false,
    appSettings: false,
    includeCredentials: false,
  );
}

/// 应用配置模型
class AppConfig {
  final SupabaseConfig? supabase;
  final WebdavConfig? webdav;
  final S3Config? s3;
  final SpitoutCloudConfig? spitoutCloud;
  final AppSettingsConfig? appSettings;
  final LedgersConfig? ledgers;
  final RecurringTransactionsConfig? recurringTransactions;
  final CategoriesConfig? categories;

  const AppConfig({
    this.supabase,
    this.webdav,
    this.s3,
    this.spitoutCloud,
    this.appSettings,
    this.ledgers,
    this.recurringTransactions,
    this.categories,
  });

  Map<String, dynamic> toYaml({bool includeCredentials = false}) {
    final map = <String, dynamic>{};

    if (supabase != null) {
      map['supabase'] = supabase!.toMap(includeCredentials: includeCredentials);
    }

    if (spitoutCloud != null) {
      map['spitout_cloud'] = spitoutCloud!.toMap(
        includeCredentials: includeCredentials,
      );
    }

    if (webdav != null) {
      map['webdav'] = webdav!.toMap(includeCredentials: includeCredentials);
    }

    if (s3 != null) {
      map['s3'] = s3!.toMap(includeCredentials: includeCredentials);
    }

    if (appSettings != null) {
      map['app_settings'] = appSettings!.toMap();
    }

    if (ledgers != null) {
      map['ledgers'] = ledgers!.toMap();
    }

    if (recurringTransactions != null) {
      map['recurring_transactions'] = recurringTransactions!.toMap();
    }

    if (categories != null) {
      map['categories'] = categories!.toMap();
    }

    return map;
  }

  static AppConfig fromYaml(Map<dynamic, dynamic> yaml) {
    return AppConfig(
      supabase: yaml.containsKey('supabase')
          ? SupabaseConfig.fromMap(
              Map<String, dynamic>.from(yaml['supabase'] as Map),
            )
          : null,
      webdav: yaml.containsKey('webdav')
          ? WebdavConfig.fromMap(
              Map<String, dynamic>.from(yaml['webdav'] as Map),
            )
          : null,
      s3: yaml.containsKey('s3')
          ? S3Config.fromMap(Map<String, dynamic>.from(yaml['s3'] as Map))
          : null,
      spitoutCloud: yaml.containsKey('spitout_cloud')
          ? SpitoutCloudConfig.fromMap(
              Map<String, dynamic>.from(yaml['spitout_cloud'] as Map),
            )
          : null,
      appSettings: yaml.containsKey('app_settings')
          ? AppSettingsConfig.fromMap(
              Map<String, dynamic>.from(yaml['app_settings'] as Map),
            )
          : null,
      ledgers: yaml.containsKey('ledgers')
          ? LedgersConfig.fromMap(
              Map<String, dynamic>.from(yaml['ledgers'] as Map),
            )
          : null,
      recurringTransactions: yaml.containsKey('recurring_transactions')
          ? RecurringTransactionsConfig.fromMap(
              Map<String, dynamic>.from(yaml['recurring_transactions'] as Map),
            )
          : null,
      categories: yaml.containsKey('categories')
          ? CategoriesConfig.fromMap(
              Map<String, dynamic>.from(yaml['categories'] as Map),
            )
          : null,
    );
  }
}

/// Supabase配置
class SupabaseConfig {
  final String url;
  final String anonKey;
  final String? bucket;
  final String? account;
  final String? password;

  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    this.bucket,
    this.account,
    this.password,
  });

  Map<String, dynamic> toMap({bool includeCredentials = false}) {
    final map = <String, dynamic>{'url': url, 'anon_key': anonKey};
    if (bucket != null && bucket!.isNotEmpty) {
      map['bucket'] = bucket;
    }
    if (account != null && account!.isNotEmpty) {
      map['account'] = account;
    }
    if (password != null && password!.isNotEmpty) {
      // 默认脱敏：只有显式勾选“包含凭据”才写入明文密码。
      map['password'] = includeCredentials ? password : '***';
    }
    return map;
  }

  static SupabaseConfig fromMap(Map<String, dynamic> map) => SupabaseConfig(
    url: map['url'] as String,
    anonKey: map['anon_key'] as String,
    bucket: map['bucket'] as String?,
    account: map['account'] as String?,
    password: map['password'] as String?,
  );
}

/// Spitout Cloud 配置（自部署 FastAPI 后端的 base URL + 可选登录态）
///
/// 多设备同步测试的便利入口：A 设备导出配置，B 设备导入就能直接进入 Cloud 模式
/// 而不用再手动敲 server URL / 登录。
///
/// 安全：accessToken / refreshToken 是登录态，导出的 yaml 文件要当作密钥级别
/// 保管。导出 UI 应默认不带 token，只有显式勾选"包含登录态"才会写进来。
class SpitoutCloudConfig {
  final String baseUrl;
  final String? account;
  final String? password;
  final String? accessToken;
  final String? refreshToken;
  final String? deviceId;

  const SpitoutCloudConfig({
    required this.baseUrl,
    this.account,
    this.password,
    this.accessToken,
    this.refreshToken,
    this.deviceId,
  });

  Map<String, dynamic> toMap({bool includeCredentials = false}) {
    final map = <String, dynamic>{'base_url': baseUrl};
    if (account != null && account!.isNotEmpty) map['account'] = account;
    if (password != null && password!.isNotEmpty) {
      map['password'] = includeCredentials ? password : '***';
    }
    if (accessToken != null && accessToken!.isNotEmpty) {
      // 登录态 token 与密码同级敏感:未勾选凭据导出时一律脱敏。
      map['access_token'] = includeCredentials ? accessToken : '***';
    }
    if (refreshToken != null && refreshToken!.isNotEmpty) {
      map['refresh_token'] = includeCredentials ? refreshToken : '***';
    }
    if (deviceId != null && deviceId!.isNotEmpty) {
      map['device_id'] = includeCredentials ? deviceId : '***';
    }
    return map;
  }

  static SpitoutCloudConfig fromMap(Map<String, dynamic> map) =>
      SpitoutCloudConfig(
        baseUrl: map['base_url'] as String,
        account: map['account'] as String?,
        password: map['password'] as String?,
        accessToken: map['access_token'] as String?,
        refreshToken: map['refresh_token'] as String?,
        deviceId: map['device_id'] as String?,
      );
}

/// WebDAV配置
class WebdavConfig {
  final String url;
  final String username;
  final String password;
  final String? remotePath;

  const WebdavConfig({
    required this.url,
    required this.username,
    required this.password,
    this.remotePath,
  });

  Map<String, dynamic> toMap({bool includeCredentials = false}) {
    final map = <String, dynamic>{
      'url': url,
      'username': username,
      'password': includeCredentials ? password : '***',
    };
    if (remotePath != null && remotePath!.isNotEmpty) {
      map['remote_path'] = remotePath;
    }
    return map;
  }

  static WebdavConfig fromMap(Map<String, dynamic> map) => WebdavConfig(
    url: map['url'] as String,
    username: map['username'] as String,
    password: map['password'] as String,
    remotePath: map['remote_path'] as String?,
  );
}

/// S3配置
class S3Config {
  final String endpoint;
  final String region;
  final String accessKey;
  final String secretKey;
  final String bucket;
  final bool? useSSL;
  final int? port;

  const S3Config({
    required this.endpoint,
    required this.region,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    this.useSSL,
    this.port,
  });

  Map<String, dynamic> toMap({bool includeCredentials = false}) {
    final map = <String, dynamic>{
      'endpoint': endpoint,
      'region': region,
      'access_key': accessKey,
      'secret_key': includeCredentials ? secretKey : '***',
      'bucket': bucket,
    };
    if (useSSL != null) {
      map['use_ssl'] = useSSL;
    }
    if (port != null) {
      map['port'] = port;
    }
    return map;
  }

  static S3Config fromMap(Map<String, dynamic> map) => S3Config(
    endpoint: map['endpoint'] as String,
    region: map['region'] as String,
    accessKey: map['access_key'] as String,
    secretKey: map['secret_key'] as String,
    bucket: map['bucket'] as String,
    useSSL: map['use_ssl'] as bool?,
    port: map['port'] as int?,
  );
}

/// 应用设置配置
class AppSettingsConfig {
  // 记账提醒
  final bool? reminderEnabled;
  final int? reminderHour;
  final int? reminderMinute;

  // 语言设置
  final String? languageCode;
  final String? countryCode;

  // 个性化设置
  final int? fontScaleLevel;
  final double? customFontScale;

  // 外观设置
  final String? themeMode;

  // 云服务选择
  final String? cloudServiceType;
  final bool? autoSync; // 自动同步

  const AppSettingsConfig({
    this.reminderEnabled,
    this.reminderHour,
    this.reminderMinute,
    this.languageCode,
    this.countryCode,
    this.fontScaleLevel,
    this.customFontScale,
    this.themeMode,
    this.cloudServiceType,
    this.autoSync,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (reminderEnabled != null) {
      map[ReminderPrefs.enabled] = reminderEnabled;
    }
    if (reminderHour != null) {
      map[ReminderPrefs.hour] = reminderHour;
    }
    if (reminderMinute != null) {
      map[ReminderPrefs.minute] = reminderMinute;
    }
    if (languageCode != null && languageCode!.isNotEmpty) {
      map['language_code'] = languageCode;
    }
    if (countryCode != null && countryCode!.isNotEmpty) {
      map['country_code'] = countryCode;
    }
    if (fontScaleLevel != null) {
      map['font_scale_level'] = fontScaleLevel;
    }
    if (customFontScale != null) {
      map['custom_font_scale'] = customFontScale;
    }
    if (themeMode != null && themeMode!.isNotEmpty) {
      map['theme_mode'] = themeMode;
    }
    if (cloudServiceType != null && cloudServiceType!.isNotEmpty) {
      map['cloud_service_type'] = cloudServiceType;
    }
    if (autoSync != null) {
      map['auto_sync'] = autoSync;
    }
    return map;
  }

  static AppSettingsConfig fromMap(Map<String, dynamic> map) =>
      AppSettingsConfig(
        reminderEnabled: map[ReminderPrefs.enabled] as bool?,
        reminderHour: map[ReminderPrefs.hour] as int?,
        reminderMinute: map[ReminderPrefs.minute] as int?,
        languageCode: map['language_code'] as String?,
        countryCode: map['country_code'] as String?,
        fontScaleLevel: map['font_scale_level'] as int?,
        customFontScale: map['custom_font_scale'] != null
            ? (map['custom_font_scale'] as num).toDouble()
            : null,
        themeMode: map['theme_mode'] as String?,
        cloudServiceType: map['cloud_service_type'] as String?,
        autoSync: map['auto_sync'] as bool?,
      );
}

/// 账本配置
class LedgersConfig {
  final List<LedgerItem> items;

  const LedgersConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {'items': items.map((item) => item.toMap()).toList()};
  }

  static LedgersConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return LedgersConfig(
      items: itemsList
          .map(
            (item) =>
                LedgerItem.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

/// 账本项
class LedgerItem {
  final String name;
  final String currency;
  final String? type; // personal / shared
  final String? createdAt; // ISO 8601 format

  const LedgerItem({
    required this.name,
    required this.currency,
    this.type,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'name': name, 'currency': currency};
    if (type != null && type!.isNotEmpty) map['type'] = type;
    if (createdAt != null) map['created_at'] = createdAt;
    return map;
  }

  static LedgerItem fromMap(Map<String, dynamic> map) {
    return LedgerItem(
      name: map['name'] as String,
      currency: map['currency'] as String? ?? 'CNY',
      type: map['type'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  factory LedgerItem.fromDb(Ledger ledger) {
    return LedgerItem(
      name: ledger.name,
      currency: ledger.currency,
      type: ledger.type,
      createdAt: ledger.createdAt.toIso8601String(),
    );
  }
}

/// 周期账单配置
class RecurringTransactionsConfig {
  final List<RecurringTransactionItem> items;

  const RecurringTransactionsConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {'items': items.map((item) => item.toMap()).toList()};
  }

  static RecurringTransactionsConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return RecurringTransactionsConfig(
      items: itemsList
          .map(
            (item) => RecurringTransactionItem.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

/// 周期账单项
class RecurringTransactionItem {
  final String ledgerName; // 账本名称（用于导出/导入匹配）
  final String type; // 全局仅支出模式，固定为 'expense'
  final double amount;
  final String? categoryName; // 分类名称（用于导出/导入匹配）
  final String? note;
  final String frequency; // daily / weekly / monthly / yearly
  final int interval;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final int? monthOfYear;
  final String startDate; // ISO 8601 format
  final String? endDate;
  final bool enabled;

  const RecurringTransactionItem({
    required this.ledgerName,
    required this.type,
    required this.amount,
    this.categoryName,
    this.note,
    required this.frequency,
    required this.interval,
    this.dayOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    required this.startDate,
    this.endDate,
    required this.enabled,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'ledger_name': ledgerName,
      'type': type,
      'amount': amount,
      'frequency': frequency,
      'interval': interval,
      'start_date': startDate,
      'enabled': enabled,
    };
    if (categoryName != null) map['category_name'] = categoryName;
    if (note != null && note!.isNotEmpty) map['note'] = note;
    if (dayOfMonth != null) map['day_of_month'] = dayOfMonth;
    if (dayOfWeek != null) map['day_of_week'] = dayOfWeek;
    if (monthOfYear != null) map['month_of_year'] = monthOfYear;
    if (endDate != null) map['end_date'] = endDate;
    return map;
  }

  static RecurringTransactionItem fromMap(Map<String, dynamic> map) {
    return RecurringTransactionItem(
      ledgerName: map['ledger_name'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryName: map['category_name'] as String?,
      note: map['note'] as String?,
      frequency: map['frequency'] as String,
      interval: map['interval'] as int,
      dayOfMonth: map['day_of_month'] as int?,
      dayOfWeek: map['day_of_week'] as int?,
      monthOfYear: map['month_of_year'] as int?,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String?,
      enabled: map['enabled'] as bool,
    );
  }

  /// 从数据库实体创建，需要传入名称映射
  factory RecurringTransactionItem.fromDb(
    RecurringTransaction rt, {
    required Map<int, String> ledgerIdToName,
    required Map<int, String> categoryIdToName,
  }) {
    return RecurringTransactionItem(
      ledgerName: ledgerIdToName[rt.ledgerId] ?? 'Unknown',
      type: rt.type,
      // 数据库为整数分,配置文件沿用"元"口径。
      amount: rt.amount / 100,
      categoryName: rt.categoryId != null
          ? categoryIdToName[rt.categoryId]
          : null,
      note: rt.note,
      frequency: rt.frequency,
      interval: rt.interval,
      dayOfMonth: rt.dayOfMonth,
      dayOfWeek: rt.dayOfWeek,
      monthOfYear: rt.monthOfYear,
      startDate: rt.startDate.toIso8601String(),
      endDate: rt.endDate?.toIso8601String(),
      enabled: rt.enabled,
    );
  }
}

/// 分类配置
class CategoriesConfig {
  final List<CategoryItem> items;

  const CategoriesConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {'items': items.map((item) => item.toMap()).toList()};
  }

  static CategoriesConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return CategoriesConfig(
      items: itemsList
          .map(
            (item) =>
                CategoryItem.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

/// 分类项
class CategoryItem {
  final String name;
  final String kind; // 全局仅支出模式，固定为 'expense'
  final String? icon;
  final int sortOrder;
  final String? parentName; // 使用父分类名称而非ID
  final int level;
  final String? syncId; // 跨设备收敛用确定性标识

  const CategoryItem({
    required this.name,
    required this.kind,
    this.icon,
    required this.sortOrder,
    this.parentName,
    required this.level,
    this.syncId,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'kind': kind,
      'sort_order': sortOrder,
      'level': level,
    };
    if (icon != null) map['icon'] = icon;
    if (parentName != null) map['parent_name'] = parentName;
    if (syncId != null) map['sync_id'] = syncId;
    return map;
  }

  static CategoryItem fromMap(Map<String, dynamic> map) {
    return CategoryItem(
      name: map['name'] as String,
      kind: map['kind'] as String,
      icon: map['icon'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      parentName: map['parent_name'] as String?,
      level: map['level'] as int? ?? 1,
      syncId: map['sync_id'] as String?,
    );
  }

  factory CategoryItem.fromDb(Category category, String? parentName) {
    return CategoryItem(
      name: category.name,
      kind: category.kind,
      icon: category.icon,
      sortOrder: category.sortOrder,
      parentName: parentName,
      level: category.level,
      syncId: category.syncId,
    );
  }
}

/// 配置内容检测结果
class ConfigContentInfo {
  final bool hasLedgers;
  final bool hasCategories;
  final bool hasRecurringTransactions;
  final bool hasAppSettings; // 包含云服务配置、应用设置

  const ConfigContentInfo({
    this.hasLedgers = false,
    this.hasCategories = false,
    this.hasRecurringTransactions = false,
    this.hasAppSettings = false,
  });
}

/// 配置导入导出服务
class ConfigExportService {
  /// 检测 YAML 内容中包含哪些配置项
  static ConfigContentInfo detectContent(String yamlContent) {
    try {
      final doc = loadYaml(yamlContent);
      if (doc is! Map) {
        return const ConfigContentInfo();
      }

      return ConfigContentInfo(
        hasLedgers: doc.containsKey('ledgers'),
        hasCategories: doc.containsKey('categories'),
        hasRecurringTransactions: doc.containsKey('recurring_transactions'),
        hasAppSettings:
            doc.containsKey('supabase') ||
            doc.containsKey('webdav') ||
            doc.containsKey('s3') ||
            doc.containsKey('spitout_cloud') ||
            doc.containsKey('app_settings'),
      );
    } catch (_) {
      return const ConfigContentInfo();
    }
  }

  /// 将字符串输出为 YAML 双引号标量，并做标准转义。
  ///
  /// 手工拼接时必须经过这里：账本名/备注/密码可能包含引号、反斜杠、
  /// 换行等字符，直接插值会生成非法 YAML 或被篡改结构。
  static String _yamlQuote(Object? value) {
    final s = value?.toString() ?? '';
    final escaped = s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t')
        .replaceAll('\u0008', '\\b')
        .replaceAll('\u000C', '\\f');
    return '"$escaped"';
  }

  /// 分类配置缺失 syncId 时生成确定性 UUID。
  ///
  /// 同一份配置在两台设备导入后分类 syncId 一致，云端按 syncId 收敛，
  /// 避免同分类在云端重复出现。key 取「父级作用域 + kind + 名称小写」，
  /// 与导入去重契约（父级作用域内唯一）保持一致。
  static String _deterministicCategorySyncId(CategoryItem item) {
    final scope = item.parentName == null
        ? '${item.kind}|${item.name.toLowerCase()}'
        : '${item.kind}|${item.parentName!.toLowerCase()}|'
              '${item.name.toLowerCase()}';
    return const Uuid().v5(Namespace.url.value, 'spitout:category:$scope');
  }

  /// 导出配置到YAML字符串
  /// [repository] 数据仓库实例，用于导出周期账单等数据
  /// [options] 导出选项，控制导出哪些内容
  static Future<String> exportToYaml({
    LocalRepository? repository,
    ExportOptions options = ExportOptions.all,
    // 测试可注入明文存储；生产默认走安全存储（FlutterSecureCredentialStorage）。
    CloudServiceStore? store,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // 云配置统一经 CloudServiceStore 读取（含凭据合并与旧数据迁移），
    // 不直接触碰云配置键，避免与存储侧安全边界分叉。
    final cloudStore = store ?? CloudServiceStore();

    // 读取Supabase配置
    SupabaseConfig? supabaseConfig;
    final supabaseCfg = await cloudStore.loadSupabase();
    if (supabaseCfg != null &&
        supabaseCfg.supabaseUrl != null &&
        supabaseCfg.supabaseAnonKey != null) {
      supabaseConfig = SupabaseConfig(
        url: supabaseCfg.supabaseUrl!,
        anonKey: supabaseCfg.supabaseAnonKey!,
        bucket: supabaseCfg.supabaseBucket,
        account: supabaseCfg.supabaseAccount,
        password: supabaseCfg.supabasePassword,
      );
    }

    // 读取WebDAV配置
    WebdavConfig? webdavConfig;
    final webdavCfg = await cloudStore.loadWebdav();
    if (webdavCfg != null &&
        webdavCfg.webdavUrl != null &&
        webdavCfg.webdavUsername != null &&
        webdavCfg.webdavPassword != null) {
      webdavConfig = WebdavConfig(
        url: webdavCfg.webdavUrl!,
        username: webdavCfg.webdavUsername!,
        password: webdavCfg.webdavPassword!,
        remotePath: webdavCfg.webdavRemotePath,
      );
    }

    // 读取S3配置
    S3Config? s3Config;
    final s3Cfg = await cloudStore.loadS3();
    if (s3Cfg != null &&
        s3Cfg.s3Endpoint != null &&
        s3Cfg.s3Region != null &&
        s3Cfg.s3AccessKey != null &&
        s3Cfg.s3SecretKey != null &&
        s3Cfg.s3Bucket != null) {
      s3Config = S3Config(
        endpoint: s3Cfg.s3Endpoint!,
        region: s3Cfg.s3Region!,
        accessKey: s3Cfg.s3AccessKey!,
        secretKey: s3Cfg.s3SecretKey!,
        bucket: s3Cfg.s3Bucket!,
        useSSL: s3Cfg.s3UseSSL,
        port: s3Cfg.s3Port,
      );
    }

    // 读取 Spitout Cloud 配置。base_url + account 总是导出（方便 B 设备导入
    // 快速填回登录表单）；登录密码不落盘，因此导出时无明文可写；access/refresh
    // token 属于登录态，需 options 显式勾选才带上。
    SpitoutCloudConfig? spitoutCloudConfig;
    final spitoutCfg = await cloudStore.loadSpitoutCloud();
    final baseUrl = spitoutCfg?.spitoutCloudBaseUrl ?? '';
    if (baseUrl.isNotEmpty) {
      spitoutCloudConfig = SpitoutCloudConfig(
        baseUrl: baseUrl,
        account: spitoutCfg?.spitoutCloudAccount,
        // 密码不持久化（见 CloudServiceStore），此处恒为 null，yaml 不写。
        password: spitoutCfg?.spitoutCloudPassword,
      );
    }

    // 预先获取所有账本、分类的名称映射（用于关联数据导出）
    Map<int, String> ledgerIdToName = {};
    Map<int, String> categoryIdToName = {};

    if (repository != null) {
      try {
        final ledgers = await repository.getAllLedgers();
        ledgerIdToName = {for (var l in ledgers) l.id: l.name};

        final categories = await repository.getAllCategories();
        categoryIdToName = {for (var c in categories) c.id: c.name};
      } catch (e) {
        logger.warning('ConfigExport', '获取名称映射失败: $e');
      }
    }

    // 收集需要强制导出的关联数据ID
    final Set<int> requiredLedgerIds = {};
    final Set<int> requiredCategoryIds = {};

    // 读取应用设置
    AppSettingsConfig? appSettings;
    final reminderEnabled = prefs.getBool(ReminderPrefs.enabled);
    final reminderHour = prefs.getInt(ReminderPrefs.hour);
    final reminderMinute = prefs.getInt(ReminderPrefs.minute);
    final languageCode = prefs.getString('selected_language');
    final countryCode = prefs.getString('selected_language_country');
    final fontScaleLevel = prefs.getInt('fontScaleLevel');
    final customFontScale = prefs.getDouble('customFontScale');
    final themeMode = prefs.getString('themeMode');

    final cloudServiceType = prefs.getString('cloud_active_type');
    final autoSync = prefs.getBool('auto_sync');

    // 如果有任何应用设置，就创建配置对象
    if (reminderEnabled != null ||
        reminderHour != null ||
        reminderMinute != null ||
        languageCode != null ||
        countryCode != null ||
        fontScaleLevel != null ||
        customFontScale != null ||
        themeMode != null ||
        cloudServiceType != null ||
        autoSync != null) {
      appSettings = AppSettingsConfig(
        reminderEnabled: reminderEnabled,
        reminderHour: reminderHour,
        reminderMinute: reminderMinute,
        languageCode: languageCode,
        countryCode: countryCode,
        fontScaleLevel: fontScaleLevel,
        customFontScale: customFontScale,
        themeMode: themeMode,
        cloudServiceType: cloudServiceType,
        autoSync: autoSync,
      );
    }

    // 读取周期账单配置（导出全部账本的周期记账）
    RecurringTransactionsConfig? recurringConfig;
    if (options.recurringTransactions && repository != null) {
      try {
        final recurringList = await repository.getAllRecurringTransactions();

        if (recurringList.isNotEmpty) {
          // 收集周期账单关联的账本、分类ID
          for (final rt in recurringList) {
            requiredLedgerIds.add(rt.ledgerId);
            if (rt.categoryId != null) {
              requiredCategoryIds.add(rt.categoryId!);
            }
          }

          recurringConfig = RecurringTransactionsConfig(
            items: recurringList
                .map(
                  (rt) => RecurringTransactionItem.fromDb(
                    rt,
                    ledgerIdToName: ledgerIdToName,
                    categoryIdToName: categoryIdToName,
                  ),
                )
                .toList(),
          );
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取周期账单配置失败: $e');
      }
    }

    // 读取账本配置（导出全部账本，或强制导出关联的账本）
    LedgersConfig? ledgersConfig;
    if (repository != null &&
        (options.ledgers || requiredLedgerIds.isNotEmpty)) {
      try {
        final ledgersList = await repository.getAllLedgers();

        if (ledgersList.isNotEmpty) {
          // 如果用户选择了导出账本，则导出全部
          // 如果用户没有选择但有关联数据需要账本，则只导出关联的账本
          final itemsToExport = options.ledgers
              ? ledgersList
              : ledgersList
                    .where((l) => requiredLedgerIds.contains(l.id))
                    .toList();

          if (itemsToExport.isNotEmpty) {
            ledgersConfig = LedgersConfig(
              items: itemsToExport
                  .map((ledger) => LedgerItem.fromDb(ledger))
                  .toList(),
            );
          }
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取账本配置失败: $e');
      }
    }

    // 读取分类配置（导出全部分类，或强制导出关联的分类）
    CategoriesConfig? categoriesConfig;
    if (repository != null &&
        (options.categories || requiredCategoryIds.isNotEmpty)) {
      try {
        // 全局仅支出模式，只导出 expense 分类。
        final expenseCategories = await repository.getTopLevelCategories(
          'expense',
        );
        final categoriesList = <Category>[];
        categoriesList.addAll(expenseCategories);

        // 获取所有子分类
        for (final category in expenseCategories) {
          final subCategories = await repository.getSubCategories(category.id);
          categoriesList.addAll(subCategories);
        }

        if (categoriesList.isNotEmpty) {
          // 构建 ID 到分类的映射，用于查找父分类名称
          final categoryMap = <int, Category>{
            for (var cat in categoriesList) cat.id: cat,
          };

          // 如果用户选择了导出分类，则导出全部
          // 如果用户没有选择但有关联数据需要分类，则只导出关联的分类及其父分类
          List<Category> itemsToExport;
          if (options.categories) {
            itemsToExport = categoriesList;
          } else {
            // 收集需要导出的分类（包括父分类）
            final idsToExport = <int>{};
            for (final id in requiredCategoryIds) {
              if (categoryMap.containsKey(id)) {
                idsToExport.add(id);
                // 如果是子分类，也要导出父分类
                final parentId = categoryMap[id]!.parentId;
                if (parentId != null) {
                  idsToExport.add(parentId);
                }
              }
            }
            itemsToExport = categoriesList
                .where((c) => idsToExport.contains(c.id))
                .toList();
          }

          if (itemsToExport.isNotEmpty) {
            categoriesConfig = CategoriesConfig(
              items: itemsToExport.map((category) {
                // 查找父分类名称
                String? parentName;
                if (category.parentId != null &&
                    categoryMap.containsKey(category.parentId)) {
                  parentName = categoryMap[category.parentId]!.name;
                }
                return CategoryItem.fromDb(category, parentName);
              }).toList(),
            );
          }
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取分类配置失败: $e');
      }
    }

    // 根据选项过滤云服务配置
    final exportSupabase = options.appSettings ? supabaseConfig : null;
    final exportWebdav = options.appSettings ? webdavConfig : null;
    final exportS3 = options.appSettings ? s3Config : null;
    final exportSpitoutCloud = options.appSettings ? spitoutCloudConfig : null;
    final exportAppSettings = options.appSettings ? appSettings : null;

    final config = AppConfig(
      supabase: exportSupabase,
      webdav: exportWebdav,
      s3: exportS3,
      spitoutCloud: exportSpitoutCloud,
      appSettings: exportAppSettings,
      ledgers: ledgersConfig,
      recurringTransactions: recurringConfig,
      categories: categoriesConfig,
    );

    // 转换为YAML格式；凭据默认脱敏，仅显式勾选“包含凭据”时写入明文。
    final yamlMap = config.toYaml(
      includeCredentials: options.includeCredentials,
    );

    // 手动构建YAML字符串以保持良好格式
    final buffer = StringBuffer();
    buffer.writeln('# Spitout 应用配置');
    buffer.writeln('# 导出时间: ${DateTime.now().toIso8601String()}');
    if (options.includeCredentials) {
      buffer.writeln('# 警告：本文件包含密码/密钥，请勿分享或提交到版本库');
    }
    buffer.writeln();

    if (yamlMap.containsKey('supabase')) {
      buffer.writeln('supabase:');
      final sb = yamlMap['supabase'] as Map<String, dynamic>;
      buffer.writeln('  url: ${_yamlQuote(sb['url'])}');
      buffer.writeln('  anon_key: ${_yamlQuote(sb['anon_key'])}');
      if (sb.containsKey('bucket')) {
        buffer.writeln('  # Storage bucket 名称，留空则使用默认值 spitout-backups');
        buffer.writeln('  bucket: ${_yamlQuote(sb['bucket'])}');
      }
      if (sb.containsKey('account') || sb.containsKey('password')) {
        buffer.writeln('  # 记住账号密码功能：导入后登录页面会自动填充');
      }
      if (sb.containsKey('account')) {
        buffer.writeln('  account: ${_yamlQuote(sb['account'])}');
      }
      if (sb.containsKey('password')) {
        buffer.writeln('  password: ${_yamlQuote(sb['password'])}');
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('webdav')) {
      buffer.writeln('webdav:');
      final wd = yamlMap['webdav'] as Map<String, dynamic>;
      buffer.writeln('  url: ${_yamlQuote(wd['url'])}');
      buffer.writeln('  username: ${_yamlQuote(wd['username'])}');
      buffer.writeln('  password: ${_yamlQuote(wd['password'])}');
      if (wd.containsKey('remote_path')) {
        buffer.writeln('  remote_path: ${_yamlQuote(wd['remote_path'])}');
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('s3')) {
      buffer.writeln('s3:');
      final s3 = yamlMap['s3'] as Map<String, dynamic>;
      buffer.writeln('  endpoint: ${_yamlQuote(s3['endpoint'])}');
      buffer.writeln('  region: ${_yamlQuote(s3['region'])}');
      buffer.writeln('  access_key: ${_yamlQuote(s3['access_key'])}');
      buffer.writeln('  secret_key: ${_yamlQuote(s3['secret_key'])}');
      buffer.writeln('  bucket: ${_yamlQuote(s3['bucket'])}');
      if (s3.containsKey('use_ssl')) {
        buffer.writeln('  use_ssl: ${s3['use_ssl']}');
      }
      if (s3.containsKey('port')) {
        buffer.writeln('  port: ${s3['port']}');
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('spitout_cloud')) {
      buffer.writeln('spitout_cloud:');
      final bc = yamlMap['spitout_cloud'] as Map<String, dynamic>;
      buffer.writeln('  # Spitout Cloud 自部署后端配置');
      buffer.writeln('  base_url: ${_yamlQuote(bc['base_url'])}');
      if (bc.containsKey('account') || bc.containsKey('password')) {
        buffer.writeln('  # 记住账号密码功能：导入后登录页面会自动填充');
      }
      if (bc.containsKey('account')) {
        buffer.writeln('  account: ${_yamlQuote(bc['account'])}');
      }
      if (bc.containsKey('password')) {
        buffer.writeln('  password: ${_yamlQuote(bc['password'])}');
      }
      if (bc.containsKey('access_token')) {
        buffer.writeln('  access_token: ${_yamlQuote(bc['access_token'])}');
      }
      if (bc.containsKey('refresh_token')) {
        buffer.writeln('  refresh_token: ${_yamlQuote(bc['refresh_token'])}');
      }
      if (bc.containsKey('device_id')) {
        buffer.writeln('  device_id: ${_yamlQuote(bc['device_id'])}');
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('app_settings')) {
      buffer.writeln('app_settings:');
      final settings = yamlMap['app_settings'] as Map<String, dynamic>;

      if (settings.containsKey(ReminderPrefs.enabled) ||
          settings.containsKey(ReminderPrefs.hour) ||
          settings.containsKey(ReminderPrefs.minute)) {
        buffer.writeln('  # 记账提醒');
        if (settings.containsKey(ReminderPrefs.enabled)) {
          buffer.writeln(
            '  ${ReminderPrefs.enabled}: ${settings[ReminderPrefs.enabled]}',
          );
        }
        if (settings.containsKey(ReminderPrefs.hour)) {
          buffer.writeln(
            '  ${ReminderPrefs.hour}: ${settings[ReminderPrefs.hour]}',
          );
        }
        if (settings.containsKey(ReminderPrefs.minute)) {
          buffer.writeln(
            '  ${ReminderPrefs.minute}: ${settings[ReminderPrefs.minute]}',
          );
        }
      }

      if (settings.containsKey('language_code') ||
          settings.containsKey('country_code')) {
        buffer.writeln('  # 语言设置');
        if (settings.containsKey('language_code')) {
          buffer.writeln(
            '  language_code: ${_yamlQuote(settings['language_code'])}',
          );
        }
        if (settings.containsKey('country_code')) {
          buffer.writeln(
            '  country_code: ${_yamlQuote(settings['country_code'])}',
          );
        }
      }

      if (settings.containsKey('font_scale_level') ||
          settings.containsKey('custom_font_scale')) {
        buffer.writeln('  # 个性化设置');
        if (settings.containsKey('font_scale_level')) {
          buffer.writeln('  font_scale_level: ${settings['font_scale_level']}');
        }
        if (settings.containsKey('custom_font_scale')) {
          buffer.writeln(
            '  custom_font_scale: ${settings['custom_font_scale']}',
          );
        }
      }

      if (settings.containsKey('theme_mode')) {
        buffer.writeln('  # 外观设置');
        buffer.writeln('  theme_mode: ${_yamlQuote(settings['theme_mode'])}');
      }

      if (settings.containsKey('cloud_service_type') ||
          settings.containsKey('auto_sync')) {
        buffer.writeln('  # 云服务');
        if (settings.containsKey('cloud_service_type')) {
          buffer.writeln(
            '  cloud_service_type: ${_yamlQuote(settings['cloud_service_type'])}',
          );
        }
        if (settings.containsKey('auto_sync')) {
          buffer.writeln('  auto_sync: ${settings['auto_sync']}');
        }
      }
    }

    // 账本
    if (yamlMap.containsKey('ledgers')) {
      buffer.writeln('# 账本');
      buffer.writeln('ledgers:');
      final ledgers = yamlMap['ledgers'] as Map<String, dynamic>;
      final items = ledgers['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln('    - name: ${_yamlQuote(itemMap['name'])}');
          buffer.writeln('      currency: ${_yamlQuote(itemMap['currency'])}');
          if (itemMap.containsKey('type') && itemMap['type'] != null) {
            buffer.writeln('      type: ${_yamlQuote(itemMap['type'])}');
          }
          if (itemMap.containsKey('created_at') &&
              itemMap['created_at'] != null) {
            buffer.writeln(
              '      created_at: ${_yamlQuote(itemMap['created_at'])}',
            );
          }
        }
      }
      buffer.writeln();
    }

    // 周期账单
    if (yamlMap.containsKey('recurring_transactions')) {
      buffer.writeln('# 周期账单');
      buffer.writeln('recurring_transactions:');
      final recurring =
          yamlMap['recurring_transactions'] as Map<String, dynamic>;
      final items = recurring['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln(
            '    - ledger_name: ${_yamlQuote(itemMap['ledger_name'])}',
          );
          buffer.writeln('      type: ${_yamlQuote(itemMap['type'])}');
          buffer.writeln('      amount: ${itemMap['amount']}');

          if (itemMap.containsKey('category_name') &&
              itemMap['category_name'] != null) {
            buffer.writeln(
              '      category_name: ${_yamlQuote(itemMap['category_name'])}',
            );
          }
          if (itemMap.containsKey('note') && itemMap['note'] != null) {
            buffer.writeln('      note: ${_yamlQuote(itemMap['note'])}');
          }

          buffer.writeln(
            '      frequency: ${_yamlQuote(itemMap['frequency'])}',
          );
          buffer.writeln('      interval: ${itemMap['interval']}');

          if (itemMap.containsKey('day_of_month')) {
            buffer.writeln('      day_of_month: ${itemMap['day_of_month']}');
          }
          if (itemMap.containsKey('day_of_week')) {
            buffer.writeln('      day_of_week: ${itemMap['day_of_week']}');
          }
          if (itemMap.containsKey('month_of_year')) {
            buffer.writeln('      month_of_year: ${itemMap['month_of_year']}');
          }

          buffer.writeln(
            '      start_date: ${_yamlQuote(itemMap['start_date'])}',
          );
          if (itemMap.containsKey('end_date') && itemMap['end_date'] != null) {
            buffer.writeln(
              '      end_date: ${_yamlQuote(itemMap['end_date'])}',
            );
          }
          buffer.writeln('      enabled: ${itemMap['enabled']}');
        }
      }
      buffer.writeln();
    }

    // 分类
    if (yamlMap.containsKey('categories')) {
      buffer.writeln('# 分类');
      buffer.writeln('categories:');
      final categories = yamlMap['categories'] as Map<String, dynamic>;
      final items = categories['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln('    - name: ${_yamlQuote(itemMap['name'])}');
          buffer.writeln('      kind: ${_yamlQuote(itemMap['kind'])}');
          if (itemMap.containsKey('sync_id') && itemMap['sync_id'] != null) {
            buffer.writeln('      sync_id: ${_yamlQuote(itemMap['sync_id'])}');
          }
          if (itemMap.containsKey('icon') && itemMap['icon'] != null) {
            buffer.writeln('      icon: ${_yamlQuote(itemMap['icon'])}');
          }
          buffer.writeln('      sort_order: ${itemMap['sort_order']}');
          if (itemMap.containsKey('parent_name') &&
              itemMap['parent_name'] != null) {
            buffer.writeln(
              '      parent_name: ${_yamlQuote(itemMap['parent_name'])}',
            );
          }
          buffer.writeln('      level: ${itemMap['level']}');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 从YAML字符串导入配置
  /// [yamlContent] YAML内容
  /// [repository] 数据仓库实例，用于导入周期账单等数据
  /// [ledgerId] 账本ID，用于导入周期账单到指定账本
  /// [options] 导入选项，控制导入哪些内容
  static Future<void> importFromYaml(
    String yamlContent, {
    LocalRepository? repository,
    int? ledgerId,
    ExportOptions options = ExportOptions.all,
    // 测试可注入明文存储；生产默认走安全存储（FlutterSecureCredentialStorage）。
    CloudServiceStore? store,
  }) async {
    final doc = loadYaml(yamlContent);

    if (doc is! Map) {
      throw const FormatException('无效的YAML格式');
    }

    final config = AppConfig.fromYaml(doc);
    final prefs = await SharedPreferences.getInstance();
    // 云配置统一经 CloudServiceStore 写入（内部完成剥离、凭据合并与迁移），
    // 业务层不直接 setString 云配置键，避免绕过安全边界。
    final cloudStore = store ?? CloudServiceStore();

    // 导入Supabase配置
    if (options.appSettings && config.supabase != null) {
      final supabaseCfg = CloudServiceConfig(
        type: CloudBackendType.supabase,
        name: 'Supabase',
        supabaseUrl: config.supabase!.url,
        supabaseAnonKey: config.supabase!.anonKey,
        supabaseBucket:
            config.supabase!.bucket ?? 'spitout-backups', // 导入时也提供默认值
        supabaseAccount: config.supabase!.account,
        // 登录密码与 CloudServiceStore 的落盘策略一致:永不清真存储,
        // 即使 YAML 显式携带密码,也由 Store 统一剥离,密码由用户在下一次登录时输入。
        supabasePassword: config.supabase!.password,
      );
      await cloudStore.saveImported(
        supabaseCfg,
        includeCredentials: options.includeCredentials,
      );
      logger.info('ConfigImport', 'Supabase配置已导入');
    }

    // 导入WebDAV配置
    if (options.appSettings && config.webdav != null) {
      final webdavCfg = CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: 'WebDAV',
        webdavUrl: config.webdav!.url,
        webdavUsername: config.webdav!.username,
        webdavPassword: config.webdav!.password,
        webdavRemotePath: config.webdav!.remotePath,
      );
      await cloudStore.saveImported(
        webdavCfg,
        includeCredentials: options.includeCredentials,
      );
      logger.info('ConfigImport', 'WebDAV配置已导入');
    }

    // 导入S3配置
    if (options.appSettings && config.s3 != null) {
      final s3Cfg = CloudServiceConfig(
        type: CloudBackendType.s3,
        name: 'S3',
        s3Endpoint: config.s3!.endpoint,
        s3Region: config.s3!.region,
        s3AccessKey: config.s3!.accessKey,
        s3SecretKey: config.s3!.secretKey,
        s3Bucket: config.s3!.bucket,
        s3UseSSL: config.s3!.useSSL,
        s3Port: config.s3!.port,
      );
      await cloudStore.saveImported(
        s3Cfg,
        includeCredentials: options.includeCredentials,
      );
      logger.info('ConfigImport', 'S3配置已导入');
    }

    // 导入 Spitout Cloud 配置（base_url + 可选 account）。
    // 登录密码不落盘（与 CloudServiceStore 一致）:导入后登录页预填账号,
    // 密码由用户输入;自动登录依赖 session token,不依赖明文密码。
    if (options.appSettings && config.spitoutCloud != null) {
      final bcCfg = CloudServiceConfig(
        type: CloudBackendType.spitoutCloud,
        name: 'Spitout Cloud',
        spitoutCloudBaseUrl: config.spitoutCloud!.baseUrl,
        spitoutCloudAccount: config.spitoutCloud!.account,
        // 登录密码同样交给 Store 统一剥离，绝不落盘。
        spitoutCloudPassword: config.spitoutCloud!.password,
      );
      await cloudStore.saveImported(
        bcCfg,
        includeCredentials: options.includeCredentials,
      );
      logger.info(
        'ConfigImport',
        'Spitout Cloud 配置已导入 url=${config.spitoutCloud!.baseUrl} '
            'hasAccount=${config.spitoutCloud!.account != null} '
            'password=skipped',
      );
    }

    // 导入应用设置
    if (options.appSettings && config.appSettings != null) {
      final settings = config.appSettings!;

      // 记账提醒
      if (settings.reminderEnabled != null) {
        await prefs.setBool(ReminderPrefs.enabled, settings.reminderEnabled!);
      }
      if (settings.reminderHour != null) {
        await prefs.setInt(ReminderPrefs.hour, settings.reminderHour!);
      }
      if (settings.reminderMinute != null) {
        await prefs.setInt(ReminderPrefs.minute, settings.reminderMinute!);
      }

      // 语言设置
      if (settings.languageCode != null) {
        await prefs.setString('selected_language', settings.languageCode!);
      }
      if (settings.countryCode != null) {
        await prefs.setString(
          'selected_language_country',
          settings.countryCode!,
        );
      }

      // 个性化设置
      if (settings.fontScaleLevel != null) {
        await prefs.setInt('fontScaleLevel', settings.fontScaleLevel!);
      }
      if (settings.customFontScale != null) {
        await prefs.setDouble('customFontScale', settings.customFontScale!);
      }

      // 外观设置
      if (settings.themeMode != null) {
        await prefs.setString('themeMode', settings.themeMode!);
      }
      // 云服务
      if (settings.cloudServiceType != null) {
        final matches = CloudBackendType.values.where(
          (e) => e.name == settings.cloudServiceType,
        );
        if (matches.isEmpty) {
          logger.warning(
            'ConfigImport',
            '未知的云服务类型: ${settings.cloudServiceType}',
          );
        } else {
          // 激活走 Store 校验：配置缺失或不完整时不激活，避免僵尸激活标记。
          final ok = await cloudStore.activate(matches.first);
          if (!ok) {
            logger.warning(
              'ConfigImport',
              '导入后激活 ${matches.first.name} 失败:配置缺失或不完整',
            );
          }
        }
      }
      if (settings.autoSync != null) {
        await prefs.setBool('auto_sync', settings.autoSync!);
      }

      logger.info('ConfigImport', '应用设置已导入（默认账户待处理）');
    }

    // === 按依赖顺序导入数据 ===
    // 1. 导入账本（周期账单、预算依赖账本）
    if (options.ledgers && config.ledgers != null && repository != null) {
      try {
        final items = config.ledgers!.items;

        // 获取现有账本名称集合
        final existingLedgers = await repository.getAllLedgers();
        final existingNames = existingLedgers
            .map((l) => l.name.toLowerCase())
            .toSet();

        // 过滤掉已存在的账本（按名称去重）
        final newItems = items
            .where((item) => !existingNames.contains(item.name.toLowerCase()))
            .toList();

        if (newItems.isNotEmpty) {
          for (final item in newItems) {
            // 归属模型：配置导入统一建为本地账本。
            // 导入的是一份「配置文件」，用户并没有表达"把这些账本上云"的意愿；
            // 若默认建成云端账本，未登录时会出现同步不了的僵尸账本，已登录时
            // 则等于静默上传。需要上云由用户在账本管理页显式移动（opt-in）。
            await repository.createLedger(
              name: item.name,
              currency: item.currency,
              storageMode: 'local',
            );
          }
          logger.info(
            'ConfigImport',
            '账本已导入: ${newItems.length}条 (跳过已存在: ${items.length - newItems.length}条)',
          );
        } else {
          logger.info('ConfigImport', '账本全部已存在，跳过导入');
        }
      } catch (e) {
        logger.error('ConfigImport', '导入账本失败: $e');
      }
    }

    // 2. 导入分类（周期账单、预算依赖分类）
    if (options.categories && config.categories != null && repository != null) {
      try {
        final items = config.categories!.items;

        final existingCategories = await repository.getAllCategories();

        // 唯一契约为「父级作用域内唯一」：一级分类按 (name, kind) 在根作用域
        // 内唯一；二级分类按 (parentName, name, kind) 在父作用域内唯一。
        // 因此去重必须按层级分别比对，否则会把「购物>服装」误当作一级「服装」
        // 已存在而跳过，或把「服装>鞋子」当作「购物>鞋子」已存在而误杀。
        //
        // 一级去重集合：只跟现有 parentId == null 的行比。
        final existingLevel1Keys = existingCategories
            .where((c) => c.parentId == null)
            .map((c) => '${c.name.toLowerCase()}|${c.kind}')
            .toSet();

        // 第一步：过滤并批量插入一级分类（仅与根作用域已有行去重）
        final level1Items = items
            .where((item) => item.parentName == null)
            .toList();
        final newLevel1Items = level1Items
            .where(
              (item) => !existingLevel1Keys.contains(
                '${item.name.toLowerCase()}|${item.kind}',
              ),
            )
            .toList();

        if (newLevel1Items.isNotEmpty) {
          final level1Companions = newLevel1Items
              .map(
                (item) => CategoriesCompanion.insert(
                  name: item.name,
                  kind: item.kind,
                  icon: d.Value(item.icon),
                  sortOrder: d.Value(item.sortOrder),
                  parentId: const d.Value(null),
                  level: d.Value(item.level),
                  syncId: d.Value(
                    item.syncId ?? _deterministicCategorySyncId(item),
                  ),
                ),
              )
              .toList();

          await repository.batchInsertCategories(level1Companions);
        }

        // 第二步：查询所有分类，构建「一级分类名称 → ID」映射。
        // 关键：只装一级（parentId == null），否则二级「购物>服装」会覆盖一级
        // 「服装」的条目，导致后续按 parentName 查父 id 时拿到二级行的 id，
        // 把导入的子分类挂到二级分类下面，树结构直接错乱。
        final allCategories = await repository.getAllCategories();
        final keyToId = <String, int>{
          for (var cat in allCategories)
            if (cat.parentId == null)
              '${cat.name.toLowerCase()}|${cat.kind}': cat.id,
        };

        // 二级已有 key 集合（含刚插入的一级下的二级），按 (parentName, name, kind)。
        final updatedLevel2Keys = <String>{};
        // 同时构建父 id 索引，便于按 parentName 反查父 id。
        // (keyToId 已经只装一级，可直接复用。)
        for (final c in allCategories) {
          if (c.parentId == null) continue;
          final parent = allCategories.firstWhere(
            (p) => p.id == c.parentId,
            orElse: () => c,
          );
          updatedLevel2Keys.add(
            '${parent.name.toLowerCase()}|${c.name.toLowerCase()}|${c.kind}',
          );
        }

        // 第三步：过滤并批量插入二级分类，去重 key 为 (parentName, name, kind)
        final level2Items = items
            .where((item) => item.parentName != null)
            .toList();
        final newLevel2Items = level2Items
            .where(
              (item) => !updatedLevel2Keys.contains(
                '${item.parentName!.toLowerCase()}|${item.name.toLowerCase()}|${item.kind}',
              ),
            )
            .toList();
        final level2Companions = <CategoriesCompanion>[];

        for (final item in newLevel2Items) {
          // 父分类与子分类同 kind,按 (parentName, kind) 在 keyToId(只装一级)中查父 id
          final parentId =
              keyToId['${item.parentName?.toLowerCase()}|${item.kind}'];
          if (parentId != null) {
            level2Companions.add(
              CategoriesCompanion.insert(
                name: item.name,
                kind: item.kind,
                icon: d.Value(item.icon),
                sortOrder: d.Value(item.sortOrder),
                parentId: d.Value(parentId),
                level: d.Value(item.level),
                syncId: d.Value(
                  item.syncId ?? _deterministicCategorySyncId(item),
                ),
              ),
            );
          } else {
            logger.warning(
              'ConfigImport',
              '找不到父分类 "${item.parentName}"，跳过二级分类: ${item.name}',
            );
          }
        }

        if (level2Companions.isNotEmpty) {
          await repository.batchInsertCategories(level2Companions);
        }

        final skippedCount =
            (level1Items.length - newLevel1Items.length) +
            (level2Items.length - newLevel2Items.length);
        logger.info(
          'ConfigImport',
          '分类已批量导入: 一级${newLevel1Items.length}条, 二级${level2Companions.length}条'
              '${skippedCount > 0 ? ' (跳过已存在: $skippedCount条)' : ''}',
        );
      } catch (e) {
        logger.error('ConfigImport', '导入分类失败: $e');
      }
    }

    // 3. 导入周期账单（依赖账本、分类）
    if (options.recurringTransactions &&
        config.recurringTransactions != null &&
        repository != null) {
      try {
        final items = config.recurringTransactions!.items;

        // 构建名称到ID的映射
        final ledgers = await repository.getAllLedgers();
        final ledgerNameToId = {for (var l in ledgers) l.name: l.id};

        final categories = await repository.getAllCategories();
        // 按 (name, kind) 映射,跨 kind 同名各自命中
        final catKeyToId = {
          for (var c in categories) '${c.name.toLowerCase()}|${c.kind}': c.id,
        };

        int importedCount = 0;
        int skippedCount = 0;

        for (final item in items) {
          // 通过名称查找账本ID
          final targetLedgerId = ledgerNameToId[item.ledgerName];
          if (targetLedgerId == null) {
            logger.warning('ConfigImport', '找不到账本: ${item.ledgerName}，跳过周期账单');
            skippedCount++;
            continue;
          }

          // 通过名称查找分类ID
          int? categoryId;
          if (item.categoryName != null) {
            // 周期账单 type 即分类 kind
            categoryId =
                catKeyToId['${item.categoryName!.toLowerCase()}|${item.type}'];
            if (categoryId == null) {
              logger.warning(
                'ConfigImport',
                '找不到分类: ${item.categoryName}，跳过周期账单',
              );
              skippedCount++;
              continue;
            }
          }

          await repository.addRecurringTransaction(
            ledgerId: targetLedgerId,
            type: item.type,
            // 配置文件为"元",落库前转整数分。
            amount: (item.amount * 100).round(),
            categoryId: categoryId,
            note: item.note,
            frequency: item.frequency,
            interval: item.interval,
            dayOfMonth: item.dayOfMonth,
            dayOfWeek: item.dayOfWeek,
            monthOfYear: item.monthOfYear,
            startDate: DateTime.parse(item.startDate),
            endDate: item.endDate != null
                ? DateTime.parse(item.endDate!)
                : null,
            enabled: item.enabled,
          );
          importedCount++;
        }

        logger.info(
          'ConfigImport',
          '周期账单已导入: $importedCount条${skippedCount > 0 ? '，跳过: $skippedCount条' : ''}',
        );
      } catch (e) {
        logger.error('ConfigImport', '导入周期账单失败: $e');
      }
    }
  }

  /// 导出配置到文件
  static Future<void> exportToFile(
    String filePath, {
    LocalRepository? repository,
    ExportOptions options = ExportOptions.all,
  }) async {
    final yamlContent = await exportToYaml(
      repository: repository,
      options: options,
    );
    final file = File(filePath);
    await file.writeAsString(yamlContent);
    logger.info('ConfigExport', '配置已导出到: $filePath');
  }

  /// 从文件导入配置
  static Future<void> importFromFile(
    String filePath, {
    LocalRepository? repository,
    int? ledgerId,
    ExportOptions options = ExportOptions.all,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final yamlContent = await file.readAsString();
    await importFromYaml(
      yamlContent,
      repository: repository,
      ledgerId: ledgerId,
      options: options,
    );
    logger.info('ConfigImport', '配置已从文件导入: $filePath');
  }
}
