import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/data/models.dart' as db;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'category_icon.dart';
import 'package:spitout/utils/currency/currencies.dart';
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/ui/theme_providers.dart' show expenseColorSchemeProvider;
import 'package:spitout/providers/providers.dart' show SpitoutCloudLedgerMember;
import 'collaborator_avatar.dart';
import 'amount_text.dart';

/// 单条交易列表项（紧凑双行布局）。
///
/// 视觉规范:
/// - 分类图标:36×36 圆形,secondary 底 + primary 图标
/// - 第一行:分类名(主文字)
/// - 第二行:备注(独立行,次要色,有才显示) · [协作头像] HH:mm
///   其中 HH:mm 在共享/非共享账本均展示;[协作头像] 受 [isShared] 守卫,
///   非共享账本不渲染头像。
/// - 金额列:固定 116px 宽,右对齐,支出用 destructive 色
///
/// [lastEditedAt] / [collaboratorMap] 支撑第二行协作元信息:[isShared] 为 true
/// (共享账本)时展示真实头像 + 创建人/编辑人重叠(与详情页一致);为 false
/// (单人账本)时仅展示时间。时间取值优先 [lastEditedAt],否则回退 [happenedAt]。
class TransactionListItem extends ConsumerWidget {
  final IconData icon;
  final db.Category? category; // 可选的分类对象，用于显示自定义图标
  final String title;
  final int amount; // 单位:分
  /// 多币种:交易原币种(null/等于账本本位币 → 维持无符号纯数字;
  /// 外币 → 金额前显示其币种符号,如 JP¥/US$,一眼区分原币)。
  final String? currencyCode;
  /// 多币种:折账本本位币快照。外币交易在金额右下角显示 ≈ 折算小字。
  final int? nativeAmount; // 单位:分
  final bool isExpense; // 决定正负号
  final VoidCallback? onTap;
  final VoidCallback? onCategoryTap; // 点击分类图标/名称的回调
  final String? categoryName; // 分类名称，用于显示
  final VoidCallback? onDelete; // 删除回调
  final DateTime? happenedAt; // 交易时间，用于显示时分

  // 批量选择模式相关
  final bool isSelectionMode; // 是否处于选择模式
  final bool isSelected; // 是否被选中
  final VoidCallback? onSelectionChanged; // 选中状态改变回调
  final bool showFullDate; // 是否显示完整日期（年-月-日 时:分）

  final bool excludeFromStats; // 不计入收支:第二行显示「不计收支」标签

  /// 最后编辑时间。列表项第二行 HH:mm 优先读本字段(语义"最后编辑时分")，
  /// 为 null 时回退 [happenedAt]。
  final DateTime? lastEditedAt;

  /// 共享账本成员表(用于解析协作头像)。非 null 即表示共享账本,
  /// 第二行展示真实头像 + 创建人/编辑人重叠(与详情页一致)。
  /// null = 单人账本或不展示头像。
  final Map<String, SpitoutCloudLedgerMember>? collaboratorMap;

  /// 交易创建人 userId(来自 Transaction.createdByUserId)。
  final String? creatorUserId;

  /// 交易最后编辑人 userId(来自 Transaction.lastEditedByUserId)。
  final String? editorUserId;

  /// 是否为共享账本。仅共享账本渲染协作头像;非共享账本(单人账本)不渲染。
  final bool isShared;

  const TransactionListItem({
      super.key,
      required this.icon,
      this.category,
      required this.title,
      required this.amount,
      this.currencyCode,
      this.nativeAmount,
      required this.isExpense,
      this.onTap,
      this.onCategoryTap,
      this.categoryName,
      this.onDelete,
      this.happenedAt,
      this.lastEditedAt,
      this.collaboratorMap,
      this.creatorUserId,
      this.editorUserId,
      this.isShared = false,
      this.isSelectionMode = false,
      this.isSelected = false,
      this.onSelectionChanged,
      this.showFullDate = false,
      this.excludeFromStats = false,
  });

  /// 「不计收支 / 不计预算」标记的小 pill（中性灰底，de-emphasis）
  Widget _flagChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: SpitoutTokens.divider(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: SpitoutTokens.textTertiary(context),
        ),
      ),
    );
  }

  bool _isForeign(WidgetRef ref) {
    final cc = currencyCode;
    if (cc == null || cc.isEmpty) return false;
    final base =
        ref.watch(currentLedgerProvider).asData?.value?.currency ?? 'CNY';
    return cc.toUpperCase() != base.toUpperCase();
  }

  /// 第二行时间源:优先 lastEditedAt(最后编辑时分),回退 happenedAt(记账时间)。
  /// 列表项第二行的 HH:mm 语义是「最后编辑时间」,但创建后从未编辑的记录
  /// lastEditedAt 为 null,此时用记账时间兜底,保证每条记录都有时分可展示。
  DateTime? get _effectiveTime => lastEditedAt ?? happenedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget child = InkWell(
      onTap: isSelectionMode ? onSelectionChanged : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: SpitoutDimens.listRowVertical),
        child: Row(
          children: [
            // 选择模式:复选框;否则:36×36 分类图标(secondary 底 + primary 图标)
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onSelectionChanged?.call(),
                activeColor: primary,
              )
            else
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onCategoryTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      // shadcn secondary 底色(亮 #EDF2F7 / 暗 #374151)
                      color: SpitoutTokens.surfaceSecondary(context),
                      shape: BoxShape.circle,
                    ),
                    child: CategoryIconWidget(
                      category: category,
                      size: 20,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            // 左侧:第一行分类名 + 第二行(备注 · [头像] HH:mm)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 第一行:分类名(主文字)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            // 第一行固定展示「分类名优先」，无分类时回退 title。
                            categoryName ?? title,
                            style: SpitoutTextTokens.title(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // 第二行:备注 · [头像] HH:mm · 不计收支标签
                    _buildSecondLine(context, ref),
                  ],
                ),
              ),
            ),
            // 右侧:金额列固定 116px,右对齐,最多两行
            SizedBox(
              width: 116,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 主金额:显示交易原币种 + 原金额(用户记账时选的币种和输入的金额)。
                  // 设计意图:记账时的币种和金额不受其他币种组件影响,
                  // 仅作为与账本币种的汇率换算基准。currencyCode 为 null(历史数据)
                  // 或等于账本本位币时,AmountText 自动回退到账本币种符号。
                  AmountText(
                      // 展示层把整数分转回"元"。
                      value: isExpense ? -amount / 100 : amount / 100,
                      signed: true,
                      showCurrency: true,
                      currencyCode: currencyCode,
                      style: SpitoutTextTokens.title(context).copyWith(
                        color: ref.watch(expenseColorSchemeProvider) == 'green' ? SpitoutTokens.success(context) : SpitoutTokens.error(context),
                      )),
                  // 副行:外币交易时显示折算到账本本位币的结果(≈ 本位币金额)。
                  // 仅当交易币种≠账本本位币且折算值≠原金额时展示(逻辑兜底:
                  // 主币种=记账币种时无需换算)。
                  Builder(builder: (context) {
                    final showConversion = _isForeign(ref) &&
                        nativeAmount != null &&
                        amount != nativeAmount;
                    if (!showConversion) {
                      return const SizedBox.shrink();
                    }
                    final ledgerCurrency = ref
                        .watch(currentLedgerProvider)
                        .asData
                        ?.value
                        ?.currency ?? 'CNY';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '≈ ${getCurrencySymbol(ledgerCurrency)} ${((nativeAmount ?? amount) / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: SpitoutTokens.textTertiary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return child;
  }

  /// 构建第二行:备注(独立行) · [最后编辑者头像] HH:mm · 不计收支标签。
  ///
  /// 第二行规范:
  /// - 备注独立成行(非括号),仅在「有分类 + 备注存在且不同于分类名」时展示(写死逻辑)
  /// - 头像仅共享账本([isShared] 为 true)展示,置于时间左侧
  /// - HH:mm 用 _effectiveTime(lastEditedAt 优先),showFullDate 模式展示完整日期,
  ///   共享与非共享账本均展示
  /// - 「不计收支」标签始终在第二行末尾
  Widget _buildSecondLine(BuildContext context, WidgetRef ref) {
    final parts = <Widget>[];

    // 备注部分(独立展示,非括号)。
    // 设计意图:备注显示方式固定为「分类名优先」,直接内联判断:只有存在分类
    // 且备注有值、且与分类名不同时才作为备注行展示。
    final note = (categoryName != null &&
            title.isNotEmpty &&
            title != categoryName)
        ? title
        : null;
    if (note != null && note.isNotEmpty) {
      parts.add(Text(
        note,
        style: TextStyle(
          fontSize: 12,
          color: SpitoutTokens.textSecondary(context),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ));
    }

    // 时间部分
    final time = _effectiveTime;
    if (time != null) {
      String timeText;
      if (showFullDate) {
        // 完整日期模式(年-月-日 时:分),用于非首页场景
        timeText =
            '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (time.hour != 0 || time.minute != 0 || time.second != 0) {
        // HH:mm(列表项时分格式)
        timeText =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else {
        timeText = '';
      }
      if (timeText.isNotEmpty) {
        // 时间文本在共享/非共享账本均展示,不受 isShared 影响。
        final timeWidget = Text(
          timeText,
          style: TextStyle(
            fontSize: 12,
            color: SpitoutTokens.textSecondary(context),
          ),
        );
        if (isShared) {
          // 仅共享账本渲染协作头像:collaboratorMap == null 表示成员表尚未加载,
          // 传 membersLoading 让组件先显示 PersonAvatar 占位，数据到位后再切真实头像。
          final isMembersLoading = collaboratorMap == null;
          final creator = (!isMembersLoading && creatorUserId != null)
              ? collaboratorMap![creatorUserId]
              : null;
          final editor = (!isMembersLoading && editorUserId != null)
              ? collaboratorMap![editorUserId]
              : null;
          parts.add(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CollaboratorAvatarGroup(
                creator: creator,
                editor: editor,
                creatorUserId: creatorUserId,
                editorUserId: editorUserId,
                radius: 9,
                membersLoading: isMembersLoading,
              ),
              const SizedBox(width: 4),
              timeWidget,
            ],
          ));
        } else {
          // 单人/本地账本:只渲染时间,不渲染协作头像(避免出现空占位圆)。
          parts.add(timeWidget);
        }
      }
    }

    // 不计收支标签
    if (excludeFromStats) {
      parts.add(_flagChip(context, AppLocalizations.of(context).txFlagExcludedTag));
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    // 用 · 连接各部分(头像+时间作为一组,不拆分)
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '·',
            style: TextStyle(
              fontSize: 12,
              color: SpitoutTokens.textTertiary(context),
            ),
          ),
        ));
      }
      children.add(parts[i]);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 0,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}
