import 'package:drift/drift.dart' as d;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/identity/local_user_identity.dart';
import '../../core/logging/logger_service.dart';
import '../../data/db.dart';

/// 本地身份 → 云身份迁移服务（方案 B）。
///
/// 设计意图：未登录时本地账本的作者字段(paidByUserId / createdByUserId /
/// lastEditedByUserId / ledger.ownerUserId / record_edit_histories.operatorUserId)
/// 写的是 localSelfId(设备 UUID)。首次登录 Spitout Cloud 后，把这些字段
/// 一次性改写为云 userId，使本地账本的「我」与云身份统一。
///
/// 幂等保证：迁移完成后写 prefs 标记位 `local_self_id_migrated_<cloudUserId>`，
/// 再次登录同一账号不会重跑。换账号登录时 cloudUserId 不同，标记位不命中，
/// 会把当前 localSelfId 迁移到新账号(符合方案 B「换号旧记录归属旧号」语义)。
///
/// 注意：登出后新记的账会重新写 localSelfId，再次登录同账号时标记位已存在
/// 不会重跑——这部分「登出期间产生的 localSelfId 记录」会保留 localSelfId，
/// 由展示层统一解析为昵称/「我」。这是方案 B 已知的行为，用户已确认接受。
class LocalIdentityMigrationService {
  LocalIdentityMigrationService._();

  /// 迁移 prefs 标记位前缀。
  static const String _migratedKeyPrefix = 'local_self_id_migrated_';

  /// 把库中所有 localSelfId 引用改写为 cloudUserId。
  ///
  /// 调用时机：登录 Spitout Cloud 成功后、首次同步前。
  /// - [db] 本地数据库实例。
  /// - [cloudUserId] 当前登录用户云 userId。
  /// - [localSelfId] 设备本地身份(由调用方从 localSelfIdProvider 注入)。
  ///
  /// 返回 true 表示执行了迁移(或已迁移过)，false 表示跳过(如 localSelfId 缺失)。
  static Future<bool> migrateToCloudUserId({
    required SpitoutDatabase db,
    required String cloudUserId,
    required String localSelfId,
  }) async {
    if (cloudUserId.isEmpty) {
      logger.warning('LocalIdentityMigration', 'cloudUserId 为空，跳过迁移');
      return false;
    }
    if (localSelfId.isEmpty) {
      logger.warning('LocalIdentityMigration', 'localSelfId 为空，跳过迁移');
      return false;
    }
    // localSelfId 与 cloudUserId 相同时无需迁移(理论上不会发生)。
    if (localSelfId == cloudUserId) return true;

    final prefs = await SharedPreferences.getInstance();
    final migratedKey = '$_migratedKeyPrefix$cloudUserId';
    if (prefs.getBool(migratedKey) == true) {
      // 已迁移过此账号，跳过(幂等)。
      return true;
    }

    logger.info('LocalIdentityMigration',
        '开始迁移 localSelfId → cloudUserId($cloudUserId)');

    try {
      // 单事务内改写所有引用 localSelfId 的字段，保证原子一致。
      // 顺序无强约束(都是 UPDATE WHERE)，但放同一事务避免半迁移。
      await db.transaction(() async {
        // 交易表：支出人 / 创建人 / 编辑人
        await db.customUpdate(
          'UPDATE transactions SET paid_by_user_id = ?1 WHERE paid_by_user_id = ?2',
          variables: [d.Variable<String>(cloudUserId), d.Variable<String>(localSelfId)],
          updates: {db.transactions},
        );
        await db.customUpdate(
          'UPDATE transactions SET created_by_user_id = ?1 WHERE created_by_user_id = ?2',
          variables: [d.Variable<String>(cloudUserId), d.Variable<String>(localSelfId)],
          updates: {db.transactions},
        );
        await db.customUpdate(
          'UPDATE transactions SET last_edited_by_user_id = ?1 WHERE last_edited_by_user_id = ?2',
          variables: [d.Variable<String>(cloudUserId), d.Variable<String>(localSelfId)],
          updates: {db.transactions},
        );

        // 账本表：所有者
        await db.customUpdate(
          'UPDATE ledgers SET owner_user_id = ?1 WHERE owner_user_id = ?2',
          variables: [d.Variable<String>(cloudUserId), d.Variable<String>(localSelfId)],
          updates: {db.ledgers},
        );

        // 编辑历史表：操作者
        await db.customUpdate(
          'UPDATE record_edit_histories SET operator_user_id = ?1 WHERE operator_user_id = ?2',
          variables: [d.Variable<String>(cloudUserId), d.Variable<String>(localSelfId)],
          updates: {db.recordEditHistories},
        );
      });

      // 标记迁移完成，防止重跑。
      await prefs.setBool(migratedKey, true);
      logger.info('LocalIdentityMigration', '迁移完成，已写标记位 $migratedKey');
      return true;
    } catch (e, st) {
      logger.error('LocalIdentityMigration', '迁移失败', e, st);
      // 不写标记位，下次登录会重试。
      return false;
    }
  }

  /// 读取备份用 localSelfId（供备份服务调用）。
  static Future<String?> readLocalSelfId() => LocalSelfId.read();

  /// 恢复 localSelfId（供恢复服务调用，仅当当前无值时写入）。
  static Future<void> restoreLocalSelfId(String value) =>
      LocalSelfId.restoreIfAbsent(value);

  /// 把指定账本内的 localSelfId 引用改写为 cloudUserId（转云端用）。
  ///
  /// 与 [migrateToCloudUserId] 区别：仅迁移单个账本，不写全局标记位
  /// （全局标记位用于整库迁移；单账本迁移是转云端时按需触发，可重复执行）。
  ///
  /// - [ledgerId] 待迁移的账本 id。
  static Future<void> migrateLedgerToCloudUserId({
    required SpitoutDatabase db,
    required int ledgerId,
    required String cloudUserId,
    required String localSelfId,
  }) async {
    if (cloudUserId.isEmpty || localSelfId.isEmpty || localSelfId == cloudUserId) {
      return;
    }
    logger.info('LocalIdentityMigration',
        '转云端:迁移账本 $ledgerId 的 localSelfId → cloudUserId($cloudUserId)');
    try {
      await db.transaction(() async {
        // 交易表：支出人 / 创建人 / 编辑人（限定 ledgerId）
        await db.customUpdate(
          'UPDATE transactions SET paid_by_user_id = ?1 '
          'WHERE ledger_id = ?2 AND paid_by_user_id = ?3',
          variables: [
            d.Variable<String>(cloudUserId),
            d.Variable<int>(ledgerId),
            d.Variable<String>(localSelfId),
          ],
          updates: {db.transactions},
        );
        await db.customUpdate(
          'UPDATE transactions SET created_by_user_id = ?1 '
          'WHERE ledger_id = ?2 AND created_by_user_id = ?3',
          variables: [
            d.Variable<String>(cloudUserId),
            d.Variable<int>(ledgerId),
            d.Variable<String>(localSelfId),
          ],
          updates: {db.transactions},
        );
        await db.customUpdate(
          'UPDATE transactions SET last_edited_by_user_id = ?1 '
          'WHERE ledger_id = ?2 AND last_edited_by_user_id = ?3',
          variables: [
            d.Variable<String>(cloudUserId),
            d.Variable<int>(ledgerId),
            d.Variable<String>(localSelfId),
          ],
          updates: {db.transactions},
        );

        // 账本行：所有者（限定 ledgerId）
        await db.customUpdate(
          'UPDATE ledgers SET owner_user_id = ?1 '
          'WHERE id = ?2 AND owner_user_id = ?3',
          variables: [
            d.Variable<String>(cloudUserId),
            d.Variable<int>(ledgerId),
            d.Variable<String>(localSelfId),
          ],
          updates: {db.ledgers},
        );

        // 编辑历史表：操作者（通过 record_id JOIN transactions 限定 ledgerId）
        await db.customUpdate(
          'UPDATE record_edit_histories SET operator_user_id = ?1 '
          'WHERE operator_user_id = ?2 AND record_id IN '
          '(SELECT id FROM transactions WHERE ledger_id = ?3)',
          variables: [
            d.Variable<String>(cloudUserId),
            d.Variable<String>(localSelfId),
            d.Variable<int>(ledgerId),
          ],
          updates: {db.recordEditHistories},
        );
      });
      logger.info('LocalIdentityMigration', '账本 $ledgerId 转云端身份迁移完成');
    } catch (e, st) {
      logger.error('LocalIdentityMigration', '账本 $ledgerId 转云端身份迁移失败', e, st);
      rethrow;
    }
  }
}
