// 头像全屏预览页。
//
// 设计意图：
//   1. 无论有无头像，点击头像均进入全屏预览；无头像时显示品牌图标大图。
//   2. 单点屏幕任意空白区域可收起（GestureDetector + Navigator.pop）。
//   3. 底部操作条：
//      - 始终显示「上传新头像」按钮，点击直接拉起系统相册选择。
//      - 有头像时额外显示「删除头像」按钮，点击直接删除本地头像。
//   4. 左上角保留关闭按钮，作为明确的退出入口。
//
// 抽到独立文件便于 Widget 测试；只持有 UI 状态，业务回调（上传、删除、关闭）
// 由调用方注入，保持组件纯净。
import 'dart:io';

import 'package:flutter/material.dart';

import 'spitout_icon.dart';

/// 头像全屏预览页。
///
/// - 纯黑背景 + 居中圆形大图（有头像）或品牌图标（无头像）。
/// - 单点屏幕任意空白处可收起（关闭当前路由）。
/// - 左上角关闭按钮（参考图位置，非右上）。
/// - 底部操作按钮：始终显示上传新头像，有头像时额外显示删除头像。
///
/// [avatarPath] 头像本地文件绝对路径；为 null 表示无头像，全屏显示品牌图标。
/// [uploadLabel] 上传按钮文案。
/// [onUpload] 点击上传按钮触发，调用方负责关闭本页并拉起系统相册选择。
/// [deleteLabel] 删除按钮文案；为 null 时不显示删除按钮。
/// [onDelete] 点击删除按钮触发，调用方负责关闭本页并删除本地头像。
class AvatarPreviewPage extends StatelessWidget {
  const AvatarPreviewPage({
    super.key,
    this.avatarPath,
    required this.uploadLabel,
    required this.onUpload,
    this.deleteLabel,
    this.onDelete,
  });

  final String? avatarPath;
  final String uploadLabel;
  final VoidCallback onUpload;
  final String? deleteLabel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath != null;
    return Scaffold(
      backgroundColor: Colors.black,
      // 外层 GestureDetector(opaque) 承接所有空白区域的单点收起手势；
      // 子 Stack 中的 InkWell（上传/删除按钮、关闭按钮）会赢得手势竞技场，
      // 因此只有点空白处才会触发 pop。
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // 居中：有头像显示圆形大图（支持双指缩放查看细节），无头像显示品牌图标
            Center(
              child: hasAvatar
                  ? ClipOval(
                      child: SizedBox(
                        width: 280,
                        height: 280,
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.file(
                            File(avatarPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              size: 80,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    )
                  // 无头像：全屏展示品牌图标占位
                  : const SpitoutIcon(size: 120.0),
            ),
            // 左上角关闭 X（参考图位置，非右上）
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                  ),
                ),
              ),
            ),
            // 底部操作按钮组：上传新头像（始终）+ 删除头像（仅有头像时）
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AvatarActionPill(
                      label: uploadLabel,
                      icon: Icons.photo_library_outlined,
                      onTap: onUpload,
                    ),
                    // 删除按钮仅在有头像且调用方提供了回调时显示
                    if (hasAvatar &&
                        onDelete != null &&
                        deleteLabel != null) ...[
                      const SizedBox(height: 12),
                      _AvatarActionPill(
                        label: deleteLabel!,
                        icon: Icons.delete_outline,
                        onTap: onDelete!,
                        danger: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作药丸条：圆角半透明背景 + 左文案右图标，整体可点。
///
/// [danger] 为 true 时文案与图标用红色，用于删除等危险操作。
class _AvatarActionPill extends StatelessWidget {
  const _AvatarActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : Colors.white;
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
