/// 公共导出目录的 providers 层动作函数。
///
/// 设计意图：把 `PublicExportDirService` 的调用收敛到 providers 层，
/// widgets 层（storage_permission_helper）不直接 import services。
/// 依赖方向保持 `pages/widgets → providers → services → data` 单向流动。
///
/// 共识①（PublicExportDir 禁缓存）：这里刻意提供**动作函数**而非
/// FutureProvider——`resolve()` 是时序敏感的能力探测（试写探针文件），
/// 用户从系统设置授权返回后必须实时重测；若套缓存 provider，
/// 授权后仍会读到 stale 结果，导致已授权用户被重复引导。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/system/public_export_dir_service.dart';

// 类型经 providers 门面 re-export：UI 层从 providers.dart 获取 PublicExportDir，
// 无需（也不允许）直接 import service（共识④：service 不留第二出口给 UI）。
export 'package:spitout/services/system/public_export_dir_service.dart'
    show PublicExportDir;

/// 实时解析公共导出目录（动作函数，不缓存）。
///
/// 每次调用都重新执行能力探测（试建目录 + 试写探针），确保授权状态
/// 变化后（如用户刚从系统设置返回）拿到的始终是最新结果。
Future<PublicExportDir?> resolveExportDir(
  WidgetRef ref, {
  String? subDir,
}) =>
    const PublicExportDirService().resolve(subDir: subDir);

/// 引导用户授予公共 Download 写权限（动作函数）。
///
/// 仅负责拉起系统权限流程（API ≤ 29 弹框 / API 30+ 跳设置页），
/// 授权结果由后续 [resolveExportDir] 重新探测判定，不做状态查询。
Future<void> requestPublicExportDirAccess(WidgetRef ref) =>
    const PublicExportDirService().requestAccess();
