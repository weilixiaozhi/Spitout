/// SpitoutCloudSyncSection 状态卡片组件测试。
///
/// 验证「账号 + 2FA + 同步状态」合并为单张卡片：
/// - 账号 / 2FA 作为卡片头部,各占一行文案;未登录时账号行直接渲染登录按钮
///   (有保存邮密 → "重新登录",否则 → "登录"),不再伪装成可点行。
/// - 卡片下半部为同步状态详情(常驻逐项计数:当前账本 / 全部账本 / 未推送变更
///   的本地·云端计数),分类行不带 icon。
/// - 卡片不渲染右箭头,改用专属图标作分类标识(已登录账号 verifiedUser、
///   登录按钮 login;2FA lock/verifiedUser)。
///
/// 测试栈：flutter_test + flutter_riverpod，与 cloud_service_page_test.dart
/// 一致：overrideWith 提供确定值，auth/sync 用 Noop/LocalOnly/Fake 替代避免触网。
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/cloud/spitout_cloud_sync_section.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/section_card.dart';

import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

/// 已登录态的 Fake 认证服务：currentUser 返回固定用户。
///
/// NoopAuthService 只能表达"未登录"，测已登录账号行需要一个
/// 返回非 null 用户的实现；除读取接口外全部空实现（测试不触发写路径）。
class _LoggedInAuthService implements CloudAuthService {
  final CloudUser user;
  _LoggedInAuthService(this.user);

  @override
  Stream<CloudUser?> get authStateChanges => Stream.value(user);

  @override
  Future<CloudUser?> get currentUser async => user;

  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      user;

  @override
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      user;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> resendEmailVerification({required String email}) async {}
}

/// 无保存凭证的 Spitout Cloud 激活配置。
CloudServiceConfig _spitoutActive() => const CloudServiceConfig(
      type: CloudBackendType.spitoutCloud,
      name: 'Spitout Cloud',
      spitoutCloudBaseUrl: 'https://cloud.example.com',
    );

/// 带保存邮密的 Spitout Cloud 激活配置（触发"重新登录"按钮）。
CloudServiceConfig _spitoutActiveWithCredentials() => const CloudServiceConfig(
      type: CloudBackendType.spitoutCloud,
      name: 'Spitout Cloud',
      spitoutCloudBaseUrl: 'https://cloud.example.com',
      spitoutCloudEmail: 'saved@example.com',
      spitoutCloudPassword: 'secret',
    );

/// 独立挂载同步区块（不经过 CloudServicePage），便于精准断言卡片内部结构。
///
/// [sync] 传非 null 时注入真实 SyncEngine（跑 fake provider 的账户级健康
/// 检测），否则用 LocalOnlySyncService —— 后者不是 SyncEngine，refresh()
/// 早退，不会触网，同步状态行显示占位"一致"文案。
/// [extraOverrides] 用于追加/覆盖 provider 注入（如切换当前账本）。
Future<void> _pumpSection(
  WidgetTester tester, {
  required CloudServiceConfig active,
  CloudAuthService? auth,
  SyncService? sync,
  List<Override> extraOverrides = const [],
  int currentLedgerId = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeCloudConfigProvider.overrideWith((ref) async => active),
        // auth 默认未登录（NoopAuthService），测试已登录态时传入 Fake。
        authServiceProvider
            .overrideWith((ref) async => auth ?? NoopAuthService()),
        syncServiceProvider
            .overrideWith((ref) => sync ?? LocalOnlySyncService()),
        autoSyncValueProvider.overrideWith((ref) async => false),
        // provider 实例为 null → 2FA 行自动隐藏、server 版本号不显示。
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
        spitoutCloudServerVersionProvider.overrideWith((ref) async => null),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => currentLedgerId),
        ...extraOverrides,
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: SpitoutCloudSyncSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 桩 auth：重新登录抛 [CloudAuthException]（账号鉴权失败分支）。
///
/// message 含 invalid/credential 关键词，[friendlyAuthError] 据此映射到
/// 「邮箱或密码不正确」，用于回归「账号失败 → 隐藏按钮 + 内联红字 + 无 toast」。
class _SectionAuthAccountFail extends NoopAuthService {
  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw CloudAuthException('Invalid login credentials');
}

/// 桩 auth：重新登录抛网络异常（[SocketException]，走「网络失败」分支）。
///
/// 用于回归「网络失败 → 保留按钮 + 弹网络 toast」。
class _SectionAuthNetworkFail extends NoopAuthService {
  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const SocketException('network down');
}

/// 桩 auth：重新登录成功，并通过 [authStateChanges] 推送用户，
/// 使 [cloudCurrentUserProvider] 刷新（账号行从「重新登录」切到邮箱展示）。
///
/// 注意：不能 extends [NoopAuthService] —— [cloudCurrentUserProvider] 会判断
/// `auth is NoopAuthService` 后直接单发 null，导致用户永远推不上去。故直接
/// implements [CloudAuthService] 并实现全部成员。
class _SectionAuthSuccess implements CloudAuthService {
  final StreamController<CloudUser?> _controller =
      StreamController<CloudUser?>.broadcast();
  CloudUser? _current;

  _SectionAuthSuccess() {
    // 首屏：未登录（seed 阶段 provider 据此显示「重新登录」按钮）。
    _controller.add(null);
  }

  @override
  Stream<CloudUser?> get authStateChanges => _controller.stream;

  @override
  Future<CloudUser?> get currentUser async => _current;

  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _current = const CloudUser(id: 'u1', email: 'saved@example.com');
    // 登录成功 → 推送新用户，驱动账号流刷新（无需外部 invalidate）。
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      _current!;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> resendEmailVerification({required String email}) async {}
}

/// 单张卡片:账号 + 2FA 头部 与 同步状态详情 合并在同一张 SectionCard 内。
Finder _card() => find.byType(SectionCard).first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('未登录无凭证：卡片含登录按钮与同步状态详情', (tester) async {
    await _pumpSection(tester, active: _spitoutActive());

    // 账号行渲染登录按钮(无凭证 → "登录"),并带 login 图标作分类标识。
    // 注:FilledButton.icon 返回私有子类 _FilledButtonWithIcon,
    // find.byType(FilledButton) 不可靠,故用文案 + 图标断言登录按钮存在。
    expect(find.text('登录'), findsOneWidget);
    expect(find.descendant(of: _card(), matching: find.byIcon(AppIcons.login)),
        findsOneWidget);

    // 整张卡片不渲染右箭头(改用 login 图标作"需要登录"分类标识)。
    expect(
        find.descendant(
            of: _card(), matching: find.byIcon(AppIcons.chevronRight)),
        findsNothing);

    // 同步状态详情同卡内常驻:标题 + 未推送变更等逐项计数。
    // 刀3 显隐下沉:无健康报告时 carrierLedgerId 为 null,「当前账本」组
    // 不渲染(LocalOnlySyncService 非 SyncEngine,refresh 早退,不会产出报告)。
    expect(find.descendant(of: _card(), matching: find.text('同步状态')),
        findsOneWidget);
    expect(find.descendant(of: _card(), matching: find.text('当前账本')),
        findsNothing);
    expect(find.descendant(of: _card(), matching: find.text('未推送变更')),
        findsOneWidget);
    expect(
        find.descendant(of: _card(), matching: find.textContaining('本地 ')),
        findsWidgets);
  });

  testWidgets('未登录有凭证：显示「重新登录」按钮且带 login 图标', (tester) async {
    await _pumpSection(tester, active: _spitoutActiveWithCredentials());

    // 有保存邮密 → 账号行渲染"重新登录"按钮(复用本地凭证静默登录)。
    // 同上,用文案 + 图标断言按钮存在(避免 byType(FilledButton) 的子类问题)。
    expect(find.text('重新登录'), findsOneWidget);
    expect(find.descendant(of: _card(), matching: find.byIcon(AppIcons.login)),
        findsOneWidget);

    // 整张卡片不渲染右箭头。
    expect(
        find.descendant(
            of: _card(), matching: find.byIcon(AppIcons.chevronRight)),
        findsNothing);
  });

  testWidgets('已登录：账号行只读展示邮箱,卡片含同步状态详情', (tester) async {
    await _pumpSection(
      tester,
      active: _spitoutActive(),
      auth: _LoggedInAuthService(
        const CloudUser(id: 'u1', email: 'user@example.com'),
      ),
    );

    // 账号行展示邮箱(只读),用 verifiedUser 图标作分类标识。
    expect(find.text('user@example.com'), findsOneWidget);
    expect(
        find.descendant(
            of: _card(), matching: find.byIcon(AppIcons.verifiedUser)),
        findsOneWidget);

    // 整张卡片不渲染右箭头。
    expect(
        find.descendant(
            of: _card(), matching: find.byIcon(AppIcons.chevronRight)),
        findsNothing);

    // 同步状态详情在同卡内(标题「同步状态」)。
    expect(find.descendant(of: _card(), matching: find.text('同步状态')),
        findsOneWidget);

    // 2FA 行:provider 实例为 null → 整行隐藏,不显示假数据。
    expect(find.textContaining('二次验证'), findsNothing);
  });

  testWidgets('同步状态详情常驻:渲染本地/云端逐项计数行', (tester) async {
    await _pumpSection(tester, active: _spitoutActive());

    // 详情面板的分组标题与计数行应渲染(在合并卡片内)。
    // 注:刀3 显隐下沉后「当前账本」组仅在 carrierLedgerId==当前账本时渲染,
    // 本地无健康报告场景不渲染,故此处只断言「全部账本」「未推送变更」等行。
    expect(find.descendant(of: _card(), matching: find.text('全部账本')),
        findsOneWidget);
    expect(find.descendant(of: _card(), matching: find.text('未推送变更')),
        findsOneWidget);
    // 逐项计数值("本地 X · 云端 Y" / "本地 X · 云端 —")应渲染。
    expect(
        find.descendant(of: _card(), matching: find.textContaining('本地 ')),
        findsWidgets);
  });

  /// 「当前账本」组显隐场景的公共装置。
  ///
  /// 组件通过 currentLedgerProvider 读当前账本来判定载体资格,而该 provider
  /// 依赖 repositoryProvider,故这里必须把 repo 也注入内存库,否则会落到真实
  /// 数据库 provider 上,拿不到测试账本。
  ///
  /// ⚠️ 测试专用规避:currentLedgerProvider 在真实应用里是 drift StreamProvider,
  /// 订阅其流后,flutter_test 收尾 dispose 会触发 drift 的 markAsClosed 延迟
  /// timer(0ms),导致 "A Timer is still pending even after the widget tree was
  /// disposed" 断言失败——这与业务无关,是 drift+riverpod+flutter_test 的已知
  /// 副作用。这里改用一次性 FutureProvider 从内存库读账本,既保留「真实选中账本」
  /// 的语义链路,又绕开 drift 流查询的 pending timer。
  ({SyncEngine engine, List<Override> overrides, int currentLedgerId})
      healthFixture({
    required SpitoutDatabase db,
    required FakeSpitoutCloudProvider provider,
    required ChangeTracker tracker,
    required LocalRepository repo,
    required int currentLedgerId,
  }) {
    return (
      engine: SyncEngine(
        db: db,
        provider: provider,
        changeTracker: tracker,
        repo: repo,
      ),
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider.overrideWith(
            (ref) => Stream.fromFuture(repo.getLedgerById(currentLedgerId))),
      ],
      currentLedgerId: currentLedgerId,
    );
  }

  /// 插入一本云账本(cloud + syncId 非空),返回本地自增 id。
  Future<int> insertCloudLedger(SpitoutDatabase db,
          {required String name, required String syncId}) =>
      db.into(db.ledgers).insert(LedgersCompanion.insert(
            name: name,
            syncId: Value(syncId),
            storageMode: const Value('cloud'),
            currency: const Value('CNY'),
          ));

  testWidgets('选中云账本 → 渲染该账本的「当前账本」组', (tester) async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    final provider = FakeSpitoutCloudProvider();
    provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-a');
    final ledgerA =
        await insertCloudLedger(db, name: 'My Ledger', syncId: 'ledger-a');

    final f = healthFixture(
      db: db,
      provider: provider,
      tracker: tracker,
      repo: repo,
      currentLedgerId: ledgerA,
    );
    await _pumpSection(tester,
        active: _spitoutActive(),
        sync: f.engine,
        currentLedgerId: f.currentLedgerId,
        extraOverrides: f.overrides);
    // initState 的 postFrameCallback 触发 refresh(),等待账户级检测完成。
    await tester.pumpAndSettle();

    expect(find.descendant(of: _card(), matching: find.text('当前账本')),
        findsOneWidget,
        reason: '选中的云账本即载体 → 「当前账本」组渲染');
    expect(find.descendant(of: _card(), matching: find.text('全部账本')),
        findsOneWidget);
    expect(find.descendant(of: _card(), matching: find.text('未推送变更')),
        findsOneWidget);

    // 冲刷全局 logger 的 2s 节流保存 timer(engine 打日志会触发),避免
    // 测试结束时 flutter_test 报 pending timer。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('选中第二本云账本 → 仍渲染「当前账本」组(不绑死 id 升序第一本)',
      (tester) async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    final provider = FakeSpitoutCloudProvider();
    provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-a');
    provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-b');
    final ledgerA =
        await insertCloudLedger(db, name: 'Ledger A', syncId: 'ledger-a');
    final ledgerB =
        await insertCloudLedger(db, name: 'Ledger B', syncId: 'ledger-b');
    expect(ledgerA, lessThan(ledgerB), reason: '确保 B 不是 id 升序第一本');

    final f = healthFixture(
      db: db,
      provider: provider,
      tracker: tracker,
      repo: repo,
      currentLedgerId: ledgerB,
    );
    await _pumpSection(tester,
        active: _spitoutActive(),
        sync: f.engine,
        currentLedgerId: f.currentLedgerId,
        extraOverrides: f.overrides);
    await tester.pumpAndSettle();

    expect(find.descendant(of: _card(), matching: find.text('当前账本')),
        findsOneWidget,
        reason: '载体跟随用户选中的 B,不再被 id 升序第一本 A 抢走');
    expect(find.descendant(of: _card(), matching: find.text('全部账本')),
        findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('选中本地账本 → 隐藏「当前账本」组,「全部账本」组不降级',
      (tester) async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    final provider = FakeSpitoutCloudProvider();
    provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-a');
    await insertCloudLedger(db, name: 'My Ledger', syncId: 'ledger-a');
    // 另一本纯本地账本(无 syncId)→ 没有载体资格。
    final localLedger = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Local Ledger',
            storageMode: const Value('local'),
            currency: const Value('CNY'),
          ),
        );

    final f = healthFixture(
      db: db,
      provider: provider,
      tracker: tracker,
      repo: repo,
      currentLedgerId: localLedger,
    );
    await _pumpSection(tester,
        active: _spitoutActive(),
        sync: f.engine,
        currentLedgerId: f.currentLedgerId,
        extraOverrides: f.overrides);
    await tester.pumpAndSettle();

    expect(find.descendant(of: _card(), matching: find.text('当前账本')),
        findsNothing,
        reason: '本地账本无载体资格 → 报告 carrierLedgerId 为 null → 本组隐藏');
    // 账户级面板不降级:内部锚点照常打 stats,「全部账本」组仍真实渲染。
    expect(find.descendant(of: _card(), matching: find.text('全部账本')),
        findsOneWidget);
    expect(find.descendant(of: _card(), matching: find.text('未推送变更')),
        findsOneWidget);
    expect(find.descendant(of: _card(), matching: find.text('暂无云端账本')),
        findsNothing,
        reason: '账户下仍有云账本,不应误报「暂无云端账本」');

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('S4 账户级熔断:A 熔断、选中本地账本时状态行同样红字',
      (tester) async {
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db, changeTracker: tracker);
    final provider = FakeSpitoutCloudProvider();
    provider.pushFakeLedgerSnapshot(ledgerId: 'ledger-a');
    final ledgerA =
        await insertCloudLedger(db, name: 'Ledger A', syncId: 'ledger-a');
    final localLedger = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Local Ledger',
            storageMode: const Value('local'),
            currency: const Value('CNY'),
          ),
        );

    final f = healthFixture(
      db: db,
      provider: provider,
      tracker: tracker,
      repo: repo,
      currentLedgerId: localLedger,
    );
    // A 熔断,但用户选中的是本地账本 → 熔断信息与选中账本无关,仍须报红。
    f.engine.debugMarkSelfHealBroken(ledgerA.toString());

    await _pumpSection(tester,
        active: _spitoutActive(),
        sync: f.engine,
        currentLedgerId: f.currentLedgerId,
        extraOverrides: f.overrides);
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: _card(), matching: find.text('自动恢复失败，请从云端恢复')),
        findsOneWidget,
        reason: '状态行按账户级判定,任一云账本熔断即红字,不受选中账本影响');

    await tester.pump(const Duration(seconds: 3));
  });

  group('重新登录双分支回归（账号失败 / 网络失败 / 成功）', () {
    testWidgets('B1 账号鉴权失败 → 隐藏按钮 + 内联红字 + 无 toast',
        (tester) async {
      final auth = _SectionAuthAccountFail();
      await _pumpSection(
        tester,
        active: _spitoutActiveWithCredentials(),
        auth: auth,
      );

      // 未登录有凭证 → 显示「重新登录」按钮
      expect(find.text('重新登录'), findsOneWidget);

      await tester.tap(find.text('重新登录'));
      await tester.pumpAndSettle();

      // 账号鉴权失败 → 不弹 toast、不弹窗，仅内联友好红字，
      // 且「重新登录」按钮消失（避免同一错误反复可点）。
      expect(find.text('邮箱或密码不正确。'), findsOneWidget);
      expect(find.text('重新登录'), findsNothing);
      // 成功 toast 不应出现
      expect(find.text('已重新登录'), findsNothing);
    });

    testWidgets('B2 网络失败 → 保留按钮 + 弹网络 toast', (tester) async {
      final auth = _SectionAuthNetworkFail();
      await _pumpSection(
        tester,
        active: _spitoutActiveWithCredentials(),
        auth: auth,
      );

      expect(find.text('重新登录'), findsOneWidget);

      await tester.tap(find.text('重新登录'));
      // toast 约 2s 后自动消失，这里只前进短时间在它消失前断言存在。
      await tester.pump(const Duration(milliseconds: 300));

      // 网络异常 → 弹网络友好 toast，且按钮仍保留（可重试）。
      expect(find.text('网络异常，请检查网络后重试。'), findsOneWidget);
      expect(find.text('重新登录'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('B3 重新登录成功 → toast + 用户被推送（按钮消失）',
        (tester) async {
      final auth = _SectionAuthSuccess();
      await _pumpSection(
        tester,
        active: _spitoutActiveWithCredentials(),
        auth: auth,
      );

      expect(find.text('重新登录'), findsOneWidget);

      await tester.tap(find.text('重新登录'));
      await tester.pump(const Duration(milliseconds: 300));

      // 成功 → 弹成功 toast
      expect(find.text('已重新登录'), findsOneWidget);
      // 用户被推送 → 账号行展示邮箱，原「重新登录」按钮消失
      expect(find.text('saved@example.com'), findsOneWidget);
      expect(find.text('重新登录'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
    });
  });
}
