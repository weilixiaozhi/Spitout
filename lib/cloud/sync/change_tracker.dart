import 'package:drift/drift.dart' as d;

import 'package:spitout/data/db.dart';
import 'package:spitout/data/models/ledger_kind.dart';
import 'package:spitout/data/repositories/support/change_recorder.dart';
import 'package:spitout/data/repositories/support/sync_signal_ports.dart';
import 'package:spitout/core/logging/logger_service.dart';

/// 本地变更追踪器。在 Repository 层捕获写操作,记录到 local_changes 表,
/// 同步引擎读取未推送的变更并上传到服务端。
///
/// ## Scope 契约(重要)
///
/// `local_changes.ledger_id` 字段有两层语义,取决于 entity 是否 user-global:
///
/// - **user-global**(category):每个用户共享一份实体,**不**归
///   属于具体账本。对应变更必须记到 `ledgerId = 0`,sync_engine._push 里靠
///   `getUnpushedChangesForLedger(0)` 查到 globalChanges,搭任一账本的 sync
///   链带出去。这样用户在任何账本上触发同步,分类的改动都能推出。
/// - **ledger-scoped**(transaction / ledger / ledger_snapshot):每条
///   变更挂在具体账本上,对应 `ledgerId = 具体账本 id`。只有用户同步这个
///   账本时 `getUnpushedChangesForLedger(ledger.id)` 才会把它推出去。
///
/// 为强制契约,**调用方不要直接调 `recordChange`**(私有内部方法),用下面
/// 两个强类型入口:
///   - [recordUserGlobalChange] — 自动挂 ledgerId=0
///   - [recordLedgerChange] — 必须传 ledgerId(非零)
///
/// 实现 data 层 [ChangeRecorder] 端口：local Repository 只依赖抽象,
/// 本类在注入点(database_providers.dart)组装,cloud → data 方向保持不变。
class ChangeTracker implements ChangeRecorder, LocalChangePort {
  final SpitoutDatabase db;

  ChangeTracker(this.db);

  /// 已知的 user-global 实体类型。recordUserGlobalChange 用白名单校验防止
  /// 调用方误用(把 transaction 之类传进来也能通过,但被 assert 拦住)。
  static const Set<String> _userGlobalEntityTypes = {
    'category',
    'exchange_rate_override',
  };

  /// 公开 read-only 视图给 sync_engine 的 push 路径用,判断"这条 change 是否
  /// 是 user-global 类型",决定 push 时 scope 字段。
  static const Set<String> userGlobalEntityTypes = _userGlobalEntityTypes;

  /// 记录一条 user-global 实体(category)的变更。
  /// 自动挂 ledgerId=0,调用方不用操心 scope 选择。
  ///
  /// 新增 user-global entity type 时改 [_userGlobalEntityTypes] 白名单即可。
  @override
  Future<void> recordUserGlobalChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required String action,
    String? payloadJson,
  }) async {
    assert(
      _userGlobalEntityTypes.contains(entityType),
      'recordUserGlobalChange 只接受 user-global 实体 '
      '($_userGlobalEntityTypes),实际传入 "$entityType" —— 应该调 '
      'recordLedgerChange 并传具体 ledgerId。',
    );
    await _insert(
      entityType: entityType,
      entityId: entityId,
      entitySyncId: entitySyncId,
      ledgerId: 0,
      action: action,
      payloadJson: payloadJson,
    );
  }

  /// 记录一条 ledger-scoped 实体(transaction / ledger / ledger_snapshot)
  /// 的变更。必须传具体 ledgerId,0 通常是错的(会混进 user-global 通道)。
  @override
  Future<void> recordLedgerChange({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  }) async {
    assert(
      !_userGlobalEntityTypes.contains(entityType),
      'recordLedgerChange 不接受 user-global 实体 '
      '($_userGlobalEntityTypes),实际传入 "$entityType" —— 应该调 '
      'recordUserGlobalChange(不传 ledgerId)。',
    );
    assert(
      ledgerId > 0,
      'recordLedgerChange 需要具体 ledgerId(>0),实际传入 $ledgerId。'
      '传 0 会落到 user-global 通道,不是本方法的契约。',
    );
    // 第二层闸门:纯本地账本(storage_mode == 'local' 且非共享)不写 local_changes,
    // 从源头阻断被动同步。配合 SyncEngine 的 sync()/fullPush() 闸门双保险,
    // 本地账本的变更既不会被记录、也不会被推送到云端。
    // 注意:账本不存在(ledger == null)时不清空——变更来自已存在实体的写入,
    // 未知 ledgerId 一律按"需要同步"处理(生产环境变更必然对应已存在账本);
    // 判定统一走 ledger_kind.dart 的 isLocalLedger,与 sync 引擎
    // 保持一致,共享账本(storageMode 缺失也不会翻转)不拦截。
    final ledger = await (db.select(
      db.ledgers,
    )..where((l) => l.id.equals(ledgerId))).getSingleOrNull();
    if (ledger != null && ledger.isLocalLedger) {
      logger.debug(
        'ChangeTracker',
        '丢弃本地账本($ledgerId)变更:storage_mode=${ledger.storageMode},不写 local_changes',
      );
      return;
    }
    await _insert(
      entityType: entityType,
      entityId: entityId,
      entitySyncId: entitySyncId,
      ledgerId: ledgerId,
      action: action,
      payloadJson: payloadJson,
    );
  }

  @override
  Future<void> recordLedgerChanges({
    required List<
      ({
        String entityType,
        int entityId,
        String entitySyncId,
        int ledgerId,
        String action,
        String? payloadJson,
      })
    >
    changes,
  }) async {
    if (changes.isEmpty) return;
    for (final c in changes) {
      assert(
        !_userGlobalEntityTypes.contains(c.entityType),
        'recordLedgerChanges 不接受 user-global 实体 '
        '($_userGlobalEntityTypes),实际传入 "${c.entityType}"。',
      );
      assert(
        c.ledgerId > 0,
        'recordLedgerChanges 需要具体 ledgerId(>0),实际传入 ${c.ledgerId}。',
      );
    }

    // 与单条路径一致:纯本地账本不写 local_changes;一次查回所有涉及账本,
    // 避免逐条 SELECT。
    final ledgerIds = changes.map((c) => c.ledgerId).toSet().toList();
    final ledgers = await (db.select(
      db.ledgers,
    )..where((l) => l.id.isIn(ledgerIds))).get();
    final localLedgerIds = ledgers
        .where((l) => l.isLocalLedger)
        .map((l) => l.id)
        .toSet();
    final effective = changes
        .where((c) => !localLedgerIds.contains(c.ledgerId))
        .toList();
    if (effective.isEmpty) return;

    await db.batch((b) {
      for (final c in effective) {
        b.insert(
          db.localChanges,
          LocalChangesCompanion.insert(
            entityType: c.entityType,
            entityId: c.entityId,
            entitySyncId: c.entitySyncId,
            ledgerId: c.ledgerId,
            action: c.action,
            payloadJson: d.Value(c.payloadJson),
          ),
        );
      }
    });
    logger.debug('ChangeTracker', '批量登记 ${effective.length} 条 ledger 变更');
  }

  @override
  Future<void> recordUserGlobalChanges({
    required List<
      ({
        String entityType,
        int entityId,
        String entitySyncId,
        String action,
        String? payloadJson,
      })
    >
    changes,
  }) async {
    if (changes.isEmpty) return;
    for (final c in changes) {
      assert(
        _userGlobalEntityTypes.contains(c.entityType),
        'recordUserGlobalChanges 只接受 user-global 实体 '
        '($_userGlobalEntityTypes),实际传入 "${c.entityType}"。',
      );
    }
    await db.batch((b) {
      for (final c in changes) {
        b.insert(
          db.localChanges,
          LocalChangesCompanion.insert(
            entityType: c.entityType,
            entityId: c.entityId,
            entitySyncId: c.entitySyncId,
            ledgerId: 0,
            action: c.action,
            payloadJson: d.Value(c.payloadJson),
          ),
        );
      }
    });
    logger.debug('ChangeTracker', '批量登记 ${changes.length} 条 user-global 变更');
  }

  /// 低层 insert,不对外暴露。路径统一:所有 record*Change 走这条,行为
  /// (日志 / insert 语义)一处维护。
  Future<void> _insert({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    String? payloadJson,
  }) async {
    await db
        .into(db.localChanges)
        .insert(
          LocalChangesCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            entitySyncId: entitySyncId,
            ledgerId: ledgerId,
            action: action,
            payloadJson: d.Value(payloadJson),
          ),
        );
    logger.debug('ChangeTracker', '$action $entityType($entitySyncId)');
  }

  /// 登记一个**从 server pull 拉下来**的实体在本地的状态。
  ///
  /// 写入一条 `local_changes` 行,**pushedAt 设为 now**(表示"server 已有此
  /// 实体,本地不需要再推")。
  ///
  /// 目的:fullPush 路径上 [SyncEngine._backfillLegacyUserGlobalChanges]
  /// 通过扫 local_changes 来识别"哪些 user-global 实体已知"。pull apply 进
  /// 来的实体如果不登记,legacy backfill 会误判为未登记并补登记,导致第二台
  /// 设备同步时把 server 已有的 user-global 实体重新推一遍,造成 server
  /// sync_changes 表膨胀。
  ///
  /// **幂等**:同一 (entityType, entitySyncId) 多次调用只插一次(同 entity
  /// 通过 apply update 多次也不会挤爆表)。
  Future<void> recordPulledFromServer({
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
  }) async {
    final existing =
        await (db.select(db.localChanges)
              ..where(
                (c) =>
                    c.entityType.equals(entityType) &
                    c.entitySyncId.equals(entitySyncId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return;

    final now = DateTime.now();
    await db
        .into(db.localChanges)
        .insert(
          LocalChangesCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            entitySyncId: entitySyncId,
            ledgerId: ledgerId,
            action: 'upsert',
            pushedAt: d.Value(now),
          ),
        );
    logger.debug(
      'ChangeTracker',
      'pulled-from-server marker: $entityType($entitySyncId)',
    );
  }

  /// 获取所有未推送的变更
  @override
  Future<List<LocalChange>> getUnpushedChanges() async {
    return await (db.select(db.localChanges)
          ..where((c) => c.pushedAt.isNull())
          ..orderBy([(c) => d.OrderingTerm.asc(c.id)]))
        .get();
  }

  /// 获取指定账本的未推送变更
  @override
  Future<List<LocalChange>> getUnpushedChangesForLedger(int ledgerId) async {
    return await (db.select(db.localChanges)
          ..where((c) => c.pushedAt.isNull() & c.ledgerId.equals(ledgerId))
          ..orderBy([(c) => d.OrderingTerm.asc(c.id)]))
        .get();
  }

  /// 标记变更已推送
  @override
  Future<void> markPushed(List<int> changeIds) async {
    if (changeIds.isEmpty) return;
    final now = DateTime.now();
    await (db.update(db.localChanges)..where((c) => c.id.isIn(changeIds)))
        .write(LocalChangesCompanion(pushedAt: d.Value(now)));
    logger.debug('ChangeTracker', '标记 ${changeIds.length} 条变更已推送');
  }

  /// 清理已推送的旧变更（保留最近 7 天）
  @override
  Future<int> cleanupPushedChanges({
    Duration retention = const Duration(days: 7),
  }) async {
    final cutoff = DateTime.now().subtract(retention);
    final count =
        await (db.delete(db.localChanges)..where(
              (c) =>
                  c.pushedAt.isNotNull() &
                  c.pushedAt.isSmallerThanValue(cutoff),
            ))
            .go();
    if (count > 0) {
      logger.info('ChangeTracker', '清理 $count 条已推送的旧变更');
    }
    return count;
  }

  /// 获取未推送变更数量
  @override
  Future<int> getUnpushedCount() async {
    // 全表查进内存再数长度在表膨胀后会很慢；用 COUNT(*) 只回传一个数字。
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM local_changes WHERE pushed_at IS NULL',
      readsFrom: {db.localChanges},
    ).getSingle();
    return row.read<int>('c');
  }

  @override
  Stream<List<LocalChange>> watchUnpushed() {
    return (db.select(db.localChanges)
          ..where((c) => c.pushedAt.isNull()))
        .watch();
  }
}
