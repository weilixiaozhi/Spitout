// categoryPickerTreeProvider 测试
//
// 验证内容：
//   1. 主表路径：首发即为合并后的分类树（一级排序 + 二级分组）
//   2. 零手动 invalidate：写 categories 表后 provider 自动重发新树
//   3. 共享账本 Editor 路径：主表内容整体丢弃，替换为
//      SharedLedgerCategories 的 synthetic 分类树（id < 0）

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/data/repositories/support/shared_ledger_picker_filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      // 默认值已改为哨兵 0（表示「未选中」），此处显式指定 1 以匹配插入的账本 id。
      currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
    ]);
    // currentLedgerIdProvider 初值为 1，插入对应账本供 picker 上下文解析
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '默认账本'));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 向主表插入一级支出分类，返回其 id
  Future<int> addTopCategory(String name, {int sortOrder = 0}) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          name: name,
          kind: 'expense',
          sortOrder: d.Value(sortOrder),
        ));
  }

  /// 轮询等待条件成立（Drift 表变更通知经 isolate 异步到达，
  /// 不能用 pumpEventQueue 假定时序），超时即失败。
  Future<void> waitFor(bool Function() cond, String reason) async {
    for (var i = 0; i < 200; i++) {
      if (cond()) return;
      await Future.delayed(const Duration(milliseconds: 10));
    }
    fail('等待超时: $reason');
  }

  test('主表路径：首发即为合并后的分类树', () async {
    final foodId = await addTopCategory('餐饮', sortOrder: 1);
    await addTopCategory('交通', sortOrder: 0);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
      name: '早餐',
      kind: 'expense',
      parentId: d.Value(foodId),
      level: const d.Value(2),
    ));

    final tree = await readProviderFutureFromContainer(
      container,
      categoryPickerTreeProvider('expense').future,
    );

    expect(tree.topLevel.map((c) => c.name), ['交通', '餐饮']);
    expect(tree.children[foodId]!.single.name, '早餐');
  });

  test('写 categories 表后自动重发新树（零手动 invalidate）', () async {
    await addTopCategory('餐饮');
    final first = await readProviderFutureFromContainer(
      container,
      categoryPickerTreeProvider('expense').future,
    );
    expect(first.topLevel.single.name, '餐饮');

    final emissions = <String>[];
    final sub = container.listen(
      categoryPickerTreeProvider('expense'),
      (prev, next) {
        final v = next.value;
        if (v != null) {
          emissions.add(v.topLevel.map((c) => c.name).join(','));
        }
      },
      fireImmediately: true,
    );

    await addTopCategory('交通');
    await waitFor(
      () => emissions.isNotEmpty && emissions.last.contains('交通'),
      'categories 表写入后 provider 应自动重发包含新分类的树',
    );
    sub.close();
  });

  test('共享账本 Editor 路径：整树替换为 synthetic 分类', () async {
    // 主表数据在 Editor 视角应被整体丢弃
    await addTopCategory('本地分类');
    // 当前账本设为共享账本 Editor
    await (db.update(db.ledgers)..where((t) => t.id.equals(1))).write(
      const LedgersCompanion(
        isShared: d.Value(true),
        myRole: d.Value('editor'),
        syncId: d.Value('LS1'),
      ),
    );
    // Owner 侧共享分类：一父一子
    await db.into(db.sharedLedgerCategories).insert(
        SharedLedgerCategoriesCompanion.insert(
      ledgerSyncId: 'LS1',
      syncId: 'c1',
      name: '共享餐饮',
      kind: 'expense',
      updatedAt: DateTime.now(),
    ));
    await db.into(db.sharedLedgerCategories).insert(
        SharedLedgerCategoriesCompanion.insert(
      ledgerSyncId: 'LS1',
      syncId: 'c2',
      name: '共享早餐',
      kind: 'expense',
      level: const d.Value(2),
      parentSyncId: const d.Value('c1'),
      updatedAt: DateTime.now(),
    ));

    final tree = await readProviderFutureFromContainer(
      container,
      categoryPickerTreeProvider('expense').future,
    );

    final parentSynthetic = syntheticIdForSyncId('c1');
    final childSynthetic = syntheticIdForSyncId('c2');
    expect(tree.topLevel.map((c) => c.id), [parentSynthetic]);
    expect(tree.topLevel.single.name, '共享餐饮');
    expect(tree.children[parentSynthetic]!.single.id, childSynthetic);
    expect(tree.children[parentSynthetic]!.single.name, '共享早餐');
    // 主表分类不出现（Editor 视角整体替换）
    expect(tree.topLevel.any((c) => c.name == '本地分类'), false);
  });
}
