// ConfigExportService 扩展测试。
//
// 锚点：
//   - 配置模型 toMap/fromMap 往返不失真，凭据默认脱敏为 ***；
//   - 导出：按 options 过滤账本/分类/周期/应用设置/云配置，关联数据强制导出；
//   - 导入：按「父级作用域唯一」去重、跳过已存在、找不到父分类/账本时跳过
//     并记录；云配置经 CloudServiceStore.saveImported 统一写入；
//   - detectContent 正确识别配置项类型。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

import 'package:spitout/cloud/spitout_cloud.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/services/export/config_export_service.dart';
import 'package:spitout/services/notification/reminder_constants.dart';

class _MockRepo extends Mock implements LocalRepository {}

CloudServiceStore _testStore() =>
    CloudServiceStore(credentialStorage: SharedPreferencesCredentialStorage());

Category _cat(int id, String name, {int? parentId, int level = 1}) =>
    Category(
      id: id,
      name: name,
      kind: 'expense',
      icon: 'utensils',
      sortOrder: id,
      parentId: parentId,
      level: level,
      syncId: 'cat-$id',
    );

Ledger _ledger(int id, String name, {String currency = 'CNY'}) => Ledger(
      id: id,
      name: name,
      currency: currency,
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 1,
      isShared: false,
      monthStartDay: 1,
      storageMode: 'local',
      aaEnabled: false,
    );

RecurringTransaction _recurring(
  int id, {
  required int ledgerId,
  String currencyCode = 'CNY',
  int? categoryId,
  String? note,
  int? dayOfMonth,
  DateTime? endDate,
}) =>
    RecurringTransaction(
      id: id,
      ledgerId: ledgerId,
      type: 'expense',
      amount: 12345,
      currencyCode: currencyCode,
      categoryId: categoryId,
      note: note,
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: dayOfMonth,
      dayOfWeek: null,
      monthOfYear: null,
      startDate: DateTime(2026, 1, 15),
      endDate: endDate,
      lastGeneratedDate: null,
      enabled: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('配置模型往返', () {
    test('SupabaseConfig 凭据脱敏与 fromMap', () {
      const cfg = SupabaseConfig(
        url: 'https://a.supabase.co',
        anonKey: 'key',
        bucket: 'bk',
        account: 'a@b.c',
        password: 'secret',
      );
      expect(cfg.toMap()['password'], '***');
      expect(cfg.toMap(includeCredentials: true)['password'], 'secret');
      final restored = SupabaseConfig.fromMap(cfg.toMap());
      expect(restored.url, 'https://a.supabase.co');
      expect(restored.bucket, 'bk');
      expect(restored.password, '***');
    });

    test('SpitoutCloudConfig token/deviceId 与密码同级受凭据开关控制', () {
      const cfg = SpitoutCloudConfig(
        baseUrl: 'https://cloud.example.com',
        account: 'a@b.c',
        password: 'p',
        accessToken: 'at',
        refreshToken: 'rt',
        deviceId: 'dev',
      );
      final masked = cfg.toMap();
      expect(masked['access_token'], '***');
      expect(masked['refresh_token'], '***');
      expect(masked['device_id'], '***');
      final plain = cfg.toMap(includeCredentials: true);
      expect(plain['access_token'], 'at');
      expect(plain['device_id'], 'dev');
      final restored = SpitoutCloudConfig.fromMap(plain);
      expect(restored.accessToken, 'at');
      expect(restored.deviceId, 'dev');
    });

    test('WebdavConfig / S3Config 往返', () {
      const wd = WebdavConfig(
        url: 'https://dav',
        username: 'u',
        password: 'p',
        remotePath: '/r',
      );
      expect(wd.toMap()['password'], '***');
      expect(WebdavConfig.fromMap(wd.toMap(includeCredentials: true)).remotePath,
          '/r');

      const s3 = S3Config(
        endpoint: 'https://s3',
        region: 'us-east-1',
        accessKey: 'AK',
        secretKey: 'SK',
        bucket: 'bk',
        useSSL: true,
        port: 9000,
      );
      expect(s3.toMap()['secret_key'], '***');
      final s3Restored = S3Config.fromMap(s3.toMap(includeCredentials: true));
      expect(s3Restored.useSSL, isTrue);
      expect(s3Restored.port, 9000);
    });

    test('AppSettingsConfig 全字段往返', () {
      final cfg = AppSettingsConfig(
        reminderEnabled: true,
        reminderHour: 21,
        reminderMinute: 30,
        languageCode: 'zh',
        countryCode: 'CN',
        fontScaleLevel: 2,
        customFontScale: 1.25,
        themeMode: 'dark',
        cloudServiceType: 'webdav',
        autoSync: false,
      );
      final restored = AppSettingsConfig.fromMap(cfg.toMap());
      expect(restored.reminderEnabled, isTrue);
      expect(restored.reminderHour, 21);
      expect(restored.reminderMinute, 30);
      expect(restored.languageCode, 'zh');
      expect(restored.countryCode, 'CN');
      expect(restored.fontScaleLevel, 2);
      expect(restored.customFontScale, 1.25);
      expect(restored.themeMode, 'dark');
      expect(restored.cloudServiceType, 'webdav');
      expect(restored.autoSync, isFalse);
      // 空配置往返不抛错
      expect(AppSettingsConfig.fromMap(const {}).languageCode, isNull);
    });

    test('LedgerItem / LedgersConfig 往返与 fromDb', () {
      final fromDb = LedgerItem.fromDb(_ledger(1, '账本', currency: 'USD'));
      expect(fromDb.currency, 'USD');
      final restored = LedgerItem.fromMap(fromDb.toMap());
      expect(restored.name, '账本');
      expect(restored.type, 'personal');
      expect(restored.createdAt, isNotNull);

      final config = LedgersConfig(items: [fromDb]);
      final round = LedgersConfig.fromMap(config.toMap());
      expect(round.items.single.name, '账本');
      // 缺 currency 时默认 CNY
      expect(LedgerItem.fromMap(const {'name': 'x'}).currency, 'CNY');
    });

    test('RecurringTransactionItem 全字段往返与 fromDb', () {
      final fromDb = _recurring(
        1,
        ledgerId: 1,
        categoryId: 2,
        note: '房租',
        dayOfMonth: 15,
        endDate: DateTime(2027, 1, 1),
      );
      final item = RecurringTransactionItem.fromDb(
        fromDb,
        ledgerIdToName: const {1: '账本'},
        categoryIdToName: const {2: '住房'},
      );
      expect(item.ledgerName, '账本');
      expect(item.categoryName, '住房');
      expect(item.amount, 123.45);
      expect(item.currencyCode, 'CNY');
      expect(item.dayOfMonth, 15);
      expect(item.endDate, isNotNull);

      final restored = RecurringTransactionItem.fromMap(item.toMap());
      expect(restored.ledgerName, '账本');
      expect(restored.amount, 123.45);
      expect(restored.currencyCode, 'CNY');
      expect(restored.enabled, isTrue);

      // 未知账本名兜底
      final unknown = RecurringTransactionItem.fromDb(
        _recurring(2, ledgerId: 99),
        ledgerIdToName: const {},
        categoryIdToName: const {},
      );
      expect(unknown.ledgerName, 'Unknown');
      expect(unknown.categoryName, isNull);
    });

    test('CategoryItem 往返、fromDb 与父级映射', () {
      final child = _cat(2, '外卖', parentId: 1, level: 2);
      final item = CategoryItem.fromDb(child, '餐饮');
      expect(item.parentName, '餐饮');
      expect(item.level, 2);
      expect(item.syncId, 'cat-2');

      final restored = CategoryItem.fromMap(item.toMap());
      expect(restored.name, '外卖');
      expect(restored.parentName, '餐饮');
      // 缺省字段兜底
      final minimal = CategoryItem.fromMap(const {'name': 'x', 'kind': 'expense'});
      expect(minimal.sortOrder, 0);
      expect(minimal.level, 1);

      final config = CategoriesConfig(items: [item]);
      expect(CategoriesConfig.fromMap(config.toMap()).items.single.name, '外卖');
    });

    test('AppConfig.toYaml/fromYaml 全段往返', () {
      final config = AppConfig(
        supabase: const SupabaseConfig(
          url: 'https://a.supabase.co',
          anonKey: 'k',
          account: 'a@b.c',
          password: 'p',
        ),
        spitoutCloud: const SpitoutCloudConfig(
          baseUrl: 'https://cloud.example.com',
          account: 'a@b.c',
        ),
        webdav: const WebdavConfig(
          url: 'https://dav',
          username: 'u',
          password: 'p',
        ),
        s3: const S3Config(
          endpoint: 'https://s3',
          region: 'r',
          accessKey: 'AK',
          secretKey: 'SK',
          bucket: 'bk',
        ),
        appSettings: AppSettingsConfig(languageCode: 'zh', autoSync: true),
        ledgers: const LedgersConfig(items: []),
        recurringTransactions: const RecurringTransactionsConfig(items: []),
        categories: const CategoriesConfig(items: []),
      );
      final yaml = config.toYaml(includeCredentials: true);
      expect(yaml.keys, containsAll([
        'supabase', 'spitout_cloud', 'webdav', 's3', 'app_settings',
        'ledgers', 'recurring_transactions', 'categories',
      ]));
      final restored = AppConfig.fromYaml(
        Map<dynamic, dynamic>.from(yaml),
      );
      expect(restored.supabase?.url, 'https://a.supabase.co');
      expect(restored.spitoutCloud?.baseUrl, 'https://cloud.example.com');
      expect(restored.appSettings?.autoSync, isTrue);

      // 空配置
      final empty = AppConfig.fromYaml(const {});
      expect(empty.supabase, isNull);
      expect(AppConfig().toYaml(), isEmpty);
    });
  });

  group('detectContent', () {
    test('识别各段配置', () {
      final info = ConfigExportService.detectContent(
        'ledgers:\n  items: []\ncategories:\n  items: []\n'
        'recurring_transactions:\n  items: []\napp_settings: {}\n'
        'webdav:\n  url: x\n',
      );
      expect(info.hasLedgers, isTrue);
      expect(info.hasCategories, isTrue);
      expect(info.hasRecurringTransactions, isTrue);
      expect(info.hasAppSettings, isTrue);
    });

    test('非 Map / 非法 YAML → 全 false', () {
      expect(ConfigExportService.detectContent('- 1\n- 2').hasLedgers, isFalse);
      final broken = ConfigExportService.detectContent(':::bad yaml:::');
      expect(broken.hasLedgers, isFalse);
      expect(broken.hasCategories, isFalse);
    });

    test('仅云配置也算 appSettings', () {
      final info = ConfigExportService.detectContent('supabase:\n  url: x');
      expect(info.hasAppSettings, isTrue);
      expect(info.hasLedgers, isFalse);
    });
  });

  group('exportToYaml 全量数据', () {
    test('导出账本/分类/周期/应用设置与云配置', () async {
      final repo = _MockRepo();
      when(() => repo.getAllLedgers()).thenAnswer(
        (_) async => [_ledger(1, '账本'), _ledger(2, '美元账本', currency: 'USD')],
      );
      when(() => repo.getAllCategories()).thenAnswer(
        (_) async => [_cat(1, '餐饮'), _cat(2, '外卖', parentId: 1, level: 2)],
      );
      when(() => repo.getTopLevelCategories(any()))
          .thenAnswer((_) async => [_cat(1, '餐饮')]);
      when(() => repo.getSubCategories(any()))
          .thenAnswer((_) async => [_cat(2, '外卖', parentId: 1, level: 2)]);
      when(() => repo.getAllRecurringTransactions()).thenAnswer(
        (_) async => [_recurring(1, ledgerId: 1, categoryId: 2)],
      );
      SharedPreferences.setMockInitialValues({
        ReminderPrefs.enabled: true,
        ReminderPrefs.hour: 21,
        ReminderPrefs.minute: 30,
        'selected_language': 'zh',
        'selected_language_country': 'CN',
        'fontScaleLevel': 1,
        'customFontScale': 1.1,
        'themeMode': 'dark',
        'cloud_active_type': 'webdav',
        'auto_sync': true,
        'cloud_supabase_cfg': encodeCloudConfig(
          const CloudServiceConfig(
            type: CloudBackendType.supabase,
            name: 'Supabase',
            supabaseUrl: 'https://a.supabase.co',
            supabaseAnonKey: 'key',
            supabaseAccount: 'a@b.c',
          ),
        ),
        'cloud_webdav_cfg': encodeCloudConfig(
          const CloudServiceConfig(
            type: CloudBackendType.webdav,
            name: 'WebDAV',
            webdavUrl: 'https://dav',
            webdavUsername: 'u',
            webdavPassword: 'p',
          ),
        ),
        'cloud_spitout_cloud_cfg': encodeCloudConfig(
          const CloudServiceConfig(
            type: CloudBackendType.spitoutCloud,
            name: 'Spitout Cloud',
            spitoutCloudBaseUrl: 'https://cloud.example.com',
            spitoutCloudAccount: 'a@b.c',
          ),
        ),
      });

      final yaml = await ConfigExportService.exportToYaml(
        repository: repo,
        store: _testStore(),
      );
      final doc = loadYaml(yaml) as Map;
      expect(doc['supabase'], isNotNull);
      expect(doc['webdav'], isNotNull);
      expect(doc['spitout_cloud'], isNotNull);
      expect((doc['ledgers'] as Map)['items'], hasLength(2));
      expect((doc['categories'] as Map)['items'], hasLength(2));
      expect((doc['recurring_transactions'] as Map)['items'], hasLength(1));
      final settings = doc['app_settings'] as Map;
      expect(settings[ReminderPrefs.enabled], isTrue);
      expect(settings['language_code'], 'zh');
      expect(settings['theme_mode'], 'dark');
      expect(settings['cloud_service_type'], 'webdav');
      expect(settings['auto_sync'], isTrue);
    });

    test('options 关闭账本/分类时关联数据仍强制导出', () async {
      final repo = _MockRepo();
      when(() => repo.getAllLedgers()).thenAnswer(
        (_) async => [_ledger(1, '账本'), _ledger(2, '无关联')],
      );
      when(() => repo.getAllCategories()).thenAnswer(
        (_) async => [_cat(1, '餐饮'), _cat(2, '外卖', parentId: 1, level: 2)],
      );
      when(() => repo.getTopLevelCategories(any()))
          .thenAnswer((_) async => [_cat(1, '餐饮')]);
      when(() => repo.getSubCategories(any()))
          .thenAnswer((_) async => [_cat(2, '外卖', parentId: 1, level: 2)]);
      when(() => repo.getAllRecurringTransactions()).thenAnswer(
        (_) async => [_recurring(1, ledgerId: 1, categoryId: 2)],
      );

      final yaml = await ConfigExportService.exportToYaml(
        repository: repo,
        options: const ExportOptions(
          ledgers: false,
          categories: false,
          recurringTransactions: true,
          appSettings: false,
        ),
        store: _testStore(),
      );
      final doc = loadYaml(yaml) as Map;
      // 只导出有关联的账本 1 与关联分类（父+子）
      final ledgerItems = (doc['ledgers'] as Map)['items'] as List;
      expect(ledgerItems.single['name'], '账本');
      final catItems = (doc['categories'] as Map)['items'] as List;
      expect(catItems.map((e) => (e as Map)['name']), containsAll(['餐饮', '外卖']));
      expect(doc.containsKey('supabase'), isFalse);
    });

    test('仓库读名称映射抛错时导出不中断', () async {
      final repo = _MockRepo();
      when(() => repo.getAllLedgers()).thenThrow(Exception('boom'));
      final yaml = await ConfigExportService.exportToYaml(
        repository: repo,
        store: _testStore(),
      );
      expect(yaml, contains('# Spitout'));
    });
  });

  group('importFromYaml 全量数据', () {
    String fullYaml() => '''
supabase:
  url: "https://a.supabase.co"
  anon_key: "key"
  account: "a@b.c"
  password: "***"
webdav:
  url: "https://dav"
  username: "u"
  password: "***"
s3:
  endpoint: "https://s3"
  region: "r"
  access_key: "AK"
  secret_key: "SK"
  bucket: "bk"
  use_ssl: true
  port: 9000
spitout_cloud:
  base_url: "https://cloud.example.com"
  account: "a@b.c"
app_settings:
  reminder_enabled: true
  reminder_hour: 20
  reminder_minute: 15
  language_code: "zh"
  country_code: "CN"
  font_scale_level: 2
  custom_font_scale: 1.2
  theme_mode: "dark"
  cloud_service_type: "webdav"
  auto_sync: false
ledgers:
  items:
    - name: "新账本"
      currency: "USD"
    - name: "重复账本"
      currency: "USD"
categories:
  items:
    - name: "新一级"
      kind: "expense"
      sort_order: 1
      level: 1
    - name: "重复一级"
      kind: "expense"
      sort_order: 2
      level: 1
    - name: "新子"
      kind: "expense"
      parent_name: "新一级"
      sort_order: 1
      level: 2
    - name: "孤儿子"
      kind: "expense"
      parent_name: "不存在的父"
      sort_order: 1
      level: 2
recurring_transactions:
  items:
    - ledger_name: "重复账本"
      type: "expense"
      amount: 12.34
      category_name: "新一级"
      frequency: "monthly"
      interval: 1
      day_of_month: 15
      start_date: "2026-01-15T00:00:00.000"
      enabled: true
    - ledger_name: "不存在的账本"
      type: "expense"
      amount: 5.0
      frequency: "weekly"
      interval: 1
      start_date: "2026-01-15T00:00:00.000"
      enabled: true
''';

    test('导入云配置、应用设置、账本、分类与周期', () async {
      final repo = _MockRepo();
      // 有状态 mock：导入流程创建账本后 getAllLedgers 必须能看到它，
      // 周期账单才能按名称匹配到新建账本。
      final ledgers = <Ledger>[_ledger(1, '重复账本')];
      when(() => repo.getAllLedgers()).thenAnswer((_) async => List.of(ledgers));
      // 有状态分类集合：批量插入后第二步按 parentName 反查父分类。
      final categories = <Category>[_cat(1, '重复一级')];
      when(() => repo.getAllCategories())
          .thenAnswer((_) async => List.of(categories));
      when(
        () => repo.createLedger(
          name: any(named: 'name'),
          currency: any(named: 'currency'),
          storageMode: any(named: 'storageMode'),
        ),
      ).thenAnswer((inv) async {
        final name = inv.namedArguments[#name] as String;
        ledgers.add(_ledger(100 + ledgers.length, name));
        return ledgers.last.id;
      });
      when(
        () => repo.batchInsertCategories(any()),
      ).thenAnswer((inv) async {
        final list =
            inv.positionalArguments.first as List<CategoriesCompanion>;
        for (final c in list) {
          categories.add(
            Category(
              id: categories.length + 1,
              name: c.name.value,
              kind: c.kind.value,
              icon: c.icon.value,
              sortOrder: c.sortOrder.value,
              parentId: c.parentId.present ? c.parentId.value : null,
              level: c.level.value,
              syncId: c.syncId.value,
            ),
          );
        }
      });
      when(
        () => repo.addRecurringTransaction(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currencyCode: any(named: 'currencyCode'),
          categoryId: any(named: 'categoryId'),
          note: any(named: 'note'),
          frequency: any(named: 'frequency'),
          interval: any(named: 'interval'),
          dayOfMonth: any(named: 'dayOfMonth'),
          dayOfWeek: any(named: 'dayOfWeek'),
          monthOfYear: any(named: 'monthOfYear'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async => 1);

      final store = _testStore();
      await ConfigExportService.importFromYaml(
        fullYaml(),
        repository: repo,
        store: store,
      );

      // 云配置经 Store 写入（密码按脱敏规则被剥离开来）
      expect((await store.loadWebdav())?.webdavPassword, isNull);
      expect((await store.loadSupabase())?.supabaseUrl, 'https://a.supabase.co');
      expect((await store.loadS3())?.s3Port, 9000);
      expect(
        (await store.loadSpitoutCloud())?.spitoutCloudBaseUrl,
        'https://cloud.example.com',
      );
      // 脱敏导入（password=***）→ Store 剥离凭据，webdav 配置不完整，
      // 按契约不激活（loadActive 回落 local），但配置本身已保存。
      expect((await store.loadActive()).type, CloudBackendType.local);
      expect((await store.loadWebdav())?.webdavUsername, 'u');

      // 应用设置落盘
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ReminderPrefs.enabled), isTrue);
      expect(prefs.getInt(ReminderPrefs.hour), 20);
      expect(prefs.getString('selected_language'), 'zh');
      expect(prefs.getDouble('customFontScale'), 1.2);
      expect(prefs.getString('themeMode'), 'dark');
      expect(prefs.getBool('auto_sync'), isFalse);

      // 账本：跳过已存在，只建新账本
      verify(
        () => repo.createLedger(
          name: any(named: 'name'),
          currency: any(named: 'currency'),
          storageMode: any(named: 'storageMode'),
        ),
      ).called(1);
      verifyNever(
        () => repo.createLedger(
          name: '重复账本',
          currency: any(named: 'currency'),
          storageMode: any(named: 'storageMode'),
        ),
      );

      // 分类：一级跳过已存在、二级孤儿跳过；批量插入包含新一级+新子
      final insertedCompanions = verify(
        () => repo.batchInsertCategories(captureAny()),
      ).captured.cast<List<CategoriesCompanion>>().expand((e) => e).toList();
      expect(insertedCompanions.map((c) => c.name.value),
          containsAll(['新一级', '新子']));
      expect(insertedCompanions.map((c) => c.name.value),
          isNot(contains('孤儿子')));

      // 周期：导入成功 1 条、缺账本跳过 1 条
      verify(
        () => repo.addRecurringTransaction(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currencyCode: 'USD',
          categoryId: any(named: 'categoryId'),
          note: any(named: 'note'),
          frequency: any(named: 'frequency'),
          interval: any(named: 'interval'),
          dayOfMonth: any(named: 'dayOfMonth'),
          dayOfWeek: any(named: 'dayOfWeek'),
          monthOfYear: any(named: 'monthOfYear'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          enabled: any(named: 'enabled'),
        ),
      ).called(1);
    });

    test('非 Map YAML 抛 FormatException', () async {
      expect(
        () => ConfigExportService.importFromYaml('- 1\n- 2'),
        throwsFormatException,
      );
    });

    test('options.none 时不导入任何内容', () async {
      final repo = _MockRepo();
      when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
      when(() => repo.getAllCategories()).thenAnswer((_) async => <Category>[]);
      final store = _testStore();
      await ConfigExportService.importFromYaml(
        fullYaml(),
        repository: repo,
        options: ExportOptions.none,
        store: store,
      );
      verifyNever(
        () => repo.createLedger(
          name: any(named: 'name'),
          currency: any(named: 'currency'),
          storageMode: any(named: 'storageMode'),
        ),
      );
      verifyNever(() => repo.batchInsertCategories(any()));
      verifyNever(
        () => repo.addRecurringTransaction(
          ledgerId: any(named: 'ledgerId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currencyCode: any(named: 'currencyCode'),
          categoryId: any(named: 'categoryId'),
          note: any(named: 'note'),
          frequency: any(named: 'frequency'),
          interval: any(named: 'interval'),
          dayOfMonth: any(named: 'dayOfMonth'),
          dayOfWeek: any(named: 'dayOfWeek'),
          monthOfYear: any(named: 'monthOfYear'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          enabled: any(named: 'enabled'),
        ),
      );
      expect(await store.loadWebdav(), isNull);
    });
  });
}
