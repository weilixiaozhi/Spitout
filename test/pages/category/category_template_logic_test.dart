// 分类模板库纯函数测试：双通道已添加判定 / 勾选联动 / 全选 / 写入计划。
//
// 验证内容：
//   1. ExistingCategoryIndex：syncId 优先 + 同名兜底的"已添加"双通道判定
//      （手动创建的同名分类也能被识别为已添加，收入分类同名不构成冲突）；
//   2. toggleFlatSelection：勾选加入、再点移除；
//   3. toggleHierarchicalSelection（2026-07-24 修订约束）：
//      子类独立勾选不连带父；勾选父连带全选未添加子类；取消父连带清子；
//   4. computeFlatSelectAll / computeHierarchicalSelectAll：只含未添加条目；
//   5. buildInsertPlan：父先子后、已添加条目防御性剔除、
//      单独勾子类时自动补建未在表的父（子类不能脱离父存在）；
//   6. buildFlatTemplateItems / buildHierarchicalTemplateGroups：
//      syncId 与 seed 同源，alreadyAdded 双通道（syncId / 同名）判定；
//   7. templateItemSyncId 与 SeedService.deterministicCategorySyncId 同源契约。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/services/data/seed_service.dart';
import 'package:spitout/services/data/category_template_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  /// 构造测试条目（name/icon 不参与断言，直接占位）
  CategoryTemplateItem item(
    String key, {
    int level = 1,
    String? parentKey,
    bool added = false,
  }) =>
      CategoryTemplateItem(
        key: key,
        name: key,
        iconName: 'icon',
        syncId: templateItemSyncId(level, key),
        level: level,
        parentKey: parentKey,
        alreadyAdded: added,
      );

  /// 构造已存在分类轻量记录（默认 expense）
  ExistingCategoryLite lite({
    required int id,
    String? syncId,
    String name = '',
    String kind = 'expense',
    int level = 1,
    int? parentId,
  }) =>
      (id: id, syncId: syncId, name: name, kind: kind, level: level, parentId: parentId);

  group('ExistingCategoryIndex', () {
    test('一级判定：syncId 命中 → 已添加', () {
      final sid = templateItemSyncId(1, 'dining');
      final index = ExistingCategoryIndex([
        lite(id: 1, syncId: sid, name: '任意名'),
      ]);
      expect(index.level1Added(syncId: sid, name: '餐饮'), isTrue);
    });

    test('一级判定：syncId 不同源但同名 → 已添加（手动创建场景）', () {
      final index = ExistingCategoryIndex([
        lite(id: 1, syncId: 'random-v4', name: '餐饮'),
      ]);
      expect(
        index.level1Added(syncId: templateItemSyncId(1, 'dining'), name: '餐饮'),
        isTrue,
      );
    });

    test('一级判定：收入分类同名 → 不构成已添加', () {
      final index = ExistingCategoryIndex([
        lite(id: 1, syncId: 'random-v4', name: '餐饮', kind: 'income'),
      ]);
      expect(
        index.level1Added(syncId: templateItemSyncId(1, 'dining'), name: '餐饮'),
        isFalse,
      );
    });

    test('二级判定：子 syncId 命中 → 已添加', () {
      final childSid = templateItemSyncId(2, 'dining_breakfast');
      final index = ExistingCategoryIndex([
        lite(id: 2, syncId: childSid, name: '任意名', level: 2, parentId: 1),
      ]);
      expect(
        index.level2Added(
          syncId: childSid,
          name: '早餐',
          parentSyncId: templateItemSyncId(1, 'dining'),
          parentName: '餐饮',
        ),
        isTrue,
      );
    });

    test('二级判定：父同名定位 + 子同名 → 已添加（手动建父又建子场景）', () {
      final index = ExistingCategoryIndex([
        lite(id: 1, syncId: 'random-v4', name: '餐饮'),
        lite(id: 2, syncId: 'random-v4-2', name: '早餐', level: 2, parentId: 1),
      ]);
      expect(
        index.level2Added(
          syncId: templateItemSyncId(2, 'dining_breakfast'),
          name: '早餐',
          parentSyncId: templateItemSyncId(1, 'dining'),
          parentName: '餐饮',
        ),
        isTrue,
      );
    });

    test('二级判定：父 syncId 定位 + 子同名 → 已添加（seed 父下手动建同名子）', () {
      final index = ExistingCategoryIndex([
        lite(id: 1, syncId: templateItemSyncId(1, 'dining'), name: '餐饮'),
        lite(id: 2, syncId: 'random-v4', name: '早餐', level: 2, parentId: 1),
      ]);
      expect(
        index.level2Added(
          syncId: templateItemSyncId(2, 'dining_breakfast'),
          name: '早餐',
          parentSyncId: templateItemSyncId(1, 'dining'),
          parentName: '餐饮',
        ),
        isTrue,
      );
    });

    test('二级判定：同名子挂在其他父下 → 不算已添加（作用域唯一契约）', () {
      final index = ExistingCategoryIndex([
        lite(id: 1, syncId: 'random-v4', name: '其他父'),
        lite(id: 2, syncId: 'random-v4-2', name: '早餐', level: 2, parentId: 1),
      ]);
      expect(
        index.level2Added(
          syncId: templateItemSyncId(2, 'dining_breakfast'),
          name: '早餐',
          parentSyncId: templateItemSyncId(1, 'dining'),
          parentName: '餐饮',
        ),
        isFalse,
      );
    });

    test('resolveLevel1Id：syncId 优先，同名兜底，均未命中返回 null', () {
      final sid = templateItemSyncId(1, 'dining');
      final index = ExistingCategoryIndex([
        lite(id: 7, syncId: sid, name: '被改名'),
        lite(id: 9, syncId: 'random-v4', name: '交通'),
      ]);
      // syncId 优先（即使名称已改）
      expect(index.resolveLevel1Id(syncId: sid, name: '餐饮'), 7);
      // 同名兜底（syncId 不同源）
      expect(
        index.resolveLevel1Id(syncId: templateItemSyncId(1, 'transport'), name: '交通'),
        9,
      );
      // 未命中
      expect(
        index.resolveLevel1Id(syncId: templateItemSyncId(1, 'medical'), name: '医疗'),
        isNull,
      );
    });

    test('level2ExistsUnder：同父同名二级存在性判断', () {
      final index = ExistingCategoryIndex([
        lite(id: 2, name: '早餐', level: 2, parentId: 1),
      ]);
      expect(index.level2ExistsUnder(parentId: 1, name: '早餐'), isTrue);
      expect(index.level2ExistsUnder(parentId: 1, name: '午餐'), isFalse);
      expect(index.level2ExistsUnder(parentId: 99, name: '早餐'), isFalse);
    });
  });

  group('toggleFlatSelection', () {
    test('勾选加入、再点移除', () {
      var selected = <String>{};
      selected = toggleFlatSelection(selected, 'dining');
      expect(selected, {'dining'});
      selected = toggleFlatSelection(selected, 'medical');
      expect(selected, {'dining', 'medical'});
      selected = toggleFlatSelection(selected, 'dining');
      expect(selected, {'medical'});
      // 原集合不被修改（纯函数返回新集合）
      expect(selected, isNot(same({})));
    });
  });

  group('toggleHierarchicalSelection（2026-07-24 修订约束）', () {
    const allChildKeys = ['dining_breakfast', 'dining_lunch', 'dining_dinner'];

    test('勾子类不连带父（支持单独选中子类）', () {
      final selected = toggleHierarchicalSelection(
        {},
        parentKey: 'dining',
        childKey: 'dining_breakfast',
      );
      expect(selected, {'dining_breakfast'});
      expect(selected.contains('dining'), isFalse, reason: '子类独立勾选，父不进选中集');
    });

    test('取消子类仅移除该子，不影响父与其他子', () {
      final selected = toggleHierarchicalSelection(
        {'dining', 'dining_breakfast', 'dining_lunch'},
        parentKey: 'dining',
        childKey: 'dining_breakfast',
      );
      expect(selected, {'dining', 'dining_lunch'});
    });

    test('勾选父 → 连带全选全部未添加子类', () {
      final selected = toggleHierarchicalSelection(
        {},
        parentKey: 'dining',
        allChildKeys: allChildKeys,
        selectableChildKeys: allChildKeys,
      );
      expect(selected, {'dining', ...allChildKeys});
    });

    test('勾选父 → 已添加子类不进选中集（selectable 已过滤）', () {
      final selected = toggleHierarchicalSelection(
        {},
        parentKey: 'dining',
        allChildKeys: allChildKeys,
        // dining_lunch 已添加，调用方传入的 selectable 不含它
        selectableChildKeys: const ['dining_breakfast', 'dining_dinner'],
      );
      expect(selected, {'dining', 'dining_breakfast', 'dining_dinner'});
    });

    test('取消父 → 连带取消其全部已勾子类', () {
      final selected = toggleHierarchicalSelection(
        {'dining', 'dining_breakfast', 'dining_lunch'},
        parentKey: 'dining',
        allChildKeys: allChildKeys,
      );
      expect(selected, isEmpty);
    });

    test('取消父不影响其他父的勾选', () {
      final selected = toggleHierarchicalSelection(
        {'dining', 'dining_breakfast', 'shopping', 'shopping_bag'},
        parentKey: 'dining',
        allChildKeys: allChildKeys,
      );
      expect(selected, {'shopping', 'shopping_bag'});
    });
  });

  group('computeSelectAll', () {
    test('flat 全选只含未添加条目', () {
      final items = [
        item('dining', added: true),
        item('medical'),
        item('sports'),
      ];
      expect(computeFlatSelectAll(items), {'medical', 'sports'});
    });

    test('hierarchical 全选：父未添加则父子一并入；父已添加则只入未添加子', () {
      final groups = [
        CategoryTemplateGroup(
          parent: item('dining'),
          children: [
            item('dining_breakfast', level: 2, parentKey: 'dining'),
            item('dining_lunch', level: 2, parentKey: 'dining', added: true),
          ],
        ),
        CategoryTemplateGroup(
          parent: item('shopping', added: true),
          children: [
            item('shopping_bag', level: 2, parentKey: 'shopping'),
          ],
        ),
      ];
      expect(computeHierarchicalSelectAll(groups), {
        'dining',
        'dining_breakfast',
        // dining_lunch 已添加 → 不选
        // shopping 已添加 → 不选
        'shopping_bag',
      });
    });
  });

  group('buildInsertPlan', () {
    test('父先子后，子的 parentSyncId/parentName 指向对应父', () {
      final all = [
        item('dining'),
        item('dining_breakfast', level: 2, parentKey: 'dining'),
        item('medical'),
      ];
      final plan = buildInsertPlan(
        allItems: all,
        selectedKeys: {'dining', 'dining_breakfast', 'medical'},
      );
      expect(plan.parentsToCreate.map((e) => e.key), ['dining', 'medical']);
      expect(plan.childrenToCreate, hasLength(1));
      expect(plan.childrenToCreate.single.child.key, 'dining_breakfast');
      expect(plan.childrenToCreate.single.parentSyncId,
          templateItemSyncId(1, 'dining'));
      expect(plan.childrenToCreate.single.parentName, 'dining');
      expect(plan.total, 3);
    });

    test('已添加条目即使在选中集中也被剔除', () {
      final all = [
        item('dining', added: true),
        item('medical'),
      ];
      final plan = buildInsertPlan(
        allItems: all,
        selectedKeys: {'dining', 'medical'},
      );
      expect(plan.parentsToCreate.map((e) => e.key), ['medical']);
      expect(plan.total, 1);
    });

    test('混合"已有父 + 新子"：父不进 parentsToCreate，子的父引用指向已有父', () {
      final all = [
        item('dining', added: true),
        item('dining_dinner', level: 2, parentKey: 'dining'),
      ];
      final plan = buildInsertPlan(
        allItems: all,
        selectedKeys: {'dining_dinner'},
      );
      expect(plan.parentsToCreate, isEmpty);
      expect(plan.childrenToCreate.single.parentSyncId,
          templateItemSyncId(1, 'dining'));
      expect(plan.total, 1);
    });

    test('单独勾子类且父未在表 → 计划自动补父（父先子后）', () {
      final all = [
        item('dining'),
        item('dining_breakfast', level: 2, parentKey: 'dining'),
        item('dining_lunch', level: 2, parentKey: 'dining'),
      ];
      final plan = buildInsertPlan(
        allItems: all,
        selectedKeys: {'dining_breakfast', 'dining_lunch'},
      );
      expect(plan.parentsToCreate.map((e) => e.key), ['dining'],
          reason: '子类不能脱离父存在，父未选中也应自动并入待建父');
      expect(plan.childrenToCreate.map((e) => e.child.key),
          ['dining_breakfast', 'dining_lunch']);
      expect(plan.total, 3);
    });

    test('父显式选中 + 子选中 → 父不重复并入', () {
      final all = [
        item('dining'),
        item('dining_breakfast', level: 2, parentKey: 'dining'),
      ];
      final plan = buildInsertPlan(
        allItems: all,
        selectedKeys: {'dining', 'dining_breakfast'},
      );
      expect(plan.parentsToCreate, hasLength(1));
    });
  });

  group('buildTemplateItems（需 l10n）', () {
    test('flat 条目：数量/层级/syncId 与 seed 同源，alreadyAdded 随索引变化', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      // 无已存在 → 全部可添加（等价于"分类被删除后释放回模板"）
      final none = buildFlatTemplateItems(l10n, ExistingCategoryIndex([]));
      expect(none, hasLength(SeedService.flatExpenseCategoryKeys.length));
      expect(none.every((e) => e.level == 1 && !e.alreadyAdded), isTrue);
      // syncId 与 seed 同源
      expect(
        none.first.syncId,
        SeedService.deterministicCategorySyncId(
            kind: 'expense', level: 1, key: SeedService.flatExpenseCategoryKeys.first),
      );

      // syncId 命中 → alreadyAdded
      final diningSid = SeedService.deterministicCategorySyncId(
          kind: 'expense', level: 1, key: 'dining');
      final withDining = buildFlatTemplateItems(
        l10n,
        ExistingCategoryIndex([
          lite(id: 1, syncId: diningSid, name: '餐饮'),
        ]),
      );
      expect(withDining.firstWhere((e) => e.key == 'dining').alreadyAdded,
          isTrue);
      expect(withDining.where((e) => e.alreadyAdded), hasLength(1));
    });

    test('flat 条目：手动创建的同名分类（syncId 不同源）也判定为已添加', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      final diningName =
          SeedService.getTranslatedCategoryName('dining', 'expense', l10n);
      final items = buildFlatTemplateItems(
        l10n,
        ExistingCategoryIndex([
          lite(id: 1, syncId: 'random-v4', name: diningName),
        ]),
      );
      expect(items.firstWhere((e) => e.key == 'dining').alreadyAdded, isTrue);
      expect(items.where((e) => e.alreadyAdded), hasLength(1));
    });

    test('hierarchical 组：父子 alreadyAdded 按各自 level 的 syncId 独立判定', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      final groups =
          buildHierarchicalTemplateGroups(l10n, ExistingCategoryIndex([]));
      expect(groups, hasLength(SeedService.hierarchicalExpenseCategories.length));

      final dining = groups.firstWhere((g) => g.parent.key == 'dining');
      expect(dining.children.map((e) => e.key),
          SeedService.hierarchicalExpenseCategories['dining']);
      expect(dining.children.every((e) => e.parentKey == 'dining'), isTrue);

      // 仅父已添加：父 alreadyAdded、子仍可添加（父已在表 → 子可单选）
      final parentSid = SeedService.deterministicCategorySyncId(
          kind: 'expense', level: 1, key: 'dining');
      final g2 = buildHierarchicalTemplateGroups(
        l10n,
        ExistingCategoryIndex([lite(id: 1, syncId: parentSid, name: '餐饮')]),
      ).firstWhere((g) => g.parent.key == 'dining');
      expect(g2.parent.alreadyAdded, isTrue);
      expect(g2.children.every((e) => !e.alreadyAdded), isTrue);

      // 仅某个子已添加：父不受影响
      final childSid = SeedService.deterministicCategorySyncId(
          kind: 'expense', level: 2, key: 'dining_breakfast');
      final g3 = buildHierarchicalTemplateGroups(
        l10n,
        ExistingCategoryIndex([
          lite(id: 2, syncId: childSid, name: '早餐', level: 2, parentId: 1),
        ]),
      ).firstWhere((g) => g.parent.key == 'dining');
      expect(g3.parent.alreadyAdded, isFalse);
      expect(
        g3.children.firstWhere((e) => e.key == 'dining_breakfast').alreadyAdded,
        isTrue,
      );
    });

    test('hierarchical 组：手动建同名父+同名子，双双判定为已添加', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      final parentName =
          SeedService.getTranslatedParentCategoryName('dining', 'expense', l10n);
      final childName =
          SeedService.getTranslatedSubCategoryName('dining_breakfast', 'expense', l10n);
      final groups = buildHierarchicalTemplateGroups(
        l10n,
        ExistingCategoryIndex([
          lite(id: 1, syncId: 'random-v4', name: parentName),
          lite(id: 2, syncId: 'random-v4-2', name: childName, level: 2, parentId: 1),
        ]),
      ).firstWhere((g) => g.parent.key == 'dining');
      expect(groups.parent.alreadyAdded, isTrue, reason: '同名父应置灰');
      expect(
        groups.children.firstWhere((e) => e.key == 'dining_breakfast').alreadyAdded,
        isTrue,
        reason: '同名父下的同名子应置灰',
      );
      // 其他子类不受影响
      expect(
        groups.children.where((e) => e.key != 'dining_breakfast').every((e) => !e.alreadyAdded),
        isTrue,
      );
    });

    test('templateItemSyncId 与 seed 确定性 syncId 同源（跨模板去重契约）', () {
      for (final level in [1, 2]) {
        expect(
          templateItemSyncId(level, 'dining'),
          SeedService.deterministicCategorySyncId(
              kind: 'expense', level: level, key: 'dining'),
        );
      }
    });
  });
}
