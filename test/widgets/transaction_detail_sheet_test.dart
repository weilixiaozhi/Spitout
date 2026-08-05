/// 记录详情 Bottom Sheet 展示名四级兜底测试。
///
/// 锁定:共享账本成员表(昵称 → 完整邮箱) → 本地昵称 → 原始 id 的兜底顺序;
/// 本地账本(无成员表)只要设置了本地昵称就必须显示昵称而非 id,与云端登录态无关。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudLedgerMember;
import 'package:spitout/data/db.dart' show LedgerVirtualUser;
import 'package:spitout/data/models.dart'
    show Ledger, RecordEditHistory, Transaction;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart'
    show currentLedgerProvider, ledgerVirtualUsersProvider;
import 'package:spitout/providers/statistics/record_history_providers.dart'
    show recordEditHistoryProvider;
import 'package:spitout/widgets/transaction_detail_sheet.dart';

import '../helpers/test_isolation.dart';

/// 渲染一个触发按钮并弹出详情 sheet。
///
/// [memberDisplayMap] / [localOwnerDisplayName] 直接透传给详情 sheet;
/// currentLedgerProvider 统一 override:详情 sheet 的 AA 区块与 AmountText
/// (currencyCode==null 时)会 watch 它,而它内部依赖 repositoryProvider →
/// databaseProvider(真实 SpitoutDatabase,构造即走 path_provider 平台通道),
/// 测试环境无平台通道,不拦掉整条链 pumpWidget 会因 MissingPluginException 崩溃。
/// recordEditHistoryProvider 同理,它内部走 repositoryProvider 查询编辑历史。
Future<void> _openSheet(
  WidgetTester tester, {
  required Transaction transaction,
  Map<String, SpitoutCloudLedgerMember> memberDisplayMap = const {},
  String? localOwnerDisplayName,
  bool aaEnabled = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentLedgerProvider.overrideWith(
          (ref) => Stream<Ledger?>.value(null),
        ),
        recordEditHistoryProvider.overrideWith(
          (ref, recordId) async => const <RecordEditHistory>[],
        ),
        // 详情 sheet 常驻 watch 虚拟用户列表（drift 流）；测试环境无真实数据库，
        // 必须 override，否则构造真实链会在 dispose 时留下 drift 的 0ms 定时器。
        ledgerVirtualUsersProvider.overrideWith(
          (ref, ledgerId) =>
              Stream<List<LedgerVirtualUser>>.value(const []),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showTransactionDetailSheet(
                  context: context,
                  transaction: transaction,
                  category: null,
                  memberDisplayMap: memberDisplayMap,
                  localOwnerDisplayName: localOwnerDisplayName,
                  aaEnabled: aaEnabled,
                  onEdit: () async {},
                  onEditAa: () async {},
                  onDelete: () async {},
                ),
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开详情'));
  await tester.pumpAndSettle();
  // 触发日志服务的 2 秒节流保存定时器:sheet 读取 localSelfIdProvider 时
  // 首次生成会写日志并调度 Timer,测试结束前不触发会报 !timersPending。
  await tester.pump(const Duration(seconds: 3));
}

/// 构造带创建人/编辑人的交易。
Transaction _transaction({
  String? createdByUserId = 'u_creator',
  String? lastEditedByUserId = 'u_editor',
}) {
  return Transaction(
    id: 1,
    ledgerId: 1,
    type: 'expense',
    amount: 1200,
    happenedAt: DateTime(2026, 1, 1, 8, 30),
    excludeFromStats: false,
    version: 1,
    createdByUserId: createdByUserId,
    lastEditedByUserId: lastEditedByUserId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetGlobalTestState();
  });

  testWidgets('本地账本 + 已设置昵称:创建人/编辑人显示昵称而非 id',
      (tester) async {
    await _openSheet(
      tester,
      transaction: _transaction(),
      localOwnerDisplayName: '本地昵称',
    );

    // 昵称出现两次(创建人 + 编辑人),id 不应出现
    expect(find.text('本地昵称'), findsNWidgets(2));
    expect(find.text('u_creator'), findsNothing);
    expect(find.text('u_editor'), findsNothing);
  });

  testWidgets('本地账本 + 未设置昵称:回退显示 id', (tester) async {
    await _openSheet(
      tester,
      transaction: _transaction(),
      localOwnerDisplayName: '',
    );

    expect(find.text('u_creator'), findsOneWidget);
    expect(find.text('u_editor'), findsOneWidget);
  });

  testWidgets('共享账本:成员表命中时优先展示成员 displayName', (tester) async {
    await _openSheet(
      tester,
      transaction: _transaction(
        createdByUserId: 'u_cloud',
        lastEditedByUserId: 'u_cloud',
      ),
      memberDisplayMap: {
        'u_cloud': SpitoutCloudLedgerMember(
          userId: 'u_cloud',
          email: 'cloud@example.com',
          role: 'owner',
          joinedAt: DateTime.utc(2026, 1, 1),
          isSelf: true,
          displayName: '云端昵称',
        ),
      },
      // 共享账本调用方按约定传 null;即使传了本地昵称,成员表优先级也应更高
      localOwnerDisplayName: '本地昵称',
    );

    expect(find.text('云端昵称'), findsNWidgets(2));
    expect(find.text('本地昵称'), findsNothing);
    expect(find.text('u_cloud'), findsNothing);
  });

  testWidgets('共享账本:成员表未命中(无 displayName)回退到本地昵称/id',
      (tester) async {
    await _openSheet(
      tester,
      transaction: _transaction(),
      memberDisplayMap: {
        'u_creator': SpitoutCloudLedgerMember(
          userId: 'u_creator',
          email: 'creator@example.com',
          role: 'editor',
          joinedAt: DateTime.utc(2026, 1, 1),
          isSelf: false,
          displayName: null,
        ),
      },
      localOwnerDisplayName: '本地昵称',
    );

    // u_creator 在成员表但 displayName 为空 → 展示完整邮箱;u_editor 不在成员表 → 本地昵称
    expect(find.text('本地昵称'), findsOneWidget);
    expect(find.text('creator@example.com'), findsOneWidget);
    expect(find.text('u_creator'), findsNothing);
    expect(find.text('u_editor'), findsNothing);
  });

  testWidgets('创建人/编辑人为空时不渲染协作成员区块', (tester) async {
    await _openSheet(
      tester,
      transaction: _transaction(
        createdByUserId: null,
        lastEditedByUserId: null,
      ),
      localOwnerDisplayName: '本地昵称',
    );

    expect(find.text('本地昵称'), findsNothing);
  });

  testWidgets('未开启分摊:底部仅常驻「编辑记账」单按钮,右上角有删除 icon',
      (tester) async {
    await _openSheet(
      tester,
      transaction: _transaction(),
      localOwnerDisplayName: '本地昵称',
      aaEnabled: false,
    );

    // sheet 内容可能超出测试 viewport,滚动到底部让 footer(底部按钮)可见
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // 仅 1 个「编辑」按钮(底部 footer)
    expect(find.text('编辑记账'), findsOneWidget);
    // 「编辑分摊」按钮不出现(账本未开启分摊)
    expect(find.text('编辑分摊'), findsNothing);
    // 删除 icon 在右上角(trailing):IconButton 1 个。
    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets('开启分摊:底部常驻「编辑分摊(左)+ 编辑记账(右)」双按钮',
      (tester) async {
    await _openSheet(
      tester,
      transaction: _transaction(),
      localOwnerDisplayName: '本地昵称',
      aaEnabled: true,
    );

    // 滚动到底部让双按钮 footer 可见
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    // 双按钮同时出现:左「编辑分摊」、右「编辑记账」
    expect(find.text('编辑分摊'), findsOneWidget);
    expect(find.text('编辑记账'), findsOneWidget);
    // 删除 icon 仍在右上角(trailing):IconButton 1 个。
    expect(find.byType(IconButton), findsOneWidget);
  });
}
