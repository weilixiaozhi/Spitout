import 'package:drift/drift.dart' as d;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_service.dart';
import '../../data/db.dart';
import '../../providers/core/database_providers.dart';
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
/// 手动换过图标的分类不会被覆盖。
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
  static Future<void> migrate({required SpitoutDatabase db}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return; // 已迁移，跳过

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
          await (db.update(db.sharedLedgerCategories)
                ..where((s) =>
                    s.syncId.equals(syncId) & s.icon.equals(oldIcon)))
              .write(SharedLedgerCategoriesCompanion(icon: d.Value(newIcon)));

          if (rows.isEmpty) continue;

          await (db.update(db.categories)
                ..where((c) =>
                    c.syncId.equals(syncId) & c.icon.equals(oldIcon)))
              .write(CategoriesCompanion(icon: d.Value(newIcon)));

          // 3) 登记 user-global 待推送变更（ledgerId=0），让云端也拿到新图标；
          //    已有未推送 change 时不重复插入。
          for (final row in rows) {
            final existing = await (db.select(db.localChanges)
                  ..where((c) =>
                      c.entityType.equals('category') &
                      c.entitySyncId.equals(syncId) &
                      c.pushedAt.isNull())
                  ..limit(1))
                .getSingleOrNull();
            if (existing != null) continue;

            await db.into(db.localChanges).insert(
              LocalChangesCompanion.insert(
                entityType: 'category',
                entityId: row.id,
                entitySyncId: syncId,
                ledgerId: 0,
                action: 'update',
              ),
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
}

/// App 启动时触发一次分类图标迁移（失败仅记日志，不阻塞启动）。
Future<void> migrateCategoryIconsOnLaunch(
  T Function<T>(ProviderListenable<T>) read,
) async {
  try {
    final db = read(databaseProvider);
    await CategoryIconMigrationService.migrate(db: db);
  } catch (e, st) {
    logger.warning('CategoryIconMigration', '启动迁移触发失败(非阻塞)', '$e\n$st');
  }
}
