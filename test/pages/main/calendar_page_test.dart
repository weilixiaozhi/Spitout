/// 日历页组件测试。
///
/// 需求期望：
/// 1. 进入日历页自动选中今天（当天交易列表直接可见）；
/// 2. 任何路径写入数据后，日历当日列表自动刷新（不依赖手动 tick）；
/// 3. 切到其他月后选中态清空，回到本月自动重新选中今天；
/// 4. 重新进入日历 tab 且无选中时，自动选中今天。
///
/// 说明：
/// - 整个文件共享同一个内存数据库，避免同一进程内第二个 drift 实例的
///   tableUpdates 流不可靠，保证随机测试顺序下行为一致；
/// - 切月用日历头部箭头按钮（确定性点击），不用手势 fling。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/calendar/calendar_page.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/ui/avatar_providers.dart';
import 'package:spitout/providers/ui/ui_state_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUpAll(() async {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await repo.createLedger(
      name: '测试账本',
      storageMode: 'local',
      ownerUserId: 'u1',
    );
  });

  tearDownAll(() async => db.close());

  /// 轮询 pump 直到 Finder 命中（日历骨架含 PulseSkeleton 持续动画，禁用 pumpAndSettle）。
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.elementList(finder).isNotEmpty) return;
    }
    fail('pumpUntilFound: $finder 在超时内未出现');
  }

  Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.elementList(finder).isEmpty) return;
    }
    fail('pumpUntilGone: $finder 在超时内未消失');
  }

  /// 点击日历头部箭头切月，并等待翻页完成。
  Future<void> tapChevron(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// 卸载整棵树并冲刷 drift 流取消时产生的 0 毫秒 Timer，
  /// 避免 flutter_test 判定「仍有 pending timer」而挂起。
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          currentLedgerIdProvider.overrideWith(
            () => SimpleStateNotifier<int>((ref) => 1),
          ),
          spitoutCloudProviderInstance.overrideWith((ref) async => null),
          avatarPathProvider.overrideWith((ref) async => null),
          localSelfIdProvider.overrideWith((ref) async => 'local-self'),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalendarPage(),
        ),
      ),
    );
  }

  testWidgets('进入日历自动选中今天；直接写库后当日列表自动刷新；回到本月自动重新选中今天', (
    tester,
  ) async {
    await pumpCalendar(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CalendarPage)),
    );
    final addTxFinder = find.text(l10n.calendarAddTransaction);

    // 1) 进入页面自动选中今天：当天交易列表的“在该日记账”按钮直接可见。
    await pumpUntilFound(tester, addTxFinder);

    // 2) 绕过 UI/手动 tick 直接写库，当日列表应自动刷新出新交易。
    final now = DateTime.now();
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 1234,
      happenedAt: now,
      note: '自动刷新验证',
    );
    await pumpUntilFound(tester, find.text('自动刷新验证'));

    // 3) 切到下一月：选中态清空，当天列表隐藏。
    await tapChevron(tester, AppIcons.chevronRight);
    await pumpUntilGone(tester, addTxFinder);

    // 4) 切回本月：自动重新选中今天，列表恢复。
    await tapChevron(tester, AppIcons.chevronLeft);
    await pumpUntilFound(tester, addTxFinder);

    await disposeTree(tester);
  });

  testWidgets('重新进入日历 tab 且无选中日期时，自动选中今天', (tester) async {
    await pumpCalendar(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CalendarPage)),
    );
    final addTxFinder = find.text(l10n.calendarAddTransaction);
    await pumpUntilFound(tester, addTxFinder);

    // 先切到下一月清空选中态。
    await tapChevron(tester, AppIcons.chevronRight);
    await pumpUntilGone(tester, addTxFinder);

    // 模拟先切走再切回日历 tab。
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CalendarPage)),
      listen: false,
    );
    container.read(bottomTabIndexProvider.notifier).set(1);
    await tester.pump();
    container.read(bottomTabIndexProvider.notifier).set(2);

    // 重新进入后应自动回到本月并选中今天。
    await pumpUntilFound(tester, addTxFinder);

    await disposeTree(tester);
  });
}
