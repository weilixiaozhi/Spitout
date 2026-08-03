// ────────────────────────────────────────────────────────────────
// ⚠️ 护栏：本文件是 barrel（聚合导出）文件。
// 被下方 export 的子文件「禁止」import 本文件，
// 否则形成循环依赖（barrel → export 子文件 → 子文件 import barrel → 死环）。
// 子文件如需引用同 barrel 下其他符号，请直接 import 对应同级子文件。
// ────────────────────────────────────────────────────────────────

// ===== 基础通用组件 =====
export 'app_empty.dart';
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
export 'overlay_keyboard_guard.dart';
export 'spitout_icon.dart';
export 'spitout_popup_menu.dart';
export 'storage_permission_helper.dart';

// ===== 金额 / 数字 / 键盘 =====
export 'amount_text.dart';
export 'format_money.dart';
export 'amount_expression_bar.dart';
export 'amount_keypad.dart';
export 'keypad_layout.dart';
export 'pin_entry_pad.dart';

// ===== 时间选择 =====
export 'wheel_picker.dart';
export 'wheel_date_picker.dart';
export 'wheel_time_picker.dart';

// ===== 通用下拉 / 选择 =====
export 'searchable_dropdown.dart';

// ===== 分类相关 =====
export 'category_icon.dart';
export 'category_selector_dialog.dart';
export 'category_grid_item.dart';
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
export 'note_input_row.dart';

// ===== AA 分摊 =====
export 'aa_mode_picker_sheet.dart';
export 'aa_participant_picker_sheet.dart';
export 'virtual_user_manage_sheet.dart';

// ===== 账号 / 登录 / 安全 =====
export 'login_2fa_challenge_view.dart';
export 'avatar_preview_page.dart';
export 'mine_page_header.dart';
export 'collaborator_avatar.dart';

// ===== 更新 =====
export 'update_dialog.dart';
export 'check_update_tile.dart';
