// CloudSyncSection（WebDAV / S3 / Supabase 备份同步区）组件测试。
//
// 设计意图：宿主页面只负责挂载，本节负责「同步状态展示 + 上传/下载 + 登录/登出 +
// 自动同步开关」全部业务交互。测试用 FakeSyncService 注入可控状态，逐分支断言：
//   - SyncDiff 9 种差异文案与图标；
//   - 同步状态详情弹窗的明细行（含 message 本地化映射）；
//   - 上传成功 / 失败、下载 diff 预览 / 旧格式全量替换 / 无预览能力各分支；
//   - Supabase 登录 / 登出（含登出后云端账本 purge）；
//   - 自动同步开关写入。
// 依赖注入沿用 cloud_service_page_test 的模式：override 各 provider 提供确定值，
// auth/sync 用 Fake 替代，避免测试环境触网或依赖真实数据库。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_diff_service.dart';
import 'package:spitout/cloud/sync/sync_service.dart';
import 'package:spitout/data/models.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/auth/login_page.dart';
import 'package:spitout/pages/cloud/cloud_sync_section.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/theme/icons/app_icons.dart';

CloudServiceConfig _webdavActive() => const CloudServiceConfig(
  type: CloudBackendType.webdav,
  name: 'WebDAV',
  webdavUrl: 'https://dav.example.com',
  webdavUsername: 'u',
  webdavPassword: 'p',
);

CloudServiceConfig _supabaseActive() => const CloudServiceConfig(
  type: CloudBackendType.supabase,
  name: 'Supabase',
  supabaseUrl: 'https://xxx.supabase.co',
  supabaseAnonKey: 'anon-key',
);

CloudServiceConfig _localActive() => CloudServiceConfig.localStorage();

/// 可配置行为的 SyncService 假实现。
///
/// 生产 SyncEngine 依赖数据库与网络，测试只需控制状态与各动作的返回值/异常，
/// 因此按接口手写一份可控替身，避免 mocktail 未 stub 方法返回 null 引发 NPE。
class _FakeSyncService implements SyncService {
  @override
  bool supportsDiffPreview = false;
  SyncStatus status = const SyncStatus(
    diff: SyncDiff.localNewer,
    localCount: 0,
    localFingerprint: '',
  );

  Object? uploadError;
  Object? downloadError;

  ({SyncPreview? preview, ImportData importData, int version})? previewResult;
  ({int inserted, int deletedDup}) downloadResult = (inserted: 1, deletedDup: 0);
  SyncApplyResult applyResult = const SyncApplyResult(addedCount: 1);

  int uploadCalls = 0;
  int downloadCalls = 0;
  int previewCalls = 0;
  int applyCalls = 0;
  int refreshFingerprintCalls = 0;

  /// 上传成功后的后台轮询依次返回的 diff（用于覆盖退避重试循环）。
  List<SyncDiff> pollStatuses = const [];

  @override
  Future<({SyncPreview? preview, ImportData importData, int version})?>
      downloadAndPreview({required int ledgerId}) async {
    previewCalls++;
    return previewResult;
  }

  @override
  Future<SyncApplyResult> applyPreviewChanges({
    required int ledgerId,
    required List<SyncChange> selectedChanges,
    required ImportData importData,
  }) async {
    applyCalls++;
    return applyResult;
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    uploadCalls++;
    final err = uploadError;
    if (err != null) throw err;
  }

  @override
  Future<({int inserted, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
    downloadCalls++;
    final err = downloadError;
    if (err != null) throw err;
    return downloadResult;
  }

  @override
  Future<int> pullIncremental({required int ledgerId}) async => 0;

  @override
  Future<PullOutcome> pullIncrementalWithHeal({required int ledgerId}) async =>
      const PullOutcome(incremental: 0);

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    // 上传成功后的后台轮询以「已同步」为终态：返回 inSync 让循环立即退出，
    // 避免测试遗留 500ms~8s 的退避定时器。
    if (uploadCalls > 0) {
      if (pollStatuses.isNotEmpty) {
        final diff = pollStatuses.removeAt(0);
        return SyncStatus(
          diff: diff,
          localCount: 0,
          localFingerprint: '',
        );
      }
      return const SyncStatus(
        diff: SyncDiff.inSync,
        localCount: 0,
        localFingerprint: '',
      );
    }
    return status;
  }

  @override
  void markLocalChanged({required int ledgerId}) {}

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async {
    refreshFingerprintCalls++;
    return (fingerprint: null, count: null, exportedAt: null);
  }

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

class _FakeAuth extends CloudAuthService {
  final CloudUser? user;
  int signOutCalls = 0;

  _FakeAuth({this.user});

  @override
  Stream<CloudUser?> get authStateChanges => Stream.value(user);

  @override
  Future<CloudUser?> get currentUser async => user;

  @override
  Future<CloudUser> signInWithAccount({
    required String account,
    required String password,
  }) async => user!;

  @override
  Future<CloudUser> signUpWithAccount({
    required String account,
    required String password,
  }) async => user!;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<void> sendPasswordResetAccount({required String account}) async {}

  @override
  Future<void> resendAccountVerification({required String account}) async {}
}

class _FakeAutoSyncSetter extends AutoSyncSetter {
  _FakeAutoSyncSetter(this.onSet, Ref ref) : super(ref);
  final void Function(bool)? onSet;

  @override
  Future<void> set(bool v) async {
    onSet?.call(v);
  }
}

class _MockRepo extends Mock implements BaseRepository {}

/// 在 ProviderContainer 中挂载 CloudSyncSection。
///
/// 默认 ledgerId=1（非哨兵 0），active 为 WebDAV；auth 未登录（NoopAuthService）。
/// 先预解析云端配置再挂载：组件首帧直接读取 `cloudConfig.value!`，
/// 配置 Future 尚未 resolved 时会空崩（生产宿主页先 watch 配置故不会触发）。
/// [extraOverrides] 用于覆盖 repositoryProvider 等特殊场景。
/// [authError] 非空时让 authServiceProvider 抛错，覆盖「加载认证失败」分支。
Future<ProviderContainer> _pumpSection(
  WidgetTester tester, {
  required CloudServiceConfig active,
  required _FakeSyncService sync,
  CloudAuthService? auth,
  Object? authError,
  int ledgerId = 1,
  bool autoSync = false,
  void Function(bool)? onAutoSync,
  SyncStatus? cachedStatus,
  Future<SyncStatus> Function(int ledgerId)? statusOverride,
  bool settle = true,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  // 抬升视口，避免区块内多行 Tile 超出默认 600px 高度导致点击不可命中。
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  final container = ProviderContainer(
    overrides: [
      activeCloudConfigProvider.overrideWith((ref) async => active),
      authServiceProvider.overrideWith((ref) async {
        final err = authError;
        if (err != null) throw err;
        return auth ?? NoopAuthService();
      }),
      syncServiceProvider.overrideWith((ref) => sync),
      currentLedgerIdProvider.overrideWithBuild((ref, notifier) => ledgerId),
      autoSyncValueProvider.overrideWith((ref) async => autoSync),
      autoSyncSetterProvider.overrideWith(
        (ref) => _FakeAutoSyncSetter(onAutoSync, ref),
      ),
      if (statusOverride != null)
        syncStatusProvider.overrideWith(
          (ref, ledgerId) => statusOverride(ledgerId),
        ),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  final cached = cachedStatus;
  if (cached != null) {
    container
        .read(lastSyncStatusProvider(ledgerId).notifier)
        .set(cached);
  }
  await container.read(activeCloudConfigProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CloudSyncSection()),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // 认证 FutureProvider 与 FutureBuilder 需要跨多帧才能落定，逐帧推进。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 冲刷 LoggerService 写日志时调度的 2s debounce 定时器，避免测试结束报 pending timer。
  Future<void> flushLoggerTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('ledgerId=0 时渲染「未找到账本」简化提示', (tester) async {
    final sync = _FakeSyncService();
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
      ledgerId: 0,
    );

    expect(find.text('未找到账本'), findsOneWidget);
  });

  testWidgets('认证服务加载失败时展示统一失败文案', (tester) async {
    final sync = _FakeSyncService();
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
      authError: Exception('auth boom'),
    );

    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    await flushLoggerTimers(tester);
  });

  testWidgets('认证服务加载中显示 loading 指示器', (tester) async {
    final sync = _FakeSyncService();
    final gate = Completer<CloudAuthService>();
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        activeCloudConfigProvider.overrideWith((ref) async => _webdavActive()),
        authServiceProvider.overrideWith((ref) => gate.future),
        syncServiceProvider.overrideWith((ref) => sync),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeCloudConfigProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CloudSyncSection()),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(NoopAuthService());
    await tester.pumpAndSettle();
  });

  group('同步状态 9 种差异文案', () {
    Future<void> pumpDiff(WidgetTester tester, SyncStatus status) async {
      final sync = _FakeSyncService()..status = status;
      await _pumpSection(
        tester,
        active: _webdavActive(),
        sync: sync,
      );
    }

    testWidgets('notLoggedIn', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.notLoggedIn,
          localCount: 0,
          localFingerprint: '',
        ),
      );
      expect(find.text('未登录'), findsWidgets);
      expect(find.byIcon(AppIcons.lock), findsOneWidget);
    });

    testWidgets('notConfigured', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.notConfigured,
          localCount: 0,
          localFingerprint: '',
        ),
      );
      expect(find.text('未配置云端'), findsWidgets);
      expect(find.byIcon(AppIcons.cloudOff), findsOneWidget);
    });

    testWidgets('localOnly', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.localOnly,
          localCount: 0,
          localFingerprint: '',
        ),
      );
      expect(find.text('本地账本，仅存本机'), findsOneWidget);
      expect(find.byIcon(AppIcons.localStorage), findsOneWidget);
    });

    testWidgets('noRemote', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.noRemote,
          localCount: 0,
          localFingerprint: '',
        ),
      );
      expect(find.text('云端暂无数据'), findsOneWidget);
      expect(find.byIcon(AppIcons.cloudQueue), findsOneWidget);
    });

    testWidgets('inSync', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.inSync,
          localCount: 5,
          localFingerprint: 'fp',
        ),
      );
      expect(find.text('已同步 (本地5条)'), findsOneWidget);
      expect(find.byIcon(AppIcons.verified), findsOneWidget);
    });

    testWidgets('localNewer', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.localNewer,
          localCount: 3,
          localFingerprint: 'fp',
        ),
      );
      expect(find.text('本地有更新 (本地3条, 建议上传)'), findsOneWidget);
      expect(find.byIcon(AppIcons.upload), findsOneWidget);
    });

    testWidgets('cloudNewer', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.cloudNewer,
          localCount: 0,
          localFingerprint: '',
        ),
      );
      expect(find.text('云端有更新 (建议下载同步)'), findsOneWidget);
      expect(find.byIcon(AppIcons.download), findsOneWidget);
    });

    testWidgets('different', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.different,
          localCount: 0,
          localFingerprint: '',
        ),
      );
      expect(find.text('本地与云端有差异，建议下载对比'), findsOneWidget);
      expect(find.byIcon(AppIcons.syncDifferent), findsOneWidget);
    });

    testWidgets('error 无 message 时回落通用文案', (tester) async {
      await pumpDiff(
        tester,
        const SyncStatus(
          diff: SyncDiff.error,
          localCount: 0,
          localFingerprint: '',
        ),
      );
      expect(find.text('状态获取失败'), findsOneWidget);
      expect(find.byIcon(AppIcons.error), findsOneWidget);
    });

    testWidgets('error 带特殊 message 时映射本地化文案', (tester) async {
      final sync = _FakeSyncService()
        ..status = const SyncStatus(
          diff: SyncDiff.error,
          localCount: 0,
          localFingerprint: '',
          message: '__SYNC_CLOUD_BACKUP_CORRUPTED__',
        );
      await _pumpSection(
        tester,
        active: _webdavActive(),
        sync: sync,
      );

      expect(find.textContaining('云端备份内容无法解析'), findsOneWidget);
      // 详情弹窗侧同样映射为本地化文案
      await tester.tap(find.textContaining('云端备份内容无法解析').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('说明: 云端备份内容无法解析'), findsOneWidget);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
    });

    testWidgets('error 带未知 message 时原样展示', (tester) async {
      final sync = _FakeSyncService()
        ..status = const SyncStatus(
          diff: SyncDiff.error,
          localCount: 0,
          localFingerprint: '',
          message: 'custom failure',
        );
      await _pumpSection(
        tester,
        active: _webdavActive(),
        sync: sync,
      );

      expect(find.text('custom failure'), findsOneWidget);
    });
  });

  testWidgets('点击同步状态行弹出详情弹窗，含云端计数/指纹/消息映射', (tester) async {
    final sync = _FakeSyncService()
      ..status = SyncStatus(
        diff: SyncDiff.different,
        localCount: 2,
        cloudCount: 3,
        localFingerprint: 'local-fp',
        cloudFingerprint: 'cloud-fp',
        cloudExportedAt: DateTime.utc(2026, 8, 8, 10, 30),
        message: '__SYNC_ACCESS_DENIED__',
      );
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('本地与云端有差异，建议下载对比'));
    await tester.pumpAndSettle();

    expect(find.text('同步状态详情'), findsOneWidget);
    expect(find.textContaining('本地记录数: 2'), findsOneWidget);
    expect(find.textContaining('云端记录数: 3'), findsOneWidget);
    expect(find.textContaining('本地指纹: local-fp'), findsOneWidget);
    expect(find.textContaining('云端指纹: cloud-fp'), findsOneWidget);
    expect(find.textContaining('403 拒绝访问'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  });

  testWidgets('上传成功：调用 uploadCurrentLedger、弹成功提示、上传标记清理', (tester) async {
    final sync = _FakeSyncService();
    final container = await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('上传'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sync.uploadCalls, 1);
    expect(find.text('已上传'), findsOneWidget);
    expect(find.text('当前账本已同步到云端'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(container.read(uploadingLedgerIdsProvider), isEmpty);
    await flushLoggerTimers(tester);
  });

  testWidgets('上传失败：弹错误提示且上传标记清理', (tester) async {
    final sync = _FakeSyncService()..uploadError = Exception('upload boom');
    final container = await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('上传'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('失败'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(container.read(uploadingLedgerIdsProvider), isEmpty);
    await flushLoggerTimers(tester);
  });

  testWidgets('下载（无 diff 预览能力）：全量恢复并弹导入条数', (tester) async {
    final sync = _FakeSyncService()
      ..supportsDiffPreview = false
      ..downloadResult = (inserted: 7, deletedDup: 2);
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('下载同步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sync.downloadCalls, 1);
    expect(find.text('同步完成'), findsOneWidget);
    expect(find.text('导入：7 条'), findsOneWidget);

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await flushLoggerTimers(tester);
  });

  testWidgets('下载失败：弹错误提示', (tester) async {
    final sync = _FakeSyncService()
      ..supportsDiffPreview = false
      ..downloadError = Exception('download boom');
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('下载同步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('失败'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await flushLoggerTimers(tester);
  });

  testWidgets('下载（diff 预览为空）：提示无需同步', (tester) async {
    final sync = _FakeSyncService()
      ..supportsDiffPreview = true
      ..previewResult = (
        preview: const SyncPreview(changes: []),
        importData: const ImportData(),
        version: 7,
      );
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('下载同步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sync.previewCalls, 1);
    expect(find.text('云端数据与本地一致，无需同步'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await flushLoggerTimers(tester);
  });

  testWidgets('下载（diff 预览非空）：应用选中变更并提示', (tester) async {
    final sync = _FakeSyncService()
      ..supportsDiffPreview = true
      ..previewResult = (
        preview: SyncPreview(
          changes: [
            SyncChange(
              type: SyncChangeType.added,
              cloudTransaction: null,
            ),
          ],
        ),
        importData: const ImportData(),
        version: 7,
      );
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('下载同步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('同步预览'), findsOneWidget);
    await tester.tap(find.text('应用 1 项'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sync.applyCalls, 1);
    expect(find.text('已应用 1 项变更'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await flushLoggerTimers(tester);
  });

  testWidgets('下载（diff 预览为 null 旧格式）：确认后全量替换', (tester) async {
    final sync = _FakeSyncService()
      ..supportsDiffPreview = true
      ..previewResult = (
        preview: null,
        importData: const ImportData(),
        version: 5,
      )
      ..downloadResult = (inserted: 4, deletedDup: 1);
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('下载同步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('云端数据格式较旧，将执行全量替换'), findsOneWidget);
    await tester.tap(find.text('确定').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sync.downloadCalls, 1);
    expect(find.text('导入：4 条'), findsOneWidget);

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    await flushLoggerTimers(tester);
  });

  testWidgets('下载（旧格式）取消确认：不执行恢复', (tester) async {
    final sync = _FakeSyncService()
      ..supportsDiffPreview = true
      ..previewResult = (
        preview: null,
        importData: const ImportData(),
        version: 5,
      );
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('下载同步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(sync.downloadCalls, 0);
  });

  testWidgets('Supabase 未登录：显示登录行，点击跳转登录页', (tester) async {
    final sync = _FakeSyncService()
      ..status = const SyncStatus(
        diff: SyncDiff.notLoggedIn,
        localCount: 0,
        localFingerprint: '',
      );
    await _pumpSection(
      tester,
      active: _supabaseActive(),
      sync: sync,
      auth: _FakeAuth(),
    );

    expect(find.text('登录'), findsWidgets);
    expect(find.text('未登录'), findsWidgets);

    await tester.tap(find.text('登录').last);
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);

    // 返回区块：push 返回后应触发同步状态刷新 tick
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('Supabase 已登录：登出需二次确认，取消不调用 signOut', (tester) async {
    final auth = _FakeAuth(
      user: const CloudUser(id: 'u1', account: 'me@x.com'),
    );
    final sync = _FakeSyncService();
    await _pumpSection(
      tester,
      active: _supabaseActive(),
      sync: sync,
      auth: auth,
    );

    expect(find.text('me@x.com'), findsOneWidget);
    await tester.tap(find.text('me@x.com'));
    await tester.pumpAndSettle();

    expect(find.text('退出登录'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 0);
  });

  testWidgets('Supabase 已登录：确认登出后调用 signOut 并清理云端账本', (tester) async {
    final auth = _FakeAuth(
      user: const CloudUser(id: 'u1', account: 'me@x.com'),
    );
    final sync = _FakeSyncService();
    final repo = _MockRepo();
    when(() => repo.purgeAllCloudLedgers()).thenAnswer((_) async {});
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);

    await _pumpSection(
      tester,
      active: _supabaseActive(),
      sync: sync,
      auth: auth,
      extraOverrides: [
        repositoryProvider.overrideWithValue(repo),
      ],
    );

    await tester.tap(find.text('me@x.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    verify(() => repo.purgeAllCloudLedgers()).called(1);
  });

  testWidgets('自动同步开关：写入 setter 并刷新值', (tester) async {
    final sync = _FakeSyncService();
    bool? written;
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
      onAutoSync: (v) => written = v,
    );

    expect(find.text('自动同步账本'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(written, isTrue);
  });

  testWidgets('本地模式：上传/下载禁用并提示仅限云服务模式', (tester) async {
    final sync = _FakeSyncService();
    await _pumpSection(
      tester,
      active: _localActive(),
      sync: sync,
    );

    expect(find.text('仅限云服务模式可用'), findsNWidgets(2));
  });

  for (final (token, expected) in const <(String, String)>[
    ('__SYNC_NOT_CONFIGURED__', '未配置云端'),
    ('__SYNC_NOT_LOGGED_IN__', '未登录'),
    ('__SYNC_NO_CLOUD_BACKUP__', '云端暂无备份'),
    ('__SYNC_ACCESS_DENIED__', '403 拒绝访问'),
  ]) {
    testWidgets('error 消息 $token：状态行与详情弹窗均本地化', (tester) async {
      final sync = _FakeSyncService()
        ..status = SyncStatus(
          diff: SyncDiff.error,
          localCount: 0,
          localFingerprint: '',
          message: token,
        );
      await _pumpSection(
        tester,
        active: _webdavActive(),
        sync: sync,
      );

      // 状态行 subtitle 命中本地化文案
      expect(find.textContaining(expected), findsWidgets);
      // 详情弹窗 message 行同样命中本地化文案
      await tester.tap(find.textContaining(expected).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('说明: $expected'), findsOneWidget);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('状态刷新中：上传/下载副标题显示「刷新中…」', (tester) async {
    final sync = _FakeSyncService();
    final pending = Completer<SyncStatus>();
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
      cachedStatus: const SyncStatus(
        diff: SyncDiff.localNewer,
        localCount: 1,
        localFingerprint: 'fp',
      ),
      statusOverride: (ledgerId) => pending.future,
      settle: false,
    );

    expect(find.text('刷新中…'), findsNWidgets(2));
    expect(find.text('本地有更新 (本地1条, 建议上传)'), findsOneWidget);
  });

  testWidgets('上传成功后后台轮询退避直至 inSync', (tester) async {
    final sync = _FakeSyncService()
      ..pollStatuses = [SyncDiff.localNewer, SyncDiff.localNewer];
    final container = await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('上传'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('确定'));
    await tester.pump();

    // 第一次 getStatus 返回 localNewer → 等待 500ms 退避
    await tester.pump(const Duration(milliseconds: 600));
    // 第二次仍 localNewer → 等待 1s 退避
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();

    final cached = container.read(lastSyncStatusProvider(1));
    expect(cached, isNotNull);
    expect(cached!.diff, SyncDiff.inSync);
    await flushLoggerTimers(tester);
  });

  testWidgets('下载（diff 预览为 null 云端无数据）：提示导入 0 条', (tester) async {
    final sync = _FakeSyncService()
      ..supportsDiffPreview = true
      ..previewResult = null;
    await _pumpSection(
      tester,
      active: _webdavActive(),
      sync: sync,
    );

    await tester.tap(find.text('下载同步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('同步完成'), findsOneWidget);
    expect(find.text('导入：0 条'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  });

  testWidgets('Supabase 已登录但账号为空：显示「已登录」占位文案', (tester) async {
    final auth = _FakeAuth(user: const CloudUser(id: 'u1'));
    final sync = _FakeSyncService();
    await _pumpSection(
      tester,
      active: _supabaseActive(),
      sync: sync,
      auth: auth,
    );

    expect(find.text('已登录'), findsOneWidget);
    expect(find.text('点击可退出登录'), findsOneWidget);
  });

  testWidgets('登出后云端账本清理失败：toast 提示需手动处理', (tester) async {
    final auth = _FakeAuth(
      user: const CloudUser(id: 'u1', account: 'me@x.com'),
    );
    final sync = _FakeSyncService();
    final repo = _MockRepo();
    when(
      () => repo.purgeAllCloudLedgers(),
    ).thenThrow(Exception('purge boom'));
    when(() => repo.getLedgerById(any())).thenAnswer((_) async => null);
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);

    await _pumpSection(
      tester,
      active: _supabaseActive(),
      sync: sync,
      auth: auth,
      extraOverrides: [
        repositoryProvider.overrideWithValue(repo),
      ],
    );

    await tester.tap(find.text('me@x.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('云端账本清理失败，请稍后重试'), findsOneWidget);

    // toast 1s 后自动消失，冲刷其定时器
    await tester.pump(const Duration(milliseconds: 1100));
    await flushLoggerTimers(tester);
  });
}
