import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'keypad_constants.dart';

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
        // 行高由父级键盘容器按剩余空间算好并锁定，stretch 让输入框填满整行
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 备注输入框
          // max 20 字、单行省略
          Expanded(
            // 圆角由 ClipRRect 显式跟随 KeypadLayout.keyRadius，
            // 不依赖 InputDecoration 的 fill 绘制路径
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KeypadLayout.keyRadius),
              child: ColoredBox(
                color: SpitoutTokens.keyDigit(context),
                child: TextField(
                  focusNode: noteFocusNode,
                  controller: noteController,
                  maxLength: 20,
                  maxLines: 1,
                  minLines: 1,
                  // 行高随键盘容器伸缩时，输入内容保持垂直居中
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(color: SpitoutTokens.textPrimary(context)),
                  decoration: InputDecoration(
                    counterText: '', // 隐藏 maxLength 计数器
                    hintText: AppLocalizations.of(context).commonNoteHint,
                    hintStyle: TextStyle(
                      color: SpitoutTokens.textTertiary(context),
                    ),
                    isDense: true,
                    // 显式关闭主题 InputDecorationTheme 的 filled 继承，
                    // 背景只由外层 ClipRRect + ColoredBox 绘制，避免出现
                    // "白色块里再套一层灰块"的双层圆角。
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SpitoutDimens.p12,
                      vertical: 5,
                    ),
                    // 清空按钮（后缀）：CircleX 图标，仅备注非空时显示。
                    // 用 ValueListenableBuilder 监听 controller 自身，输入变化时
                    // 按钮即时出现/消失，不依赖父层是否重建本组件。
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: noteController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () => onNotePicked(''),
                          child: Icon(
                            AppIcons.cancel,
                            size: SpitoutDimens.icon16,
                            color: SpitoutTokens.iconSecondary(context),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 无旗标入口（不含 excludeFromStats 功能）
        ],
      ),
    );
  }
}
