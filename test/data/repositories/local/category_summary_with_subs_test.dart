// 分类汇总含子分类交易契约测试。
//
// 锁死：一级分类的分类汇总（CategoryDetailPage）调用
// watchTransactionsByCategory(includeSubCategories: true) 时，必须包含
// 其所有二级分类的交易。即使一级分类自身无直接交易，只要二级分类有交易，
// 汇总列表也不为空、金额不为 0。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpitoutDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  /// 创建测试账本，返回账本 id
  Future<int> seedLedger() {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
          monthStartDay: const Value(1),
        ));
  }

  group('watchTransactionsByCategory 含子分类 (includeSubCategories)', () {
    test('一级分类无直接交易但二级分类有交易 → 汇总包含子分类交易', () async {
      final lid = await seedLedger();
      // 一级分类「餐饮」+ 二级分类「午餐」「晚餐」
      final parentId = await repo.createCategory(name: '餐饮', kind: 'expense');
      final subA = await repo.createSubCategory(
          parentId: parentId, name: '午餐', kind: 'expense');
      final subB = await repo.createSubCategory(
          parentId: parentId, name: '晚餐', kind: 'expense');

      // 一级分类自身无直接交易，只给二级分类挂交易
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 50,
        categoryId: subA,
        happenedAt: DateTime(2026, 7, 1),
      );
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 80,
        categoryId: subB,
        happenedAt: DateTime(2026, 7, 2),
      );

      // includeSubCategories: true —— 应包含两条子分类交易
      final withSubs = await repo
          .watchTransactionsByCategory(parentId,
              ledgerId: lid, includeSubCategories: true)
          .first;
      expect(withSubs.length, 2,
          reason: '一级分类汇总应包含所有二级分类的交易');
      final total = withSubs.fold<double>(0, (a, t) => a + t.amount);
      expect(total, 130.0, reason: '汇总金额应为子分类交易之和 50+80=130');

      // includeSubCategories: false（默认）—— 不含子分类交易，应为空
      final withoutSubs = await repo
          .watchTransactionsByCategory(parentId, ledgerId: lid)
          .first;
      expect(withoutSubs, isEmpty,
          reason: '默认不含子分类时，一级分类无直接交易应返回空列表');
    });

    test('一级分类有直接交易 + 二级分类有交易 → 汇总包含全部', () async {
      final lid = await seedLedger();
      final parentId = await repo.createCategory(name: '交通', kind: 'expense');
      final sub = await repo.createSubCategory(
          parentId: parentId, name: '地铁', kind: 'expense');

      // 一级分类直接挂一笔 + 二级分类挂一笔
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 200,
        categoryId: parentId,
        happenedAt: DateTime(2026, 7, 1),
      );
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 30,
        categoryId: sub,
        happenedAt: DateTime(2026, 7, 2),
      );

      final txs = await repo
          .watchTransactionsByCategory(parentId,
              ledgerId: lid, includeSubCategories: true)
          .first;
      expect(txs.length, 2, reason: '应包含一级直接交易 + 二级子分类交易');
      final total = txs.fold<double>(0, (a, t) => a + t.amount);
      expect(total, 230.0, reason: '汇总金额应为 200+30=230');
    });

    test('二级分类调用 includeSubCategories → 仅返回自身交易（无子分类）',
        () async {
      final lid = await seedLedger();
      final parentId = await repo.createCategory(name: '购物', kind: 'expense');
      final sub = await repo.createSubCategory(
          parentId: parentId, name: '衣物', kind: 'expense');

      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 100,
        categoryId: sub,
        happenedAt: DateTime(2026, 7, 1),
      );
      // 一级分类挂一笔，不应出现在二级分类的汇总中
      await repo.addTransaction(
        ledgerId: lid,
        type: 'expense',
        amount: 500,
        categoryId: parentId,
        happenedAt: DateTime(2026, 7, 2),
      );

      // 二级分类即使传 includeSubCategories: true，它没有子分类，
      // 应只返回自身那一条交易
      final txs = await repo
          .watchTransactionsByCategory(sub,
              ledgerId: lid, includeSubCategories: true)
          .first;
      expect(txs.length, 1, reason: '二级分类无子分类，应只返回自身交易');
      expect(txs.first.amount, 100.0);
    });

    test('不含 ledgerId 过滤时返回跨账本的全部子分类交易', () async {
      final lid1 = await seedLedger();
      final lid2 = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '账本2', monthStartDay: const Value(1)));

      final parentId = await repo.createCategory(name: '娱乐', kind: 'expense');
      final sub = await repo.createSubCategory(
          parentId: parentId, name: '电影', kind: 'expense');

      // 两个账本各挂一笔到子分类
      await repo.addTransaction(
        ledgerId: lid1,
        type: 'expense',
        amount: 60,
        categoryId: sub,
        happenedAt: DateTime(2026, 7, 1),
      );
      await repo.addTransaction(
        ledgerId: lid2,
        type: 'expense',
        amount: 90,
        categoryId: sub,
        happenedAt: DateTime(2026, 7, 2),
      );

      // allLedgers 场景：不传 ledgerId，应返回全部账本的交易
      final txs = await repo
          .watchTransactionsByCategory(parentId, includeSubCategories: true)
          .first;
      expect(txs.length, 2, reason: '不限账本时应返回全部子分类交易');
    });
  });
}
