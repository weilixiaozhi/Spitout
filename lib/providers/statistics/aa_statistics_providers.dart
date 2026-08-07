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
/// - [aaStatisticsProvider]:账本 AA 分摊汇总(纯计算,依赖交易+成员+虚拟用户)。
library;

import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_self_id_providers.dart';
import '../../core/logging/logger_service.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/core/database_providers.dart';
import '../../providers/sync/cloud_client_providers.dart';
import '../../providers/sync/shared_ledger_providers.dart';
import '../ui/avatar_providers.dart';
import '../../providers/ui/language_provider.dart';
import '../../providers/ui/theme_providers.dart';
import '../../services/data/tx_author_service.dart';
import '../../services/statistics/aa_edit_models.dart';
import '../../services/statistics/aa_member_detail_models.dart';
import '../../services/statistics/aa_statistics_service.dart';

/// 本地账本自我参与人的展示名:优先本地昵称(displayNameProvider),
/// 昵称为空时统一回退「未设置昵称」,与「我的页」昵称占位文案保持一致。
/// 仅返回纯名字,「(我)」后缀由 UI 层基于 isSelf 标记用共享
/// meSuffixSpan/MeSuffix 统一渲染,不在数据层拼接。
String _localSelfName(Ref ref) {
  final nickname = ref.read(displayNameProvider).trim();
  if (nickname.isNotEmpty) return nickname;
  // 昵称为空:兜底展示「未设置昵称」,不暴露原始 id。
  final locale =
      ref.read(languageProvider) ?? ui.PlatformDispatcher.instance.locale;
  final l10n = lookupAppLocalizations(locale);
  return l10n.mineSlogan;
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
    logger.error(
      'AaStatistics',
      'setAaEnabled 失败 ledger=$ledgerId enabled=$enabled',
      e,
      st,
    );
    rethrow;
  }
}

/// 账本虚拟用户列表(Stream,自动响应增删改)。
///
/// family by ledgerId,UI(分摊设置/编辑页)watch 此 provider 渲染参与人选项。
final ledgerVirtualUsersProvider = StreamProvider.autoDispose
    .family<List<LedgerVirtualUser>, int>((ref, ledgerId) {
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
    logger.error('AaStatistics', '新建虚拟用户失败 ledger=$ledgerId name=$name', e, st);
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
    logger.error('AaStatistics', '重命名虚拟用户失败 id=$id name=$name', e, st);
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
    logger.error('AaStatistics', '删除虚拟用户失败 id=$id', e, st);
    rethrow;
  }
}

/// 解析当前操作者 id(云 userId 优先,未登录回退设备身份 localSelfId)。
///
/// 供分摊编辑页默认支出人展示/锁定使用;与落库层 markTxAuthor 的身份
/// 解析口径一致,避免页面直接依赖 TxAuthorService。
Future<String> currentOperatorIdFromUi(WidgetRef ref) async {
  final cloud = await ref.read(spitoutCloudProviderInstance.future);
  final cloudUserId = await TxAuthorService.currentUserId(cloud?.auth);
  final localSelfId = await ref.read(localSelfIdProvider.future);
  return (cloudUserId != null && cloudUserId.isNotEmpty)
      ? cloudUserId
      : localSelfId;
}

/// 账本 AA 参与人选项列表(真实成员 + 虚拟用户)。
///
/// 供编辑器 AA 区块、AaEditPage、交易详情页统一取参与人名册,
/// 标识口径与 [aaStatisticsProvider] 一致(真实成员 userId、
/// 虚拟用户 syncId,无 syncId 兜底 `vu_<本地id>`)。
/// watch [sharedResourceRefreshProvider] 让成员变更后自动重取。
///
/// 单人/本地账本(无 syncId)无成员表,此处会把 owner 自动纳入参与人
/// 名册(优先 ledger.ownerUserId,其次当前登录用户),避免参与人选择器
/// 在单人账本场景下出现空列表、用户无从下手。
final aaParticipantOptionsProvider = FutureProvider.autoDispose
    .family<List<AaParticipantOption>, int>((ref, ledgerId) async {
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
            // displayName 可能为 null/空,account 兜底(account 为非空字段)。
            final dn = m.displayName;
            options.add(
              AaParticipantOption(
                id: m.userId,
                name: (dn != null && dn.isNotEmpty) ? dn : m.account,
                isVirtual: false,
                // 本人标记:UI 据此统一渲染「(我)」后缀,与成员管理模块一致。
                isSelf: m.isSelf,
              ),
            );
          }
        } catch (e, st) {
          logger.warning(
            'AaStatistics',
            '读取账本成员失败 ledger=$ledgerId,成员选项降级为空',
            '$e\n$st',
          );
        }
      } else {
        // 单人/本地账本:无成员表,把 owner 自动纳入参与人名册,
        // 保证参与人选择器至少有一个可选项。
        // 优先取 ledger.ownerUserId;为空时回退当前登录用户 id;
        // 两者都拿不到时用 localSelfId(设备身份 UUID)兜底,确保 UI 不空态。
        var ownerId = ledger?.ownerUserId;
        if (ownerId == null || ownerId.isEmpty) {
          final cloud = await ref.read(spitoutCloudProviderInstance.future);
          ownerId = await TxAuthorService.currentUserId(cloud?.auth);
        }
        // 真实 userId 直接作为参与人标识;拿不到时用 localSelfId 兜底,保证名册非空。
        // 展示名统一走本地昵称/「未设置昵称」兜底(剥离「(我)」后缀,由 UI
        // 层统一渲染),与交易详情页口径一致。
        final localSelfId = await ref.read(localSelfIdProvider.future);
        final finalId = (ownerId != null && ownerId.isNotEmpty)
            ? ownerId
            : localSelfId;
        final ownerName = _localSelfName(ref);
        options.add(
          AaParticipantOption(
            id: finalId,
            name: ownerName,
            isVirtual: false,
            // 单人/本地账本 owner 即本人,标记 isSelf 供 UI 渲染「(我)」后缀。
            isSelf: true,
          ),
        );
      }

      // 虚拟用户:syncId 作为参与人标识(与统计口径一致)。
      final virtualUsers = await repo.getByLedger(ledgerId);
      for (final vu in virtualUsers) {
        options.add(
          AaParticipantOption(
            id: vu.syncId ?? 'vu_${vu.id}',
            name: vu.name,
            isVirtual: true,
          ),
        );
      }
      return options;
    });

/// 账本成员支出统计项(按 paidByUserId 聚合)。
///
/// 设计意图:成员支出模块需要包含虚拟用户的支出,而云端 memberStats 仅含
/// 真实成员。按交易 paidByUserId 本地聚合(支出人 = paidByUserId),
/// 关联参与人名册(真实成员 + 虚拟用户)拿展示名,与 AA 分摊统计口径一致。
class MemberExpenseStatItem {
  const MemberExpenseStatItem({
    required this.participantId,
    required this.displayName,
    required this.expenseTotal,
    required this.txCount,
    this.isSelf = false,
    this.avatarUrl,
    this.localAvatarPath,
  });

  /// 参与人标识(userId 或虚拟用户 syncId)。
  final String participantId;

  /// 展示名(真实成员 displayName/account、虚拟用户 name)。
  ///
  /// 本人时已剥离「(我)」后缀(仅保留纯名字),「(我)」标记由 UI 层
  /// 统一渲染,保证与成员管理模块的字号/颜色/空格一致。
  final String displayName;

  /// 该成员作为支出人的支出金额合计（单位：元；数据库存整数分，输出前已 /100）。
  final double expenseTotal;

  /// 该成员作为支出人的支出笔数。
  final int txCount;

  /// 是否本人(当前用户);UI 据此追加「(我)」后缀,与成员管理模块一致。
  final bool isSelf;

  /// 服务端头像相对/绝对 URL(真实成员);虚拟用户为 null。
  final String? avatarUrl;

  /// 本人本地头像文件路径;无头像或非本人为 null。
  final String? localAvatarPath;
}

/// 账本成员支出统计(按 paidByUserId 聚合,含虚拟用户)。
///
/// 数据源:账本全部支出交易(type='expense'),按 paidByUserId 分组聚合
/// 金额与笔数;展示名取参与人名册(真实成员 + 虚拟用户),与 AA 分摊统计
/// 口径一致。paidByUserId 为空的交易不计入(支出人未知,无法归属)。
final memberExpenseStatsProvider = FutureProvider.autoDispose
    .family<List<MemberExpenseStatItem>, int>((ref, ledgerId) async {
      // 监听统一数据变更信号：任何交易/成员/虚拟用户写入都会自动重算。
      ref.watch(dataChangeSignalProvider);
      ref.watch(sharedResourceRefreshProvider);
      // 本人头像变化时成员支出列表也要跟着刷新
      ref.watch(avatarRefreshProvider);

      final repo = ref.read(repositoryProvider);
      final ledger = await repo.getLedgerById(ledgerId);
      if (ledger == null) return const [];
      String? localAvatarPath;
      try {
        localAvatarPath = await ref.read(avatarPathProvider.future);
      } catch (e, st) {
        logger.warning('AaStatistics', '读取本地头像失败，成员支出头像降级为图标', '$e\n$st');
      }

      // 账本全部支出交易(只统计支出,与首页/统计口径一致)。
      final allTx = await repo.getTransactionsByLedger(ledgerId);
      final expenseTx = allTx.where((t) => t.type == 'expense').toList();

      // 按 paidByUserId 聚合:金额合计 + 笔数。paidByUserId 为空跳过(无法归属)。
      // amountMap 累加的是数据库"整数分"，输出时统一 /100 转"元"——与
      // AaStatisticsService / 账本卡片的口径一致，避免 UI 直接展示放大 100 倍。
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
      // 本人标记:单人/本地账本的 owner、共享账本 isSelf 成员均为「我」,
      // 由 UI 层统一渲染「(我)」后缀,与成员管理模块样式一致。
      final selfMap = <String, bool>{};
      // 真实成员的头像 URL(userId → server avatarUrl)
      final avatarUrlMap = <String, String?>{};
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
            displayNameMap[m.userId] = (dn != null && dn.isNotEmpty)
                ? dn
                : m.account;
            selfMap[m.userId] = m.isSelf;
            avatarUrlMap[m.userId] = m.avatarUrl;
          }
        } catch (e, st) {
          logger.warning(
            'AaStatistics',
            '读取账本成员失败 ledger=$ledgerId,成员支出降级为仅虚拟用户',
            '$e\n$st',
          );
        }
      } else {
        // 单人/本地账本:owner 即本人,展示名剥离「(我)」后缀(纯名字),
        // 后缀交给 UI 统一渲染,避免与成员管理模块的拼接格式不一致。
        final selfName = _localSelfName(ref);
        var ownerId = ledger.ownerUserId;
        if (ownerId == null || ownerId.isEmpty) {
          final cloud = await ref.read(spitoutCloudProviderInstance.future);
          ownerId = await TxAuthorService.currentUserId(cloud?.auth);
        }
        if (ownerId != null && ownerId.isNotEmpty) {
          displayNameMap[ownerId] = selfName;
          selfMap[ownerId] = true;
        } else {
          final localSelfId = await ref.read(localSelfIdProvider.future);
          displayNameMap[localSelfId] = selfName;
          selfMap[localSelfId] = true;
        }
      }

      // 组装结果:仅保留有支出的参与人(amountMap 的 key),按金额降序。
      final items = <MemberExpenseStatItem>[];
      amountMap.forEach((pid, total) {
        final isSelf = selfMap[pid] ?? false;
        items.add(
          MemberExpenseStatItem(
            participantId: pid,
            displayName: displayNameMap[pid] ?? pid,
            expenseTotal: total / 100,
            txCount: countMap[pid] ?? 0,
            isSelf: isSelf,
            avatarUrl: avatarUrlMap[pid],
            localAvatarPath: isSelf ? localAvatarPath : null,
          ),
        );
      });
      items.sort((a, b) => b.expenseTotal.compareTo(a.expenseTotal));
      return items;
    });

/// 账本 AA 分摊汇总(纯计算,依赖交易+成员+虚拟用户)。
///
/// watch [dataChangeSignalProvider] 让任意写库（含云同步 pull）后自动重算;
/// watch [sharedResourceRefreshProvider] 让成员变更后自动重算。
final aaStatisticsProvider = FutureProvider.autoDispose
    .family<AaLedgerStatistics, int>((ref, ledgerId) async {
      // 依赖统一数据变更信号 + 共享资源刷新 tick,数据变化时自动重算。
      ref.watch(dataChangeSignalProvider);
      ref.watch(sharedResourceRefreshProvider);

      final repo = ref.read(repositoryProvider);
      final ledger = await repo.getLedgerById(ledgerId);
      if (ledger == null) {
        return AaLedgerStatistics(participants: const [], transfers: const []);
      }

      // 账本未开启 AA:返回空汇总(入口隐藏、历史数据不展示)。
      if (!ledger.aaEnabled) {
        return AaLedgerStatistics(participants: const [], transfers: const []);
      }

      // 1) 取账本全部 AA 交易(aaMode != 1,已过滤"不分摊")
      final aaTxs = await repo.getAaTransactionsByLedger(ledgerId);

      // 2) 取账本全部参与人:真实成员(ledgerSyncId 查 LedgerMembers)+
      //    虚拟用户(LedgerVirtualUsers)
      final virtualUsers = await repo.getByLedger(ledgerId);
      final participantIds = <String>[];
      final displayNameMap = <String, String>{};
      // 本人标记:真实成员按成员表 isSelf,单人/本地账本 owner 恒为本人。
      final selfMap = <String, bool>{};

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
          final members = await ref.read(
            ledgerMembersProvider(ledger.syncId!).future,
          );
          for (final m in members) {
            participantIds.add(m.userId);
            // displayName 可能为 null/空,account 兜底(account 为非空字段)。
            final dn = m.displayName;
            displayNameMap[m.userId] = (dn != null && dn.isNotEmpty)
                ? dn
                : m.account;
            selfMap[m.userId] = m.isSelf;
          }
        } catch (e, st) {
          logger.warning(
            'AaStatistics',
            '读取账本成员失败 ledger=$ledgerId,真实成员降级为空',
            '$e\n$st',
          );
        }
      } else {
        // 单人/本地账本:无成员表,把 owner 纳入参与人名册。
        var ownerId = ledger.ownerUserId;
        if (ownerId == null || ownerId.isEmpty) {
          final cloud = await ref.read(spitoutCloudProviderInstance.future);
          ownerId = await TxAuthorService.currentUserId(cloud?.auth);
        }
        if (ownerId != null && ownerId.isNotEmpty) {
          participantIds.add(ownerId);
          displayNameMap[ownerId] = _localSelfName(ref);
          selfMap[ownerId] = true;
        } else {
          // 未登录本地账本:用 localSelfId 占位参与人,保证结算侧参与人名册与
          // 参与人选择器口径一致;展示名为本地昵称/「未设置昵称」纯名,
          // 「(我)」后缀由 UI 层统一渲染。
          final localSelfId = await ref.read(localSelfIdProvider.future);
          participantIds.add(localSelfId);
          displayNameMap[localSelfId] = _localSelfName(ref);
          selfMap[localSelfId] = true;
        }
      }

      // 3) 调用纯计算服务
      return AaStatisticsService.computeLedger(
        transactions: aaTxs,
        allParticipants: participantIds,
        displayNameMap: displayNameMap,
        selfMap: selfMap,
      );
    });

/// 成员账单详情（按支出人维度汇总）。
///
/// 分摊详情表点击成员进入本详情页：只展示「该成员作为支出人」的 AA 账单
/// （aaMode != 1），并复用 [aaStatisticsProvider] 的参与人名册 / 本人标记 /
/// 汇总口径，保证详情页与分摊详情表的实付 / 应摊 / 差额完全一致。
///
/// 单笔账单的分摊明细由 [AaStatisticsService.computeTx] 重算（与账本级
/// 统计同一条计算路径），避免维护第二套分摊算法。
final aaMemberDetailProvider = FutureProvider.autoDispose
    .family<AaMemberDetailData?, ({int ledgerId, String participantId})>((
      ref,
      args,
    ) async {
      // 依赖账本级统计：成员/交易变化时详情页自动重算，且直接复用其结果中的
      // 参与人名册与本人标记，避免在 Provider 层再复制一份身份组装逻辑。
      final stats = await ref.watch(aaStatisticsProvider(args.ledgerId).future);
      final repo = ref.read(repositoryProvider);
      final ledger = await repo.getLedgerById(args.ledgerId);
      if (ledger == null || !ledger.aaEnabled) return null;

      // 从统计结果中定位成员：统计结果包含全部参与人（含虚拟用户与兜底参与人），
      // 找不到说明该参与人已不在当前账本，直接返回 null 走空态兜底。
      AaParticipantSummary? member;
      for (final p in stats.participants) {
        if (p.participantId == args.participantId) {
          member = p;
          break;
        }
      }
      if (member == null) return null;

      // 参与人名册 / 显示名 / 本人标记均以统计结果为唯一来源，与分摊详情表一致。
      final participantIds = <String>[
        for (final p in stats.participants) p.participantId,
      ];
      final nameOf = <String, String>{
        for (final p in stats.participants) p.participantId: p.displayName,
      };
      final selfOf = <String, bool>{
        for (final p in stats.participants) p.participantId: p.isSelf,
      };

      // 取账本全部交易（带分类）；watch 变体返回流，取首帧快照即可。
      // 成员详情本质是「首页支出列表按支出人筛选」：全部支出（含不分摊）
      // 都要展示，仅收入交易与未知支出人不归属任何成员。
      final all = await repo
          .watchTransactionsWithCategoryAll(ledgerId: args.ledgerId)
          .first;
      final bills = <AaMemberBill>[];
      for (final it in all) {
        final tx = it.t;
        if (tx.type != 'expense') continue; // 支出明细不含收入交易。
        final paidBy = tx.paidByUserId;
        if (paidBy == null || paidBy.isEmpty) continue; // 支出人未知，无法归属。
        if (paidBy != args.participantId) continue; // 只保留本人垫付的账单。

        final mode = AaMode.fromDb(tx.aaMode);
        // 不分摊（aaMode=1）不参与 AA 计算：整笔支出归本人，无分摊明细；
        // 指定分摊数据异常（如 aaSplits 为空）同样降级为整笔归本人。
        final result = mode == AaMode.noSplit
            ? null
            : AaStatisticsService.computeTx(
                tx: tx,
                allParticipants: participantIds,
              );
        if (result == null) {
          bills.add(
            AaMemberBill(
              tx: tx,
              category: it.category,
              mode: mode,
              // 成员详情按账本本位币口径展示,与分摊详情表/汇总卡一致。
              totalAmount: (tx.nativeAmount ?? tx.amount) / 100,
              myShare: (tx.nativeAmount ?? tx.amount) / 100,
              payerName: nameOf[paidBy] ?? paidBy,
              splits: const [],
            ),
          );
          continue;
        }

        final shares = result.shares;
        bills.add(
          AaMemberBill(
            tx: tx,
            category: it.category,
            mode: result.mode,
            totalAmount: result.paidAmount,
            // 本人应摊：人均模式全员在册；指定金额未填本人时兜底 0。
            myShare: shares[args.participantId] ?? 0,
            payerName: nameOf[result.paidBy] ?? result.paidBy,
            splits: [
              for (final e in shares.entries)
                AaMemberSplit(
                  participantId: e.key,
                  displayName: nameOf[e.key] ?? e.key,
                  amount: e.value,
                  isSelf: selfOf[e.key] ?? false,
                ),
            ],
          ),
        );
      }
      // 按发生时间倒序，列表按日期分组时自然保持最新在前。
      bills.sort((a, b) => b.tx.happenedAt.compareTo(a.tx.happenedAt));

      return AaMemberDetailData(
        ledgerName: ledger.name,
        member: member,
        bills: bills,
      );
    });

/// 参与人头像上下文：参与人标识(userId) → 云端成员(含头像 URL)。
///
/// 供转账方案行渲染"昵称前头像"使用：真实成员取 avatarUrl，
/// 虚拟用户/未配置头像的成员无 URL，UI 层据此回退 person 占位图标。
/// 本地/单人账本无成员表，返回空映射，全部参与人走占位头像。
class AaParticipantAvatarContext {
  const AaParticipantAvatarContext({
    this.members = const {},
    this.baseUrl = '',
  });

  /// 参与人标识(userId) → 云端成员(共享账本才可能有数据)。
  final Map<String, SpitoutCloudLedgerMember> members;

  /// 云服务 baseUrl，用于把相对头像路径拼成完整 URL。
  final String baseUrl;
}

/// 账本参与人头像上下文(共享账本成员 + 云 baseUrl)。
///
/// watch [sharedResourceRefreshProvider] 让成员变更后自动刷新，
/// 与 [aaStatisticsProvider] 同源数据、口径一致。
final aaParticipantAvatarContextProvider = FutureProvider.autoDispose
    .family<AaParticipantAvatarContext, int>((ref, ledgerId) async {
      ref.watch(sharedResourceRefreshProvider);

      final repo = ref.read(repositoryProvider);
      final ledger = await repo.getLedgerById(ledgerId);
      final syncId = ledger?.syncId;
      // 本地/单人账本无成员表：返回空上下文，UI 统一走占位头像。
      if (syncId == null || syncId.isEmpty) {
        return const AaParticipantAvatarContext();
      }
      try {
        final members = await ref.read(ledgerMembersProvider(syncId).future);
        final cloud = await ref.read(spitoutCloudProviderInstance.future);
        return AaParticipantAvatarContext(
          members: {for (final m in members) m.userId: m},
          baseUrl: cloud?.baseUrl ?? '',
        );
      } catch (e, st) {
        logger.warning(
          'AaStatistics',
          '读取账本成员头像失败 ledger=$ledgerId,头像上下文降级为空',
          '$e\n$st',
        );
        return const AaParticipantAvatarContext();
      }
    });
