import 'package:spitout/data/db.dart';

/// 记账页分类树：一级分类列表 + 父分类 ID → 二级分类列表的映射。
///
/// 设计意图：记账编辑页分类网格需要「全部一级 + 各一级的全部二级」，
/// 由 [LocalRepository.getCategoryTree]（主表）或共享账本等效查询
/// （SharedLedgerCategories，synthetic id）一次性构建。
class CategoryPickerTree {
  const CategoryPickerTree({required this.topLevel, required this.children});

  /// 一级分类（按 sortOrder 升序）
  final List<Category> topLevel;

  /// 父分类 ID → 其子分类列表（仅含有子分类的父项；子列表按 sortOrder 升序）。
  /// 共享账本 Editor 视角下键与值均为 synthetic id（负数）。
  final Map<int, List<Category>> children;

  /// 空树（无分类场景）
  static const empty = CategoryPickerTree(topLevel: [], children: {});
}
