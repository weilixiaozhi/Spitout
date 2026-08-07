/// 本地存储页（LocalBackupPage）组件测试。
///
/// 覆盖：页面渲染（标题/开关默认开/引导文案/空态）、开关写 prefs、
/// 备份列表渲染与恢复二次确认弹窗（取消分支）。
/// 恢复成功路径的数据回滚由 local_backup_service_test.dart 在文件级覆盖。
///
/// 架构说明：使用 StubLocalBackupService 完全替换真实文件 IO，
/// 避免 FutureBuilder + dart:io 在 fake async zone 中永不完成导致的
/// pumpAndSettle 卡死问题。桩服务不触碰磁盘，直接通过 pumpAndSettle 验收。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/settings/local_backup_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/backup/local_backup_service.dart';
import '../../helpers/test_isolation.dart';

// =============================================================================
// 桩服务与测试工具
// =============================================================================

/// 不触碰磁盘的内存桩服务。
///
/// 设计意图：Flutter 测试的 fake async zone 无法处理 dart:io 真实文件 IO，
/// FutureBuilder 的 future 会永远 pending 导致 pumpAndSettle 超时卡死。
/// 本桩将所有 IO 方法替换为内存同步返回，消除卡死根因且不产生磁盘污染。
class StubLocalBackupService extends LocalBackupService {
  final List<LocalBackupFile> _stubList;

  /// listBackups 被调用次数：用于断言下拉刷新 / resume 触发了重读。
  int listBackupsCalls = 0;

  /// [backups] 控制 listBackups 返回的桩数据，默认空列表（空态）。
  StubLocalBackupService({List<LocalBackupFile>? backups})
    : _stubList = backups ?? [],
      super();

  @override
  Future<List<LocalBackupFile>> listBackups() async {
    listBackupsCalls++;
    return List.unmodifiable(_stubList);
  }

  @override
  Future<File> createBackup({
    required SpitoutDatabase db,
    String filePrefix = LocalBackupService.backupPrefix,
    String? localSelfId,
  }) async {
    throw UnimplementedError('widget test 桩：不应在 UI 测试中写盘');
  }

  @override
  Future<RestoreResult> restoreFromBackup({
    required SpitoutDatabase db,
    required File backupFile,
    Future<void> Function(String localSelfId)? onRestoredLocalSelfId,
  }) async {
    throw UnimplementedError('widget test 桩：不应在 UI 测试中执行恢复');
  }

  @override
  Future<RestoreStatus?> validateBackup(
    File backupFile,
    int currentSchemaVersion,
  ) async {
    // 桩：校验总是通过，不打开 sqlite 连接
    return null;
  }

  @override
  Future<void> pruneBackups() async {}

  @override
  Future<Directory> backupDirectory() async {
    return Directory.systemTemp.createTempSync('stub_backup_');
  }

  @override
  Future<File> databaseFile() async {
    return File('/stub/spitout.sqlite');
  }
}

/// 构造测试用 LocalBackupFile（不触碰磁盘，仅提供展示所需字段）。
///
/// [fileName] 包含扩展名，如 'spitout_backup_20260702_090000.sqlite'。
/// [sizeBytes] 默认 1024（展示为 1.0 KB）。
LocalBackupFile stubBackupFile(
  String fileName, {
  int sizeBytes = 1024,
  DateTime? createdAt,
}) {
  return LocalBackupFile(
    file: File('/stub/$fileName'),
    createdAt: createdAt ?? DateTime(2026, 7, 2, 9, 0),
    sizeBytes: sizeBytes,
  );
}

/// 挂载页面并 override 备份服务为桩服务。
///
/// 桩不碰磁盘，FutureBuilder 的 future 在 fake async zone 中立即完成，
/// pumpAndSettle 可正常收敛。
Future<void> _pumpPage(
  WidgetTester tester, {
  required LocalBackupService service,
  bool showOldBackupLink = true,
  Future<void> Function()? requestAllFilesAccess,
  Future<bool> Function()? allFilesAccessChecker,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localBackupServiceProvider.overrideWithValue(service),
        showOldBackupLinkProvider.overrideWithValue(showOldBackupLink),
        allFilesAccessCheckerProvider.overrideWithValue(
          allFilesAccessChecker ?? () async => false,
        ),
        if (requestAllFilesAccess != null)
          requestAllFilesAccessProvider.overrideWithValue(
            requestAllFilesAccess,
          ),
      ],
      child: MaterialApp(
        // 强制 zh 渲染中文文案（测试环境默认 en）
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LocalBackupPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// =============================================================================
// 测试用例
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  testWidgets('页面渲染：标题 / 开关默认开 / 引导文案 / 空态 / 立即备份按钮', (tester) async {
    await _pumpPage(tester, service: StubLocalBackupService());

    expect(find.text('本地存储'), findsOneWidget);
    expect(find.text('自动本地备份'), findsOneWidget);
    expect(find.text('每天首次打开应用时自动备份数据库快照'), findsOneWidget);
    expect(find.text('选择一个数据进行恢复：'), findsOneWidget);
    // 桩返回空列表 → 空态文案
    expect(find.text('暂无备份'), findsOneWidget);

    // 开关默认开（prefs 无记录时按 true 兜底，零干预保护数据）
    final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.value, isTrue);
  });

  testWidgets('关闭开关后写入 SharedPreferences', (tester) async {
    await _pumpPage(tester, service: StubLocalBackupService());

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LocalBackupService.prefsKeyAutoBackup), isFalse);
    // UI 同步为关
    final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.value, isFalse);
  });

  testWidgets('备份列表渲染文件名与大小，点击弹出恢复二次确认，取消不动数据', (tester) async {
    // 桩注入两个假备份（文件名大小与真实格式一致，不碰磁盘）
    final service = StubLocalBackupService(
      backups: [
        stubBackupFile('spitout_backup_20260701_090000.sqlite'),
        stubBackupFile('spitout_backup_20260702_090000.sqlite'),
      ],
    );

    await _pumpPage(tester, service: service);

    // 按时间戳倒序展示（listBackups 桩保持插入顺序，调用方负责排序）
    expect(find.text('spitout_backup_20260702_090000.sqlite'), findsOneWidget);
    expect(find.text('spitout_backup_20260701_090000.sqlite'), findsOneWidget);
    expect(find.text('1.0 KB'), findsNWidgets(2));
    expect(find.text('暂无备份'), findsNothing);

    // 点击快照 → 二次确认对话框（防误触，必须显式选择）
    await tester.tap(find.text('spitout_backup_20260702_090000.sqlite'));
    await tester.pumpAndSettle();
    expect(find.text('恢复备份'), findsOneWidget);
    expect(find.text('恢复将覆盖当前全部数据且不可逆，是否继续？'), findsOneWidget);

    // 取消 → 对话框关闭，不发生任何恢复动作
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('恢复备份'), findsNothing);
    // 列表仍在、当前页未退出
    expect(find.text('spitout_backup_20260702_090000.sqlite'), findsOneWidget);
  });

  testWidgets('找回旧备份入口：点击弹出说明弹窗，「去开启」拉起系统权限并关闭弹窗', (tester) async {
    var grantCalls = 0;
    await _pumpPage(
      tester,
      service: StubLocalBackupService(),
      requestAllFilesAccess: () async => grantCalls++,
    );

    // 入口文字链常驻渲染
    expect(find.text('看不到旧版本备份？'), findsOneWidget);
    // 链接所在行水平居中
    final linkAlign = tester.widget<Align>(
      find
          .ancestor(of: find.text('看不到旧版本备份？'), matching: find.byType(Align))
          .first,
    );
    expect(linkAlign.alignment, Alignment.center);

    await tester.tap(find.text('看不到旧版本备份？'));
    await tester.pumpAndSettle();

    // 说明弹窗：标题 + 原因/方法/安全三块 + 两个操作按钮
    expect(find.text('找回旧版本备份'), findsOneWidget);
    expect(find.text('为什么看不到？'), findsOneWidget);
    expect(find.text('怎么找回？'), findsOneWidget);
    expect(find.text('安全说明'), findsOneWidget);
    expect(find.text('去开启'), findsOneWidget);
    expect(find.text('暂不'), findsOneWidget);

    // 主按钮拉起系统授权动作（页面不直接触碰 permission_handler）
    await tester.tap(find.text('去开启'));
    await tester.pumpAndSettle();

    expect(grantCalls, 1);
    expect(find.text('找回旧版本备份'), findsNothing);
  });

  testWidgets('权限已开启时弹窗主按钮显示「已开启」且不拉起权限', (tester) async {
    var grantCalls = 0;
    await _pumpPage(
      tester,
      service: StubLocalBackupService(),
      requestAllFilesAccess: () async => grantCalls++,
      allFilesAccessChecker: () async => true,
    );

    await tester.tap(find.text('看不到旧版本备份？'));
    await tester.pumpAndSettle();

    // 已开启：主按钮为「已开启」，不出现「去开启」
    expect(find.text('已开启'), findsOneWidget);
    expect(find.text('去开启'), findsNothing);

    // 已开启按钮不可点击：点击后弹窗仍在、不拉起权限
    await tester.tap(find.text('已开启'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(grantCalls, 0);
    expect(find.text('找回旧版本备份'), findsOneWidget);
  });

  testWidgets('找回旧备份弹窗：点「暂不」关闭弹窗且不拉起权限', (tester) async {
    var grantCalls = 0;
    await _pumpPage(
      tester,
      service: StubLocalBackupService(),
      requestAllFilesAccess: () async => grantCalls++,
    );

    await tester.tap(find.text('看不到旧版本备份？'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暂不'));
    await tester.pumpAndSettle();

    expect(grantCalls, 0);
    expect(find.text('找回旧版本备份'), findsNothing);
  });

  testWidgets('非 Android 平台不展示找回旧备份入口', (tester) async {
    await _pumpPage(
      tester,
      service: StubLocalBackupService(),
      showOldBackupLink: false,
    );

    expect(find.text('看不到旧版本备份？'), findsNothing);
  });

  testWidgets('下拉刷新重新拉取备份列表', (tester) async {
    final service = StubLocalBackupService();
    await _pumpPage(tester, service: service);

    // 首次进入页面拉取一次
    expect(service.listBackupsCalls, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(service.listBackupsCalls, 2);
  });

  testWidgets('从系统设置返回（resume）自动刷新备份列表', (tester) async {
    final service = StubLocalBackupService();
    await _pumpPage(tester, service: service);

    expect(service.listBackupsCalls, 1);

    // 模拟跳系统设置授权后回到应用：paused -> resumed
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(service.listBackupsCalls, 2);
  });
}
