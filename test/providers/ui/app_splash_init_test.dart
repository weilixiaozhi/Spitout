// appSplashInitProvider 启动预加载流程测试。
//
// 需求锚点：
//   1. 依次完成基础配置初始化（主题/应用锁/显示名/可见币种等）；
//   2. 按当前账本预加载月度统计与最近交易，并写入缓存 provider；
//   3. 完成后切换 appInitState 为 ready；任一步失败不阻断完成。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/cloud/sync/sync_service.dart' show LocalOnlySyncService;
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/providers/providers.dart';

class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;

  setUp(() {
    resetGlobalTestState();
    repo = _MockRepo();
    // 跳过一次性历史修复，避免依赖真实 DB。
    SharedPreferences.setMockInitialValues({
      'shared_ledger_category_repair_v1_done': true,
      'local_identity_repair_v1_done': true,
    });

    when(() => repo.getAllLedgers()).thenAnswer((_) async => <db.Ledger>[]);
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(
      () => repo.monthlyTotals(
        ledgerId: any(named: 'ledgerId'),
        month: any(named: 'month'),
      ),
    ).thenAnswer((_) async => 0.0);
    when(
      () => repo.getRecentTransactionsWithCategory(
        ledgerId: any(named: 'ledgerId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <({db.Transaction t, db.Category? category})>[]);
    when(
      () => repo.getCountsForLedger(ledgerId: any(named: 'ledgerId')),
    ).thenAnswer((_) async => (dayCount: 0, txCount: 0));
  });

  test('预加载完成并切换到 ready', () async {
    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider.overrideWith(
          (ref) => Stream<db.Ledger?>.value(null),
        ),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appInitStateProvider), AppInitState.splash);

    await readProviderFutureFromContainer(
      container,
      appSplashInitProvider.future,
    );
    // 让 fire-and-forget 微任务（统计/周期生成）跑完。
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();

    expect(container.read(appInitStateProvider), AppInitState.ready);
    verify(
      () => repo.getRecentTransactionsWithCategory(
        ledgerId: 0,
        limit: 20,
      ),
    ).called(1);
  });

  test('基础 provider 异常不阻断 ready', () async {
    when(
      () => repo.monthlyTotals(
        ledgerId: any(named: 'ledgerId'),
        month: any(named: 'month'),
      ),
    ).thenThrow(Exception('db down'));

    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider.overrideWith(
          (ref) => Stream<db.Ledger?>.value(null),
        ),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      ],
    );
    addTearDown(container.dispose);

    await readProviderFutureFromContainer(
      container,
      appSplashInitProvider.future,
    );
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();

    expect(container.read(appInitStateProvider), AppInitState.ready,
        reason: '预加载失败也要切换主应用，不卡启动');
    await logger.clear();
  });
}
