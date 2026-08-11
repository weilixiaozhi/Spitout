/// Shared-ledger Riverpod 层。
///
/// 把 SpitoutCloudProvider 的 invites / members API 封装成可缓存的
/// FutureProvider,UI 直接 ref.watch。失效刷新走 family.refresh 或 invalidate。
///
/// 设计:
/// - 所有 provider autoDispose,避免后台残留 — 共享账本是低频功能,
///   UI 关掉就该释放。
/// - cloud provider 缺失 / 用户未登录时,所有 provider 返回 null 或空集合,
///   UI 自己降级提示。
/// - 只 import 叶子模块（cloud_client / refresh_ticks / ledger_list /
///   database），不 import 编排器 sync_providers.dart。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:spitout/cloud/spitout_cloud.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/sync/ledger_list_providers.dart';
import 'package:spitout/providers/core/refresh_ticks.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/services/data/tx_author_service.dart';

// sharedResourceRefreshProvider 由叶子模块 refresh_ticks.dart 定义，
// 此处 re-export 供消费方（picker / 反查 widget）统一引用。
export 'package:spitout/providers/core/refresh_ticks.dart';
// 共享账本成员 / 邀请 DTO 经 providers 层 barrel 转发给 UI，
// data 层不反向依赖 cloud 层（分层规则：data 不得 import cloud）。
export 'package:spitout/cloud/spitout_cloud.dart'
    show SpitoutCloudLedgerMember, SpitoutCloudInvite;

/// 列出某账本的成员(任何 member 可读)。
/// watch sharedResourceRefreshProvider 让 WS 重连后(server 不持久化离线
/// member_change 事件)自动重拉,避免被踢 / 新成员加入但本地列表 stale。
final ledgerMembersProvider = FutureProvider.autoDispose
    .family<List<SpitoutCloudLedgerMember>, String>((ref, ledgerId) async {
  ref.watch(sharedResourceRefreshProvider);
  final cloud = await ref.watch(spitoutCloudProviderInstance.future);
  if (cloud == null) return const [];
  return cloud.listMembers(ledgerId: ledgerId);
});

/// 列出某账本"当前 active"邀请(仅 owner)。
final ledgerInvitesProvider = FutureProvider.autoDispose
    .family<List<SpitoutCloudInvite>, String>((ref, ledgerId) async {
  final cloud = await ref.watch(spitoutCloudProviderInstance.future);
  if (cloud == null) return const [];
  try {
    return await cloud.listInvites(ledgerId: ledgerId);
  } catch (_) {
    // 非 owner 拉这个会 404 — 降级返空,UI 不显示邀请列表区
    return const [];
  }
});

/// 发邀请前的分类上云失败（重试一次后仍失败）。
///
/// 调用方(member_list_page.dart)凭类型区分此错误并展示本地化友好提示,
/// 其余错误仍按原始文本展示便于定位。底层原因已记 error 日志,这里仅
/// 透传 [cause] 供调试。
class CategorySyncBeforeInviteException implements Exception {
  const CategorySyncBeforeInviteException(this.cause);

  /// 重试仍失败时的底层原始错误
  final Object cause;

  @override
  String toString() => 'CategorySyncBeforeInviteException: $cause';
}

/// 一次性触发函数:创建邀请 → 自动失效列表 cache。
///
/// 发邀请前先经 [syncEngineProvider] 把本地 user-global
/// 实体(分类等)推上云,避免「云端空快照」流到 Editor 端导致协作者看不到
/// Owner 的分类。pushUserGlobalEntities 是 public、全局单飞(详见
/// sync_engine.dart L1549),失败时重试一次——单飞锁在 finally 已复位,重试
/// 安全;重试仍失败则抛 [CategorySyncBeforeInviteException] 阻断邀请,
/// 调用方(member_list_page.dart)catch 兜底显示友好错误,不让残缺邀请发出。
///
/// 主动推送说明（请勿误删）：这里的直接推送是「发邀请」业务前置——必须
/// 在邀请生效前让云端分类就绪，且邀请是用户显式动作、需要同步等待结果来
/// 决定是否放行，无法改由数据变更驱动的 250ms 后台同步兜底。它与
/// PostProcessor 的写后自动同步是两条职责不同的路径：后者负责常规数据变更，
/// 这里负责邀请前的强一致前置校验，并非可删除的冗余。
Future<SpitoutCloudInvite> createInviteAndRefresh(
  WidgetRef ref, {
  required String ledgerId,
  required String role,
  required int expiresInHours,
}) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  if (cloud == null) {
    throw StateError('Spitout Cloud not configured');
  }
  // 先确保 user-global 实体(分类等)已上云,再发邀请。失败重试一次后仍失败
  // 则 throw 阻断邀请:宁可让 Owner 看到错误重试,也不让协作者收到空快照。
  final engine = ref.read(syncEngineProvider(cloud));
  try {
    await engine.pushUserGlobalEntities();
  } catch (e, st) {
    logger.warning('SharedLedger',
        'createInvite 前 pushUserGlobalEntities 首次失败,重试一次', '$e\n$st');
    try {
      await engine.pushUserGlobalEntities();
    } catch (e2, st2) {
      logger.error('SharedLedger',
          'createInvite 前 pushUserGlobalEntities 重试仍失败,阻断邀请', e2, st2);
      throw CategorySyncBeforeInviteException(e2);
    }
  }
  final invite = await cloud.createInvite(
    ledgerId: ledgerId,
    role: role,
    expiresInHours: expiresInHours,
  );
  ref.invalidate(ledgerInvitesProvider(ledgerId));
  return invite;
}

/// 一次性触发函数:撤销邀请 → 失效列表。
Future<void> revokeInviteAndRefresh(
  WidgetRef ref, {
  required String ledgerId,
  required String inviteId,
}) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  if (cloud == null) return;
  await cloud.revokeInvite(ledgerId: ledgerId, inviteId: inviteId);
  ref.invalidate(ledgerInvitesProvider(ledgerId));
}

/// 接受邀请 — 不绑特定 ledger family(此时还不知道是哪个 ledger)。
Future<SpitoutCloudInviteAcceptResult> acceptInvite(
  WidgetRef ref, {
  required String code,
}) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  if (cloud == null) {
    throw StateError('Spitout Cloud not configured');
  }
  final result = await cloud.acceptInvite(code: code);
  // 接受后整个账本列表(本地 ledger / remote ledgers)都可能变,失效兜底
  // 由 sync engine 的 pull 路径 + cloud 同步刷新。
  return result;
}

/// 接受邀请 + 触发引擎完整初始化 + 强力刷新(一次性触发函数)。
///
/// 三步合一:acceptInvite → engine.onInviteAccepted → 三次 tick bump,
/// 页面只调这一个,避免 UI 层直接触碰 SyncEngine 内部实现(依赖方向
/// pages → providers → cloud)。
///
/// onInviteAccepted 失败不阻塞"加入成功"体验:后续 WS member_change.joined
/// 广播 / 下次启动自动 sync 都会兜底补数据,这里只记 warning 日志。
Future<SpitoutCloudInviteAcceptResult> acceptSharedLedgerInvite(
  WidgetRef ref, {
  required String code,
  required String ledgerExternalId,
}) async {
  final result = await acceptInvite(ref, code: code);
  try {
    final cloud = await ref.read(spitoutCloudProviderInstance.future);
    if (cloud != null) {
      final engine = ref.read(syncEngineProvider(cloud));
      await engine.onInviteAccepted(ledgerExternalId);
    }
    // 强力 invalidate 所有 ledger 相关 provider,确保下一帧 UI 立即重渲染
    // (单纯 state++ 在 cached FutureProvider 上偶发不触发 reCompute,
    // invalidate 是无条件 dispose + 下次 watch 重新 build)
    ref.invalidate(localLedgersProvider);
    ref.read(ledgerListRefreshProvider.notifier).tick();
    // 汇总/统计刷新由统一数据变更信号自动驱动（邀请落库即触发）。
  } catch (e, st) {
    // 静默,UI 自己刷不到下次 sync 再补;但 log 出来便于诊断
    logger.warning('JoinSharedLedger',
        'accept 后 sync/刷新失败 — 下次启动会兜底', '$e\n$st');
  }
  return result;
}

/// preview(不写)
Future<SpitoutCloudInvitePreview> previewInvite(
  WidgetRef ref, {
  required String code,
}) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  if (cloud == null) {
    throw StateError('Spitout Cloud not configured');
  }
  return cloud.previewInvite(code: code);
}

/// 删成员(踢人 / 退出)。caller 给 ledgerId 用于 cache 失效。
Future<void> removeMemberAndRefresh(
  WidgetRef ref, {
  required String ledgerId,
  required String userId,
}) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  if (cloud == null) return;
  await cloud.removeMember(ledgerId: ledgerId, userId: userId);
  ref.invalidate(ledgerMembersProvider(ledgerId));

  // 共享账本:Owner 踢成员后,本地 Ledgers 表的 memberCount / isShared
  // 需要更新(server 端 LedgerMember 行已删,/read/ledgers 会返新数据,但
  // 本地数据 stale → 首页 header / 账本列表 🤝 显示还是 2 人)。手动调
  // syncLedgersFromServer 让本地 ledger 字段对齐,然后 bump 所有相关 tick。
  try {
    final engine = ref.read(syncEngineProvider(cloud));
    await engine.syncLedgersFromServer();
  } catch (_) {}
  ref.invalidate(localLedgersProvider);
  ref.read(ledgerListRefreshProvider.notifier).tick();
  // currentLedgerProvider 也得 invalidate — 首页 header 看的是它
  ref.invalidate(currentLedgerProvider);
}

/// 协作者"退出并删除"共享账本(本地清数据 + 云端退出)。
///
/// cloud-first 对称设计:先走 [SpitoutCloudProvider.leaveLedger](DELETE
/// /members/self)退出,server 移除成员后不返回该账本;再 purge 本地
/// (清 local_changes → 镜像表 → 交易 → 账本行)。两条路径汇到
/// [LocalRepository.purgeSharedLedger] 同一入口,幂等早退,保证协作者删除账本
/// = 退出账本 + 清空数据,下次 sync 不会被云端重新 upsert 回来。
Future<void> leaveAndDeleteSharedLedgerProvider(
  WidgetRef ref, {
  required String ledgerId,
}) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  if (cloud == null) return;
  // 1) 云端退出(DELETE /members/self):server 移除成员,不返回该账本
  await cloud.leaveLedger(ledgerId: ledgerId);
  // 2) 清本地残留数据(不写 local_changes,云端状态已变更)
  final engine = ref.read(syncEngineProvider(cloud));
  await engine.repo.purgeSharedLedger(ledgerId);
  // 3) 刷新:成员列表 / 账本列表 / 当前账本都失效,首页 header 同步
  ref.invalidate(ledgerMembersProvider(ledgerId));
  try {
    await engine.syncLedgersFromServer();
  } catch (_) {}
  ref.invalidate(localLedgersProvider);
  ref.read(ledgerListRefreshProvider.notifier).tick();
  ref.invalidate(currentLedgerProvider);
}

/// Owner"全局删除"共享账本(云端删除 + 本地清数据)。
///
/// cloud-first 对称设计:DELETE /write/ledgers/{id} 由 server 事务内级联踢出
/// 所有成员并广播 member_change.removed,各客户端收到后清本地;本端直接 purge
/// 本地即可,无需客户端循环踢人。保证 Owner 删除账本 = 全局所有协作者和 owner
/// 都删除账本、踢出成员、清空所有协作者账本。
Future<void> deleteSharedLedgerAsOwnerProvider(
  WidgetRef ref, {
  required String ledgerId,
}) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  if (cloud == null) return;
  // 1) 云端删除(级联踢出所有成员 + 广播)
  await cloud.deleteLedger(ledgerId: ledgerId);
  // 2) 清本地残留数据(不写 local_changes,云端级联已处理)
  final engine = ref.read(syncEngineProvider(cloud));
  await engine.repo.purgeSharedLedger(ledgerId);
  // 3) 刷新:成员列表 / 账本列表 / 当前账本都失效
  ref.invalidate(ledgerMembersProvider(ledgerId));
  try {
    await engine.syncLedgersFromServer();
  } catch (_) {}
  ref.invalidate(localLedgersProvider);
  ref.read(ledgerListRefreshProvider.notifier).tick();
  ref.invalidate(currentLedgerProvider);
}

/// Surface 2:云端主动失活(退出登录 / 切回本地模式 / 清除当前 active 配置)时,
/// 全量清本地云端账本(storage_mode='cloud' 或 isShared=true)并收尾刷新 UI。
///
/// ⚠️ 调用位置约束:仅限 signOut 之后、新配置激活之前调用——「云已失活」这一
/// 前提由调用点位置保证:
/// - _activateService:仅在目标 type != spitoutCloud 时调(local/webdav/s3/
///   supabase 均属本地快照备份范畴,切走即清云端账本);
/// - _clearConfig:仅在被清的正是当前 active 云配置时调;
/// - cloud_sync_section 退出登录:signOut 成功后无条件调。
///
/// 页面销毁后仍需清理时,在页面存活期捕获 ref.container 交由
/// [purgeLocalCloudLedgersWithContainer] 执行——container 随 app 生命周期
/// 存活,清理不依赖页面 mounted。
///
/// 底层走 repo.purgeAllCloudLedgers()(WHERE storage_mode='cloud' OR
/// isShared=true 批量闸门):云端账本的数据在服务端,退出后重登会重新拉回,
/// 留在本地只会产生"看得见却同步不了"的僵尸账本;而纯本地账本(local)是这台
/// 设备自己的数据,一行都不会动。失败仅记日志不抛出,避免打断登出/切换主流程。

/// 私有清理实现:把 read/invalidate 两个能力抽象成参数,供 WidgetRef 版与
/// ProviderContainer 版共用,避免两处重复同一套清理逻辑(也避免 FutureProvider
/// 结果缓存导致二次切换 purge 不重跑的陷阱)。
///
/// 返回 bool(成功 true / 失败 false):失败不静默吞掉,调用方(退出登录 /
/// 切回本地 / 清配置)可据此提示「云端账本清理失败」,让用户知道残留的
/// 云账本需要手动处理,而不是误以为清理成功。
Future<bool> _purge(
  T Function<T>(ProviderListenable<T>) read,
  void Function(ProviderOrFamily) invalidate,
) async {
  try {
    final repo = read(repositoryProvider);
    await repo.purgeAllCloudLedgers();
    // 当前账本可能刚被清掉:重指第一个可用账本,再刷新列表 / 当前账本 / 缓存
    await selectFirstLedger(read);
    invalidate(localLedgersProvider);
    read(ledgerListRefreshProvider.notifier).tick();
    invalidate(currentLedgerProvider);
    read(cachedTransactionsProvider.notifier).set(null);
    return true;
  } catch (e, st) {
    logger.error('SharedLedger', 'purgeLocalCloudLedgers 失败: $e', e, st);
    return false;
  }
}

/// WidgetRef 版:供页面内直接持有的 ref 调用(如仍在存活态的点击回调)。
Future<bool> purgeLocalCloudLedgersProvider(WidgetRef ref) =>
    _purge(ref.read, ref.invalidate);

/// ProviderContainer 版:供页面已销毁的延迟清理使用。
/// 调用方须在页面仍存活时捕获 ref.container,再于 postFrame / 异步回调中传入,
/// 从而保证 purge 必然执行。
Future<bool> purgeLocalCloudLedgersWithContainer(ProviderContainer container) =>
    _purge(container.read, container.invalidate);

/// 本地新建 tx 后回填「创建人 + 编辑人」（动作函数）。
///
/// 设计意图：云身份解析 + localSelfId 读取在 providers 层完成，widget 侧
/// 只传 txId，不直接 import tx_author_service.dart（保持
/// `pages/widgets → providers → services` 单向）。失败静默，本函数不抛错。
///
/// 身份解析按账本归属选择：本地账本写 localSelfId，云端账本写缓存的云 userId；
/// 云身份缓存未就绪时留空，由同步推送后服务端注入，绝不降级写 localSelfId。
/// paidByUserId 回填规则:为空时取操作者,编辑器已显式写入的值(指定分摊)不覆盖。
Future<void> markTxCreatedFromUi(WidgetRef ref, int txId) async {
  final repo = ref.read(repositoryProvider);
  final userId = await _authorUserIdForTx(ref, txId);
  if (userId == null || userId.isEmpty) return;
  try {
    await repo.markTxAuthor(
      txId: txId,
      userId: userId,
      isCreate: true,
    );
  } catch (e, st) {
    logger.warning('SharedLedger', 'markTxCreated 失败(不阻塞主流程): $e', st);
  }
}

/// 本地编辑 tx 后回填「编辑人」（动作函数）。
///
/// 语义同 [markTxCreatedFromUi]：写 lastEditedByUserId（创建人
/// first-write-wins 不变);paidByUserId 为空时回填操作者,非空视为
/// 用户手改值保留。身份解析同 [markTxCreatedFromUi]。
Future<void> markTxEditedFromUi(WidgetRef ref, int txId) async {
  final repo = ref.read(repositoryProvider);
  final userId = await _authorUserIdForTx(ref, txId);
  if (userId == null || userId.isEmpty) return;
  try {
    await repo.markTxAuthor(
      txId: txId,
      userId: userId,
      isCreate: false,
    );
  } catch (e, st) {
    logger.warning('SharedLedger', 'markTxEdited 失败(不阻塞主流程): $e', st);
  }
}

/// 按交易所属账本归属解析当前操作者 id（作者位统一入口）。
///
/// 本地账本一律 localSelfId；云端账本一律缓存的云 userId（可返回 null）。
Future<String?> _authorUserIdForTx(WidgetRef ref, int txId) async {
  final repo = ref.read(repositoryProvider);
  final tx = await repo.getTransactionById(txId);
  if (tx == null) return null;
  return authorUserIdForLedger(ref, tx.ledgerId);
}

/// 按账本归属解析当前操作者 id。
///
/// - 本地账本（storage_mode='local'）：一律 localSelfId，云端登录不影响；
/// - 云端账本（storage_mode='cloud' 或 isShared）：一律缓存的云 userId，
///   缓存未就绪返回 null，由同步服务端回填，绝不降级写 localSelfId。
Future<String?> authorUserIdForLedger(WidgetRef ref, int ledgerId) async {
  final repo = ref.read(repositoryProvider);
  bool isCloudLedger = false;
  try {
    final ledger = await repo.getLedgerById(ledgerId);
    isCloudLedger = ledger != null &&
        ((ledger.storageMode == 'cloud') || ledger.isShared);
  } catch (e, st) {
    // 读不到账本归属时不确定身份来源，宁可不写作者位（由同步服务端回填），
    // 也不降级写 localSelfId，同时保证保存动作不被阻塞。
    logger.warning('AuthorIdentity', '读取账本归属失败，作者位留空待同步回填', '$e\n$st');
    return null;
  }
  return currentAuthorIdByLedgerMode(ref, isCloudLedger: isCloudLedger);
}

/// 按账本归属模式解析当前操作者 id（新建账本等尚无 ledgerId 的场景）。
Future<String?> currentAuthorIdByLedgerMode(
  WidgetRef ref, {
  required bool isCloudLedger,
}) async {
  if (!isCloudLedger) return ref.read(localSelfIdProvider.future);
  return currentOperatorUserIdFromUi(ref);
}

/// 读取已缓存的云身份（本地持久化 session 种子，离线可用、无网络、无超时）。
///
/// 云端账本存在即说明会话已恢复；缓存未就绪时返回 null，调用方留空作者位，
/// 由同步推送后服务端注入真实身份，绝不降级写 localSelfId。
Future<String?> currentOperatorUserIdFromUi(WidgetRef ref) async {
  try {
    final cloud = await ref.read(spitoutCloudProviderInstance.future);
    if (cloud == null) return null;
    return TxAuthorService.cachedCurrentUserId(cloud.auth);
  } catch (e, st) {
    logger.warning('AuthorIdentity', '读取云端身份失败，作者位留空待同步回填', '$e\n$st');
    return null;
  }
}
