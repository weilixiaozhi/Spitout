// getCategoryTree 分类树合并查询测试
//
// 验证内容：
//   1. 单查询分组：一级按 sortOrder 排序，二级按父ID分组且各自排序
//   2. 无子分类的父项不出现在 children 中；空表返回空树
//   3. 按 kind 过滤（其他 kind 的分类不进入树）

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_category_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalCategoryRepository repo;

  /// 每个测试前创建内存数据库 + 仓储实例
  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalCategoryRepository(db);
  });

  /// 每个测试后关闭数据库
  tearDown(() async {
    await db.close();
  });

  test('单查询分组：一级按 sortOrder 排序，二级按父ID分组且各自排序', () async {
    final food = await repo.createCategory(
        name: '餐饮', kind: 'expense', sortOrder: 1);
    await repo.createCategory(name: '交通', kind: 'expense', sortOrder: 0);
    await repo.createSubCategory(
        parentId: food, name: '早餐', kind: 'expense', sortOrder: 1);
    await repo.createSubCategory(
        parentId: food, name: '午餐', kind: 'expense', sortOrder: 0);

    final tree = await repo.getCategoryTree('expense');

    expect(tree.topLevel.map((c) => c.name), ['交通', '餐饮']);
    expect(tree.children.keys, [food]);
    expect(tree.children[food]!.map((c) => c.name), ['午餐', '早餐']);
  });

  test('无子分类的父项不出现在 children 中；空表返回空树', () async {
    expect((await repo.getCategoryTree('expense')).topLevel, isEmpty);

    await repo.createCategory(name: '其他', kind: 'expense');
    final tree = await repo.getCategoryTree('expense');
    expect(tree.topLevel.length, 1);
    expect(tree.children, isEmpty);
  });

  test('按 kind 过滤：其他 kind 的分类不进入树', () async {
    await repo.createCategory(name: '工资', kind: 'income');
    await repo.createCategory(name: '餐饮', kind: 'expense');

    final tree = await repo.getCategoryTree('expense');
    expect(tree.topLevel.map((c) => c.name), ['餐饮']);
  });
}
