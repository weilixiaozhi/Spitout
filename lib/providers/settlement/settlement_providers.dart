/// AA 分摊 Provider 层。
///
/// 设计意图(文档 §五):
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_service.dart';
import '../../data/db.dart';
import '../../providers/core/database_providers.dart';
import '../../providers/sync/shared_ledger_providers.dart';
import '../../providers/sync/sync_state_providers.dart';
import '../../services/settlement/aa_edit_models.dart';
import '../../services/settlement/aa_settlement_service.dart';

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
/// (aaEnabled 必须跨设备同步,文档 §1.1.5)。
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
/// 名下有账(被交易 aaParticipants 引用)不可删(R7 硬约束),
/// 子仓抛 [StateError],调用方(UI)catch 后展示友好提示。
Future<void> deleteVirtualUser(WidgetRef ref, int id) async {
  try {
    final repo = ref.read(repositoryProvider);
    await repo.delete(id);
  } on StateError {
    // R7 硬约束:名下有账不可删,向上透传让 UI 展示。
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
final aaParticipantOptionsProvider =
    FutureProvider.autoDispose.family<List<AaParticipantOption>, int>(
        (ref, ledgerId) async {
  ref.watch(sharedResourceRefreshProvider);

  final repo = ref.read(repositoryProvider);
  final options = <AaParticipantOption>[];

  // 真实成员:仅共享账本(有 syncId)才有成员体系;
  // 单人/本地账本无成员表,参与人仅虚拟用户。
  final ledger = await repo.getLedgerById(ledgerId);
  final syncId = ledger?.syncId;
  if (syncId != null && syncId.isNotEmpty) {
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

  // 账本未开启 AA:返回空汇总(入口隐藏、历史数据不展示,文档 §6.7)。
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

  // 真实成员:userId 作为参与人标识
  // 共享账本:从 ledgerMembersProvider 取(需 ledger.syncId);
  // 单人/本地账本:无成员表,用操作者兜底(单人场景 paidByUserId 即自己)。
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
    // 单人账本:无成员表,若交易有 paidByUserId 则自动纳入汇总(兜底)。
    // 这里不预填,computeLedger 内部对未知 paidBy 会自动补入。
  }

  // 3) 调用纯计算服务
  return AaSettlementService.computeLedger(
    transactions: aaTxs,
    allParticipants: participantIds,
    displayNameMap: displayNameMap,
  );
});
