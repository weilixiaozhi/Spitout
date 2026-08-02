/// MemberManagementSection 内嵌邀请模块 widget 测试。
///
/// 「邀请新成员」模块内嵌在成员管理模块的成员列表下方,
/// 只有 Owner 可见。本测试锁定以下行为:
/// - Owner 视角:成员列表下方渲染邀请模块,默认收起只显示标题,
///   点击标题展开后展示角色/有效期 chip 与生成按钮,且无跳转箭头;
/// - 协作者视角:整个邀请模块不渲染;
/// - 云端未配置时点「生成邀请码」内联展示错误文案(不跳页、不崩溃)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/member_management_section.dart';

/// Mock SyncEngine：只 stub pushUserGlobalEntities 的成败行为。
class _MockSyncEngine extends Mock implements SyncEngine {}

/// 构造成员桩数据 — 只填测试关心的字段,其余给固定值。
SpitoutCloudLedgerMember _member({
  required String userId,
  required String role,
  required bool isSelf,
}) =>
    SpitoutCloudLedgerMember(
      userId: userId,
      email: '$userId@example.com',
      role: role,
      joinedAt: DateTime.utc(2026, 1, 1),
      isSelf: isSelf,
    );

/// 挂载 MemberManagementSection:
/// - ledgerMembersProvider 直接注入桩成员列表,避免触网;
/// - spitoutCloudProviderInstance 置 null(头像走首字母 fallback,
///   生成邀请码走「云端未配置」错误分支);
/// - 模块自身不带滚动与 Scaffold,测试用 SingleChildScrollView 包裹补齐。
Future<void> _pump(
  WidgetTester tester, {
  required List<SpitoutCloudLedgerMember> members,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ledgerMembersProvider.overrideWith((ref, ledgerId) async => members),
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MemberManagementSection(
              ledgerExternalId: 'ext-1',
              ledgerName: '测试账本',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Owner 可见内嵌邀请模块:默认收起 + 点击展开后显示表单 + 无跳转箭头',
      (tester) async {
    await _pump(tester, members: [
      _member(userId: 'u1', role: 'owner', isSelf: true),
      _member(userId: 'u2', role: 'editor', isSelf: false),
    ]);

    // 默认收起:模块标题沿用「邀请新成员」文案,表单不可见
    expect(find.text('邀请新成员'), findsOneWidget);
    expect(find.text('角色'), findsNothing);
    expect(find.text('有效期'), findsNothing);
    expect(find.text('生成邀请码'), findsNothing);

    // 点击标题展开:角色 / 有效期 / 生成按钮直接可见,无需跳页
    await tester.tap(find.text('邀请新成员'));
    await tester.pumpAndSettle();
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('有效期'), findsOneWidget);
    expect(find.text('生成邀请码'), findsOneWidget);
    // 1 个角色 chip + 3 个有效期 chip
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    // 模块内无跳转箭头(chevronRight)
    expect(find.byIcon(AppIcons.chevronRight), findsNothing);
  });

  testWidgets('协作者不可见邀请模块', (tester) async {
    await _pump(tester, members: [
      _member(userId: 'u1', role: 'owner', isSelf: false),
      _member(userId: 'u2', role: 'editor', isSelf: true),
    ]);

    expect(find.text('邀请新成员'), findsNothing);
    expect(find.text('生成邀请码'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('云端未配置时点「生成邀请码」内联显示错误', (tester) async {
    await _pump(tester, members: [
      _member(userId: 'u1', role: 'owner', isSelf: true),
    ]);

    // 默认收起,先点击标题展开表单
    await tester.tap(find.text('邀请新成员'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('生成邀请码'));
    await tester.tap(find.text('生成邀请码'));
    await tester.pumpAndSettle();

    // createInviteAndRefresh 在 cloud == null 时抛 StateError,
    // 错误必须内联展示在模块内,而不是静默或崩溃
    expect(
      find.textContaining('Spitout Cloud not configured'),
      findsOneWidget,
    );
  });

  testWidgets('发邀请前分类上云重试仍失败：内联显示本地化友好提示', (tester) async {
    // 防线 A：pushUserGlobalEntities 连续失败（含重试一次）→ 阻断邀请,
    // 错误对用户必须可读（本地化文案），而不是原始异常堆栈。
    final engine = _MockSyncEngine();
    when(() => engine.pushUserGlobalEntities())
        .thenAnswer((_) async => throw Exception('push boom'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerMembersProvider.overrideWith((ref, ledgerId) async =>
              [_member(userId: 'u1', role: 'owner', isSelf: true)]),
          spitoutCloudProviderInstance
              .overrideWith((ref) async => FakeSpitoutCloudProvider()),
          syncEngineProvider.overrideWith((ref, arg) => engine),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberManagementSection(
                ledgerExternalId: 'ext-1',
                ledgerName: '测试账本',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认收起,先点击标题展开表单
    await tester.tap(find.text('邀请新成员'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('生成邀请码'));
    await tester.tap(find.text('生成邀请码'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.categorySyncFailedBeforeInvite), findsOneWidget);
    // 首次失败 + 重试一次：pushUserGlobalEntities 共调用 2 次
    verify(() => engine.pushUserGlobalEntities()).called(2);

    // 失败日志的 LoggerService debounce 定时器推进掉，避免 pending timer
    await tester.pump(const Duration(seconds: 3));
  });
}
