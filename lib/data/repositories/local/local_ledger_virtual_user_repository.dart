import 'dart:async';

import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../ledger_virtual_user_repository.dart';

/// AA 分摊:虚拟用户本地 Repository 实现。
///
/// 基于 Drift 数据库实现 [LedgerVirtualUserRepository] 接口。
/// 本实现是子仓库层,不挂 changeTracker —— sync 登记由外层
/// [LocalRepository] 委托层负责(与其他子仓库保持一致)。
class LocalLedgerVirtualUserRepository implements LedgerVirtualUserRepository {
  final SpitoutDatabase db;

  LocalLedgerVirtualUserRepository(this.db);

  static const _uuid = Uuid();

  @override
  Stream<List<LedgerVirtualUser>> watchByLedger(int ledgerId) {
    return (db.select(db.ledgerVirtualUsers)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) => d.OrderingTerm(expression: t.id, mode: d.OrderingMode.asc)
          ]))
        .watch();
  }

  @override
  Future<List<LedgerVirtualUser>> getByLedger(int ledgerId) async {
    return await (db.select(db.ledgerVirtualUsers)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([
            (t) => d.OrderingTerm(expression: t.id, mode: d.OrderingMode.asc)
          ]))
        .get();
  }

  @override
  Future<LedgerVirtualUser?> getBySyncId(String syncId) async {
    return await (db.select(db.ledgerVirtualUsers)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();
  }

  @override
  Future<int> create({
    required int ledgerId,
    required String name,
    String? syncId,
  }) async {
    // 新建场景自动填 UUID;sync pull 时由调用方传 server 下发的 syncId。
    final effectiveSyncId = syncId ?? _uuid.v4();
    return db.into(db.ledgerVirtualUsers).insert(
          LedgerVirtualUsersCompanion.insert(
            ledgerId: ledgerId,
            syncId: d.Value(effectiveSyncId),
            name: name,
          ),
        );
  }

  @override
  Future<void> rename({
    required int id,
    required String name,
  }) async {
    await (db.update(db.ledgerVirtualUsers)..where((t) => t.id.equals(id)))
        .write(LedgerVirtualUsersCompanion(
      name: d.Value(name),
      updatedAt: d.Value(DateTime.now()),
    ));
  }

  @override
  Future<bool> delete(int id) async {
    // 名下有账不可删。先校验引用,被引用则抛错阻止删除。
    final referenced = await isReferencedByAnyTransaction(id);
    if (referenced) {
      throw StateError(
          '虚拟用户(id=$id)被交易的 aaParticipants 引用,不允许删除');
    }
    // 未被引用 → 硬删
    final n = await (db.delete(db.ledgerVirtualUsers)
          ..where((t) => t.id.equals(id)))
        .go();
    return n > 0;
  }

  @override
  Future<bool> isReferencedByAnyTransaction(int id) async {
    // 先查虚拟用户的 syncId(跨设备引用走 syncId 而非本地 int id)
    final user = await (db.select(db.ledgerVirtualUsers)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (user == null || user.syncId == null) {
      // 未创建或未同步(syncId 为 null)的虚拟用户不会被交易引用
      return false;
    }
    // 交易的 aaParticipants 是 JSON 数组字符串,包含 userId 或虚拟用户 syncId。
    // 用 LIKE 模糊匹配 aaParticipants 列中包含该 syncId 的行。
    // 这不是精确 JSON 解析,但足以做"是否被引用"的判定 ——
    // syncId 是 UUID,出现在 aaParticipants 中即可判定被引用。
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions '
      "WHERE aa_participants LIKE ?1",
      variables: [d.Variable.withString('%${user.syncId}%')],
      readsFrom: {db.transactions},
    ).getSingle();
    final v = row.data['c'];
    if (v is int) return v > 0;
    if (v is BigInt) return v.toInt() > 0;
    if (v is num) return v.toInt() > 0;
    return false;
  }
}
