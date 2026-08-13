import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'app_list_tile.dart';

/// Mine 页「备份与云同步配置」统一入口。
///
/// 合并「云服务入口」与「同步状态卡片」两个 tile：
/// - leading 图标与 subtitle 文案按 9 种状态切换
///   （8 种 [SyncDiff] + 首屏未加载的 loading 态）；
/// - 图标映射复用 cloud_sync_page 同步状态行的映射关系，
///   文案使用带 localCount 的参数化版本，信息密度与配置页状态行一致；
/// - 点击进入 [CloudServicePage]，不按后端类型路由分叉
///   （Spitout Cloud / WebDAV 等差异由配置页内部按显示/隐藏处理）。
///
/// 数据源与同步卡片一致：`syncStatusProvider` 实时值优先，
/// 回退 `lastSyncStatusProvider` 缓存，避免刷新间隙闪烁。
/// 登录态不单独判断 —— 未登录会由 sync 层反映为 [SyncDiff.notLoggedIn]。
class CloudServiceEntryTile extends ConsumerWidget {
  /// 点击入口回调，由 page 层注入导航逻辑（通常进入云服务配置页）。
  /// widget 不感知具体 page，保持 pages → widgets 单向依赖。
  final VoidCallback onTap;

  const CloudServiceEntryTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final asyncSt = ref.watch(syncStatusProvider(ledgerId));
    final cached = ref.watch(lastSyncStatusProvider(ledgerId));
    final st = asyncSt.asData?.value ?? cached;
    final refreshing = asyncSt.isLoading;

    // 9 态映射：8 种 SyncDiff + st == null 的首屏加载态。
    // local 模式下 NoopSyncService 恒返回 notConfigured，自然落入第 1 态。
    final IconData icon;
    final String subtitle;
    if (st == null) {
      icon = AppIcons.cloudQueue;
      subtitle = l10n.mineCloudServiceLoading;
    } else {
      switch (st.diff) {
        case SyncDiff.notLoggedIn:
          icon = AppIcons.lock;
          subtitle = l10n.mineSyncNotLoggedIn;
          break;
        case SyncDiff.notConfigured:
          icon = AppIcons.cloudOff;
          subtitle = l10n.mineSyncNotConfigured;
          break;
        case SyncDiff.localOnly:
          icon = AppIcons.localStorage;
          subtitle = l10n.mineSyncLocalOnly;
          break;
        case SyncDiff.noRemote:
          icon = AppIcons.cloudQueue;
          subtitle = l10n.mineSyncNoRemote;
          break;
        case SyncDiff.inSync:
          icon = AppIcons.verified;
          subtitle = l10n.mineSyncInSync(st.localCount);
          break;
        case SyncDiff.localNewer:
          icon = AppIcons.upload;
          subtitle = l10n.mineSyncLocalNewer(st.localCount);
          break;
        case SyncDiff.cloudNewer:
          icon = AppIcons.download;
          subtitle = l10n.mineSyncCloudNewer;
          break;
        case SyncDiff.different:
          icon = AppIcons.syncDifferent;
          subtitle = l10n.mineSyncDifferent;
          break;
        case SyncDiff.error:
          icon = AppIcons.error;
          subtitle = l10n.mineSyncError;
          break;
      }
    }

    return AppListTile(
      leading: icon,
      title: l10n.mineCloudService,
      subtitle: subtitle,
      // 首屏加载 / 后台刷新中时 trailing 显示小 spinner，
      // 否则显示常规导航箭头。该入口是进入配置页的唯一路径，始终可点。
      trailing: (st == null || refreshing)
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(AppIcons.chevronRight,
              color: SpitoutTokens.iconTertiary(context), size: SpitoutDimens.icon20),
      onTap: onTap,
    );
  }
}
