// 通知工厂平台分支测试。
//
// 设计意图：App 仅面向 Android（仓库无 ios/ 目录），非 Android 测试宿主上
// getInstance 应明确抛 UnsupportedError；测试注入点 setInstanceForTesting
// 让业务编排可在任意平台验证；时区初始化不抛异常。

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show PendingNotificationRequest;
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/services/notification/notification_factory.dart';
import 'package:spitout/services/notification/notification_util.dart';

import '../../helpers/test_isolation.dart';

class _FakeUtil extends NotificationUtil {
  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<bool> checkPermissionStatus() async => true;

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async =>
      const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> scheduleOnceReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {}

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetGlobalTestState);

  test('非 Android 平台 getInstance 抛 UnsupportedError', () {
    if (Platform.isAndroid) {
      // Android 真机/模拟器上走正常分支，跳过本断言
      return;
    }
    expect(NotificationFactory.getInstance, throwsUnsupportedError);
  });

  test('setInstanceForTesting 注入后 getInstance 返回 fake；reset 清空', () async {
    NotificationFactory.setInstanceForTesting(_FakeUtil());
    expect(NotificationFactory.getInstance(), isA<_FakeUtil>());

    NotificationFactory.reset();
    if (!Platform.isAndroid) {
      expect(NotificationFactory.getInstance, throwsUnsupportedError);
    }
  });

  test('initializeTimeZone 不抛异常', () {
    // 时区库初始化应幂等且安全
    NotificationFactory.initializeTimeZone();
    NotificationFactory.initializeTimeZone();
  });
}
