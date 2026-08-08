// 设置类二级页面测试：语言、外观（主题/支出配色/语言导航）、应用锁、
// 提醒设置、日志中心。
//
// 用 ProviderContainer + 真实 SharedPreferences mock，验证页面渲染、交互后
// provider 状态与持久化落盘，以及页面间导航。

import 'package:flutter/material.dart';
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
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/services/notification/notification_factory.dart';
import 'package:spitout/services/notification/notification_util.dart';
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
