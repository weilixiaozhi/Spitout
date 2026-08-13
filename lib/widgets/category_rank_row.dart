import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';
import 'category_icon.dart';
import 'amount_text.dart';
import 'package:spitout/utils/category_utils.dart';
import 'package:spitout/data/models.dart' as db;

class CategoryRankRow extends ConsumerStatefulWidget {
  final int? categoryId; // 分类ID
  final db.Category? category; // 分类对象（用于显示图标）
  final String name;
  final double value;
  final double percent; // 0..1 (相对于总金额的真实占比)
  final Color color;

  /// 点击分类（icon / 子分类行）时的回调，由 page 层注入导航逻辑
  ///（widget 不感知具体 page，保持 pages → widgets 单向依赖）。
  final void Function(int categoryId, String categoryName)? onCategoryTap;
  final List<({int id, db.Category? category, String name, double total})>? subCategories; // 预计算的子分类明细

  const CategoryRankRow({
    super.key,
    this.categoryId,
    this.category,
    required this.name,
    required this.value,
    required this.percent,
    required this.color,
    this.onCategoryTap,
    this.subCategories,
  });

  @override
  ConsumerState<CategoryRankRow> createState() => _CategoryRankRowState();
}

class _CategoryRankRowState extends ConsumerState<CategoryRankRow> {
  bool _expanded = false;
  List<({int id, db.Category? category, String name, double total, double percent})>? _subCategories;
  bool _hasCheckedSubCategories = false;

  /// 该父分类是否「实际」存在可展示的子分类。
  /// 与 _toggleExpand 的展开判定保持一致：预计算的子分类里存在金额 > 0 的明细。
  /// 用于决定是否渲染收起/展开指示箭头，避免对无子分类的父分类显示误导性箭头。
  bool get _hasSubCategories =>
      widget.subCategories?.any((s) => s.total > 0) ?? false;

  @override
  void didUpdateWidget(CategoryRankRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当一级分类的金额或占比发生变化时，重置二级分类缓存
    if (oldWidget.value != widget.value || oldWidget.percent != widget.percent) {
      _hasCheckedSubCategories = false;
      _subCategories = null;
      // 如果当前是展开状态，重新加载数据
      if (_expanded) {
        _loadSubCategories();
      }
    }
  }


  Future<void> _loadSubCategories() async {
    if (widget.categoryId == null) return;

    // 优先使用预计算的子分类数据（已按时间范围正确聚合）
    if (widget.subCategories != null && widget.subCategories!.isNotEmpty) {
      final totalAmount = widget.value;
      final subCatData = widget.subCategories!
          .where((s) => s.total > 0)
          .map((s) => (
                id: s.id,
                category: s.category,
                name: s.name,
                total: s.total,
                percent: totalAmount > 0
                    ? widget.percent * (s.total / totalAmount)
                    : 0.0,
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _hasCheckedSubCategories = true;
        _subCategories = subCatData;
      });
      return;
    }

    // 无预计算数据时，标记为空列表
    if (!mounted) return;
    setState(() {
      _hasCheckedSubCategories = true;
      _subCategories = [];
    });
  }

  void _handleTap(int? categoryId, String categoryName) {
    if (categoryId == null) return;
    // 导航职责在 page 层：widget 只上报点击事件，不感知目标页面
    widget.onCategoryTap?.call(categoryId, categoryName);
  }

  /// 点击父分类的内容区域（标题/金额/百分比/进度条）时触发：展开或折叠子分类。
  /// 仅负责展开/折叠，不负责跳转详情页（跳转由点击 icon 单独处理）。
  void _toggleExpand() async {
    // 首次点击时检查是否有子分类
    if (!_hasCheckedSubCategories) {
      await _loadSubCategories();
    }

    // 有子分类：展开/折叠；无子分类：不做任何操作（用户可点 icon 进入详情）
    if (_subCategories != null && _subCategories!.isNotEmpty) {
      setState(() {
        _expanded = !_expanded;
      });
    }
  }

  Widget _buildCategoryRow({
    required int? categoryId,
    required db.Category? category,
    required String name,
    required double value,
    required double percent,
    required bool isTopLevel,
  }) {
    // 使用统一的 CategoryIconWidget
    final iconWidget = CategoryIconWidget(
      category: category,
      size: isTopLevel ? 20 : 18,
      color: widget.color,
    );

    // 内容列：标题+金额、百分比、进度条。
    // 父分类点击此区域 → 展开/折叠子分类；子分类点击 → 跳转详情页。
    // 注意：contentColumn 本身是 Column（不含 Expanded），由各使用方按需
    // 用 Expanded 包裹后放入 Row。不能在这里就包 Expanded，否则在顶级分类
    // 行中 Expanded 会被 GestureDetector 隔离于 Row 之外，触发
    // ParentDataWidget 断言异常（release 下渲染为灰块，即"列表崩了"bug）。
    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        CategoryUtils.getDisplayName(name, context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: isTopLevel ? 14 : 13,
                        ),
                      ),
                    ),
                    // 仅顶级父分类且「实际存在子分类」时，在标题隔壁放置收起/展开指示箭头：
                    // 收起态 → 向右(chevronRight)，点击展开后旋转 90° 向下(chevronDown)。
                    // 放在标题右侧而非金额下方，使箭头的语义与标题直接绑定，更直观。
                    // 使用 AnimatedRotation 平滑过渡，避免图标突兀切换。
                    if (isTopLevel && _hasSubCategories) ...[
                      const SizedBox(width: SpitoutDimens.p4),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          AppIcons.chevronRight,
                          size: SpitoutDimens.icon16,
                          color: SpitoutTokens.iconTertiary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SpitoutDimens.p8),
              // 金额补上货币符号（showCurrency: true），与趋势网格口径一致
              AmountText(
                value: value,
                signed: false,
                showCurrency: true,
                style: SpitoutTextTokens.body(context),
              ),
            ],
          ),
          const SizedBox(height: SpitoutDimens.p4),
          Row(
            children: [
              Text(
                '${(percent * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: SpitoutTokens.textTertiary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpitoutDimens.p4),
          ClipRRect(
            borderRadius: BorderRadius.circular(SpitoutDimens.radius4),
            child: Stack(
              children: [
                Container(
                  height: isTopLevel ? 6 : 5,
                  color: widget.color.withValues(alpha: 0.15),
                ),
                FractionallySizedBox(
                  widthFactor: percent.clamp(0, 1),
                  child: Container(
                    height: isTopLevel ? 6 : 5,
                    color: widget.color.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    // 图标容器（圆形背景 + icon）
    final iconContainer = Container(
      width: isTopLevel ? 44 : 38,
      height: isTopLevel ? 44 : 38,
      decoration: BoxDecoration(
        color: isTopLevel
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : widget.color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: iconWidget,
    );

    if (isTopLevel) {
      // 父分类：区分两个点击事件
      // - 点击 icon → 进入该父分类的分类汇总页面
      // - 点击标题/金额/百分比/进度条 → 展开/折叠子分类
      return Padding(
        padding: const EdgeInsets.only(
          left: 0,
          top: SpitoutDimens.p8,
          bottom: SpitoutDimens.p8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // icon 区域：独立可点击，跳转分类汇总页
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(SpitoutDimens.radius20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: categoryId != null
                    ? () => _handleTap(categoryId, name)
                    : null,
                borderRadius: BorderRadius.circular(SpitoutDimens.radius20),
                child: iconContainer,
              ),
            ),
            const SizedBox(width: SpitoutDimens.p12),
            // 内容区域：点击展开/折叠子分类。
            // Expanded 必须作为 Row 直接子节点；GestureDetector 包在 Expanded
            // 内部（而非外部），否则 Expanded 脱离 Flex 父级会触发断言异常。
            Expanded(
              child: GestureDetector(
                onTap: _toggleExpand,
                behavior: HitTestBehavior.opaque,
                // 内容列已包含标题旁的箭头；此处不单独渲染箭头。
                child: contentColumn,
              ),
            ),
          ],
        ),
      );
    }

    // 子分类：整行可点击，跳转详情页
    return InkWell(
      onTap: () => _handleTap(categoryId, name),
      child: Padding(
        padding: const EdgeInsets.only(
          left: SpitoutDimens.p16,
          top: SpitoutDimens.p8,
          bottom: SpitoutDimens.p8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            iconContainer,
            const SizedBox(width: SpitoutDimens.p12),
            Expanded(child: contentColumn),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 一级分类
        _buildCategoryRow(
          categoryId: widget.categoryId,
          category: widget.category,
          name: widget.name,
          value: widget.value,
          percent: widget.percent,
          isTopLevel: true,
        ),
        // 二级分类展开区域
        if (_expanded && _subCategories != null && _subCategories!.isNotEmpty)
          ...(_subCategories!.map((subCat) {
            return _buildCategoryRow(
              categoryId: subCat.id,
              category: subCat.category,
              name: subCat.name,
              value: subCat.total,
              percent: subCat.percent, // 使用真实占比
              isTopLevel: false,
            );
          }).toList()),
      ],
    );
  }
}
