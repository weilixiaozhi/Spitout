// 设置类二级页面测试：语言、外观（主题/支出配色/语言导航）、应用锁、
// 提醒设置、日志中心。
//
// 用 ProviderContainer + 真实 SharedPreferences mock，验证页面渲染、交互后
// provider 状态与持久化落盘，以及页面间导航。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show PendingNotificationRequest;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/auth/pin_setup_page.dart';
import 'package:spitout/pages/settings/app_lock_settings_page.dart';
import 'package:spitout/pages/settings/appearance_settings_page.dart';
import 'package:spitout/pages/settings/config_import_export_page.dart';
import 'package:spitout/pages/settings/language_settings_page.dart';
import 'package:spitout/pages/settings/log_center_page.dart';
import 'package:spitout/pages/settings/reminder_settings_page.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/security/app_lock_service.dart';
import 'package:spitout/services/notification/notification_factory.dart';
import 'package:spitout/services/notification/notification_util.dart';
import 'package:spitout/services/notification/reminder_constants.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/wheel_time_picker.dart';

import '../../helpers/test_isolation.dart';

/// 内存假通知实现：不触碰平台通道，仅记录调用。
class _FakeNotificationUtil extends NotificationUtil {
  final List<String> calls = [];

  @override
  Future<void> cancelAllNotifications() async => calls.add('cancelAll');

  @override
  Future<void> cancelNotification(int id) async => calls.add('cancel:$id');

  @override
  Future<bool> checkPermissionStatus() async => true;

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async =>
      const [];

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  Future<bool> requestPermissions() async {
    calls.add('requestPermissions');
    return true;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    calls.add('daily:$id');
  }

  @override
  Future<void> scheduleOnceReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    calls.add('once:$id');
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    calls.add('show:$id');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() {
    resetGlobalTestState();
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async => db.close());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pump();
  }

  /// 在数字键盘上依次输入 PIN 数字。
  Future<void> enterPinDigits(WidgetTester tester, String pin) async {
    for (final ch in pin.split('')) {
      await tester.tap(find.text(ch));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 应用锁已开启的初始环境：真实 prefs 写入 PIN，provider 同步为开启。
  Future<void> seedAppLockEnabled() async {
    await AppLockService.setPin('1234');
    container.read(appLockEnabledProvider.notifier).set(true);
  }

  group('LanguageSettingsPage', () {
    testWidgets('渲染全部语言项；选择中文/跟随系统并持久化', (tester) async {
      await pumpPage(tester, const LanguageSettingsPage());

      expect(find.text('中文'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('한국어'), findsOneWidget);

      // 选择简体中文 → provider 状态 + prefs 落盘
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(container.read(languageProvider), const Locale('zh'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_language'), 'zh');

      // 切回跟随系统
      await tester.tap(find.text('跟随系统'));
      await tester.pumpAndSettle();
      expect(container.read(languageProvider), isNull);
      expect(prefs.getString('selected_language'), isNull);
    });
  });

  group('AppearanceSettingsPage', () {
    testWidgets('渲染外观项；切换支出配色方案并持久化', (tester) async {
      await pumpPage(tester, const AppearanceSettingsPage());
      // 激活持久化监听（真实应用中由 app 根节点 watch 该 init provider）
      container.read(expenseColorSchemeInitProvider);

      // 默认红色方案
      expect(container.read(expenseColorSchemeProvider), 'red');

      // 打开配色对话框并选绿色
      await tester.tap(find.text('支出颜色'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('绿色表示支出'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      // 保存后 1s 弱化 loading + toast，推进时间落定
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));

      expect(container.read(expenseColorSchemeProvider), 'green');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('expenseColorScheme'), 'green');
    });

    testWidgets('主题模式对话框：切到深色', (tester) async {
      await pumpPage(tester, const AppearanceSettingsPage());

      expect(container.read(themeModeProvider), ThemeMode.system);
      await tester.tap(find.text('深色模式'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('暗黑模式'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    testWidgets('点击「应用语言」导航到语言设置页', (tester) async {
      await pumpPage(tester, const AppearanceSettingsPage());

      await tester.tap(find.text('应用语言'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageSettingsPage), findsOneWidget);
    });
  });

  group('AppLockSettingsPage', () {
    testWidgets('开启应用锁 → 跳转 PIN 设置页', (tester) async {
      await pumpPage(tester, const AppLockSettingsPage());

      expect(find.text('应用上锁'), findsWidgets);
      // 开关初始关闭；点击开关触发 PIN 设置导航
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.byType(PinSetupPage), findsOneWidget);
    });

    testWidgets('开启全流程：设置 PIN 后开启并持久化，展示管理区段', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpPage(tester, const AppLockSettingsPage());
      expect(container.read(appLockEnabledProvider), isFalse);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.byType(PinSetupPage), findsOneWidget);

      // create 模式：首次输入 + 二次确认
      await enterPinDigits(tester, '1234');
      await tester.pumpAndSettle();
      await enterPinDigits(tester, '1234');
      await tester.pumpAndSettle();

      expect(container.read(appLockEnabledProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppLockService.prefsKeyEnabled), isTrue);
      // 已开启后展示 PIN 管理与超时区段
      expect(find.text('修改密码'), findsOneWidget);
      expect(find.text('自动锁定时间'), findsOneWidget);
      // 冲刷 PIN 设置 toast(1s)与 LoggerService 保存定时器(2s)
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('关闭应用锁：验证当前 PIN 成功后关闭并提示', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await seedAppLockEnabled();
      await pumpPage(tester, const AppLockSettingsPage());
      expect(container.read(appLockEnabledProvider), isTrue);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('请输入当前密码'), findsOneWidget);

      // 输错 → 错误态并自动清空
      await enterPinDigits(tester, '0000');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));

      // 输入正确 PIN → 关闭成功
      await enterPinDigits(tester, '1234');
      await tester.pumpAndSettle();

      expect(container.read(appLockEnabledProvider), isFalse);
      expect(find.text('应用锁已关闭'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppLockService.prefsKeyPinHash), isNull);
      await tester.pump(const Duration(seconds: 2)); // toast 定时器
    });

    testWidgets('修改密码：跳转 PIN 修改页并可返回', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await seedAppLockEnabled();
      await pumpPage(tester, const AppLockSettingsPage());

      await tester.tap(find.text('修改密码'));
      await tester.pumpAndSettle();
      expect(find.byType(PinSetupPage), findsOneWidget);

      // PrimaryHeader 自定义返回按钮
      await tester.tap(find.byIcon(AppIcons.back));
      await tester.pumpAndSettle();
      expect(find.text('应用上锁'), findsOneWidget);
      // 冲刷 seedAppLockEnabled 触发的 LoggerService 保存定时器(2s)
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('超时设置：底部弹层选择 1 分钟后并持久化', (tester) async {
      await seedAppLockEnabled();
      await pumpPage(tester, const AppLockSettingsPage());

      await tester.tap(find.text('自动锁定时间'));
      await tester.pumpAndSettle();
      expect(find.text('1分钟后'), findsOneWidget);

      await tester.tap(find.text('1分钟后'));
      await tester.pumpAndSettle();

      expect(container.read(appLockTimeoutProvider), 60);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppLockService.prefsKeyTimeoutSeconds), 60);
      // 冲刷 seedAppLockEnabled 触发的 LoggerService 保存定时器(2s)
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('ReminderSettingsPage', () {
    testWidgets('开关提醒并持久化；时间行弹出滚轮选择', (tester) async {
      final fakeNotifications = _FakeNotificationUtil();
      NotificationFactory.setInstanceForTesting(fakeNotifications);
      await pumpPage(tester, const ReminderSettingsPage());

      expect(container.read(reminderSettingsProvider).isEnabled, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(container.read(reminderSettingsProvider).isEnabled, isTrue);
      expect(fakeNotifications.calls, contains('requestPermissions'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('reminder_enabled'), isTrue);

      // 时间行 → 滚轮选择器
      await tester.tap(find.text('提醒时间'));
      await tester.pumpAndSettle();
      expect(find.byType(WheelTimePicker), findsOneWidget);
    });

    testWidgets('时间滚轮确定后更新并持久化', (tester) async {
      final fakeNotifications = _FakeNotificationUtil();
      NotificationFactory.setInstanceForTesting(fakeNotifications);
      await pumpPage(tester, const ReminderSettingsPage());

      await tester.tap(find.text('提醒时间'));
      await tester.pumpAndSettle();
      expect(find.byType(WheelTimePicker), findsOneWidget);

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(ReminderPrefs.hour), isNotNull);
      expect(prefs.getInt(ReminderPrefs.minute), isNotNull);
    });

    testWidgets('发送测试通知：调用通知服务并提示', (tester) async {
      final fakeNotifications = _FakeNotificationUtil();
      NotificationFactory.setInstanceForTesting(fakeNotifications);
      await pumpPage(tester, const ReminderSettingsPage());

      await tester.tap(find.text('发送测试通知'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeNotifications.calls, contains('show:9999'));
      expect(find.text('测试通知已发送'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2)); // toast 定时器
    });
  });

  group('LogCenterPage', () {
    testWidgets('渲染日志并按关键词过滤', (tester) async {
      // 预置一条唯一标记的日志，供搜索断言
      logger.info('settings_test_marker', '独特的日志内容 marker_unique_123');
      await pumpPage(tester, const LogCenterPage());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('日志中心'), findsOneWidget);
      expect(find.textContaining('marker_unique_123'), findsOneWidget);

      // 搜索不存在的关键词 → 列表为空
      await tester.enterText(
        find.byType(TextField),
        'no_such_marker_zzz',
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('marker_unique_123'), findsNothing);

      // 清空关键词 → 日志恢复显示
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('marker_unique_123'), findsOneWidget);

      // flush LoggerService 加载日志时调度的 2s 保存定时器
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('日志条目详情对话框与复制', (tester) async {
      logger.info('tag_detail', 'detail_marker_xyz');
      await pumpPage(tester, const LogCenterPage());
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.textContaining('detail_marker_xyz'));
      await tester.pumpAndSettle();
      expect(find.text('[tag_detail]'), findsWidgets);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);

      await tester.tap(find.text('复制'));
      await tester.pump();
      expect(find.text('已复制到剪贴板'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // 长按条目直接复制
      await tester.longPress(find.textContaining('detail_marker_xyz'));
      await tester.pump();
      expect(find.text('已复制到剪贴板'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3)); // toast + 保存定时器
    });

    testWidgets('级别过滤与搜索清除按钮', (tester) async {
      logger.info('tag_i', 'info_marker_1');
      logger.warning('tag_w', 'warn_marker_2');
      await pumpPage(tester, const LogCenterPage());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('info_marker_1'), findsOneWidget);
      expect(find.textContaining('warn_marker_2'), findsOneWidget);

      // 取消选中 INFO 级别 → 该级别日志隐藏
      await tester.tap(find.widgetWithText(FilterChip, 'INFO'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('info_marker_1'), findsNothing);
      expect(find.textContaining('warn_marker_2'), findsOneWidget);

      // 搜索后点清除按钮恢复
      await tester.enterText(find.byType(TextField), 'no_such');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('warn_marker_2'), findsNothing);
      await tester.tap(find.byIcon(AppIcons.close));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('warn_marker_2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('清空日志：取消保留，确认后清空并提示', (tester) async {
      logger.info('tag_clear', 'to_be_cleared_marker');
      await pumpPage(tester, const LogCenterPage());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('to_be_cleared_marker'), findsOneWidget);

      // 取消 → 日志保留
      await tester.tap(find.byTooltip('清空'));
      await tester.pumpAndSettle();
      expect(find.text('确定要清空所有日志吗？此操作不可恢复。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.textContaining('to_be_cleared_marker'), findsOneWidget);

      // 确认 → 清空并提示
      await tester.tap(find.byTooltip('清空'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('日志已清空'), findsOneWidget);
      // 日志监听 500ms 防抖后重建为空态
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('暂无日志'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('导出日志：平台通道不可用时提示失败', (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'unavailable'),
      );
      addTearDown(() => binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      logger.info('tag_export', 'export_marker');
      await pumpPage(tester, const LogCenterPage());
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byTooltip('导出'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('导出失败'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('ConfigImportExportPage', () {
    testWidgets('导出配置：选项对话框 → 预览 → 取消（不落盘）', (tester) async {
      await pumpPage(tester, const ConfigImportExportPage());

      expect(find.text('导出配置'), findsOneWidget);
      expect(find.text('导入配置'), findsOneWidget);

      // 打开导出选项对话框
      await tester.tap(find.text('导出配置'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('账本'), findsWidgets);

      // 默认全选，直接下一步 → 生成 YAML 预览
      await tester.tap(find.text('下一步'));
      // 导出中 tile 会显示旋转指示器，pumpAndSettle 永不落定，用显式 pump
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('导出预览'), findsOneWidget);
      // 预览区是可选中 YAML 文本
      expect(find.byType(SelectableText), findsOneWidget);

      // 取消导出：不写文件、回到页面
      await tester.tap(find.text('取消'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('导出配置'), findsOneWidget);
    });
  });
}
