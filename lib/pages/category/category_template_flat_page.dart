import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/data/models.dart' as db;
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/core/post_processor.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/widgets/widgets.dart';
import 'category_template_widgets.dart';

/// 一级分类模板页（flat 模板库）
///
/// 交互对齐分类管理删除模式：
/// - 卡片右上角常驻复选框；已在 categories 表的条目勾选置灰、不可再选；
/// - 底部常驻操作栏（已选计数 / 全选·取消全选 / 添加），添加前二次确认；
/// - 已添加判定为双通道（确定性 syncId 优先、同名兜底），
///   手动创建的同名分类也会置灰；删除分类后条目自动恢复可添加。
class CategoryTemplateFlatPage extends ConsumerStatefulWidget {
  const CategoryTemplateFlatPage({super.key});

  @override
  ConsumerState<CategoryTemplateFlatPage> createState() =>
      _CategoryTemplateFlatPageState();
}

class _CategoryTemplateFlatPageState
    extends ConsumerState<CategoryTemplateFlatPage> {
  /// 本次勾选的模板 key（不含已添加条目）
  Set<String> _selected = {};

  /// 是否正在执行写入
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catsAsync = ref.watch(categoriesWithCountProvider);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.categoryTemplateFlatTitle,
            showBack: true,
          ),
          Expanded(
            child: catsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                logger.error('categoryTemplate', 'flat 分类加载失败', e, st);
                return Center(
                  child: Text(l10n.commonOperationFailed),
                );
              },
              data: (cats) => _buildBody(context, l10n, cats),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建页面主体：模板网格 + 底部操作栏
  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    List<({db.Category category, int transactionCount})> cats,
  ) {
    final existingIndex = ExistingCategoryIndex([
      for (final c in cats)
        (
          id: c.category.id,
          syncId: c.category.syncId,
          name: c.category.name,
          kind: c.category.kind,
          level: c.category.level,
          parentId: c.category.parentId,
        ),
    ]);
    final items = buildFlatTemplateItems(l10n, existingIndex);
    final selectableCount = items.where((it) => !it.alreadyAdded).length;

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(SpitoutDimens.p16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return TemplateItemTile(
                item: item,
                selected: _selected.contains(item.key),
                onToggle: () => setState(
                  () => _selected = toggleFlatSelection(_selected, item.key),
                ),
              );
            },
          ),
        ),
        TemplateBottomBar(
          selectedCount: _selected.length,
          allSelected:
              selectableCount > 0 && _selected.length == selectableCount,
          isAdding: _isAdding,
          onToggleSelectAll: () => setState(() {
            final all = computeFlatSelectAll(items);
            // 已全选 → 取消全选；否则全选（只含未添加条目）
            _selected = _selected.length == all.length ? {} : all;
          }),
          onAdd: () => _onAdd(l10n, items, cats),
        ),
      ],
    );
  }

  /// 点击"添加"：二次确认 → 写入 categories 表
  Future<void> _onAdd(
    AppLocalizations l10n,
    List<CategoryTemplateItem> items,
    List<({db.Category category, int transactionCount})> cats,
  ) async {
    final plan = buildInsertPlan(allItems: items, selectedKeys: _selected);
    if (plan.total == 0) return;

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.categoryTemplateConfirmTitle,
      message: l10n.categoryTemplateConfirmMessage(plan.total),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isAdding = true);
    try {
      final added = await executeTemplateInsertPlanFromUi(
        ref,
        plan: plan,
        existingCategories: [for (final c in cats) c.category],
      );
      logger.info('categoryTemplate', 'flat 模板写入 $added 个分类');
      // 分类是 user-scoped 资源，ChangeTracker 记在 ledgerId=0；
      // 用当前账本触发一次 sync 即时推到服务端（与编辑页手动新增同策略）。
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      if (mounted) {
        showToast(context, l10n.categoryTemplateAddSuccess(added));
        // 清空本次勾选；新写入条目经 stream 自动变为"已添加"置灰态
        setState(() => _selected = {});
      }
    } catch (e, st) {
      // 常见冲突：同作用域存在同名自定义分类（DuplicateNameException）
      logger.error('categoryTemplate', 'flat 模板写入失败', e, st);
      if (mounted) {
        showToast(
          context,
          l10n.categoryTemplateAddFailed(l10n.commonOperationFailed),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }
}
