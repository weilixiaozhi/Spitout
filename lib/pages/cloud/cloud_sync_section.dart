import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show CloudUser, CloudBackendType;

import 'package:spitout/providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/colors.dart';
import '../../l10n/app_localizations.dart';
import 'package:spitout/providers/core/post_processor.dart';
import '../../data/models.dart';
import '../auth/login_page.dart';
import 'sync_preview_dialog.dart';
import '../../theme/icons/app_icons.dart';
import '../../core/logging/logger_service.dart';

/// 备份同步操作区块（原 CloudSyncPage 改造为可嵌入组件）。
///
/// 服务于 WebDAV / S3 / Supabase 的"整包快照上传/下载"路径，
/// 由 CloudServicePage 嵌入在当前选中的备份同步类服务卡片正下方
/// （仅 active.type ∈ {webdav, s3, supabase} 时显示，其余后端隐藏）。
///
/// 与原独立页面相比仅去掉 Scaffold / PrimaryHeader / RefreshIndicator 外壳：
/// - 下拉刷新动作（清状态缓存 + bump tick + 等待状态）上移为宿主
///   `_onHostRefresh` 的对应分支，代码逐行一致；
/// - 上传/下载/登录登出/自动同步开关等全部业务逻辑原样保留。
class CloudSyncSection extends ConsumerStatefulWidget {
  const CloudSyncSection({super.key});

  @override
  ConsumerState<CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends ConsumerState<CloudSyncSection> {
  bool uploadBusy = false;
  bool downloadBusy = false;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authServiceProvider);
    final sync = ref.watch(syncServiceProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);

    if (ledgerId == 0) {
      // 无账本时展示简化提示（原独立页面为整页 Scaffold，嵌入后收敛为行内文案）
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          AppLocalizations.of(context).aiOcrNoLedger,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SpitoutTokens.textSecondary(context),
              ),
        ),
      );
    }

    return authAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        logger.error('CloudSyncSection', '加载认证服务失败', e, st);
        return Center(
          child: Text(AppLocalizations.of(context).commonOperationFailed),
        );
      },
      data: (auth) => FutureBuilder<CloudUser?>(
        future: auth.currentUser,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snap.data;
          final cloudConfig = ref.watch(activeCloudConfigProvider);
          final isLocalMode = cloudConfig.hasValue &&
              cloudConfig.value!.type == CloudBackendType.local;
          // 宿主已按显隐规则保证本区块仅在 WebDAV/S3/Supabase 激活时挂载；
          // 此处判断保留作防御。
          final needsLogin = cloudConfig.hasValue &&
              cloudConfig.value!.type == CloudBackendType.supabase;
          // Supabase 需要登录，其他云服务（S3/WebDAV）使用配置文件认证
          final canUseCloud = !isLocalMode && (!needsLogin || user != null);

          final asyncSt = ref.watch(syncStatusProvider(ledgerId));
          final cached = ref.watch(lastSyncStatusProvider(ledgerId));
          final st = asyncSt.asData?.value ?? cached;

          final isFirstLoad = st == null;
          final refreshing = asyncSt.isLoading;
          bool inSync = false;
          bool notLoggedIn = false;

          // 计算同步状态显示
          String subtitle = '';
          IconData icon = AppIcons.refresh;

          if (!isFirstLoad) {
            switch (st.diff) {
              case SyncDiff.notLoggedIn:
                subtitle = AppLocalizations.of(context).mineSyncNotLoggedIn;
                icon = AppIcons.lock;
                notLoggedIn = true;
                break;
              case SyncDiff.notConfigured:
                subtitle = AppLocalizations.of(context).mineSyncNotConfigured;
                icon = AppIcons.cloudOff;
                break;
              case SyncDiff.noRemote:
                subtitle = AppLocalizations.of(context).mineSyncNoRemote;
                icon = AppIcons.cloudQueue;
                break;
              case SyncDiff.inSync:
                subtitle = AppLocalizations.of(context).mineSyncInSync(st.localCount);
                icon = AppIcons.verified;
                inSync = true;
                break;
              case SyncDiff.localNewer:
                subtitle = AppLocalizations.of(context).mineSyncLocalNewer(st.localCount);
                icon = AppIcons.upload;
                break;
              case SyncDiff.cloudNewer:
                subtitle = AppLocalizations.of(context).mineSyncCloudNewer;
                icon = AppIcons.download;
                break;
              case SyncDiff.different:
                subtitle = AppLocalizations.of(context).mineSyncDifferent;
                icon = AppIcons.syncDifferent;
                break;
              case SyncDiff.error:
                String? localizedMessage;
                if (st.message != null) {
                  switch (st.message!) {
                    case '__SYNC_NOT_CONFIGURED__':
                      localizedMessage = AppLocalizations.of(context).syncNotConfiguredMessage;
                      break;
                    case '__SYNC_NOT_LOGGED_IN__':
                      localizedMessage = AppLocalizations.of(context).syncNotLoggedInMessage;
                      break;
                    case '__SYNC_CLOUD_BACKUP_CORRUPTED__':
                      localizedMessage = AppLocalizations.of(context).syncCloudBackupCorruptedMessage;
                      break;
                    case '__SYNC_NO_CLOUD_BACKUP__':
                      localizedMessage = AppLocalizations.of(context).syncNoCloudBackupMessage;
                      break;
                    case '__SYNC_ACCESS_DENIED__':
                      localizedMessage = AppLocalizations.of(context).syncAccessDeniedMessage;
                      break;
                    default:
                      localizedMessage = st.message;
                  }
                }
                subtitle = localizedMessage ?? AppLocalizations.of(context).mineSyncError;
                icon = AppIcons.error;
                break;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 提示文案
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  AppLocalizations.of(context).cloudSyncHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: SpitoutTokens.textTertiary(context),
                  ),
                ),
              ),
              // 同步操作 Section
              SectionCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    // 同步状态
                    AppListTile(
                      leading: icon,
                      title: AppLocalizations.of(context).mineSyncTitle,
                      subtitle: isFirstLoad ? null : subtitle,
                      enabled: canUseCloud &&
                          !isFirstLoad &&
                          !refreshing &&
                          !uploadBusy &&
                          !downloadBusy,
                      trailing: (canUseCloud &&
                              (isFirstLoad || refreshing || uploadBusy || downloadBusy))
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : null,
                      onTap: (isFirstLoad ||
                              !canUseCloud ||
                              refreshing ||
                              uploadBusy ||
                              downloadBusy)
                          ? null
                          : () async {
                              if (!context.mounted) return;
                              final lines = <String>[
                                AppLocalizations.of(context)
                                    .mineSyncLocalRecords(st.localCount),
                                if (st.cloudCount != null)
                                  AppLocalizations.of(context)
                                      .mineSyncCloudRecords(st.cloudCount!),
                                if (st.cloudExportedAt != null)
                                  AppLocalizations.of(context).mineSyncCloudLatest(
                                      DateFormat('yyyy-MM-dd HH:mm:ss')
                                          .format(st.cloudExportedAt!.toLocal())),
                                AppLocalizations.of(context)
                                    .mineSyncLocalFingerprint(st.localFingerprint),
                                if (st.cloudFingerprint != null)
                                  AppLocalizations.of(context)
                                      .mineSyncCloudFingerprint(st.cloudFingerprint!),
                                if (st.message != null)
                                  () {
                                    String localizedMessage = st.message!;
                                    switch (st.message!) {
                                      case '__SYNC_NOT_CONFIGURED__':
                                        localizedMessage = AppLocalizations.of(context)
                                            .syncNotConfiguredMessage;
                                        break;
                                      case '__SYNC_NOT_LOGGED_IN__':
                                        localizedMessage = AppLocalizations.of(context)
                                            .syncNotLoggedInMessage;
                                        break;
                                      case '__SYNC_CLOUD_BACKUP_CORRUPTED__':
                                        localizedMessage = AppLocalizations.of(context)
                                            .syncCloudBackupCorruptedMessage;
                                        break;
                                      case '__SYNC_NO_CLOUD_BACKUP__':
                                        localizedMessage = AppLocalizations.of(context)
                                            .syncNoCloudBackupMessage;
                                        break;
                                      case '__SYNC_ACCESS_DENIED__':
                                        localizedMessage = AppLocalizations.of(context)
                                            .syncAccessDeniedMessage;
                                        break;
                                    }
                                    return AppLocalizations.of(context)
                                        .mineSyncMessage(localizedMessage);
                                  }(),
                              ];
                              await AppDialog.info(context,
                                  title: AppLocalizations.of(context).mineSyncDetailTitle,
                                  message: lines.join('\n'));
                            },
                    ),
                    // ===== 上传/下载 =====
                    ...[
                      SpitoutTokens.cardDivider(context),
                      // 上传
                      AppListTile(
                        leading: AppIcons.cloudUpload,
                        title:
                            AppLocalizations.of(context).mineUploadTitle,
                        subtitle: isFirstLoad
                            ? null
                            : !canUseCloud
                                ? AppLocalizations.of(context)
                                    .mineUploadNeedCloudService
                                : notLoggedIn
                                    ? AppLocalizations.of(context)
                                        .mineUploadNeedLogin
                                    : uploadBusy
                                        ? AppLocalizations.of(context)
                                            .mineUploadInProgress
                                        : (refreshing
                                            ? AppLocalizations.of(context)
                                                .mineUploadRefreshing
                                            : (inSync
                                                ? AppLocalizations.of(
                                                        context)
                                                    .mineUploadSynced
                                                : null)),
                        enabled: canUseCloud &&
                            !inSync &&
                            !notLoggedIn &&
                            !uploadBusy &&
                            !downloadBusy &&
                            !isFirstLoad &&
                            !refreshing,
                        trailing: (uploadBusy ||
                                refreshing ||
                                (isFirstLoad && canUseCloud))
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : null,
                        onTap: () async {
                          setState(() => uploadBusy = true);
                          // 标记为上传中
                          final uploadingIds = ref.read(uploadingLedgerIdsProvider);
                          ref.read(uploadingLedgerIdsProvider.notifier).set({...uploadingIds, ledgerId});

                          try {
                            await sync.uploadCurrentLedger(
                                ledgerId: ledgerId);
                            if (!context.mounted) return;

                            // 刷新账本列表
                            ref.read(ledgerListRefreshProvider.notifier).tick();

                            await AppDialog.info(context,
                                title: AppLocalizations.of(context)
                                    .mineUploadSuccess,
                                message: AppLocalizations.of(context)
                                    .mineUploadSuccessMessage);
                            Future(() async {
                              try {
                                await sync.refreshCloudFingerprint(
                                    ledgerId: ledgerId);
                              } catch (_) {}
                              try {
                                const maxAttempts = 6;
                                var delay = const Duration(milliseconds: 500);
                                for (var i = 0; i < maxAttempts; i++) {
                                  final stNow =
                                      await sync.getStatus(ledgerId: ledgerId);
                                  if (stNow.diff == SyncDiff.inSync) {
                                    ref
                                        .read(lastSyncStatusProvider(ledgerId)
                                            .notifier)
                                        .set(stNow);
                                    break;
                                  }
                                  if (i < maxAttempts - 1) {
                                    await Future.delayed(delay);
                                    delay *= 2;
                                  }
                                }
                                ref.read(syncStatusRefreshProvider.notifier).tick();
                                // 再次刷新账本列表确保状态更新
                                ref.read(ledgerListRefreshProvider.notifier).tick();
                              } catch (_) {}
                            });
                          } catch (e, st) {
                            logger.error('CloudSyncSection', '上传失败', e, st);
                            if (!context.mounted) return;
                            await AppDialog.info(context,
                                title:
                                    AppLocalizations.of(context).commonFailed,
                                message: AppLocalizations.of(
                                    context,
                                ).commonOperationFailed);
                          } finally {
                            if (mounted) setState(() => uploadBusy = false);
                            // 移除上传中标记
                            final uploadingIds = ref.read(uploadingLedgerIdsProvider);
                            ref.read(uploadingLedgerIdsProvider.notifier).set(uploadingIds.where((id) => id != ledgerId).toSet());
                          }
                        },
                      ),
                      SpitoutTokens.cardDivider(context),
                      // 下载
                      AppListTile(
                        leading: AppIcons.cloudDownload,
                        title: AppLocalizations.of(context).mineDownloadTitle,
                        subtitle: isFirstLoad
                            ? null
                            : !canUseCloud
                                ? AppLocalizations.of(context)
                                    .mineDownloadNeedCloudService
                                : notLoggedIn
                                    ? AppLocalizations.of(context)
                                        .mineUploadNeedLogin
                                    : (refreshing
                                        ? AppLocalizations.of(context)
                                            .mineUploadRefreshing
                                        : (inSync
                                            ? AppLocalizations.of(context)
                                                .mineUploadSynced
                                            : null)),
                        enabled: canUseCloud &&
                            !inSync &&
                            !notLoggedIn &&
                            !downloadBusy &&
                            !isFirstLoad &&
                            !refreshing &&
                            !uploadBusy,
                        trailing: (downloadBusy ||
                                refreshing ||
                                (isFirstLoad && canUseCloud))
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : null,
                        onTap: () async {
                          setState(() => downloadBusy = true);
                          try {
                            // 按接口能力分支:只有支持 diff 预览的后端才走预览流程,
                            // 不依赖具体同步实现类(后续新增后端无需改本页)。
                            if (sync.supportsDiffPreview) {
                              final previewResult = await sync.downloadAndPreview(
                                ledgerId: ledgerId,
                              );

                              if (!context.mounted) return;

                              if (previewResult == null) {
                                // 云端无数据
                                await AppDialog.info(context,
                                    title: AppLocalizations.of(context).mineDownloadComplete,
                                    message: AppLocalizations.of(context).mineDownloadResult(0));
                              } else if (previewResult.preview != null) {
                                // v6+ 格式，有 diff 预览
                                final preview = previewResult.preview!;
                                if (preview.isEmpty) {
                                  await AppDialog.info(context,
                                      title: AppLocalizations.of(context).mineDownloadComplete,
                                      message: AppLocalizations.of(context).syncPreviewEmpty);
                                } else {
                                  final primaryColor = Theme.of(context).colorScheme.primary;
                                  final selected = await showSyncPreviewDialog(
                                    context,
                                    preview: preview,
                                    primaryColor: primaryColor,
                                  );

                                  if (selected != null && selected.isNotEmpty && context.mounted) {
                                    final result = await sync.applyPreviewChanges(
                                      ledgerId: ledgerId,
                                      selectedChanges: selected,
                                      importData: previewResult.importData,
                                    );

                                    if (!context.mounted) return;
                                    await AppDialog.info(context,
                                        title: AppLocalizations.of(context).mineDownloadComplete,
                                        message: AppLocalizations.of(context)
                                            .syncPreviewApplied(result.totalCount));

                                    PostProcessor.runAfterDownload(ref);
                                  }
                                }
                              } else {
                                // 旧格式（无可选变更预览），全量替换
                                final confirmed = await AppDialog.confirm<bool>(
                                  context,
                                  title: AppLocalizations.of(context).syncPreviewOldFormat,
                                  message: AppLocalizations.of(context).syncPreviewOldFormatMessage,
                                ) ?? false;

                                if (confirmed && context.mounted) {
                                  final res = await sync.downloadAndRestoreToCurrentLedger(
                                      ledgerId: ledgerId);
                                  if (!context.mounted) return;
                                  await AppDialog.info(context,
                                      title: AppLocalizations.of(context).mineDownloadComplete,
                                      message: AppLocalizations.of(context).mineDownloadResult(res.inserted));
                                  PostProcessor.runAfterDownload(ref);
                                }
                              }
                            } else {
                              // 无 diff 预览能力的后端,走常规全量下载路径。
                              final res = await sync.downloadAndRestoreToCurrentLedger(
                                  ledgerId: ledgerId);
                              if (!context.mounted) return;
                              await AppDialog.info(context,
                                  title: AppLocalizations.of(context).mineDownloadComplete,
                                  message: AppLocalizations.of(context).mineDownloadResult(res.inserted));
                              PostProcessor.runAfterDownload(ref);
                            }
                          } catch (e, st) {
                            logger.error('CloudSyncSection', '下载失败', e, st);
                            if (!context.mounted) return;
                            await AppDialog.error(context,
                                title:
                                    AppLocalizations.of(context).commonFailed,
                                message: AppLocalizations.of(
                                    context,
                                ).commonOperationFailed);
                          } finally {
                            if (mounted) setState(() => downloadBusy = false);
                          }
                        },
                      ),
                      // 登录/登出 (仅 Supabase 需要，其他云服务使用配置文件认证)
                      if (!isLocalMode && cloudConfig.value!.type == CloudBackendType.supabase)
                        Column(
                          children: [
                            SpitoutTokens.cardDivider(context),
                            AppListTile(
                              leading: user == null
                                  ? AppIcons.login
                                  : AppIcons.verifiedUser,
                              // 本行仅 Supabase 激活时渲染，直接显示账号；
                              // 原 WebDAV 分支（user.id 去后缀）在本上下文中不可达，已按死代码清理。
                              title: user == null
                                  ? AppLocalizations.of(context).mineLoginTitle
                                  : user.account ??
                                      AppLocalizations.of(context)
                                          .mineLoggedInAccount,
                              subtitle: user == null
                                  ? AppLocalizations.of(context)
                                      .mineLoginSubtitle
                                  : AppLocalizations.of(context)
                                      .mineLogoutSubtitle,
                              onTap: () async {
                                // 捕获 app 级 container：页面销毁后仍可完成清理。
                                // 须在首个 await 前捕获,此时 context 仍安全可用。
                                final container = ProviderScope.containerOf(
                                    context,
                                    listen: false);
                                if (user == null) {
                                  await Navigator.of(context).push(
                                      appPageRoute(
                                          builder: (_) =>
                                              const LoginPage()));
                                  ref
                                      .read(syncStatusRefreshProvider
                                          .notifier)
                                      .tick();
                                  ref
                                      .read(
                                          statsRefreshProvider.notifier)
                                      .tick();
                                } else {
                                  final confirmed =
                                      await AppDialog.confirm<bool>(
                                            context,
                                            title: AppLocalizations.of(
                                                    context)
                                                .mineLogoutConfirmTitle,
                                            message: AppLocalizations.of(
                                                    context)
                                                .mineLogoutConfirmMessage,
                                            okLabel: AppLocalizations.of(
                                                    context)
                                                .mineLogoutButton,
                                            cancelLabel:
                                                AppLocalizations.of(
                                                        context)
                                                    .commonCancel,
                                          ) ??
                                          false;

                                  if (confirmed) {
                                    final authService = await ref
                                        .read(authServiceProvider.future);
                                    await authService.signOut();

                                    // 刷新认证服务和同步服务以触发状态更新
                                    ref.invalidate(authServiceProvider);
                                    ref.invalidate(syncServiceProvider);

                                    ref
                                        .read(syncStatusRefreshProvider
                                            .notifier)
                                        .tick();
                                    ref
                                        .read(statsRefreshProvider
                                            .notifier)
                                        .tick();

                                    // Surface 2：登出即云失活，全量清本地
                                    // 云端账本（本地账本不受影响）。放到
                                    // postFrame 确保 SyncEngine 已随
                                    // invalidate 重建销毁，避免与 engine
                                    // 的 GC1/WS 竞态重拉。container 已在 if 块开头
                                    // 捕获，用户登出后快速退出页面也能完成清理，
                                    // 不残留僵尸云端账本。
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) async {
                                      final ok =
                                          await purgeLocalCloudLedgersWithContainer(
                                              container);
                                      // purge 失败不静默,提示用户云端账本残留需手动处理。
                                      if (!ok && context.mounted) {
                                        showToast(
                                            context,
                                            AppLocalizations.of(context)
                                                .cloudPurgeFailed);
                                      }
                                    });
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      // 自动同步
                      if (!isLocalMode)
                        Consumer(builder: (ctx, r, _) {
                          final autoSync = r.watch(autoSyncValueProvider);
                          final setter = r.read(autoSyncSetterProvider);
                          final value = autoSync.asData?.value ?? false;
                          final can = canUseCloud;

                          return Column(
                            children: [
                              SpitoutTokens.cardDivider(context),
                              SwitchListTile(
                                title: Text(AppLocalizations.of(context)
                                    .mineAutoSyncTitle),
                                subtitle: can
                                    ? Text(AppLocalizations.of(context)
                                        .mineAutoSyncSubtitle)
                                    : Text(AppLocalizations.of(context)
                                        .mineAutoSyncNeedLogin),
                                value: can ? value : false,
                                onChanged: can
                                    ? (v) async {
                                        await setter.set(v);
                                      }
                                    : null,
                              ),
                            ],
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
