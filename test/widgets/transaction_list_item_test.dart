/// TransactionListItem 第二行时间展示测试。
///
/// 锁定:HH:mm(或完整日期)在共享/非共享账本均展示,isShared 只决定是否渲染
/// 协作头像。本地账本(isShared=false)必须能看到记录时分。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/models.dart' show Ledger;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart'
    show currentLedgerProvider, spitoutCloudProviderInstance;
import 'package:spitout/widgets/collaborator_avatar.dart';
import 'package:spitout/widgets/transaction_list_item.dart';

import '../helpers/test_isolation.dart';

/// 渲染单个列表项。
///
/// [overrides] 供共享账本用例追加 spitoutCloudProviderInstance 之外的桩;
/// currentLedgerProvider 在此统一 override:AmountText 在 currencyCode == null
/// 时会 watch 它,而其内部依赖 repositoryProvider → databaseProvider(真实
/// SpitoutDatabase,构造即走 path_provider 平台通道)。测试环境无平台通道,
/// 不拦掉整条链 pumpWidget 会因 MissingPluginException 崩溃。
Future<void> _pump(
  WidgetTester tester,
  TransactionListItem item, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentLedgerProvider.overrideWith(
          (ref) => Stream<Ledger?>.value(null),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: item),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetGlobalTestState();
  });

  testWidgets('本地账本(isShared=false)显示 HH:mm 时间且不渲染协作头像',
      (tester) async {
    await _pump(
      tester,
      TransactionListItem(
        icon: Icons.circle,
        title: '早餐',
        amount: 12,
        isExpense: true,
        happenedAt: DateTime(2026, 1, 1, 8, 30),
        isShared: false,
      ),
    );

    expect(find.text('08:30'), findsOneWidget);
    expect(find.byType(CollaboratorAvatarGroup), findsNothing);
  });

  testWidgets('本地账本 showFullDate 模式显示完整日期', (tester) async {
    await _pump(
      tester,
      TransactionListItem(
        icon: Icons.circle,
        title: '早餐',
        amount: 12,
        isExpense: true,
        happenedAt: DateTime(2026, 1, 1, 8, 30),
        showFullDate: true,
        isShared: false,
      ),
    );

    expect(find.text('2026-01-01 08:30'), findsOneWidget);
  });

  testWidgets('本地账本零点交易(00:00:00)不显示时间', (tester) async {
    await _pump(
      tester,
      TransactionListItem(
        icon: Icons.circle,
        title: '早餐',
        amount: 12,
        isExpense: true,
        happenedAt: DateTime(2026, 1, 1),
        isShared: false,
      ),
    );

    expect(find.text('00:00'), findsNothing);
  });

  testWidgets('共享账本(isShared=true)同时显示时间与协作头像', (tester) async {
    await _pump(
      tester,
      TransactionListItem(
        icon: Icons.circle,
        title: '早餐',
        amount: 12,
        isExpense: true,
        happenedAt: DateTime(2026, 1, 1, 8, 30),
        // 头像组要求至少有一个协作者 userId,否则内部直接 shrink
        creatorUserId: 'u1',
        editorUserId: 'u1',
        collaboratorMap: const {},
        isShared: true,
      ),
      overrides: [
        // 云客户端桩:避免真实 SpitoutCloudProvider 走网络/安全存储
        spitoutCloudProviderInstance.overrideWith((ref) async => null),
      ],
    );

    expect(find.text('08:30'), findsOneWidget);
    expect(find.byType(CollaboratorAvatarGroup), findsOneWidget);
  });

  testWidgets('lastEditedAt 优先于 happenedAt 展示', (tester) async {
    await _pump(
      tester,
      TransactionListItem(
        icon: Icons.circle,
        title: '早餐',
        amount: 12,
        isExpense: true,
        happenedAt: DateTime(2026, 1, 1, 8, 30),
        lastEditedAt: DateTime(2026, 1, 2, 21, 5),
        isShared: false,
      ),
    );

    expect(find.text('21:05'), findsOneWidget);
    expect(find.text('08:30'), findsNothing);
  });
}
