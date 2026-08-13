// ────────────────────────────────────────────────────────────────
// ⚠️ 护栏：本文件是 barrel（聚合导出）文件。
// 被下方 export 的子文件「禁止」import 本文件，
// 否则形成循环依赖（barrel → export 子文件 → 子文件 import barrel → 死环）。
// 子文件如需引用同 barrel 下其他符号，请直接 import 对应同级子文件。
// 新增 export 前先做符号级使用审计：只导出确实经 barrel 被消费的符号，
// 直接 import 消费的组件不应进入 barrel。
// ────────────────────────────────────────────────────────────────

// ===== 基础通用组件 =====
export 'app_empty.dart';
export 'person_avatar.dart';
export 'app_list_tile.dart';
export 'app_sheet.dart';
export 'app_dialog.dart';
export 'app_route.dart';
export 'day_section_header.dart';
export 'primary_header.dart';
export 'section_card.dart';
export 'skeleton.dart';
export 'swipe_hint.dart';
export 'capsule_switcher.dart';
export 'toast.dart';
export 'spitout_icon.dart';
export 'spitout_popup_menu.dart';
export 'storage_permission_helper.dart';

// ===== 金额 / 数字 / 键盘 =====
export 'amount_text.dart';
export 'format_money.dart';
export 'amount_input_panel.dart';
export 'keypad_constants.dart';
export 'pin_entry_pad.dart';
export 'press_key.dart';

// ===== 时间选择 =====
export 'wheel_picker.dart';
export 'wheel_date_picker.dart';
export 'wheel_time_picker.dart';

// ===== 分类相关 =====
export 'category_icon.dart';
export 'category_selector_dialog.dart';
export 'category_grid_section.dart';

// ===== 账本相关 =====
export 'ledger_card.dart';
export 'ledger_selector_dialog.dart';
export 'ledger_currency_change.dart';
export 'cloud_service_entry_tile.dart';

// ===== 共享账本成员协作 =====
export 'member_management_section.dart';
export 'member_stats_section.dart';

// ===== 货币相关 =====
export 'currency_flag.dart';
export 'currency_picker_sheet.dart';

// ===== 统计图表 =====
export 'line_chart.dart';
export 'category_donut_chart.dart';
export 'category_rank_row.dart';

// ===== 交易记录列表 =====
export 'transaction_list.dart';
export 'transaction_list_item.dart';
export 'transaction_detail_sheet.dart';

// ===== 记账编辑 =====
export 'transaction_editor_sheet.dart';
export 'transaction_editor_sheet_entry.dart';
export 'transaction_edit_utils.dart';
export 'transaction_aa_edit_utils.dart';

// ===== AA 分摊 =====
export 'aa_participant_avatar.dart';
export 'aa_payer_picker_sheet.dart';

// ===== 账号 / 登录 / 安全 =====
export 'mine_page_header.dart';
