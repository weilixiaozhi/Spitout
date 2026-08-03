import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/cloud/sync/snapshot_dirty_tracker.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/main/ledger_edit_page.dart';
import 'package:spitout/providers/providers.dart';

import '../../helpers/test_isolation.dart';

/// 可人为卡住写库时机的仓库：用 Completer 门闩制造「用户在保存落库期间
/// 极快退出页面」的确定性竞态，避免依赖真实时序的偶发性。
class _GatedRepo extends LocalRepository {
  _GatedRepo(super.db);

  /// createLedger 的门闩；null 表示不拦截直接放行。
  Completer<void>? createGate;

  /// updateLedger 的门闩；null 表示不拦截直接放行。
  Completer<void>? updateGate;

  /// 最近一次创建出的账本 id，供断言使用。
  int? lastCreatedId;

  @override
  Future<int> createLedger({
    required String name,
    String currency = 'CNY',
    String storageMode = 'cloud',
    String? ownerUserId,
  }) async {
    if (createGate != null) await createGate!.future;
    return lastCreatedId = await super.createLedger(
      name: name,
      currency: currency,
      storageMode: storageMode,
      ownerUserId: ownerUserId,
    );
  }

  @override
  Future<void> updateLedger({
    required int id,
    String? name,
    String? currency,
    int? monthStartDay,
    bool? aaEnabled,
  }) async {
    if (updateGate != null) await updateGate!.future;
    await super.updateLedger(
      id: id,
      name: name,
      currency: currency,
      monthStartDay: monthStartDay,
      aaEnabled: aaEnabled,
    );
  }
}

/// 记录 markLocalChanged 调用的同步服务替身：断言「首快照/同步是否被触发」。
/// 非 SyncEngine 类型 → PostProcessor 走 auto_sync 开关分支（测试默认关闭），
/// 不会真的发起上传，纯粹观测触发行为。
class _RecordingSyncService extends LocalOnlySyncService {
  final List<int> marked = [];

  @override
  void markLocalChanged({required int ledgerId}) => marked.add(ledgerId);
}

void main() {
  late SpitoutDatabase db;
  late _GatedRepo repo;
  late _RecordingSyncService syncService;
  late ProviderContainer container;

  /// 按指定后端配置(重)建 container：默认组 setUp 建 Spitout Cloud 版，
  /// 快照后端用例调用本函数换成 webdav 版（先释放旧容器避免泄漏）。
  void buildContainer(CloudServiceConfig config) {
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      syncServiceProvider.overrideWithValue(syncService),
      currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(null)),
      activeCloudConfigProvider.overrideWith((ref) async => config),
    ]);
  }

  setUp(() {
    resetGlobalTestState();
    TestWidgetsFlutterBinding.ensureInitialized();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = _GatedRepo(db);
    // 模拟 Spitout Cloud 登录态的生产接线：注入 ChangeTracker 后,
    // createLedger 会在数据层登记 ledger:upsert 变更（规则4 的驱动源）。
    repo.changeTracker = ChangeTracker(db);
    syncService = _RecordingSyncService();
    buildContainer(CloudServiceConfig(
      type: CloudBackendType.spitoutCloud,
      name: 'Spitout Cloud',
      spitoutCloudBaseUrl: 'https://example.com',
    ));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 用外部 container（UncontrolledProviderScope）承载页面：页面销毁后
  /// container 仍存活，可继续断言全局状态 —— 与真实 app 根容器行为一致。
  Future<AppLocalizations> pump(WidgetTester tester,
      {LedgerDisplayItem? ledger}) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LedgerEditPage(ledger: ledger),
        ),
      ),
    );
    // 等待 initState 的异步链（默认币种/账本数据加载 + 云配置 resolve）全部完成。
    await tester.runAsync(() async {
      await tester.pumpAndSettle();
    });
    return l10n;
  }

  /// 把页面从树上摘除（模拟用户极快退出），但保留外部 container。
  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
  }

  group('新建账本 + 极快退出：状态副作用不得依赖页面挂载', () {
    testWidgets('退出后仍应完成 首快照触发 + 首本账本选中 + 列表刷新', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextFormField).first, '竞态账本');
      final baseRefresh = container.read(ledgerListRefreshProvider);

      // 卡住落库 → 点保存 → 此时 _saveNewLedger 停在 createLedger 门闩上
      repo.createGate = Completer<void>();
      await tester.tap(find.byType(FilledButton));

      // 落库完成前页面已被销毁（用户极快退出）
      await disposePage(tester);

      // 放行落库并让剩余异步链（首快照 / 当前账本切换 / 刷新信号）跑完
      await tester.runAsync(() async {
        repo.createGate!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });

      final newId = repo.lastCreatedId;
      expect(newId, isNotNull, reason: '账本应已成功落库');
      // 规则4：Spitout Cloud 的同步由数据层写入 local_changes 驱动
      // （SyncCoordinator 监听），与页面生命周期彻底无关。
      final changes = await db.select(db.localChanges).get();
      expect(
        changes.where((c) => c.entityType == 'ledger' && c.action == 'upsert'),
        hasLength(1),
        reason: '新建云端账本必须在 local_changes 登记 ledger:upsert',
      );
      // 页面链路不得再手动触发同步（规则4：UI 点击不直调 sync 链路）
      expect(syncService.marked, isEmpty,
          reason: 'Spitout Cloud 下页面不应再手动 markLocalChanged');
      // 空账本场景：首本账本必须被选中，否则 app 停留在"无当前账本"状态
      expect(container.read(currentLedgerIdProvider), newId,
          reason: '页面退出后仍应切换到新建的首本账本');
      // 账本列表页在本页 pop 后仍存活，必须收到刷新信号
      expect(container.read(ledgerListRefreshProvider), greaterThan(baseRefresh),
          reason: '页面退出后仍应 bump 列表刷新信号');

      // ChangeTracker 落变更时 logger 会启动 2s 的日志落盘 debounce Timer，
      // 推进时钟让其走完，避免测试结束时报 pending timer。
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('已登录 Spitout Cloud 但归属选本地：不应触发同步（白跑 SyncEngine）',
        (tester) async {
      final l10n = await pump(tester);

      await tester.enterText(find.byType(TextFormField).first, '本地归属账本');
      // 切换归属为「本地」
      await tester.tap(find.text(l10n.ledgersSectionLocal));
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });

      expect(repo.lastCreatedId, isNotNull);
      // 本地归属账本不参与云同步：markLocalChanged 不应被调用
      expect(syncService.marked, isEmpty,
          reason: '登录态下选本地归属，不应触发 PostProcessor 同步');
      // 本地账本 syncId 为 null，数据层也不得登记任何变更
      final changes = await db.select(db.localChanges).get();
      expect(changes, isEmpty,
          reason: '本地归属账本不应产生 local_changes 记录');

      // 页面未退出场景会正常弹出成功 toast(2s 定时器)，推进时钟让其走完，
      // 避免测试结束时报 pending timer
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('快照型后端（webdav）新建账本：响应式脏信号触发', () {
    testWidgets('极快退出后仍应写入首快照脏信号（snapshot_dirty_ledgers）', (tester) async {
      // 快照后端不读 local_changes，createLedger 在数据层同事务写
      // snapshot_dirty_ledgers 脏信号，由 SnapshotSyncCoordinator 监听消费
      // （coordinator 消费逻辑由独立单测覆盖）。页面零后端知识，不显式调 sync。
      container.dispose();
      // 快照后端接线与生产 database_providers 一致：不注入 ChangeTracker
      // （增量通道），改注入 SnapshotDirtyTracker（快照脏信号通道）。
      repo.changeTracker = null;
      repo.snapshotDirtyMarker = SnapshotDirtyTracker(db);
      buildContainer(CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: 'WebDAV',
        webdavUrl: 'https://dav.example.com',
      ));

      await pump(tester);
      await tester.enterText(find.byType(TextFormField).first, '快照账本');

      repo.createGate = Completer<void>();
      await tester.tap(find.byType(FilledButton));
      await disposePage(tester);

      await tester.runAsync(() async {
        repo.createGate!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });

      final newId = repo.lastCreatedId;
      expect(newId, isNotNull, reason: '账本应已成功落库');
      // 响应式脏信号：createLedger 同事务写入 snapshot_dirty_ledgers，
      // 与页面生命周期彻底无关（规则4：同步由数据变更驱动，UI 不显式调 sync）。
      final dirty = await db.select(db.snapshotDirtyLedgers).get();
      expect(dirty.map((d) => d.ledgerId), contains(newId),
          reason: '快照后端新建账本必须写入 snapshot_dirty_ledgers 脏信号');
      // 未登录 Spitout Cloud → 账本被夹紧为 local，无 syncId，
      // 不应产生 local_changes（那是 Spitout Cloud 增量同步的专属通道）。
      final changes = await db.select(db.localChanges).get();
      expect(changes, isEmpty,
          reason: '快照后端新建账本不应写 local_changes');
      // 页面链路不得再手动触发同步（syncNewLedgerC 已删除，规则4）
      expect(syncService.marked, isEmpty,
          reason: '快照后端下页面不应再手动 markLocalChanged');
      // LoggerService 落日志时会启动 2s debounce Timer(markLedgerDirty 内
      // logger.debug 触发),推进时钟让其走完,避免测试结束时报 pending timer。
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('编辑账本 + 极快退出：刷新与同步不得依赖页面挂载', () {
    testWidgets('退出后仍应完成 列表刷新 + 同步触发', (tester) async {
      // 直接用仓库种一本本地账本（避开 syncId 分配逻辑的干扰）
      late int ledgerId;
      await tester.runAsync(() async {
        ledgerId = await repo.createLedger(name: 'Old', storageMode: 'local');
      });
      final item = LedgerDisplayItem.fromLocal(
        id: ledgerId,
        name: 'Old',
        currency: 'CNY',
        createdAt: DateTime.now(),
        transactionCount: 0,
        expenseTotal: 0,
        isShared: false,
        memberCount: 1,
        myRole: 'owner',
        storageMode: 'local',
      );
      await pump(tester, ledger: item);

      await tester.enterText(find.byType(TextFormField).first, 'Renamed');
      final baseRefresh = container.read(ledgerListRefreshProvider);

      // 卡住 updateLedger → 点保存 → 让保存链推进到门闩处
      repo.updateGate = Completer<void>();
      await tester.tap(find.byType(FilledButton));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      // 写库完成前页面已被销毁
      await disposePage(tester);

      await tester.runAsync(() async {
        repo.updateGate!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });

      // 改名已落库 → 刷新信号与同步触发必须完成，不得因 ref 失效被静默吞掉
      expect(container.read(ledgerListRefreshProvider), greaterThan(baseRefresh),
          reason: '页面退出后仍应 bump 列表刷新信号');
      expect(syncService.marked, contains(ledgerId),
          reason: '页面退出后仍必须触发同步（markLocalChanged）');
    });
  });
}
