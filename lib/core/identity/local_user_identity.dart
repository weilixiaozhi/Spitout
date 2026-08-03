import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../logging/logger_service.dart';

/// 本地设备身份（localSelfId）持久化服务。
///
/// 设计意图：未登录云时，本地账本的「我」需要一个稳定的标识，
/// 用于 paidByUserId / createdByUserId / lastEditedByUserId /
/// ledger.ownerUserId 等字段。历史上用字面量 'me' 占位，但它会
/// 在界面上泄漏、且无法被登录后迁移覆盖。现在改为持久化的真 UUID，
/// 每台设备首次启动生成一次、写入 SharedPreferences，此后稳定不变。
///
/// 与云身份的关系（方案 B）：
/// - 未登录：所有作者字段写 localSelfId。
/// - 已登录：新数据写云 userId；首次登录时通过迁移服务把历史的
///   localSelfId 一次性改写为云 userId。
/// - 登出后：新记的账重新写 localSelfId（同一账本可能出现 localSelfId
///   与云 userId 混存，由展示层统一解析为昵称/「我」）。
class LocalSelfId {
  LocalSelfId._();

  /// SharedPreferences 存储 key。
  static const String prefsKey = 'local_self_id';

  static const _uuid = Uuid();

  /// 读取或生成 localSelfId。
  ///
  /// 首次调用时 prefs 无值 → 生成 UUID 并持久化；后续直接返回已存值。
  /// 生成与写入不在同一事务内，极端情况下（写入前进程被杀）下次启动
  /// 会重新生成新 UUID，不影响正确性（此时库中尚无引用旧值的数据）。
  static Future<String> getOrCreate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(prefsKey);
      if (existing != null && existing.isNotEmpty) return existing;
      final generated = _uuid.v4();
      await prefs.setString(prefsKey, generated);
      logger.info('LocalSelfId', '首次生成 localSelfId');
      return generated;
    } catch (e, st) {
      // prefs 不可用时退化为内存 UUID（不持久化，仅本次运行有效）。
      // 这种情况极罕见，展示层仍可正常工作，下次启动重新生成。
      logger.error('LocalSelfId', '读取/写入 prefs 失败，退化为内存 UUID', e, st);
      return _uuid.v4();
    }
  }

  /// 读取已持久化的 localSelfId（不生成）。
  ///
  /// 供备份/恢复等「只读不写」场景使用；未设置时返回 null。
  static Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefsKey);
    } catch (e, st) {
      logger.warning('LocalSelfId', '读取 prefs 失败', '$e\n$st');
      return null;
    }
  }

  /// 写入指定 localSelfId（恢复备份用）。
  ///
  /// 仅当当前无值时写入，避免覆盖设备已有身份导致旧记录解析错位。
  static Future<void> restoreIfAbsent(String value) async {
    if (value.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(prefsKey);
      if (existing == null || existing.isEmpty) {
        await prefs.setString(prefsKey, value);
        logger.info('LocalSelfId', '从备份恢复 localSelfId');
      }
    } catch (e, st) {
      logger.warning('LocalSelfId', '恢复 localSelfId 失败', '$e\n$st');
    }
  }
}

/// 全局 localSelfId Provider。
///
/// 非 autoDispose：设备身份在 app 生命周期内不变，缓存一次即可。
/// 首次 await 时触发生成与持久化，后续读取走缓存。
final localSelfIdProvider = FutureProvider<String>((ref) async {
  return LocalSelfId.getOrCreate();
});
