import 'package:flutter/material.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';

/// 更新检查结果的统一弹窗。
///
/// 设计意图：用一个组件按 [AppUpdateInfo.status] 渲染三种语义状态，
/// 每种状态都有完整的主行动按钮，避免「已是最新版本」却只剩孤零零的
/// 「取消」按钮这类排版怪象。
///
/// 三种状态与按钮排版：
/// - [UpdateStatus.hasUpdate]：成功色图标 + 主按钮「前往 GitHub 下载」(占满宽度、醒目)
///   + 次要文字按钮「稍后再说」(不抢戏)。
/// - [UpdateStatus.latest]：信息色图标 + 单个主按钮「好的」。
/// - [UpdateStatus.unknown]：警告色图标 + 「前往 GitHub 查看」+「取消」
///   (私有仓库/网络异常降级，引导去浏览器，不报硬错误)。
///
/// 这里只用 [AlertDialog] 的 content 自行布局，刻意绕开默认的 actions，
/// 以保证按钮纵向铺满、主行动最突出，符合直觉排版。
class UpdateDialog extends StatelessWidget {
  /// 检查结果，决定头部色、标题与按钮组。
  final AppUpdateInfo info;

  /// 点击「前往 GitHub」系列按钮时的回调（由调用方负责关闭弹窗并拉起浏览器）。
  final VoidCallback onOpenGitHub;

  /// 点击「稍后再说 / 好的 / 取消」时的回调（关闭弹窗）。
  final VoidCallback onDismiss;

  const UpdateDialog({
    super.key,
    required this.info,
    required this.onOpenGitHub,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 先取出 latestVersion，避免 switch 表达式内对属性反复加 `!`。
    final latestVersion = info.latestVersion;

    // 按状态切换头部图标 / 颜色 / 标题 / 正文 / 按钮组。
    // 用 switch 表达式一次性产出，保证三种状态视觉一致、易维护。
    final (
      IconData icon,
      Color color,
      String title,
      String? body,
      List<Widget> actions,
    ) = switch (info.status) {
      UpdateStatus.hasUpdate => (
        AppIcons.cloudDownload,
        SpitoutTokens.success(context),
        l10n.updateAvailableTitle,
        latestVersion != null
            ? l10n.updateLatestVersion(latestVersion)
            : null,
        <Widget>[
          // 主行动：占满宽度，醒目引导用户去 GitHub 下载。
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenGitHub,
              icon: const Icon(AppIcons.link),
              label: Text(l10n.updateGotoDownload),
            ),
          ),
          const SizedBox(height: 4),
          // 次要行动：不抢戏的文字按钮。
          TextButton(
            onPressed: onDismiss,
            child: Text(l10n.updateLater),
          ),
        ],
      ),
      UpdateStatus.latest => (
        AppIcons.checkCircle,
        SpitoutTokens.info(context),
        l10n.updateAlreadyLatestTitle,
        l10n.updateAlreadyLatest(info.currentVersion),
        <Widget>[
          // 已是最新：仅保留单个主按钮「好的」用于确认关闭。
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDismiss,
              child: Text(l10n.updateOk),
            ),
          ),
        ],
      ),
      UpdateStatus.unknown => (
        AppIcons.info,
        SpitoutTokens.warning(context),
        l10n.updateCantAutoCheckTitle,
        l10n.updateCantAutoCheck,
        <Widget>[
          // 降级态：引导去 GitHub（浏览器登录态可访问私有仓库），并可取消。
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenGitHub,
              icon: const Icon(AppIcons.link),
              label: Text(l10n.updateGoToGithub),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onDismiss,
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    };

    return AlertDialog(
      // 自定义内边距，让圆形图标徽标有呼吸感。
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 圆形语义色图标徽标，作为状态视觉锚点。
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: SpitoutTextTokens.title(context).copyWith(
              color: SpitoutTokens.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body,
              style: SpitoutTextTokens.label(context).copyWith(
                color: SpitoutTokens.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          ...actions,
        ],
      ),
    );
  }
}
