// 记账提醒设置 provider 测试。
//
// 需求锚点：
//   1. ReminderSettings 默认 21:00 关闭、copyWith、timeString、相等语义；
//   2. 从 prefs 恢复设置；
//   3. updateEnabled/updateTime/updateSettings 持久化并编排通知（注入假 NotificationUtil）；
//   4. 开启时请求权限并调度每日提醒；关闭时取消通知。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_isolation.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/notification/notification_factory.dart';
import 'package:spitout/services/notification/reminder_constants.dart';
import 'package:spitout/services/notification/notification_util.dart';

class _FakeNotificationUtil extends Fake implements NotificationUtil {
  int requestCount = 0;
  final scheduled = <String>[];
  final cancelled = <int>[];

  @override
  Future<bool> requestPermissions() async {
    requestCount++;
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
    scheduled.add('$id:$hour:$minute');
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelled.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotificationUtil notifications;

  setUp(() {
    resetGlobalTestState();
    notifications = _FakeNotificationUtil();
    NotificationFactory.setInstanceForTesting(notifications);
  });

  tearDown(() => NotificationFactory.reset());

  test('ReminderSettings 默认值/copyWith/timeString/相等', () {
    final d = ReminderSettings.defaultSettings();
    expect(d.isEnabled, isFalse);
    expect(d.hour, 21);
    expect(d.minute, 0);
    expect(d.timeString, '21:00');

    final changed = d.copyWith(isEnabled: true, hour: 8, minute: 30);
    expect(changed.timeString, '08:30');
    expect(changed == d, isFalse);
    expect(d.copyWith(), d);
  });

  test('从 prefs 恢复设置', () async {
    SharedPreferences.setMockInitialValues({
      ReminderPrefs.enabled: true,
      ReminderPrefs.hour: 8,
      ReminderPrefs.minute: 30,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(reminderSettingsProvider).isEnabled, isFalse,
        reason: '先同步返回默认值');
    await Future<void>.delayed(Duration.zero);
    final settings = container.read(reminderSettingsProvider);
    expect(settings.isEnabled, isTrue);
    expect(settings.hour, 8);
    expect(settings.minute, 30);
  });

  test('updateEnabled(true) 请求权限并调度提醒；updateEnabled(false) 取消', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(reminderSettingsProvider.notifier);

    await notifier.updateEnabled(true);
    expect(notifications.requestCount, 1);
    expect(notifications.scheduled.single, contains('21:0'));

    await notifier.updateEnabled(false);
    expect(notifications.cancelled, [ReminderPrefs.mainNotificationId]);
  });

  test('updateTime 持久化并在开启时重排通知', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(reminderSettingsProvider.notifier);

    await notifier.updateTime(8, 30);
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ReminderPrefs.hour), 8);
    expect(notifications.cancelled, isEmpty, reason: '未开启时只保存时间');

    await notifier.updateEnabled(true);
    await notifier.updateTime(9, 15);
    expect(notifications.scheduled.last, contains('9:15'));
  });

  test('updateSettings 整包应用', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(reminderSettingsProvider.notifier);

    await notifier.updateSettings(
      const ReminderSettings(isEnabled: true, hour: 7, minute: 45),
    );
    expect(container.read(reminderSettingsProvider).timeString, '07:45');
    expect(notifications.scheduled.single, contains('7:45'));
  });
}
