// CloudServicePage 行为测试扩展：切换服务 / 配置保存并切换 / Spitout 登录 / 失败分支。
//
// 已有 cloud_service_page_test 覆盖可见性与弹窗形态；本文件驱动完整交互链路：
//   - 卡片切换（确认 → 登出旧服务 → store.activate → postFrame purge → toast）
//   - 切换取消 / 同类型跳过 / 激活失败（配置缺失 / 异常）
//   - Supabase / WebDAV / S3 配置保存「暂不切换」与「立即切换」
//   - Spitout Cloud 保存并登录成功 / 鉴权失败
//   - 保存失败统一错误弹窗
//   - 下拉刷新与本地备份页入口
// 依赖注入与 cloud_service_page_test 一致：store 走 SharedPreferences mock，
// auth/sync 用 Noop/LocalOnly，repository 用 mocktail 替身避免触库。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_service.dart'
    show LocalOnlySyncService, SyncService;
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/cloud/cloud_service_page.dart';
import 'package:spitout/pages/settings/local_backup_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/app_sheet.dart';

CloudServiceConfig _webdavActive() => const CloudServiceConfig(
  type: CloudBackendType.webdav,
  name: 'WebDAV',
  webdavUrl: 'https://dav.example.com',
  webdavUsername: 'u',
  webdavPassword: 'p',
);

CloudServiceConfig _supabaseActive() => const CloudServiceConfig(
  type: CloudBackendType.supabase,
  name: 'Supabase',
  supabaseUrl: 'https://xxx.supabase.co',
  supabaseAnonKey: 'anon-key',
);

CloudServiceConfig _s3Active() => const CloudServiceConfig(
  type: CloudBackendType.s3,
  name: 'S3',
  s3Endpoint: 's3.example.com',
  s3AccessKey: 'ak',
  s3SecretKey: 'sk',
  s3Bucket: 'bucket',
);

CloudServiceConfig _spitoutActive() => const CloudServiceConfig(
  type: CloudBackendType.spitoutCloud,
  name: 'Spitout Cloud',
  spitoutCloudBaseUrl: 'https://cloud.example.com',
);

CloudServiceConfig _localActive() => CloudServiceConfig.localStorage();

CloudServiceStore _testStore() =>
    CloudServiceStore(credentialStorage: SharedPreferencesCredentialStorage());

class _MockRepo extends Mock implements LocalRepository {}

class _SignInAuth extends CloudAuthService {
  final Object? error;
  int signInCalls = 0;
  int signOutCalls = 0;

  _SignInAuth({this.error});

  @override
  Stream<CloudUser?> get authStateChanges => Stream.value(null);

  @override
  Future<CloudUser?> get currentUser async => null;

  @override
  String? get currentUserId => null;

  @override
  Future<CloudUser> signInWithAccount({
    required String account,
    required String password,
  }) async {
    signInCalls++;
    final e = error;
    if (e != null) throw e;
    return const CloudUser(id: 'u1', account: 'me@x.com');
  }

  @override
  Future<CloudUser> signUpWithAccount({
    required String account,
    required String password,
  }) async => const CloudUser(id: 'u1', account: 'me@x.com');

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<void> sendPasswordResetAccount({required String account}) async {}

  @override
  Future<void> resendAccountVerification({required String account}) async {}
}

/// 挂载 CloudServicePage：store 用真实实现 + SharedPreferences mock，
/// auth/sync 用替身，repository 用 mocktail 以走通 purge / 登录迁移分支。
Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  required CloudServiceConfig active,
  CloudServiceConfig? webdav,
  CloudServiceConfig? supabase,
  CloudServiceConfig? s3,
  CloudServiceConfig? spitoutCloud,
  CloudAuthService? auth,
  SyncService? sync,
  CloudServiceStore? store,
  LocalRepository? repo,
  Future<void> Function(CloudServiceStore store)? seedStore,
  TargetPlatform platform = TargetPlatform.android,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final effectiveStore = store ?? _testStore();
  if (seedStore != null) {
    await seedStore(effectiveStore);
  }
  // 高视口保证 5 张服务卡片全部进入 ListView 构建树（懒加载下不足时底部卡片找不到）。
  tester.view.physicalSize = const Size(1000, 12000);
  tester.view.devicePixelRatio = 1.0;
  final mockRepo = repo ?? _MockRepo();
  if (repo == null) {
    when(() => mockRepo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => mockRepo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => mockRepo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
  }
  final container = ProviderContainer(
    overrides: [
        activeCloudConfigProvider.overrideWith((ref) async => active),
        webdavConfigProvider.overrideWith((ref) async => webdav),
        s3ConfigProvider.overrideWith((ref) async => s3),
        supabaseConfigProvider.overrideWith((ref) async => supabase),
        spitoutCloudConfigProvider.overrideWith((ref) async => spitoutCloud),
        cloudServiceStoreProvider.overrideWith(
          (ref) => effectiveStore,
        ),
        authServiceProvider.overrideWith(
          (ref) async => auth ?? NoopAuthService(),
        ),
        syncServiceProvider.overrideWith(
          (ref) => sync ?? LocalOnlySyncService(),
        ),
        autoSyncValueProvider.overrideWith((ref) async => false),
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
        spitoutCloudServerVersionProvider.overrideWith((ref) async => null),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
        repositoryProvider.overrideWithValue(mockRepo),
        ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CloudServicePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _flushLoggerTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('切换服务：确认后登出旧服务、激活新服务并弹 toast', (tester) async {
    final auth = _SignInAuth();
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    await _pumpPage(
      tester,
      active: _localActive(),
      webdav: _webdavActive(),
      auth: auth,
      repo: repo,
      seedStore: (s) => s.saveOnly(_webdavActive()),
    );

    await tester.tap(find.text('自定义 WebDAV'));
    await tester.pumpAndSettle();
    expect(find.text('切换云服务'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 激活成功 → 已切换 toast + purge 清理云端账本
    expect(find.text('已切换到WebDAV'), findsOneWidget);
    verify(() => repo.purgeAllCloudLedgers()).called(1);

    await tester.pump(const Duration(milliseconds: 1100));
    await _flushLoggerTimers(tester);
  });

  testWidgets('切换服务：取消确认则不激活', (tester) async {
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    await _pumpPage(
      tester,
      active: _localActive(),
      webdav: _webdavActive(),
      repo: repo,
      seedStore: (s) => s.saveOnly(_webdavActive()),
    );

    await tester.tap(find.text('自定义 WebDAV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.purgeAllCloudLedgers());
  });

  testWidgets('切换服务：目标已是当前类型则跳过确认', (tester) async {
    await _pumpPage(
      tester,
      active: _webdavActive(),
      webdav: _webdavActive(),
    );

    await tester.tap(find.text('自定义 WebDAV'));
    await tester.pumpAndSettle();

    expect(find.text('切换云服务'), findsNothing);
  });

  testWidgets('激活失败（store.activate 返回 false）：提示配置缺失', (tester) async {
    // 卡片已配置但 store 中无对应配置 → activate 找不到目标配置
    await _pumpPage(
      tester,
      active: _localActive(),
      webdav: _webdavActive(),
      store: _FailingActivateStore(),
    );

    await tester.tap(find.text('自定义 WebDAV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('切换失败'), findsOneWidget);
    expect(find.text('请先配置该云服务'), findsOneWidget);

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await _flushLoggerTimers(tester);
  });

  testWidgets('激活异常：弹出统一失败文案', (tester) async {
    final auth = _SignInAuth();
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    await _pumpPage(
      tester,
      active: _localActive(),
      webdav: _webdavActive(),
      auth: auth,
      repo: repo,
      store: _ThrowingStore(),
    );

    await tester.tap(find.text('自定义 WebDAV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('切换失败'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await _flushLoggerTimers(tester);
  });

  testWidgets('下拉刷新：local 模式仅刷新配置', (tester) async {
    final container = await _pumpPage(
      tester,
      active: _localActive(),
      platform: TargetPlatform.iOS,
    );
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pump();

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(container.read(activeCloudConfigProvider).hasValue, isTrue);
  });

  testWidgets('下拉刷新：WebDAV 模式清状态缓存并重取同步状态', (tester) async {
    final sync = _CountingSyncService();
    final container = await _pumpPage(
      tester,
      active: _webdavActive(),
      webdav: _webdavActive(),
      sync: sync,
      platform: TargetPlatform.iOS,
    );
    final before = container.read(syncStatusRefreshProvider);

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pump();

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(container.read(syncStatusRefreshProvider), greaterThan(before));
    expect(sync.clearStatusCacheCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('本地备份页入口：点击本地存储卡片的配置按钮跳转', (tester) async {
    await _pumpPage(tester, active: _localActive());

    await tester.tap(find.text('配置').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LocalBackupPage), findsOneWidget);
  });

  testWidgets('Supabase 配置：保存后「暂不切换」只持久化不激活', (tester) async {
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    await _pumpPage(
      tester,
      active: _localActive(),
      repo: repo,
    );

    await tester.tap(find.text('自定义 Supabase'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://supabase.example.com',
    );
    await tester.enterText(find.byType(TextField).at(1), 'anon-key');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('配置已保存'), findsOneWidget);
    await tester.tap(find.text('暂不切换'));
    await tester.pumpAndSettle();

    // 未激活 → 不 purge
    verifyNever(() => repo.purgeAllCloudLedgers());
    // 配置已持久化
    final store = _testStore();
    final saved = await store.loadSupabase();
    expect(saved?.supabaseUrl, 'https://supabase.example.com');
  });

  testWidgets('WebDAV 配置：保存并切换 → 激活 + purge', (tester) async {
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    await _pumpPage(
      tester,
      active: _localActive(),
      repo: repo,
    );

    await tester.tap(find.text('自定义 WebDAV'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://dav.example.com',
    );
    await tester.enterText(find.byType(TextField).at(1), 'user');
    await tester.enterText(find.byType(TextField).at(2), 'pass');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即切换'));
    await tester.pumpAndSettle();

    expect(find.text('已切换到WebDAV'), findsOneWidget);
    verify(() => repo.purgeAllCloudLedgers()).called(1);

    await tester.pump(const Duration(milliseconds: 1100));
    await _flushLoggerTimers(tester);
  });

  testWidgets('S3 配置：保存并切换 → 激活', (tester) async {
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    await _pumpPage(
      tester,
      active: _localActive(),
      repo: repo,
    );

    await tester.tap(find.text('S3 协议存储'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://s3.example.com',
    );
    await tester.enterText(find.byType(TextField).at(2), 'ak');
    await tester.enterText(find.byType(TextField).at(3), 'sk');
    await tester.enterText(find.byType(TextField).at(4), 'bucket');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即切换'));
    await tester.pumpAndSettle();

    expect(find.text('已切换到S3'), findsOneWidget);
    verify(() => repo.purgeAllCloudLedgers()).called(1);

    await tester.pump(const Duration(milliseconds: 1100));
    await _flushLoggerTimers(tester);
  });

  testWidgets('Spitout Cloud 配置：保存并登录成功 → 登录成功 toast', (tester) async {
    final auth = _SignInAuth();
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    when(() => repo.countUnconvertedForeignTx(any())).thenAnswer((_) async => 0);
    when(() => repo.getAllLedgerStats()).thenAnswer((_) async => {});
    await _pumpPage(
      tester,
      active: _localActive(),
      auth: auth,
      repo: repo,
      extraOverrides: [
        cloudServicesFactoryProvider.overrideWith(
          (ref) => (cfg) async => (provider: null, auth: auth),
        ),
        localSelfIdProvider.overrideWith((ref) async => 'local-uuid'),
      ],
    );

    await tester.tap(find.text('Spitout Cloud'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://cloud.example.com',
    );
    await tester.enterText(find.byType(TextField).at(1), 'me@x.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即切换'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(auth.signInCalls, 1);
    // 登录成功后激活服务，最终 toast 为「已切换到Spitout Cloud」（登录 toast 被其替换）
    expect(find.text('已切换到Spitout Cloud'), findsOneWidget);

    // 等待 postFrame 迁移完成，再冲刷 toast 定时器
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1100));
    await _flushLoggerTimers(tester);
  });

  testWidgets('Spitout Cloud 配置：鉴权失败弹登录失败且不激活', (tester) async {
    final auth = _SignInAuth(error: CloudAuthException('Invalid login credentials'));
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
    await _pumpPage(
      tester,
      active: _localActive(),
      auth: auth,
      repo: repo,
      extraOverrides: [
        cloudServicesFactoryProvider.overrideWith(
          (ref) => (cfg) async => (provider: null, auth: auth),
        ),
      ],
    );

    await tester.tap(find.text('Spitout Cloud'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://cloud.example.com',
    );
    await tester.enterText(find.byType(TextField).at(1), 'me@x.com');
    await tester.enterText(find.byType(TextField).at(2), 'wrong');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即切换'));
    await tester.pumpAndSettle();

    expect(find.text('登录失败'), findsOneWidget);
    verifyNever(() => repo.purgeAllCloudLedgers());

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await _flushLoggerTimers(tester);
  });

  testWidgets('配置保存失败：弹出统一失败文案', (tester) async {
    await _pumpPage(
      tester,
      active: _localActive(),
      store: _ThrowingStore(),
    );

    await tester.tap(find.text('自定义 Supabase'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://supabase.example.com',
    );
    await tester.enterText(find.byType(TextField).at(1), 'anon-key');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('保存失败'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await _flushLoggerTimers(tester);
  });

  testWidgets('Spitout 配置保存失败：弹出统一失败文案', (tester) async {
    await _pumpPage(
      tester,
      active: _localActive(),
      store: _ThrowingStore(),
    );

    await tester.tap(find.text('Spitout Cloud'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://cloud.example.com',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('保存失败'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await _flushLoggerTimers(tester);
  });

  testWidgets('WebDAV 配置保存失败：弹出统一失败文案', (tester) async {
    await _pumpPage(
      tester,
      active: _localActive(),
      store: _ThrowingStore(),
    );

    await tester.tap(find.text('自定义 WebDAV'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://dav.example.com',
    );
    await tester.enterText(find.byType(TextField).at(1), 'user');
    await tester.enterText(find.byType(TextField).at(2), 'pass');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('保存失败'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await _flushLoggerTimers(tester);
  });

  testWidgets('已有配置对话框：预填字段，删除图标走二次确认并清配置', (tester) async {
    // 逐个验证 Spitout / Supabase / S3：已配置时打开对话框应预填旧值且可删除。
    final cases = <(String, CloudServiceConfig)>[
      ('Spitout Cloud', _spitoutActive()),
      ('自定义 Supabase', _supabaseActive()),
      ('S3 协议存储', _s3Active()),
    ];

    for (final (title, cfg) in cases) {
      final repo = _MockRepo();
      when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
      when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
      when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
      await _pumpPage(
        tester,
        active: _localActive(),
        spitoutCloud: cfg.type == CloudBackendType.spitoutCloud ? cfg : null,
        supabase: cfg.type == CloudBackendType.supabase ? cfg : null,
        s3: cfg.type == CloudBackendType.s3 ? cfg : null,
        repo: repo,
        seedStore: (s) => s.saveOnly(cfg),
      );

      // 本地存储卡片常驻「配置」按钮(index 0)，目标服务是唯一已配置卡片(index 1)。
      await tester.tap(find.text('配置').at(1));
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.delete), findsOneWidget);
      final firstField = tester.widget<TextField>(find.byType(TextField).first);
      expect(firstField.controller?.text, isNotEmpty);

      await tester.tap(find.byIcon(AppIcons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSheet), findsNothing);
      expect(find.text(title), findsOneWidget);

      // 冲刷删除成功的 toast 定时器与日志 debounce，避免循环残留 pending timer。
      await tester.pump(const Duration(milliseconds: 1100));
      await _flushLoggerTimers(tester);
    }
  });
}

/// store.activate 恒返回 false 的替身。
class _FailingActivateStore extends CloudServiceStore {
  _FailingActivateStore()
      : super(credentialStorage: SharedPreferencesCredentialStorage());

  @override
  Future<bool> activate(CloudBackendType type) async => false;
}

/// 所有写操作抛异常的替身。
class _ThrowingStore extends CloudServiceStore {
  _ThrowingStore()
      : super(credentialStorage: SharedPreferencesCredentialStorage());

  @override
  Future<void> saveOnly(CloudServiceConfig config) async {
    throw Exception('store boom');
  }

  @override
  Future<bool> activate(CloudBackendType type) async {
    throw Exception('activate boom');
  }
}

/// 记录 clearStatusCache 调用次数的 SyncService 替身。
class _CountingSyncService extends LocalOnlySyncService {
  int clearStatusCacheCalls = 0;

  @override
  void clearStatusCache({int? ledgerId}) {
    clearStatusCacheCalls++;
  }
}
