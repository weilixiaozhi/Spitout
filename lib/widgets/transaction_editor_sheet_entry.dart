import 'package:flutter/material.dart';

import 'app_route.dart';
import 'transaction_editor_sheet.dart';

/// 弹出记账编辑 BottomSheet（单页:分类 + 金额 + 备注同页）。
///
/// 设计意图:金额输入与分类选择在同一个 BottomSheet 内完成,互不阻塞;
/// 系统键盘拉起时整页保持可见并上移,仅把备注 / 币种行顶到键盘之上,
/// 不收起分类区。
///
/// [initialKind] 值固定为 'expense'（全局仅支出模式）。
/// 传入 [editingTransactionId] 即为编辑模式,会按初始值回显。
///
/// AA 分摊初值(initialAaMode/initialAaParticipants/initialAaSplits/
/// initialPaidByUserId)仅编辑模式回填;新建交易传 null 即默认
/// 人均分摊 / 全部成员,支出人由落库层回填操作者。
Future<void> showTransactionEditorSheet(
  BuildContext context, {
  String initialKind = 'expense',
  int? editingTransactionId,
  int? initialCategoryId,
  double? initialAmount,
  DateTime? initialDate,
  String? initialNote,
  String? initialCurrencyCode,
  double? initialNativeAmount,
  int? initialAaMode,
  List<String>? initialAaParticipants,
  Map<String, String>? initialAaSplits,
  String? initialPaidByUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // useSafeArea: true —— sheet 顶部正好顶到状态栏下面(SafeArea 自动计算
    // 各机型安全区,无需手动捕获/传入状态栏高度,避免不同手机效果不一致)。
    // 同时去掉遮罩(barrierColor 透明):顶部状态栏区域透出下层页面,不再有
    // 半透明黑雾遮罩。
    useSafeArea: true,
    // 去掉遮罩:sheet 从状态栏下沿开始铺到屏幕底,顶部无 sheet 背景覆盖,
    // 遮罩若保留会在状态栏区域透出半透明黑雾。
    barrierColor: Colors.transparent,
    // 透明背景:圆角容器自行绘制,避免双层底色
    backgroundColor: Colors.transparent,
    // 全局统一上滑动画：线性曲线（无加速减速），时长与页面切换一致。
    sheetAnimationStyle: kSheetAnimationStyle,
    builder: (context) => TransactionEditorSheet(
      initialKind: initialKind,
      editingTransactionId: editingTransactionId,
      initialCategoryId: initialCategoryId,
      initialAmount: initialAmount,
      initialDate: initialDate,
      initialNote: initialNote,
      initialCurrencyCode: initialCurrencyCode,
      initialNativeAmount: initialNativeAmount,
      initialAaMode: initialAaMode,
      initialAaParticipants: initialAaParticipants,
      initialAaSplits: initialAaSplits,
      initialPaidByUserId: initialPaidByUserId,
    ),
  );
}

