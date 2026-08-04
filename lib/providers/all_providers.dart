// ────────────────────────────────────────────────────────────────
// ⚠️ 护栏：本文件是 barrel（聚合导出）文件。
// 被下方 export 的子文件「禁止」import 本文件（或上层 providers.dart），
// 否则形成循环依赖（barrel → export 子文件 → 子文件 import barrel → 死环）。
// 子文件如需引用同 barrel 下其他符号，请直接 import 对应同级子文件。
// ────────────────────────────────────────────────────────────────
// 统一的providers导出文件，方便统一导入所有providers

// 主题相关（已去自引用，可安全 export）
export 'package:spitout/providers/ui/theme_providers.dart';

// 数据库相关  
export 'package:spitout/providers/core/database_providers.dart';

// 记账页分类树缓存
export 'package:spitout/providers/category/category_picker_providers.dart';

// 统计相关
export 'package:spitout/providers/statistics/statistics_providers.dart';

// 多币种相关
export 'package:spitout/providers/currency/currency_providers.dart';

// 同步相关
export 'package:spitout/providers/sync/sync_providers.dart';

// 云同步操作门面（UI 不直接触碰 SyncEngine / SyncService 内部实现）
export 'package:spitout/providers/sync/spitout_cloud_sync_actions.dart';

// App 启动同步收敛器
export 'package:spitout/providers/sync/app_startup_sync.dart';

// UI状态相关
export 'package:spitout/providers/ui/ui_state_providers.dart';

// 导入导出相关
export 'package:spitout/providers/import_export/import_export_providers.dart';

// 提醒相关
export 'package:spitout/providers/reminder/reminder_providers.dart';

// 语言相关
export 'package:spitout/providers/ui/language_provider.dart';

// 安全相关
export 'package:spitout/providers/security/security_providers.dart';

// 日历相关（已去自引用，可安全 export）
export 'package:spitout/providers/statistics/calendar_providers.dart';

// 记录编辑历史
export 'package:spitout/providers/statistics/record_history_providers.dart';

// 应用更新检查动作函数（checkAppUpdate）
export 'package:spitout/providers/ui/update_check_providers.dart';

// 公共导出目录动作函数（resolveExportDir / requestPublicExportDirAccess）
export 'package:spitout/providers/import_export/public_export_dir_providers.dart';

// AA 分摊(统计 + 虚拟用户管理 + 账本开关)
export 'package:spitout/providers/statistics/aa_statistics_providers.dart';