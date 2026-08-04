import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../../models/ledger_kind.dart';
import '../ledger_repository.dart';
import '../support/change_recorder.dart';
import '../support/snapshot_dirty_marker.dart';

const _uuid = Uuid();

/// 本地账本Repository实现
/// 基于 Drift 数据库实现
class LocalLedgerRepository implements LedgerRepository {
  final SpitoutDatabase db;

  /// 变更登记器的惰性获取函数。
  ///
  /// 为什么用 getter 而不是直接持有实例:changeTracker 挂在外层
  /// LocalRepository 上且可能在运行期被替换(登录/登出 Spitout Cloud 时
  /// 重建),用 getter 保证每次取到的都是最新引用,与
  /// LocalExchangeRateRepository 的注入模式保持一致。
  final ChangeRecorder? Function()? _trackerGetter;

  /// 快照型后端脏账本标记器的惰性获取函数。
  ///
  /// 与 [_trackerGetter] 对称:挂在外层 LocalRepository 上,由注入点
  /// (database_providers)按后端类型决定是否注入。仅快照型后端
  /// (webdav/s3/supabase)注入;Spitout Cloud 走 [ChangeRecorder] +
  /// local_changes 增量通道;无后端时两者都不注入。
  final SnapshotDirtyMarker? Function()? _snapshotDirtyMarkerGetter;

  LocalLedgerRepository(
    this.db, {
    ChangeRecorder? Function()? trackerGetter,
    SnapshotDirtyMarker? Function()? snapshotDirtyMarkerGetter,
  })  : _trackerGetter = trackerGetter,
        _snapshotDirtyMarkerGetter = snapshotDirtyMarkerGetter;

  @override
  Stream<List<Ledger>> watchLedgers() => db.select(db.ledgers).watch();

  @override
  Future<List<Ledger>> getAllLedgers() async {
    return db.select(db.ledgers).get();
  }

  @override
  Future<Ledger?> getLedgerById(int id) async {
    final query = db.select(db.ledgers)..where((l) => l.id.equals(id));
    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<({int dayCount, int txCount})> getCountsForLedger({
    required int ledgerId,
  }) async {
    final txRow = await db.customSelect(
        'SELECT COUNT(*) AS c FROM transactions WHERE ledger_id = ?1',
        variables: [d.Variable.withInt(ledgerId)],
        readsFrom: {db.transactions}).getSingle();
    // 计算记账天数：今天 - 第一笔记账日期 + 1
    final dayRow = await db.customSelect("""
      SELECT CASE
        WHEN MIN(happened_at) IS NULL THEN 0
        ELSE CAST(julianday('now', 'localtime') - julianday(MIN(happened_at), 'unixepoch', 'localtime') + 1 AS INTEGER)
      END AS c
      FROM transactions WHERE ledger_id = ?1
      """,
        variables: [d.Variable.withInt(ledgerId)],
        readsFrom: {db.transactions}).getSingle();

    int parse(dynamic v) {
      if (v is int) return v;
      if (v is BigInt) return v.toInt();
      if (v is num) return v.toInt();
      return 0;
    }

    return (dayCount: parse(dayRow.data['c']), txCount: parse(txRow.data['c']));
  }

  @override
  Future<({double expenseTotal, int transactionCount})> getLedgerStats({
    required int ledgerId,
    List<Transaction>? transactions,
  }) async {
    // 如果没有传入 transactions，则查询
    final rows = transactions ?? await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();

    // 交易数
    final transactionCount = rows.length;

    // 账本支出总额(账本维度,读折算值 nativeAmount ?? amount 兜底,
    // 单币种账本 native==amount 结果不变)。
    double expenseTotal = 0.0;
    for (final t in rows) {
      final v = t.nativeAmount ?? t.amount;
      // 全局仅支出模式，所有交易 type 恒为 'expense'
      expenseTotal += v;
    }

    return (expenseTotal: expenseTotal, transactionCount: transactionCount);
  }

  @override
  Future<int> createLedger({
    required String name,
    String currency = 'CNY',
    // 默认 'cloud' 以兼容现有调用方(均假设新建账本可上云);未登录用户由
    // Phase D UI 显式传 'local'。storage_mode 决定归属:local 永不分配 syncId。
    String storageMode = 'cloud',
    // 账本所有者 userId:UI 新建路径传入(已登录=云 userId,未登录=localSelfId)。
    // 同步路径(副本/导入)不传,保持 null 由云端数据回填。
    String? ownerUserId,
    // AA 分摊开关:默认 false(新账本关闭);「复制到本地」等同步路径
    // 会透传源账本的 aaEnabled,保证副本与源账本行为一致。
    bool aaEnabled = false,
  }) async {
    // storage_mode 决定云端归属:仅 cloud 模式分配跨设备 syncId;local 账本
    // syncId 为 null,从源头断开云端关联(配合三路闸门,local 账本永不上云)。
    final syncId = storageMode == 'cloud' ? _uuid.v4() : null;
    // insert 与变更登记放同一事务:避免"账本落库成功但变更登记失败"留下
    // 一本云端永远推不出去的新账本(规则4:同步由 local_changes 驱动)。
    return db.transaction(() async {
      final id = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: name,
              currency: d.Value(currency),
              syncId: d.Value(syncId),
              storageMode: d.Value(storageMode),
              ownerUserId: ownerUserId != null && ownerUserId.isNotEmpty
                  ? d.Value(ownerUserId)
                  : const d.Value.absent(),
              aaEnabled: d.Value(aaEnabled),
            ),
          );
      // 仅云端账本登记 ledger:upsert 到 local_changes:
      //   - SyncCoordinator 监听未推送变更后自动触发同步,新建账本从此
      //     不需要 UI 手动判断后端类型/手动触发(消除页面 mounted 竞态);
      //   - local 账本 syncId 为 null,本就不该上云,直接跳过;
      //   - tracker 为 null(未登录 Spitout Cloud / 快照型后端)时为 no-op。
      final tracker = _trackerGetter?.call();
      if (tracker != null && syncId != null) {
        await tracker.recordLedgerChange(
          entityType: 'ledger',
          entityId: id,
          entitySyncId: syncId,
          ledgerId: id,
          action: 'upsert',
        );
      }
      // 快照型后端(webdav/s3/supabase)新建账本:登记"脏"信号到
      // snapshot_dirty_ledgers,由 SnapshotSyncCoordinator 监听并响应式触发
      // 首快照上传(规则4:同步由数据变更驱动,UI 不显式调 sync)。
      //   - 仅非 cloud 账本(syncId == null)写入:快照后端下 storageMode 恒为
      //     'local',syncId 必为 null;Spitout Cloud 的 cloud 账本走 local_changes
      //     增量通道,marker 未注入此处为 no-op;
      //   - 同事务写入,保证"账本落库"与"脏信号登记"原子一致,不会出现
      //     "账本建成功但脏信号丢失"导致首快照永不触发的窗口。
      final snapshotMarker = _snapshotDirtyMarkerGetter?.call();
      if (snapshotMarker != null && syncId == null) {
        await snapshotMarker.markLedgerDirty(id);
      }
      return id;
    });
  }

  @override
  Future<void> updateLedgerStorageMode({
    required int id,
    required String storageMode,
  }) async {
    // 移动操作(转云端/转本地)完成后翻归属标记。写 local_changes 由
    // ChangeTracker 依据新模式决定,见 database_providers。
    await (db.update(db.ledgers)..where((tbl) => tbl.id.equals(id))).write(
      LedgersCompanion(storageMode: d.Value(storageMode)),
    );
  }

  @override
  Future<void> updateLedgerSyncId({
    required int id,
    String? syncId,
  }) async {
    // 传入 null 用于"移动到本地"彻底断联云端;非 null 用于补发/确认后写入。
    await (db.update(db.ledgers)..where((tbl) => tbl.id.equals(id))).write(
      LedgersCompanion(syncId: d.Value(syncId)),
    );
  }

  @override
  Future<void> detachFromCloud(int id) async {
    // 「转本地」断联:把翻归属(storageMode='local')与清 syncId 合并进同一事务。
    //
    // 为什么必须事务化:两条更新若各自裸跑,中途失败会留下半截态——
    //   - 仅翻了 local 但 syncId 还在 → pull 时按 syncId 命中,可能被回灌/误删;
    //   - 仅清了 syncId 但仍标 cloud → pull 把它当成待拉取的云端账本处理。
    // 事务保证要么两条都生效、要么全回滚,归属与断联始终原子一致。
    //
    // 记账安全:updateLedgerStorageMode / updateLedgerSyncId 均不触碰
    // _trackerGetter、不写 local_changes,合入事务不改变记账语义。
    await db.transaction(() async {
      await updateLedgerStorageMode(id: id, storageMode: 'local');
      await updateLedgerSyncId(id: id, syncId: null);
    });
  }

  @override
  Future<void> copyLedgerData({
    required int sourceLedgerId,
    required int targetLedgerId,
  }) async {
    // 跨账本数据搬运:拷贝交易及其编辑历史。
    // 注意:本项目的 Categories 是全局表(无 ledgerId 列),分类被所有账本共享,
    // 故无需按账本拷贝分类——交易直接保留原 categoryId 即可,避免重复复制造成冗余。
    // 新建副本一律新 syncId、清空共享 override,独立成一份本地数据。
    // AA 分摊字段(paidByUserId/aaMode/aaSplits 等)随交易一起拷贝,保证副本
    // 与原账本的 AA 分摊语义一致;虚拟用户表(AA 参与人)同样整表拷贝。
    // 单事务保证要么全搬要么不搬,避免半拷贝被 sync 误用。
    await db.transaction(() async {
      final srcTxs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(sourceLedgerId)))
          .get();
      for (final tx in srcTxs) {
        final newTxId = await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                ledgerId: targetLedgerId,
                type: tx.type,
                amount: tx.amount,
                categoryId: d.Value(tx.categoryId),
                happenedAt: d.Value(tx.happenedAt),
                note: d.Value(tx.note),
                recurringId: d.Value(tx.recurringId),
                // 本地副本:新 syncId + 清共享 override(走本地 int categoryId)。
                syncId: d.Value(_uuid.v4()),
                createdByUserId: d.Value(tx.createdByUserId),
                lastEditedByUserId: d.Value(tx.lastEditedByUserId),
                excludeFromStats: d.Value(tx.excludeFromStats),
                currencyCode: d.Value(tx.currencyCode),
                nativeAmount: d.Value(tx.nativeAmount),
                version: d.Value(tx.version),
                lastEditedAt: d.Value(tx.lastEditedAt),
                // AA 分摊:整份随交易拷贝,副本账本保持与原账本一致的 AA 语义。
                paidByUserId: d.Value(tx.paidByUserId),
                aaMode: d.Value(tx.aaMode),
                aaParticipants: tx.aaParticipants != null
                    ? d.Value(tx.aaParticipants!)
                    : const d.Value.absent(),
                aaSplits: tx.aaSplits != null
                    ? d.Value(tx.aaSplits!)
                    : const d.Value.absent(),
              ),
            );
        // 拷贝该交易的编辑历史(保留 operatorUserId 作审计文本)。
        final hist = await (db.select(db.recordEditHistories)
              ..where((h) => h.recordId.equals(tx.id)))
            .get();
        for (final h in hist) {
          await db.into(db.recordEditHistories).insert(
                RecordEditHistoriesCompanion.insert(
                  recordId: newTxId,
                  version: h.version,
                  operatorUserId: d.Value(h.operatorUserId),
                  summary: h.summary,
                  createdAt: d.Value(h.createdAt),
                ),
              );
        }
      }
      // 拷贝虚拟用户(AA 分摊参与人):整表按账本维度复制,新 syncId 独立成副本。
      final srcVirtualUsers = await (db.select(db.ledgerVirtualUsers)
            ..where((v) => v.ledgerId.equals(sourceLedgerId)))
          .get();
      for (final vu in srcVirtualUsers) {
        await db.into(db.ledgerVirtualUsers).insert(
              LedgerVirtualUsersCompanion.insert(
                ledgerId: targetLedgerId,
                syncId: d.Value(_uuid.v4()),
                name: vu.name,
                createdAt: d.Value(vu.createdAt),
                updatedAt: vu.updatedAt != null
                    ? d.Value(vu.updatedAt!)
                    : const d.Value.absent(),
              ),
            );
      }
    });
  }

  @override
  Future<void> updateLedgerName({required int id, required String name}) async {
    await (db.update(db.ledgers)..where((tbl) => tbl.id.equals(id))).write(
      LedgersCompanion(name: d.Value(name)),
    );
  }

  @override
  Future<void> updateLedger({
    required int id,
    String? name,
    String? currency,
    int? monthStartDay,
    bool? aaEnabled,
  }) async {
    final comp = LedgersCompanion(
      name: name != null ? d.Value(name) : const d.Value.absent(),
      currency: currency != null ? d.Value(currency) : const d.Value.absent(),
      monthStartDay: monthStartDay != null
          ? d.Value(monthStartDay.clamp(1, 28))
          : const d.Value.absent(),
      // AA 开关:null = 不更新;非 null = 显式写入(跨设备同步)
      aaEnabled: aaEnabled != null
          ? d.Value(aaEnabled)
          : const d.Value.absent(),
    );
    await (db.update(db.ledgers)..where((tbl) => tbl.id.equals(id)))
        .write(comp);
  }

  @override
  Stream<Ledger?> watchLedger(int id) {
    return (db.select(db.ledgers)..where((l) => l.id.equals(id)))
        .watchSingleOrNull();
  }

  @override
  Future<void> deleteLedger(int id) async {
    // 先删除该账本下的所有交易，再删除账本本身
    await db.transaction(() async {
      await (db.delete(db.transactions)..where((t) => t.ledgerId.equals(id)))
          .go();
      await (db.delete(db.ledgers)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  @override
  Future<int> getMaxLedgerId() async {
    final row = await db.customSelect(
        'SELECT IFNULL(MAX(id), 0) AS m FROM ledgers',
        readsFrom: {db.ledgers}).getSingle();
    final v = row.data['m'];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Future<int> getNextFreeLedgerId() async {
    final maxId = await getMaxLedgerId();
    return maxId + 1;
  }

  @override
  Future<void> reassignLedgerId({
    required int fromId,
    required int toId,
  }) async {
    if (fromId == toId) return;
    final existsTo = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(toId)))
        .getSingleOrNull();
    if (existsTo != null) {
      throw StateError('目标账本ID已存在: $toId');
    }
    await db.transaction(() async {
      // 先迁移子表中的外键引用
      await db.customUpdate(
        'UPDATE transactions SET ledger_id = ?1 WHERE ledger_id = ?2',
        variables: [d.Variable<int>(toId), d.Variable<int>(fromId)],
        updates: {db.transactions},
      );
      // 再更新主表ID（SQLite 允许更新 INTEGER PRIMARY KEY 的值）
      await db.customUpdate(
        'UPDATE ledgers SET id = ?1 WHERE id = ?2',
        variables: [d.Variable<int>(toId), d.Variable<int>(fromId)],
        updates: {db.ledgers},
      );
    });
  }

  @override
  Future<int> clearLedgerTransactions(int ledgerId) async {
    // 删除该账本下的全部交易记录
    final count = await (db.delete(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .go();
    return count;
  }

  @override
  Future<void> clearLocalChangesForLedger(int ledgerId) async {
    // 为什么需要这个方法:deleteLedger 会向 local_changes 登记 delete 变更
    // (供正常同步推送)。但「全局删除账本」场景下远端已先行删除,这些残留
    // change 若被 SyncCoordinator 捡起,会向已删除的远端账本推送、甚至触发
    // 快照复活,因此删除完成后必须一次性抹掉该账本的所有待推送变更。
    await (db.delete(db.localChanges)
          ..where((c) => c.ledgerId.equals(ledgerId)))
        .go();
  }

  @override
  Future<void> purgeSharedLedger(String externalId, {int? localId}) async {
    // 1) 解析本地 id:localId 优先锁定唯一账本;syncId 匹配仅在 externalId 非空时
    //    执行(覆盖 dup 行——ledgers.sync_id 无 UNIQUE 约束,dup 行真实存在)。
    //    空串必须跳过 syncId 匹配:否则 WHERE syncId='' 会误命中所有空 syncId 行,
    //    其中往往包含从未上云的个人账本,造成误删。
    final localIds = <int>{};
    if (externalId.isNotEmpty) {
      final matched = await (db.select(db.ledgers)
            ..where((l) => l.syncId.equals(externalId)))
          .get();
      localIds.addAll(matched.map((l) => l.id));
    }
    if (localId != null) localIds.add(localId);
    if (localIds.isEmpty) return; // 幂等快路径:本地已经没有该账本
    // 2) 单个事务内按「local_changes → 镜像表 → 交易 → 账本行」顺序清除,
    //    保证要么全清要么不清,避免半清状态被 sync 误用。dup 行一并清掉。
    await db.transaction(() async {
      // 2a) 清 local_changes(按本地 int ledgerId),避免同步引擎之后误重放
      for (final id in localIds) {
        await (db.delete(db.localChanges)
              ..where((c) => c.ledgerId.equals(id)))
            .go();
      }
      // 2b) SharedLedger* 镜像表按 ledgerSyncId(Text)清
      await (db.delete(db.ledgerMembers)
            ..where((t) => t.ledgerSyncId.equals(externalId)))
          .go();
      await (db.delete(db.sharedLedgerCategories)
            ..where((t) => t.ledgerSyncId.equals(externalId)))
          .go();
      // 2c) 交易走 ledgers 外键级联;显式删 transactions 再删账本行(逐条含 dup)
      for (final id in localIds) {
        await (db.delete(db.transactions)
              ..where((t) => t.ledgerId.equals(id)))
            .go();
        await (db.delete(db.ledgers)..where((l) => l.id.equals(id))).go();
      }
    });
  }

  @override
  Future<void> purgeAllSharedLedgers() async {
    // 一次取出所有共享账本的本地 id 与 syncId。
    // 选择键是 isShared,与 syncId 是否为空无关——空 syncId 行也会在此被清,
    // 且只清共享账本,个人账本(syncId 可能也为空)不受影响。
    final rows = await (db.select(db.ledgers)
          ..where((l) => l.isShared.equals(true)))
        .get();
    if (rows.isEmpty) return; // 幂等快路径:本地没有任何共享账本
    final localIds = rows.map((r) => r.id).toList();
    // 过滤 null / 空串:镜像表按 ledgerSyncId(Text)清,null 无法参与 IN 匹配,
    // 空串行本就不该存在于镜像表,过滤后语义更干净。
    final syncIds = rows
        .map((r) => r.syncId)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    // 单事务内按「local_changes → 镜像表 → 交易 → 账本行」级联清除,
    // 保证要么全清要么不清,避免半清状态被 sync 误用。
    await db.transaction(() async {
      await (db.delete(db.localChanges)
            ..where((c) => c.ledgerId.isIn(localIds)))
          .go();
      if (syncIds.isNotEmpty) {
        await (db.delete(db.ledgerMembers)
              ..where((t) => t.ledgerSyncId.isIn(syncIds)))
            .go();
        await (db.delete(db.sharedLedgerCategories)
              ..where((t) => t.ledgerSyncId.isIn(syncIds)))
            .go();
      }
      await (db.delete(db.transactions)
            ..where((t) => t.ledgerId.isIn(localIds)))
          .go();
      await (db.delete(db.ledgers)..where((l) => l.id.isIn(localIds))).go();
    });
  }

  @override
  Future<void> purgeAllCloudLedgers() async {
    // 退出登录 = 这台设备不持有云账号的数据。
    // 选择键统一走 ledger_kind.dart 的 cloudLedgerFilter(语义:storage_mode='cloud'
    // OR isShared=true):storage_mode='cloud' 是归属模型下的正解(数据在云上,重登
    // 会拉回来);isShared=true 兜底(部分数据 storage_mode 可能未标记为 cloud,
    // 但共享账本属于别人的云端资源,退出后绝不能留在本地)。纯本地账本(local 且非共享)
    // 一行都不动 —— 那是这台设备自己的数据。
    final rows = await (db.select(db.ledgers)..where(cloudLedgerFilter)).get();
    if (rows.isEmpty) return; // 幂等快路径
    final localIds = rows.map((r) => r.id).toList();
    final syncIds = rows
        .map((r) => r.syncId)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    // 先取待删交易 id,用于连带清编辑历史(record_edit_histories 引用 tx.id,
    // 只删交易会留下永远匹配不上的孤儿历史行)。
    final txIds = (await (db.select(db.transactions)
              ..where((t) => t.ledgerId.isIn(localIds)))
            .get())
        .map((t) => t.id)
        .toList();

    // 单事务级联:local_changes → 编辑历史 → 镜像表 → 交易 → 账本行。
    await db.transaction(() async {
      await (db.delete(db.localChanges)
            ..where((c) => c.ledgerId.isIn(localIds)))
          .go();
      if (txIds.isNotEmpty) {
        await (db.delete(db.recordEditHistories)
              ..where((h) => h.recordId.isIn(txIds)))
            .go();
      }
      if (syncIds.isNotEmpty) {
        await (db.delete(db.ledgerMembers)
              ..where((t) => t.ledgerSyncId.isIn(syncIds)))
            .go();
        await (db.delete(db.sharedLedgerCategories)
              ..where((t) => t.ledgerSyncId.isIn(syncIds)))
            .go();
      }
      await (db.delete(db.transactions)
            ..where((t) => t.ledgerId.isIn(localIds)))
          .go();
      await (db.delete(db.ledgers)..where((l) => l.id.isIn(localIds))).go();
    });
  }

  @override
  Future<({int personal, int shared})> normalizeOrphanCloudLedgers() async {
    // 选区与 purgeAllCloudLedgers 同源(cloudLedgerFilter),但动作相反:
    // purge 是「退出登录,云端数据不该滞留」→ 删行;
    // normalize 是「未登录恢复出的云端账本无法转本地」→ 只改归属字段、一行不删。
    // 恢复出来的账本里躺着用户的真实流水,任何删除都是数据损失。
    final rows = await (db.select(db.ledgers)..where(cloudLedgerFilter)).get();
    if (rows.isEmpty) return (personal: 0, shared: 0); // 幂等快路径:不进事务

    // 按 isShared 的**原值**分计数 —— 字段清完之后就再也分不出这两类了,
    // 必须在改写前统计。
    var personal = 0;
    var shared = 0;
    for (final r in rows) {
      if (r.isShared) {
        shared++;
      } else {
        personal++;
      }
    }

    final localIds = rows.map((r) => r.id).toList();
    final syncIds = rows
        .map((r) => r.syncId)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    await db.transaction(() async {
      // 顺序不可调换:镜像表以 ledger_sync_id 关联账本,一旦先清空 syncId,
      // 这些协作行就再也定位不到宿主账本、变成永久孤儿(共享账本的成员列表
      // 与共享分类会继续被 UI 读到,形成脏数据)。
      if (syncIds.isNotEmpty) {
        await (db.delete(db.ledgerMembers)
              ..where((t) => t.ledgerSyncId.isIn(syncIds)))
            .go();
        await (db.delete(db.sharedLedgerCategories)
              ..where((t) => t.ledgerSyncId.isIn(syncIds)))
            .go();
      }

      // 归属六件套一次写全:少清任何一个都会让账本卡在半云半本地态
      // (例如只清 storageMode 而留 isShared=true,仍会被云闸门拦截)。
      // syncId / ownerUserId 必须写 Value<String?>(null):裸 Value(null) 会被
      // 推断成 Value<Null> 而无法匹配 Value<String?> 字段,直接编译失败。
      await (db.update(db.ledgers)..where((l) => l.id.isIn(localIds))).write(
        const LedgersCompanion(
          storageMode: d.Value('local'),
          syncId: d.Value<String?>(null),
          isShared: d.Value(false),
          myRole: d.Value('owner'),
          memberCount: d.Value(1),
          ownerUserId: d.Value<String?>(null),
        ),
      );
    });

    return (personal: personal, shared: shared);
  }
}
