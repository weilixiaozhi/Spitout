import 'package:drift/drift.dart' as d;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_service.dart';
import '../../data/db.dart';
import '../../data/repositories/support/change_recorder.dart';
import 'seed_service.dart';

/// 分类图标升级迁移（Layer 2 数据迁移）。
///
/// 背景：订阅服务与转账的默认图标分别为 repeat（循环箭头）和
/// arrowLeftRight（双向箭头），视觉上高度相似且与其他语义撞车。
/// 新版本已将默认图标改为 calendarClock / handCoins（见 seed_service
/// getDefaultIcon），但已安装用户的 categories 表仍持久化旧图标名，
/// 需要一次性按确定性 syncId 回写。
///
/// 为什么走 Layer 2 而不是 schema onUpgrade：
/// - 仅更新业务数据、无 DDL，schema 结构未变；
/// - 仓库约定“按新规则转换旧数据”的业务迁移放独立 MigrationService；
/// - onUpgrade 在数据层、不持有 SharedPreferences，幂等标记放这里。
///
/// 幂等：写 prefs 标记位 + UPDATE 带 WHERE 守卫（icon = 旧值），
/// 手动换过图标的分类不会被覆盖；启动时若发现仍残留旧图标会再次修复，
/// 避免一次性迁移被云同步回拉旧数据后永久失效。
class CategoryIconMigrationService {
  CategoryIconMigrationService._();

  static const String _migratedKey = 'category_icon_migration_sub_transfer_v1';

  /// 要迁移的分类 key → (旧图标, 新图标)。
  static const Map<String, ({String oldIcon, String newIcon})> _iconChanges = {
    'subscription': (oldIcon: 'repeat', newIcon: 'calendarClock'),
    'transfer': (oldIcon: 'arrowLeftRight', newIcon: 'handCoins'),
  };

  /// 按确定性 syncId 把存量默认分类的旧图标回写为新图标。
  ///
  /// - [db] 本地数据库实例。
  /// - [changeRecorder] 变更登记端口；由 providers 层按当前云后端注入，
  ///   为 null 时跳过登记（与仓库“未注入即空实现”的语义一致）。
  static Future<void> migrate({
    required SpitoutDatabase db,
    ChangeRecorder? changeRecorder,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // 快速路径：迁移已执行过且当前没有残留旧图标才跳过。
    // 不能只依赖标记位——迁移结果可能被云同步 pull 回写旧值覆盖，
    // 此时必须允许再次修复，否则升级后图标会一直停留在旧状态。
    if (prefs.getBool(_migratedKey) == true && !await _hasStaleIcons(db)) {
      return;
    }

    logger.info('CategoryIconMigration', '开始迁移订阅/转账分类图标');

    try {
      await db.transaction(() async {
        for (final entry in _iconChanges.entries) {
          final syncId = SeedService.deterministicCategorySyncId(
            kind: 'expense',
            level: 1,
            key: entry.key,
          );
          final oldIcon = entry.value.oldIcon;
          final newIcon = entry.value.newIcon;

          // 1) 主表：只更新仍是旧图标的默认分类
          final rows = await (db.select(db.categories)
                ..where((c) =>
                    c.syncId.equals(syncId) & c.icon.equals(oldIcon)))
              .get();

          // 2) 共享账本镜像表（Editor 本地缓存，随 Owner 推送后收敛）
          final mirrorUpdated = await (db.update(db.sharedLedgerCategories)
                ..where((s) =>
                    s.syncId.equals(syncId) & s.icon.equals(oldIcon)))
              .write(SharedLedgerCategoriesCompanion(icon: d.Value(newIcon)));
          if (mirrorUpdated > 0) {
            logger.info(
                'CategoryIconMigration', '共享账本镜像表修复 $mirrorUpdated 行');
          }

          if (rows.isEmpty) continue;

          await (db.update(db.categories)
                ..where((c) =>
                    c.syncId.equals(syncId) & c.icon.equals(oldIcon)))
              .write(CategoriesCompanion(icon: d.Value(newIcon)));

          // 3) 登记 user-global 待推送变更（ledgerId=0），让云端也拿到新图标；
          //    已有未推送 change 时不重复登记；登记统一走 ChangeRecorder 端口。
          for (final row in rows) {
            final existing = await (db.select(db.localChanges)
                  ..where((c) =>
                      c.entityType.equals('category') &
                      c.entitySyncId.equals(syncId) &
                      c.pushedAt.isNull())
                  ..limit(1))
                .getSingleOrNull();
            if (existing != null) continue;

            await changeRecorder?.recordUserGlobalChange(
              entityType: 'category',
              entityId: row.id,
              entitySyncId: syncId,
              action: 'update',
            );
          }
        }
      });

      await prefs.setBool(_migratedKey, true);
      logger.info('CategoryIconMigration', '迁移完成，已写标记位');
    } catch (e, st) {
      logger.error('CategoryIconMigration', '迁移失败', e, st);
      // 不写标记位，下次启动重试。
    }
  }

  /// 检查是否仍存在需要迁移的旧图标（主表或共享账本镜像表）。
  ///
  /// 供启动自愈使用：标记位已写但数据仍残留旧图标时，也必须重新执行迁移，
  /// 否则“迁移跑过但被同步覆盖”的用户永远不会得到新图标。
  static Future<bool> _hasStaleIcons(SpitoutDatabase db) async {
    for (final entry in _iconChanges.entries) {
      final syncId = SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 1,
        key: entry.key,
      );
      final oldIcon = entry.value.oldIcon;

      final mainHit = await (db.select(db.categories)
            ..where((c) => c.syncId.equals(syncId) & c.icon.equals(oldIcon))
            ..limit(1))
          .getSingleOrNull();
      if (mainHit != null) return true;

      final mirrorHit = await (db.select(db.sharedLedgerCategories)
            ..where((s) => s.syncId.equals(syncId) & s.icon.equals(oldIcon))
            ..limit(1))
          .getSingleOrNull();
      if (mirrorHit != null) return true;
    }
    return false;
  }
}
