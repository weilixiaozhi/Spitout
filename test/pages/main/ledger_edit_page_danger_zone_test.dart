import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/ledger_edit_page.dart';
import 'package:spitout/providers/providers.dart';

import '../../helpers/test_isolation.dart';

/// [LedgerEditPage] 右上角「更多」菜单的「角色门控」widget 测试。
///
/// 敏感操作（清空 / 删除共享账本 / 退出并删除 / 删除账本）账本编辑页右上角 [_buildMoreMenu]（SpitoutPopupMenu），
/// 菜单项按角色动态生成。本测试验证菜单只展示当前角色应有的危险项，
/// 避免越权操作入口：
///   - Owner 共享账本 → 仅「删除共享账本」；
///   - 协作者共享账本 → 仅「退出并删除」；
///   - 本地（非共享）账本 → 仅「删除账本」（全局删除:远端+本地+待推送变更）。
///
/// 说明：activeCloudConfig 覆盖为 local 类型,使「共享成员列表」分支早退,
/// 避免触发真实云成员接口；菜单渲染只依赖 widget.ledger 的字段。
void main() {
  late SpitoutDatabase db;
  late LocalRepository repo;
  late ChangeTracker tracker;

  setUp(() {
    resetGlobalTestState();
    TestWidgetsFlutterBinding.ensureInitialized();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
  });

  tearDown(() => db.close());

  Future<LedgerDisplayItem> seed(String extId, bool isShared, String myRole) async {
    final localId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L-$extId',
            syncId: isShared ? Value(extId) : const Value.absent(),
            isShared: Value(isShared),
            myRole: Value(myRole),
          ),
        );
    return LedgerDisplayItem.fromLocal(
      id: localId,
      name: 'L-$extId',
      currency: 'CNY',
      createdAt: DateTime.now(),
      transactionCount: 0,
      expenseTotal: 0,
      isShared: isShared,
      memberCount: isShared ? 2 : 1,
      myRole: myRole,
    );
  }

  Future<AppLocalizations> pump(WidgetTester tester, LedgerDisplayItem ledger) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) => repo),
            currentLedgerProvider
                .overrideWith((ref) => Stream<Ledger?>.value(null)),
            activeCloudConfigProvider.overrideWith((ref) async =>
                const CloudServiceConfig(
                  type: CloudBackendType.local,
                  name: 'Local',
                )),
          ],
          child: LedgerEditPage(ledger: ledger),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 编辑页读取 localSelfIdProvider 时首次生成会写日志并调度 2s 节流保存
    // Timer，测试结束前推进虚拟时钟让 Timer 到期，避免 !timersPending 报错。
    await tester.pump(const Duration(seconds: 3));
    return l10n;
  }

  // 展开右上角「更多」菜单：SpitoutPopupMenu 内部是 PopupMenuButton<String>，
  // 点击其省略号图标后，菜单项文本才会出现在 widget 树中，供下方断言使用。
  Future<void> openMoreMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
  }

  testWidgets('Owner 共享账本 → 菜单含「删除共享账本」,不含「退出并删除」',
      (tester) async {
    final ledger = await seed('ext-owner', true, 'owner');
    final l10n = await pump(tester, ledger);
    await openMoreMenu(tester);
    expect(find.text(l10n.ledgersDeleteShared), findsOneWidget);
    expect(find.text(l10n.ledgersLeaveAndDelete), findsNothing);
  });

  testWidgets('协作者共享账本 → 菜单含「退出并删除」,不含「删除共享账本」',
      (tester) async {
    final ledger = await seed('ext-editor', true, 'editor');
    final l10n = await pump(tester, ledger);
    await openMoreMenu(tester);
    expect(find.text(l10n.ledgersLeaveAndDelete), findsOneWidget);
    expect(find.text(l10n.ledgersDeleteShared), findsNothing);
  });

  testWidgets('本地（非共享）账本 → 菜单含「删除账本」,不含共享按钮',
      (tester) async {
    // myRole 用 'owner':个人账本删除按钮的门控条件为 !isShared,
    // 这里保持模型默认角色语义（非共享账本恒为 owner）。
    final ledger = await seed('local-1', false, 'owner');
    final l10n = await pump(tester, ledger);
    await openMoreMenu(tester);
    expect(find.text(l10n.ledgersDelete), findsOneWidget);
    expect(find.text(l10n.ledgersDeleteShared), findsNothing);
    expect(find.text(l10n.ledgersLeaveAndDelete), findsNothing);
  });
}
