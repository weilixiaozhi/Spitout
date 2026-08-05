// 分类管理页三种删除策略集成测试
//
// 验证内容：
//   1. deleteTransactionsByCategoryIds — 批量删除指定分类下的交易
//   2. promoteSubCategoriesToTopLevel — 提升子分类为一级分类
//   3. 策略 A（含二级删除）：删交易(含子分类) + 删分类
//   4. 策略 B（迁移）：迁移交易+子分类到目标 + 删源分类
//   5. 策略 C（不含二级）：删一级交易 + 提升子分类 + 删一级分类
//   6. 边界条件：空列表、无子分类、无交易等

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_category_repository.dart';
import 'package:spitout/data/repositories/support/exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // seed 过程中 logger 会把日志持久化到 SharedPreferences，测试环境需 mock 掉。
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

  // ==================== 辅助方法 ====================

  /// 创建一个一级分类，返回其 id
  Future<int> createTopCategory(String name, {int sortOrder = 0}) async {
    return await repo.createCategory(
      name: name,
      kind: 'expense',
      icon: 'utensils',
      sortOrder: sortOrder,
    );
  }

  /// 在指定父分类下创建一个二级分类，返回其 id
  Future<int> createSubCategory(int parentId, String name, {int sortOrder = 0}) async {
    return await repo.createSubCategory(
      parentId: parentId,
      name: name,
      kind: 'expense',
      icon: 'utensils',
      sortOrder: sortOrder,
    );
  }

  /// 在指定账本下、指定分类创建一条交易记录，返回其 id
  Future<int> createTransaction(int ledgerId, int? categoryId, {int amount = 10000}) async {
    return await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        ledgerId: ledgerId,
        type: 'expense',
        amount: amount,
        categoryId: drift.Value(categoryId),
      ),
    );
  }

  /// 创建一个账本，返回其 id
  Future<int> createLedger() async {
    return await db.into(db.ledgers).insert(
      LedgersCompanion.insert(name: 'Test Ledger'),
    );
  }

  // ==================== deleteTransactionsByCategoryIds ====================

  group('deleteTransactionsByCategoryIds — 批量删除分类下交易', () {
    test('删除单个分类下的所有交易', () async {
      final ledgerId = await createLedger();
      final catId = await createTopCategory('餐饮');
      // 在该分类下创建 3 条交易
      await createTransaction(ledgerId, catId);
      await createTransaction(ledgerId, catId);
      await createTransaction(ledgerId, catId);

      final deleted = await repo.deleteTransactionsByCategoryIds([catId]);

      expect(deleted, 3, reason: '应删除 3 条交易');
      final remaining = await repo.getTransactionCountByCategory(catId);
      expect(remaining, 0, reason: '删除后该分类下应无交易');
    });

    test('批量删除多个分类下的交易', () async {
      final ledgerId = await createLedger();
      final cat1 = await createTopCategory('餐饮');
      final cat2 = await createTopCategory('交通');
      await createTransaction(ledgerId, cat1);
      await createTransaction(ledgerId, cat1);
      await createTransaction(ledgerId, cat2);

      final deleted = await repo.deleteTransactionsByCategoryIds([cat1, cat2]);

      expect(deleted, 3, reason: '应删除两个分类下共 3 条交易');
    });

    test('传入空列表返回 0 且不报错', () async {
      final deleted = await repo.deleteTransactionsByCategoryIds([]);
      expect(deleted, 0, reason: '空列表应返回 0');
    });

    test('分类下无交易时返回 0', () async {
      final catId = await createTopCategory('餐饮');
      final deleted = await repo.deleteTransactionsByCategoryIds([catId]);
      expect(deleted, 0, reason: '无交易时应返回 0');
    });

    test('不影响其他分类的交易', () async {
      final ledgerId = await createLedger();
      final cat1 = await createTopCategory('餐饮');
      final cat2 = await createTopCategory('交通');
      await createTransaction(ledgerId, cat1);
      await createTransaction(ledgerId, cat2);
      await createTransaction(ledgerId, cat2);

      // 只删 cat1 的交易
      await repo.deleteTransactionsByCategoryIds([cat1]);

      expect(await repo.getTransactionCountByCategory(cat1), 0, reason: 'cat1 交易应被清空');
      expect(await repo.getTransactionCountByCategory(cat2), 2, reason: 'cat2 交易应不受影响');
    });
  });

  // ==================== promoteSubCategoriesToTopLevel ====================

  group('promoteSubCategoriesToTopLevel — 提升子分类为一级', () {
    test('提升多个子分类为一级分类', () async {
      final parentId = await createTopCategory('餐饮', sortOrder: 0);
      await createSubCategory(parentId, '早餐');
      await createSubCategory(parentId, '午餐');
      await createSubCategory(parentId, '晚餐');

      final promoted = await repo.promoteSubCategoriesToTopLevel(parentId);

      expect(promoted, 3, reason: '应提升 3 个子分类');

      // 验证子分类已变为一级分类
      final subs = await repo.getSubCategories(parentId);
      expect(subs, isEmpty, reason: '提升后父分类下应无子分类');

      final topLevel = await repo.getTopLevelCategories('expense');
      // 原有 1 个一级 + 提升 3 个 = 4 个一级
      expect(topLevel.length, 4, reason: '一级分类应从 1 增至 4');

      // 验证提升的分类 parentId 为 null 且 level 为 1
      for (final cat in topLevel.where((c) => c.id != parentId)) {
        expect(cat.parentId, isNull, reason: '提升后的分类 parentId 应为 null');
        expect(cat.level, 1, reason: '提升后的分类 level 应为 1');
      }
    });

    test('提升后的子分类 sortOrder 排在已有分类之后', () async {
      // 已有两个一级分类 sortOrder=0, 1
      await createTopCategory('交通', sortOrder: 0);
      await createTopCategory('购物', sortOrder: 1);
      final parentId = await createTopCategory('餐饮', sortOrder: 2);
      await createSubCategory(parentId, '早餐');

      await repo.promoteSubCategoriesToTopLevel(parentId);

      final topLevel = await repo.getTopLevelCategories('expense');
      final promotedCat = topLevel.firstWhere((c) => c.name == '早餐');
      // 提升 sortOrder 应 >= max(已有 sortOrder) = 2
      expect(
        promotedCat.sortOrder,
        greaterThanOrEqualTo(2),
        reason: '提升后的分类 sortOrder 应排在已有分类之后',
      );
    });

    test('无子分类时返回 0', () async {
      final parentId = await createTopCategory('独立分类');
      final promoted = await repo.promoteSubCategoriesToTopLevel(parentId);
      expect(promoted, 0, reason: '无子分类时应返回 0');
    });

    test('提升操作在事务中执行（原子性）', () async {
      final parentId = await createTopCategory('餐饮');
      await createSubCategory(parentId, '早餐');
      await createSubCategory(parentId, '午餐');

      // 正常提升不应抛异常
      final promoted = await repo.promoteSubCategoriesToTopLevel(parentId);
      expect(promoted, 2, reason: '事务正常完成应提升 2 个子分类');

      // 验证提升结果持久化
      final subs = await repo.getSubCategories(parentId);
      expect(subs, isEmpty, reason: '事务提交后子分类应已脱离父分类');
    });
  });

  // ==================== 策略 A：含二级删除 ====================

  group('策略 A：删除分类和分类下的所有数据（含二级）', () {
    test('完整流程：收集子分类 ID → 删交易 → 删分类', () async {
      final ledgerId = await createLedger();
      final parentId = await createTopCategory('餐饮');
      final sub1 = await createSubCategory(parentId, '早餐');
      final sub2 = await createSubCategory(parentId, '午餐');
      // 在一级和二级分类下各创建交易
      await createTransaction(ledgerId, parentId);
      await createTransaction(ledgerId, sub1);
      await createTransaction(ledgerId, sub2);

      // 1. 收集所有分类 ID（一级 + 其子分类）
      final allCategoryIds = <int>[parentId, sub1, sub2];
      // 2. 删除这些分类下的所有交易
      final deletedTx = await repo.deleteTransactionsByCategoryIds(allCategoryIds);
      // 3. 删除分类记录（含子分类）
      await repo.deleteCategoriesByIds([parentId]);

      expect(deletedTx, 3, reason: '应删除 3 条交易');
      expect(await repo.getCategoryById(parentId), isNull, reason: '父分类应被删除');
      expect(await repo.getCategoryById(sub1), isNull, reason: '子分类应被删除');
      expect(await repo.getCategoryById(sub2), isNull, reason: '子分类应被删除');
    });

    test('删除多个一级分类及其子分类', () async {
      final ledgerId = await createLedger();
      final cat1 = await createTopCategory('餐饮');
      final sub1 = await createSubCategory(cat1, '早餐');
      final cat2 = await createTopCategory('交通');
      final sub2 = await createSubCategory(cat2, '地铁');

      await createTransaction(ledgerId, cat1);
      await createTransaction(ledgerId, sub1);
      await createTransaction(ledgerId, cat2);
      await createTransaction(ledgerId, sub2);

      final allIds = [cat1, sub1, cat2, sub2];
      await repo.deleteTransactionsByCategoryIds(allIds);
      await repo.deleteCategoriesByIds([cat1, cat2]);

      // 验证所有分类都被删除（deleteCategoriesByIds 会连带删除子分类）
      expect(await repo.getCategoryById(cat1), isNull);
      expect(await repo.getCategoryById(sub1), isNull);
      expect(await repo.getCategoryById(cat2), isNull);
      expect(await repo.getCategoryById(sub2), isNull);
    });
  });

  // ==================== 策略 B：迁移后删除 ====================

  group('策略 B：删除分类并迁移数据到其他分类', () {
    test('迁移一级分类的交易和子分类到目标分类', () async {
      final ledgerId = await createLedger();
      // 源分类（待删除）
      final sourceCat = await createTopCategory('旧分类');
      final sourceSub = await createSubCategory(sourceCat, '旧子分类');
      // 目标分类
      final targetCat = await createTopCategory('新分类');

      // 在源分类及其子分类下各创建 1 条交易
      await createTransaction(ledgerId, sourceCat);
      await createTransaction(ledgerId, sourceSub);

      // 执行迁移：
      // - sourceCat 上的 1 条交易 → 重指派到 targetCat
      // - sourceSub（无同名）→ parentId 改为 targetCat，其交易不动
      final result = await repo.migrateCategoryTransactions(
        fromCategoryId: sourceCat,
        toCategoryId: targetCat,
      );

      // migratedTransactions 只统计「重指派 categoryId」的交易，
      // 子分类的交易随子分类移动保留，不单独计数
      expect(result.migratedTransactions, 1, reason: '应重指派 1 条直接交易');
      expect(result.migratedSubCategories, 1, reason: '应移动 1 个子分类');

      // 验证直接交易已迁移到目标分类
      expect(await repo.getTransactionCountByCategory(targetCat), 1,
          reason: '目标分类应有 1 条直接交易');

      // 删除源分类
      await repo.deleteCategoriesByIds([sourceCat]);
      expect(await repo.getCategoryById(sourceCat), isNull, reason: '源分类应被删除');

      // 验证子分类已挂到目标分类下，且其交易保留
      final targetSubs = await repo.getSubCategories(targetCat);
      expect(targetSubs.any((c) => c.name == '旧子分类'), isTrue,
          reason: '源子分类应已迁移到目标分类下');
      final movedSub = targetSubs.firstWhere((c) => c.name == '旧子分类');
      expect(await repo.getTransactionCountByCategory(movedSub.id), 1,
          reason: '子分类的交易应随子分类保留');
    });

    test('迁移时目标分类已有同名子分类则合并交易', () async {
      final ledgerId = await createLedger();
      final sourceCat = await createTopCategory('旧分类');
      await createSubCategory(sourceCat, '同名子分类');
      final targetCat = await createTopCategory('新分类');
      final existingSub = await createSubCategory(targetCat, '同名子分类');

      // 在源子分类和目标子分类下各创建交易
      final sourceSubs = await repo.getSubCategories(sourceCat);
      final sourceSubId = sourceSubs.first.id;
      await createTransaction(ledgerId, sourceSubId);
      await createTransaction(ledgerId, existingSub);

      final result = await repo.migrateCategoryTransactions(
        fromCategoryId: sourceCat,
        toCategoryId: targetCat,
      );

      // 合并路径：交易迁移到已有子分类，源子分类被删除
      expect(result.migratedTransactions, 1, reason: '应迁移 1 条交易到同名子分类');
      expect(result.migratedSubCategories, 0, reason: '同名子分类被合并，不计数移动');

      // 目标子分类应有 2 条交易（原有 1 + 迁移 1）
      expect(await repo.getTransactionCountByCategory(existingSub), 2,
          reason: '目标同名子分类应有合并后的 2 条交易');
    });

    test('迁移后源分类交易数为 0', () async {
      final ledgerId = await createLedger();
      final sourceCat = await createTopCategory('旧分类');
      final targetCat = await createTopCategory('新分类');
      await createTransaction(ledgerId, sourceCat);
      await createTransaction(ledgerId, sourceCat);

      await repo.migrateCategoryTransactions(
        fromCategoryId: sourceCat,
        toCategoryId: targetCat,
      );

      expect(await repo.getTransactionCountByCategory(sourceCat), 0,
          reason: '迁移后源分类交易数应为 0');
    });
  });

  // ==================== 策略 C：不含二级（提升子分类） ====================

  group('策略 C：删除分类但保留二级（二级变一级）', () {
    test('完整流程：删一级交易 → 提升子分类 → 删一级分类', () async {
      final ledgerId = await createLedger();
      final parentId = await createTopCategory('餐饮');
      final sub1 = await createSubCategory(parentId, '早餐');
      final sub2 = await createSubCategory(parentId, '午餐');

      // 在一级和二级分类下各创建交易
      await createTransaction(ledgerId, parentId);
      await createTransaction(ledgerId, sub1);
      await createTransaction(ledgerId, sub2);

      // 1. 仅删除一级分类自身的直接交易（不含子分类）
      await repo.deleteTransactionsByCategoryIds([parentId]);
      // 2. 提升子分类为一级
      final promoted = await repo.promoteSubCategoriesToTopLevel(parentId);
      // 3. 删除一级分类记录（子分类已脱离，不会被连带删除）
      await repo.deleteCategoriesByIds([parentId]);

      expect(promoted, 2, reason: '应提升 2 个子分类');
      expect(await repo.getCategoryById(parentId), isNull, reason: '父分类应被删除');

      // 验证子分类已变为一级分类且交易保留
      final sub1Cat = await repo.getCategoryById(sub1);
      final sub2Cat = await repo.getCategoryById(sub2);
      expect(sub1Cat, isNotNull, reason: '子分类应保留');
      expect(sub2Cat, isNotNull, reason: '子分类应保留');
      expect(sub1Cat!.level, 1, reason: '子分类应变为一级');
      expect(sub1Cat.parentId, isNull, reason: 'parentId 应为 null');
      expect(sub2Cat!.level, 1, reason: '子分类应变为一级');
      expect(sub2Cat.parentId, isNull, reason: 'parentId 应为 null');

      // 子分类下的交易应保留
      expect(await repo.getTransactionCountByCategory(sub1), 1,
          reason: '子分类交易应保留');
      expect(await repo.getTransactionCountByCategory(sub2), 1,
          reason: '子分类交易应保留');
    });

    test('无子分类的一级分类删除时提升返回 0', () async {
      final ledgerId = await createLedger();
      final parentId = await createTopCategory('独立分类');
      await createTransaction(ledgerId, parentId);

      await repo.deleteTransactionsByCategoryIds([parentId]);
      final promoted = await repo.promoteSubCategoriesToTopLevel(parentId);
      await repo.deleteCategoriesByIds([parentId]);

      expect(promoted, 0, reason: '无子分类时提升应返回 0');
      expect(await repo.getCategoryById(parentId), isNull, reason: '分类应被删除');
    });
  });

  // ==================== deleteCategoriesByIds 边界 ====================

  group('deleteCategoriesByIds 边界条件', () {
    test('空列表不报错', () async {
      await repo.deleteCategoriesByIds([]);
      // 无异常即通过
    });

    test('连带删除子分类', () async {
      final parentId = await createTopCategory('父分类');
      await createSubCategory(parentId, '子分类1');
      await createSubCategory(parentId, '子分类2');

      await repo.deleteCategoriesByIds([parentId]);

      expect(await repo.getCategoryById(parentId), isNull, reason: '父分类应被删除');
      final subs = await repo.getSubCategories(parentId);
      expect(subs, isEmpty, reason: '子分类应被连带删除');
    });

    test('批量删除多个不连续的分类', () async {
      final cat1 = await createTopCategory('分类1');
      final cat2 = await createTopCategory('分类2');
      final cat3 = await createTopCategory('分类3');

      await repo.deleteCategoriesByIds([cat1, cat3]);

      expect(await repo.getCategoryById(cat1), isNull);
      expect(await repo.getCategoryById(cat2), isNotNull, reason: '未选中的分类应保留');
      expect(await repo.getCategoryById(cat3), isNull);
    });
  });

  // ==================== 作用域唯一性契约 ====================

  group('分类名称作用域唯一性', () {
    test('同父级下二级分类不允许同名', () async {
      final parentId = await createTopCategory('父分类');
      await createSubCategory(parentId, '子分类');

      expect(
        () => createSubCategory(parentId, '子分类'),
        throwsA(isA<DuplicateNameException>()),
        reason: '同父级下同名二级分类应抛 DuplicateNameException',
      );
    });

    test('跨父级允许同名二级分类', () async {
      final parent1 = await createTopCategory('父分类1');
      final parent2 = await createTopCategory('父分类2');

      // 在不同父级下创建同名子分类，不应抛异常
      await createSubCategory(parent1, '同名子分类');
      await createSubCategory(parent2, '同名子分类');

      // 验证两个子分类都存在
      final subs1 = await repo.getSubCategories(parent1);
      final subs2 = await repo.getSubCategories(parent2);
      expect(subs1.any((c) => c.name == '同名子分类'), isTrue);
      expect(subs2.any((c) => c.name == '同名子分类'), isTrue);
    });

    test('isCategoryNameDuplicate 按作用域判重', () async {
      final parent1 = await createTopCategory('父分类1');
      final parent2 = await createTopCategory('父分类2');
      await createSubCategory(parent1, '鞋子');

      // 同父级下判重
      final dup1 = await repo.isCategoryNameDuplicate(
        name: '鞋子',
        kind: 'expense',
        parentId: parent1,
      );
      expect(dup1, isTrue, reason: '同父级下应判重');

      // 跨父级不判重
      final dup2 = await repo.isCategoryNameDuplicate(
        name: '鞋子',
        kind: 'expense',
        parentId: parent2,
      );
      expect(dup2, isFalse, reason: '跨父级不应判重');
    });
  });
}
