/// AA 分摊 Provider 层。
///
/// 设计意图:
/// - 新增 AA 分摊统计查询、虚拟用户 CRUD 状态入口。
/// - 全部写操作走 [LocalRepository](保证 sync 登记统一,禁止绕过)。
/// - 读操作直接走子仓查询,UI 通过 ref.watch 自动响应数据变化。
///
/// Provider 职责:
/// - [aaEnabledProvider]:账本 AA 开关(读写)。
/// - [ledgerVirtualUsersProvider]:账本虚拟用户列表(Stream)。
/// - 虚拟用户 CRUD 动作函数(createVirtualUser/renameVirtualUser/deleteVirtualUser)。
/// - [aaSettlementProvider]:账本 AA 分摊汇总(纯计算,依赖交易+成员+虚拟用户)。
library;

import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/identity/local_user_identity.dart';
import '../../core/logging/logger_service.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/core/database_providers.dart';
import '../../providers/sync/cloud_client_providers.dart';
import '../../providers/sync/shared_ledger_providers.dart';
import '../../providers/sync/sync_state_providers.dart';
import '../../providers/ui/language_provider.dart';
import '../../providers/ui/theme_providers.dart';
import '../../services/data/tx_author_service.dart';
import '../../services/settlement/aa_edit_models.dart';
import '../../services/settlement/aa_settlement_service.dart';

/// 本地账本自我参与人的展示名:优先本地昵称(displayNameProvider),
/// 昵称为空时统一回退「未设置昵称(我)」,与「我的页」昵称占位文案保持一致。
String _localSelfName(Ref ref) {
  final nickname = ref.read(displayNameProvider).trim();
  if (nickname.isNotEmpty) return nickname;
  // 昵称为空:兜底展示「未设置昵称(我)」,不暴露原始 id。
  final locale = ref.read(languageProvider) ?? ui.PlatformDispatcher.instance.locale;
  final l10n = lookupAppLocalizations(locale);
  return '${l10n.mineSlogan}(${l10n.aaMe})';
}

/// 当前账本的 AA 分摊开关(Stream,自动响应 ledger.aaEnabled 变更)。
///
/// UI(账本设置页开关)watch 此 provider 即可实时反映开关状态;
/// 写入走 [setAaEnabled] 动作函数。
final aaEnabledProvider = StreamProvider<bool>((ref) {
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);
  return repo.watchLedger(ledgerId).map((l) => l?.aaEnabled ?? false);
});

/// 切换账本 AA 分摊开关(动作函数)。
///
/// 走 [LocalRepository.updateLedger] 保证 changeTracker 登记 sync
/// (aaEnabled 必须跨设备同步)。
Future<void> setAaEnabled(WidgetRef ref, int ledgerId, bool enabled) async {
  try {
    final repo = ref.read(repositoryProvider);
    await repo.updateLedger(id: ledgerId, aaEnabled: enabled);
    // 失效账本流,确保 UI 立即刷新。
    ref.invalidate(currentLedgerProvider);
  } catch (e, st) {
    logger.error('AaSettlement', 'setAaEnabled 失败 ledger=$ledgerId enabled=$enabled', e, st);
    rethrow;
  }
}

/// 账本虚拟用户列表(Stream,自动响应增删改)。
///
/// family by ledgerId,UI(分摊设置/编辑页)watch 此 provider 渲染参与人选项。
final ledgerVirtualUsersProvider =
    StreamProvider.autoDispose.family<List<LedgerVirtualUser>, int>(
        (ref, ledgerId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchByLedger(ledgerId);
});

/// 新建虚拟用户(动作函数)。
///
/// 走 [LocalRepository.create] 委托层,保证 changeTracker 登记 sync
/// (虚拟用户是 ledger-scoped 同步实体,change log 走 create)。
/// 失败时抛错由调用方(UI)展示友好提示。
Future<int> createVirtualUser(
  WidgetRef ref, {
  required int ledgerId,
  required String name,
}) async {
  try {
    final repo = ref.read(repositoryProvider);
    return await repo.create(ledgerId: ledgerId, name: name);
  } catch (e, st) {
    logger.error('AaSettlement', '新建虚拟用户失败 ledger=$ledgerId name=$name', e, st);
    rethrow;
  }
}

/// 重命名虚拟用户(动作函数)。
Future<void> renameVirtualUser(
  WidgetRef ref, {
  required int id,
  required String name,
}) async {
  try {
    final repo = ref.read(repositoryProvider);
    await repo.rename(id: id, name: name);
  } catch (e, st) {
    logger.error('AaSettlement', '重命名虚拟用户失败 id=$id name=$name', e, st);
    rethrow;
  }
}

/// 删除虚拟用户(动作函数,硬删)。
///
/// 名下有账(被交易 aaParticipants 引用)不可删,
/// 子仓抛 [StateError],调用方(UI)catch 后展示友好提示。
Future<void> deleteVirtualUser(WidgetRef ref, int id) async {
  try {
    final repo = ref.read(repositoryProvider);
    await repo.delete(id);
  } on StateError {
    // 名下有账不可删,向上透传让 UI 展示。
    rethrow;
  } catch (e, st) {
    logger.error('AaSettlement', '删除虚拟用户失败 id=$id', e, st);
    rethrow;
  }
}

/// 账本 AA 参与人选项列表(真实成员 + 虚拟用户)。
///
/// 供编辑器 AA 区块、AaEditPage、交易详情页统一取参与人名册,
/// 标识口径与 [aaSettlementProvider] 一致(真实成员 userId、
/// 虚拟用户 syncId,无 syncId 兜底 `vu_<本地id>`)。
/// watch [sharedResourceRefreshProvider] 让成员变更后自动重取。
///
/// 单人/本地账本(无 syncId)无成员表,此处会把 owner 自动纳入参与人
/// 名册(优先 ledger.ownerUserId,其次当前登录用户),避免参与人选择器
/// 在单人账本场景下出现空列表、用户无从下手。
final aaParticipantOptionsProvider =
    FutureProvider.autoDispose.family<List<AaParticipantOption>, int>(
        (ref, ledgerId) async {
  ref.watch(sharedResourceRefreshProvider);

  final repo = ref.read(repositoryProvider);
  final options = <AaParticipantOption>[];

  final ledger = await repo.getLedgerById(ledgerId);
  final syncId = ledger?.syncId;
  final isSharedLedger = syncId != null && syncId.isNotEmpty;

  if (isSharedLedger) {
    // 共享账本:从 ledgerMembersProvider 取真实成员(userId 为参与人标识)。
    try {
      final members = await ref.read(ledgerMembersProvider(syncId).future);
      for (final m in members) {
        // displayName 可能为 null/空,email 兜底(email 为非空字段)。
        final dn = m.displayName;
        options.add(AaParticipantOption(
          id: m.userId,
          name: (dn != null && dn.isNotEmpty) ? dn : m.email,
          isVirtual: false,
        ));
      }
    } catch (e, st) {
      logger.warning(
          'AaSettlement', '读取账本成员失败 ledger=$ledgerId,成员选项降级为空', '$e\n$st');
    }
  } else {
    // 单人/本地账本:无成员表,把 owner 自动纳入参与人名册,
    // 保证参与人选择器至少有一个可选项。
    // 优先取 ledger.ownerUserId;为空时回退当前登录用户 id;
    // 两者都拿不到时用 localSelfId(设备身份 UUID)兜底,确保 UI 不空态。
    var ownerId = ledger?.ownerUserId;
    if (ownerId == null || ownerId.isEmpty) {
      final cloud = await ref.read(spitoutCloudProviderInstance.future);
      ownerId = await TxAuthorService.currentUserId(cloud);
    }
    // 真实 userId 直接作为参与人标识;拿不到时用 localSelfId 兜底,保证名册非空。
    // 展示名统一走本地昵称/「未设置昵称(我)」,与交易详情页口径一致。
    final localSelfId = await ref.read(localSelfIdProvider.future);
    final finalId =
        (ownerId != null && ownerId.isNotEmpty) ? ownerId : localSelfId;
    final ownerName = _localSelfName(ref);
    options.add(AaParticipantOption(
      id: finalId,
      name: ownerName,
      isVirtual: false,
    ));
  }

  // 虚拟用户:syncId 作为参与人标识(与统计口径一致)。
  final virtualUsers = await repo.getByLedger(ledgerId);
  for (final vu in virtualUsers) {
    options.add(AaParticipantOption(
      id: vu.syncId ?? 'vu_${vu.id}',
      name: vu.name,
      isVirtual: true,
    ));
  }
  return options;
});

/// 账本成员支出统计项(按 paidByUserId 聚合)。
///
/// 设计意图:成员支出模块需要包含虚拟用户的支出,而云端 memberStats 仅含
/// 真实成员。改为本地按交易 paidByUserId 聚合(支出人 = paidByUserId),
/// 关联参与人名册(真实成员 + 虚拟用户)拿展示名,与 AA 分摊统计口径一致。
class MemberExpenseStatItem {
  const MemberExpenseStatItem({
    required this.participantId,
    required this.displayName,
    required this.expenseTotal,
    required this.txCount,
  });

  /// 参与人标识(userId 或虚拟用户 syncId)。
  final String participantId;

  /// 展示名(真实成员 displayName/email、虚拟用户 name)。
  final String displayName;

  /// 该成员作为支出人的支出金额合计。
  final double expenseTotal;

  /// 该成员作为支出人的支出笔数。
  final int txCount;
}

/// 账本成员支出统计(按 paidByUserId 聚合,含虚拟用户)。
///
/// 数据源:账本全部支出交易(type='expense'),按 paidByUserId 分组聚合
/// 金额与笔数;展示名取参与人名册(真实成员 + 虚拟用户),与 AA 分摊统计
/// 口径一致。paidByUserId 为空的交易不计入(支出人未知,无法归属)。
final memberExpenseStatsProvider = FutureProvider.autoDispose
    .family<List<MemberExpenseStatItem>, int>((ref, ledgerId) async {
  ref.watch(syncGenerationProvider);
  ref.watch(sharedResourceRefreshProvider);

  final repo = ref.read(repositoryProvider);
  final ledger = await repo.getLedgerById(ledgerId);
  if (ledger == null) return const [];

  // 账本全部支出交易(只统计支出,与首页/统计口径一致)。
  final allTx = await repo.getTransactionsByLedger(ledgerId);
  final expenseTx = allTx.where((t) => t.type == 'expense').toList();

  // 按 paidByUserId 聚合:金额合计 + 笔数。paidByUserId 为空跳过(无法归属)。
  final amountMap = <String, double>{};
  final countMap = <String, int>{};
  for (final t in expenseTx) {
    final pid = t.paidByUserId;
    if (pid == null || pid.isEmpty) continue;
    amountMap[pid] = (amountMap[pid] ?? 0) + t.amount;
    countMap[pid] = (countMap[pid] ?? 0) + 1;
  }

  // 参与人名册 → 展示名映射(真实成员 + 虚拟用户),与 aaParticipantOptionsProvider 口径一致。
  final displayNameMap = <String, String>{};
  // 虚拟用户:syncId 作为参与人标识。
  final virtualUsers = await repo.getByLedger(ledgerId);
  for (final vu in virtualUsers) {
    final pid = vu.syncId ?? 'vu_${vu.id}';
    displayNameMap[pid] = vu.name;
  }
  // 真实成员:共享账本从 ledgerMembersProvider 取;单人/本地账本纳入 owner。
  final syncId = ledger.syncId;
  if (syncId != null && syncId.isNotEmpty) {
    try {
      final members = await ref.read(ledgerMembersProvider(syncId).future);
      for (final m in members) {
        final dn = m.displayName;
        displayNameMap[m.userId] =
            (dn != null && dn.isNotEmpty) ? dn : m.email;
      }
    } catch (e, st) {
      logger.warning('AaSettlement',
          '读取账本成员失败 ledger=$ledgerId,成员支出降级为仅虚拟用户', '$e\n$st');
    }
  } else {
    var ownerId = ledger.ownerUserId;
    if (ownerId == null || ownerId.isEmpty) {
      final cloud = await ref.read(spitoutCloudProviderInstance.future);
      ownerId = await TxAuthorService.currentUserId(cloud);
    }
    if (ownerId != null && ownerId.isNotEmpty) {
      displayNameMap[ownerId] = _localSelfName(ref);
    } else {
      final localSelfId = await ref.read(localSelfIdProvider.future);
      displayNameMap[localSelfId] = _localSelfName(ref);
    }
  }

  // 组装结果:仅保留有支出的参与人(amountMap 的 key),按金额降序。
  final items = <MemberExpenseStatItem>[];
  amountMap.forEach((pid, total) {
    items.add(MemberExpenseStatItem(
      participantId: pid,
      displayName: displayNameMap[pid] ?? pid,
      expenseTotal: total,
      txCount: countMap[pid] ?? 0,
    ));
  });
  items.sort((a, b) => b.expenseTotal.compareTo(a.expenseTotal));
  return items;
});

/// 账本 AA 分摊汇总(纯计算,依赖交易+成员+虚拟用户)。
///
/// watch [syncGenerationProvider] 让云同步 pull 后自动重算;
/// watch [sharedResourceRefreshProvider] 让成员变更后自动重算。
final aaSettlementProvider =
    FutureProvider.autoDispose.family<AaLedgerSettlement, int>(
        (ref, ledgerId) async {
  // 依赖同步代数 + 共享资源刷新 tick,数据变化时自动重算。
  ref.watch(syncGenerationProvider);
  ref.watch(sharedResourceRefreshProvider);

  final repo = ref.read(repositoryProvider);
  final ledger = await repo.getLedgerById(ledgerId);
  if (ledger == null) {
    return AaLedgerSettlement(participants: const [], transfers: const []);
  }

  // 账本未开启 AA:返回空汇总(入口隐藏、历史数据不展示)。
  if (!ledger.aaEnabled) {
    return AaLedgerSettlement(participants: const [], transfers: const []);
  }

  // 1) 取账本全部 AA 交易(aaMode != 1,已过滤"不分摊")
  final aaTxs = await repo.getAaTransactionsByLedger(ledgerId);

  // 2) 取账本全部参与人:真实成员(ledgerSyncId 查 LedgerMembers)+
  //    虚拟用户(LedgerVirtualUsers)
  final virtualUsers = await repo.getByLedger(ledgerId);
  final participantIds = <String>[];
  final displayNameMap = <String, String>{};

  // 虚拟用户:syncId 作为参与人标识
  for (final vu in virtualUsers) {
    final pid = vu.syncId ?? 'vu_${vu.id}';
    participantIds.add(pid);
    displayNameMap[pid] = vu.name;
  }

  // 真实成员:userId 作为参与人标识。
  // 共享账本从 ledgerMembersProvider 取;单人/本地账本无成员表,
  // 把 owner 纳入(优先 ledger.ownerUserId,其次当前登录用户),保证统计侧
  // 参与人名册与 aaParticipantOptionsProvider 口径一致,不依赖 computeLedger 兜底。
  if (ledger.syncId != null && ledger.syncId!.isNotEmpty) {
    try {
      final members =
          await ref.read(ledgerMembersProvider(ledger.syncId!).future);
      for (final m in members) {
        participantIds.add(m.userId);
        // displayName 可能为 null/空,email 兜底(email 为非空字段)。
        final dn = m.displayName;
        displayNameMap[m.userId] =
            (dn != null && dn.isNotEmpty) ? dn : m.email;
      }
    } catch (e, st) {
      logger.warning('AaSettlement',
          '读取账本成员失败 ledger=$ledgerId,真实成员降级为空', '$e\n$st');
    }
  } else {
    // 单人/本地账本:无成员表,把 owner 纳入参与人名册。
    var ownerId = ledger.ownerUserId;
    if (ownerId == null || ownerId.isEmpty) {
      final cloud = await ref.read(spitoutCloudProviderInstance.future);
      ownerId = await TxAuthorService.currentUserId(cloud);
    }
    if (ownerId != null && ownerId.isNotEmpty) {
      participantIds.add(ownerId);
      displayNameMap[ownerId] = _localSelfName(ref);
    } else {
      // 未登录本地账本:用 localSelfId 占位参与人,保证结算侧参与人名册与
      // 参与人选择器口径一致;展示名统一为本地昵称/「未设置昵称(我)」。
      final localSelfId = await ref.read(localSelfIdProvider.future);
      participantIds.add(localSelfId);
      displayNameMap[localSelfId] = _localSelfName(ref);
    }
  }

  // 3) 调用纯计算服务
  return AaSettlementService.computeLedger(
    transactions: aaTxs,
    allParticipants: participantIds,
    displayNameMap: displayNameMap,
  );
});
