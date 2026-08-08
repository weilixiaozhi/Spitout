/// LedgersPage 行为流测试（第二弹）：加载/错误态、账本切换、冲突对话框全流程、
/// 共享账本入口与导入完成联动。
///
/// 设计意图：第一弹（ledgers_page_test.dart）覆盖双分区渲染与下拉刷新骨架，
/// 本文件集中覆盖「点击卡片后的业务分支」——同步状态获取失败按无冲突处理、
/// 冲突时进入对话框、下载/上传成功与失败、处理中 spinner 等，避免把页面交互
/// 拆散到多个文件里难以对照需求断言。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show CloudBackendType, CloudServiceConfig;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/cloud/join_shared_ledger_page.dart';
import 'package:spitout/pages/main/ledger_edit_page.dart';
import 'package:spitout/pages/main/ledgers_page.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// 可配置行为的 SyncService 替身。
///
/// 生产 SyncEngine 依赖数据库与网络；这里只控制 getStatus / 上传 / 下载的
/// 返回值与异常，并把调用次数暴露给断言，验证页面确实把操作派发到了服务层。
class _FakeSyncService implements SyncService {
  SyncStatus status = const SyncStatus(
    diff: SyncDiff.inSync,
    localCount: 0,
    localFingerprint: '',
  );

  Object? getStatusError;
  Object? uploadError;
  Object? downloadError;

  /// 上传/下载闸门：置为非空时操作会挂起，用于断言「处理中 spinner」。
  Completer<void>? uploadGate;
  Completer<void>? downloadGate;

  ({int inserted, int deletedDup}) downloadResult = (inserted: 5, deletedDup: 0);

  int uploadCalls = 0;
  int downloadCalls = 0;
  int markLocalChangedCalls = 0;

  @override
  bool supportsDiffPreview = false;

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    final err = getStatusError;
    if (err != null) throw err;
    return status;
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    uploadCalls++;
    final gate = uploadGate;
    if (gate != null) await gate.future;
    final err = uploadError;
    if (err != null) throw err;
  }

  @override
  Future<({int inserted, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
    downloadCalls++;
    final gate = downloadGate;
    if (gate != null) await gate.future;
    final err = downloadError;
    if (err != null) throw err;
    return downloadResult;
  }

  @override
  void markLocalChanged({required int ledgerId}) {
    markLocalChangedCalls++;
  }

  @override
  Future<({SyncPreview? preview, ImportData importData, int version})?>
      downloadAndPreview({required int ledgerId}) async => null;

  @override
  Future<SyncApplyResult> applyPreviewChanges({
    required int ledgerId,
    required List<SyncChange> selectedChanges,
    required ImportData importData,
  }) async =>
      const SyncApplyResult(addedCount: 0);

  @override
  Future<int> pullIncremental({required int ledgerId}) async => 0;

  @override
  Future<PullOutcome> pullIncrementalWithHeal({required int ledgerId}) async =>
      const PullOutcome(incremental: 0);

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async =>
      (fingerprint: null, count: null, exportedAt: null);

  @override
  Future<void> deleteRemoteBackup({required int ledgerId}) async {}

  @override
  Future<void> deleteLedgerGlobally(int ledgerId) async {}

  @override
  Future<void> moveToCloud(int ledgerId) async {}

  @override
  Future<void> moveToLocal(int ledgerId) async {}

  @override
  Future<int> copyToLocal(int sourceLedgerId) async => 0;

  @override
  void clearStatusCache({int? ledgerId}) {}
}

/// 构造确定的账本展示项。
LedgerDisplayItem _localItem(
  int id,
  String name, {
  String storageMode = 'local',
}) =>
    LedgerDisplayItem.fromLocal(
      id: id,
      name: name,
      currency: 'CNY',
      createdAt: DateTime(2026, 1, 1),
      transactionCount: 3,
      expenseTotal: 100.0,
      storageMode: storageMode,
    );

/// Spitout Cloud 激活配置（触发「加入共享账本」入口与云端空态文案）。
CloudServiceConfig _spitoutConfig() => const CloudServiceConfig(
  type: CloudBackendType.spitoutCloud,
  name: 'Spitout Cloud',
  spitoutCloudBaseUrl: 'https://cloud.example.com',
);

/// 挂载 LedgersPage 并返回容器。
///
/// [cloudConfig] 控制共享账本入口的可见性；[sync] 注入可配置的同步服务替身。
/// 默认 local 配置 + Fake 服务，测试即可确定性地驱动所有交互分支。
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<LedgerDisplayItem> ledgers = const [],
  Future<List<LedgerDisplayItem>> Function()? localBuilder,
  CloudServiceConfig? cloudConfig,
  SyncService? sync,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      localLedgersProvider.overrideWith(
        (ref) {
          // 与真实实现一致：刷新 tick 变化时重算，否则下拉刷新无法驱动测试状态。
          ref.watch(ledgerListRefreshProvider);
          return localBuilder != null ? localBuilder() : Future.value(ledgers);
        },
      ),
      activeCloudConfigProvider.overrideWith(
        (ref) async => cloudConfig ?? CloudServiceConfig.localStorage(),
      ),
      syncServiceProvider.overrideWith((ref) => sync ?? _FakeSyncService()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const LedgersPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return container;
}

/// 让 LoggerService 的 2s 异步保存定时器与 toast 定时器走完，避免 pending timer。
Future<void> _flushTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('加载中且无缓存：显示全局 spinner', (tester) async {
    final pending = Completer<List<LedgerDisplayItem>>();
    final container = ProviderContainer(
      overrides: [
        localLedgersProvider.overrideWith((ref) => pending.future),
        activeCloudConfigProvider.overrideWith(
          (ref) async => CloudServiceConfig.localStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LedgersPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('本地账本'), findsNothing,
        reason: '加载中不应提前渲染分区列表');
  });

  testWidgets('本地加载失败且无缓存：显示错误文案', (tester) async {
    final container = ProviderContainer(
      overrides: [
        localLedgersProvider.overrideWith(
          (ref) => Future<List<LedgerDisplayItem>>.error(StateError('boom')),
        ),
        activeCloudConfigProvider.overrideWith(
          (ref) async => CloudServiceConfig.localStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LedgersPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('错误'), findsOneWidget,
        reason: '加载失败应展示「错误: <原因>」而非空列表');
    await _flushTimers(tester);
  });

  testWidgets('下拉刷新时本地 provider 抛错：不崩溃、刷新信号仍自增', (tester) async {
    // 首次构建成功渲染列表；刷新 tick 触发 provider 重算时抛错，
    // 才能走到 _handleRefresh 的 try-catch（错误态下没有 ListView 可下拉）。
    var calls = 0;
    final container = await _pump(
      tester,
      localBuilder: () async {
        calls++;
        if (calls > 1) throw StateError('boom');
        return [_localItem(1, '旅行账本')];
      },
    );

    final before = container.read(ledgerListRefreshProvider);
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(ledgerListRefreshProvider), before + 1,
        reason: '刷新入口应照常自增信号，错误仅记录日志');
    await _flushTimers(tester);
  });

  testWidgets('导入完成（running→completed 且带 ledgerId）：触发同步刷新', (tester) async {
    final sync = _FakeSyncService();
    final container = await _pump(tester, sync: sync, overrides: [
      importProgressProvider.overrideWith(
        () => SimpleStateNotifier<ImportProgress>((ref) => ImportProgress.empty),
      ),
    ]);

    final listTickBefore = container.read(ledgerListRefreshProvider);
    final statusTickBefore = container.read(syncStatusRefreshProvider);

    // 先置为「导入中」，让 ref.listen 拿到 running 作为 previous。
    container.read(importProgressProvider.notifier).set(
      const ImportProgress(
        running: true,
        total: 5,
        done: 2,
        ok: 2,
        fail: 0,
      ),
    );
    await tester.pump();

    // 置为「刚完成」，应触发 PostProcessor.sync(ledgerId)。
    container.read(importProgressProvider.notifier).set(
      const ImportProgress(
        running: false,
        total: 5,
        done: 5,
        ok: 5,
        fail: 0,
        ledgerId: 1,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sync.markLocalChangedCalls, greaterThanOrEqualTo(1),
        reason: '导入完成应通知同步服务清理缓存');
    expect(container.read(ledgerListRefreshProvider), greaterThan(listTickBefore));
    expect(
      container.read(syncStatusRefreshProvider),
      greaterThan(statusTickBefore),
    );
    await _flushTimers(tester);
  });

  testWidgets('点击本地账本卡片：切换当前账本并弹 toast', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.inSync,
        localCount: 3,
        localFingerprint: 'local-fp',
      );
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    // 预置最近一次成功状态，避免等待云端探测。
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(currentLedgerIdProvider), 5,
        reason: '点击卡片应把当前账本切到目标账本');
    expect(find.textContaining('已切换', findRichText: true), findsOneWidget,
        reason: '切换成功应弹轻量 toast 反馈');
    await _flushTimers(tester);
  });

  testWidgets('同步状态获取失败：按无冲突降级切换（不阻塞用户）', (tester) async {
    final sync = _FakeSyncService();
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
      overrides: [
        // 无缓存且云端状态查询失败，_awaitSyncStatus 应降级为 null。
        syncStatusProvider(5).overrideWith(
          (ref) => Future<SyncStatus>.error(StateError('network down')),
        ),
      ],
    );

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(currentLedgerIdProvider), 5,
        reason: '状态查询失败不应卡死切换，应按无冲突继续');
    expect(find.textContaining('已切换', findRichText: true), findsOneWidget);
    await _flushTimers(tester);
  });

  testWidgets('冲突：点击卡片弹出冲突对话框并展示本地/云端信息', (tester) async {
    final sync = _FakeSyncService()
      ..status = SyncStatus(
        diff: SyncDiff.different,
        localCount: 12,
        localFingerprint: 'abc123456789',
        cloudCount: 10,
        cloudFingerprint: 'xyz1234567890',
        cloudExportedAt: DateTime(2026, 1, 1, 10, 30),
      );
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('同步冲突'), findsOneWidget);
    expect(find.text('本地和云端账本数据不一致，请选择操作：'), findsOneWidget);
    expect(find.text('本地：12 笔账单'), findsOneWidget);
    expect(find.text('本地指纹：abc12345'), findsOneWidget,
        reason: '指纹应截取前 8 位展示');
    expect(find.text('云端：10 笔账单'), findsOneWidget);
    expect(find.text('云端更新：2026-01-01 10:30:00'), findsOneWidget);
    expect(find.text('云端指纹：xyz12345'), findsOneWidget);

    // 取消应关闭对话框，不执行任何同步动作。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('同步冲突'), findsNothing);
    expect(sync.uploadCalls, 0);
    expect(sync.downloadCalls, 0);
    await _flushTimers(tester);
  });

  testWidgets('冲突：云端信息缺失时不渲染云端区块', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.different,
        localCount: 4,
        localFingerprint: 'abc',
      );
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('同步冲突'), findsOneWidget);
    expect(find.text('本地指纹：abc'), findsOneWidget,
        reason: '短指纹应整体展示，不截断');
    expect(find.textContaining('云端指纹'), findsNothing,
        reason: '无云端指纹/时间时不应渲染云端信息区块');

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await _flushTimers(tester);
  });

  testWidgets('冲突：下载成功 → 关闭对话框、弹成功 toast 并刷新信号', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.different,
        localCount: 12,
        localFingerprint: 'abc123456789',
      )
      ..downloadResult = (inserted: 5, deletedDup: 0);
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pumpAndSettle();

    final listTickBefore = container.read(ledgerListRefreshProvider);
    final statusTickBefore = container.read(syncStatusRefreshProvider);

    await tester.tap(find.text('下载到本地'));
    await tester.pumpAndSettle();

    expect(sync.downloadCalls, 1);
    expect(find.text('同步冲突'), findsNothing,
        reason: '下载成功应关闭冲突对话框');
    expect(find.text('下载成功，已合并 5 笔账单'), findsOneWidget);
    expect(container.read(ledgerListRefreshProvider), greaterThan(listTickBefore));
    expect(
      container.read(syncStatusRefreshProvider),
      greaterThan(statusTickBefore),
    );
    await _flushTimers(tester);
  });

  testWidgets('冲突：下载失败 → 弹错误对话框且可关闭', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.different,
        localCount: 12,
        localFingerprint: 'abc123456789',
      )
      ..downloadError = StateError('download boom');
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载到本地'));
    await tester.pumpAndSettle();

    expect(find.text('失败'), findsOneWidget,
        reason: '下载失败应弹统一错误对话框');
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('失败'), findsNothing);
    await _flushTimers(tester);
  });

  testWidgets('冲突：下载处理中显示 spinner 并隐藏操作按钮', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.different,
        localCount: 12,
        localFingerprint: 'abc123456789',
      )
      ..downloadGate = Completer<void>();
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载到本地'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: '处理中应显示 loading 占位');
    expect(find.text('下载到本地'), findsNothing);
    expect(find.text('上传到云端'), findsNothing,
        reason: '处理中应隐藏操作按钮，防止重复提交');

    sync.downloadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('同步冲突'), findsNothing);
    await _flushTimers(tester);
  });

  testWidgets('冲突：上传成功 → 关闭对话框、弹成功 toast 并刷新信号', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.different,
        localCount: 12,
        localFingerprint: 'abc123456789',
      );
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pumpAndSettle();

    final listTickBefore = container.read(ledgerListRefreshProvider);
    final statusTickBefore = container.read(syncStatusRefreshProvider);

    await tester.tap(find.text('上传到云端'));
    await tester.pumpAndSettle();

    expect(sync.uploadCalls, 1);
    expect(find.text('同步冲突'), findsNothing);
    expect(find.text('上传成功'), findsOneWidget);
    expect(container.read(ledgerListRefreshProvider), greaterThan(listTickBefore));
    expect(
      container.read(syncStatusRefreshProvider),
      greaterThan(statusTickBefore),
    );
    await _flushTimers(tester);
  });

  testWidgets('冲突：上传失败 → 弹错误对话框且可关闭', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.different,
        localCount: 12,
        localFingerprint: 'abc123456789',
      )
      ..uploadError = StateError('upload boom');
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上传到云端'));
    await tester.pumpAndSettle();

    expect(find.text('失败'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('失败'), findsNothing);
    await _flushTimers(tester);
  });

  testWidgets('冲突：getStatus 详情失败 → 只弹 toast，不进对话框', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.different,
        localCount: 12,
        localFingerprint: 'abc123456789',
      )
      ..getStatusError = StateError('status boom');
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    await tester.tap(find.textContaining('旅行账本', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('同步冲突'), findsNothing,
        reason: '详情获取失败不应进入冲突对话框');
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    await _flushTimers(tester);
  });

  testWidgets('冲突：卡片编辑入口同样先弹冲突对话框，不进入编辑页', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.different,
        localCount: 12,
        localFingerprint: 'abc123456789',
      );
    final container = await _pump(
      tester,
      ledgers: [_localItem(5, '旅行账本')],
      sync: sync,
    );
    container.read(lastSyncStatusProvider(5).notifier).set(sync.status);

    final editBtn = find.widgetWithIcon(IconButton, AppIcons.edit);
    expect(editBtn, findsOneWidget);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    expect(find.text('同步冲突'), findsOneWidget);
    expect(find.byType(LedgerEditPage), findsNothing,
        reason: '有冲突时编辑入口应拦截，不得放行进编辑页');

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await _flushTimers(tester);
  });

  testWidgets('Spitout Cloud 激活：显示「加入共享账本」入口并可跳转', (tester) async {
    await _pump(
      tester,
      ledgers: [_localItem(1, '旅行账本')],
      cloudConfig: _spitoutConfig(),
    );

    final joinBtn = find.text('加入共享账本');
    expect(joinBtn, findsOneWidget,
        reason: '仅 Spitout Cloud 激活时展示共享账本入口');

    await tester.tap(joinBtn);
    await tester.pumpAndSettle();

    expect(find.byType(JoinSharedLedgerPage), findsOneWidget);
    expect(find.text('输入邀请码或点击对方分享的链接'), findsWidgets,
        reason: '跳转后应进入共享账本加入页');
    await _flushTimers(tester);
  });

  testWidgets('Spitout Cloud 激活且云端为空：显示云端空态文案', (tester) async {
    await _pump(
      tester,
      ledgers: [_localItem(1, '旅行账本')],
      cloudConfig: _spitoutConfig(),
    );

    expect(find.text('暂无云端账本，云端账本会在各设备间同步'), findsOneWidget,
        reason: 'Spitout Cloud 登录态下空分区应给「暂无云端账本」而非登录引导');
    expect(find.text('登录 Spitout Cloud 后即可使用云端账本'), findsNothing);
  });

  testWidgets('本地分区空态：点击「新建账本」跳转 LedgerEditPage', (tester) async {
    await _pump(tester);

    final newBtn = find.ancestor(
      of: find.byIcon(AppIcons.addCircle),
      matching: find.bySubtype<OutlinedButton>(),
    );
    expect(newBtn, findsOneWidget);

    await tester.tap(newBtn);
    await tester.pumpAndSettle();

    expect(find.byType(LedgerEditPage), findsOneWidget,
        reason: '空态「新建账本」应打开新建账本编辑页');
    await _flushTimers(tester);
  });
}
