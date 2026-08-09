// 加入共享账本页测试。
//
// 覆盖：邀请码格式校验 → 预览成功/失败 → 预览卡片（角色/有效期文案）→
// 取消返回输入态 → 接受成功/失败 → prefilledCode 自动预览。
// 云端 backend 与同步引擎用 mock 注入，不触网。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show
        SpitoutCloudInviteAcceptResult,
        SpitoutCloudInvitePreview,
        SpitoutCloudSyncBackend;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/cloud/join_shared_ledger_page.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart';

import '../../helpers/test_isolation.dart';

class _MockBackend extends Mock implements SpitoutCloudSyncBackend {}

class _MockEngine extends Mock implements SyncEngine {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBackend backend;
  late _MockEngine engine;

  SpitoutCloudInvitePreview previewFixture({
    DateTime? expiresAt,
    bool nullExpiry = false,
    String role = 'editor',
  }) {
    // 多给 5 分钟缓冲，避免断言瞬间跨越整点/整小时边界。
    final expiry = nullExpiry
        ? null
        : (expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 5)));
    return SpitoutCloudInvitePreview(
      code: 'ABC234',
      ledgerExternalId: 'ledger-ext-1',
      ledgerCurrency: 'CNY',
      invitedByDisplay: '小明',
      targetRole: role,
      expiresAt: expiry,
      ledgerName: '家庭账本',
    );
  }

  setUp(() {
    resetGlobalTestState();
    backend = _MockBackend();
    engine = _MockEngine();
    when(() => backend.previewInvite(code: any(named: 'code')))
        .thenAnswer((_) async => previewFixture());
    when(() => backend.acceptInvite(code: any(named: 'code')))
        .thenAnswer((_) async => const SpitoutCloudInviteAcceptResult(
              ledgerExternalId: 'ledger-ext-1',
              ledgerCurrency: 'CNY',
              role: 'editor',
              memberCount: 2,
              ledgerName: '家庭账本',
            ));
    // onInviteAccepted 是扩展方法无法被 mocktail 拦截，stub 其内部首个
    // 实例方法即可；后续扩展逻辑内部调用失败会被自身 catch 兜住。
    when(() => engine.syncLedgersFromServer()).thenAnswer((_) async => 0);
  });

  Widget buildApp({
    String? prefilledCode,
    bool pushRoute = true,
  }) {
    final page = JoinSharedLedgerPage(prefilledCode: prefilledCode);
    return ProviderScope(
      overrides: [
        spitoutCloudProviderInstance.overrideWith((ref) async => backend),
        syncEngineProvider.overrideWith((ref, cloud) => engine),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: pushRoute
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => page),
                      ),
                      child: const Text('open-join'),
                    ),
                  ),
                ),
              )
            : page,
      ),
    );
  }

  Future<void> openPage(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.tap(find.text('open-join'));
    await tester.pumpAndSettle();
  }

  Future<void> submitCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('验证邀请码'));
    await tester.pumpAndSettle();
  }

  group('输入与预览', () {
    testWidgets('邀请码不足 6 位：展示格式错误提示', (tester) async {
      await openPage(tester, buildApp());

      await tester.enterText(find.byType(TextField), 'AB');
      await tester.tap(find.text('验证邀请码'));
      await tester.pump();

      expect(find.text('邀请码格式不对,请输入 6 位字母数字'), findsOneWidget);
      verifyNever(() => backend.previewInvite(code: any(named: 'code')));
    });

    testWidgets('预览成功：展示邀请人/账本名/角色/有效期与接受按钮', (tester) async {
      await openPage(tester, buildApp());

      await submitCode(tester, 'ABC234');

      expect(find.text('小明 邀请你加入'), findsOneWidget);
      expect(find.text('家庭账本'), findsOneWidget);
      expect(find.text('角色:编辑者'), findsOneWidget);
      expect(find.textContaining('有效期还剩 5 小时'), findsOneWidget);
      expect(find.text('加入账本'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      verify(() => backend.previewInvite(code: 'ABC234')).called(1);
    });

    testWidgets('预览接口返回无效码：展示对应错误文案', (tester) async {
      when(() => backend.previewInvite(code: any(named: 'code')))
          .thenThrow(Exception('Invalid or expired invite'));
      await openPage(tester, buildApp());

      await submitCode(tester, 'ABC234');

      expect(find.text('邀请码无效或已过期,请向邀请人索取新码'), findsOneWidget);
      // 仍停留在输入卡片
      expect(find.text('验证邀请码'), findsOneWidget);
    });

    testWidgets('预览后点取消：回到输入卡片', (tester) async {
      await openPage(tester, buildApp());

      await submitCode(tester, 'ABC234');
      expect(find.text('加入账本'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('验证邀请码'), findsOneWidget);
      expect(find.text('加入账本'), findsNothing);
    });

    testWidgets('prefilledCode 自动规范化并预览', (tester) async {
      await tester.pumpWidget(buildApp(prefilledCode: 'abc-234'));
      await tester.tap(find.text('open-join'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      // post-frame 自动触发预览，输入卡片已被预览卡片替换
      expect(find.text('小明 邀请你加入'), findsOneWidget);
      verify(() => backend.previewInvite(code: 'ABC234')).called(1);
    });
  });

  group('接受邀请', () {
    testWidgets('接受成功：toast 提示并携带 true 返回', (tester) async {
      await openPage(tester, buildApp());
      await submitCode(tester, 'ABC234');

      await tester.tap(find.text('加入账本'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('已加入「家庭账本」'), findsOneWidget);
      expect(find.text('open-join'), findsOneWidget, reason: '页面已 pop 回宿主');
      verify(() => backend.acceptInvite(code: 'ABC234')).called(1);
      verify(() => engine.onInviteAccepted('ledger-ext-1')).called(1);
      await tester.pump(const Duration(seconds: 2)); // toast 定时器
    });

    testWidgets('已是成员：展示对应错误文案', (tester) async {
      when(() => backend.acceptInvite(code: any(named: 'code')))
          .thenThrow(Exception('Already a member'));
      await openPage(tester, buildApp());
      await submitCode(tester, 'ABC234');

      await tester.tap(find.text('加入账本'));
      await tester.pumpAndSettle();

      expect(find.text('你已经是该账本成员'), findsOneWidget);
      // 未 pop，仍在预览卡片
      expect(find.text('加入账本'), findsOneWidget);
    });

    testWidgets('预览无有效期：按无效处理并展示提示', (tester) async {
      when(() => backend.previewInvite(code: any(named: 'code')))
          .thenAnswer((_) async => previewFixture(nullExpiry: true));
      await openPage(tester, buildApp());

      await submitCode(tester, 'ABC234');

      expect(find.text('邀请码无效或已过期,请向邀请人索取新码'), findsOneWidget);
    });

    testWidgets('有效期不足 1 小时：按分钟展示', (tester) async {
      when(() => backend.previewInvite(code: any(named: 'code')))
          .thenAnswer((_) async => previewFixture(
                // 加 1 分钟缓冲，保证断言时仍在 30 分钟档
                expiresAt:
                    DateTime.now().toUtc().add(const Duration(minutes: 31)),
              ));
      await openPage(tester, buildApp());

      await submitCode(tester, 'ABC234');

      expect(find.textContaining('有效期还剩 30 分钟'), findsOneWidget);
    });

    testWidgets('owner 角色与超 24 小时有效期文案', (tester) async {
      when(() => backend.previewInvite(code: any(named: 'code')))
          .thenAnswer((_) async => previewFixture(
                role: 'owner',
                // 加 1 小时缓冲，保证断言时仍在 3 天档
                expiresAt:
                    DateTime.now().toUtc().add(const Duration(days: 3, hours: 1)),
              ));
      await openPage(tester, buildApp());

      await submitCode(tester, 'ABC234');

      expect(find.text('角色:所有者'), findsOneWidget);
      expect(find.textContaining('有效期还剩 3 天'), findsOneWidget);
    });
  });
}
