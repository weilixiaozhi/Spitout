/// 记账页分类树缓存 provider。
///
/// 设计动机：记账编辑 sheet 的分类网格若用「两层嵌套 FutureBuilder +
/// 逐父分类串行查子分类（N+1）」会明显滞后；且 FutureBuilder 在 build 中
/// 新建 Future，每次按键 setState 都会触发全量重查。
///
/// 本 provider 的三层设计：
/// - **合并查询**：一次 select 取回该 kind 全部 level 1+2，内存分组（消灭 N+1）；
/// - **全局常驻缓存**（非 autoDispose）：app 启动即预热，sheet 打开时首帧
///   同步命中缓存，分类区无空白期；
/// - **零手动 invalidate**：以 Drift tableUpdates 监听 categories /
///   sharedLedgerCategories / ledgers 三表 —— 所有分类变更（管理页增删改/
///   排序/迁移、模板写入、导入 upsert、孤儿清理、云同步落库、WS 共享资源
///   变更）最终都写本地表，自动触发重建，不存在漏写 invalidate 显示旧数据
///   的维护成本。
library;

import 'dart:async';
import 'dart:collection';

import 'package:drift/drift.dart' as d;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/data/models/category_picker_tree.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';

/// 自愈拉取冷却时间:同一 ledgerSyncId 5 分钟内不重复打网络。
/// 选 5 分钟而非更短:WS 重连 / 邀请接受 / 切账本兜底等路径已覆盖多数实时
/// 同步场景,本自愈是"用户打开记账页"的最后一道兜底,不应频繁触发;
/// 5 分钟也短到足以让弱网失败的用户重开 app 后能重试。
const _selfHealCooldown = Duration(minutes: 5);

/// per-ledgerSyncId 的下次允许拉取时间(UTC 时间戳)。
///
/// 用 HashMap 而非 Set:需要在每次"打开"时记录"何时可再拉"而非"是否曾拉过"
/// —— 失败也写入,保证弱网失败后等冷却到期允许重试(Set 模式失败一次就永久
/// 阻断,不满足弱网重试需求)。
///
/// 用 provider 而非模块级全局 Map:让状态绑定 Riverpod 生命周期,
/// 随 ProviderContainer 的 dispose 自动回收,避免跨测试用例残留污染。
final selfHealCooldownProvider =
    Provider<HashMap<String, DateTime>>((ref) => HashMap<String, DateTime>());

/// 记账页分类树。family 参数为分类 kind（全局仅支出模式，恒为 'expense'）。
final categoryPickerTreeProvider =
    StreamProvider.family<CategoryPickerTree, String>((ref, kind) {
  final repo = ref.watch(repositoryProvider);
  // 切账本即重建:共享账本 Editor 视角的分类树取决于当前账本上下文。
  final ledgerId = ref.watch(currentLedgerIdProvider);

  final db = repo.db;

  Future<CategoryPickerTree> load() async {
    // 共享账本 Editor:主表内容整体丢弃,替换为 SharedLedgerCategories
    // 的 synthetic 分类树(与 picker 既有语义一致)。
    final ctx = await db.loadLedgerPickerContext(ledgerId);
    if (ctx != null && ctx.isEditorInShared && ctx.ledgerSyncId != null) {
      final tree = await db.getSharedCategoryPickerTree(ctx.ledgerSyncId!, kind);
      // 防线 B —— 即时自愈:镜像表为空(WS 漏推 / 邀请接受后拉取失败 /
      // 新设备首次绑定)时立刻 fire-and-forget 拉一次 SharedResources,
      // 写镜像表后 tableUpdates 会自动触发本 provider 重建,分类当场出现。
      // 冷却节流(per-ledgerSyncId + 5 分钟,失败同样冷却):防"空分类账本
      // 反复打网络",同时保证弱网失败后下次打开能重试 —— 这是相对"一次性 Set"
      // 的关键差异(后者失败后永不重试,本冷却到期后允许重试)。
      if (tree.topLevel.isEmpty) {
        unawaited(
            _pullSharedResourcesIfPossible(ref, ctx.ledgerSyncId!));
      }
      return tree;
    }
    return repo.getCategoryTree(kind);
  }

  // 首次立即发一次;此后三表任一变化(本地写 / 同步落库 / WS 应用)都
  // 重查重发。每次 load 只是一次带索引的本地 select,开销可忽略。
  Stream<CategoryPickerTree> watch() async* {
    yield await load();
    await for (final _ in db.tableUpdates(d.TableUpdateQuery.onAllTables(
        [db.categories, db.sharedLedgerCategories, db.ledgers]))) {
      yield await load();
    }
  }

  return watch();
});

/// 即时自愈:Editor 视角镜像表为空时,fire-and-forget 调 SyncEngine 拉一次
/// SharedResources,成功后写镜像表 → tableUpdates 自动触发
/// [categoryPickerTreeProvider] 重建,分类当场出现。
///
/// 严格单向依赖:本函数只通过 providers 层抽象(syncEngineProvider /
/// spitoutCloudProviderInstance)访问云同步能力,不直连 cloud/sync 内部实现。
///
/// 冷却节流逻辑:
/// - cloud 为 null(本地单机 / 云失活中) → 直接 return,本地无云无需拉;
/// - 同一 ledgerSyncId 在 [_selfHealCooldown] 窗口内 → 直接 return,
///   防止"空分类账本反复打网络"(成功后镜像表已非空,本兜底不会再进 isEmpty
///   分支,冷却 Map 中条目可保留至过期也无害;失败时冷却保证下个窗口可重试)。
Future<void> _pullSharedResourcesIfPossible(
  Ref ref,
  String ledgerSyncId,
) async {
  final cooldownMap = ref.read(selfHealCooldownProvider);
  final now = DateTime.now().toUtc();
  final nextAllowed = cooldownMap[ledgerSyncId];
  if (nextAllowed != null && now.isBefore(nextAllowed)) {
    return;
  }
  // 立即登记冷却窗口:无论本次成功 / 失败,窗口内不重复触发。
  // 失败同样冷却是相对"一次性 Set + 失败不重试"方案的关键差异 ——
  // 弱网失败一次就永久阻塞会让用户彻底看不到共享分类,只能在窗口到期后
  // 通过下一次"打开记账页"重试。
  cooldownMap[ledgerSyncId] = now.add(_selfHealCooldown);

  try {
    final cloud = await ref.read(spitoutCloudProviderInstance.future);
    if (cloud == null) return;
    await ref
        .read(syncEngineProvider(cloud))
        .fetchAndStoreSharedResources(ledgerSyncId);
  } catch (e, st) {
    logger.warning('CategoryPicker',
        '自愈拉取 SharedResources 失败 ledger=$ledgerSyncId: $e', st);
  }
}
