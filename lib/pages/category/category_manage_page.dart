import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/data/models.dart' as db;
import 'package:spitout/providers/core/post_processor.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/utils/category_utils.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'category_edit_page.dart';
import 'category_template_flat_page.dart';
import 'category_template_hierarchical_page.dart';

/// 分类管理页面
///
/// 全局仅支出模式：无 Tab 栏，直接展示支出分类网格。
/// 支持长按拖拽排序、添加分类、复选删除模式（三种删除策略）。
class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  /// 是否处于删除模式
  bool _isDeleteMode = false;

  /// 删除模式下选中的分类 ID 集合
  final Set<int> _selectedCategoryIds = {};

  /// 删除策略：0=含二级删除, 1=迁移到其他分类, 2=不含二级(提升子分类)
  int _deleteOption = 0;

  @override
  Widget build(BuildContext context) {
    final categoriesWithCountAsync = ref.watch(categoriesWithCountProvider);
    final l10n = AppLocalizations.of(context);

    // 删除模式下按返回键退出删除模式而非关闭页面
    return PopScope(
      canPop: !_isDeleteMode,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _exitDeleteMode();
      },
      child: Scaffold(
        body: Column(
          children: [
            PrimaryHeader(
              title: l10n.categoryTitle,
              showBack: true,
              // 右上角"添加分类"图标按钮（删除模式隐藏）；
              // "删除分类"入口已移至分类网格底部操作区。
              // 右缘留白由 PrimaryHeader 默认 padding 提供，不叠加额外 padding
              actions: _isDeleteMode
                  ? null
                  : [
                      // 统一使用圆圈加号图标（与周期账单新增入口一致）
                      HeaderIconAction(
                        icon: AppIcons.addCircle,
                        tooltip: l10n.categoryManageAdd,
                        onPressed: _addCategory,
                      ),
                    ],
            ),
            // 共享账本横幅：按角色提示分类归属（Owner → 修改同步给成员；
            // Editor → 记账用 Owner 分类，此处仅影响个人分类），非共享不渲染
            _buildSharedLedgerBanner(context, l10n),
            Expanded(
              child: categoriesWithCountAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(l10n.categoryLoadFailed(error.toString())),
                ),
                data: (categoriesWithCount) {
                  return _buildBody(context, l10n, categoriesWithCount);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 共享账本横幅：仅当前账本为共享账本时渲染，按我的角色切换文案——
  /// Owner：提示分类变更会同步给全体成员；Editor：提示共享账本记账使用
  /// Owner 的分类，此页编辑仅影响个人分类。角色取自 [currentLedgerProvider]
  /// 状态入口，不直连 db。
  Widget _buildSharedLedgerBanner(BuildContext context, AppLocalizations l10n) {
    final ledger = ref.watch(currentLedgerProvider).value;
    if (ledger == null || !ledger.isShared) return const SizedBox.shrink();
    final isOwner = ledger.myRole == 'owner';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: SpitoutTokens.surface(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                AppIcons.people,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOwner
                      ? l10n.categorySharedManageBannerOwner
                      : l10n.categorySharedManageBannerEditor,
                  style: TextStyle(
                    fontSize: 12,
                    color: SpitoutTokens.textSecondary(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建页面主体：排序提示 + 分类网格（底部操作区作为网格 footer 随内容滚动）
  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    List<({db.Category category, int transactionCount})> categoriesWithCount,
  ) {
    return Column(
      children: [
        // 正常模式：标题下方依次展示模板库入口按钮区、长按排序提示
        if (!_isDeleteMode) _buildTemplateEntries(context, l10n),
        if (!_isDeleteMode) _buildReorderHint(context, l10n),
        // 分类网格（正常模式可拖拽排序，删除模式显示复选框）
        Expanded(
          child: _CategoryGridView(
            categoriesWithCount: categoriesWithCount,
            kind: 'expense',
            isDeleteMode: _isDeleteMode,
            selectedCategoryIds: _selectedCategoryIds,
            onToggleSelect: _toggleSelect,
            // 底部操作区随网格一起滚动，位于分类最后一行下方，不常驻页面底部：
            // 正常模式显示"删除分类"入口（带 icon）；删除模式显示"确认删除"+
            // "清空未使用分类"同一行 + 三个删除策略单选项
            footer: _isDeleteMode
                ? _buildDeleteFooter(context, l10n)
                : _buildDeleteCategoryButton(context, l10n),
          ),
        ),
      ],
    );
  }

  /// 模板库入口区：一级/二级模板两个独立按钮（不是头部文字链），
  /// 位于"分类管理"标题之下、长按排序提示之上，删除模式下隐藏。
  Widget _buildTemplateEntries(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildTemplateEntryButton(
              context,
              label: l10n.categoryTemplateEntryFlat,
              icon: AppIcons.viewWeek,
              page: const CategoryTemplateFlatPage(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTemplateEntryButton(
              context,
              label: l10n.categoryTemplateEntryHierarchical,
              icon: AppIcons.checklist,
              page: const CategoryTemplateHierarchicalPage(),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个模板库入口按钮（OutlinedButton 图标+文字，等宽平分整行）
  Widget _buildTemplateEntryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Widget page,
  }) {
    return OutlinedButton.icon(
      onPressed: () =>
          Navigator.of(context).push(appPageRoute(builder: (_) => page)),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: SpitoutTokens.primary(context),
        side: BorderSide(color: SpitoutTokens.borderStrong(context)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ==================== 排序提示 ====================

  /// 长按排序提示行
  Widget _buildReorderHint(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(
            AppIcons.sort,
            size: 15,
            color: SpitoutTokens.textSecondary(context),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.categoryManageReorderHint,
            style: TextStyle(
              fontSize: 10,
              color: SpitoutTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 底部：删除分类入口 ====================

  /// 正常模式底部的"删除分类"入口按钮（带 icon）
  ///
  /// 作为网格 footer 随内容滚动，点击进入删除模式。
  /// 字号与原"清空未使用分类"一致（15），icon 使用删除语义图标。
  Widget _buildDeleteCategoryButton(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Center(
        // 纯动作（进入删除模式），无选中态，按原则补涟漪反馈
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enterDeleteMode,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SpitoutTokens.error(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    AppIcons.delete,
                    size: 18,
                    color: SpitoutTokens.error(context),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.categoryManageDelete,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: SpitoutTokens.error(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 底部：删除模式操作区 ====================

  /// 删除模式底部操作区
  ///
  /// 顶部一行左右排放「确认删除」与「清空未使用分类」：
  /// - "确认删除"：基于复选选中的分类执行删除，0 选中时禁用
  /// - "清空未使用分类"：独立逻辑，不与复选选中关联，直接清空交易数为 0 的分类
  /// 下方为三个删除策略单选项（仅作用于"确认删除"）。
  Widget _buildDeleteFooter(BuildContext context, AppLocalizations l10n) {
    // 0 选中或分类数据未就绪(加载中/失败)时确认删除不可点击:
    // 未就绪时弹窗列表为空,若仍按 _selectedCategoryIds 执行会变成盲删。
    final categoriesAsync = ref.watch(categoriesWithCountProvider);
    final isDisabled =
        _selectedCategoryIds.isEmpty || !categoriesAsync.hasValue;
    final confirmColor = isDisabled
        ? SpitoutTokens.textDisabled(context)
        : SpitoutTokens.error(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 确认删除 + 清空未使用分类：同一行左右排放
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 确认删除（依赖复选选中，0 选中时禁用）
              _buildFooterTextLink(
                context,
                label: l10n.categoryManageConfirmDelete,
                color: confirmColor,
                onTap: isDisabled ? null : _confirmDelete,
              ),
              // 清空未使用分类（独立逻辑，不与复选关联，始终可点击）
              _buildFooterTextLink(
                context,
                label: l10n.categoryClearUnused,
                color: SpitoutTokens.error(context),
                onTap: _clearUnusedCategories,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDeleteOptions(context, l10n),
        ],
      ),
    );
  }

  /// 删除模式底部文字链（15px，与"清空未使用分类"字号一致）
  ///
  /// 纯动作文字链，无选中态，按统一原则补 Material+InkWell 涟漪反馈；
  /// onTap 为 null 时呈禁用态（不响应点击也不显示涟漪）。
  Widget _buildFooterTextLink(
    BuildContext context, {
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // 对称 padding：涟漪在文字四周均匀外扩（参照 TextButton）。
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  /// 删除模式底部的三个删除策略单选项
  Widget _buildDeleteOptions(BuildContext context, AppLocalizations l10n) {
    final options = [
      l10n.categoryDeleteOptionAll,
      l10n.categoryDeleteOptionMigrate,
      l10n.categoryDeleteOptionPromote,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < options.length; i++)
          _buildRadioOption(context, options[i], i == _deleteOption, () {
            setState(() => _deleteOption = i);
          }),
      ],
    );
  }

  /// 单个单选项行
  Widget _buildRadioOption(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final color = isSelected
        ? SpitoutTokens.error(context)
        : SpitoutTokens.textSecondary(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // 单选指示器
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? SpitoutTokens.error(context)
                      : SpitoutTokens.textTertiary(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SpitoutTokens.error(context),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 11, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 删除模式状态管理 ====================

  /// 进入删除模式
  void _enterDeleteMode() {
    setState(() {
      _isDeleteMode = true;
      _selectedCategoryIds.clear();
      _deleteOption = 0;
    });
  }

  /// 退出删除模式
  void _exitDeleteMode() {
    setState(() {
      _isDeleteMode = false;
      _selectedCategoryIds.clear();
    });
  }

  /// 切换分类选中状态
  void _toggleSelect(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  // ==================== 确认删除入口 ====================

  /// 点击"确认删除"按钮
  ///
  /// 根据当前选择的删除策略分流：
  /// - 策略 0/2：弹出确认弹窗，展示待删除分类列表
  /// - 策略 1：弹出迁移目标分类选择 BottomSheet
  Future<void> _confirmDelete() async {
    if (_selectedCategoryIds.isEmpty) return;

    final categoriesWithCount = ref.read(categoriesWithCountProvider).value;
    if (categoriesWithCount == null) {
      // 双保险:按钮已按就绪态禁用,此处再拦一次异常路径(如 provider 出错)。
      if (mounted) {
        showToast(context, AppLocalizations.of(context).commonOperationFailed);
      }
      return;
    }

    if (_deleteOption == 1) {
      // 迁移模式：选择目标分类
      await _showMigrateTargetSheet(categoriesWithCount);
    } else {
      // 删除模式：确认弹窗
      await _showDeleteConfirmDialog(categoriesWithCount);
    }
  }

  // ==================== 删除确认弹窗（策略 0 和 2） ====================

  /// 显示删除确认弹窗
  ///
  /// 弹窗内容根据删除策略不同：
  /// - 策略 0（含二级）：列出一级+二级分类及笔数
  /// - 策略 2（不含二级）：仅列出一级分类及笔数
  Future<void> _showDeleteConfirmDialog(
    List<({db.Category category, int transactionCount})> categoriesWithCount,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selectedCount = _selectedCategoryIds.length;

    // 收集待删除分类信息
    final selectedCategories = categoriesWithCount
        .where(
          (item) =>
              _selectedCategoryIds.contains(item.category.id) &&
              item.category.level == 1,
        )
        .toList();

    // 构建弹窗内容列表
    final listWidgets = <Widget>[];
    for (final item in selectedCategories) {
      final name = CategoryUtils.getDisplayName(item.category.name, context);
      listWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    color: SpitoutTokens.textPrimary(context),
                  ),
                ),
              ),
              Text(
                l10n.categoryMigrationTransactionLabel(item.transactionCount),
                style: TextStyle(
                  fontSize: 12,
                  color: SpitoutTokens.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      );

      // 策略 0（含二级）：展示子分类
      if (_deleteOption == 0) {
        final subCategories = categoriesWithCount
            .where((sub) => sub.category.parentId == item.category.id)
            .toList();
        for (final sub in subCategories) {
          final subName = CategoryUtils.getDisplayName(
            sub.category.name,
            context,
          );
          listWidgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
              child: Row(
                children: [
                  Text(
                    '├─ ',
                    style: TextStyle(
                      fontSize: 12,
                      color: SpitoutTokens.textTertiary(context),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      subName,
                      style: TextStyle(
                        fontSize: 12,
                        color: SpitoutTokens.textSecondary(context),
                      ),
                    ),
                  ),
                  Text(
                    l10n.categoryMigrationTransactionLabel(
                      sub.transactionCount,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: SpitoutTokens.textTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    final subtitle = _deleteOption == 0
        ? l10n.categoryDeleteSelectedSubtitleWithSub(selectedCount)
        : l10n.categoryDeleteSelectedSubtitleWithoutSub(selectedCount);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpitoutTokens.surfaceElevated(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.categoryDeleteSelectedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: SpitoutTokens.textPrimary(context),
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          // 全部待删分类一次性渲染在滚动视图中：内容超出 0.6 倍屏高时弹窗
          // 内部可滑动，保证多选父分类时所有父/子分类都能完整展示；
          // 滚动条常显，让"内容可滑动"可感知，避免用户误判列表被截断。
          // 注意：不能用懒加载的 ListView(shrinkWrap)——AlertDialog 内部用
          // IntrinsicWidth 布局，懒加载视口不支持 intrinsic 测量会抛异常。
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: SpitoutTokens.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...listWidgets,
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: SpitoutTokens.error(context),
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _executeDelete(categoriesWithCount);
  }

  // ==================== 迁移目标选择 BottomSheet（策略 1） ====================

  /// 显示迁移目标分类选择 BottomSheet
  ///
  /// 先过滤出可选目标，再弹共用选择层；选中目标后执行"迁移数据并删除分类"
  Future<void> _showMigrateTargetSheet(
    List<({db.Category category, int transactionCount})> categoriesWithCount,
  ) async {
    final l10n = AppLocalizations.of(context);

    // 排除待删除分类及其子分类，只保留可选的目标分类
    final availableCategories = categoriesWithCount.where((item) {
      // 排除被选中删除的一级分类
      if (_selectedCategoryIds.contains(item.category.id)) return false;
      // 排除被选中删除分类的子分类
      if (item.category.parentId != null &&
          _selectedCategoryIds.contains(item.category.parentId)) {
        return false;
      }
      return item.category.kind == 'expense';
    }).toList();

    if (availableCategories.isEmpty) {
      if (!mounted) return;
      showToast(context, l10n.categoryCannotDelete);
      return;
    }

    // 迁移目标选择弹层（搜索 + 先父后子排列 + 层级标注，与子分类弹窗共用），
    // 返回选中的目标分类 id；直接关闭未选择时返回 null，不执行后续操作。
    final targetId = await showMigrateTargetSheet(
      context,
      availableCategories: availableCategories,
    );
    if (targetId != null && mounted) {
      _executeMigrateAndDelete(categoriesWithCount, targetId);
    }
  }

  // ==================== 执行删除 ====================

  /// 执行删除操作（策略 0 和 2）
  Future<void> _executeDelete(
    List<({db.Category category, int transactionCount})> categoriesWithCount,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selectedIds = _selectedCategoryIds.toList();

    try {
      final repo = ref.read(repositoryProvider);

      if (_deleteOption == 0) {
        // 策略 0：删除分类和分类下的所有数据（含二级）
        // 1. 收集所有分类 ID（一级 + 其子分类）
        final allCategoryIds = <int>[...selectedIds];
        for (final id in selectedIds) {
          final subCategories = categoriesWithCount
              .where((item) => item.category.parentId == id)
              .map((item) => item.category.id);
          allCategoryIds.addAll(subCategories);
        }
        // 2. 删除这些分类下的所有交易
        await repo.deleteTransactionsByCategoryIds(allCategoryIds);
        // 3. 删除分类记录（含子分类）
        await repo.deleteCategoriesByIds(selectedIds);
      } else {
        // 策略 2：删除分类和分类下的所有数据（不含二级，二级变一级）
        // 1. 删除一级分类自身的直接交易
        await repo.deleteTransactionsByCategoryIds(selectedIds);
        // 2. 提升子分类为一级分类
        for (final id in selectedIds) {
          await repo.promoteSubCategoriesToTopLevel(id);
        }
        // 3. 删除一级分类记录（子分类已脱离，不会被连带删除）
        await repo.deleteCategoriesByIds(selectedIds);
      }

      // 推送到云端同步
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }

      if (!mounted) return;
      showToast(context, l10n.categoryClearUnusedSuccess(selectedIds.length));
      ref.invalidate(categoriesWithCountProvider);
      _exitDeleteMode();
    } catch (e) {
      logger.error('CategoryManage', '批量删除分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryDeleteError);
    }
  }

  /// 执行迁移并删除（策略 1）
  ///
  /// 两步操作：先迁移数据到目标分类，再删除源分类
  Future<void> _executeMigrateAndDelete(
    List<({db.Category category, int transactionCount})> categoriesWithCount,
    int targetCategoryId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selectedIds = _selectedCategoryIds.toList();

    try {
      final repo = ref.read(repositoryProvider);

      // 1. 逐个迁移分类数据到目标分类（交易 + 子分类）
      for (final id in selectedIds) {
        await repo.migrateCategoryTransactions(
          fromCategoryId: id,
          toCategoryId: targetCategoryId,
        );
      }
      // 2. 删除已迁移的源分类
      await repo.deleteCategoriesByIds(selectedIds);

      // 推送到云端同步
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }

      if (!mounted) return;
      showToast(context, l10n.categoryClearUnusedSuccess(selectedIds.length));
      ref.invalidate(categoriesWithCountProvider);
      _exitDeleteMode();
    } catch (e) {
      logger.error('CategoryManage', '迁移并删除分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryDeleteError);
    }
  }

  // ==================== 添加分类 ====================

  /// 跳转到新增分类页面
  void _addCategory() async {
    await Navigator.of(context).push(
      appPageRoute(builder: (_) => const CategoryEditPage(kind: 'expense')),
    );
  }

  // ==================== 清空未使用分类 ====================

  /// 清空未使用的分类（交易数为 0 的分类）
  Future<void> _clearUnusedCategories() async {
    final l10n = AppLocalizations.of(context);
    final categoriesWithCount =
        ref.read(categoriesWithCountProvider).value ?? [];

    // 找出交易数为 0 的分类（统计已包含子分类交易数）
    final unusedCategories = categoriesWithCount
        .where((item) => item.transactionCount == 0)
        .toList();

    if (unusedCategories.isEmpty) {
      showToast(context, l10n.categoryClearUnusedEmpty);
      return;
    }

    // 收集将被删除的分类信息（包括子分类）
    final toDeleteList = <String>[];
    for (final item in unusedCategories) {
      final categoryName = CategoryUtils.getDisplayName(
        item.category.name,
        context,
      );
      toDeleteList.add(categoryName);

      // 如果是父分类，添加其所有将被删除的子分类
      if (item.category.level == 1) {
        final children = unusedCategories
            .where((c) => c.category.parentId == item.category.id)
            .toList();
        for (final child in children) {
          final childName = CategoryUtils.getDisplayName(
            child.category.name,
            context,
          );
          toDeleteList.add('  ├─ $childName');
        }
      }
    }

    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.categoryClearUnusedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.categoryClearUnusedMessage(unusedCategories.length)),
            const SizedBox(height: 16),
            Text(
              l10n.categoryClearUnusedListTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(toDeleteList.join('\n'), style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      final ids = unusedCategories.map((item) => item.category.id).toList();
      await repo.deleteCategoriesByIds(ids);

      // 把批量删除推到服务端（分类是 user-scoped ledgerId=0 变更）
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }

      if (!mounted) return;
      showToast(context, l10n.categoryClearUnusedSuccess(ids.length));
      ref.invalidate(categoriesWithCountProvider);
    } catch (e) {
      logger.error('CategoryManage', '清空未使用分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryClearUnusedFailed);
    }
  }
}

// ==================== 分类网格 ====================

/// 分类网格视图
///
/// 正常模式：可长按拖拽排序，点击进入编辑/子分类对话框
/// 删除模式：显示复选框，点击切换选中状态
class _CategoryGridView extends ConsumerStatefulWidget {
  final List<({db.Category category, int transactionCount})>
  categoriesWithCount;
  final String kind;

  /// 是否处于删除模式
  final bool isDeleteMode;

  /// 删除模式下选中的分类 ID 集合
  final Set<int> selectedCategoryIds;

  /// 切换选中状态的回调
  final void Function(int categoryId) onToggleSelect;

  /// 底部操作区：作为网格最后一行之后的 footer，随网格一起滚动
  /// （不常驻页面底部）
  final Widget? footer;

  const _CategoryGridView({
    required this.categoriesWithCount,
    required this.kind,
    required this.isDeleteMode,
    required this.selectedCategoryIds,
    required this.onToggleSelect,
    this.footer,
  });

  @override
  ConsumerState<_CategoryGridView> createState() => _CategoryGridViewState();
}

class _CategoryGridViewState extends ConsumerState<_CategoryGridView> {
  List<_CategoryItem> _flatList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_CategoryGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categoriesWithCount != oldWidget.categoriesWithCount ||
        widget.kind != oldWidget.kind) {
      _loadData();
    }
  }

  /// 加载数据：只构建一级分类列表，从已有数据判断是否有子分类
  void _loadData() {
    // 获取当前类型的一级分类
    final topLevelCategories = widget.categoriesWithCount
        .where(
          (item) =>
              item.category.kind == widget.kind && item.category.level == 1,
        )
        .toList();

    // 按 sortOrder 排序
    topLevelCategories.sort(
      (a, b) => a.category.sortOrder.compareTo(b.category.sortOrder),
    );

    // 构建父分类 ID 集合，用于快速判断是否有子分类
    final parentIds = widget.categoriesWithCount
        .where((item) => item.category.parentId != null)
        .map((item) => item.category.parentId!)
        .toSet();

    final flatList = <_CategoryItem>[];

    for (final topItem in topLevelCategories) {
      // 直接从内存数据判断是否有子分类
      final hasSubCategories = parentIds.contains(topItem.category.id);

      // transactionCount 已经包含了所有子分类的交易数，不需要再累加
      flatList.add(
        _CategoryItem(
          category: topItem.category,
          transactionCount: topItem.transactionCount,
          isDefault: false,
          isSubCategory: false,
          hasSubCategories: hasSubCategories,
        ),
      );
    }

    setState(() {
      _flatList = flatList;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 数据还未加载完成
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 过滤出一级分类
    final topLevelCategories = _flatList
        .where((item) => !item.isSubCategory)
        .toList();

    if (topLevelCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.category,
              size: 64,
              color: SpitoutTokens.textTertiary(context),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).categoryEmpty,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: SpitoutTokens.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    // 删除模式下不启用拖拽排序。
    // 两种模式统一用 CustomScrollView + Sliver 网格 + SliverToBoxAdapter(footer)，
    // 让底部操作区跟在分类最后一行之后随内容一起滚动，而不是常驻页面底部。
    if (widget.isDeleteMode) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = topLevelCategories[index];
                return _CategoryCard(
                  key: ValueKey(item.category.id),
                  item: item,
                  isDeleteMode: true,
                  isSelected: widget.selectedCategoryIds.contains(
                    item.category.id,
                  ),
                  onTap: () => widget.onToggleSelect(item.category.id),
                );
              }, childCount: topLevelCategories.length),
            ),
          ),
          if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ReorderableSliverGridView(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
            // 自定义拖拽中的卡片外观：包默认用 Material(elevation: 3) 包裹，
            // 会在圆角卡片底部衬出一个方形背景；用透明 Material 不绘制该背景，
            // 拖拽时只呈现卡片自身的圆角样式。
            dragWidgetBuilderV2: DragWidgetBuilderV2(
              builder: (index, child, screenshot) =>
                  Material(type: MaterialType.transparency, child: child),
            ),
            onReorder: (oldIndex, newIndex) {
              _onReorderTopLevel(oldIndex, newIndex, topLevelCategories);
            },
            children: [
              for (final item in topLevelCategories)
                _CategoryCard(
                  key: ValueKey(item.category.id),
                  item: item,
                  isDeleteMode: false,
                  isSelected: false,
                  onTap: () => _onCategoryTap(item),
                ),
            ],
          ),
        ),
        if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
      ],
    );
  }

  /// 拖拽排序后批量更新 sortOrder。
  ///
  /// 注意：reorderable_grid_view 的 onReorder 回调中 newIndex 已是「直接插入位置」，
  /// 与原生 ReorderableListView（newIndex 为移除拖拽项后的下标）语义不同，
  /// 切勿再做 `if (oldIndex < newIndex) newIndex -= 1` 的修正，
  /// 否则向右相邻一格拖拽会变成 remove 后原样 insert，表现为「移动失败、跳回原位」。
  Future<void> _onReorderTopLevel(
    int oldIndex,
    int newIndex,
    List<_CategoryItem> topLevelCategories,
  ) async {
    // 同步获取文案，避免在异步 gap 后跨 BuildContext 读取
    final l10n = AppLocalizations.of(context);
    final failMessage = l10n.categorySortSaveFailed;

    // 1. 先乐观更新本地状态（reorderable_grid_view 的 newIndex 即为插入位置，无需减 1），
    //    保证 UI 立即响应拖拽、不回跳。
    final reorderedItems = List<_CategoryItem>.from(topLevelCategories);
    final movedItem = reorderedItems.removeAt(oldIndex);
    reorderedItems.insert(newIndex, movedItem);

    // 重建 _flatList，保持一级分类的新顺序
    setState(() {
      _flatList = reorderedItems;
    });

    try {
      // 2. 批量保存到数据库
      final repo = ref.read(repositoryProvider);
      final updates = reorderedItems.asMap().entries.map((entry) {
        return (id: entry.value.category.id, sortOrder: entry.key);
      }).toList();
      await repo.updateCategorySortOrders(updates);

      // 拖拽排序也记了 ChangeTracker 变更，推到云端让 web 的 sortOrder 一致
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }

      // 3. 刷新 provider 以同步其他地方的数据
      ref.invalidate(categoriesWithCountProvider);
    } catch (e, stack) {
      // 记录详细错误日志，便于排查排序保存失败的原因
      logger.error('CategoryManage', '拖拽排序一级分类失败', e, stack);
      // 保存失败时回滚乐观更新，恢复拖拽前的顺序，避免 UI 与数据库不一致
      if (mounted) {
        setState(() {
          _flatList = List<_CategoryItem>.from(topLevelCategories);
        });
        // 向用户展示友好的错误提示
        showToast(context, failMessage);
      }
    }
  }

  /// 点击分类卡片
  ///
  /// 有子分类：弹出子分类对话框
  /// 无子分类：直接进入编辑
  void _onCategoryTap(_CategoryItem item) async {
    if (item.isSubCategory) {
      await _onEditCategory(item.category);
    } else {
      if (item.hasSubCategories) {
        // 有子分类：弹出对话框
        await _showSubcategoryDialog(item.category);
      } else {
        // 无子分类：直接编辑
        await _onEditCategory(item.category);
      }
    }
  }

  /// 显示子分类对话框
  Future<void> _showSubcategoryDialog(db.Category parentCategory) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _SubcategoryDialog(
        parentCategory: parentCategory,
        categoriesWithCount: widget.categoriesWithCount,
        onSubCategoryTap: (cat) {
          Navigator.pop(dialogContext);
          _onEditCategory(cat);
        },
        onAddSubCategory: () {
          Navigator.pop(dialogContext);
          _onAddSubCategory(parentCategory);
        },
        onEditParentCategory: () {
          Navigator.pop(dialogContext);
          _onEditCategory(parentCategory);
        },
      ),
    );
  }

  /// 跳转到分类编辑页
  Future<void> _onEditCategory(db.Category category) async {
    await Navigator.of(context).push(
      appPageRoute(
        builder: (_) =>
            CategoryEditPage(category: category, kind: category.kind),
      ),
    );
  }

  /// 跳转到新增子分类页
  Future<void> _onAddSubCategory(db.Category parent) async {
    await Navigator.of(context).push(
      appPageRoute(
        builder: (_) =>
            CategoryEditPage(kind: parent.kind, parentCategory: parent),
      ),
    );
    _loadData();
  }
}

/// 分类项数据模型
class _CategoryItem {
  final db.Category category;
  final int transactionCount;
  final bool isDefault;
  final bool isSubCategory;
  final bool hasSubCategories;

  _CategoryItem({
    required this.category,
    required this.transactionCount,
    required this.isDefault,
    required this.isSubCategory,
    this.hasSubCategories = false,
  });
}

/// 分类卡片
///
/// 正常模式：展示图标、名称、笔数；有子分类的一级分类右下角显示指示器
/// 删除模式：右上角显示复选框，点击切换选中状态
class _CategoryCard extends ConsumerWidget {
  final _CategoryItem item;
  final VoidCallback onTap;

  /// 是否处于删除模式
  final bool isDeleteMode;

  /// 删除模式下是否被选中
  final bool isSelected;

  const _CategoryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.isDeleteMode,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 二级分类：使用浅色背景
    final backgroundColor = item.isSubCategory
        ? Colors.orange[50]
        : Theme.of(context).colorScheme.surface;

    // 选中状态：边框高亮
    final borderColor = isSelected
        ? SpitoutTokens.error(context)
        : (item.isSubCategory
              ? Colors.orange.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: item.isSubCategory ? 28 : 32,
                    height: item.isSubCategory ? 28 : 32,
                    decoration: BoxDecoration(
                      color: item.isSubCategory
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: CategoryIconWidget(
                      category: item.category,
                      size: item.isSubCategory ? 16.0 : 18.0,
                      color: item.isSubCategory
                          ? Colors.orange[700]!
                          : Theme.of(context).colorScheme.primary,
                      circular: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      CategoryUtils.getDisplayName(item.category.name, context),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: item.isSubCategory ? 10 : 12,
                        color: item.isSubCategory ? Colors.orange[900] : null,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).categoryMigrationTransactionLabel(item.transactionCount),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: item.isSubCategory
                          ? Colors.orange[700]
                          : Theme.of(context).colorScheme.outline,
                      fontSize: item.isSubCategory ? 9 : 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // 删除模式：右上角复选框
            if (isDeleteMode)
              Positioned(
                right: 4,
                top: 4,
                child: _DeleteModeCheckbox(isSelected: isSelected),
              ),
            // 正常模式：有子分类的一级分类右下角显示指示器
            if (!isDeleteMode && !item.isSubCategory && item.hasSubCategories)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AppIcons.moreHorizontal,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 删除模式复选框（管理页一级分类网格与子分类弹窗共用）
///
/// 选中态：实心 error 圆 + 白色勾选图标；未选中态：空心圆。
class _DeleteModeCheckbox extends StatelessWidget {
  /// 是否被选中
  final bool isSelected;

  const _DeleteModeCheckbox({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final errorColor = SpitoutTokens.error(context);

    if (isSelected) {
      // 选中态：实心圆 + 勾选图标
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: errorColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.check, size: 12, color: Colors.white),
      );
    }

    // 未选中态：空心圆
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: SpitoutTokens.surfaceChip(context),
        shape: BoxShape.circle,
        border: Border.all(
          color: SpitoutTokens.borderStrong(context),
          width: 1.5,
        ),
      ),
    );
  }
}

// ==================== 迁移目标选择 BottomSheet（共用） ====================

/// 显示迁移目标分类选择 BottomSheet（管理页一级分类迁移与子分类弹窗迁移共用）
///
/// - 顶部搜索框：按分类显示名过滤（大小写不敏感）
/// - 排列顺序：先父后子——列完一个一级分类及其全部二级分类，再列下一个
/// - 每个分类标注层级：一级分类 / 二级·所属父分类名
///
/// 返回选中的目标分类 id；未选择直接关闭时返回 null。
Future<int?> showMigrateTargetSheet(
  BuildContext context, {
  required List<({db.Category category, int transactionCount})>
  availableCategories,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SpitoutTokens.surfaceSheet(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    // 全局统一上滑动画：线性曲线（无加速减速），时长与页面切换一致。
    sheetAnimationStyle: kSheetAnimationStyle,
    builder: (sheetContext) {
      return _MigrateTargetSheet(availableCategories: availableCategories);
    },
  );
}

/// 迁移目标选择 BottomSheet 内容：搜索框 + 父子排序网格 + 确定按钮
class _MigrateTargetSheet extends StatefulWidget {
  /// 可选的迁移目标分类（调用方已完成排除过滤）
  final List<({db.Category category, int transactionCount})>
  availableCategories;

  const _MigrateTargetSheet({required this.availableCategories});

  @override
  State<_MigrateTargetSheet> createState() => _MigrateTargetSheetState();
}

class _MigrateTargetSheetState extends State<_MigrateTargetSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  int? _selectedTargetId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 父 → 子 有序排列：每个一级分类后紧跟其全部二级分类，再排下一个一级分类；
  /// 同级内部按 sortOrder 排序，与分类管理页展示顺序保持一致。
  List<({db.Category category, int transactionCount})> _buildOrderedList() {
    final all = widget.availableCategories;
    final parents = all.where((i) => i.category.level == 1).toList()
      ..sort((a, b) => a.category.sortOrder.compareTo(b.category.sortOrder));

    final ordered = <({db.Category category, int transactionCount})>[];
    for (final parent in parents) {
      ordered.add(parent);
      final children =
          all.where((i) => i.category.parentId == parent.category.id).toList()
            ..sort(
              (a, b) => a.category.sortOrder.compareTo(b.category.sortOrder),
            );
      ordered.addAll(children);
    }
    return ordered;
  }

  /// 按搜索词过滤（对本地化显示名做包含匹配）；命中项仍保持父 → 子 相对顺序
  List<({db.Category category, int transactionCount})> _filteredList() {
    final ordered = _buildOrderedList();
    if (_searchText.isEmpty) return ordered;
    return ordered.where((i) {
      final name = CategoryUtils.getDisplayName(
        i.category.name,
        context,
      ).toLowerCase();
      return name.contains(_searchText);
    }).toList();
  }

  /// 查子分类所属父分类的本地化显示名（层级标注"二级 · 父名"用）。
  /// 调用方的过滤规则保证候选中子分类的父必定同在候选内。
  String _parentDisplayName(int parentId) {
    for (final i in widget.availableCategories) {
      if (i.category.id == parentId) {
        return CategoryUtils.getDisplayName(i.category.name, context);
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filteredList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Text(
            l10n.categoryMigrateSelectTargetTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SpitoutTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          // 搜索框（样式对齐所属分类选择弹窗：圆角浅底 + 搜索图标 + 清除按钮）
          Container(
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceSecondary(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.categorySearchCategory,
                hintStyle: TextStyle(
                  color: SpitoutTokens.textSecondary(context),
                ),
                prefixIcon: Icon(
                  AppIcons.search,
                  size: 18,
                  color: SpitoutTokens.iconTertiary(context),
                ),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: Icon(
                          AppIcons.close,
                          size: 18,
                          color: SpitoutTokens.iconTertiary(context),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 分类网格（先父后子：列完一个分类的全部再列下个分类）
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: filtered.map((item) {
                  final isSelected = _selectedTargetId == item.category.id;
                  final category = item.category;
                  return _MigrateCategoryChip(
                    item: item,
                    isSelected: isSelected,
                    // 层级标注：一级分类 / 二级 · 所属父分类名
                    badgeLabel: category.level == 1
                        ? l10n.categoryTopLevelLabel
                        : l10n.categoryMigrateChildLabel(
                            _parentDisplayName(category.parentId ?? 0),
                          ),
                    onTap: () => setState(() {
                      _selectedTargetId = category.id;
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 确定按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedTargetId == null
                  ? null
                  : () => Navigator.pop(context, _selectedTargetId),
              style: FilledButton.styleFrom(
                backgroundColor: SpitoutTokens.error(context),
                disabledBackgroundColor: SpitoutTokens.buttonDisabled(context),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                l10n.categoryMigrateConfirmButton,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 迁移目标 BottomSheet 中的单个分类选项卡片
/// （管理页一级分类迁移与子分类弹窗迁移共用）
class _MigrateCategoryChip extends StatelessWidget {
  final ({db.Category category, int transactionCount}) item;

  /// 是否为当前选中的迁移目标
  final bool isSelected;
  final VoidCallback onTap;

  /// 层级标注：一级分类显示"一级分类"，二级分类显示"二级 · 所属父分类名"
  final String badgeLabel;

  const _MigrateCategoryChip({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isSub = item.category.level == 2;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? SpitoutTokens.surfaceSelected(context)
              : SpitoutTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : SpitoutTokens.borderStrong(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: isSub ? 28 : 32,
              height: isSub ? 28 : 32,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CategoryIconWidget(
                category: item.category,
                size: isSub ? 16.0 : 18.0,
                color: primaryColor,
                circular: true,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              CategoryUtils.getDisplayName(item.category.name, context),
              style: TextStyle(
                fontSize: isSub ? 10 : 11,
                color: SpitoutTokens.textPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // 层级标注行（一级/二级·父名），与笔数行区分用更弱的三级文字色
            Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 9,
                color: SpitoutTokens.textTertiary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              AppLocalizations.of(
                context,
              ).categoryMigrationTransactionLabel(item.transactionCount),
              style: TextStyle(
                fontSize: 9,
                color: SpitoutTokens.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 子分类对话框 ====================

/// 子分类对话框
///
/// 正常模式：标题旁"编辑父分类"文字链，网格展示子分类，
/// 底部"添加子分类"/"删除子分类"文字链。
/// 删除模式：卡片右上角显示复选框，底部"确认删除" + 两个删除策略单选项
/// （删除全部数据 / 迁移数据后删除），逻辑与本页分类管理的删除模式一致。
class _SubcategoryDialog extends ConsumerStatefulWidget {
  final db.Category parentCategory;
  final List<({db.Category category, int transactionCount})>
  categoriesWithCount;
  final Function(db.Category) onSubCategoryTap;
  final VoidCallback onAddSubCategory;
  final VoidCallback onEditParentCategory;

  const _SubcategoryDialog({
    required this.parentCategory,
    required this.categoriesWithCount,
    required this.onSubCategoryTap,
    required this.onAddSubCategory,
    required this.onEditParentCategory,
  });

  @override
  ConsumerState<_SubcategoryDialog> createState() => _SubcategoryDialogState();
}

class _SubcategoryDialogState extends ConsumerState<_SubcategoryDialog> {
  List<({db.Category category, int transactionCount})>? _subCategories;
  bool _isLoading = true;

  /// 加载失败标志:失败时展示重试入口,避免弹窗永久转圈。
  bool _loadFailed = false;

  /// 是否处于删除模式
  bool _isDeleteMode = false;

  /// 删除模式下选中的子分类 ID 集合
  final Set<int> _selectedCategoryIds = {};

  /// 删除策略：0=删除分类和分类下的所有数据, 1=迁移数据到其他分类后删除
  /// （二级分类无子级，不适用管理页的"提升子分类"策略，仅两个选项）
  int _deleteOption = 0;

  @override
  void initState() {
    super.initState();
    _loadSubCategories();
  }

  /// 异步加载子分类列表及其交易笔数
  ///
  /// 笔数优先取 provider 最新值（删除刷新后仍能拿到正确笔数），
  /// provider 未就绪时回退到打开弹窗时传入的快照。
  Future<void> _loadSubCategories() async {
    try {
      final repo = ref.read(repositoryProvider);
      final subCategories = await repo.getSubCategories(
        widget.parentCategory.id,
      );

      final countsSource =
          ref.read(categoriesWithCountProvider).value ??
          widget.categoriesWithCount;
      final result = <({db.Category category, int transactionCount})>[];
      for (final subCat in subCategories) {
        final subCount = countsSource
            .firstWhere(
              (item) => item.category.id == subCat.id,
              orElse: () => (category: subCat, transactionCount: 0),
            )
            .transactionCount;
        result.add((category: subCat, transactionCount: subCount));
      }

      if (mounted) {
        setState(() {
          _subCategories = result;
          _isLoading = false;
          _loadFailed = false;
        });
      }
    } catch (e, st) {
      // 加载失败进入失败态,用户可点重试重新查询。
      logger.error(
        'CategoryManage',
        '加载子分类失败 parentId=${widget.parentCategory.id}',
        e,
        st,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  /// 子分类弹窗内拖拽排序后的处理。
  ///
  /// 注意：reorderable_grid_view 的 newIndex 为「直接插入位置」，无需做减 1 修正。
  void _onReorderSubCategory(int oldIndex, int newIndex) {
    if (_subCategories == null) return;

    // 1. 乐观更新本地列表顺序，立即刷新弹窗网格
    final reordered = List<({db.Category category, int transactionCount})>.from(
      _subCategories!,
    );
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() {
      _subCategories = reordered;
    });

    // 2. 持久化 + 云同步（失败仅提示，不回滚本地顺序以免打断连续拖拽）
    _persistSubCategoryOrder(reordered);
  }

  /// 将子分类的新顺序写入数据库，并触发云同步
  Future<void> _persistSubCategoryOrder(
    List<({db.Category category, int transactionCount})> ordered,
  ) async {
    // 同步获取文案，避免在异步 gap 后跨 BuildContext 读取
    final l10n = AppLocalizations.of(context);
    final failMessage = l10n.categorySortSaveFailed;
    try {
      final repo = ref.read(repositoryProvider);
      final updates = ordered.asMap().entries.map((entry) {
        return (id: entry.value.category.id, sortOrder: entry.key);
      }).toList();
      await repo.updateCategorySortOrders(updates);

      // 排序变更推到云端，保持 web 端 sortOrder 一致
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
    } catch (e, stack) {
      // 记录详细错误日志，便于排查子分类排序保存失败的原因
      logger.error('SubcategoryDialog', '拖拽排序子分类失败', e, stack);
      // 向用户展示友好的错误提示
      if (mounted) {
        showToast(context, failMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, l10n, primaryColor),
            const SizedBox(height: 16),
            // 内容区域
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadFailed)
              // 失败态:提示重试,避免弹窗永久转圈。
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.commonOperationFailed,
                        style: TextStyle(
                          color: SpitoutTokens.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _loadFailed = false;
                          });
                          _loadSubCategories();
                        },
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              )
            else if (_subCategories?.isEmpty ?? true)
              // 空态：全部子分类被删除后保留弹窗，便于继续添加
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    l10n.subcategoryEmpty,
                    style: TextStyle(
                      color: SpitoutTokens.textTertiary(context),
                    ),
                  ),
                ),
              )
            else
              // 网格限高可滚，避免子分类过多导致弹窗溢出屏幕
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 正常模式下展示长按排序提示，与一级分类管理页保持一致
                  if (!_isDeleteMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.sort,
                            size: 15,
                            color: SpitoutTokens.textSecondary(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.categoryManageReorderHint,
                            style: TextStyle(
                              fontSize: 10,
                              color: SpitoutTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ReorderableGridView.builder(
                      // shrinkWrap: 让网格高度随子分类数量自适应。
                      // 设计意图：上方 maxHeight 是"上限"，网格内容不足时收紧到实际
                      // 高度（弹窗随子分类数量自适应），只有超出上限时才在限高内
                      // 滚动。不写 shrinkWrap 时网格会恒占满 maxHeight，导致只有
                      // 一两个子分类也撑满半屏、留白突兀。
                      shrinkWrap: true,
                      // 删除模式下禁用拖拽（仅用于点击切换选中），正常模式可长按拖拽排序
                      dragEnabled: !_isDeleteMode,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                      itemCount: _subCategories!.length,
                      itemBuilder: (context, index) {
                        final item = _subCategories![index];
                        return _DialogSubCategoryCard(
                          key: ValueKey(item.category.id),
                          category: item.category,
                          transactionCount: item.transactionCount,
                          isDeleteMode: _isDeleteMode,
                          isSelected: _selectedCategoryIds.contains(
                            item.category.id,
                          ),
                          onTap: () {
                            if (_isDeleteMode) {
                              _toggleSelect(item.category.id);
                            } else {
                              widget.onSubCategoryTap(item.category);
                            }
                          },
                        );
                      },
                      // 不绘制拖拽时默认的白底方块背景，保持卡片原样
                      dragWidgetBuilderV2: DragWidgetBuilderV2(
                        builder: (index, child, screenshot) =>
                            Material(color: Colors.transparent, child: child),
                      ),
                      onReorder: (oldIndex, newIndex) {
                        _onReorderSubCategory(oldIndex, newIndex);
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // 底部：正常模式双文字链；删除模式"确认删除" + 删除策略单选项
            if (_isDeleteMode)
              _buildDeleteModeFooter(context, l10n)
            else
              _buildNormalFooter(context, l10n),
          ],
        ),
      ),
    );
  }

  // ==================== 标题栏 ====================

  /// 标题栏：父分类图标 + 名称 + "编辑父分类"文字链（删除模式隐藏）+ 关闭按钮
  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    Color primaryColor,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: CategoryIconWidget(
            category: widget.parentCategory,
            size: 18,
            color: primaryColor,
            circular: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              // 名称过长时省略，避免挤压关闭按钮
              Flexible(
                child: Text(
                  CategoryUtils.getDisplayName(
                    widget.parentCategory.name,
                    context,
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 删除模式隐藏编辑入口，专注删除操作
              if (!_isDeleteMode) ...[
                const SizedBox(width: 8),
                _buildTextLink(
                  context,
                  label: l10n.subcategoryEditParent,
                  color: SpitoutTokens.textLink(context),
                  onTap: widget.onEditParentCategory,
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.close),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  // ==================== 底部区域 ====================

  /// 正常模式底部："添加子分类" / "删除子分类" 文字链
  Widget _buildNormalFooter(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildTextLink(
          context,
          label: l10n.subcategoryAdd,
          color: SpitoutTokens.textLink(context),
          onTap: widget.onAddSubCategory,
        ),
        _buildTextLink(
          context,
          label: l10n.subcategoryDelete,
          color: SpitoutTokens.error(context),
          onTap: _enterDeleteMode,
        ),
      ],
    );
  }

  /// 删除模式底部："确认删除"（居中）+ 两个删除策略单选项
  ///
  /// 布局顺序：确认删除在上、单选项在下。
  Widget _buildDeleteModeFooter(BuildContext context, AppLocalizations l10n) {
    // 0 选中时确认删除不可点击（禁用色 + 不响应点击）
    final isDisabled = _selectedCategoryIds.isEmpty;
    final confirmColor = isDisabled
        ? SpitoutTokens.textDisabled(context)
        : SpitoutTokens.error(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: _buildTextLink(
            context,
            label: l10n.categoryManageConfirmDelete,
            color: confirmColor,
            onTap: isDisabled ? null : _confirmDelete,
          ),
        ),
        const SizedBox(height: 8),
        _buildRadioOption(context, l10n.subcategoryDeleteOptionAll, 0),
        _buildRadioOption(context, l10n.subcategoryDeleteOptionMigrate, 1),
      ],
    );
  }

  /// 文字链按钮（13px + 下划线，与分类管理页头部文字链同款）
  /// 文字链按钮（13px + 下划线，与分类管理页头部文字链同款）。
  ///
  /// 纯动作（编辑父分类/添加子分类/删除子分类/确认删除），无选中态，
  /// 按统一原则使用 Material+InkWell 提供涟漪点击反馈。
  Widget _buildTextLink(
    BuildContext context, {
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // 对称 padding：涟漪在文字四周均匀外扩（参照 TextButton）。
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  /// 单个单选项行（样式与分类管理页删除模式一致：圆点单选，选中 error 色）
  Widget _buildRadioOption(BuildContext context, String label, int value) {
    final isSelected = _deleteOption == value;
    final color = isSelected
        ? SpitoutTokens.error(context)
        : SpitoutTokens.textSecondary(context);

    return InkWell(
      onTap: () => setState(() => _deleteOption = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // 单选指示器
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? SpitoutTokens.error(context)
                      : SpitoutTokens.textTertiary(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SpitoutTokens.error(context),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 11, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 删除模式状态管理 ====================

  /// 进入删除模式
  void _enterDeleteMode() {
    setState(() {
      _isDeleteMode = true;
      _selectedCategoryIds.clear();
      _deleteOption = 0;
    });
  }

  /// 退出删除模式
  void _exitDeleteMode() {
    setState(() {
      _isDeleteMode = false;
      _selectedCategoryIds.clear();
    });
  }

  /// 切换子分类选中状态
  void _toggleSelect(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  // ==================== 确认删除入口 ====================

  /// 点击"确认删除"按钮
  ///
  /// 根据当前选择的删除策略分流：
  /// - 策略 0：弹出确认弹窗，展示待删除子分类列表
  /// - 策略 1：弹出迁移目标分类选择 BottomSheet
  Future<void> _confirmDelete() async {
    if (_selectedCategoryIds.isEmpty) return;

    if (_deleteOption == 1) {
      await _showMigrateTargetSheet();
    } else {
      await _showDeleteConfirmDialog();
    }
  }

  // ==================== 删除确认弹窗（策略 0） ====================

  /// 显示删除确认弹窗：列出全部选中的待删除子分类及各自笔数
  Future<void> _showDeleteConfirmDialog() async {
    final l10n = AppLocalizations.of(context);
    final selectedCount = _selectedCategoryIds.length;

    // 收集待删除子分类信息（保持网格中的展示顺序）
    final selectedItems = (_subCategories ?? [])
        .where((item) => _selectedCategoryIds.contains(item.category.id))
        .toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpitoutTokens.surfaceElevated(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.categoryDeleteSelectedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: SpitoutTokens.textPrimary(dialogContext),
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.subcategoryDeleteSelectedSubtitle(selectedCount),
                  style: TextStyle(
                    fontSize: 13,
                    color: SpitoutTokens.textSecondary(dialogContext),
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in selectedItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            CategoryUtils.getDisplayName(
                              item.category.name,
                              dialogContext,
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: SpitoutTokens.textPrimary(dialogContext),
                            ),
                          ),
                        ),
                        Text(
                          l10n.categoryMigrationTransactionLabel(
                            item.transactionCount,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: SpitoutTokens.textSecondary(dialogContext),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: SpitoutTokens.error(dialogContext),
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _executeDelete();
  }

  // ==================== 迁移目标选择 BottomSheet（策略 1） ====================

  /// 显示迁移目标分类选择 BottomSheet
  ///
  /// 排除选中的待删除子分类，其余 expense 分类（含父分类与其他子分类）
  /// 均可作为迁移目标；弹层与管理页共用，选中后执行"迁移数据并删除分类"。
  Future<void> _showMigrateTargetSheet() async {
    final l10n = AppLocalizations.of(context);

    // 取最新分类数据；排除待删除的子分类自身
    final countsSource =
        ref.read(categoriesWithCountProvider).value ??
        widget.categoriesWithCount;
    final availableCategories = countsSource.where((item) {
      if (_selectedCategoryIds.contains(item.category.id)) return false;
      return item.category.kind == 'expense';
    }).toList();

    if (availableCategories.isEmpty) {
      if (!mounted) return;
      showToast(context, l10n.categoryCannotDelete);
      return;
    }

    // 与管理页共用的迁移目标选择弹层，返回选中的目标分类 id；
    // 直接关闭未选择时返回 null，不执行后续操作。
    final targetId = await showMigrateTargetSheet(
      context,
      availableCategories: availableCategories,
    );
    if (targetId != null && mounted) {
      _executeMigrateAndDelete(targetId);
    }
  }

  // ==================== 执行删除 ====================

  /// 执行删除（策略 0）：先删子分类下的交易，再删子分类记录
  Future<void> _executeDelete() async {
    final l10n = AppLocalizations.of(context);
    final selectedIds = _selectedCategoryIds.toList();

    try {
      final repo = ref.read(repositoryProvider);
      await repo.deleteTransactionsByCategoryIds(selectedIds);
      await repo.deleteCategoriesByIds(selectedIds);
      await _afterMutation(selectedIds.length);
    } catch (e) {
      logger.error('SubcategoryDialog', '批量删除子分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryDeleteError);
    }
  }

  /// 执行迁移并删除（策略 1）：先迁移数据到目标分类，再删除源子分类
  Future<void> _executeMigrateAndDelete(int targetCategoryId) async {
    final l10n = AppLocalizations.of(context);
    final selectedIds = _selectedCategoryIds.toList();

    try {
      final repo = ref.read(repositoryProvider);
      // 1. 逐个迁移子分类交易到目标分类（二级分类无子级，仅迁移交易）
      for (final id in selectedIds) {
        await repo.migrateCategoryTransactions(
          fromCategoryId: id,
          toCategoryId: targetCategoryId,
        );
      }
      // 2. 删除已迁移的源子分类
      await repo.deleteCategoriesByIds(selectedIds);
      await _afterMutation(selectedIds.length);
    } catch (e) {
      logger.error('SubcategoryDialog', '迁移并删除子分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryDeleteError);
    }
  }

  /// 删除/迁移成功后的统一收尾：
  /// 云端同步 → toast 提示 → 刷新管理页数据 → 退出删除模式并重载列表
  Future<void> _afterMutation(int deletedCount) async {
    final l10n = AppLocalizations.of(context);

    // 推送到云端同步
    final activeLedgerId = ref.read(currentLedgerIdProvider);
    if (activeLedgerId > 0) {
      unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
    }

    if (!mounted) return;
    showToast(context, l10n.categoryClearUnusedSuccess(deletedCount));
    ref.invalidate(categoriesWithCountProvider);
    _exitDeleteMode();
    // 重载子分类列表；若已全部删除，弹窗保留展示空态
    await _loadSubCategories();
  }
}

/// 对话框中的子分类卡片
///
/// 正常模式：点击进入编辑；删除模式：右上角显示复选框，点击切换选中状态
class _DialogSubCategoryCard extends StatelessWidget {
  final db.Category category;
  final int transactionCount;
  final VoidCallback onTap;

  /// 是否处于删除模式
  final bool isDeleteMode;

  /// 删除模式下是否被选中
  final bool isSelected;

  const _DialogSubCategoryCard({
    super.key,
    required this.category,
    required this.transactionCount,
    required this.onTap,
    this.isDeleteMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = SpitoutTokens.isDark(context);

    // 删除模式选中态：error 色加粗边框高亮
    final showSelectedBorder = isDeleteMode && isSelected;
    final borderColor = showSelectedBorder
        ? SpitoutTokens.error(context)
        : (isDark ? SpitoutTokens.border(context) : Colors.grey[300]!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: SpitoutTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: showSelectedBorder ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: CategoryIconWidget(
                      category: category,
                      size: 14,
                      color: primaryColor,
                      circular: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      CategoryUtils.getDisplayName(category.name, context),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).categoryMigrationTransactionLabel(transactionCount),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            // 删除模式：右上角复选框
            if (isDeleteMode)
              Positioned(
                right: 4,
                top: 4,
                child: _DeleteModeCheckbox(isSelected: isSelected),
              ),
          ],
        ),
      ),
    );
  }
}
