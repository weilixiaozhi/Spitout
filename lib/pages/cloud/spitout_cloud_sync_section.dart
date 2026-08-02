import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show CloudUser, CloudAuthException, TwoFactorStatus;

import 'package:spitout/providers/providers.dart';
import '../../data/models.dart';
import '../../widgets/widgets.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../core/logging/logger_service.dart';
import '../../cloud/auth_error_localizer.dart';
import '../auth/login_page.dart';
import '../settings/log_center_page.dart';
import '../../theme/icons/app_icons.dart';

/// Spitout Cloud 专属同步区块（原 SpitoutCloudSyncPage 改造为可嵌入组件）。
///
/// 跟 `cloud_sync_section.dart` 分开:后者服务于 WebDAV / S3 / Supabase
/// 备份,UI 语义是"整包快照上传/下载";Spitout Cloud 是增量 sync_changes 日志,
/// 全自动,用户感知不到"上传/下载"这个动作,所以单独一个区块。
///
/// 由 CloudServicePage 嵌入在 SpitoutCloud 服务卡片正下方
/// （仅 active.type == spitoutCloud 时显示，其余后端隐藏）。
///
/// 区块结构(单张卡片):
///   1. 头部:账号 + 2FA 各占一行文案,不独立成模块。
///      - 已登录:账号行只读展示邮箱;2FA 行展示启用状态(拉不到时自动隐藏)。
///      - 未登录:账号行直接渲染登录按钮(有保存邮密 → "重新登录"复用凭证,
///        否则跳登录页),不伪装成可点行,避免"看着能点却点不动"的误导。
///      - 专属图标作分类标识:已登录账号 verifiedUser、登录按钮 login、
///        2FA 用 lock/verifiedUser;整张卡片不渲染右箭头。
///   2. 同步状态详情(常驻,不折叠):当前账本 / 全部账本的逐项计数(交易 / 分类)
///      以及未推送变更数量;分类行不带图标,纯文本逐项计数。
///   3. 同步说明(折叠) + server 版本号
///
/// 本 Section 不带 Scaffold / PrimaryHeader / RefreshIndicator 外壳：
/// 下拉刷新由宿主 `_onHostRefresh` 通过 GlobalKey 调用 [refresh]，
/// 方法体（对账 → 健康检查 → 有差异自动 sync）与独立页面一致。
class SpitoutCloudSyncSection extends ConsumerStatefulWidget {
  const SpitoutCloudSyncSection({super.key});

  @override
  ConsumerState<SpitoutCloudSyncSection> createState() =>
      SpitoutCloudSyncSectionState();
}

/// State 类公开：宿主页持有 `GlobalKey<SpitoutCloudSyncSectionState>`，
/// 用于把宿主 RefreshIndicator 的下拉手势转发给 [refresh]。
class SpitoutCloudSyncSectionState
    extends ConsumerState<SpitoutCloudSyncSection> {
  SyncHealthReport? _latestReport;
  bool _checking = false;
  bool _autoSyncing = false;

  /// DEEP:云端是否「一个账本都没有」(checkAccountHealth 返回 null)。
  ///
  /// 为 true 时健康面板直接展示「暂无云端账本」提示,不渲染对账计数骨架,
  /// 也不触发 checkAccountHealth —— 本地账本无 syncId,删兜底后检测必 error,
  /// 展示错误提示反而误导用户以为云端异常,实际只是还没同步过任何账本。
  ///
  /// 复位机制:[refresh] 在 [cloudLedgers] 非空时自动置 false,无需手动清零。
  bool _noCloudLedgers = false;

  /// 重新登录（复用本地保存凭证）失败时的内联友好提示文案。
  ///
  /// 设计意图：账号鉴权失败（[CloudAuthException]，如邮箱/密码错）属于「纯账号
  /// 问题」，不弹 toast、不弹窗，仅在账号行下方用一行红字内联提示，同时让
  /// 「重新登录」按钮消失（避免同一错误反复可点）。网络类异常走另一分支
  /// （保留按钮 + 弹网络 toast），不会写到这里。
  ///
  /// 复位机制：本字段没有显式清零逻辑——按钮仅当 `_credentialInvalidHint == null`
  /// 时渲染，而挂载 onPressed 的那一刻它必然为 null（下方早返回已拦截），故无需手动
  /// reset。用户离开本页 → State.dispose → 再次进入重建为 null，天然复位。
  String? _credentialInvalidHint;

  @override
  void initState() {
    super.initState();
    // 区块一挂载就拉一次 sync health,让"同步状态"面板开屏即有内容。
    // server 版本号由 [spitoutCloudServerVersionProvider] 自动获取(它依赖
    // syncStatusRefreshProvider,每次同步完成自动重新拉一次),不存本地
    // setState 缓存——server 升级后用户在 app 内任何同步操作完都会刷新。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      unawaited(refresh());
    });
  }

  /// 当前选中账本能否充当「当前账本」组的载体,不能则返回 null。
  ///
  /// 资格判定与引擎侧完全对齐(storageMode 为云 + syncId 非空):syncId 为空
  /// 串的云账本从未同步过,拿它当载体会让引擎直接走 error 分支。
  ///
  /// 用 `.future` 等待而非同步读 `valueOrNull`:currentLedgerProvider 是
  /// StreamProvider,开屏 postFrame 触发 refresh 时它多半还停在 loading,
  /// 同步读会拿到 null,导致「当前账本」组在冷启动首帧被误判为"无载体"而
  /// 永久隐藏(要等用户手动切一次账本才出现)。
  Future<int?> _currentCarrierLedgerId() async {
    final current = await ref.read(currentLedgerProvider.future);
    if (current == null) return null;
    if (!isCloudLedgerOf(current.storageMode, isShared: current.isShared)) {
      return null;
    }
    final syncId = current.syncId;
    if (syncId == null || syncId.isEmpty) return null;
    return current.id;
  }

  /// 切账本后只重拉面板数据,不跑完整 [refresh]。
  ///
  /// 刻意不触发同步:切账本事件已由 SyncCoordinator 的 ledger_switched →
  /// triggerAutoSync 覆盖,这里再跑一遍 refresh 会造成双重同步。
  /// 同理也不 bump syncStatusRefreshProvider —— 本方法只负责让「当前账本」
  /// 组跟上新选中的账本。
  Future<void> _reloadPanelOnly() async {
    if (!mounted) return;
    // 无云能力(LocalOnly / 快照型后端)直接早退,连 loading 都不起 —— 等价于
    // 原 `engine is! SyncEngine → return`,类型判断由门面 hasSyncEngine 收口。
    final actions = ref.read(spitoutCloudSyncActionsProvider);
    if (!actions.hasSyncEngine) return;
    try {
      final carrier = await _currentCarrierLedgerId();
      if (!mounted) return;
      final report = await actions.checkAccountHealth(carrierLedgerId: carrier);
      if (!mounted) return;
      setState(() {
        _noCloudLedgers = report == null;
        _latestReport = report;
      });
    } catch (e, st) {
      // 面板跟随属于锦上添花,失败只记日志:切账本主流程(数据加载 + 自动
      // 同步)不能因为一次对账请求出错而被打断。
      logger.warning('CloudSyncSection', '切账本重拉同步面板失败: $e', st);
    }
  }

  /// 下拉刷新入口:对账 → 健康检查 → 有差异自动 syncAccount。
  ///
  /// 走账户级入口而非单本 sync():用户选中本地账本时 currentLedgerId 指向
  /// local,单本 sync() 会被 storage_mode 闸门挡掉,云端账本永远同步不了。
  /// 载体账本只影响「当前账本」组的展示,不影响同步范围。
  ///
  /// 整个流程异步跑得久(10k 数据可能几分钟),用户随时可能切走 →
  /// widget dispose,ref 失效。所有访问 ref 的地方都先看 mounted。
  Future<void> refresh() async {
    if (!mounted) return;
    // 无云能力(LocalOnly / 快照型后端)直接早退,连 loading 都不起 —— 等价于
    // 原 `engine is! SyncEngine → return`,类型判断由门面 hasSyncEngine 收口。
    // 不能删:LocalOnly 场景若继续走,`await _currentCarrierLedgerId()` 会
    // 等一个永不完成的 StreamProvider.future,loading 无限转导致测试超时。
    final actions = ref.read(spitoutCloudSyncActionsProvider);
    if (!actions.hasSyncEngine) return;

    setState(() => _checking = true);
    try {
      // Step 1: 对账 profile。把"server 上缺但本地有"的字段补推上去。
      if (!mounted) return;
      await actions.reconcileProfileToServer(
        cloudProviderFuture: ref.read(spitoutCloudProviderInstance.future),
        currentDisplayName: ref.read(displayNameProvider),
        currentExpenseColorScheme: ref.read(expenseColorSchemeProvider),
      );
      if (!mounted) return;
      await actions.syncMyProfile();

      if (!mounted) return;

      // 「当前账本」组必须跟随用户真实选中的账本,所以载体由 UI 显式指定,
      // 不能交给引擎自选(自选是 id 升序第一本,与用户选中无关)。
      final carrier = await _currentCarrierLedgerId();
      if (!mounted) return;
      // 账户级检查:unpushed 用全局口径;传 carrier 时报告回填
      // carrierLedgerId,「当前账本」组据此显隐(见 _buildHealthSection)。
      // 返回 null 即「一个云端账本都没有」→ 面板展示「暂无云端账本」提示,
      // 不触发任何 sync / 健康检测。
      var report = await actions.checkAccountHealth(carrierLedgerId: carrier);
      if (!mounted) return;
      if (report == null) {
        setState(() {
          _noCloudLedgers = true;
          _latestReport = null;
        });
        return;
      }
      if (_noCloudLedgers) {
        setState(() => _noCloudLedgers = false);
      }
      setState(() => _latestReport = report);

      // [Route B] 登录态正在静默恢复(撞 30s 冷却)→ 不报错、不触发同步,
      // 等冷却结束自动再拉一次,避免用户手动狂刷。
      if (report.recovering) {
        final wait =
            report.recoveryRemaining ?? const Duration(seconds: 30);
        unawaited(Future.delayed(wait, () {
          if (mounted) refresh();
        }));
        return;
      }
      // [Route B] 无恢复凭证 / 恢复彻底失败 → 友好提示手动登录,不抛 raw 异常
      // (具体文案见 _buildHealthSection 的 needsLogin 分支)。
      if (report.needsLogin) {
        return;
      }

      // carrierLedgerId 非空判定不可省:当前选中本地账本时报告不带载体,
      // 此时跳过本轮 backfill(切回云账本再补),避免空断言崩溃。
      if (report.needsBackfill && report.carrierLedgerId != null) {
        final backfilled = await actions
            .backfillUntrackedEntities(ledgerId: report.carrierLedgerId!);
        logger.info('CloudSyncSection',
            'refresh: backfill 补写 $backfilled 条 sync_change');
        if (backfilled > 0 && mounted) {
          // 重拉必须复用同一 carrier,否则报告的 carrierLedgerId 会变 null,
          // 「当前账本」组在刷新中途闪没。
          report = await actions.checkAccountHealth(carrierLedgerId: carrier);
          if (report == null || !mounted) return;
          setState(() => _latestReport = report);
        }
      }

      if (report.hasDiff && mounted) {
        setState(() => _autoSyncing = true);
        try {
          // DEEP:账户级同步原语 —— 内部枚举全部云端账本并逐个 fullPush/
          // 增量/fast-skip(单个账本失败已内部兜底,不中断其余账本),同时
          // 完成 Phase1 用户级数据(profile / storage.list / pull('') /
          // pushUserGlobalEntities),与 app.dart 冷启动共用同一入口。
          final result = await actions.syncAccount();
          if (!mounted || result == null) return;
          logger.info('CloudSyncSection',
              'refresh: syncAccount pushed=${result.pushed} '
              'pulled=${result.pulled} skipped=${result.skipped}');
          // 同理复用 carrier:同步完成后的重拉若丢了载体,「当前账本」组同样闪没。
          final after =
              await actions.checkAccountHealth(carrierLedgerId: carrier);
          if (after != null && mounted) {
            setState(() => _latestReport = after);
          }
        } catch (e) {
          if (mounted) {
            showToast(
                context, '${AppLocalizations.of(context).commonFailed}: $e');
          }
        } finally {
          if (mounted) setState(() => _autoSyncing = false);
        }
      }

      // 不管是否 sync,都 bump 下 UI tick。widget 已 dispose 时跳过 —
      // 否则 ref.read 会抛 StateError "Cannot use ref after the widget was disposed"。
      if (mounted) {
        ref.read(syncStatusRefreshProvider.notifier).state++;
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听用户流：登录 / 登出 / token 静默恢复后 [cloudCurrentUserProvider]
    // 自动推送新值，账号行与同步状态面板即时刷新，无需退出重进。
    final userAsync = ref.watch(cloudCurrentUserProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final l10n = AppLocalizations.of(context);

    // 切账本后让「当前账本」组跟上新选中的账本。注册在 early return 之前,
    // 保证 ledgerId 从 0 变为真实账本时也能触发。
    ref.listen<int>(currentLedgerIdProvider, (prev, next) {
      if (prev == next) return;
      unawaited(_reloadPanelOnly());
    });

    if (ledgerId == 0) {
      // 无账本时展示简化提示（原独立页面为整页 Scaffold，嵌入后收敛为行内文案）
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          l10n.aiOcrNoLedger,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SpitoutTokens.textSecondary(context),
              ),
        ),
      );
    }

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (user) => Column(
        // 横向交给 SectionCard 自带的 horizontal:12 margin,
        // 这里只给垂直 8 避免首尾贴屏幕。
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 单张卡片:账号 + 2FA 作为卡片头部(各占一行文案),下方紧接
          // 同步状态详情(常驻逐项计数)。账号/2FA 不独立成模块,需要
          // 登录时直接在账号行给一个登录按钮,避免拆多张卡占位。
          // 2FA 行内部根据是否能拉到 status 决定显示与否(未登录 /
          // 拉取失败 → 自动隐藏)。不在外层 gate user,切换云方案重新
          // 登录成功后该行走会自动出现。
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 头部:账号 + 2FA(各一行)。未登录时账号行渲染登录按钮。
                _buildAccountSection(context, user),
                const _TwoFactorStatusRow(),
                const Divider(height: 16),
                // 同步状态详情:常驻展示当前账本/全部账本的逐项计数与未推送变更。
                _buildHealthSection(context),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Section 2: 同步说明(折叠) — 解释增量/全量、断点续传、排查
          SectionCard(
            child: _buildSyncHelpSection(context),
          ),
          // Spitout Cloud server 版本号,底部弱展示。
          // 跟 web header 的 vX.Y.Z 对齐,方便确认 server 哪版。
          // 通过 provider 监听,server 升级后跟着 sync ticker 自
          // 动刷新,不依赖死缓存。
          Consumer(builder: (ctx, r, _) {
            final v = r.watch(spitoutCloudServerVersionProvider).valueOrNull;
            if (v == null || v.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Center(
                child: Text(
                  'Spitout Cloud v$v',
                  style: TextStyle(
                    fontSize: 11,
                    color: SpitoutTokens.textTertiary(context),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 账号头部行:已登录时只读展示邮箱(一行文案);未登录时在账号行直接
  /// 给出登录按钮(有保存邮密 → "重新登录"自动复用凭证静默登录,否则跳登录页)。
  /// 不渲染右箭头,用专属图标作分类标识,避免"看着能点却点不动"的误导。
  Widget _buildAccountSection(BuildContext context, CloudUser? user) {
    final l10n = AppLocalizations.of(context);
    final cfg = ref.watch(activeCloudConfigProvider).valueOrNull;
    final cachedEmail = cfg?.spitoutCloudEmail ?? '';
    final cachedPassword = cfg?.spitoutCloudPassword ?? '';
    final hasCredentials = cachedEmail.isNotEmpty && cachedPassword.isNotEmpty;

    // 已登录:纯展示行,不可点。显式传 trailing 空占位隐藏 AppListTile
    // 默认右箭头,使用 verifiedUser 图标作分类标识。
    if (user != null) {
      return AppListTile(
        leading: AppIcons.verifiedUser,
        title: user.email ?? l10n.mineLoggedInEmail,
        trailing: const SizedBox.shrink(),
      );
    }

    // 重新登录失败过：此时账号必然未登录（否则上面的 user != null 已早返回），
    // 在账号行下方内联一行友好红字，并让「重新登录」按钮消失（setState 后 widget
    // 重建 → 命中本早返回 → 按钮不渲染，避免同一错误反复可点）。
    // 字段复位靠离开页面 dispose 重建（见字段注释），无需手动清零。
    if (_credentialInvalidHint != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _credentialInvalidHint!,
          style: TextStyle(fontSize: 13, color: SpitoutTokens.error(context)),
        ),
      );
    }

    // 未登录:用户要求"有需要 login 就给 login 按钮"。这里直接渲染一个
    // 明确的登录按钮(而非伪装成可点行),避免"看着能点却点不动"。
    // 有保存邮密 → "重新登录"复用本地凭证静默登录;无邮密 → 跳传统登录页。
    // 两者都用 AppIcons.login 作分类标识。
    final VoidCallback? onPressed;
    final String label;
    if (hasCredentials) {
      label = l10n.cloudReloginTitle; // "重新登录"
      onPressed = () async {
        try {
          // 走统一 auth 实例（与 SyncEngine / 账号流同源），登录成功后
          // _authStateController 自动推送新用户，账号流即时刷新，无需 invalidate。
          final auth = await ref.read(authServiceProvider.future);
          await auth.signInWithEmail(
            email: cachedEmail,
            password: cachedPassword,
          );
          if (!context.mounted) return;
          showToast(context, l10n.cloudReloginSuccess);
          ref.read(syncStatusRefreshProvider.notifier).state++;
          ref.read(statsRefreshProvider.notifier).state++;
        } on CloudAuthException catch (e) {
          // 账号鉴权失败（邮箱/密码错、账号被锁等）：纯账号问题，不弹 toast、
          // 不弹窗，仅内联友好红字并隐藏按钮（setState 后 widget 重建 → 命中上方
          // 早返回 → 「重新登录」按钮不渲染，避免同一错误反复可点）。
          if (!context.mounted) return;
          setState(() => _credentialInvalidHint = friendlyAuthError(e, context));
        } catch (e) {
          // 其余异常（网络超时、服务端 5xx 等）：保留按钮，弹网络友好 toast，
          // 用户可立即重试。与账号失败分支区分：账号失败不可重试（按钮消失），
          // 网络失败通常短暂且可重试（按钮保留）。
          if (!context.mounted) return;
          showToast(context, friendlyAuthError(e, context));
        }
      };
    } else {
      label = l10n.mineLoginTitle; // "登录"
      onPressed = () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        ref.read(syncStatusRefreshProvider.notifier).state++;
      };
    }

    // 左对齐的紧凑按钮,不撑满整行,与上方标题/下方计数保持一致的左缩进。
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(AppIcons.login, size: 18),
        label: Text(label),
      ),
    );
  }

  /// 同步说明(可折叠):增量/全量、何时走全量、断点续传、排查入口。
  Widget _buildSyncHelpSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      // 去掉 ExpansionTile 默认的上下分割线,贴合 SectionCard 风格
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: Icon(AppIcons.help,
            color: SpitoutTokens.iconSecondary(context)),
        title: Text(
          l10n.cloudSyncHelpTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SpitoutTokens.textPrimary(context),
          ),
        ),
        children: [
          _helpBlock(context, l10n.cloudSyncHelpModesTitle,
              l10n.cloudSyncHelpModesBody),
          _helpBlock(context, l10n.cloudSyncHelpWhenFullTitle,
              l10n.cloudSyncHelpWhenFullBody),
          _helpBlock(context, l10n.cloudSyncHelpStuckTitle,
              l10n.cloudSyncHelpStuckBody),
          _helpBlock(context, l10n.cloudSyncHelpTroubleshootTitle,
              l10n.cloudSyncHelpTroubleshootBody),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogCenterPage()),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(AppIcons.article, size: 18),
              label: Text(l10n.cloudSyncHelpOpenLogCenter),
            ),
          ),
        ],
      ),
    );
  }

  /// 同步说明里的一段:加粗小标题 + 正文(正文里用 \n 分条)。
  Widget _helpBlock(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SpitoutTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: SpitoutTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 同步健康度「详情面板」:本地 / 云端逐项计数常驻展示。
  ///
  /// 设计意图:用户要求同步状态内容常驻可见(不分页、不折叠),
  /// 所以这里直接铺开「当前账本 / 全部账本」两组的交易与分类计数,
  /// 以及「未推送变更」数量。状态判定优先级
  /// (恢复中 → 需登录 → 检测失败 → 自愈熔断 → 差异 → 一致),
  /// 把"单行摘要"扩展为"逐项计数 + 摘要"两截。
  Widget _buildHealthSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = _latestReport;
    final ledgerId = ref.watch(currentLedgerIdProvider);

    // DEEP:一个云端账本都没有 → 直接展示「暂无云端账本」提示,不画计数骨架。
    // (refresh 里 checkAccountHealth 返回 null 时会置 _noCloudLedgers = true
    //  并清空 _latestReport;这里与下方 recovering / needsLogin / error 分支并列。)
    if (_noCloudLedgers) {
      return _buildHealthError(context, l10n.ledgersSectionCloudEmpty);
    }

    // 初次 init 时 report 还没填,仍然把面板骨架 + 占位值画出来(用户要求常驻)。
    final effective = report ??
        const SyncHealthReport(
          ledgerTx: SyncCountPair.missing(),
          totalTx: SyncCountPair.missing(),
          categories: SyncCountPair.missing(),
          unpushedChanges: 0,
        );

    // 异常态(恢复中 / 需登录 / 检测失败)走内联错误展示,与正常态的逐项计数面板分离。
    if (effective.recovering) {
      return _buildHealthError(
        context,
        l10n.syncHealthRecovering,
        showSpinner: _autoSyncing || _checking,
      );
    }
    if (effective.needsLogin) {
      return _buildHealthError(context, l10n.syncHealthNeedsLogin,
          color: Colors.red);
    }
    if (effective.error != null) {
      return _buildHealthError(
          context, l10n.syncHealthCheckFailed(effective.error!),
          color: Colors.red);
    }

    // 状态摘要:自愈熔断 → 红字;差异 → 橙字;一致 → 默认主文字色。
    // selfHealBroken 是 SyncEngine 特有概念(公开方法但不进 SyncService
    // 接口),由门面 SpitoutCloudSyncActions 统一收口,UI 不 is 判断后端类型。
    final actions = ref.read(spitoutCloudSyncActionsProvider);
    // 熔断按**账户级**判定:整行状态描述的是整个账户的同步健康度,任一云端
    // 账本自动恢复失败都要红字。不绑定载体/当前选中账本 —— 否则 A 熔断而
    // 用户选中 B(或选中本地账本)时整行会哑掉,漏报真实故障。
    final selfHealBroken = actions.anySelfHealBroken();
    final String statusText;
    final Color? statusColor;
    if (selfHealBroken) {
      statusText = l10n.cloudSyncHealFailed;
      statusColor = Colors.red;
    } else if (effective.hasDiff) {
      statusText = l10n.syncHealthHasDiff;
      statusColor = Colors.orange;
    } else {
      statusText = l10n.syncHealthInSync;
      statusColor = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部标题行:icon + 标题 + 状态(含检测 / 同步中 spinner)。
        Row(
          children: [
            Icon(AppIcons.cloudSync,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(l10n.syncHealthTitle,
                style: SpitoutTextTokens.title(context)),
            const Spacer(),
            if (_checking || _autoSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // 状态文案:恢复中 / 需登录 / 差异 / 一致 ……(颜色由上述分支决定)。
        Text(statusText,
            style: SpitoutTextTokens.body(context).copyWith(
              color: statusColor ?? SpitoutTokens.textPrimary(context),
            )),
        const SizedBox(height: 12),
        // 当前账本分组:交易数。
        //
        // 用 `== ledgerId` 而非 `!= null`,三层原因:
        // 1. 语义:本组表达的就是「当前选中账本」的口径,载体对不上当前账本
        //    时顶着表头显示另一本账的数据会误导用户。
        // 2. 本地账本:refresh 不传载体 → 引擎剥离输出 carrierLedgerId 为
        //    null → 恒不相等 → 本组自动隐藏,是剥离设计的必然结果而非巧合。
        // 3. 契约:refresh / _reloadPanelOnly 必须以 currentLedgerProvider
        //    的同一条 id 入参。切账本瞬间 ledgerId 同步重建、_latestReport
        //    尚未异步刷新,此时 `!= null` 会短暂显示旧账本数据,`==` 则先
        //    隐藏再出现,不会出现错配。
        if (effective.carrierLedgerId == ledgerId) ...[
          _groupHeader(context, l10n.syncHealthGroupCurrentLedger),
          _pairRow(context, l10n.syncHealthRowTx, effective.ledgerTx),
        ],
        // 全部账本分组:交易数 + 分类数。
        _groupHeader(context, l10n.syncHealthGroupAll),
        _pairRow(context, l10n.syncHealthRowTx, effective.totalTx),
        // 分类行不带 icon(用户要求去掉同步状态分类图标),保持纯文本逐项计数。
        _pairRow(context, l10n.syncHealthRowCategory, effective.categories),
        // 未推送变更。
        _unpushedRow(context, effective.unpushedChanges),
      ],
    );
  }

  /// 同步状态异常态(恢复中 / 需登录 / 检测失败)的内联展示:
  /// 卡片头部(icon + 标题) + 文案,支持可选 spinner / 红色高亮。
  Widget _buildHealthError(
    BuildContext context,
    String message, {
    Color? color,
    bool showSpinner = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.cloudSync, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l10n.syncHealthTitle,
                style: SpitoutTextTokens.title(context)),
            const Spacer(),
            if (showSpinner)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline,
                size: 16, color: color ?? theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: SpitoutTextTokens.body(context).copyWith(
                  color: color ?? SpitoutTokens.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 分组小标题(当前账本 / 全部账本),带前置图标 + 半透明分隔感。
  Widget _groupHeader(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 一行「标签 + 本地·云端计数」。
  ///
  /// [label] 为行首标签(如"交易"/"分类");[pair.remote] < 0 表示远端拉不到
  /// (网络错 / 老 server 无该字段),此时只显示本地数 + 占位「—」,不把 -1
  /// 误渲染成计数;[pair.hasDiff] 为真(本地 ≠ 远端)时整行橙色高亮,提示存在差异。
  /// 同步状态分类行不带 icon,保持纯文本逐项计数。
  Widget _pairRow(
    BuildContext context,
    String label,
    SyncCountPair pair,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final remoteMissing = pair.remote < 0;
    final mismatch = pair.hasDiff;
    final value = remoteMissing
        ? l10n.syncHealthValueRemoteMissing(pair.local)
        : l10n.syncHealthValue(pair.local, pair.remote);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mismatch ? Colors.orange : null,
            ),
          ),
        ],
      ),
    );
  }

  /// 未推送变更行:数量 > 0 时橙色高亮,与逐项计数里的 mismatch 提示语义一致。
  Widget _unpushedRow(BuildContext context, int count) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            l10n.syncHealthRowUnpushed,
            style: TextStyle(
              fontSize: 13,
              color: SpitoutTokens.textSecondary(context),
            ),
          ),
          Expanded(
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                color: count > 0
                    ? Colors.orange
                    : SpitoutTokens.textPrimary(context),
                fontWeight:
                    count > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// 2FA 状态展示行(只读)。
///
/// 拉取 GET /auth/2fa/status,展示「已启用 ✓ · 启用于 YYYY-MM-DD」或「未启用」。
/// 拉取失败(未登录 / 网络错 / 不是 Spitout Cloud)→ 整行隐藏,不展示假数据。
///
/// 监听 [syncStatusRefreshProvider] tick(用户重新登录 / 同步成功后会 bump),
/// 自动重新拉取,所以切换云方案再切回来也能拿到最新状态。
///
/// App 端为 only-read 状态:仅展示,不提供启用/关闭操作。
class _TwoFactorStatusRow extends ConsumerStatefulWidget {
  const _TwoFactorStatusRow();

  @override
  ConsumerState<_TwoFactorStatusRow> createState() =>
      _TwoFactorStatusRowState();
}

class _TwoFactorStatusRowState extends ConsumerState<_TwoFactorStatusRow> {
  TwoFactorStatus? _status;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final provider =
          await ref.read(spitoutCloudProviderInstance.future);
      if (provider == null) {
        if (mounted) {
          setState(() {
            _loaded = true;
            _status = null;
          });
        }
        return;
      }
      // currentUser 是 null 时再请求会拿到 401 / 走 silent recovery 也拿不到
      // session,所以提前判断登录态,避免无谓请求 + 闪烁。
      final user = await provider.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _loaded = true;
            _status = null;
          });
        }
        return;
      }
      final s = await provider.getTwoFactorStatus();
      if (!mounted) return;
      setState(() {
        _status = s;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _status = null;
      });
      logger.warning('2fa.status.fetch.failed', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // syncStatusRefreshProvider 在「重新登录成功 / 同步完成」时 bump,
    // 监听它就能让切换云方案后回来 / 用户重新登录后自动重新拉取 2FA 状态。
    ref.listen<int>(syncStatusRefreshProvider, (_, __) => _load());

    // 还没加载完 / 拉取失败 / 未登录 / 不是 Spitout Cloud → 整行隐藏。
    // 不显示 loading 占位避免初次进入页面时闪一下。
    if (!_loaded || _status == null) {
      return const SizedBox.shrink();
    }
    final status = _status!;

    final enabledLabel =
        status.enabled ? l10n.twofaStatusEnabled : l10n.twofaStatusDisabled;
    // 启用日期并入标题保持单行紧凑;
    // 标题超长时由 AppListTile 的 ellipsis 兜底。
    final enabledAtSuffix = status.enabled && status.enabledAt != null
        ? ' · ${l10n.twofaStatusEnabledAt(
            '${status.enabledAt!.year}-${status.enabledAt!.month.toString().padLeft(2, '0')}-${status.enabledAt!.day.toString().padLeft(2, '0')}',
          )}'
        : '';

    // 不自带 SectionCard:本行已并入宿主的"状态卡片"(账号/2FA/同步状态
    // 三行合一)。只读行显式传 trailing 空占位隐藏默认右箭头,避免
    // "看着能点却点不动"的误导(2FA 开关只能在 Web 端操作,App 端只读)。
    return AppListTile(
      leading: status.enabled ? AppIcons.verifiedUser : AppIcons.lock,
      title: '${l10n.twofaStatusTitle} · $enabledLabel$enabledAtSuffix',
      trailing: const SizedBox.shrink(),
    );
  }
}