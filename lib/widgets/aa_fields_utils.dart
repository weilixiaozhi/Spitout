import 'dart:convert';

import '../core/logging/logger_service.dart';

/// AA 分摊字段统一工具。
///
/// 解析 / 序列化 aaParticipants / aaSplits 原先在交易编辑、AA 快捷编辑、
/// 详情页三处各维护一份，口径漂移风险高；收敛到这里后所有调用方共享同一份
/// 实现（空值语义、失败兜底、编辑模式清空语义只定义一次）。

/// 解析 aaParticipants（JSON 数组字符串）为参与人标识列表。
///
/// 空 / 解析失败返回 null（语义：全部成员运行时展开）。
List<String>? parseAaParticipantIds(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    return (jsonDecode(json) as List).map((e) => e.toString()).toList();
  } catch (e, st) {
    logger.warning('AaFields', '解析 aaParticipants 失败', '$e\n$st');
    return null;
  }
}

/// 解析 aaSplits（JSON 对象字符串）为 参与人标识 → 金额字符串 映射。
///
/// 空 / 解析失败返回 null。
Map<String, String>? parseAaSplits(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final obj = jsonDecode(json) as Map<String, dynamic>;
    return {for (final e in obj.entries) e.key: e.value.toString()};
  } catch (e, st) {
    logger.warning('AaFields', '解析 aaSplits 失败', '$e\n$st');
    return null;
  }
}

/// 组装 aaParticipants 落库值。
///
/// updateTransaction 的 aa* 参数 null = 不更新，因此编辑模式从「部分参与人 /
/// 指定分摊」切到「全部成员 / 不分摊」时必须显式写空串清空旧值；新建模式
/// 没有旧值可清，写 null（落库层默认）。
String? aaParticipantsJsonForWrite(
  List<String>? participants, {
  required bool isEditing,
}) {
  if (participants == null) return isEditing ? '' : null;
  return jsonEncode(participants);
}

/// 组装 aaSplits 落库值，清空语义与 [aaParticipantsJsonForWrite] 一致。
String? aaSplitsJsonForWrite(
  Map<String, String>? splits, {
  required bool isEditing,
}) {
  if (splits == null) return isEditing ? '' : null;
  return jsonEncode(splits);
}

/// 共享账本 Editor 视角下 AA 快捷编辑的 category_id 落库值。
///
/// synthetic override 存在时 categoryId 必须留 null（与编辑器主路径一致），
/// 避免把 synthetic 负数 id 写进共享账本交易的 category_id，造成主表 JOIN
/// 不到 / 孤儿扫描误报的悬空引用。
int? aaEditCategoryIdForWrite({
  required int? categoryId,
  required String? categorySyncIdOverride,
}) {
  return categorySyncIdOverride != null ? null : categoryId;
}
