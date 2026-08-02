import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/providers.dart';

import '../l10n/app_localizations.dart';
import 'app_dialog.dart';

/// 公共 Download 写入前的权限引导（导出配置 / 导出明细 CSV / 手动备份共用）。
///
/// 位置说明：本流程需要弹 AppDialog，属 UI 交互编排，位于 widgets/ 层；
/// utils 层只保留纯函数工具。
///
/// 设计意图：
/// - Android 11+ 作用域存储下，写公共 Download 需用户手动授予「所有文件访问」，
///   该授权只能跳系统设置页完成，无法静默弹框，故必须在用户主动点击导出/备份
///   时引导一次，而不是在后台任务（自动备份）里打扰；
/// - 探测到目录可写（已授权或低版本系统）时零打扰直接通过；
/// - 未授权时给出两个选择：跳设置授权，或继续走应用专属降级目录——
///   两条路径都允许流程继续，保证功能在任何授权状态下可用。
///
/// 返回解析后的公共导出目录；返回 `null` 表示不可继续（页面已销毁中止，
/// 或外部存储整体不可用），调用方应中止后续写入。
///
/// 分层说明：经 [resolveExportDir] / [requestPublicExportDirAccess] 动作函数
/// 走 providers 层，本 helper 不直接触碰 services 层（单向依赖）。
Future<PublicExportDir?> ensureExportDirAccess(
  BuildContext context,
  WidgetRef ref,
) async {
  // 非 Android 平台无「公共 Download」授权流程：外部存储不可用时
  // 返回 null（由调用方各自平台分支决定降级策略）。
  if (!Platform.isAndroid) return null;
  final resolved = await resolveExportDir(ref);
  // resolved 为 null（外部存储不可用）时不在此拦截：
  // 后续实际写入会抛异常，由调用方统一的错误弹窗如实反馈
  if (resolved == null || resolved.isPublicDownload) return resolved;
  if (!context.mounted) return null;

  final l10n = AppLocalizations.of(context);
  final goGrant = await AppDialog.confirm<bool>(
    context,
    title: l10n.storagePermissionTitle,
    message: l10n.storagePermissionMessage,
    okLabel: l10n.storagePermissionGrant,
    cancelLabel: l10n.storagePermissionContinue,
  );
  if (goGrant == true) {
    // 跳系统设置页/弹权限框；用户返回后由后续 resolve 重新探测，
    // 即使最终未授权也会自动走降级目录，无需在此重复确认
    await requestPublicExportDirAccess(ref);
  }
  return context.mounted ? await resolveExportDir(ref) : null;
}
