// CategoryNode / CategoryHierarchy 纯逻辑测试。
//
// 需求锚点（以行为为准）：
//   1. 节点 hasChildren / isTopLevel 语义；
//   2. buildHierarchy：一级/二级分组、按 sortOrder 排序、孤儿二级单独标记并告警；
//   3. findOrphanCategories：parentId 指向不存在的分类即为孤儿；
//   4. getTopLevelOnly / getSubCategoriesOf 过滤排序；
//   5. getUsableCategories：排除父分类与孤儿，仅叶子可用。

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart' as db;
import 'package:spitout/data/models/category_node.dart';

void main() {
  db.Category cat({
    required int id,
    required String name,
    int level = 1,
    int sortOrder = 0,
    int? parentId,
  }) {
    return db.Category(
      id: id,
      name: name,
      kind: 'expense',
      icon: 'x',
      sortOrder: sortOrder,
      parentId: parentId,
      level: level,
    );
  }

  test('CategoryNode hasChildren / isTopLevel', () {
    final leaf = CategoryNode(
      category: cat(id: 1, name: '餐饮', level: 1),
    );
    expect(leaf.hasChildren, isFalse);
    expect(leaf.isTopLevel, isTrue);

    final parent = CategoryNode(
      category: cat(id: 1, name: '餐饮', level: 1),
      children: [cat(id: 2, name: '早餐', level: 2, parentId: 1)],
    );
    expect(parent.hasChildren, isTrue);
    expect(parent.isTopLevel, isTrue);

    final sub = CategoryNode(
      category: cat(id: 2, name: '早餐', level: 2, parentId: 1),
    );
    expect(sub.isTopLevel, isFalse);
  });

  test('buildHierarchy 分组、排序并挂载子分类', () {
    final tree = CategoryHierarchy.buildHierarchy([
      cat(id: 1, name: 'A', sortOrder: 2),
      cat(id: 3, name: 'C', sortOrder: 0),
      cat(id: 2, name: 'B', sortOrder: 1),
      cat(id: 10, name: 'A1', level: 2, parentId: 1, sortOrder: 1),
      cat(id: 11, name: 'A0', level: 2, parentId: 1, sortOrder: 0),
    ]);

    expect(tree.map((n) => n.category.name), ['C', 'B', 'A'],
        reason: '一级按 sortOrder 升序');
    final nodeA = tree.firstWhere((n) => n.category.name == 'A');
    expect(nodeA.children.map((c) => c.name), ['A0', 'A1'],
        reason: '子分类按 sortOrder 升序');
  });

  test('findOrphanCategories：parentId 指向缺失分类', () {
    final orphans = CategoryHierarchy.findOrphanCategories([
      cat(id: 1, name: 'A'),
      cat(id: 9, name: 'sub-of-missing', level: 2, parentId: 99),
    ]);
    expect(orphans.map((c) => c.id), [9]);
  });

  test('getTopLevelOnly 与 getSubCategoriesOf', () {
    final all = [
      cat(id: 1, name: 'A', sortOrder: 1),
      cat(id: 2, name: 'B', sortOrder: 0),
      cat(id: 10, name: 'A1', level: 2, parentId: 1, sortOrder: 1),
      cat(id: 11, name: 'A0', level: 2, parentId: 1, sortOrder: 0),
    ];
    expect(CategoryHierarchy.getTopLevelOnly(all).map((c) => c.name),
        ['B', 'A']);
    expect(
      CategoryHierarchy.getSubCategoriesOf(all, 1).map((c) => c.name),
      ['A0', 'A1'],
    );
  });

  test('getUsableCategories：排除父分类与孤儿', () {
    final usable = CategoryHierarchy.getUsableCategories([
      cat(id: 1, name: 'A', sortOrder: 1),
      cat(id: 10, name: 'A1', level: 2, parentId: 1, sortOrder: 1),
      cat(id: 2, name: 'B', sortOrder: 0),
      cat(id: 99, name: 'orphan', level: 2, parentId: 88, sortOrder: 3),
    ]);
    expect(usable.map((c) => c.name), ['B', 'A1'],
        reason: '父分类 A 不可选、孤儿不可选、叶子 B/A1 可选且排序');
  });
}
