import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/cloud/spitout_cloud.dart'
    show SpitoutCloudLedgerMember;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/core/local_self_id_providers.dart';
import 'package:spitout/providers/sync/cloud_client_providers.dart';
import 'package:spitout/providers/ui/theme_providers.dart';

/// 用户展示名统一解析器。
///
/// 修复「同一账号在不同账本显示为 id / 账号 / 昵称混用」的问题。
/// 根因:展示层只查 memberDisplayMap,查不到就裸展示 userId 字符串。
/// 实际上 userId 可能是当前登录用户(本地账本无成员表)或 localSelfId,
/// 这些都应解析为昵称/账号/「我」,而非裸 id。
///
/// 解析优先级:
/// 1. 共享账本成员表(昵称 → 账号)
/// 2. 本人(当前云 userId 或 localSelfId → 本地昵称 → 云账号 → 「未设置昵称」)
/// 3. 虚拟用户名(由调用方传入)
/// 4. 原始 id(未知 id 不套用本地昵称,避免张冠李戴)
class UserDisplayNameResolver {
  final Map<String, SpitoutCloudLedgerMember> memberDisplayMap;
  final String? localOwnerDisplayName;
  final String localSelfId;
  final CloudUser? currentUser;
  final Map<String, String> virtualNames;
  final AppLocalizations l10n;

  UserDisplayNameResolver({
    required this.memberDisplayMap,
    required this.localOwnerDisplayName,
    required this.localSelfId,
    required this.currentUser,
    required this.virtualNames,
    required this.l10n,
  });

  /// 解析 userId 为展示名。
  ///
  /// [userId] 待解析的用户标识(云 userId / localSelfId / 虚拟用户 syncId)。
  /// 返回空串表示「无此人信息,调用方可自行决定是否展示」。
  String resolve(String? userId) {
    if (userId == null || userId.isEmpty) return '';

    // 1. 共享账本成员表:昵称 → 账号
    final member = memberDisplayMap[userId];
    if (member != null) {
      final dn = member.displayName?.trim() ?? '';
      if (dn.isNotEmpty) return dn;
      final account = member.account.trim();
      if (account.isNotEmpty) return account;
    }

    // 2. 本人(当前云 userId 或 localSelfId):本地昵称 → 云账号 → 「未设置昵称」。
    // 两种 id 显示完全一致,避免同一人因身份来源不同出现账号/昵称混用。
    final isCloudMe = currentUser != null && userId == currentUser!.id;
    if (isCloudMe || userId == localSelfId) {
      final localName = localOwnerDisplayName?.trim() ?? '';
      if (localName.isNotEmpty) return localName;
      if (isCloudMe) {
        final account = currentUser!.account?.trim() ?? '';
        if (account.isNotEmpty) return account;
      }
      // 无昵称兜底:仅返回纯名「未设置昵称」,「(我)」后缀由 UI 层通过
      // 共享 meSuffixSpan 统一渲染。
      return l10n.mineSlogan;
    }

    // 3. 虚拟用户
    final virtualName = virtualNames[userId];
    if (virtualName != null && virtualName.isNotEmpty) return virtualName;

    // 4. 兜底原始 id:未知 id 不套用本地昵称,避免张冠李戴。
    return userId;
  }

  /// 判断 userId 是否为本人(当前登录用户或本地账本「我」)。
  ///
  /// 设计意图:本人「(我)」标记统一由 UI 层基于该标记追加共享后缀
  /// (meSuffixSpan/MeSuffix),而非在数据层拼接整体字符串,保证各模块
  /// 字号/颜色/间距一致。共享账本成员表的 isSelf 由成员表提供,此处
  /// 覆盖 currentUser 与 localSelfId 两种本人身份(成员表命中的场景
  /// 走第 1 优先级的 displayName,标记也已在调用方按成员 isSelf 处理)。
  bool isSelf(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (currentUser != null && userId == currentUser!.id) return true;
    return userId == localSelfId;
  }
}

/// 异步构建 [UserDisplayNameResolver]。
///
/// 读取 localSelfId、当前登录用户、本地昵称,组合为解析器实例。
/// 调用方(ref.watch)在 build 中调用,数据变化时自动重建。
Future<UserDisplayNameResolver> buildDisplayNameResolver(
  Ref ref, {
  required Map<String, SpitoutCloudLedgerMember> memberDisplayMap,
  required AppLocalizations l10n,
  Map<String, String> virtualNames = const {},
  String? localOwnerDisplayName,
}) async {
  // 同步 watch 登录态（StreamProvider）：登录 / 登出 / token 静默恢复后，
  // 调用方 build 自动重建解析器，不依赖其它依赖项恰好变化。
  // 必须在首个 await 之前 watch，否则 Riverpod 会因 build 期间异步读取报错。
  final userAsync = ref.watch(cloudCurrentUserProvider);
  final localSelfId = await ref.read(localSelfIdProvider.future);
  CloudUser? currentUser;
  try {
    currentUser = userAsync.asData?.value;
  } catch (_) {
    currentUser = null;
  }
  // localOwnerDisplayName 未传入时,读 displayNameProvider(本地昵称)。
  final localName = localOwnerDisplayName ?? ref.read(displayNameProvider);
  return UserDisplayNameResolver(
    memberDisplayMap: memberDisplayMap,
    localOwnerDisplayName: localName,
    localSelfId: localSelfId,
    currentUser: currentUser,
    virtualNames: virtualNames,
    l10n: l10n,
  );
}
