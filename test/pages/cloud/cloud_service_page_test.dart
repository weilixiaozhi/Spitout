/// 云服务页（CloudServicePage）组件测试。
///
/// 验证 TAB 改为单列表分组的改造：
/// - 三段 TAB（离线模式 / 备份同步 / 云端协同）变为分组主标题，原 CapsuleSwitcher 被移除。
/// - 各分组下的服务卡片（逻辑不变）仍正常渲染。
/// - 多设备同步警告仅在激活非本地、非 Spitout Cloud 后端时出现在「备份同步」分组下。
///
/// 以及云同步页面归并改造（2026-07-26）：
/// - 5 张服务卡片在任意激活类型下常驻（切换/配置入口始终可达）。
/// - CloudSyncSection 仅当 active ∈ {webdav, s3, supabase} 时显示；
///   SpitoutCloudSyncSection 仅当 active == spitoutCloud 时显示。
///
/// 测试栈：flutter_test + flutter_riverpod（与项目一致）。通过 overrideWith
/// 直接提供各云服务配置 Provider 的确定值，避免依赖数据库 / SharedPreferences。
/// 嵌入区块的 auth/sync 依赖用 NoopAuthService / LocalOnlySyncService 替代，
/// 避免测试环境触网。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/pages/cloud/cloud_service_page.dart';
import 'package:spitout/pages/cloud/cloud_sync_section.dart';
import 'package:spitout/pages/cloud/spitout_cloud_sync_section.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/widgets.dart';

/// 桩 auth：记录 [CloudAuthService.signInWithEmail] 是否被调用及入参，
/// 用于断言「保存并立即切换 → 登录」与「保存但暂不切换 → 不登录」两个分支。
class _FakeSpitoutAuth extends CloudAuthService {
  bool signInCalled = false;
  String? emailUsed;
  String? passwordUsed;

  @override
  Stream<CloudUser?> get authStateChanges => Stream.value(null);

  @override
  Future<CloudUser?> get currentUser async => null;

  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    emailUsed = email;
    passwordUsed = password;
    return const CloudUser(id: 'fake-uid', email: 'fake@x.com');
  }

  @override
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      const CloudUser(id: 'fake-uid', email: 'fake@x.com');

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> resendEmailVerification({required String email}) async {}
}

/// 桩 auth：登录抛 [CloudAuthException]（账号鉴权失败分支）。
///
/// 用于回归「账号鉴权失败 → 弹友好文案且不激活服务」：message 含 invalid/
/// credential 关键词，[friendlyAuthError] 据此映射到「邮箱或密码不正确」。
class _CloudPageAuthAccountFail extends _FakeSpitoutAuth {
  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    throw CloudAuthException('Invalid login credentials');
  }
}

/// 桩 auth：登录抛网络异常（[SocketException]，走「网络失败」分支）。
///
/// 用于回归「网络异常 → 弹网络友好文案且不激活服务」。
class _CloudPageAuthNetworkFail extends _FakeSpitoutAuth {
  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    throw const SocketException('network down');
  }
}

/// 本地存储配置：作为激活配置时不渲染多设备同步警告。
CloudServiceConfig _localActive() => CloudServiceConfig.localStorage();

/// 已校验的 WebDAV 配置：作为激活配置时应渲染多设备同步警告。
CloudServiceConfig _webdavActive() => const CloudServiceConfig(
      type: CloudBackendType.webdav,
      name: 'WebDAV',
      webdavUrl: 'https://dav.example.com',
      webdavUsername: 'u',
      webdavPassword: 'p',
    );

/// 已校验的 S3 配置。
CloudServiceConfig _s3Active() => const CloudServiceConfig(
      type: CloudBackendType.s3,
      name: 'S3',
      s3Endpoint: 'https://s3.example.com',
      s3AccessKey: 'ak',
      s3SecretKey: 'sk',
      s3Bucket: 'bucket',
    );

/// 已校验的 Supabase 配置。
CloudServiceConfig _supabaseActive() => const CloudServiceConfig(
      type: CloudBackendType.supabase,
      name: 'Supabase',
      supabaseUrl: 'https://xxx.supabase.co',
      supabaseAnonKey: 'anon-key',
    );

/// 已校验的 Spitout Cloud 配置。
CloudServiceConfig _spitoutActive() => const CloudServiceConfig(
      type: CloudBackendType.spitoutCloud,
      name: 'Spitout Cloud',
      spitoutCloudBaseUrl: 'https://cloud.example.com',
    );

/// 在 ProviderScope 中挂载页面，并覆盖 5 个云服务配置 Provider 的确定值。
Future<void> _pumpPage(
  WidgetTester tester, {
  required CloudServiceConfig active,
  CloudServiceConfig? webdav,
  CloudServiceConfig? s3,
  CloudServiceConfig? supabase,
  CloudServiceConfig? spitoutCloud,
  Map<String, Object>? initialPrefs,
}) async {
  // 预置 SharedPreferences，使 initState 中的测试结果恢复不依赖真实存储；
  // 也用于验证「重新进入页面保留上次测试结果」的持久化逻辑。
  SharedPreferences.setMockInitialValues(initialPrefs ?? {});
  // ListView 为懒构建：测试默认视口仅 600px，底部的「云端协同」分组不会被构建。
  // 抬高视口以确保所有分组均进入构建树，便于断言。
  // 仅本文件两个测试使用，互不影响，无需复位。
  // 高度设足（4000）以确保 ListView 懒构建出底部「云端协同」分组；
  // 宽度设 1000 以规避主 Header 在窄屏下的 2.6px 横向溢出（与本次改造无关）。
  tester.view.physicalSize = const Size(1000, 4000);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // FutureProvider 使用 overrideWith 提供确定值（本版本 riverpod 不支持 overrideWithValue）
        activeCloudConfigProvider.overrideWith((ref) async => active),
        webdavConfigProvider.overrideWith((ref) async => webdav),
        s3ConfigProvider.overrideWith((ref) async => s3),
        supabaseConfigProvider.overrideWith((ref) async => supabase),
        spitoutCloudConfigProvider.overrideWith((ref) async => spitoutCloud),
        // 嵌入同步区块（CloudSyncSection / SpitoutCloudSyncSection）的依赖：
        // Noop/LocalOnly 实现替代真实 auth/sync，避免测试环境触网或依赖数据库。
        authServiceProvider.overrideWith((ref) async => NoopAuthService()),
        syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
        autoSyncValueProvider.overrideWith((ref) async => false),
        // SpitoutCloud 区块的 2FA 状态行与 server 版本号：
        // provider 为 null 时自动隐藏，无需真实实例。
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
        spitoutCloudServerVersionProvider.overrideWith((ref) async => null),
        // 本测试只验证云 UI 可见性，与「当前账本选择」无关。currentLedgerIdProvider
        // 默认已改为哨兵 0（表示「未选中」），而同步区块对 ledgerId==0 渲染为
        // 简化提示而非完整 UI，故显式指定一个有效账本 id 以渲染完整同步区块。
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
      ],
      child: MaterialApp(
        // 测试环境默认 locale 为 en，强制 zh 以渲染中文文案
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CloudServicePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('列表布局：三段 TAB 变为分组主标题，CapsuleSwitcher 已移除',
      (tester) async {
    await _pumpPage(tester, active: _localActive());

    // 三个分组主标题均渲染
    expect(find.text('离线模式'), findsOneWidget);
    expect(find.text('备份同步'), findsOneWidget);
    expect(find.text('云端协同'), findsOneWidget);

    // 原 TAB 控件已彻底移除
    expect(find.byType(CapsuleSwitcher), findsNothing);

    // 离线模式分组下的本地存储卡片渲染
    expect(find.text('本地存储'), findsOneWidget);

    // 本地激活时不渲染多设备同步警告
    expect(find.text('多设备使用提醒'), findsNothing);
  });

  testWidgets('备份同步分组：WebDAV 激活时展示多设备同步警告',
      (tester) async {
    await _pumpPage(tester, active: _webdavActive(), webdav: _webdavActive());

    // WebDAV 已激活 → 多设备同步警告出现
    expect(find.text('多设备使用提醒'), findsOneWidget);

    // 三个分组主标题始终都在
    expect(find.text('离线模式'), findsOneWidget);
    expect(find.text('备份同步'), findsOneWidget);
    expect(find.text('云端协同'), findsOneWidget);

    // Spitout Cloud 分组卡片（未配置状态）也正常渲染
    expect(find.text('Spitout Cloud'), findsOneWidget);

    // 归并改造：WebDAV 激活 → 备份同步区块显示、云端协同区块隐藏
    expect(find.byType(CloudSyncSection), findsOneWidget);
    expect(find.byType(SpitoutCloudSyncSection), findsNothing);
  });

  testWidgets('可见性：local 激活时两个同步区块均隐藏，5 张卡片常驻',
      (tester) async {
    await _pumpPage(tester, active: _localActive());

    expect(find.byType(CloudSyncSection), findsNothing);
    expect(find.byType(SpitoutCloudSyncSection), findsNothing);

    // 5 张服务卡片常驻（切换/配置入口始终可达）
    expect(find.text('本地存储'), findsOneWidget);
    expect(find.text('自定义 WebDAV'), findsOneWidget);
    expect(find.text('S3 协议存储'), findsOneWidget);
    expect(find.text('自定义 Supabase'), findsOneWidget);
    expect(find.text('Spitout Cloud'), findsOneWidget);
  });

  testWidgets('可见性：S3 激活时显示备份同步区块（上传/下载/自动同步）',
      (tester) async {
    await _pumpPage(tester, active: _s3Active(), s3: _s3Active());

    expect(find.byType(CloudSyncSection), findsOneWidget);
    expect(find.byType(SpitoutCloudSyncSection), findsNothing);

    // 区块内同步操作锚点（LocalOnlySyncService 返回 notConfigured → 操作可用）
    expect(find.text('上传'), findsOneWidget);
    expect(find.text('下载同步'), findsOneWidget);
    expect(find.text('自动同步账本'), findsOneWidget);
  });

  testWidgets('可见性：Supabase 激活时显示备份同步区块且含登录行',
      (tester) async {
    await _pumpPage(tester,
        active: _supabaseActive(), supabase: _supabaseActive());

    expect(find.byType(CloudSyncSection), findsOneWidget);
    expect(find.byType(SpitoutCloudSyncSection), findsNothing);

    // Supabase 专属登录行（NoopAuthService → 未登录态显示「登录」）
    expect(find.text('登录'), findsOneWidget);
  });

  testWidgets('可见性：SpitoutCloud 激活时显示云端协同区块、隐藏备份同步区块',
      (tester) async {
    await _pumpPage(tester,
        active: _spitoutActive(), spitoutCloud: _spitoutActive());

    expect(find.byType(CloudSyncSection), findsNothing);
    expect(find.byType(SpitoutCloudSyncSection), findsOneWidget);

    // 云端协同区块锚点：紧凑状态行（改造后为「同步状态 · xxx」单行文案）
    // + 同步说明折叠区标题
    expect(find.textContaining('同步状态'), findsOneWidget);
    expect(find.text('同步说明 · 为什么有时同步不动？'), findsOneWidget);

    // 5 张服务卡片仍然常驻，保证可切回其他后端
    expect(find.text('本地存储'), findsOneWidget);
    expect(find.text('自定义 WebDAV'), findsOneWidget);
    expect(find.text('S3 协议存储'), findsOneWidget);
    expect(find.text('自定义 Supabase'), findsOneWidget);

    // SpitoutCloud 激活时不显示多设备警告
    expect(find.text('多设备使用提醒'), findsNothing);
  });

  testWidgets('配置对话框：已配置显示删除图标，未配置不显示', (tester) async {
    // WebDAV 已配置、Supabase 未配置
    await _pumpPage(tester, active: _localActive(), webdav: _webdavActive());

    // —— 已配置:点 WebDAV 卡片的「配置」按钮打开对话框 ——
    // 注意:本地存储卡片新增「配置」入口(进入本地备份页)后,页面上有多个
    // 「配置」按钮;按布局顺序(离线模式分组在前)本地存储为第 0 个,WebDAV 为第 1 个。
    await tester.tap(find.text('配置').at(1));
    await tester.pumpAndSettle();
    // 配置弹窗已改为顶部贴边弹层 AppSheet,不再使用 AlertDialog
    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsOneWidget);
    // 关闭对话框
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);

    // —— 未配置:点 Supabase 卡片(未配置时点击卡片即打开配置对话框) ——
    await tester.tap(find.text('自定义 Supabase'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsNothing);
  });

  testWidgets('配置弹窗改为顶部贴边弹层 AppSheet,聚焦下一字段不收起键盘',
      (tester) async {
    await _pumpPage(tester, active: _localActive(), webdav: _webdavActive());

    // 打开 WebDAV 配置弹窗(现为顶部贴边弹层)
    await tester.tap(find.text('配置').at(1));
    await tester.pumpAndSettle();

    // 关键断言:配置弹窗为 AppSheet 而非 AlertDialog(修复弹窗弹跳/键盘闪烁的根因)
    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    // 弹窗内 4 个输入框:0=地址 1=用户名 2=密码 3=远程路径
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));

    // 焦点链式切换:在第一个字段触发「下一步」后,焦点应落到第二个字段,
    // 从而避免输入框切换时键盘反复收起/拉起。
    await tester.showKeyboard(fields.at(0));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final secondField = tester.widget<TextField>(fields.at(1));
    expect(secondField.focusNode?.hasFocus, isTrue,
        reason: '点击「下一步」后焦点应移交到下一输入框,键盘不应收起');
  });

  testWidgets('配置弹窗顶部贴边且无键盘跟随动画(无 AnimatedPadding)',
      (tester) async {
    await _pumpPage(tester, active: _localActive(), webdav: _webdavActive());

    // 打开 WebDAV 配置弹窗(顶部贴边弹层)
    await tester.tap(find.text('配置').at(1));
    await tester.pumpAndSettle();

    // 弹层为 AppSheet(非 AlertDialog)
    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    // 关键回归守卫:弹层必须锚定在屏幕顶部(Align.topCenter),而非底部弹层。
    // 底部弹层(showModalBottomSheet)内部用 AnimatedPadding 跟随键盘 viewInsets 做动画,
    // 切换输入框时会触发 IME 收起/拉起,表现为弹窗上下「弹跳」。顶部贴边后键盘自底部拉起,
    // 与弹层物理上不重叠,彻底规避弹跳。若改回底部弹层,此处 Align.topCenter 将不存在,测试转红。
    // 注:路由外层 SafeArea 本身含一个 AnimatedPadding(跟随 padding 而非 viewInsets,无键盘动画),
    // 故不采用「无 AnimatedPadding」断言,改用顶部锚定断言更精准。
    final aligns = tester.widgetList<Align>(find.byType(Align));
    expect(
      aligns.any((a) => a.alignment == Alignment.topCenter),
      isTrue,
    );

    // 进一步确证:弹层实际贴住屏幕顶部(顶部 y 接近 0,远小于屏高的 10%),
    // 区别于底部弹层(其顶部位于屏幕下方约 15% 处)。
    // 注意:getTopLeft 返回逻辑像素,故屏高需用 physicalSize / devicePixelRatio 换算。
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final sheetTop = tester.getTopLeft(find.byType(AppSheet)).dy;
    expect(sheetTop, lessThan(logicalHeight * 0.1));
  });

  testWidgets('配置弹窗保存时内联校验:缺必填项不弹窗、保留已填内容',
      (tester) async {
    // Supabase 在此入参下为「未配置」,点击卡片即打开配置弹窗且字段初始为空,
    // 便于稳定验证「缺必填项」的内联校验(已配置弹窗会预填旧值,无法触发缺项)。
    await _pumpPage(tester, active: _localActive(), webdav: _webdavActive());
    await tester.tap(find.text('自定义 Supabase'));
    await tester.pumpAndSettle();

    // 仅填入 url,key 留空(key 为必填);此时弹窗字段初始为空,不会因预填而误判通过。
    await tester.enterText(find.byType(TextField).at(0), 'https://supabase.example.com');
    await tester.pumpAndSettle();

    // 点击「保存」
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 关键回归:校验失败不应切换到另一个弹窗(不再出现独立错误弹窗),
    // 也不会因弹窗关闭而丢失已填内容。若改回「先 pop 再 AppDialog.error」,
    // 此处将出现 AlertDialog 且 AppSheet 消失,测试转红。
    expect(find.byType(AlertDialog), findsNothing,
        reason: '校验失败不应弹出独立错误弹窗');
    expect(find.byType(AppSheet), findsOneWidget,
        reason: '校验失败时配置弹窗应保持打开');

    // 内联弱提示出现在未填的必填字段下方(随文案本地化,不直接硬编码字符串)
    final l10n = AppLocalizations.of(tester.element(find.byType(TextField).first));
    expect(find.text(l10n.cloudConfigInvalidMessage), findsWidgets,
        reason: '未填必填项应在字段下方显示内联弱提示');

    // 已填内容被保留:url 字段文本仍在,弹窗未关闭
    final urlField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(urlField.controller?.text, 'https://supabase.example.com');
  });

  testWidgets('清除配置流程：删除 → 确认 → 回到未配置状态', (tester) async {
    // 用真实 CloudServiceStore + mock SharedPreferences,验证端到端清除效果
    SharedPreferences.setMockInitialValues({});
    await CloudServiceStore().saveOnly(_webdavActive());

    // 不 override 配置 Provider,让其读真实 store
    tester.view.physicalSize = const Size(1000, 4000);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CloudServicePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 已配置 → 存在「配置」按钮（第 1 个为 WebDAV，第 0 个为本地存储备份入口）
    await tester.tap(find.text('配置').at(1));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.delete), findsOneWidget);

    // 点删除图标 → 二次确认弹窗
    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    expect(find.text('清除云端配置'), findsOneWidget);

    // 确认清除
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 配置已被清除,卡片回到未配置副标题
    expect(await CloudServiceStore().loadWebdav(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('点击配置坚果云/Nextcloud等'), findsOneWidget);

    // 排空 toast 的 2s 延时移除,避免测试结束时存在 pending Timer
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('清除配置流程：取消确认 → 配置保留', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await CloudServiceStore().saveOnly(_webdavActive());

    tester.view.physicalSize = const Size(1000, 4000);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CloudServicePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('配置').at(1)); // 第 1 个为 WebDAV
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    expect(find.text('清除云端配置'), findsOneWidget);

    // 取消 → 配置仍在
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await CloudServiceStore().loadWebdav(), isNotNull);
  });

  group('测试连接（内联展示 + 持久化）', () {
    testWidgets('WebDAV 激活：展示「测试连接」文字链与「未测试」状态，且点击不弹窗',
        (tester) async {
      await _pumpPage(tester, active: _webdavActive(), webdav: _webdavActive());
      // 内联「测试连接」文字链存在
      expect(find.text('测试连接'), findsOneWidget);
      // 初次进入（无历史）显示「未测试」
      expect(find.text('未测试'), findsOneWidget);
      // 点击文字链不应弹出任何对话框（已改为内联展示）
      await tester.tap(find.text('测试连接'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('local 激活：不展示「测试连接」文字链与状态徽标', (tester) async {
      await _pumpPage(tester, active: _localActive());
      expect(find.text('测试连接'), findsNothing);
      expect(find.text('未测试'), findsNothing);
    });

    testWidgets('重新进入页面保留上次测试结果（持久化恢复 + 内联时间/详情）',
        (tester) async {
      final now = DateTime(2026, 7, 19, 16, 12, 12);
      await _pumpPage(
        tester,
        active: _webdavActive(),
        webdav: _webdavActive(),
        initialPrefs: {
          'cloud_test_result_webdav': true,
          'cloud_test_time_webdav': now.millisecondsSinceEpoch,
          'cloud_test_message_webdav': '连接正常,配置有效',
        },
      );
      // 状态徽标：连接正常
      expect(find.text('连接正常'), findsOneWidget);
      // 上次测试时间行（格式 YYYY-MM-DD HH:MM:SS）
      expect(find.text('上次测试时间：2026-07-19 16:12:12'), findsOneWidget);
      // 详情文案
      expect(find.text('连接正常,配置有效'), findsOneWidget);
      // 文字链仍在
      expect(find.text('测试连接'), findsOneWidget);
    });
  });

  group('首次保存后引导切换（2026-07-27）', () {
    /// 使用真实 CloudServiceStore（mock SharedPreferences）挂载页面。
    ///
    /// 与 [_pumpPage] 的区别:不覆盖各配置 Provider,让保存 → 激活流程
    /// 端到端走真实 store;仅将 auth/sync 等运行时依赖替换为 Noop/LocalOnly,
    /// 避免切换成功后渲染同步区块时触网或依赖数据库。
    Future<void> pumpWithRealStore(WidgetTester tester) async {
      // 显式设置 DPR=1,保证逻辑宽度足够（默认 DPR=3 时逻辑宽仅 333px,
      // 引导弹窗的双按钮行会溢出导致测试误报）
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) async => NoopAuthService()),
            syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
            autoSyncValueProvider.overrideWith((ref) async => false),
            spitoutCloudProviderInstance.overrideWith((ref) async => null),
            spitoutCloudServerVersionProvider.overrideWith((ref) async => null),
            currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CloudServicePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// 打开未配置的 WebDAV 配置弹窗并填写有效配置后点击保存。
    Future<void> fillAndSaveWebdav(WidgetTester tester) async {
      // 未配置时点击卡片即打开配置弹窗
      await tester.tap(find.text('自定义 WebDAV'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsOneWidget);

      // 弹窗内 TextField 顺序:0=地址 1=用户名 2=密码 3=远程路径
      await tester.enterText(
          find.byType(TextField).at(0), 'https://dav.example.com');
      await tester.enterText(find.byType(TextField).at(1), 'user');
      await tester.enterText(find.byType(TextField).at(2), 'pass');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
    }

    testWidgets('首次创建保存后弹出引导弹窗,选「暂不切换」仅保存不激活',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpWithRealStore(tester);
      await fillAndSaveWebdav(tester);

      // 引导弹窗出现,含两个选项
      expect(find.text('暂不切换'), findsOneWidget);
      expect(find.text('立即切换'), findsOneWidget);

      // 选「暂不切换」→ 配置已保存但激活仍为本地存储
      await tester.tap(find.text('暂不切换'));
      await tester.pumpAndSettle();
      // 首次创建由引导弹窗承接反馈,不应再出现「配置已保存」toast
      // （弹窗已关闭,此时若有 toast 仍会在屏,故 findsNothing 可判定）
      expect(find.text('配置已保存'), findsNothing);
      expect(await CloudServiceStore().loadWebdav(), isNotNull);
      expect((await CloudServiceStore().loadActive()).type,
          CloudBackendType.local);
      // 同步区块不应出现
      expect(find.byType(CloudSyncSection), findsNothing);

      // 排空 toast 的延时移除,避免测试结束时存在 pending Timer
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('首次创建保存后选「立即切换」→ 配置被激活且同步区块出现',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpWithRealStore(tester);
      await fillAndSaveWebdav(tester);

      // 选「立即切换」→ 保存后自动激活为当前同步配置
      await tester.tap(find.text('立即切换'));
      await tester.pumpAndSettle();
      expect((await CloudServiceStore().loadActive()).type,
          CloudBackendType.webdav);
      // 激活后备份同步区块出现（卡片显示已连接状态）
      expect(find.byType(CloudSyncSection), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('编辑已有配置保存后也弹引导弹窗（新建/编辑统一）且无 toast',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      // 预置已有 WebDAV 配置 → 走「编辑」场景
      await CloudServiceStore().saveOnly(_webdavActive());
      await pumpWithRealStore(tester);

      // 已配置 → 点「配置」按钮打开编辑弹窗（第 0 个为本地存储备份入口）
      await tester.tap(find.text('配置').at(1));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsOneWidget);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 编辑场景同样弹出引导弹窗（标题即「配置已保存」承接反馈,不再 toast）
      expect(find.text('暂不切换'), findsOneWidget);
      expect(find.text('立即切换'), findsOneWidget);

      // 选「暂不切换」→ 激活状态不受影响,且弹窗关闭后无残留 toast
      await tester.tap(find.text('暂不切换'));
      await tester.pumpAndSettle();
      expect(find.text('配置已保存'), findsNothing);
      expect((await CloudServiceStore().loadActive()).type,
          CloudBackendType.local);

      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Spitout Cloud 登录 / 暂不切换（桩 createCloudServices）', () {
    /// 挂载页面 + 真实 store + 桩 cloudServicesFactoryProvider。
    /// 桩在 Spitout 登录块返回带断言钩子的 [fakeAuth]，不触网。
    Future<void> pumpWithFakeCloud(
      WidgetTester tester,
      _FakeSpitoutAuth fakeAuth,
    ) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) async => NoopAuthService()),
            syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
            autoSyncValueProvider.overrideWith((ref) async => false),
            spitoutCloudProviderInstance.overrideWith((ref) async => null),
            spitoutCloudServerVersionProvider.overrideWith((ref) async => null),
            currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
            // 关键桩：让 Spitout 登录块走可覆盖工厂，返回 Fake auth
            cloudServicesFactoryProvider.overrideWith(
              (ref) => (config) async => (provider: null, auth: fakeAuth),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CloudServicePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openSpitoutDialogAndFill(WidgetTester tester) async {
      // 未配置时点击卡片直接打开配置弹窗
      await tester.tap(find.text('Spitout Cloud'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://cloud.example.com',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextField).at(2), 'secret');
      // 保存 → 弹出"是否立即切换"引导
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
    }

    testWidgets('带邮箱密码保存 + 立即切换 → 登录且 auto_sync 开启',
        (tester) async {
      final fakeAuth = _FakeSpitoutAuth();
      SharedPreferences.setMockInitialValues({});
      await pumpWithFakeCloud(tester, fakeAuth);

      await openSpitoutDialogAndFill(tester);

      // 引导弹窗选择"立即切换"
      expect(find.text('立即切换'), findsOneWidget);
      await tester.tap(find.text('立即切换'));
      await tester.pumpAndSettle();

      // 1) 登录被调用，且邮箱/密码正确透传
      expect(fakeAuth.signInCalled, isTrue);
      expect(fakeAuth.emailUsed, 'user@example.com');
      expect(fakeAuth.passwordUsed, 'secret');

      // 2) 自动同步被置为 true（持久化到 SharedPreferences）
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auto_sync'), isTrue);

      // 3) 活跃类型切到 spitoutCloud，且云端协同区块出现
      expect((await CloudServiceStore().loadActive()).type,
          CloudBackendType.spitoutCloud);
      expect(find.byType(SpitoutCloudSyncSection), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('带邮箱密码保存 + 暂不切换 → 不登录、auto_sync 仍为 false、活跃仍是 local',
        (tester) async {
      final fakeAuth = _FakeSpitoutAuth();
      SharedPreferences.setMockInitialValues({});
      await pumpWithFakeCloud(tester, fakeAuth);

      await openSpitoutDialogAndFill(tester);

      // 引导弹窗选择"暂不切换"（本次关键修复：不再假切换登录）
      expect(find.text('暂不切换'), findsOneWidget);
      await tester.tap(find.text('暂不切换'));
      await tester.pumpAndSettle();

      // 1) 未触发登录
      expect(fakeAuth.signInCalled, isFalse);

      // 2) auto_sync 未被置 true
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auto_sync'), isNot(isTrue));

      // 3) 活跃类型仍是 local（仅保存，未切换）
      expect((await CloudServiceStore().loadActive()).type,
          CloudBackendType.local);

      // 4) 配置已持久化（卡片"已配置"徽标随之刷新），且同步区块不出现
      expect(await CloudServiceStore().loadSpitoutCloud(), isNotNull);
      expect(find.byType(SpitoutCloudSyncSection), findsNothing);
      expect(find.byType(CloudSyncSection), findsNothing);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('带邮箱密码保存 + 立即切换 → 账号异常弹窗且不激活服务',
        (tester) async {
      final fakeAuth = _CloudPageAuthAccountFail();
      SharedPreferences.setMockInitialValues({});
      await pumpWithFakeCloud(tester, fakeAuth);

      await openSpitoutDialogAndFill(tester);

      expect(find.text('立即切换'), findsOneWidget);
      await tester.tap(find.text('立即切换'));
      await tester.pumpAndSettle();

      // 账号鉴权失败 → 友好文案弹窗（邮箱或密码不正确），且不激活服务。
      expect(find.text('邮箱或密码不正确。'), findsOneWidget);
      expect(fakeAuth.signInCalled, isTrue);
      expect((await CloudServiceStore().loadActive()).type,
          isNot(equals(CloudBackendType.spitoutCloud)));

      // 排空弹窗（保持打开状态），测试结束无残留定时器。
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('带邮箱密码保存 + 立即切换 → 网络异常弹窗且不激活服务',
        (tester) async {
      final fakeAuth = _CloudPageAuthNetworkFail();
      SharedPreferences.setMockInitialValues({});
      await pumpWithFakeCloud(tester, fakeAuth);

      await openSpitoutDialogAndFill(tester);

      expect(find.text('立即切换'), findsOneWidget);
      await tester.tap(find.text('立即切换'));
      await tester.pumpAndSettle();

      // 网络异常 → 友好文案弹窗（网络异常，请检查网络后重试），同样不激活服务。
      expect(find.text('网络异常，请检查网络后重试。'), findsOneWidget);
      expect(fakeAuth.signInCalled, isTrue);
      expect((await CloudServiceStore().loadActive()).type,
          isNot(equals(CloudBackendType.spitoutCloud)));

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('带邮箱密码保存 + 立即切换 → 登录成功且无错误弹窗、激活服务',
        (tester) async {
      final fakeAuth = _FakeSpitoutAuth();
      SharedPreferences.setMockInitialValues({});
      await pumpWithFakeCloud(tester, fakeAuth);

      await openSpitoutDialogAndFill(tester);

      expect(find.text('立即切换'), findsOneWidget);
      await tester.tap(find.text('立即切换'));
      await tester.pumpAndSettle();

      // 成功：不应出现任何错误弹窗文案，且正常激活到 spitoutCloud。
      expect(find.text('邮箱或密码不正确。'), findsNothing);
      expect(find.text('网络异常，请检查网络后重试。'), findsNothing);
      expect((await CloudServiceStore().loadActive()).type,
          CloudBackendType.spitoutCloud);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('无邮箱密码 + 立即切换 → 跳过登录直接激活（不调用登录）',
        (tester) async {
      final fakeAuth = _FakeSpitoutAuth();
      SharedPreferences.setMockInitialValues({});
      await pumpWithFakeCloud(tester, fakeAuth);

      // 打开配置弹窗但邮箱/密码留空
      await tester.tap(find.text('Spitout Cloud'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://cloud.example.com',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('立即切换'), findsOneWidget);
      await tester.tap(find.text('立即切换'));
      await tester.pumpAndSettle();

      // 无凭证 → 登录块被跳过，fakeAuth 的 signIn 未被调用，但仍激活服务。
      expect(fakeAuth.signInCalled, isFalse);
      expect((await CloudServiceStore().loadActive()).type,
          CloudBackendType.spitoutCloud);

      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Supabase 立即切换（回归：激活由 _activateService 接管，无冗余 invalidate active）', () {
    testWidgets('保存 + 立即切换 → 激活 Supabase 且同步区块出现', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) async => NoopAuthService()),
            syncServiceProvider.overrideWith((ref) => LocalOnlySyncService()),
            autoSyncValueProvider.overrideWith((ref) async => false),
            spitoutCloudProviderInstance.overrideWith((ref) async => null),
            spitoutCloudServerVersionProvider.overrideWith((ref) async => null),
            currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CloudServicePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 未配置时点击卡片打开 Supabase 配置弹窗
      await tester.tap(find.text('自定义 Supabase'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).at(0), 'https://supabase.example.com');
      await tester.enterText(find.byType(TextField).at(1), 'anon-key');
      await tester.enterText(find.byType(TextField).at(2), 'bucket-1');
      // 保存 → 弹出"是否立即切换"引导
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 引导弹窗选择"立即切换"
      expect(find.text('立即切换'), findsOneWidget);
      await tester.tap(find.text('立即切换'));
      await tester.pumpAndSettle();

      // 激活由 _activateService 接管（不再手写 invalidate active），行为等价：
      // 活跃类型切到 supabase，且通用同步区块（含登录行）出现。
      expect((await CloudServiceStore().loadActive()).type,
          CloudBackendType.supabase);
      expect(find.byType(CloudSyncSection), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });
  });
}