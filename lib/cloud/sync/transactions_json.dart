import 'dart:convert';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:decimal/decimal.dart';
import '../../data/db.dart';
import '../../data/models.dart';
import '../../data/repositories/base_repository.dart';
import '../../services/import/data_import_service.dart';
import '../../core/logging/logger_service.dart';

/// 账本交易数据的 JSON 导入导出工具
///
/// 用于云同步时序列化和反序列化交易数据

/// 账本快照 JSON 的当前版本号。
///
/// 快照导出（transactions_json / sync_engine_serialization 的 fullPush）
/// 必须统一引用本常量，避免增量栈升级到 v8+ 时快照栈悄悄落后。
const int transactionsJsonVersion = 7;

// --- 字符串清理 ---

/// 清理字符串中的控制字符，防止 JSON 解析错误
String _sanitizeString(String? input) {
  if (input == null) return '';
  // 移除所有控制字符（ASCII 0-31，除了常见的制表符、换行符等）
  // 并替换换行符和制表符为空格
  return input
      .replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('\t', ' ')
      .trim();
}

// --- 导出 ---

/// 导出账本交易数据为 JSON 字符串
///
/// [db] - 数据库实例
/// [ledgerId] - 账本ID
///
/// 返回包含以下字段的 JSON：
/// - version: 数据格式版本（当前为 [transactionsJsonVersion]）
/// - exportedAt: 导出时间戳
/// - ledgerId: 账本ID
/// - ledgerName: 账本名称
/// - currency: 货币
/// - count: 交易条数
/// - categories: 分类列表（name, kind, level, icon, parentName）
/// - items: 交易明细（type, amount, categoryName, categoryKind, happenedAt, note,
///   syncId, currencyCode, nativeAmount, excludeFromStats）
Future<String> exportTransactionsJson(SpitoutDatabase db, int ledgerId) async {
  logger.debug('TransactionsJson', '开始导出账本 $ledgerId');

  final txs = await (db.select(db.transactions)
        ..where((t) => t.ledgerId.equals(ledgerId)))
      .get();

  logger.debug('TransactionsJson', '账本 $ledgerId 共有 ${txs.length} 条交易');

  // 稳定排序，避免不同平台/查询导致顺序差异
  txs.sort((a, b) {
    final c = a.happenedAt.compareTo(b.happenedAt);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });

  // 获取所有交易

  // Map categoryId -> name/kind for used categories
  final usedCatIds = txs.map((t) => t.categoryId).whereType<int>().toSet();
  final cats = <int, Map<String, dynamic>>{};
  final allCategoriesSet = <int>{}; // 存储所有相关分类ID（包括父分类）

  for (final cid in usedCatIds) {
    final c = await (db.select(db.categories)..where((c) => c.id.equals(cid)))
        .getSingleOrNull();
    if (c != null) {
      final sanitizedName = _sanitizeString(c.name);
      cats[cid] = {"name": sanitizedName, "kind": c.kind};
      allCategoriesSet.add(cid);

      // 如果是二级分类，也需要导出其父分类
      if (c.level == 2 && c.parentId != null) {
        allCategoriesSet.add(c.parentId!);
      }
    }
  }

  // 交易导出不包含账户维度
  // Accounts 表不在当前同步域内,无法查账户名,导出 JSON 里也不携带账户信息。

  final items = txs.map((t) {
    // 安全获取分类信息（分类可能已被删除）
    final catInfo = t.categoryId != null ? cats[t.categoryId] : null;

    // 记录分类缺失的交易（用于排查数据问题）
    if (t.categoryId != null && catInfo == null) {
      logger.warning('TransactionsJson',
        '交易 ${t.id} 引用了不存在的分类 ${t.categoryId}, '
        'amount=${t.amount}, note=${t.note}, happenedAt=${t.happenedAt}');
    }

    final nativeAmount = t.nativeAmount;
    final item = <String, dynamic>{
      'type': t.type,
      // 数据库存整数分,JSON 备份/云端恢复仍按"元"口径输出(契约不变)。
      'amount': t.amount / 100,
      'categoryName': catInfo?['name'],
      'categoryKind': catInfo?['kind'],
      'happenedAt': t.happenedAt.toUtc().toIso8601String(),
      'note': _sanitizeString(t.note),
      if (t.syncId != null) 'syncId': t.syncId,
      // 交易级多币种 + 免统计标记:补齐导出才能让"JSON 备份恢复"与
      // "/sync/full 全量恢复"round-trip 保真。server snapshot 同样输出这三键,
      // 键名 camelCase 与服务端契约对齐。
      if (t.currencyCode != null) 'currencyCode': t.currencyCode,
      if (nativeAmount != null) 'nativeAmount': nativeAmount / 100,
      // 缺键 = false(server snapshot 同语义),只为 true 时输出,保持 payload 干净。
      if (t.excludeFromStats) 'excludeFromStats': true,
      // 创建人(非空才发):供导入侧「默认支出人 = 创建人」兜底,与 AA 字段
      // 同样的缺键兼容策略(v6 及更早备份无此键 → 导入兜底空串)。
      if (t.createdByUserId != null && t.createdByUserId!.isNotEmpty)
        'createdByUserId': t.createdByUserId,
      // AA 分摊字段(非空才发,与 serializer "非空才发"守卫一致):
      // 缺键导入兜底为 null → 视为未启用 AA,与旧 v6 备份兼容。
      if (t.paidByUserId != null && t.paidByUserId!.isNotEmpty)
        'paidByUserId': t.paidByUserId,
      if (t.aaMode != null) 'aaMode': t.aaMode,
      if (t.aaParticipants != null && t.aaParticipants!.isNotEmpty)
        'aaParticipants': t.aaParticipants,
      if (t.aaSplits != null && t.aaSplits!.isNotEmpty)
        'aaSplits': t.aaSplits,
    };

    return item;
  }).toList();

  // ledger meta
  final ledger = await (db.select(db.ledgers)
        ..where((l) => l.id.equals(ledgerId)))
      .getSingleOrNull();

  // 构建 categories 数组（包含图标、层级、父分类信息）
  final categoryItems = <Map<String, dynamic>>[];
  final allCategoriesList = await (db.select(db.categories)
        ..where((c) => c.id.isIn(allCategoriesSet.toList())))
      .get();

  // 先导出一级分类，再导出二级分类（便于导入时先创建父分类）
  allCategoriesList.sort((a, b) {
    if (a.level != b.level) return a.level.compareTo(b.level);
    return a.id.compareTo(b.id);
  });

  for (final cat in allCategoriesList) {
    final categoryItem = <String, dynamic>{
      'name': _sanitizeString(cat.name),
      'kind': cat.kind,
      'level': cat.level,
      'sortOrder': cat.sortOrder, // 保存排序顺序
    };

    // 添加图标信息（如果存在）
    if (cat.icon != null && cat.icon!.isNotEmpty) {
      categoryItem['icon'] = cat.icon;
    }

    // 添加父分类名称（如果是二级分类）
    if (cat.level == 2 && cat.parentId != null) {
      final parentCat = allCategoriesList.firstWhere(
        (c) => c.id == cat.parentId,
        orElse: () => allCategoriesList.first, // 不应该发生
      );
      categoryItem['parentName'] = _sanitizeString(parentCat.name);
    }

    categoryItems.add(categoryItem);
  }

  // 检查账本是否存在
  if (ledger == null) {
    logger.error('TransactionsJson', '账本 $ledgerId 不存在！');
    throw Exception('账本 $ledgerId 不存在');
  }

  // 虚拟用户:随账本导出,否则导入后指定分摊数据(aaParticipants/
  // aaSplits 引用虚拟用户 syncId)会悬空。按 id 升序保证导出稳定。
  final virtualUsers = await (db.select(db.ledgerVirtualUsers)
        ..where((u) => u.ledgerId.equals(ledgerId))
        ..orderBy([(u) => OrderingTerm.asc(u.id)]))
      .get();
  final virtualUserItems = virtualUsers.map((u) {
    final vuItem = <String, dynamic>{
      'name': _sanitizeString(u.name),
    };
    if (u.syncId != null && u.syncId!.isNotEmpty) {
      vuItem['syncId'] = u.syncId;
    }
    return vuItem;
  }).toList();

  final payload = {
    'version': transactionsJsonVersion, // v7:AA 分摊功能(paidByUserId/aaMode/aaParticipants/
    // aaSplits + ledger.aaEnabled + virtualUsers 数组)。
    // v6 导入兜底为 null/空 → 视为未启用 AA,向后兼容。
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'ledgerId': ledgerId,
    'ledgerName': ledger.name,
    'currency': ledger.currency,
    'monthStartDay': ledger.monthStartDay,
    'aaEnabled': ledger.aaEnabled,
    'count': items.length,
    'categories': categoryItems,
    'items': items,
    'virtualUsers': virtualUserItems,
  };

  logger.debug('TransactionsJson',
      '导出完成: ${items.length} 条交易, ${categoryItems.length} 个分类, ${virtualUserItems.length} 个虚拟用户');
  return jsonEncode(payload);
}

// --- 导入 ---

/// 将 JSON 数据转换为统一的 ImportData 格式
ImportData parseJsonToImportData(String jsonStr) {
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;

  // 解析分类
  final categories = <ImportCategory>[];
  final jsonCategories = data['categories'] as List?;
  if (jsonCategories != null) {
    for (final cat in jsonCategories.cast<Map<String, dynamic>>()) {
      categories.add(ImportCategory(
        name: cat['name'] as String,
        kind: cat['kind'] as String,
        level: cat['level'] as int? ?? 1,
        sortOrder: cat['sortOrder'] as int? ?? 0,
        icon: cat['icon'] as String?,
        parentName: cat['parentName'] as String?,
      ));
    }
  }

  // 解析交易
  final transactions = <ImportTransaction>[];
  final jsonItems = data['items'] as List?;
  if (jsonItems != null) {
    for (final it in jsonItems.cast<Map<String, dynamic>>()) {
      final type = it['type'] as String;
      transactions.add(ImportTransaction(
        type: type,
        amount: Decimal.parse((it['amount'] as num).toString()),
        // 全量恢复保真(S1):/sync/full 与本文件导出路径都会输出这三键;
        // JSON 缺键 → null,落库走既有兜底(本位币/重算/false)。
        currencyCode: it['currencyCode'] as String?,
        nativeAmount: it['nativeAmount'] != null
            ? Decimal.parse((it['nativeAmount'] as num).toString())
            : null,
        excludeFromStats: it['excludeFromStats'] as bool?,
        categoryName: it['categoryName'] as String?,
        categoryKind: it['categoryKind'] as String?,
        happenedAt: DateTime.parse(it['happenedAt'] as String).toLocal(),
        note: it['note'] as String?,
        syncId: it['syncId'] as String?,
        // 创建人(v7 备份携带):支出人缺失时兜底「默认支出人 = 创建人」。
        createdByUserId: it['createdByUserId'] as String?,
        // AA 分摊字段:v6 缺键兜底 null → 落库视为未启用 AA。
        // v7 显式输出(非空才发),round-trip 保真。
        paidByUserId: it['paidByUserId'] as String?,
        aaMode: it['aaMode'] as int?,
        aaParticipants: it['aaParticipants'] as String?,
        aaSplits: it['aaSplits'] as String?,
      ));
    }
  }

  // 解析虚拟用户(v7+ 携带;v6 缺键 → 空列表,导入跳过)
  final virtualUsers = <ImportVirtualUser>[];
  final jsonVirtualUsers = data['virtualUsers'] as List?;
  if (jsonVirtualUsers != null) {
    for (final vu in jsonVirtualUsers.cast<Map<String, dynamic>>()) {
      virtualUsers.add(ImportVirtualUser(
        syncId: vu['syncId'] as String?,
        name: vu['name'] as String? ?? '',
      ));
    }
  }

  // monthStartDay 在导出 payload 里有,但这里刻意不读 —— 恢复路径由
  // syncLedgersFromServer 收敛。
  // aaEnabled:v6 缺键 → null(不更新账本既有值);v7 显式携带。
  return ImportData(
    categories: categories,
    transactions: transactions,
    virtualUsers: virtualUsers,
    ledgerName: data['ledgerName'] as String?,
    currency: data['currency'] as String?,
    aaEnabled: data['aaEnabled'] as bool?,
  );
}

/// 解析 JSON 并增量导入
///
/// [repo] - 数据仓库
/// [ledgerId] - 目标账本ID
/// [jsonStr] - JSON 字符串
/// [onProgress] - 进度回调 (已处理数, 总数)
///
/// 返回 (inserted,) 元组：
/// - inserted: 新增条数
Future<({int inserted})> importTransactionsJson(
  BaseRepository repo,
  int ledgerId,
  String jsonStr, {
  void Function(int done, int total)? onProgress,
  bool recordChanges = true,
}) async {
  // 1. 解析 JSON 为统一格式
  final importData = parseJsonToImportData(jsonStr);

  // 2. 使用统一导入服务
  // [recordChanges] 默认 true 兼容 CSV 导入路径(`data_import_service` 会
  // 通过 LocalRepository 写 local_changes 让本地变更能推到云端)。
  // SyncEngine.runFullPull 走"从云端拉数据"路径,显式传 false 避免反向回流。
  final result = await dataImportService.importData(
    repo,
    ledgerId,
    importData,
    defaultCurrency: importData.currency ?? 'CNY',
    onProgress: onProgress,
    recordChanges: recordChanges,
  );

  return (inserted: result.inserted,);
}
