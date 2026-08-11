import 'dart:convert';

import 'package:drift/drift.dart' as d;

import 'package:spitout/core/identity/local_user_identity.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/data/db.dart';

/// 本地身份按账本归属收敛服务。
///
/// 设计意图：未登录时本地账本的作者字段(paidByUserId / createdByUserId /
/// lastEditedByUserId / ledger.ownerUserId / record_edit_histories.operatorUserId)
/// 只能写 localSelfId(设备 UUID)，云端账本只能写云 userId，两者不得混存。
/// 历史版本曾把云 userId 写进本地账本、把 localSelfId 写进云端账本，
/// 本服务按 storage_mode 逐账本收敛，保证「本地账本不受云端影响」。
///
/// 幂等：全部使用 UPDATE WHERE 或按行 JSON 收敛，可重复执行。
class LocalIdentityMigrationService {
  LocalIdentityMigrationService._();

  /// 按账本归属修复存量混存身份（登录后调用）。
  ///
  /// 设计意图：本地账本的作者身份只能属于本机（localSelfId），云端账本只能
  /// 属于云账号（cloudUserId）。历史版本可能把两种 id 混进同一账本，这里按
  /// storage_mode 逐账本收敛；UPDATE WHERE 天然幂等，可重复执行。
  ///
  /// - 本地账本：所有非虚拟用户 id → localSelfId（虚拟用户按表排除）；
  /// - 云端账本：localSelfId → cloudUserId，其他成员 id 保留。
  static Future<void> repairAuthorIdsByStorageMode({
    required SpitoutDatabase db,
    required String localSelfId,
    required String cloudUserId,
  }) async {
    if (localSelfId.isEmpty ||
        cloudUserId.isEmpty ||
        localSelfId == cloudUserId) {
      return;
    }
    final rows = await db.customSelect(
      'SELECT id, storage_mode, is_shared FROM ledgers',
      readsFrom: {db.ledgers},
    ).get();
    for (final row in rows) {
      final ledgerId = row.read<int>('id');
      final storageMode = row.read<String?>('storage_mode') ?? 'local';
      final isShared = row.read<bool>('is_shared');
      if (storageMode == 'cloud' || isShared) {
        await migrateLedgerToCloudUserId(
          db: db,
          ledgerId: ledgerId,
          cloudUserId: cloudUserId,
          localSelfId: localSelfId,
        );
      } else {
        await repairLocalLedgerToLocalSelfId(
          db: db,
          ledgerId: ledgerId,
          localSelfId: localSelfId,
        );
      }
    }
  }

  /// 仅修复本地账本（启动期兜底，不依赖云端登录态）。
  static Future<void> repairLocalLedgersToLocalSelfId({
    required SpitoutDatabase db,
    required String localSelfId,
  }) async {
    if (localSelfId.isEmpty) return;
    final rows = await db.customSelect(
      "SELECT id FROM ledgers WHERE is_shared = 0 "
      "AND (storage_mode IS NULL OR storage_mode = 'local')",
      readsFrom: {db.ledgers},
    ).get();
    for (final row in rows) {
      await repairLocalLedgerToLocalSelfId(
        db: db,
        ledgerId: row.read<int>('id'),
        localSelfId: localSelfId,
      );
    }
  }

  /// 把单个本地账本内所有作者位收敛为 localSelfId（虚拟用户 id 保留）。
  static Future<void> repairLocalLedgerToLocalSelfId({
    required SpitoutDatabase db,
    required int ledgerId,
    required String localSelfId,
  }) async {
    final virtualRows = await (db.select(db.ledgerVirtualUsers)
          ..where((v) => v.ledgerId.equals(ledgerId)))
        .get();
    final virtualIds = <String>{
      for (final v in virtualRows) v.syncId ?? 'vu_${v.id}',
    };

    Future<void> rewriteColumn(String column) async {
      final notIn = virtualIds.isEmpty
          ? ''
          : ' AND $column NOT IN ('
              '${[for (var i = 0; i < virtualIds.length; i++) '?${3 + i}'].join(', ')})';
      await db.customUpdate(
        'UPDATE transactions SET $column = ?1 WHERE ledger_id = ?2 '
        'AND $column IS NOT NULL AND $column != ?1$notIn',
        variables: [
          d.Variable<String>(localSelfId),
          d.Variable<int>(ledgerId),
          ...virtualIds.map((id) => d.Variable<String>(id)),
        ],
        updates: {db.transactions},
      );
    }

    await db.transaction(() async {
      // 交易三字段：支出人 / 创建人 / 编辑人。
      await rewriteColumn('paid_by_user_id');
      await rewriteColumn('created_by_user_id');
      await rewriteColumn('last_edited_by_user_id');

      // 账本所有者。
      await db.customUpdate(
        'UPDATE ledgers SET owner_user_id = ?1 WHERE id = ?2 '
        'AND owner_user_id IS NOT NULL AND owner_user_id != ?1',
        variables: [
          d.Variable<String>(localSelfId),
          d.Variable<int>(ledgerId),
        ],
        updates: {db.ledgers},
      );

      // 编辑历史操作者（虚拟用户同样排除）。
      final historyNotIn = virtualIds.isEmpty
          ? ''
          : ' AND operator_user_id NOT IN ('
              '${[for (var i = 0; i < virtualIds.length; i++) '?${3 + i}'].join(', ')})';
      await db.customUpdate(
        'UPDATE record_edit_histories SET operator_user_id = ?1 '
        'WHERE operator_user_id IS NOT NULL AND operator_user_id != ?1'
        '$historyNotIn '
        'AND record_id IN (SELECT id FROM transactions WHERE ledger_id = ?2)',
        variables: [
          d.Variable<String>(localSelfId),
          d.Variable<int>(ledgerId),
          ...virtualIds.map((id) => d.Variable<String>(id)),
        ],
        updates: {db.recordEditHistories},
      );

      // AA 分摊 JSON 引用同样收敛，避免统计侧出现陌生参与人。
      await _rewriteLocalAaReferencesInTx(
        db: db,
        ledgerId: ledgerId,
        localSelfId: localSelfId,
        virtualIds: virtualIds,
      );
    });
  }

  /// 读取备份用 localSelfId（供备份服务调用）。
  static Future<String?> readLocalSelfId() => LocalSelfId.read();

  /// 恢复 localSelfId（供恢复服务调用，仅当当前无值时写入）。
  static Future<void> restoreLocalSelfId(String value) =>
      LocalSelfId.restoreIfAbsent(value);

  /// 把指定账本内的 localSelfId 引用改写为 cloudUserId（转云端用）。
  ///
  /// 仅迁移单个账本，不影响其他账本；可重复执行。
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

        // AA 分摊引用同样限定账本范围改写。
        await _rewriteAaReferencesInTx(
          db: db,
          ledgerId: ledgerId,
          localSelfId: localSelfId,
          cloudUserId: cloudUserId,
        );
      });
      logger.info('LocalIdentityMigration', '账本 $ledgerId 转云端身份迁移完成');
    } catch (e, st) {
      logger.error('LocalIdentityMigration', '账本 $ledgerId 转云端身份迁移失败', e, st);
      rethrow;
    }
  }

  /// 把单个本地账本交易 AA 字段中的外来身份收敛为 localSelfId。
  ///
  /// 虚拟用户 id 保留；外来身份并入 localSelfId 时若本地已有金额则保留本地值，
  /// 与云端收敛语义一致。JSON 解析失败的行保持原样并记日志。
  static Future<void> _rewriteLocalAaReferencesInTx({
    required SpitoutDatabase db,
    required int ledgerId,
    required String localSelfId,
    required Set<String> virtualIds,
  }) async {
    final rows = await db.customSelect(
      'SELECT id, aa_participants, aa_splits FROM transactions '
      'WHERE ledger_id = ?1',
      variables: [d.Variable<int>(ledgerId)],
      readsFrom: {db.transactions},
    ).get();

    for (final row in rows) {
      final txId = row.read<int>('id');
      var participants = row.readNullable<String>('aa_participants');
      var splits = row.readNullable<String>('aa_splits');
      var participantsChanged = false;
      var splitsChanged = false;

      // aaParticipants：非虚拟用户 id 一律收敛为 localSelfId 并去重。
      if (participants != null && participants.isNotEmpty) {
        try {
          final list = (jsonDecode(participants) as List).cast<String>();
          final replaced = <String>[];
          for (final id in list) {
            final target = (id == localSelfId || virtualIds.contains(id))
                ? id
                : localSelfId;
            if (!replaced.contains(target)) replaced.add(target);
          }
          final encoded = jsonEncode(replaced);
          if (encoded != participants) {
            participants = encoded;
            participantsChanged = true;
          }
        } catch (e, st) {
          logger.warning(
              'LocalIdentityMigration', '解析 aaParticipants 失败 tx=$txId', '$e\n$st');
        }
      }

      // aaSplits：非虚拟用户 key 并入 localSelfId，本地已有金额优先保留。
      if (splits != null && splits.isNotEmpty) {
        try {
          final map = (jsonDecode(splits) as Map).cast<String, String>();
          final merged = <String, String>{};
          // 本地身份已有金额优先保留，外来身份并入时不得覆盖。
          final localValue = map[localSelfId];
          if (localValue != null) merged[localSelfId] = localValue;
          for (final e in map.entries) {
            if (e.key == localSelfId) continue;
            final key = (e.key == localSelfId || virtualIds.contains(e.key))
                ? e.key
                : localSelfId;
            merged.putIfAbsent(key, () => e.value);
          }
          final encoded = jsonEncode(merged);
          if (encoded != splits) {
            splits = encoded;
            splitsChanged = true;
          }
        } catch (e, st) {
          logger.warning(
              'LocalIdentityMigration', '解析 aaSplits 失败 tx=$txId', '$e\n$st');
        }
      }

      if (participantsChanged || splitsChanged) {
        final assignments = <String>[];
        final variables = <d.Variable<Object>>[];
        if (participantsChanged) {
          assignments.add('aa_participants = ?${assignments.length + 1}');
          variables.add(d.Variable<String>(participants!));
        }
        if (splitsChanged) {
          assignments.add('aa_splits = ?${assignments.length + 1}');
          variables.add(d.Variable<String>(splits!));
        }
        await db.customUpdate(
          'UPDATE transactions SET ${assignments.join(', ')} '
          'WHERE id = ?${assignments.length + 1}',
          variables: [...variables, d.Variable<int>(txId)],
          updates: {db.transactions},
        );
      }
    }
  }

  /// 重写交易 AA 字段中的 localSelfId → cloudUserId。
  ///
  /// [ledgerId] 为空时全库改写，否则仅改写指定账本（与调用方事务保持一致）。
  /// JSON 解析失败的行保持原样并记日志，不让单条脏数据阻断整批迁移。
  static Future<void> _rewriteAaReferencesInTx({
    required SpitoutDatabase db,
    required String localSelfId,
    required String cloudUserId,
    int? ledgerId,
  }) async {
    final rows = await db.customSelect(
      ledgerId == null
          ? '''
            SELECT id, aa_participants, aa_splits
            FROM transactions
            WHERE aa_participants LIKE ?1 OR aa_splits LIKE ?1
            '''
          : '''
            SELECT id, aa_participants, aa_splits
            FROM transactions
            WHERE ledger_id = ?2 AND (aa_participants LIKE ?1 OR aa_splits LIKE ?1)
            ''',
      variables: [
        d.Variable<String>('%$localSelfId%'),
        if (ledgerId != null) d.Variable<int>(ledgerId),
      ],
      readsFrom: {db.transactions},
    ).get();

    for (final row in rows) {
      final txId = row.read<int>('id');
      var participants = row.readNullable<String>('aa_participants');
      var splits = row.readNullable<String>('aa_splits');
      var participantsChanged = false;
      var splitsChanged = false;

      // aaParticipants:JSON 数组,元素为 userId 或虚拟用户 syncId。
      // 替换后去重,防止 localSelfId 与 cloudUserId 并存时出现重复参与人。
      if (participants != null && participants.isNotEmpty) {
        try {
          final list = (jsonDecode(participants) as List).cast<String>();
          if (list.contains(localSelfId)) {
            final replaced = <String>[];
            for (final id in list) {
              final target = id == localSelfId ? cloudUserId : id;
              if (!replaced.contains(target)) replaced.add(target);
            }
            participants = jsonEncode(replaced);
            participantsChanged = true;
          }
        } catch (e, st) {
          logger.warning(
              'LocalIdentityMigration', '解析 aaParticipants 失败 tx=$txId', '$e\n$st');
        }
      }

      // aaSplits:JSON 对象,key=参与人,value=金额字符串。
      // cloudUserId 已存在时保留原值,避免覆盖可能更新的分摊数据。
      if (splits != null && splits.isNotEmpty) {
        try {
          final map = (jsonDecode(splits) as Map).cast<String, String>();
          if (map.containsKey(localSelfId)) {
            final value = map.remove(localSelfId)!;
            map.putIfAbsent(cloudUserId, () => value);
            splits = jsonEncode(map);
            splitsChanged = true;
          }
        } catch (e, st) {
          logger.warning(
              'LocalIdentityMigration', '解析 aaSplits 失败 tx=$txId', '$e\n$st');
        }
      }

      // 只回写实际变化的列；Drift 的 Variable 不接受可空类型，
      // 未变化的列不参与 UPDATE，天然保留原值（含 NULL）。
      if (participantsChanged || splitsChanged) {
        final assignments = <String>[];
        final variables = <d.Variable<Object>>[];
        if (participantsChanged) {
          assignments.add('aa_participants = ?${assignments.length + 1}');
          variables.add(d.Variable<String>(participants!));
        }
        if (splitsChanged) {
          assignments.add('aa_splits = ?${assignments.length + 1}');
          variables.add(d.Variable<String>(splits!));
        }
        await db.customUpdate(
          'UPDATE transactions SET ${assignments.join(', ')} '
          'WHERE id = ?${assignments.length + 1}',
          variables: [...variables, d.Variable<int>(txId)],
          updates: {db.transactions},
        );
      }
    }
  }
}
