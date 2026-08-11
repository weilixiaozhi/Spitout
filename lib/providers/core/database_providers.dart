import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/cloud/sync/backend_capability_factory.dart';
import 'package:spitout/core/logging/logger_service.dart';
// 只依赖叶子 provider（云配置 + 刷新 tick），不 import sync_providers.dart
// 本体 —— 后者反向依赖本文件，直接互 import 会成环。
import 'package:spitout/providers/sync/sync_state_providers.dart';
import 'package:spitout/providers/core/simple_state_notifier.dart';
// 叶子模块：仅账本列表刷新 tick，供自愈兜底监听使用，不反向依赖本文件（不成环）。
import 'package:spitout/providers/core/refresh_ticks.dart';

// 数据库Provider
/// 统一业务数据变更信号：任何业务表发生写入（插入/更新/删除）都会发射一次。
///
/// 设计意图：所有汇总/统计 provider 只依赖这一个信号，即可保证「无论从哪条路径
/// 写库（UI 记账、导入、云端同步、后台任务、维护工具等）都会自动刷新」，
/// 每个调用方无需手动 bump 分散的 tick，从根上消除「漏刷一处」与多份
/// 刷新状态不一致的问题。
///
/// 只订阅业务表，排除同步簿记表（local_changes / sync_state / sync_pull_errors /
/// snapshot_dirty_ledgers）与编辑历史表，避免伴随业务写入产生的流水噪声触发
/// 无意义重算。
final dataChangeSignalProvider = StreamProvider<Set<TableUpdate>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.tableUpdates(
    TableUpdateQuery.onAllTables([
      db.ledgers,
      db.categories,
      db.transactions,
      db.recurringTransactions,
      db.ledgerMembers,
      db.sharedLedgerCategories,
      db.exchangeRates,
      db.exchangeRateOverrides,
      db.ledgerVirtualUsers,
    ]),
  );
});

final databaseProvider = Provider<SpitoutDatabase>((ref) {
  final db = SpitoutDatabase();
  ref.onDispose(() async {
    // 本地备份恢复流程会在 invalidate 前手动 close 过连接，此处二次 close
    // Drift 会抛 StateError，故幂等容错——dispose 语义不因恢复路径而炸。
    try {
      await db.close();
    } catch (_) {}
  });
  return db;
});

// 仓储Provider — 一律 LocalRepository(本地优先 + ChangeTracker 推 Spitout Cloud)。
// 采用「本地优先 + 推送」范式,不存在数据全存 Supabase 的 Cloud* 仓库。
final repositoryProvider = Provider<BaseRepository>((ref) {
  final db = ref.watch(databaseProvider);

  // P0-b 闸门：云失活流程进行中（invalidate 旧值窗口）即使 active 仍持旧
  // Spitout 配置，也必须以「无 tracker」装配仓库——绝不重建带 ChangeTracker
  // 的实例，防止失活窗口内的本地写登记到已失效的同步通道（与
  // spitoutCloudProviderInstance / syncServiceProvider 的闸门语义一致）。
  if (ref.watch(cloudDeactivationInProgressProvider)) {
    return LocalRepository(db);
  }

  final config = ref.watch(activeCloudConfigProvider).value;

  // 后端能力由 cloud 层工厂集中决策，装配点只把结果注入仓库：
  // Spitout Cloud 走实体级增量，快照型后端走账本级脏信号，两者互斥。
  final trackers = config != null && config.valid
      ? backendCapabilityFactory.createTrackers(db, config)
      : (changeTracker: null, snapshotDirtyTracker: null);

  logger.info('RepositoryProvider',
      '✅ LocalRepository (changeTracker=${trackers.changeTracker != null}, snapshotDirtyTracker=${trackers.snapshotDirtyTracker != null})');
  return LocalRepository(
    db,
    changeTracker: trackers.changeTracker,
    snapshotDirtyMarker: trackers.snapshotDirtyTracker,
  );
});

// 记住当前账本：启动时从持久化值恢复并校验有效性，失效则回退到本地第一个账本。
//
// 默认值 0 为「未选中」哨兵：SQLite 自增主键从 1 起，0 永远不可能是真实账本 id，
// 可彻底消除「账本 1 不存在时回落到 1 指向空账本、首页误判为空状态并误导
// 进入『新建账本』」的隐患。
final currentLedgerIdProvider =
    NotifierProvider<SimpleStateNotifier<int>, int>(
  () => SimpleStateNotifier((ref) => 0),
);

// 获取当前账本的详细信息。
// StreamProvider:sync pull / 本地编辑改了 ledger 行(如 monthStartDay)会自动
// 重建 watcher,B 端改设置 A 端自动刷新,无需手动 invalidate。
final currentLedgerProvider = StreamProvider<Ledger?>((ref) {
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);
  return repo.watchLedger(ledgerId);
});

/// 当前账本的每月起始日(1-28);未加载完成时按 1(自然月)兜底。
final currentMonthStartDayProvider = Provider<int>((ref) {
  final ledger = ref.watch(currentLedgerProvider).value;
  return (ledger?.monthStartDay ?? 1).clamp(1, 28);
});

/// 选中本地第一个账本并把 id 写回 prefs（仅当前选中无效时才生效，幂等）。
///
/// 为什么需要独立函数而不能只靠 currentLedgerPersistProvider：
/// 该 provider 的启动解析在 main() 启动预加载阶段只执行一次；新用户引导流程
/// （欢迎页 seed / 导入配置）在其之后才创建账本，解析执行时库还是空的，
/// currentLedgerId 会永远停留在哨兵 0——这正是「重装应用走引导后默认账本
/// 未被选中」回归的根因。因此账本创建完成后必须显式调用本函数选中账本，
/// 不能依赖启动时序。
///
/// [read] 传 `ref.read` 的 tear-off（Ref / WidgetRef / ProviderContainer 均可），
/// 用函数参数解耦具体 Ref 类型，pages 层与 providers 层共用一份实现（同
/// autoBackupOnLaunch(ref.read) 的既有模式）。
Future<void> selectFirstLedger(T Function<T>(ProviderListenable<T>) read) async {
  try {
    final repo = read(repositoryProvider);

    // 当前已选中且账本真实存在 → 尊重现状不覆盖（幂等保护，
    // 避免导入配置等场景把用户已生效的选择改掉）。
    final current = read(currentLedgerIdProvider);
    if (current != 0 && await repo.getLedgerById(current) != null) return;

    final ledgers = await repo.getAllLedgers();
    // 确实无账本：显式清掉可能的僵尸 ID（如换账号 GC 清空后内存态仍指向
    // 已删账本），重置哨兵 0，由真正的「无账本」空状态引导新建。持久化由
    // currentLedgerPersistProvider 的 listen 兜底写回，这里无需手写 prefs。
    if (ledgers.isEmpty) {
      if (read(currentLedgerIdProvider) != 0) {
        read(currentLedgerIdProvider.notifier).set(0);
      }
      return;
    }

    // getAllLedgers 按 id 升序，first 即最早创建的账本。
    final first = ledgers.first.id;
    if (read(currentLedgerIdProvider) != first) {
      read(currentLedgerIdProvider.notifier).set(first);
    }
    // 直接写回 prefs 而不依赖 currentLedgerPersistProvider 的 listen 回调：
    // 引导阶段该 provider 可能尚未被激活，显式写回才能保证下次启动稳定恢复。
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_ledger_id', first);
  } catch (_) {
    // 选中失败不阻断引导/启动流程：最坏进入首页后可在账本页手动选择。
  }
}

// 记住当前账本：启动时恢复并校验，切换时持久化。
//
// 设计要点：「校验存在性 + 回退到本地第一个账本」。仅在有存储值且 saved 仍
// 存在时恢复，避免覆盖更新清空 prefs（saved==null）或原账本被删后回落到
// 硬编码默认 1 指向不存在的账本、引发首页空状态误判甚至误导进入『新建账本』：
//   - saved 指向的账本仍存在 → 沿用用户上次选择；
//   - 不存在 / 无存储值 → 回退本地第一个账本（复用 selectFirstLedger，内含写回 prefs）；
//   - 本地确实无任何账本 → 保持哨兵 0，由 currentLedgerProvider 返回 null
//     触发真正的「无账本」空状态，而非误判。
//
// 实现为 FutureProvider：调用方（测试 / 启动编排）可
// `await container.read(provider.future)` 等待解析完成，消除 fire-and-forget
// 的时序断言盲区。
//
// ⚠️ 时序边界：本 provider 只在首次被读取时执行一次，不感知「账本从无到有」。
// 新用户引导（seed / 导入配置）在其之后才建账本，须由引导完成处显式调用
// selectFirstLedger 兜底选中（见 welcome_page.dart）。
final currentLedgerPersistProvider = FutureProvider<void>((ref) async {
  // 先注册持久化 / 自愈监听（同步执行，不依赖本次解析完成），保证任意路径的
  // 账本切换 / 失效都能被捕获。
  ref.listen<int>(currentLedgerIdProvider, (prev, next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_ledger_id', next);
    } catch (_) {}
  });

  // 运行时自愈：任意路径（切本地全量 purge / 换账号 per-ledger GC / 手动删
  // 当前账本）导致 currentLedgerProvider 解析为 null 时，
  // 若本地仍有账本则自动回退第一个；若确无账本则重置哨兵 0。不关心「谁、从
  // 哪条路径」清的账本，只监听「当前账本失效」这一个事实（防御性设计，天然
  // 覆盖所有未来新增的清账本路径）。
  ref.listen<AsyncValue<Ledger?>>(currentLedgerProvider, (prev, next) {
    // 仅在流已解析（含解析为 null）后介入，跳过 StreamProvider 重建时的
    // AsyncLoading 过渡态，避免无谓的账本表查询。
    if (!next.hasValue) return;
    if (next.value != null) return; // 有账本：尊重用户当前选择，不干预。
    // 捕获触发时刻的 id：启动瞬间 id=0 的 watchLedger(0) 也会真实发射 null，
    // 与启动解析的 prefs 恢复并发竞跑。异步查询后必须重校验 id 未被他处改走
    // （启动解析恢复 / selectFirstLedger / 用户手动切换），否则会把用户保存的
    // 非首个账本抢先覆盖成第一个。
    final triggerId = ref.read(currentLedgerIdProvider);
    Future(() async {
      try {
        final repo = ref.read(repositoryProvider);
        final ledgers = await repo.getAllLedgers();
        // 重校验：id 已被其它路径更新 → 放弃本次自愈（那条路径的 watchLedger
        // 若仍解析为 null，会再次触发本监听，收敛性不受影响）。
        if (ref.read(currentLedgerIdProvider) != triggerId) return;
        if (ledgers.isEmpty) {
          // 真·无账本：清掉可能的僵尸 ID，保持哨兵 0（与 selectFirstLedger
          // 空表分支对齐）。
          if (triggerId != 0) {
            ref.read(currentLedgerIdProvider.notifier).set(0);
          }
          return;
        }
        final first = ledgers.first.id;
        if (triggerId == first) return; // 幂等保护。
        // 启动窗口期（id 仍为哨兵 0）不抢跑：把 prefs 恢复权留给启动解析——
        // 它校验 saved 有效即沿用、无效则走 selectFirstLedger，两者都能收敛；
        // 此处若抢先选 first 会覆盖用户保存的非首个账本。
        if (triggerId == 0) return;
        // 仅更新内存态：上方持久化 ref.listen 会在 id 变化时自动写回 prefs，
        // 无需在此重复写（单一数据源）。
        ref.read(currentLedgerIdProvider.notifier).set(first);
      } catch (e, stackTrace) {
        // 自愈失败不阻断主流程：最坏进空状态，用户可在管理页手动选。
        logger.error('CurrentLedgerSelfHeal', '自愈回退账本失败: $e', e, stackTrace);
      }
    });
  });

  // 兜底：账本列表刷新后若仍停在哨兵 0 但已有账本（如换账号后新账本陆续同步
  // 到位的窗口期，主监听因 watchLedger(0) 不重发而不会触发），同样回退到
  // 首个可用账本，避免空状态卡死。
  ref.listen<int>(ledgerListRefreshProvider, (prev, next) {
    if (ref.read(currentLedgerIdProvider) != 0) return; // 已选中则不动。
    Future(() async {
      try {
        final repo = ref.read(repositoryProvider);
        final ledgers = await repo.getAllLedgers();
        if (ledgers.isEmpty) return;
        // 异步查询期间 id 可能已被其它路径选中，重校验后再介入（幂等）。
        if (ref.read(currentLedgerIdProvider) != 0) return;
        ref.read(currentLedgerIdProvider.notifier).set(ledgers.first.id);
      } catch (e, stackTrace) {
        logger.error('CurrentLedgerSelfHeal', '刷新兜底选账本失败: $e', e, stackTrace);
      }
    });
  });

  // 启动解析：恢复持久化账本，失效 / 缺失则回退本地第一个账本。
  try {
    final prefs = await SharedPreferences.getInstance();
    final repo = ref.read(repositoryProvider);
    final saved = prefs.getInt('current_ledger_id');

    if (saved != null && await repo.getLedgerById(saved) != null) {
      // 持久化的账本仍然有效：沿用用户上次选择。
      final st = ref.read(currentLedgerIdProvider);
      if (st != saved) {
        ref.read(currentLedgerIdProvider.notifier).set(saved);
      }
    } else {
      // 账本已不存在（被删 / 首次安装未选 / 覆盖更新清空 prefs）：
      // 回退到本地第一个账本并写回 prefs，避免首页空状态误判。
      await selectFirstLedger(ref.read);
    }
  } catch (_) {
    // 读取或校验失败时保持现状，不阻断首页渲染（最坏只是空状态，可手动重选）。
  }
});

// 当账本切换时，顺便触发一次设置页状态刷新（确保"我的"页及时反映）
final ledgerChangeListenerProvider = Provider<void>((ref) {
  // 激活持久化监听
  ref.read(currentLedgerPersistProvider);
  ref.listen<int>(currentLedgerIdProvider, (prev, next) {
    ref.read(syncStatusRefreshProvider.notifier).tick();
  });
});

// 确保监听器被激活
final appInitProvider = FutureProvider<void>((ref) async {
  // 读取以激活监听
  ref.read(ledgerChangeListenerProvider);
});

// 分类Provider
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  // 任何分类/交易等业务表写入都会经统一数据变更信号触发重算。
  ref.watch(dataChangeSignalProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getAllCategories();
});

// 分类与交易笔数组合Provider（响应式版本）
// 使用 autoDispose 在页面关闭时自动取消订阅
final categoriesWithCountProvider = StreamProvider.autoDispose<List<({Category category, int transactionCount})>>((ref) {
  final repo = ref.watch(repositoryProvider);
  // Owner 资源不 mirror 主表,管理页直接读主 Categories
  // 自然只看到用户自己 user-global 行,无需过滤。
  return repo.watchCategoriesWithCount();
});

// 所有重复交易Provider（不限账本）
final allRecurringTransactionsProvider = StreamProvider.autoDispose<List<RecurringTransaction>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllRecurringTransactions();
});

/// 按 id 缓存的分类查询。
///
/// 周期账单列表/编辑页共用:FutureProvider.family 保证同一分类只查一次,
/// 避免列表卡片每次 build 都重新发起数据库查询。
final categoryByIdProvider =
    FutureProvider.autoDispose.family<Category?, int>((ref, categoryId) {
      final repo = ref.watch(repositoryProvider);
      return repo.getCategoryById(categoryId);
    });

/// 按 id 缓存的账本查询。
///
/// 与 [categoryByIdProvider] 同理,供周期账单卡片展示账本名复用。
final ledgerByIdProvider =
    FutureProvider.autoDispose.family<Ledger?, int>((ref, ledgerId) {
      final repo = ref.watch(repositoryProvider);
      return repo.getLedgerById(ledgerId);
    });
