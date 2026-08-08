// 登录页（AuthPage）交互测试。
//
// 锚点：
//   - 密码只作为一次性输入、从不落盘；「记住账号」仅持久化账号，勾选状态由
//     账号是否存在推导；
//   - WebDAV 后端不需要登录页，直接展示「已配置」提示；
//   - 登录失败展示友好文案并允许重试；成功切到「我的」页并关闭登录页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/auth/login_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';

class _FakeAuth extends CloudAuthService {
  bool signInCalled = false;
  String? accountUsed;
  String? passwordUsed;
  Object? throwError;

  @override
  Stream<CloudUser?> get authStateChanges => Stream.value(null);

  @override
  Future<CloudUser?> get currentUser async => null;

  @override
  Future<CloudUser> signInWithAccount({
    required String account,
    required String password,
  }) async {
    signInCalled = true;
    accountUsed = account;
    passwordUsed = password;
    if (throwError != null) {
      throw throwError!;
    }
    return const CloudUser(id: 'uid-1', account: 'a@example.com');
  }

  @override
  Future<CloudUser> signUpWithAccount({
    required String account,
    required String password,
  }) async => const CloudUser(id: 'uid-1', account: 'a@example.com');

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetAccount({required String account}) async {}

  @override
  Future<void> resendAccountVerification({required String account}) async {}
}

CloudServiceConfig _spitoutConfig({String? account}) => CloudServiceConfig(
      type: CloudBackendType.spitoutCloud,
      name: 'Spitout Cloud',
      spitoutCloudBaseUrl: 'https://cloud.example.com',
      spitoutCloudApiPrefix: '/api/v1',
      spitoutCloudAccount: account,
      spitoutCloudPassword: null,
    );

CloudServiceConfig _supabaseConfig({String? account}) => CloudServiceConfig(
      type: CloudBackendType.supabase,
      name: 'Supabase',
      supabaseUrl: 'https://supabase.example.com',
      supabaseAnonKey: 'anon-key',
      supabaseBucket: 'spitout-backups',
      supabaseAccount: account,
      supabasePassword: null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuth auth;
  late CloudServiceStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _FakeAuth();
    store = CloudServiceStore(
      credentialStorage: SharedPreferencesCredentialStorage(),
    );
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    CloudServiceConfig? active,
    CloudServiceConfig? supabase,
    CloudServiceConfig? spitoutCloud,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCloudConfigProvider.overrideWith(
            (ref) async => active ?? _spitoutConfig(),
          ),
          supabaseConfigProvider.overrideWith((ref) async => supabase),
          spitoutCloudConfigProvider.overrideWith(
            (ref) async => spitoutCloud ?? _spitoutConfig(),
          ),
          authServiceProvider.overrideWith((ref) async => auth),
          cloudServiceStoreProvider.overrideWith((ref) => store),
          syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
          autoSyncValueProvider.overrideWith((ref) async => false),
          spitoutCloudProviderInstance.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AuthPage(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('WebDAV 后端不展示登录表单，显示已配置提示', (tester) async {
    await pumpLogin(
      tester,
      active: CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: 'WebDAV',
      ),
    );

    expect(find.text('WebDAV 云服务已配置'), findsOneWidget);
    expect(find.text('账号'), findsNothing);
  });

  testWidgets('空账号点击登录 → 显示账号无效提示', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('请输入账号'), findsOneWidget);
    expect(auth.signInCalled, isFalse);
    // flush LoggerService 的 2s 保存定时器
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('密码可见性切换', (tester) async {
    await pumpLogin(tester);

    final pwdField = find.byType(TextField).at(1);
    expect(tester.widget<TextField>(pwdField).obscureText, isTrue);

    await tester.tap(find.byIcon(AppIcons.visibility));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(pwdField).obscureText, isFalse);
  });

  testWidgets('勾选记住账号后登录成功 → 账号写入存储、密码不落盘、关闭登录页',
      (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.textContaining('记住账号'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(auth.signInCalled, isTrue);
    expect(auth.accountUsed, 'a@example.com');
    expect(auth.passwordUsed, 'secret123');

    final saved = await store.loadSpitoutCloud();
    expect(saved?.spitoutCloudAccount, 'a@example.com');
    expect(saved?.spitoutCloudPassword, isNull,
        reason: '密码绝不能落盘');
    // 登录页已关闭（回到首页按钮）
    expect(find.text('open'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('不勾选记住账号 → 保存时清空账号', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    final saved = await store.loadSpitoutCloud();
    expect(saved?.spitoutCloudAccount, isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('登录失败 → 展示友好错误并可重试', (tester) async {
    auth.throwError = CloudAuthException('Invalid login credentials');
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.textContaining('账号或密码不正确'), findsOneWidget);
    // 按钮恢复可用，可重试
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Supabase 后端登录成功走 Supabase 配置保存', (tester) async {
    await pumpLogin(
      tester,
      active: _supabaseConfig(),
      supabase: _supabaseConfig(),
      spitoutCloud: null,
    );

    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.textContaining('记住账号'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    final saved = await store.loadSupabase();
    expect(saved?.supabaseAccount, 'a@example.com');
    expect(saved?.supabasePassword, isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('已保存账号时进入页面自动回填并勾选记住', (tester) async {
    await pumpLogin(
      tester,
      active: _spitoutConfig(account: 'saved@example.com'),
      spitoutCloud: _spitoutConfig(account: 'saved@example.com'),
    );

    expect(find.text('saved@example.com'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });
}
