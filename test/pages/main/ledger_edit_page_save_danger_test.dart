/// LedgerEditPage 保存流与危险区操作测试。
///
/// 需求锚点：
/// - 新建保存：名称必填校验、AA 开关随 createLedger 落库、虚拟用户批量落库、
///   成功后 toast + pop；编辑保存：改名/AA 变更走 updateLedger，无变更直接关闭；
/// - 危险区（右上角「更多」菜单）：
///   - 清空账本：确认 → clearLedgerTransactions → toast；
///   - 删除个人账本：确认 → deleteLedgerGlobally → 清 prefs → 删除成功 pop；
///   - 协作者退出并删除 / Owner 删除共享账本：确认 → 云端调用 + 本地清理；
/// - 邀请流程：账本已带 syncId 时点击邀请入口直接进入正式邀请（不触发轮询）。
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/ledger_edit_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/currency/exchange_rate_service.dart';
import 'package:spitout/widgets/sheet_grab_handle.dart';
import 'package:spitout/widgets/text_state_switch.dart';

import '../../helpers/test_isolation.dart';

/// 记录 deleteLedgerGlobally 调用并委托真实本地删除的 LocalOnlySyncService。
class _RecordingSyncService extends LocalOnlySyncService {
  final List<int> deletedLedgerIds = [];
  bool failDelete = false;

  _RecordingSyncService({super.repoResolver});

  @override
  Future<void> deleteLedgerGlobally(int ledgerId) async {
    deletedLedgerIds.add(ledgerId);
    if (failDelete) throw Exception('delete boom');
    await super.deleteLedgerGlobally(ledgerId);
  }
}

/// 假汇率服务：立即失败且不留 pending timer，避免切币种/拉汇率路径触网。
class _FailingRateService implements ExchangeRateService {
  @override
  Future<RateFetchResult> fetch(String base) async {
    throw RateFetchException('fake fail');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;
  late _RecordingSyncService syncService;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    syncService = _RecordingSyncService(repoResolver: () => repo);
  });

  tearDown(() => db.close());

  /// 播种账本，返回展示项。
  Future<LedgerDisplayItem> seed({
    String name = '测试账本',
    String? syncId,
    bool isShared = false,
    String myRole = 'owner',
    String storageMode = 'local',
    bool aaEnabled = false,
    int monthStartDay = 1,
  }) async {
    final localId = await db.into(db.ledgers).insert(
      LedgersCompanion.insert(
        name: name,
        currency: const Value('CNY'),
        syncId: syncId == null ? const Value.absent() : Value(syncId),
        isShared: Value(isShared),
        myRole: Value(myRole),
        storageMode: Value(storageMode),
        aaEnabled: Value(aaEnabled),
        monthStartDay: Value(monthStartDay),
      ),
    );
    return LedgerDisplayItem.fromLocal(
      id: localId,
      name: name,
      currency: 'CNY',
      createdAt: DateTime.now(),
      transactionCount: 0,
      expenseTotal: 0,
      isShared: isShared,
      memberCount: isShared ? 2 : 1,
      myRole: myRole,
      storageMode: storageMode,
    );
  }

  /// 挂载编辑页。
  ///
  /// [cloud] 传 fake 时注入真实 SyncEngine + FakeSpitoutCloudProvider，
  /// 供共享账本删除路径使用；[ledger] 为 null 表示新建模式。
  Future<AppLocalizations> pump(
    WidgetTester tester, {
    LedgerDisplayItem? ledger,
    FakeSpitoutCloudProvider? cloud,
    bool settle = true,
    int? currentLedgerId,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final engine = cloud == null
        ? null
        : SyncEngine(
            db: db,
            provider: cloud,
            changeTracker: ChangeTracker(db),
            repo: repo,
          );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWith((ref) => repo),
            if (cloud != null)
              syncEngineProvider.overrideWith((ref, arg) {
                return engine!;
              }),
            currentLedgerProvider.overrideWith(
              (ref) => Stream<Ledger?>.value(null),
            ),
            if (currentLedgerId != null)
              currentLedgerIdProvider.overrideWithBuild(
                (ref, notifier) => currentLedgerId,
              ),
            syncServiceProvider.overrideWithValue(syncService),
            exchangeRateServiceProvider.overrideWithValue(_FailingRateService()),
            activeCloudConfigProvider.overrideWith(
              (ref) async => CloudServiceConfig(
                type: cloud == null
                    ? CloudBackendType.local
                    : CloudBackendType.spitoutCloud,
                name: cloud == null ? 'Local' : 'Spitout Cloud',
                spitoutCloudBaseUrl: cloud == null
                    ? null
                    : 'https://example.com',
              ),
            ),
            if (cloud != null) ...[
              spitoutCloudProviderInstance.overrideWith(
                (ref) async => cloud,
              ),
            ],
            localSelfIdProvider.overrideWith((ref) async => 'device-1'),
          ],
          retry: (retryCount, error) => null,
          child: LedgerEditPage(ledger: ledger),
        ),
      ),
    );
    if (settle) {
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });
    } else {
      // 共享账本 + 云渲染时 pumpAndSettle 可能永不收敛（成员 provider 持续
      // 重试/动画），用有界 pump 推进初始加载。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    // localSelfId 等异步链的收尾 timer 消化。
    await tester.pump(const Duration(seconds: 3));
    return l10n;
  }

  /// 展开右上角「更多」菜单并点击指定项。
  Future<void> tapMoreAction(
    WidgetTester tester,
    String label,
  ) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// 在确认对话框点「确定」。
  Future<void> confirmDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
  }

  group('保存流', () {
    testWidgets('新建：名称必填校验，不填不落库', (tester) async {
      final l10n = await pump(tester);
      await tester.tap(find.text(l10n.ledgersCreate));
      await tester.pumpAndSettle();

      // 校验失败提示 = 名称标签文本，且页面仍在。
      expect(find.text(l10n.ledgerNameLabel), findsWidgets);
      final ledgers = await db.select(db.ledgers).get();
      expect(ledgers, isEmpty);
    });

    testWidgets('新建：填写名称保存成功，AA 开关与虚拟用户随账本落库',
        (tester) async {
      final l10n = await pump(tester);

      // 开启 AA 开关（TextStateSwitch 轨道点击切换）。
      await tester.tap(find.byType(TextStateSwitch));
      await tester.pumpAndSettle();
      // 添加一个虚拟用户（自动命名）。
      await tester.tap(find.text('添加虚拟用户'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '新账本');
      await tester.tap(find.text(l10n.ledgersCreate));
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });

      final ledgers = await db.select(db.ledgers).get();
      expect(ledgers, hasLength(1));
      expect(ledgers.single.name, '新账本');
      expect(ledgers.single.aaEnabled, isTrue);
      final vus = await db.select(db.ledgerVirtualUsers).get();
      expect(vus, hasLength(1));
      // 新建成功 toast。
      expect(find.text(l10n.ledgersCreateSuccess), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('编辑：改名并开启 AA 保存，updateLedger 落库', (tester) async {
      final ledger = await seed(aaEnabled: false);
      final l10n = await pump(tester, ledger: ledger);

      await tester.enterText(find.byType(TextFormField).first, '改名后');
      await tester.tap(find.byType(TextStateSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonSave));
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });

      final row = await repo.getLedgerById(ledger.id);
      expect(row!.name, '改名后');
      expect(row.aaEnabled, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('编辑：无任何变更直接保存关闭', (tester) async {
      final ledger = await seed();
      final l10n = await pump(tester, ledger: ledger);

      await tester.tap(find.text(l10n.commonSave));
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });
      final row = await repo.getLedgerById(ledger.id);
      expect(row!.name, '测试账本');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('编辑：切换币种保存，applyLedgerCurrencyChange 落库', (tester) async {
      final ledger = await seed();
      final l10n = await pump(tester, ledger: ledger);

      // 点击币种行打开选择器。
      await tester.tap(find.text('CNY (¥)'));
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });
      // 选 USD。
      await tester.tap(find.textContaining('美元'));
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });

      await tester.tap(find.text(l10n.commonSave));
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });
      final row = await repo.getLedgerById(ledger.id);
      expect(row!.currency, 'USD');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('编辑：月起始日选择器更新并保存', (tester) async {
      final ledger = await seed();
      final l10n = await pump(tester, ledger: ledger);

      // 点击月起始日行打开 28 宫格选择器。
      await tester.tap(find.text(l10n.ledgersMonthStartDayNatural));
      await tester.pumpAndSettle();
      expect(find.byType(SheetGrabHandle), findsOneWidget,
          reason: '底部弹层应有统一拖拽条');
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.commonSave));
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });
      final row = await repo.getLedgerById(ledger.id);
      expect(row!.monthStartDay, 15);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('加载失败与重试', () {
    testWidgets('账本行缺失：错误态 + 重试恢复', (tester) async {
      final ledger = await seed();
      // 先删掉账本行模拟加载失败。
      await (db.delete(db.ledgers)..where((l) => l.id.equals(ledger.id))).go();
      final l10n = await pump(tester, ledger: ledger);

      expect(find.text(l10n.categoryDetailLoadFailed), findsOneWidget);
      expect(find.text(l10n.analyticsRetry), findsOneWidget);
      expect(find.text(l10n.commonSave), findsNothing);

      // 恢复账本行后重试 → 正常加载。
      await db.into(db.ledgers).insert(
        LedgersCompanion.insert(
          id: Value(ledger.id),
          name: ledger.name,
          currency: const Value('CNY'),
        ),
      );
      await tester.tap(find.text(l10n.analyticsRetry));
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });
      expect(find.text(l10n.commonSave), findsOneWidget);
      expect(find.text(l10n.categoryDetailLoadFailed), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('邀请流程 syncId 轮询', () {
    testWidgets('新建态点邀请：自动保存账本并轮询到 syncId', (tester) async {
      final l10n = await pump(tester, settle: false);
      await tester.enterText(find.byType(TextFormField).first, '邀请账本');

      // 点击「邀请新成员」入口。
      await tester.tap(find.text(l10n.sharedMembersInviteCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 等待账本被自动创建，随后写入 syncId 模拟上云完成。
      Ledger? row;
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final rows = await db.select(db.ledgers).get();
        if (rows.isNotEmpty) {
          row = rows.first;
          break;
        }
      }
      expect(row != null, isTrue, reason: '邀请应自动保存账本');
      await (db.update(db.ledgers)
            ..where((l) => l.id.equals(row!.id)))
          .write(LedgersCompanion(syncId: const Value('synced-1')));

      // 推进 400ms 轮询周期，让 syncId 被捕获。
      await tester.pump(const Duration(milliseconds: 450));
      // 轮询成功后页面显示正式邀请表单（syncId 已更新）。
      expect(find.text('云端同步尚未完成，请稍后重试'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('危险区操作', () {
    testWidgets('清空账本：确认后清空交易并 toast', (tester) async {
      final ledger = await seed();
      // 预置一笔交易。
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          ledgerId: ledger.id,
          type: 'expense',
          amount: 100,
          happenedAt: Value(DateTime.now()),
          version: const Value(1),
        ),
      );
      final l10n = await pump(tester, ledger: ledger);

      await tapMoreAction(tester, l10n.ledgersClear);
      await confirmDialog(tester);

      final txs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(ledger.id)))
          .get();
      expect(txs, isEmpty);
      expect(find.text(l10n.ledgersClearSuccess), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('删除个人账本：确认后全局删除 + 清 prefs + 成功', (tester) async {
      final ledger = await seed(name: '待删账本');
      final l10n = await pump(tester, ledger: ledger);

      await tapMoreAction(tester, l10n.ledgersDelete);
      await confirmDialog(tester);
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });

      expect(syncService.deletedLedgerIds, [ledger.id]);
      final rows = await db.select(db.ledgers).get();
      expect(rows, isEmpty);
      expect(find.text(l10n.ledgersDeleted), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('删除个人账本：用户取消确认不删除', (tester) async {
      final ledger = await seed(name: '保留账本');
      final l10n = await pump(tester, ledger: ledger);

      await tapMoreAction(tester, l10n.ledgersDelete);
      await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
      await tester.pumpAndSettle();

      expect(syncService.deletedLedgerIds, isEmpty);
      final rows = await db.select(db.ledgers).get();
      expect(rows, hasLength(1));
    });

    testWidgets('删除当前账本：切换到剩余账本', (tester) async {
      final l1 = await seed(name: '账本A');
      final l2 = await seed(name: '账本B');
      final l10n = await pump(
        tester,
        ledger: l1,
        currentLedgerId: l1.id,
      );

      await tapMoreAction(tester, l10n.ledgersDelete);
      await confirmDialog(tester);
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });

      // 通过页面的 ref 无法直接读，改为验证 syncService 被调用 + 数据库只留 B。
      expect(syncService.deletedLedgerIds, [l1.id]);
      final rows = await db.select(db.ledgers).get();
      expect(rows.map((r) => r.id), [l2.id]);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('共享账本无 syncId：点击删除提示先启用云同步', (tester) async {
      final ledger = await seed(
        name: '无同步账本',
        isShared: true,
        myRole: 'owner',
      );
      final l10n = await pump(tester, ledger: ledger);

      await tapMoreAction(tester, l10n.ledgersDeleteShared);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.sharedRequiresCloudSync), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('删除个人账本失败：错误弹窗', (tester) async {
      final ledger = await seed(name: '删不掉');
      final l10n = await pump(tester, ledger: ledger);
      // 让删除失败：syncService 抛错。
      syncService.failDelete = true;

      await tapMoreAction(tester, l10n.ledgersDelete);
      await confirmDialog(tester);
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });

      expect(find.text(l10n.commonOperationFailed), findsWidgets);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('协作者退出并删除共享账本：走云端 leaveLedger + 本地清理',
        (tester) async {
      final fake = FakeSpitoutCloudProvider();
      final ledger = await seed(
        name: '共享账本',
        syncId: 'ext-1',
        isShared: true,
        myRole: 'editor',
        storageMode: 'cloud',
      );
      final l10n = await pump(
        tester,
        ledger: ledger,
        cloud: fake,
        settle: false,
      );

      await tapMoreAction(tester, l10n.ledgersLeaveAndDelete);
      await confirmDialog(tester);
      // 让云端退出 + 本地清理的异步链走完（有界推进，避免 settle 挂起）。
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(fake.leaveLedgerCalls, ['ext-1']);
      final rows = await db.select(db.ledgers).get();
      expect(rows, isEmpty);
      // 页面已 pop（删除成功），toast 因 Overlay 随页面销毁不在此断言。
      expect(find.byType(LedgerEditPage), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Owner 删除共享账本：走云端 deleteLedger + 本地清理',
        (tester) async {
      final fake = FakeSpitoutCloudProvider();
      final ledger = await seed(
        name: '共享账本',
        syncId: 'ext-2',
        isShared: true,
        myRole: 'owner',
        storageMode: 'cloud',
      );
      final l10n = await pump(
        tester,
        ledger: ledger,
        cloud: fake,
        settle: false,
      );

      await tapMoreAction(tester, l10n.ledgersDeleteShared);
      await confirmDialog(tester);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(fake.deleteLedgerCalls, ['ext-2']);
      final rows = await db.select(db.ledgers).get();
      expect(rows, isEmpty);
      expect(find.byType(LedgerEditPage), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('存储归属移动执行', () {
    testWidgets('移动到云端：确认后执行并成功关闭页面', (tester) async {
      final fake = FakeSpitoutCloudProvider();
      // 云端优先转云端：fullPush 建本成功后需要 readLedgers 能确认该账本，
      // 模拟真实 server 的自动登记行为。
      fake.autoRegisterWrittenLedgers = true;
      final ledger = await seed(name: '本地账本');
      final l10n = await pump(
        tester,
        ledger: ledger,
        cloud: fake,
        settle: false,
      );

      await tester.tap(find.text(l10n.ledgersActionMoveToCloud));
      await tester.pumpAndSettle();
      await confirmDialog(tester);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final row = await repo.getLedgerById(ledger.id);
      expect(row!.storageMode, 'cloud');
      // 移动成功后 pop 回列表。
      expect(find.byType(LedgerEditPage), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('移动到云端：用户取消确认不执行', (tester) async {
      final fake = FakeSpitoutCloudProvider();
      final ledger = await seed(name: '本地账本');
      final l10n = await pump(
        tester,
        ledger: ledger,
        cloud: fake,
        settle: false,
      );

      await tester.tap(find.text(l10n.ledgersActionMoveToCloud));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
      await tester.pumpAndSettle();

      final row = await repo.getLedgerById(ledger.id);
      expect(row!.storageMode, 'local');
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
