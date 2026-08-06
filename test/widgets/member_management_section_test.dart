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
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/data/db.dart' show LedgerVirtualUser;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import 'package:spitout/providers/providers.dart' show ledgerVirtualUsersProvider;
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/member_management_section.dart';
import 'package:spitout/widgets/text_state_switch.dart';

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
      account: '$userId@example.com',
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
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MemberManagementSection(
              ledgerExternalId: 'ext-1',
              ledgerName: '测试账本',
              ledgerId: null,
              aaEnabled: false,
              onAaChanged: (_) {},
              isReadOnly: false,
              pendingVirtualUsers: const [],
              onPendingVirtualUsersChanged: (_) {},
              showInviteEntry: true,
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
    // 收起态箭头朝右(chevronRight)
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
    expect(find.byIcon(AppIcons.chevronDown), findsNothing);

    // 点击标题展开:角色 / 有效期 / 生成按钮直接可见,无需跳页
    await tester.tap(find.text('邀请新成员'));
    await tester.pumpAndSettle();
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('有效期'), findsOneWidget);
    expect(find.text('生成邀请码'), findsOneWidget);
    // 1 个角色 chip + 3 个有效期 chip
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    // 展开态箭头朝下(chevronDown),不再有朝右箭头
    expect(find.byIcon(AppIcons.chevronDown), findsOneWidget);
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
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberManagementSection(
                ledgerExternalId: 'ext-1',
                ledgerName: '测试账本',
                ledgerId: null,
                aaEnabled: false,
                onAaChanged: (_) {},
                isReadOnly: false,
                pendingVirtualUsers: const [],
                onPendingVirtualUsersChanged: (_) {},
                showInviteEntry: true,
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

  testWidgets('本地账本(showInviteEntry=false)不渲染邀请新成员入口', (tester) async {
    // 本地账本不支持协作邀请:点击会因同步层不会创建 syncId 而陷入永久 loading,
    // 故 showInviteEntry=false 时整个邀请模块不应渲染。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spitoutCloudProviderInstance.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberManagementSection(
                // 无 syncId 模拟本地账本
                ledgerExternalId: null,
                ledgerName: '本地账本',
                ledgerId: 1,
                aaEnabled: false,
                onAaChanged: (_) {},
                isReadOnly: false,
                pendingVirtualUsers: const [],
                onPendingVirtualUsersChanged: (_) {},
                // 本地账本不展示邀请入口
                showInviteEntry: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 成员管理标题常驻显示,但邀请新成员入口不渲染
    expect(find.text('成员管理'), findsOneWidget);
    expect(find.text('邀请新成员'), findsNothing);
    expect(find.text('生成邀请码'), findsNothing);
  });

  testWidgets('虚拟用户行编辑输入在父级重建后保留', (tester) async {
    final vu = LedgerVirtualUser(
      id: 1,
      ledgerId: 1,
      syncId: 'vu-1',
      name: '虚拟用户1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerVirtualUsersProvider.overrideWith(
            (ref, ledgerId) =>
                Stream<List<LedgerVirtualUser>>.value([vu]),
          ),
          ledgerMembersProvider.overrideWith(
            (ref, ledgerId) async =>
                [_member(userId: 'u1', role: 'owner', isSelf: true)],
          ),
          spitoutCloudProviderInstance.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberManagementSection(
                ledgerExternalId: 'ext-1',
                ledgerName: '测试账本',
                ledgerId: 1,
                aaEnabled: true,
                onAaChanged: (_) {},
                isReadOnly: false,
                pendingVirtualUsers: const [],
                onPendingVirtualUsersChanged: (_) {},
                showInviteEntry: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('虚拟用户1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '新名字');
    await tester.pump();

    // 展开邀请区触发成员管理整棵子树 setState 重建：
    // State 持有的 controller 必须保留正在编辑但未失焦的内容。
    await tester.tap(find.text('邀请新成员'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '新名字',
        reason: '父级重建后行内编辑输入不应丢失');
  });

  testWidgets('AA 分摊开关位于成员管理标题行(文字+开关)', (tester) async {
    // AA 开关不再作为卡片内 SwitchListTile,而是并入标题行(文字+紧凑 Switch)。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spitoutCloudProviderInstance.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberManagementSection(
                ledgerExternalId: null,
                ledgerName: '测试账本',
                ledgerId: 1,
                aaEnabled: false,
                onAaChanged: (_) {},
                isReadOnly: false,
                pendingVirtualUsers: const [],
                onPendingVirtualUsersChanged: (_) {},
                showInviteEntry: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AA 分摊开关与「成员管理」标题同处一行:开关内嵌状态文案
    // (aaEnabled=false 显示「关闭AA分摊」),无独立的"AA 分摊"标题文本。
    expect(find.text('成员管理'), findsOneWidget);
    expect(find.text('关闭AA分摊'), findsOneWidget);
    // 开关已是轨道内带状态文案的 TextStateSwitch,不再是系统 Switch
    expect(find.byType(TextStateSwitch), findsOneWidget);
    // 不再使用 SwitchListTile(卡片内独立一行)
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
