import 'package:drift/drift.dart' as d;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/identity/local_user_identity.dart';
import '../../core/logging/logger_service.dart';
import '../../data/db.dart';
import '../../providers/core/database_providers.dart';

/// 历史 'me' 占位符清理服务（Layer 2 迁移）。
///
/// 背景：早期版本未登录本地记账时 paidByUserId 写字面量 'me' 占位，
/// 该值非空导致 markTxAuthor 回填逻辑永不覆盖，永久残留为脏数据。
/// 现已改用持久化的 localSelfId(UUID)，需要一次性把库中遗留的 'me'
/// 改写为当前设备的 localSelfId，让展示层能正确解析为昵称/「我」。
///
/// 与 schema onUpgrade 的区别：此迁移需要 localSelfId(来自 SharedPreferences)，
/// 而 onUpgrade 在数据层、不持有 prefs，故放在 Layer 2 由 app 启动后触发。
///
/// 幂等：用 prefs 标记位 `me_placeholder_cleaned` 防重跑。
class MePlaceholderMigrationService {
  MePlaceholderMigrationService._();

  static const String _cleanedKey = 'me_placeholder_cleaned';

  /// 把库中所有 'me' 占位符改写为 localSelfId。
  ///
  /// 调用时机：app 启动后、localSelfId 就绪后(由 mePlaceholderMigrationProvider 触发)。
  /// - [db] 本地数据库实例。
  /// - [localSelfId] 设备本地身份 UUID。
  static Future<void> clean({
    required SpitoutDatabase db,
    required String localSelfId,
  }) async {
    if (localSelfId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_cleanedKey) == true) return; // 已清理，跳过

    logger.info('MePlaceholderMigration', '开始清理历史 me 占位符');

    try {
      await db.transaction(() async {
        // 交易表：支出人(主要脏数据来源)、创建人、编辑人
        await db.customUpdate(
          "UPDATE transactions SET paid_by_user_id = ?1 WHERE paid_by_user_id = 'me'",
          variables: [d.Variable<String>(localSelfId)],
          updates: {db.transactions},
        );
        await db.customUpdate(
          "UPDATE transactions SET created_by_user_id = ?1 WHERE created_by_user_id = 'me'",
          variables: [d.Variable<String>(localSelfId)],
          updates: {db.transactions},
        );
        await db.customUpdate(
          "UPDATE transactions SET last_edited_by_user_id = ?1 WHERE last_edited_by_user_id = 'me'",
          variables: [d.Variable<String>(localSelfId)],
          updates: {db.transactions},
        );

        // 账本表：所有者
        await db.customUpdate(
          "UPDATE ledgers SET owner_user_id = ?1 WHERE owner_user_id = 'me'",
          variables: [d.Variable<String>(localSelfId)],
          updates: {db.ledgers},
        );

        // 编辑历史表：操作者
        await db.customUpdate(
          "UPDATE record_edit_histories SET operator_user_id = ?1 WHERE operator_user_id = 'me'",
          variables: [d.Variable<String>(localSelfId)],
          updates: {db.recordEditHistories},
        );
      });

      await prefs.setBool(_cleanedKey, true);
      logger.info('MePlaceholderMigration', '清理完成，已写标记位');
    } catch (e, st) {
      logger.error('MePlaceholderMigration', '清理失败', e, st);
      // 不写标记位，下次启动重试。
    }
  }
}

/// App 启动时触发历史 'me' 占位符清理。
///
/// 读取 localSelfId(首次会生成并持久化)与数据库实例，执行幂等迁移。
/// 失败仅记日志，不影响 app 启动。供 app.dart initState 调用。
Future<void> migrateMePlaceholderOnLaunch(
  T Function<T>(ProviderListenable<T>) read,
) async {
  try {
    final localSelfId = await read(localSelfIdProvider.future);
    final db = read(databaseProvider);
    await MePlaceholderMigrationService.clean(
      db: db,
      localSelfId: localSelfId,
    );
  } catch (e, st) {
    logger.warning('MePlaceholderMigration', '启动迁移触发失败(非阻塞)', '$e\n$st');
  }
}
