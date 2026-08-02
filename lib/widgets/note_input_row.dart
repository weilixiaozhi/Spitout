import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/icons/app_icons.dart';

/// 备注输入行：输入框 + CircleX 清空（后缀）。
///
/// - 备注 max 20 字、单行省略。
/// - 右侧 CircleX 清除备注（仅备注非空时显示）。
/// - 无旗标入口（不含 excludeFromStats 功能）。
/// - maxLength 固定为 20。
/// - 清空按钮图标用 AppIcons.cancel（对应设计 CircleX）。
/// - 不含历史备注选择器（NotePickerDialog）入口。
class NoteInputRow extends ConsumerWidget {
  final TextEditingController noteController;
  final FocusNode noteFocusNode;

  // 备注选中后回填（由父 sheet 重建驱动，清空按钮也复用此回调）
  final ValueChanged<String> onNotePicked;

  const NoteInputRow({
    super.key,
    required this.noteController,
    required this.noteFocusNode,
    required this.onNotePicked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 水平方向不设 padding，由外层 Padding 统一控制左右对齐
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // 备注输入框
          // max 20 字、单行省略
          Expanded(
            child: TextField(
              focusNode: noteFocusNode,
              controller: noteController,
              maxLength: 20,
              maxLines: 1,
              minLines: 1,
              style: TextStyle(color: SpitoutTokens.textPrimary(context)),
              decoration: InputDecoration(
                counterText: '', // 隐藏 maxLength 计数器
                hintText: AppLocalizations.of(context).commonNoteHint,
                hintStyle:
                    TextStyle(color: SpitoutTokens.textTertiary(context)),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: SpitoutTokens.surfaceInput(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                // 清空按钮（后缀）：CircleX 图标，仅备注非空时显示
                suffixIcon: noteController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => onNotePicked(''),
                        child: Icon(
                          AppIcons.cancel,
                          size: 18,
                          color: SpitoutTokens.iconSecondary(context),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          // 无旗标入口（不含 excludeFromStats 功能）
        ],
      ),
    );
  }
}
