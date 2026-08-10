import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/data/models.dart' as db;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/utils/category_utils.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/providers/core/post_processor.dart';
import 'package:spitout/widgets/overlay_keyboard_guard.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/icons/category_icons.dart';
import 'package:spitout/pages/transaction/category_detail_page.dart';
import 'package:spitout/core/logging/logger_service.dart';

class CategoryEditPage extends ConsumerStatefulWidget {
  final db.Category? category; // null表示新建
  final String kind; // 全局仅支出模式，固定为 'expense'
  final db.Category? parentCategory; // 父分类（用于创建二级分类）

  const CategoryEditPage({
    super.key,
    this.category,
    required this.kind,
    this.parentCategory,
  });

  @override
  ConsumerState<CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends ConsumerState<CategoryEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _selectedIcon;
  bool _saving = false;
  bool _isDuplicateName = false;
  String? _duplicateErrorMessage;
  /// 判重查询失败标志:失败时按「不可保存」保守处理,避免重名入库后被 repo 抛错。
  bool _duplicateCheckFailed = false;
  Timer? _debounceTimer;

  // 父分类相关状态
  db.Category? _selectedParentCategory;
  /// 当前编辑的分类是否已有子分类（编辑模式下异步加载）
  /// 为 true 时所属分类行置灰不可点击（状态 4.3）
  bool _hasChildren = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');

    // 确保选中的图标在可用的图标组中存在
    final categoryIcon = widget.category?.icon;
    if (categoryIcon != null &&
        categoryIcon.isNotEmpty &&
        _isValidIcon(categoryIcon)) {
      _selectedIcon = categoryIcon;
    } else {
      _selectedIcon = 'category'; // 默认图标
    }

    // 初始化父分类状态
    if (widget.category != null) {
      // 编辑模式：加载现有父分类
      if (widget.category!.level == 2 && widget.category!.parentId != null) {
        _loadParentCategory(widget.category!.parentId!);
      }
      // 异步检查当前分类是否有子分类（决定所属分类行是否可点击）
      _loadHasChildren();
    } else if (widget.parentCategory != null) {
      // 创建二级分类模式：预设父分类
      _selectedParentCategory = widget.parentCategory;
    }

    // 监听输入框文本变化，防抖500毫秒后检查重复
    _nameController.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkNameDuplicate();
      });
    });
  }

  /// 异步加载当前编辑分类是否有子分类
  /// 有子分类 → 所属分类行置灰（状态 4.3），无法修改父分类
  Future<void> _loadHasChildren() async {
    if (widget.category == null) return;
    try {
      final repo = ref.read(repositoryProvider);
      final hasChildren = await repo.hasSubCategories(widget.category!.id);
      if (mounted) {
        setState(() {
          _hasChildren = hasChildren;
        });
      }
    } catch (e, st) {
      // 查询失败时保守视为「已有子分类」:禁用所属分类修改,避免把带子分类的
      // 父分类改挂到别处造成数据错乱。
      logger.error('CategoryEdit', '加载子分类状态失败', e, st);
      if (mounted) {
        setState(() => _hasChildren = true);
        showToast(context, AppLocalizations.of(context).commonOperationFailed);
      }
    }
  }

  Future<void> _loadParentCategory(int parentId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final parent = await repo.getCategoryById(parentId);
      if (mounted && parent != null) {
        setState(() {
          _selectedParentCategory = parent;
        });
      }
    } catch (e, st) {
      // 父分类加载失败不阻断编辑:保持初始 null(视为一级分类),记录日志便于排查。
      logger.error('CategoryEdit', '加载父分类失败 parentId=$parentId', e, st);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  bool get isEditing => widget.category != null;

  bool get isCreatingSubCategory => widget.parentCategory != null;

  /// 检查分类名称是否重复
  Future<void> _checkNameDuplicate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _isDuplicateName = false;
        _duplicateErrorMessage = null;
        _duplicateCheckFailed = false;
      });
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      final excludeId = isEditing ? widget.category!.id : null;

      // 作用域判重:二级分类只和「同一父级下」的兄弟比,一级分类只和其他一级比。
      // 跨父级允许同名(默认 seed 即有「购物>鞋子」「服装>鞋子」)。
      final isDuplicate = await repo.isCategoryNameDuplicate(
        name: name,
        kind: widget.kind,
        excludeId: excludeId,
        // 以 _selectedParentCategory 是否为空判定子分类作用域
        parentId: _selectedParentCategory?.id,
      );

      if (mounted) {
        setState(() {
          _isDuplicateName = isDuplicate;
          _duplicateCheckFailed = false;
          if (isDuplicate) {
            final l10n = AppLocalizations.of(context);
            _duplicateErrorMessage = l10n.categoryNameDuplicate;
          } else {
            _duplicateErrorMessage = null;
          }
        });
        // 触发表单验证更新
        _formKey.currentState?.validate();
      }
    } catch (e, st) {
      // 判重查询失败:禁用保存并提示,避免用户保存后被 repo 抛重名错误。
      logger.error('CategoryEdit', '检查分类名称重复失败', e, st);
      if (mounted) {
        setState(() {
          _duplicateCheckFailed = true;
          _duplicateErrorMessage =
              AppLocalizations.of(context).commonOperationFailed;
        });
        _formKey.currentState?.validate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    String headerTitle;
    if (isEditing) {
      headerTitle = l10n.categoryEditTitle;
    } else {
      headerTitle = l10n.categoryNewTitle;
    }

    return _buildScaffold(context, headerTitle, null);
  }

  Widget _buildScaffold(
      BuildContext context, String headerTitle, String? headerSubtitle) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: headerTitle,
            subtitle: headerSubtitle,
            showBack: true,
            // 编辑模式恒显示分类汇总入口：编辑对象恒存在，入口始终可见
            actions: isEditing && widget.category != null
                ? [
                    HeaderIconAction(
                      icon: AppIcons.categoryDetail,
                      tooltip: l10n.categoryDetailTooltip,
                      onPressed: () {
                        Navigator.of(context).push(
                          appPageRoute(
                            builder: (context) => CategoryDetailPage(
                              categoryId: widget.category!.id,
                              categoryName: widget.category!.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ]
                : null,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 1. 分类名称（移至最上方）──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.categoryNameLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: l10n.categoryNameHint,
                              errorText: _duplicateErrorMessage,
                            ),
                            maxLength: 10,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.categoryNameRequired;
                              }
                              if (value.trim().length > 10) {
                                return l10n.categoryNameTooLong;
                              }
                              if (_isDuplicateName) {
                                return _duplicateErrorMessage;
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 2. 所属分类 ──
                  _buildParentCategoryCard(context),

                  const SizedBox(height: 16),

                  // ── 3. 分类图标 ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.categoryIconLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          // 当前图标预览
                          _buildCurrentIconPreview(context, primaryColor),
                          const SizedBox(height: 8),
                          // 分割线
                          SpitoutTokens.cardDivider(context, indent: 0),
                          const SizedBox(height: 8),
                          // Lucide 图标网格（限高滚动）
                          SizedBox(
                            height: 360,
                            child: _GroupedIconGrid(
                              selectedIcon: _selectedIcon,
                              kind: widget.kind,
                              onIconSelected: (icon) {
                                setState(() {
                                  _selectedIcon = icon;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部保存按钮
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: (_saving || _isDuplicateName || _duplicateCheckFailed)
                  ? null
                  : _saveCategory,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建所属分类卡片
  ///
  /// 三种状态：
  /// - 4.1 独立分类（无父级、无子级）：正常色，副标题为空，可点击
  /// - 4.2 有父级分类：正常色，副标题为父分类名，可点击
  /// - 4.3 父级且有子分类：置灰，副标题"此分类包含二级分类，无法修改"，不可点击
  Widget _buildParentCategoryCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // 状态 4.3：当前分类有子分类 → 置灰不可点击
    final isDisabled = _hasChildren;
    // 状态 4.2：有父分类 → 显示父分类名
    final hasParent = _selectedParentCategory != null;
    // 仅在「有父分类」或「置灰(有子分类)」时显示副标题；
    // 独立分类 / 新增分类无副标题，不用空串占位，标题垂直居中。
    final showSubtitle = isDisabled || hasParent;

    // 置灰时使用 textDisabled / iconTertiary，正常时使用 textPrimary / iconSecondary
    final titleColor = isDisabled
        ? SpitoutTokens.textDisabled(context)
        : SpitoutTokens.textPrimary(context);
    final iconColor = isDisabled
        ? SpitoutTokens.iconTertiary(context)
        : primaryColor;

    // ConstrainedBox 只锁最小高度而非固定高度：
    // 真机字体下三种状态内容都不超过 64，视觉等高（设计意图）；
    // 测试环境的备用字体行高偏大，有副标题时内容约 40px > 64-28(上下 padding)，
    // 固定高度会溢出 4px，minHeight 允许卡片按内容自然增高，彻底规避溢出。
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: InkWell(
          // 仅非置灰状态可点击
          onTap: isDisabled ? null : () => _selectParentCategory(),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              // Row 整体垂直居中，无论有无副标题都对齐到同一个高度里
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 上箭头图标
                Icon(AppIcons.parentCategory, color: iconColor, size: 24),
                const SizedBox(width: 16),
                // 标题 + 副标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // min：配合外层 minHeight 约束，内容不足 64 时被撑到约束下限，
                    // 剩余空间仍按 center 分配 → 无副标题时标题照样垂直居中；
                    // 若用 max，在 ListView 的无限高度约束下会请求无限高而报错。
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.categoryParentCategoryTitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: titleColor,
                        ),
                      ),
                      // 副标题行：4.2 显示父分类名，4.3 显示置灰提示；
                      // 4.1 独立分类无内容时整行不渲染。
                      if (showSubtitle)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isDisabled
                                ? l10n.categoryHasSubCategories
                                : CategoryUtils.getDisplayName(
                                    _selectedParentCategory!.name, context),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDisabled
                                  ? SpitoutTokens.textDisabled(context)
                                  : SpitoutTokens.textSecondary(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 右侧箭头：4.3 隐藏
                if (!isDisabled)
                  Icon(
                    AppIcons.chevronRight,
                    color: SpitoutTokens.iconTertiary(context),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建当前图标预览行
  Widget _buildCurrentIconPreview(BuildContext context, Color primaryColor) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        // 40x40 图标方框（主题色 10% 背景 + 主题色 2px 边框，圆角 8）
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            border: Border.all(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            lucideIconLibrary[_selectedIcon] ?? lucideFallback,
            size: 20,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          l10n.categoryCurrentIcon,
          style: TextStyle(
            fontSize: 14,
            color: SpitoutTokens.textPrimary(context),
          ),
        ),
      ],
    );
  }

  void _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    // 保存前再次检查名称重复(作用域判重,与 _checkNameDuplicate 口径一致)
    // 以 _selectedParentCategory 是否为空判定子分类作用域
    final repo = ref.read(repositoryProvider);
    final name = _nameController.text.trim();
    final excludeId = isEditing ? widget.category!.id : null;
    final isDuplicate = await repo.isCategoryNameDuplicate(
      name: name,
      kind: widget.kind,
      excludeId: excludeId,
      parentId: _selectedParentCategory?.id,
    );

    if (isDuplicate) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).categorySaveError,
        message: AppLocalizations.of(context).categoryNameDuplicate,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // 是否为子分类：有父分类 → level 2，无父分类 → level 1
      final isSubCategory = _selectedParentCategory != null;

      if (isEditing) {
        // 编辑现有分类
        // parentId: -1 表示清空父分类（从二级变一级），有值表示设置父分类
        final parentId = isSubCategory
            ? _selectedParentCategory!.id
            : (widget.category!.level == 2 ? -1 : null);
        final level = isSubCategory ? 2 : 1;

        await repo.updateCategory(
          widget.category!.id,
          name: name,
          icon: _selectedIcon,
          parentId: parentId,
          level: level,
        );

        if (!mounted) return;
        showToast(context, AppLocalizations.of(context).categoryUpdated(name));
      } else {
        // 新建分类
        if (isSubCategory) {
          // 新建二级分类
          await repo.createSubCategory(
            parentId: _selectedParentCategory!.id,
            name: name,
            kind: widget.kind,
            icon: _selectedIcon,
          );
          if (!mounted) return;
          showToast(context,
              AppLocalizations.of(context).categorySubCategoryCreated(name));
        } else {
          // 新建一级分类
          await repo.createCategory(
            name: name,
            kind: widget.kind,
            icon: _selectedIcon,
          );
          if (!mounted) return;
          showToast(
              context, AppLocalizations.of(context).categoryCreated(name));
        }
      }

      // 刷新分类列表
      ref.invalidate(categoriesProvider);

      // 分类也是 user-scoped，ChangeTracker 记在 ledgerId=0；用当前 ledger
      // 触发一次 sync 把新增/重命名推到服务端，web 秒刷。
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }

      if (!mounted) return;
      Navigator.of(context).pop(true); // 返回true表示有更新
    } catch (e, st) {
      logger.error('CategoryEdit', '保存分类失败', e, st);
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).categorySaveError,
        message: AppLocalizations.of(context).commonOperationFailed,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isValidIcon(String iconName) {
    // 图标名存在于 lucideIconLibrary 注册表即有效
    return lucideIconLibrary.containsKey(iconName);
  }

  /// 拉起选择所属分类 BottomSheet
  /// 过滤逻辑：有子分类的一级分类 OR 无交易记录的一级分类
  void _selectParentCategory() async {
    // 收起键盘并等待动画结束，避免选择所属分类后键盘重新弹出（与记账页 _pickDate() 统一）。
    await prepareForOverlay();
    if (!mounted) return;

    final repo = ref.read(repositoryProvider);

    final selected = await showParentCategorySelector(
      context,
      initialSelection: _selectedParentCategory,
      // 编辑模式排除当前分类自身（不能选自己做父分类）
      excludeIds: isEditing ? [widget.category!.id] : null,
      categoryFilter: (category) async {
        // 可选条件：有子分类 OR 没有交易记录
        final hasSubCategories = await repo.hasSubCategories(category.id);
        if (hasSubCategories) return true;

        final transactionCount =
            await repo.getTransactionCountByCategory(category.id);
        return transactionCount == 0;
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedParentCategory = selected;
      });
      // 切换父分类后主动重跑判重:防抖只监听文本输入,不改名只切父时
      // 按钮态仍停留在旧父级作用域,这里显式刷新一次。
      _debounceTimer?.cancel();
      _checkNameDuplicate();
    }
  }
}

class _GroupedIconGrid extends StatelessWidget {
  final String? selectedIcon;
  final String kind;
  final ValueChanged<String> onIconSelected;

  const _GroupedIconGrid({
    required this.selectedIcon,
    required this.kind,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    final iconGroups = _getIconGroups();
    final primaryColor = Theme.of(context).colorScheme.primary;

    // 使用 ListView 实现区域内滚动（不随全页 ListView 滚动）
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: iconGroups.map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分组标题：底部留白 12px，拉开“标题→首行图标”距离，避免与图标过于紧凑；
            // 组内行间距由 Wrap.runSpacing 控制（8px），组间间距见下方 SizedBox(18)。
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                group.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            // 图标网格：用 Wrap 实现。
            // 关键原因：GridView 必须用一个“格子高度”（childAspectRatio 或
            // mainAxisExtent）来框定每个 cell，而该高度与“图标+名字”真实内容高度
            // 永远存在偏差，居中后产生留白 g，导致“标题→第一行”比其他距离大。
            // Wrap 没有强制格子高度：每个盒子高度由内容决定（mainAxisSize: min），
            // 盒子（边框/选中高亮）真正贴合内容；spacing=横向间距、runSpacing=纵向
            // 行间距，显式都设 6，与标题 Padding(bottom:6)、组间 SizedBox(6) 完全一致，
            // 因此“标题→图标→图标→标题”所有方向视觉间距恒为 6px。
            LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 5;
                const spacing = 6.0; // 横向列间距
                const runSpacing = 8.0; // 纵向行间距
                // 均分可用宽度得到每个格子的精确宽度，保证 5 列对齐
                final itemWidth =
                    (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
                        crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: runSpacing,
                  children: group.icons.map((iconItem) {
                    final isSelected = selectedIcon == iconItem.key;
                    return SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        onTap: () => onIconSelected(iconItem.key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withValues(alpha: 0.1)
                                : null,
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : SpitoutTokens.border(context),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          // 仅留少量内边距让盒子贴紧内容（不被强制拉高产生留白）
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            // min：盒子高度=内容高度，彻底消除居中留白 g
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 图标
                              Icon(
                                // 键即 Lucide 图标名,经注册表反解;未命中走兜底防问号
                                lucideIconLibrary[iconItem.key] ?? lucideFallback,
                                size: 20,
                                color: isSelected
                                    ? primaryColor
                                    : SpitoutTokens.iconCategory(context),
                              ),
                              const SizedBox(height: 4),
                              // 图标名（Lucide 原名，不翻译）
                              Text(
                                iconItem.key,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected
                                      ? primaryColor
                                      : SpitoutTokens.textTertiary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            // 末行图标→下一组标题间距 18px，与标题底部留白（12px）错位以区分分组
            const SizedBox(height: 18),
          ],
        );
      }).toList(),
    );
  }

  /// 图标分组清单。key 均为 Lucide 图标名，须存在于 lucideIconLibrary
  /// （选中后该字符串直接持久化到 Category.icon）。
  /// 分组顺序："基础"固定在倒数第二（"其他"之上），业务分组在前。
  List<_IconGroup> _getIconGroups() {
    if (kind == 'expense') {
      return [
        _IconGroup('餐饮美食', [
          _IconData('utensils'),
          _IconData('utensilsCrossed'),
          _IconData('sandwich'),
          _IconData('coffee'),
          _IconData('wine'),
          _IconData('pizza'),
          _IconData('cake'),
          _IconData('cakeSlice'),
          _IconData('croissant'),
          _IconData('iceCream'),
          _IconData('cookie'),
          _IconData('candy'),
          _IconData('beer'),
          _IconData('martini'),
          _IconData('chefHat'),
          _IconData('soup'),
          _IconData('beef'),
          _IconData('milk'),
          _IconData('cupSoda'),
          _IconData('glassWater'),
        ]),
        _IconGroup('交通出行', [
          _IconData('car'),
          _IconData('bus'),
          _IconData('train'),
          _IconData('plane'),
          _IconData('bike'),
          _IconData('footprints'),
          _IconData('ship'),
          _IconData('navigation'),
          _IconData('fuel'),
          _IconData('parkingCircle'),
          _IconData('truck'),
          _IconData('key'),
        ]),
        _IconGroup('购物消费', [
          _IconData('shoppingCart'),
          _IconData('shoppingBag'),
          _IconData('store'),
          _IconData('building'),
          _IconData('carrot'),
          _IconData('package'),
          _IconData('boxes'),
          _IconData('tags'),
          _IconData('receipt'),
          _IconData('tag'),
          _IconData('badgePercent'),
          _IconData('gift'),
          _IconData('award'),
          _IconData('ticket'),
          _IconData('badgeCheck'),
        ]),
        _IconGroup('居住生活', [
          _IconData('home'),
          _IconData('building2'),
          _IconData('sofa'),
          _IconData('bed'),
          _IconData('bath'),
          _IconData('armchair'),
          _IconData('tv'),
          _IconData('refrigerator'),
          _IconData('lightbulb'),
          _IconData('airVent'),
          _IconData('zap'),
          _IconData('droplet'),
          _IconData('wind'),
          _IconData('sprayCan'),
          _IconData('wrench'),
          _IconData('hammer'),
          _IconData('paintbrush'),
          _IconData('scroll'),
        ]),
        _IconGroup('通讯设备', [
          _IconData('phone'),
          _IconData('smartphone'),
          _IconData('tablet'),
          _IconData('laptop'),
          _IconData('monitor'),
          _IconData('watch'),
          _IconData('headphones'),
          _IconData('keyboard'),
          _IconData('mouse'),
          _IconData('wifi'),
          _IconData('router'),
          _IconData('plug'),
        ]),
        _IconGroup('娱乐休闲', [
          _IconData('clapperboard'),
          _IconData('music'),
          _IconData('gamepad2'),
          _IconData('venetianMask'),
          _IconData('dice5'),
          _IconData('partyPopper'),
          _IconData('moon'),
          _IconData('ticket'),
          _IconData('ferrisWheel'),
          _IconData('umbrella'),
          _IconData('waves'),
          _IconData('flower'),
          _IconData('goal'),
          _IconData('medal'),
          _IconData('trophy'),
          _IconData('target'),
        ]),
        _IconGroup('健康医疗', [
          _IconData('cross'),
          _IconData('stethoscope'),
          _IconData('pill'),
          _IconData('shieldCheck'),
          _IconData('syringe'),
          _IconData('dumbbell'),
          _IconData('sunrise'),
          _IconData('brain'),
          _IconData('heartPulse'),
          _IconData('activity'),
          _IconData('user'),
          _IconData('clipboardList'),
          _IconData('atom'),
          _IconData('biohazard'),
          _IconData('thermometer'),
        ]),
        _IconGroup('教育学习', [
          _IconData('graduationCap'),
          _IconData('bookOpen'),
          _IconData('library'),
          _IconData('bookMarked'),
          _IconData('pencil'),
          _IconData('edit2'),
          _IconData('calculator'),
          _IconData('flaskConical'),
          _IconData('brush'),
          _IconData('palette'),
          _IconData('film'),
          _IconData('languages'),
          _IconData('badgeHelp'),
        ]),
        _IconGroup('宠物动物', [
          _IconData('dog'),
          _IconData('cat'),
          _IconData('bone'),
          _IconData('bug'),
          _IconData('flower2'),
          _IconData('treePine'),
          _IconData('shrub'),
          _IconData('trees'),
          _IconData('sprout'),
          _IconData('leaf'),
          _IconData('fish'),
          _IconData('wheat'),
        ]),
        _IconGroup('服装美容', [
          _IconData('shirt'),
          _IconData('smile'),
          _IconData('sparkles'),
          _IconData('scissors'),
          _IconData('sparkle'),
          _IconData('droplets'),
          _IconData('gem'),
          _IconData('clock'),
          _IconData('bell'),
          _IconData('hand'),
        ]),
        _IconGroup('基础', [
          _IconData('category'),
          _IconData('tag'),
          _IconData('bookmark'),
          _IconData('star'),
          _IconData('heart'),
          _IconData('circle'),
        ]),
        _IconGroup('其他杂项', [
          _IconData('camera'),
          _IconData('image'),
          _IconData('video'),
          _IconData('printer'),
          _IconData('mail'),
          _IconData('inbox'),
          _IconData('globe'),
          _IconData('mapPin'),
          _IconData('map'),
          _IconData('compass'),
          _IconData('timer'),
          _IconData('calendarClock'),
          _IconData('handCoins'),
        ]),
      ];
    } else {
      return [
        _IconGroup('工作职业', [
          _IconData('briefcase'),
          _IconData('building2'),
          _IconData('presentation'),
          _IconData('code'),
          _IconData('penTool'),
          _IconData('hardHat'),
          _IconData('terminal'),
          _IconData('bug'),
          _IconData('monitor'),
          _IconData('laptop'),
          _IconData('atom'),
          _IconData('flaskConical'),
          _IconData('brain'),
          _IconData('stethoscope'),
          _IconData('graduationCap'),
          _IconData('scale'),
          _IconData('headphones'),
        ]),
        _IconGroup('金融理财', [
          _IconData('landmark'),
          _IconData('wallet'),
          _IconData('piggyBank'),
          _IconData('trendingUp'),
          _IconData('trendingDown'),
          _IconData('lineChart'),
          _IconData('barChart3'),
          _IconData('circleDollarSign'),
          _IconData('banknote'),
          _IconData('arrowLeftRight'),
          _IconData('creditCard'),
          _IconData('walletCards'),
          _IconData('receipt'),
          _IconData('fileText'),
          _IconData('badgeDollarSign'),
          _IconData('percent'),
          _IconData('euro'),
          _IconData('japaneseYen'),
        ]),
        _IconGroup('奖励礼品', [
          _IconData('gift'),
          _IconData('award'),
          _IconData('trophy'),
          _IconData('partyPopper'),
          _IconData('heartHandshake'),
          _IconData('badgePercent'),
          _IconData('medal'),
          _IconData('crown'),
          _IconData('badgeCheck'),
          _IconData('gem'),
          _IconData('sparkles'),
          _IconData('sparkle'),
          _IconData('ticket'),
          _IconData('dice5'),
          _IconData('checkCircle2'),
        ]),
        _IconGroup('投资收益', [
          _IconData('building'),
          _IconData('home'),
          _IconData('key'),
          _IconData('store'),
          _IconData('factory'),
          _IconData('sprout'),
          _IconData('leaf'),
          _IconData('sun'),
          _IconData('fuel'),
          _IconData('droplet'),
          _IconData('zap'),
        ]),
        _IconGroup('基础', [
          _IconData('category'),
          _IconData('tag'),
          _IconData('bookmark'),
          _IconData('star'),
          _IconData('heart'),
          _IconData('circle'),
        ]),
        _IconGroup('其他收入', [
          _IconData('heartHandshake'),
          _IconData('clock'),
          _IconData('undo'),
          _IconData('refreshCw'),
          _IconData('rotateCw'),
          _IconData('download'),
          _IconData('rotateCcw'),
          _IconData('checkCircle2'),
          _IconData('arrowRightLeft'),
          _IconData('arrowUpDown'),
          _IconData('phoneIncoming'),
          _IconData('logIn'),
          _IconData('arrowDown'),
          _IconData('arrowDownToLine'),
          _IconData('phoneOutgoing'),
        ]),
      ];
    }
  }
}

class _IconGroup {
  final String title;
  final List<_IconData> icons;

  const _IconGroup(this.title, this.icons);
}

class _IconData {
  /// Lucide 图标名（lucideIconLibrary 的键，持久化到 Category.icon）
  final String key;

  const _IconData(this.key);
}
