import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:spitout/core/logging/logger_service.dart';
import 'notification_util.dart';
import 'notification_android.dart';

/// 通知工厂类 - 根据平台创建对应的通知实现
class NotificationFactory {
  static NotificationUtil? _instance;
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 获取平台特定的通知工具实例
  static NotificationUtil getInstance() {
    if (_instance != null) return _instance!;

    if (Platform.isAndroid) {
      _instance = AndroidNotificationUtil(_plugin);
    } else {
      throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
    }

    return _instance!;
  }

  /// 测试注入点：非 Android 测试宿主（如 Windows/CI）无法创建平台通知实现，
  /// 允许测试注入内存假实现来验证业务编排，不影响生产路径。
  @visibleForTesting
  static void setInstanceForTesting(NotificationUtil? instance) {
    _instance = instance;
  }

  /// 初始化时区（必须在使用通知服务之前调用）
  static void initializeTimeZone() {
    try {
      tz.initializeTimeZones();

      // 按设备当前 UTC 偏移推导时区，不硬编码 Asia/Shanghai：
      // 整小时偏移映射到 Etc/GMT±X（注意 Etc/GMT 的符号与 UTC 偏移相反），
      // 常见的半小时/45 分钟偏移映射到对应 IANA 时区。
      // 局限：跨夏令时的地区在切换日前后会差 1 小时，完整方案需
      // flutter_timezone 读取系统 IANA 标识，这里先消除“固定北京时间”的偏差。
      final offset = DateTime.now().timeZoneOffset;
      final totalMinutes = offset.inMinutes;
      final zoneName = _resolveZoneName(totalMinutes);
      try {
        tz.setLocalLocation(tz.getLocation(zoneName));
        logger.info('NotificationFactory', '[Timezone] 设置为: $zoneName');
      } catch (e) {
        // 时区库缺少该标识时回退 UTC，避免调度直接崩溃。
        tz.setLocalLocation(tz.UTC);
        logger.warning(
          'NotificationFactory',
          '[Timezone] 无法解析 $zoneName，回退 UTC: $e',
        );
      }

      logger.info('NotificationFactory', '[Timezone] ✅ 时区初始化完成');
    } catch (e) {
      logger.warning('NotificationFactory', '[Timezone] ❌ 时区初始化失败: $e');
    }
  }

  /// 由设备 UTC 偏移（分钟）推导时区标识。
  static String _resolveZoneName(int totalMinutes) {
    if (totalMinutes == 0) return 'UTC';

    const halfHourZones = <int, String>{
      3 * 60 + 30: 'Asia/Tehran',
      4 * 60 + 30: 'Asia/Kabul',
      5 * 60 + 30: 'Asia/Kolkata',
      5 * 60 + 45: 'Asia/Kathmandu',
      6 * 60 + 30: 'Asia/Yangon',
      9 * 60 + 30: 'Australia/Darwin',
      8 * 60 + 45: 'Australia/Eucla',
      -(3 * 60 + 30): 'America/St_Johns',
      -(9 * 60 + 30): 'Pacific/Marquesas',
    };
    final mapped = halfHourZones[totalMinutes];
    if (mapped != null) return mapped;

    if (totalMinutes % 60 == 0) {
      final hours = totalMinutes ~/ 60;
      // Etc/GMT 的符号与 UTC 偏移相反：UTC+8 → Etc/GMT-8。
      final sign = hours >= 0 ? '-' : '+';
      return 'Etc/GMT$sign${hours.abs()}';
    }
    // 无法映射的非常规偏移回退 UTC（极端罕见）。
    return 'UTC';
  }

  /// 重置实例（用于测试）
  static void reset() {
    _instance = null;
  }
}
