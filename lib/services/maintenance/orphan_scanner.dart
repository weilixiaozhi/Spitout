/// 本地孤儿数据扫描器。
///
/// `scanXxx()` 方法各自独立,只查不改;`scanAll()` 一次跑完返
/// [OrphanScanReport]。逻辑严格按 plan A 类 / C1 实现
/// (不含文件类 B 检测,分类图标不支持自定义)。
///
/// 注意:
/// - DB 类用 Drift `customSelect` + LEFT JOIN,跨 `transaction()` 不必要,
///   纯读不会污染状态。
library;

import '../../data/db.dart';
import 'orphan_record.dart';

class OrphanScanner {
  OrphanScanner({
    required this.db,
  });

  final SpitoutDatabase db;

  /// 跑全部检测项。
  Future<OrphanScanReport> scanAll() async {
    final dbOrphans = <OrphanRecord>[
      ...await scanTxMissingCategory(),
      ...await scanCategoryMissingParent(),
      ...await scanSharedCategoryMissingParent(),
      ...await scanTxMissingLedger(),
      ...await scanTxDuplicateSyncId(),
    ];
    final syncOrphans = <OrphanRecord>[
      ...await scanLocalChangeMissingEntity(),
    ];
    return OrphanScanReport(
      dbOrphans: dbOrphans,
      syncOrphans: syncOrphans,
    );
  }

  // ─────────────────────────── A. DB 孤儿（不含标签/预算/附件相关检测 A1/A2/A3/A4/A8/A10） ───────────────────────────

  /// A6 — 交易的 `category_id` 在 categories 表不存在(非 null)。
  Future<List<OrphanRecord>> scanTxMissingCategory() async {
    final rows = await db.customSelect(
      '''
      SELECT t.id AS tx_id, t.amount, t.type, t.category_id
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.category_id IS NOT NULL AND c.id IS NULL
      ''',
      readsFrom: {db.transactions, db.categories},
    ).get();
    return rows.map((row) {
      final txId = row.read<int>('tx_id');
      // 数据库金额为整数分,展示转"元"。
      final amount = (row.readNullable<num>('amount') ?? 0).toDouble() / 100;
      final txType = row.readNullable<String>('type') ?? '';
      final catId = row.read<int>('category_id');
      return OrphanRecord(
        type: OrphanType.txMissingCategory,
        localId: txId,
        title: '交易 #$txId',
        subtitle: '$txType · ¥${amount.toStringAsFixed(2)} · 分类已删 (categoryId=$catId)',
      );
    }).toList();
  }

  /// A7 — 二级分类 `parent_id` 在 categories 表不存在。
  Future<List<OrphanRecord>> scanCategoryMissingParent() async {
    final rows = await db.customSelect(
      '''
      SELECT c.id AS cat_id, c.name, c.parent_id, c.kind
      FROM categories c
      LEFT JOIN categories p ON p.id = c.parent_id
      WHERE c.level = 2 AND c.parent_id IS NOT NULL AND p.id IS NULL
      ''',
      readsFrom: {db.categories},
    ).get();
    return rows.map((row) {
      final catId = row.read<int>('cat_id');
      final name = row.readNullable<String>('name') ?? '';
      final parentId = row.read<int>('parent_id');
      final kind = row.readNullable<String>('kind') ?? '';
      return OrphanRecord(
        type: OrphanType.categoryMissingParent,
        localId: catId,
        title: '二级分类「$name」#$catId',
        subtitle: '$kind · 父分类已删 (parentId=$parentId)',
      );
    }).toList();
  }

  /// A9 — 共享二级分类的 `parent_sync_id` 在同 ledger 的 SharedLedgerCategories
  /// 范围内不存在。复合主键 (ledger_sync_id, sync_id) → 用 NOT IN 子查询。
  Future<List<OrphanRecord>> scanSharedCategoryMissingParent() async {
    final rows = await db.customSelect(
      '''
      SELECT child.ledger_sync_id, child.sync_id, child.name, child.parent_sync_id
      FROM shared_ledger_categories child
      WHERE COALESCE(child.level, 1) = 2
        AND child.parent_sync_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM shared_ledger_categories parent
          WHERE parent.ledger_sync_id = child.ledger_sync_id
            AND parent.sync_id = child.parent_sync_id
            AND COALESCE(parent.level, 1) = 1
        )
      ''',
      readsFrom: {db.sharedLedgerCategories},
    ).get();
    return rows.map((row) {
      final ledgerSyncId = row.read<String>('ledger_sync_id');
      final syncId = row.read<String>('sync_id');
      final name = row.readNullable<String>('name') ?? '';
      final parentSyncId = row.readNullable<String>('parent_sync_id') ?? '';
      return OrphanRecord(
        type: OrphanType.sharedCategoryMissingParent,
        syncId: syncId,
        title: '共享二级分类「$name」',
        subtitle: '父分类已删 (parentSyncId=$parentSyncId)',
        extra: {'ledgerSyncId': ledgerSyncId},
      );
    }).toList();
  }

  /// A_new — 交易的 `ledger_id` 在 ledgers 表不存在(无账本孤儿数据)。
  /// 与 A6(category 失主)不同,ledger_id 为 NOT NULL 列,
  /// 而非可空的 category_id,因此清理时需直接删除该交易。
  Future<List<OrphanRecord>> scanTxMissingLedger() async {
    final rows = await db.customSelect(
      '''
      SELECT t.id AS tx_id, t.amount, t.type, t.ledger_id
      FROM transactions t
      LEFT JOIN ledgers l ON l.id = t.ledger_id
      WHERE l.id IS NULL
      ''',
      readsFrom: {db.transactions, db.ledgers},
    ).get();
    return rows.map((row) {
      final txId = row.read<int>('tx_id');
      final amount = (row.readNullable<num>('amount') ?? 0).toDouble() / 100;
      final txType = row.readNullable<String>('type') ?? '';
      final ledgerId = row.read<int>('ledger_id');
      return OrphanRecord(
        type: OrphanType.txMissingLedger,
        localId: txId,
        title: '交易 #$txId',
        subtitle: '$txType · ¥${amount.toStringAsFixed(2)} · 账本已删 (ledgerId=$ledgerId)',
        // 记录已删账本 ID,供 UI 层按账本分组 + 移动到其他账本时使用
        extra: {'ledgerId': ledgerId},
      );
    }).toList();
  }

  /// A_dup — 同账本内 `sync_id` 重复的交易(云端全量恢复盲插导致的重复行)。
  ///
  /// 为什么会出现:transactions.sync_id 无 UNIQUE 约束,
  /// "下拉刷新 → 全量恢复盲插" 会把整份云端快照重复插回本地。
  /// 去重策略:按 (ledger_id, sync_id) 分组,保留最早插入的一条(MIN(id),
  /// 即原始行),其余重复行全部报为孤儿供用户勾选删除。
  Future<List<OrphanRecord>> scanTxDuplicateSyncId() async {
    final rows = await db.customSelect(
      '''
      SELECT t.id AS tx_id, t.amount, t.type, t.sync_id, t.ledger_id
      FROM transactions t
      JOIN (
        SELECT ledger_id, sync_id, MIN(id) AS keep_id
        FROM transactions
        WHERE sync_id IS NOT NULL AND sync_id != ''
        GROUP BY ledger_id, sync_id
        HAVING COUNT(*) > 1
      ) dup ON dup.ledger_id = t.ledger_id AND dup.sync_id = t.sync_id
      WHERE t.id != dup.keep_id
      ''',
      readsFrom: {db.transactions},
    ).get();
    return rows.map((row) {
      final txId = row.read<int>('tx_id');
      final amount = (row.readNullable<num>('amount') ?? 0).toDouble() / 100;
      final txType = row.readNullable<String>('type') ?? '';
      final syncId = row.read<String>('sync_id');
      final ledgerId = row.read<int>('ledger_id');
      return OrphanRecord(
        type: OrphanType.txDuplicateSyncId,
        localId: txId,
        syncId: syncId,
        title: '重复交易 #$txId',
        subtitle: '$txType · ¥${amount.toStringAsFixed(2)} · '
            '同步ID重复 (ledgerId=$ledgerId)',
        extra: {'ledgerId': ledgerId},
      );
    }).toList();
  }

  // ─────────────────────────── C. 同步孤儿 ───────────────────────────

  /// C1 — `local_changes.entity_sync_id` 对应的本地实体已不存在(且未推送)。
  ///
  /// entity_type 分支:
  /// - transaction → transactions.sync_id
  /// - category → categories.sync_id
  /// - ledger_snapshot / ledger → ledgers.sync_id
  /// - virtual_user → ledger_virtual_users.sync_id
  /// - exchange_rate_override → exchange_rate_overrides.sync_id
  ///
  /// 注:`action = 'delete'` 的 change 不算孤儿(它的语义就是删除,实体本来该
  /// 不在了)。
  Future<List<OrphanRecord>> scanLocalChangeMissingEntity() async {
    final rows = await db.customSelect(
      '''
      SELECT lc.id AS lc_id, lc.entity_type, lc.entity_sync_id, lc.action,
             lc.created_at
      FROM local_changes lc
      WHERE lc.pushed_at IS NULL
        AND lc.action != 'delete'
        AND NOT EXISTS (
          SELECT 1 FROM transactions t
            WHERE lc.entity_type = 'transaction' AND t.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM categories c
            WHERE lc.entity_type = 'category' AND c.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM ledgers l
            WHERE lc.entity_type IN ('ledger', 'ledger_snapshot')
              AND l.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM ledger_virtual_users vu
            WHERE lc.entity_type = 'virtual_user'
              AND vu.sync_id = lc.entity_sync_id
          UNION ALL
          SELECT 1 FROM exchange_rate_overrides ero
            WHERE lc.entity_type = 'exchange_rate_override'
              AND ero.sync_id = lc.entity_sync_id
        )
      ''',
      readsFrom: {
        db.localChanges,
        db.transactions,
        db.categories,
        db.ledgers,
        db.ledgerVirtualUsers,
        db.exchangeRateOverrides,
      },
    ).get();
    return rows.map((row) {
      final lcId = row.read<int>('lc_id');
      final entityType = row.read<String>('entity_type');
      final entitySyncId = row.read<String>('entity_sync_id');
      final action = row.read<String>('action');
      return OrphanRecord(
        type: OrphanType.localChangeMissingEntity,
        localId: lcId,
        syncId: entitySyncId,
        title: '同步变更 #$lcId',
        subtitle: '$entityType · $action · 实体已删 (syncId=$entitySyncId)',
      );
    }).toList();
  }

}
