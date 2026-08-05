// 分类判重契约测试。
//
// 锁死「作用域唯一」契约(2026-07 分类默认结构重排后调整):
//  - 同一父级作用域内 (name, kind) 唯一:一级分类之间 / 同父的二级之间禁止重名;
//  - 跨 kind 允许同名(收入「红包」+ 支出「红包」);
//  - 跨父级的二级分类允许同名(默认 seed 即有「购物>鞋子」「服装>鞋子」);
//  - 一级与二级允许同名(「服装」父分类 vs「购物>服装」子分类)。

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/data/repositories/support/exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('分类跨类型同名 (name, kind)', () {
    test('跨 kind 同名分类可共存(收入红包 + 支出红包)', () async {
      final inc = await repo.createCategory(name: '红包', kind: 'income');
      final exp = await repo.createCategory(name: '红包', kind: 'expense');
      expect(inc, isNot(exp));
    });

    test('同 kind 重名抛 DuplicateNameException', () async {
      await repo.createCategory(name: '红包', kind: 'expense');
      expect(
        () => repo.createCategory(name: '红包', kind: 'expense'),
        throwsA(isA<DuplicateNameException>()),
      );
    });

    test('isCategoryNameDuplicate 按 (name, kind) 判定', () async {
      await repo.createCategory(name: '红包', kind: 'expense');
      expect(
        await repo.isCategoryNameDuplicate(name: '红包', kind: 'expense'),
        isTrue,
      );
      expect(
        await repo.isCategoryNameDuplicate(name: '红包', kind: 'income'),
        isFalse,
      );
    });

    test('upsertCategory 跨 kind 不误复用、同 kind 复用', () async {
      final a = await repo.upsertCategory(name: '红包', kind: 'income');
      final b = await repo.upsertCategory(name: '红包', kind: 'expense');
      expect(a.id, isNot(b.id)); // 跨 kind → 建两个独立分类
      final aAgain = await repo.upsertCategory(name: '红包', kind: 'income');
      expect(aAgain.id, a.id); // 同 kind → 复用
      expect(aAgain.created, isFalse);
    });

    test('createSubCategory 跨 kind 同名子分类可共存', () async {
      final pInc = await repo.createCategory(name: '工资', kind: 'income');
      final pExp = await repo.createCategory(name: '餐饮', kind: 'expense');
      final subInc = await repo.createSubCategory(
        parentId: pInc,
        name: '红包',
        kind: 'income',
      );
      final subExp = await repo.createSubCategory(
        parentId: pExp,
        name: '红包',
        kind: 'expense',
      );
      expect(subInc, isNot(subExp));
    });

    test('createSubCategory 同父级下重名抛 DuplicateNameException', () async {
      final p = await repo.createCategory(name: '餐饮', kind: 'expense');
      await repo.createSubCategory(parentId: p, name: '午餐', kind: 'expense');
      expect(
        () => repo.createSubCategory(parentId: p, name: '午餐', kind: 'expense'),
        throwsA(isA<DuplicateNameException>()),
      );
    });
  });

  group('分类作用域唯一(跨父级/跨层级允许同名)', () {
    test('跨父级同名二级分类可共存(购物>鞋子 + 服装>鞋子)', () async {
      final pShopping = await repo.createCategory(name: '购物', kind: 'expense');
      final pClothing = await repo.createCategory(name: '服装', kind: 'expense');
      final shoesA = await repo.createSubCategory(
        parentId: pShopping,
        name: '鞋子',
        kind: 'expense',
      );
      final shoesB = await repo.createSubCategory(
        parentId: pClothing,
        name: '鞋子',
        kind: 'expense',
      );
      expect(shoesA, isNot(shoesB));
    });

    test('一级与二级允许同名(「服装」父分类 vs「购物>服装」子分类)', () async {
      final pShopping = await repo.createCategory(name: '购物', kind: 'expense');
      await repo.createSubCategory(
        parentId: pShopping,
        name: '服装',
        kind: 'expense',
      );
      // 已存在「购物>服装」二级分类时,仍可创建同名一级分类
      final l1 = await repo.createCategory(name: '服装', kind: 'expense');
      expect(l1, isPositive);
    });

    test('isCategoryNameDuplicate 按作用域判重', () async {
      final pShopping = await repo.createCategory(name: '购物', kind: 'expense');
      final pClothing = await repo.createCategory(name: '服装', kind: 'expense');
      await repo.createSubCategory(
        parentId: pShopping,
        name: '鞋子',
        kind: 'expense',
      );
      // 同父级作用域 → 重复
      expect(
        await repo.isCategoryNameDuplicate(
          name: '鞋子',
          kind: 'expense',
          parentId: pShopping,
        ),
        isTrue,
      );
      // 另一个父级作用域 → 不算重复
      expect(
        await repo.isCategoryNameDuplicate(
          name: '鞋子',
          kind: 'expense',
          parentId: pClothing,
        ),
        isFalse,
      );
      // 根作用域(一级分类之间) → 与二级「鞋子」不冲突
      expect(
        await repo.isCategoryNameDuplicate(name: '鞋子', kind: 'expense'),
        isFalse,
      );
    });

    test('upsertCategory 命中多行取 id 最小的一行', () async {
      final pShopping = await repo.createCategory(name: '购物', kind: 'expense');
      final pClothing = await repo.createCategory(name: '服装', kind: 'expense');
      final shoesA = await repo.createSubCategory(
        parentId: pShopping,
        name: '鞋子',
        kind: 'expense',
      );
      await repo.createSubCategory(
        parentId: pClothing,
        name: '鞋子',
        kind: 'expense',
      );
      // 两个同名「鞋子」存在时,upsert 不抛异常且结果确定(id 最小)
      final resolved = await repo.upsertCategory(name: '鞋子', kind: 'expense');
      expect(resolved.id, shoesA);
    });
  });

  group('deleteCategory fail-loud', () {
    test('有子分类时拒绝直接删除并保留分类', () async {
      final parent = await repo.createCategory(name: '父类', kind: 'expense');
      await repo.createSubCategory(
        parentId: parent,
        name: '子类',
        kind: 'expense',
      );

      await expectLater(
        repo.deleteCategory(parent),
        throwsA(isA<StateError>()),
      );
      expect(await repo.getCategoryById(parent), isNotNull);
    });

    test('有交易时拒绝直接删除并保留分类与交易', () async {
      final ledgerId = await repo.createLedger(
        name: '删分类',
        storageMode: 'local',
      );
      final categoryId = await repo.createCategory(name: '餐饮', kind: 'expense');
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 1000,
        happenedAt: DateTime(2026, 8, 5),
        categoryId: categoryId,
      );

      await expectLater(
        repo.deleteCategory(categoryId),
        throwsA(isA<StateError>()),
      );
      expect(await repo.getCategoryById(categoryId), isNotNull);
      expect(await repo.getTransactionsByCategory(categoryId), hasLength(1));
    });

    test('空分类可直接删除', () async {
      final categoryId = await repo.createCategory(name: '空类', kind: 'expense');
      await repo.deleteCategory(categoryId);
      expect(await repo.getCategoryById(categoryId), isNull);
    });
  });

  group(
    'watchCategoryWithSubs / watchCategoriesWithCount / getCategoryFullName',
    () {
      test('watchCategoryWithSubs 构造的 Category 带 syncId', () async {
        final parent = await repo.createCategory(name: '父类', kind: 'expense');
        await repo.createSubCategory(
          parentId: parent,
          name: '子类',
          kind: 'expense',
        );

        final cats = await repo.watchCategoryWithSubs(parent).first;

        expect(cats, hasLength(2));
        expect(cats.every((c) => c.syncId != null), isTrue);
      });

      test('watchCategoriesWithCount 用单 SQL 返回含子分类的总笔数', () async {
        final ledgerId = await repo.createLedger(
          name: '统计',
          storageMode: 'local',
        );
        final parent = await repo.createCategory(name: '父类', kind: 'expense');
        final child = await repo.createSubCategory(
          parentId: parent,
          name: '子类',
          kind: 'expense',
        );
        await repo.addTransaction(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 1000,
          happenedAt: DateTime(2026, 8, 5),
          categoryId: parent,
        );
        await repo.addTransaction(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 2000,
          happenedAt: DateTime(2026, 8, 5),
          categoryId: child,
        );

        final rows = await repo.watchCategoriesWithCount().first;
        final parentRow = rows.firstWhere((r) => r.category.id == parent);
        final childRow = rows.firstWhere((r) => r.category.id == child);

        expect(parentRow.transactionCount, 2);
        expect(childRow.transactionCount, 1);
      });

      test('getCategoryFullName 父分类缺失时降级返回子分类名', () async {
        final parent = await repo.createCategory(name: '父类', kind: 'expense');
        final child = await repo.createSubCategory(
          parentId: parent,
          name: '子类',
          kind: 'expense',
        );
        await (db.delete(
          db.categories,
        )..where((c) => c.id.equals(parent))).go();

        expect(await repo.getCategoryFullName(child), '子类');
      });
    },
  );
}
