import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'package:spitout/providers/ui/avatar_providers.dart';
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/providers/ui/theme_providers.dart';
import '../core/logging/logger_service.dart';
import '../theme/typography.dart';
import '../theme/icons/app_icons.dart';
import 'avatar_preview_page.dart';
import 'spitout_icon.dart';
import 'toast.dart';

/// 我的页头部：居中头像（上）+ 昵称（下），点击头像全屏预览，点击昵称编辑。
class MinePageHeader extends ConsumerStatefulWidget {
  const MinePageHeader({super.key});

  @override
  ConsumerState<MinePageHeader> createState() => _MinePageHeaderState();
}

class _MinePageHeaderState extends ConsumerState<MinePageHeader> {
  // 本地 optimistic override：用户自己刚选完图片时立刻更新到这里，配合 setState
  // 让 UI 零延迟响应。首次加载由 build 中 ref.watch(avatarPathProvider) 驱动
  // （avatarPathProvider 本身是包了 getAvatarPath() 的 FutureProvider）；
  // _avatarPath 只在 provider 重载完成的间隙做乐观覆盖，渲染时 provider 值优先。
  String? _avatarPath;

  /// 点击头像 → 全屏预览（无论有无头像均进入）。
  ///
  /// 设计意图：头像点击聚焦到「看大图」这一个动作。
  /// 无头像时全屏显示品牌图标占位；有头像时显示圆形大图。
  /// 全屏页底部提供「上传新头像」按钮（直接拉起相册）和「删除头像」按钮（仅有
  /// 头像时显示，直接删除），来源选择直接在按钮操作内完成，不弹 BottomSheet。
  Future<void> _showAvatarPreview() async {
    final avatarAsync = ref.read(avatarPathProvider);
    final path = avatarAsync.asData?.value ?? _avatarPath;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvatarPreviewPage(
          avatarPath: path,
          uploadLabel: l10n.mineAvatarUploadNew,
          // 上传回调：先关闭预览页，再直接拉起系统相册选择
          onUpload: _onUploadAvatar,
          // 删除按钮 + 回调仅在有头像时提供
          deleteLabel: path != null ? l10n.mineAvatarDelete : null,
          onDelete: path != null ? _onDeleteAvatar : null,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// 预览页「上传新头像」回调：先关闭全屏预览页，再直接拉起系统相册选择。
  ///
  /// 从全屏预览页直接拉起系统相册，无中间弹窗——
  /// 用户在全屏页点「上传新头像」即直接进入系统相册。
  void _onUploadAvatar() {
    Navigator.of(context).pop(); // 关闭全屏预览页
    _pickAvatarFromGallery();
  }

  /// 预览页「删除头像」回调：先关闭全屏预览页，再直接删除本地头像。
  ///
  /// 从全屏预览页直接执行删除，无中间弹窗——
  /// 用户在全屏页点「删除头像」即直接删除本地头像。
  void _onDeleteAvatar() {
    Navigator.of(context).pop(); // 关闭全屏预览页
    _deleteAvatar();
  }

  /// 从系统相册选择并保存头像。
  ///
  /// 成功后乐观更新本地 [_avatarPath] 并 invalidate provider 让全局生效；
  /// 云同步走 [_syncAvatarToCloud]，失败不阻塞本地使用。
  Future<void> _pickAvatarFromGallery() async {
    try {
      final path = await pickAndSaveAvatarFromUi(ref);
      if (mounted && path != null) {
        setState(() => _avatarPath = path);
        ref.invalidate(avatarPathProvider);
        await _syncAvatarToCloud(path);
      }
    } catch (e) {
      if (!mounted) return;
      showToast(context, '${AppLocalizations.of(context).commonError}: $e');
    }
  }

  /// 删除头像：先删云端，再删本地。
  ///
  /// 顺序很关键 —— 必须先确认服务端真正删掉（途径一 DELETE /api/v1/profile/avatar），
  /// 再清本地缓存。若反过来先删本地、云端请求又失败，下一次周期 pull 时服务端仍
  /// 保留着更高版本头像会被重新下载回来，形成"删了又回来"。云端删除失败时本地
  /// 保持不动并提示重试，宁可用户看到头像还在，也不能被回灌。
  Future<void> _deleteAvatar() async {
    try {
      // 1) 先真正发出云端删除请求（核心：必须发出，否则服务端头像删不掉）
      await _deleteAvatarFromCloud();
      // 2) 云端确认删除成功后，再清本地缓存，用户本地视角才最终消失
      await deleteAvatarFromUi(ref);
      if (mounted) {
        setState(() => _avatarPath = null);
        ref.invalidate(avatarPathProvider);
      }
    } catch (e) {
      if (!mounted) return;
      // 云端删除未成功：本地不动，避免服务端头像被周期 pull 回灌；提示用户重试
      showToast(context, '${AppLocalizations.of(context).commonError}: $e');
    }
  }

  /// 删除 Spitout Cloud 服务端头像（走 DELETE /api/v1/profile/avatar）。
  ///
  /// WebDAV/Supabase 模式直接返回(无云端头像);Spitout Cloud 模式下删除失败向上抛出,
  /// 由 [_deleteAvatar] 统一兜底(云端没删成功就别清本地,避免头像被周期 pull 回灌)。
  Future<void> _deleteAvatarFromCloud() async {
    final providerInstance =
        await ref.read(spitoutCloudProviderInstance.future);
    if (providerInstance == null) {
      // 非 Spitout Cloud 模式（WebDAV/Supabase）无云端头像,直接返回
      return;
    }
    await providerInstance.deleteMyAvatar();
  }

  /// 头像同步到 Spitout Cloud（走 /api/v1/profile/avatar）。
  /// 失败仅记日志，不阻塞用户使用本地头像；WebDAV/Supabase 场景跳过。
  Future<void> _syncAvatarToCloud(String absolutePath) async {
    try {
      final providerInstance =
          await ref.read(spitoutCloudProviderInstance.future);
      if (providerInstance == null) {
        logger.debug('avatar_sync', '非 Spitout Cloud 模式，跳过头像云同步');
        return;
      }
      final file = File(absolutePath);
      if (!file.existsSync()) {
        logger.warning(
            'avatar_sync', 'upload skipped: file missing $absolutePath');
        return;
      }
      final bytes = await file.readAsBytes();
      final name = absolutePath.split('/').last;
      logger.info('avatar_sync',
          'upload start path=$absolutePath size=${bytes.length}B');
      final result = await providerInstance.uploadMyAvatar(
        bytes: bytes,
        fileName: name,
        mimeType:
            name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
      );
      // 上传成功后把本地 remoteVersion 立刻推到 server 的新版本，避免下一次
      // bootstrap 再触发一次重新下载自己刚传的头像。
      await setStoredAvatarRemoteVersion(ref, result.avatarVersion);
      logger.info('avatar_sync',
          'upload done server_version=${result.avatarVersion} url=${result.avatarUrl}');
    } catch (e, st) {
      logger.warning('avatar_sync', 'upload failed (non-blocking): $e', st);
    }
  }

  /// 按本地时段返回问候语 + 配图(太阳/月亮)+ 图标色:5-11 早 / 11-13 午 /
  /// 13-18 下午 / 18-23 晚 / 23-5 夜。白天用太阳(暖色 amber→orange),晚上 / 夜里
  /// 用月亮(violet / indigo);图标色不随主题变。
  ({String text, IconData icon, Color color}) _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) {
      return (
        text: l10n.mineGreetingMorning,
        icon: AppIcons.twilight,
        color: const Color(0xFFF59E0B),
      );
    }
    if (h >= 11 && h < 13) {
      return (
        text: l10n.mineGreetingNoon,
        icon: AppIcons.lightMode,
        color: const Color(0xFFF59E0B),
      );
    }
    if (h >= 13 && h < 18) {
      return (
        text: l10n.mineGreetingAfternoon,
        icon: AppIcons.lightMode,
        color: const Color(0xFFF97316),
      );
    }
    if (h >= 18 && h < 23) {
      return (
        text: l10n.mineGreetingEvening,
        icon: AppIcons.nightlight,
        color: const Color(0xFF8B5CF6),
      );
    }
    return (
      text: l10n.mineGreetingNight,
      icon: AppIcons.nightlight,
      color: const Color(0xFF818CF8),
    );
  }

  /// 编辑用户昵称。保存写入 displayNameProvider —— 本地持久化与(仅 Spitout
  /// Cloud 模式)云推送由 provider 的 listener 自动完成。v1 不支持清空已设昵称:
  /// trim 为空则不改动。
  ///
  /// controller 由弹窗 [_EditDisplayNameDialog] 自己持有/释放,不在本异步方法里
  /// `finally { controller.dispose() }` —— 否则取消时弹窗退场动画未结束、TextField
  /// 仍挂载就释放 controller，会触发 "used after disposed" 红屏。
  Future<void> _showEditDisplayName() async {
    final current = ref.read(displayNameProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditDisplayNameDialog(initial: current),
    );
    if (result == null || !mounted) return;
    final name = result.trim();
    if (name.isEmpty || name == current) return; // v1 不清空；无变化不写
    ref.read(displayNameProvider.notifier).state = name;
    showToast(context, AppLocalizations.of(context).mineDisplayNameSaved);
  }

  @override
  Widget build(BuildContext context) {
    // 监听云同步写下来的头像路径：当 SyncEngine.syncMyProfile 从服务端拉到
    // 新头像并 bump avatarRefreshProvider 时，这里自动拿到新值，无需手动刷新。
    // 优先级：云同步路径 > 本地 optimistic (_avatarPath)。
    final avatarAsync = ref.watch(avatarPathProvider);
    final effectiveAvatarPath = avatarAsync.asData?.value ?? _avatarPath;

    final displayName = ref.watch(displayNameProvider);
    final l10n = AppLocalizations.of(context);
    final greeting = _greeting(l10n);
    // 昵称作为"我的"tab 首行文字，字号为 SpitoutTextTokens.title(15)，
    // 与全局首行文字大小一致；保留居中显示与点击编辑交互。
    final nameStyle = SpitoutTextTokens.title(context);
    // 已设置=「问候，昵称」(与 web 一致)，未设置=mineSlogan。
    final headerText = displayName.isNotEmpty
        ? l10n.mineGreetingNamed(greeting.text, displayName)
        : l10n.mineSlogan;

    return Padding(
      // 居中布局：头像在上、昵称在下，整体左右居中。
      // 顶部留白交由 PrimaryHeader 默认 padding（all(8)）统一控制，
      // 此处不叠加，保证"我的"tab 首行（头像）顶距与其余 tab 一致。
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 14.0),
      // SizedBox(width: double.infinity) 强制 Column 占满可用宽度，
      // 使 CrossAxisAlignment.center 能真正水平居中子项；
      // 否则 Scaffold body 给的是 loose 约束，Column 会收缩到子项宽度。
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 头像：点击进入全屏预览（无论有无头像均进入）。
            // 尺寸 88x88，圆形裁切，带边框。
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(44),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _showAvatarPreview,
                borderRadius: BorderRadius.circular(44),
                child: Container(
                  width: 88.0,
                  height: 88.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    // 首次加载用 avatarPathProvider 的 loading 态驱动 spinner：
                    // 删除 _loadAvatar 后无独立 loading 状态，FutureProvider 已自带。
                    child: avatarAsync.isLoading
                        ? Center(
                            child: SizedBox(
                              width: 22.0,
                              height: 22.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : (effectiveAvatarPath != null
                            ? Image.file(
                                // key 加入 path：Flutter 以 (File ,key) 区分不同图片，
                                // 否则从 A.jpg 换到 B.jpg（路径不同但 widget 复用）
                                // 有时仍显示缓存的 A。
                                key: ValueKey(effectiveAvatarPath),
                                File(effectiveAvatarPath),
                                fit: BoxFit.cover,
                                errorBuilder: (context , error , stackTrace) =>
                                    const SpitoutIcon(size: 44.0),
                              )
                            : const SpitoutIcon(size: 44.0)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14.0),
            // 昵称行：居中显示，单行省略。点击直接编辑。
            // 时段图标仅在已设置昵称时出现。
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _showEditDisplayName,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (displayName.isNotEmpty) ...[
                        Icon(greeting.icon, size: 20.0, color: greeting.color),
                        const SizedBox(width: 6.0),
                      ],
                      Flexible(
                        child: Text(
                          headerText,
                          style: nameStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 昵称编辑弹窗。独立 StatefulWidget 自己持有 controller、在 dispose() 释放，
/// 把 controller 的生命周期绑到弹窗本身 —— 弹窗(含 TextField)整棵子树卸载后
/// 才释放，彻底规避调用方在退场动画期间提前 dispose 造成的 "used after disposed"。
class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mineDisplayNameEditTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: l10n.mineDisplayNameHint),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(context, v);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final canSave = value.text.trim().isNotEmpty;
            return TextButton(
              onPressed: canSave
                  ? () => Navigator.pop(context, _controller.text)
                  : null,
              child: Text(l10n.commonSave),
            );
          },
        ),
      ],
    );
  }
}
