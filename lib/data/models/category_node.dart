import '../db.dart';
import '../../core/logging/logger_service.dart';

/// 分类树节点
/// 用于在 UI 层组织和展示分类的层级结构
class CategoryNode {
  final Category category;
  final List<Category> children;

  CategoryNode({
    required this.category,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;
  bool get isTopLevel => category.level == 1;
}

/// 分类层级构建器
/// 将扁平的分类列表转换为树形结构
class CategoryHierarchy {
  /// 构建分类树
  static List<CategoryNode> buildHierarchy(List<Category> allCategories) {
    // 分组：一级分类和二级分类
    final topLevel = <Category>[];
    final subCategories = <int, List<Category>>{}; // parentId -> children

    for (final cat in allCategories) {
      if (cat.level == 1 || cat.parentId == null) {
        topLevel.add(cat);
      } else if (cat.parentId != null) {
        subCategories.putIfAbsent(cat.parentId!, () => []).add(cat);
      }
    }

    // 按 sortOrder 排序
    topLevel.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final children in subCategories.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // 孤儿二级分类单独标记并记 warning：父分类不在一级列表里（父被删未级联 /
    // 导入数据 parentId 失配），这类分类在管理页不可见，也应在记账选择中排除，
    // 避免同一份数据在「管理页没有、记账页却能选」两个口径打架。
    final orphans = findOrphanCategories(allCategories);
    if (orphans.isNotEmpty) {
      logger.warning(
        'CategoryHierarchy',
        '构建分类树发现 ${orphans.length} 个孤儿二级分类: '
        '${orphans.map((c) => '${c.name}(id=${c.id},parentId=${c.parentId})').join(', ')}',
      );
    }

    // 构建节点
    return topLevel.map((cat) {
      final children = subCategories[cat.id] ?? [];
      return CategoryNode(
        category: cat,
        children: children,
      );
    }).toList();
  }

  /// 找出所有孤儿二级分类：parentId 指向的分类不在一级列表里。
  ///
  /// 与 [buildHierarchy] 的挂树规则保持一致：只有「父分类存在于一级列表」
  /// 的孩子才可见。调用方（UI/维护工具）可据此分组展示或触发数据修复。
  static List<Category> findOrphanCategories(List<Category> allCategories) {
    final topLevelIds = allCategories
        .where((c) => c.level == 1 || c.parentId == null)
        .map((c) => c.id)
        .toSet();
    return allCategories
        .where((c) => c.parentId != null && !topLevelIds.contains(c.parentId))
        .toList();
  }

  /// 获取所有一级分类（不包含子分类）
  static List<Category> getTopLevelOnly(List<Category> allCategories) {
    return allCategories
        .where((c) => c.level == 1 || c.parentId == null)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 获取指定父分类的所有子分类
  static List<Category> getSubCategoriesOf(
    List<Category> allCategories,
    int parentId,
  ) {
    return allCategories
        .where((c) => c.parentId == parentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 获取可用于记账的分类（叶子分类）
  ///
  /// 可用分类 = 没有子分类的分类
  /// - 如果是一级分类且有子分类 -> 不可用（需要选择子分类）
  /// - 如果是一级分类且没有子分类 -> 可用
  /// - 如果是二级分类 -> 可用
  ///
  /// 此方法用于：
  /// 1. AI 记账时匹配分类
  /// 2. AI 提示词中传递分类列表
  /// 3. 分类兜底选择
  static List<Category> getUsableCategories(List<Category> allCategories) {
    // 找出所有作为父分类的 ID
    final parentIds = allCategories
        .where((c) => c.parentId != null)
        .map((c) => c.parentId!)
        .toSet();

    // 孤儿二级分类（父分类缺失）与树构建口径一致：管理页不可见，记账也不能选，
    // 避免出现「管理里没有、记账里却能选」的怪现象。
    final orphanIds = findOrphanCategories(allCategories)
        .map((c) => c.id)
        .toSet();

    // 过滤出可用分类：不是父分类、且不是孤儿分类的分类
    return allCategories
        .where((c) => !parentIds.contains(c.id) && !orphanIds.contains(c.id))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

}
