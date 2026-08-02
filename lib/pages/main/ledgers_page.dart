/// 账本列表页面。
///
/// 账本归属模型:每本账都明确属于「本地」或「Spitout Cloud」,由账本自身的
/// storage_mode 决定,而不是"当前有没有登录"。因此列表常驻两个分区标题
/// (本地账本 / Spitout Cloud 账本),即使某一侧为空也保留标题 —— 让用户
/// 随时看得见"我的数据分别放在哪",而不是登录状态一变列表就换一副面孔。
///
/// 卡片的编辑入口直接打开编辑页,编辑页内承载账本归属操作
/// (移动到云端 / 移动到本地 / 复制到本地);移动语义 fail-closed,
/// 详见 ledger_storage_providers。
library;

import 'package:flutter/material.dart';
import 'package:spitout/cloud/spitout_cloud.dart' show CloudBackendType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:spitout/providers/providers.dart';
import '../../data/models.dart';
import '../../widgets/widgets.dart';
import '../cloud/join_shared_ledger_page.dart';
import 'ledger_edit_page.dart';
import '../../core/logging/logger_service.dart';
import '../../utils/format_utils.dart';
import 'package:spitout/providers/core/post_processor.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/icons/app_icons.dart';

class LedgersPage extends ConsumerStatefulWidget {
  const LedgersPage({super.key});

  @override
  ConsumerState<LedgersPage> createState() => _LedgersPageState();
}

class _LedgersPageState extends ConsumerState<LedgersPage> {
  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(currentLedgerIdProvider);
    final localLedgersAsync = ref.watch(localLedgersProvider);

    // 监听导入进度，当导入完成时自动刷新账本列表和同步状态
    ref.listen<ImportProgress>(importProgressProvider, (previous, next) {
      // 检测到导入完成（从运行中变为完成状态）
      if (previous?.running == true && next.isJustCompleted && next.ledgerId != null) {
        debugPrint('🟢 [LedgersPage] 检测到导入完成: ledgerId=${next.ledgerId}');
        // 触发同步状态刷新和账本列表刷新
        PostProcessor.sync(ref, ledgerId: next.ledgerId!);
      }
    });

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).ledgersTitle,
            // 与「分类管理」页保持一致：添加账本入口统一收归右上角 actions，
            // 并使用圆圈加号图标(AppIcons.addCircle)，整站"新增"心智模型一致；
            // 刷新入口为列表下拉(RefreshIndicator)，不占用头部按钮。
            // 唯一入口是首页 ledger picker 的「管理账本」按钮通过 Navigator.push
            // 进来，可以 pop。showBack=true 让用户回到首页。
            showBack: true,
            actions: [
              HeaderIconAction(
                icon: AppIcons.addCircle, // 与分类页「添加分类」同源：圆圈加号
                tooltip: AppLocalizations.of(context).ledgersCreate,
                onPressed: () => _showCreateLedgerDialog(context),
              ),
            ],
          ),
          Expanded(
            // 刷新入口为列表下拉：RefreshIndicator 提供顶部转圈反馈，无独立刷新按钮。
            child: RefreshIndicator(
              onRefresh: () => _handleRefresh(ref),
              child: _buildLedgerListBody(
                context,
                ref,
                currentId,
                localLedgersAsync,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 下拉刷新回调：自增刷新信号触发本地 provider 重算，并 await 完成，
  /// 使 RefreshIndicator 的转圈能在数据就绪后正确收尾。
  ///
  /// 为什么不弹结果 Toast:「远端账本」概念下线后刷新只是重查本地库,
  /// RefreshIndicator 的转圈收尾本身就是完成反馈,再弹 Toast 反而打扰。
  Future<void> _handleRefresh(WidgetRef ref) async {
    ref.read(ledgerListRefreshProvider.notifier).state++;

    // 本地刷新：本地库查询，provider 内部已兜底（失败返回空列表并记日志），
    // 这里的 try-catch 只是防御 provider 被 override 等极端情况。
    try {
      await ref.read(localLedgersProvider.future);
    } catch (e, st) {
      logger.warning('LedgersPage', '下拉刷新本地账本失败: $e', st);
    }
  }

  /// 账本列表主体：加载态 / 错误态 / 双分区列表
  Widget _buildLedgerListBody(
    BuildContext context,
    WidgetRef ref,
    int? currentId,
    AsyncValue<List<LedgerDisplayItem>> localAsync,
  ) {
    final localLedgers = localAsync.valueOrNull ?? [];
    final localError = localAsync.error;

    // 如果本地在加载中且没有缓存数据，显示全局加载
    if (localAsync.isLoading && localLedgers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 如果本地加载失败，显示错误
    if (localError != null && localLedgers.isEmpty) {
      return Center(
        child: Text('${AppLocalizations.of(context).commonError}: $localError'),
      );
    }

    return _buildSectionedLedgerList(context, ref, localLedgers, currentId);
  }

  /// 构建「本地账本 / Spitout Cloud 账本」双分区列表。
  ///
  /// 两个标题常驻:即使某一侧一本账都没有也保留标题 + 空提示。这样用户在
  /// 未登录、刚登录、账本全在本地等任何状态下看到的都是同一套结构,
  /// 「我的账本存在哪」这件事一眼可见,不需要靠图标去猜。
  Widget _buildSectionedLedgerList(
    BuildContext context,
    WidgetRef ref,
    List<LedgerDisplayItem> ledgers,
    int? currentId,
  ) {
    final l10n = AppLocalizations.of(context);
    // 共享账本是 Spitout Cloud 独有能力(server 端的成员管理 / WS fan-out
    // 都在 Spitout Cloud 后端),非 Spitout Cloud 用户(local / WebDAV /
    // S3 / Supabase 等)就算扫码也走不通,按钮藏起来避免误导。
    final cloudConfigAsync = ref.watch(activeCloudConfigProvider);
    final isSpitoutCloud =
        cloudConfigAsync.valueOrNull?.type == CloudBackendType.spitoutCloud;

    // 归属分区的唯一依据是 storage_mode，与登录状态无关：
    // 未登录时云端账本已被登出清理，分区自然为空，不会出现"看得见但同步不了"。
    final localOnly = ledgers.where((l) => !l.isCloudLedger).toList();
    final cloudOnly = ledgers.where((l) => l.isCloudLedger).toList();

    Widget card(LedgerDisplayItem ledger) => LedgerCard(
          ledger: ledger,
          selected: ledger.id == currentId,
          onTap: () => _handleLocalLedgerTap(ledger),
          onLongPress: () => _openLedgerEditPage(ledger),
          onMore: () => _openLedgerEditPage(ledger),
        );

    return ListView(
      // 内容不足一屏时（如只有一两个账本）夹紧滚动物理不产生 overscroll，
      // 下拉刷新会失效；AlwaysScrollableScrollPhysics 保证任何状态都可下拉。
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        // ---------------- 本地账本 ----------------
        _buildSectionHeader(context,
            icon: AppIcons.localStorage, title: l10n.ledgersSectionLocal),
        if (localOnly.isEmpty)
          _buildSectionEmptyHint(
            context,
            text: l10n.ledgersSectionLocalEmpty,
            // 全空时这里是用户唯一的引导入口，保留「新建账本」按钮。
            action: OutlinedButton.icon(
              onPressed: () => _showCreateLedgerDialog(context),
              icon: const Icon(AppIcons.addCircle, size: 18),
              label: Text(l10n.ledgersNew),
            ),
          )
        else
          ...localOnly.map(card),

        const SizedBox(height: 20.0),

        // ---------------- Spitout Cloud 账本 ----------------
        _buildSectionHeader(context,
            icon: AppIcons.cloudQueue, title: l10n.ledgersSectionCloud),
        // 共享账本入口 — 跟 web 端 LedgersSection 一致，
        // 归属模型下它属于云端范畴，因此收进云端分区标题下方。
        if (isSpitoutCloud)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
            child: OutlinedButton.icon(
              icon: const Icon(AppIcons.personAdd, size: 18),
              label: Text(l10n.sharedJoinPageTitle),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const JoinSharedLedgerPage(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        // 云端账本无论当前是哪种后端都要渲染:退出登录只是"暂时连不上",
        // 若因此把云端账本从列表里藏掉，用户会以为数据丢了。
        if (cloudOnly.isNotEmpty)
          ...cloudOnly.map(card)
        else
          _buildSectionEmptyHint(
            context,
            // 未登录 / 非 Spitout Cloud 后端时给的是"去登录"引导而非"暂无"，
            // 避免用户以为云端真的空了。
            text: isSpitoutCloud
                ? l10n.ledgersSectionCloudEmpty
                : l10n.ledgersSectionCloudSignInHint,
          ),
        const SizedBox(height: 60.0),
      ],
    );
  }

  /// 分区标题（图标 + 文案），本地/云端两侧共用同一套视觉。
  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// 分区空提示：一句说明 + 可选行动按钮。
  ///
  /// 刻意不用整页 AppEmpty —— 分区标题必须常驻，空提示只能占据分区内部
  /// 的一小块，否则一侧为空就会把另一侧的账本挤出视野。
  Widget _buildSectionEmptyHint(
    BuildContext context, {
    required String text,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            action,
          ],
        ],
      ),
    );
  }

  /// 处理本地账本点击 - 切换账本或显示冲突对话框
  Future<void> _handleLocalLedgerTap(LedgerDisplayItem ledger) async {
    // 获取同步状态
    final syncStatusAsync = ref.read(syncStatusProvider(ledger.id));
    final syncStatus = syncStatusAsync.valueOrNull;

    // 检查是否有冲突
    if (syncStatus?.diff == SyncDiff.different) {
      // 显示冲突解决对话框
      await _showConflictResolutionDialog(context, ledger);
      return;
    }

    // 正常切换账本
    ref.read(currentLedgerIdProvider.notifier).state = ledger.id;
    // 切换账本后强制刷新统计页与日历（部分 provider 仅监听刷新信号，不随 ledgerId 参数重算）
    ref.read(statsRefreshProvider.notifier).state++;
    ref.read(calendarRefreshProvider.notifier).state++;
    showToast(context, AppLocalizations.of(context).ledgersSwitched(translateLedgerName(context, ledger.name)));
  }

  /// 打开本地账本编辑二级页面（保留冲突拦截）
  Future<void> _openLedgerEditPage(LedgerDisplayItem ledger) async {
    // 冲突拦截：有冲突 → 先弹冲突解决对话框，不进编辑页
    final syncStatusAsync = ref.read(syncStatusProvider(ledger.id));
    final syncStatus = syncStatusAsync.valueOrNull;
    if (syncStatus?.diff == SyncDiff.different) {
      await _showConflictResolutionDialog(context, ledger);
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LedgerEditPage(ledger: ledger)),
    );
  }



  /// 打开新建账本二级页面
  void _showCreateLedgerDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LedgerEditPage()),
    );
  }

  /// 显示冲突解决对话框
  Future<void> _showConflictResolutionDialog(BuildContext context, LedgerDisplayItem ledger) async {
    

    final l10n = AppLocalizations.of(context);
    final syncService = ref.read(syncServiceProvider);

    // 获取同步状态详情
    final syncStatus = await syncService.getStatus(ledgerId: ledger.id);

    if (!mounted) return;

    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    await showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // 用 ValueNotifier 让 isProcessing 跨 build 持久化（若直接放在
        // StatefulBuilder.builder 闭包内，每次 build 都会重新初始化为 false，
        // loading 占位永远不显示），ValueListenableBuilder 负责在值变化时
        // 触发局部 rebuild。
        final isProcessing = ValueNotifier<bool>(false);
        return ValueListenableBuilder<bool>(
          valueListenable: isProcessing,
          builder: (stateContext, processing, _) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(AppIcons.warning, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Text(l10n.ledgersConflictTitle),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ledgersConflictMessage,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),

                    // 本地信息
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.ledgersConflictLocalInfo(syncStatus.localCount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.ledgersConflictLocalFingerprint(
                              syncStatus.localFingerprint.substring(0, 8),
                            ),
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 云端信息
                    if (syncStatus.cloudFingerprint != null && syncStatus.cloudExportedAt != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.ledgersConflictRemoteInfo(syncStatus.cloudCount ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.ledgersConflictRemoteUpdated(
                                dateFormat.format(syncStatus.cloudExportedAt!.toLocal()),
                              ),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.ledgersConflictRemoteFingerprint(
                                syncStatus.cloudFingerprint!.substring(0, 8),
                              ),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                if (processing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.commonCancel),
                  ),
                  TextButton(
                    onPressed: () async {
                      isProcessing.value = true;
                      try {
                        showToast(context, l10n.ledgersConflictDownloading);
                        final result = await syncService.downloadAndRestoreToCurrentLedger(
                          ledgerId: ledger.id,
                        );

                        if (stateContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (!mounted) return;

                        // 下载完成后，触发刷新状态和账本列表
                        await PostProcessor.sync(ref, ledgerId: ledger.id);

                        if (!mounted) return;

                        // 刷新统计
                        ref.read(statsRefreshProvider.notifier).state++;

                        showToast(
                          this.context,
                          l10n.ledgersConflictDownloadSuccess(result.inserted),
                        );
                      } catch (e) {
                        isProcessing.value = false;
                        if (stateContext.mounted) {
                          await AppDialog.error(
                            stateContext,
                            title: l10n.commonFailed,
                            message: '$e',
                          );
                        }
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.download, size: 18),
                        const SizedBox(width: 4),
                        Text(l10n.ledgersConflictDownload),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      isProcessing.value = true;
                      try {
                        showToast(context, l10n.ledgersConflictUploading);
                        await syncService.uploadCurrentLedger(ledgerId: ledger.id);

                        if (stateContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (!mounted) return;

                        // 刷新列表和同步状态
                        ref.read(ledgerListRefreshProvider.notifier).state++;
                        ref.read(syncStatusRefreshProvider.notifier).state++;

                        showToast(this.context, l10n.ledgersConflictUploadSuccess);
                      } catch (e) {
                        isProcessing.value = false;
                        if (stateContext.mounted) {
                          await AppDialog.error(
                            stateContext,
                            title: l10n.commonFailed,
                            message: '$e',
                          );
                        }
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.upload, size: 18),
                        const SizedBox(width: 4),
                        Text(l10n.ledgersConflictUpload),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}