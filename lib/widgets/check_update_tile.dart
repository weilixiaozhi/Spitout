import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';
import 'app_list_tile.dart';
import 'update_dialog.dart';

/// 「检查更新」入口卡片。
///
/// 设计意图：把「检查更新」的本地 UI 状态（当前版本、最近一次检查结果、
/// 是否正在检查）收敛到这个组件内，避免污染 MinePage。
/// 视觉上复用全站统一的 [AppListTile]，并在「发现新版本」时显示成功色
/// 「更新」胶囊，与探测结果联动。
///
/// 更新检查的实际调用由调用方（页面）注入：组件本身不直接触碰
/// services 层，测试也可传入桩函数避免真实网络（必传注入）。
class CheckUpdateTile extends StatefulWidget {
  /// 版本检查函数（必传）。
  ///
  /// 设计意图：由页面经 providers 动作函数（如 `checkAppUpdate`）注入，
  /// 组件保持纯 UI 职责；测试同样用桩函数替换，隔离网络依赖。
  final Future<AppUpdateInfo> Function() check;

  const CheckUpdateTile({super.key, required this.check});

  @override
  State<CheckUpdateTile> createState() => _CheckUpdateTileState();
}

class _CheckUpdateTileState extends State<CheckUpdateTile> {
  /// 最近一次检查结果，驱动「发现新版本」徽标与副标题版本提示。
  AppUpdateInfo? _lastResult;

  /// 当前安装的版本号，用于副标题始终展示「当前版本 vX」。
  String? _currentVersion;

  /// 是否正在检查中，避免重复点击触发多个请求。
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // 提前拿到当前版本，副标题即可在首屏就展示版本，无需等待点击检查。
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _currentVersion = pkg.version);
    } catch (_) {
      // 取不到版本也不影响功能，副标题留空即可。
    }
  }

  Future<void> _onTap() async {
    final l10n = AppLocalizations.of(context);
    if (_checking) return;
    setState(() => _checking = true);

    // 先弹加载框，给网络请求一个明确反馈，避免界面「无反应」的错觉。
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2.5),
              const SizedBox(width: 16),
              Text(l10n.updateChecking),
            ],
          ),
        ),
      ),
    );

    try {
      // check() 已内部降级：私有仓库/网络异常都会返回 unknown 而非抛错。
      // 统一走注入的 checker（页面注入动作函数 / 测试注入桩函数）。
      final info = await widget.check();
      if (!mounted) return;
      _lastResult = info;
      // 关闭加载框后再展示结果弹窗，避免两个 dialog 叠加。
      Navigator.of(context).pop();

      await showDialog<void>(
        context: context,
        builder: (_) => UpdateDialog(
          info: info,
          // 主行动：拉起外部浏览器打开 release 页。
          // 私有仓库在浏览器登录态下可正常访问，不会报错。
          onOpenGitHub: () async {
            Navigator.of(context).pop();
            final url = info.releaseUrl ?? AppUpdateInfo.releasePageBase;
            try {
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            } catch (e) {
              // 拉起浏览器失败（极罕见），静默忽略，弹窗已关闭。
            }
          },
          // 取消/稍后/好的：直接关闭结果弹窗。
          onDismiss: () => Navigator.of(context).pop(),
        ),
      );
    } catch (e) {
      // 理论上不会到这（check 已降级），兜底关闭加载框，不向用户甩错误。
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasNew = _lastResult?.status == UpdateStatus.hasUpdate;

    // 副标题：检测到新版本时展示版本号提示，否则展示当前版本。
    final subtitle = hasNew && _lastResult!.latestVersion != null
        ? l10n.updateNewVersionHint(_lastResult!.latestVersion!)
        : (_currentVersion != null
            ? l10n.updateCurrentVersion(_currentVersion!)
            : null);

    // trailing：有更新时显示成功色「更新」胶囊；否则显示默认箭头。
    final trailing = hasNew
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SpitoutTokens.success(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.mineUpdateNow,
              style: SpitoutTextTokens.label(context).copyWith(
                color: SpitoutTokens.success(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : Icon(
            AppIcons.chevronRight,
            color: SpitoutTokens.iconTertiary(context),
          );

    return AppListTile(
      leading: AppIcons.cloudDownload,
      title: l10n.mineCheckUpdate,
      subtitle: subtitle,
      enabled: !_checking,
      trailing: trailing,
      onTap: _onTap,
    );
  }
}
