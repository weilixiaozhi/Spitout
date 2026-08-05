/// 账本归属（本地 ↔ Spitout Cloud）操作的 Riverpod 门面。
///
/// 设计意图:UI 只表达「用户想把这本账搬到哪」,不碰 SyncEngine / 数据库。
/// 三个入口分别对应账本管理页的三个菜单项:
///   - [moveLedgerToCloudProvider]：本地账本 → 云端（秒级翻 mode、后台推送）
///   - [moveLedgerToLocalProvider]：云端账本 → 本地（abort 信号双中止、删云端、断联）
///   - [copyLedgerToLocalProvider]：云端账本 ↘ 本地副本（云端保留，常用于共享账本留档）
///
/// 归属正确性由底层 SyncEngine 保证(主防线为 moveToLocal 的 abort 信号双中止 +
/// waitFullPushSettle + 404/410 放行 + detach 原子断联);删远端等前置步骤失败仍会抛
/// [CloudSyncException],由调用方(页面)转成用户可读提示。
/// 成功后统一刷新账本列表 / 当前账本 / 交易缓存,避免 UI 显示 stale 归属。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/cloud/spitout_cloud.dart';

import '../core/local_self_id_providers.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/core/refresh_ticks.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/sync/ledger_list_providers.dart';
import 'package:spitout/services/data/local_identity_migration_service.dart';
import 'package:spitout/services/data/tx_author_service.dart';

/// 拿到已登录的云端 provider,未登录直接抛出可读异常。
///
/// 三种归属操作都必须与服务端交互(推送 / 删除 / 确认),离线或未登录时
/// 不能只改本地 storage_mode —— 那会立刻制造"本地标记与云端实际不一致"的孤岛。
Future<SpitoutCloudSyncBackend> _requireCloud(WidgetRef ref) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  if (cloud == null) {
    throw CloudSyncException('请先登录 Spitout Cloud 再移动账本');
  }
  return cloud;
}

/// 归属变更后的统一收尾:列表、当前账本、交易缓存全部刷新。
void _refreshAfterMove(WidgetRef ref) {
  ref.invalidate(localLedgersProvider);
  ref.read(ledgerListRefreshProvider.notifier).tick();
  ref.invalidate(currentLedgerProvider);
  ref.read(cachedTransactionsProvider.notifier).set(null);
}

/// 把本地账本移动到 Spitout Cloud。
///
/// 秒级翻 storage_mode='cloud' 后台推送:翻 mode 后 UI 立即显示云端态,数据推送
/// 由 auto sync 异步完成;翻 mode 失败时账本保持本地不变。
///
/// 转云端前先把该账本的 localSelfId 作者字段改写为云 userId,避免云端
/// 出现「幽灵成员」(云端成员表里没有 localSelfId,展示层无法解析)。
Future<void> moveLedgerToCloudProvider(
  WidgetRef ref, {
  required int ledgerId,
}) async {
  final cloud = await _requireCloud(ref);
  // 转云端前迁移该账本的 localSelfId → cloudUserId,保证云端数据身份一致。
  await _migrateLedgerIdentityBeforeCloudMove(ref, ledgerId, cloud);
  await ref.read(syncEngineProvider(cloud)).moveToCloud(ledgerId);
  _refreshAfterMove(ref);
}

/// 登录 Spitout Cloud 后执行全库本地身份迁移(方案 B)。
///
/// 把库中所有 localSelfId 引用改写为云 userId,使本地账本的「我」与云身份统一。
/// 幂等(标记位防重跑),失败仅记日志不阻塞 UI。
/// 用 [ProviderContainer] 而非 WidgetRef:页面销毁后迁移仍可完成。
Future<void> migrateLocalIdentityAfterLoginWithContainer(
  ProviderContainer container,
) async {
  try {
    final cloud = await container.read(spitoutCloudProviderInstance.future);
    if (cloud == null) return;
    final cloudUserId = await TxAuthorService.currentUserId(cloud.auth);
    if (cloudUserId == null || cloudUserId.isEmpty) return;
    final localSelfId = await container.read(localSelfIdProvider.future);
    final db = container.read(databaseProvider);
    await LocalIdentityMigrationService.migrateToCloudUserId(
      db: db,
      cloudUserId: cloudUserId,
      localSelfId: localSelfId,
    );
  } catch (e, st) {
    logger.warning(
      'LedgerStorage',
      '登录后本地身份迁移失败(非阻塞,下次登录会重试)',
      '$e\n$st',
    );
  }
}

/// 转云端前把指定账本内的 localSelfId 引用改写为云 userId。
///
/// 仅改写该账本下的交易/编辑历史,以及该账本行的 ownerUserId。
/// 幂等:无 localSelfId 引用时 UPDATE 0 行,不报错。
Future<void> _migrateLedgerIdentityBeforeCloudMove(
  WidgetRef ref,
  int ledgerId,
  SpitoutCloudSyncBackend cloud,
) async {
  try {
    final cloudUserId = await TxAuthorService.currentUserId(cloud.auth);
    if (cloudUserId == null || cloudUserId.isEmpty) return;
    final localSelfId = await ref.read(localSelfIdProvider.future);
    if (localSelfId.isEmpty || localSelfId == cloudUserId) return;
    await LocalIdentityMigrationService.migrateLedgerToCloudUserId(
      db: ref.read(databaseProvider),
      ledgerId: ledgerId,
      cloudUserId: cloudUserId,
      localSelfId: localSelfId,
    );
  } catch (e, st) {
    // 迁移失败不阻断转云端流程,云端仍可靠成员表兜底解析。
    logger.warning('LedgerStorage',
        '转云端前身份迁移失败(非阻断)', '$e\n$st');
  }
}

/// 把云端账本移回本地。
///
/// 信号驱动:登记 abort 中止在途推送 → 等 fullPush 收敛 → 删云端副本(404/410
/// 放行)→ 原子断联。删失败会抛异常且账本保持云端,不会出现「本地已断联、云端
/// 还留着一份」的双份数据。
Future<void> moveLedgerToLocalProvider(
  WidgetRef ref, {
  required int ledgerId,
}) async {
  final cloud = await _requireCloud(ref);
  await ref.read(syncEngineProvider(cloud)).moveToLocal(ledgerId);
  _refreshAfterMove(ref);
}

/// 把云端账本复制一份到本地（云端原件保留）。
///
/// 返回新建的本地账本 id。共享账本无法移动归属（那是别人的云端资源），
/// 想在本地留档只能走这条路径。
Future<int> copyLedgerToLocalProvider(
  WidgetRef ref, {
  required int ledgerId,
}) async {
  final cloud = await _requireCloud(ref);
  final newId = await ref.read(syncEngineProvider(cloud)).copyToLocal(ledgerId);
  _refreshAfterMove(ref);
  return newId;
}
