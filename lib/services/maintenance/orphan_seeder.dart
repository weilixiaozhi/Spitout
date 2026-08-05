/// **仅 debug 测试用** — 在本地 DB / 文件系统手动塞各类孤儿数据。
///
/// `OrphanCleanupPage` 在 debug build 的 header actions 露一个 bug 图标按钮,
/// 点一下调 [seedAll],立刻能在清理列表里看到 10+ 项异常,验证 scanner /
/// cleaner / UI 全链路。
///
/// **不要在 release build 调用** — `kDebugMode` 守门,正式包不会暴露入口。
library;

import 'dart:math';

import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../../core/logging/logger_service.dart';

class OrphanSeeder {
  OrphanSeeder({required this.db});
  final SpitoutDatabase db;
  final _rand = Random();

  /// 一键塞多项孤儿,覆盖 A/C 各大类。返回汇总 log,方便 toast 显示。
  Future<String> seedAll() async {
    final lines = <String>[];
    try {
      lines.add('A6: ${await _seedTxMissingCategory()} 个');
      lines.add('A7: ${await _seedCategoryMissingParent()} 个');
      lines.add('A_new(无账本): ${await _seedTxMissingLedger()} 个');
      lines.add('C1: ${await _seedLocalChangeMissing()} 个');
    } catch (e, st) {
      logger.error('OrphanSeeder', '种孤儿数据失败', e, st);
      return '失败: $e';
    }
    return lines.join('\n');
  }

  // ────────────── A 类 — 直接绕过级联删主表（不含标签/预算/附件相关 A1/A2/A3A4/A8/A10） ──────────────

  Future<int> _seedTxMissingCategory() async {
    final lid = await _ensureLedger();
    final cid = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
            name: '_seed_cat_${_rand.nextInt(99999)}', kind: 'expense'));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: lid,
          type: 'expense',
          amount: 660,
          categoryId: d.Value(cid),
          happenedAt: d.Value(DateTime.now()),
          syncId: d.Value('seed-tx-${_rand.nextInt(99999)}'),
        ));
    await (db.delete(db.categories)..where((t) => t.id.equals(cid))).go();
    return 1;
  }

  Future<int> _seedCategoryMissingParent() async {
    final parent = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
            name: '_seed_parent_${_rand.nextInt(99999)}', kind: 'expense'));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '_seed_child_${_rand.nextInt(99999)}',
          kind: 'expense',
          parentId: d.Value(parent),
          level: const d.Value(2),
        ));
    await (db.delete(db.categories)..where((t) => t.id.equals(parent))).go();
    return 1;
  }

  /// 创建临时账本 → 插入交易引用该账本 → 删除账本,留下孤儿交易(无账本数据)。
  Future<int> _seedTxMissingLedger() async {
    final lid = await db.into(db.ledgers).insert(
        LedgersCompanion.insert(
            name: '_seed_rm_${_rand.nextInt(99999)}',
            syncId: d.Value('seed-to-delete-${_rand.nextInt(99999)}')));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: lid,
          type: 'expense',
          amount: 666,
          categoryId: const d.Value(null),
          happenedAt: d.Value(DateTime.now()),
          syncId: d.Value('seed-tx-no-ledger-${_rand.nextInt(99999)}'),
        ));
    // 删除账本 — 交易保留,ledger_id 成为悬空引用
    await (db.delete(db.ledgers)..where((t) => t.id.equals(lid))).go();
    return 1;
  }

  // ────────────── C 类 ──────────────

  Future<int> _seedLocalChangeMissing() async {
    await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
          entityType: 'transaction',
          entityId: 999990 + _rand.nextInt(1000),
          entitySyncId: 'seed-ghost-tx-c1-${_rand.nextInt(99999)}',
          ledgerId: 1,
          action: 'update',
        ));
    return 1;
  }

  // ────────────── helpers ──────────────

  Future<int> _ensureLedger() async {
    final existing = await (db.select(db.ledgers)..limit(1)).getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: '_seed_holder', syncId: const d.Value('seed-holder')));
  }
}
