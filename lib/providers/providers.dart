// 主 providers 门面 - 统一导出所有 providers
//
// ⚠️ 护栏：本文件是 barrel（聚合导出）文件。
// 被下方 export 的子文件「禁止」import 本文件，
// 否则形成循环依赖（barrel → export 子文件 → 子文件 import barrel → 死环）。
// 子文件如需引用同 barrel 下其他符号，请直接 import 对应同级子文件。
// 新增 export 前先做符号级使用审计：新 provider 优先放入已拆分的叶子模块，
// 避免 barrel 无限膨胀。

// 主题相关（叶子模块，可安全 export）
export 'package:spitout/providers/ui/theme_providers.dart';

// 数据库相关
export 'package:spitout/providers/core/database_providers.dart';

// 首次初始化种子服务门面
export 'package:spitout/providers/core/seed_providers.dart';

// 本地设备身份相关
export 'package:spitout/providers/core/local_self_id_providers.dart';

// 记账页分类树缓存
export 'package:spitout/providers/category/category_picker_providers.dart';

// 分类模板页（模板库写入动作与类型）
export 'package:spitout/providers/category/category_template_providers.dart';

// 统计相关
export 'package:spitout/providers/statistics/statistics_providers.dart';

// 多币种相关
export 'package:spitout/providers/currency/currency_providers.dart';

// 同步相关
export 'package:spitout/providers/sync/sync_providers.dart';

// 共享账本成员/邀请 provider（含对应 DTO 类型转发）
export 'package:spitout/providers/sync/shared_ledger_providers.dart';

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

// 维护工具（孤儿数据清理 / 统计测试数据填充）
export 'package:spitout/providers/maintenance/maintenance_providers.dart';

// 语言相关
export 'package:spitout/providers/ui/language_provider.dart';

// 安全相关
export 'package:spitout/providers/security/security_providers.dart';

// 日历相关（叶子模块，可安全 export）
export 'package:spitout/providers/statistics/calendar_providers.dart';

// 记录编辑历史
export 'package:spitout/providers/statistics/record_history_providers.dart';

// 应用更新检查动作函数（checkAppUpdate）
export 'package:spitout/providers/ui/update_check_providers.dart';

// 公共导出目录动作函数（resolveExportDir / requestPublicExportDirAccess）
export 'package:spitout/providers/import_export/public_export_dir_providers.dart';

// AA 分摊(统计 + 虚拟用户管理 + 账本开关)
export 'package:spitout/providers/statistics/aa_statistics_providers.dart';

// provider.future 首值读取工具（UI 层经本门面统一使用）
export 'package:spitout/providers/core/read_provider_future.dart';
