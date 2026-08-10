/// 应用更新检查的 providers 层动作函数。
///
/// 设计意图：把「检查更新」的 service 调用收敛到 providers 层，
/// widgets 层（CheckUpdateTile）不直接 import
/// `services/update/app_update_service.dart`，而是由页面（MinePage）
/// 通过 [checkAppUpdate] 以回调注入的方式传入——依赖方向保持
/// `pages/widgets → providers → services → data` 单向流动。
///
/// 返回的 [AppUpdateInfo] 类型来自 data 层门面 `data/models.dart`，
/// 不在此处 re-export service 的任何符号（共识④：不建第二个出口）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/data/models.dart';
import 'package:spitout/services/update/app_update_service.dart';

/// 检查应用更新（动作函数，WidgetRef 为参）。
///
/// 设计意图：service 的 `AppUpdateService.check` 需要真实网络与
/// package_info_plus 平台通道，不适合作为纯 provider 依赖（难以测试且
/// 无需缓存）。这里以动作函数形式收敛调用点，UI 点击时才真正触发。
Future<AppUpdateInfo> checkAppUpdate(WidgetRef ref) =>
    AppUpdateService.check();
