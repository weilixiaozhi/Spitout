/// 记账提醒相关持久化键与通知 ID 的统一常量。
///
/// 设计意图：providers / main / 提醒监控服务 / 配置导入导出多处读写同一组
/// prefs 键与通知 ID，字符串散落会导致改名时静默失联（如安全模块
/// app_lock_* 的教训）。集中定义后所有调用方引用同一常量，键值字符串只
/// 在这里出现一次。
class ReminderPrefs {
  const ReminderPrefs._();

  /// 提醒开关键。
  static const String enabled = 'reminder_enabled';

  /// 提醒小时键（0-23）。
  static const String hour = 'reminder_hour';

  /// 提醒分钟键（0-59）。
  static const String minute = 'reminder_minute';

  /// 每日提醒主通知 ID。
  ///
  /// 与 Android 实现的约定绑定：7 天备用提醒占 `id+1..id+7`，
  /// AlarmManager 备用占 `id+100`。取消 / 重建时必须带同一主 ID，
  /// 否则旧备用通知会残留旧时间。
  static const int mainNotificationId = 1001;
}
