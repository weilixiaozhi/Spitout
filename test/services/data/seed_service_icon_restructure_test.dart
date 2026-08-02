// 分类默认图标/名称重构测试
//
// 验证内容：
//   1. getDefaultIcon 返回的重构后图标名（11 处改动）正确无遗漏
//   2. lollipop 图标已登记到 lucideIconLibrary（新增登记项）
//   3. 所有 seed 分类 key 的默认图标均命中注册表（无回退兜底）
//   4. 确定性 syncId 计算与 level 关联（level 变化 → syncId 变化）

import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/services/data/seed_service.dart';
import 'package:spitout/theme/icons/category_icons.dart';

void main() {
  group('分类默认图标重构', () {
    /// 重构后的图标映射表
    /// 仅列出本次发生变更的 11 个 key，其余 key 不在本测试断言范围。
    const changedIcons = <String, String>{
      // key: 分类 key, value: 重构后预期图标名
      'dining_breakfast': 'sandwich',
      'dining_lunch': 'salad',
      'dining_dinner': 'soup',
      'beverage_milk_tea': 'cupSoda',
      'beverage_water': 'glassWater',
      'transport': 'bus',
      'entertainment': 'partyPopper',
      'sports': 'dumbbell',
      'snacks': 'lollipop',
      'beverage': 'milk',
      'beverage_soda': 'beer',
    };

    test('getDefaultIcon 返回重构后的正确图标名', () {
      for (final entry in changedIcons.entries) {
        final actual = SeedService.getDefaultIcon(entry.key);
        expect(
          actual,
          entry.value,
          reason: 'key="${entry.key}" 的默认图标应为 "${entry.value}"，'
              '实际为 "$actual"（图标重构后未生效或回退）',
        );
      }
    });

    test('lollipop 图标已登记到 lucideIconLibrary', () {
      // lollipop 是本次新增登记的图标，snacks 一级分类默认图标依赖它。
      // 未登记会导致运行时回退到 helpCircle 兜底图标。
      expect(
        lucideIconLibrary.containsKey('lollipop'),
        isTrue,
        reason: 'lollipop 必须登记到 lucideIconLibrary，否则 snacks 分类图标会回退兜底',
      );
      expect(
        lucideIconLibrary['lollipop'],
        isNotNull,
        reason: 'lollipop 对应的 IconData 不应为 null',
      );
    });

    test('所有 seed 分类 key 的默认图标均命中 lucideIconLibrary（零回退）', () {
      // 合并一级 + 二级分类的所有 key，确保无任何 key 回退到 'category' 兜底
      final allKeys = <String>{
        ...SeedService.flatExpenseCategoryKeys,
        ...SeedService.hierarchicalExpenseCategories.values.expand((c) => c),
        ...SeedService.hierarchicalExpenseCategories.keys,
      };

      final gaps = <String>[];
      for (final key in allKeys) {
        final iconName = SeedService.getDefaultIcon(key);
        if (!lucideIconLibrary.containsKey(iconName)) {
          gaps.add('key="$key" → icon="$iconName" 未在注册表中登记');
        }
      }

      expect(
        gaps,
        isEmpty,
        reason: '存在未登记图标，运行时会回退到兜底图标: \n${gaps.join('\n')}',
      );
    });

    test('未知 key 回退到 category 兜底图标名', () {
      // 边界条件：传入不存在的 key，应返回 'category' 而非 null
      expect(
        SeedService.getDefaultIcon('non_existent_key_xyz'),
        'category',
        reason: '未知 key 应回退到 "category" 默认图标名',
      );
    });

    test('重构后的图标名均已在 lucideIconLibrary 中注册', () {
      // 确保重构涉及的 11 个图标名全部在注册表中可用
      for (final iconName in changedIcons.values) {
        expect(
          lucideIconLibrary.containsKey(iconName),
          isTrue,
          reason: '图标名 "$iconName" 必须在 lucideIconLibrary 中注册',
        );
      }
    });
  });

  group('确定性 syncId 计算 (deterministicCategorySyncId)', () {
    test('相同 kind/level/key 产生相同 syncId（确定性）', () {
      final id1 = SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 1,
        key: 'dining',
      );
      final id2 = SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 1,
        key: 'dining',
      );

      expect(id1, id2, reason: '相同输入必须产生相同 syncId（UUID v5 确定性）');
    });

    test('不同 level 产生不同 syncId（level 参与哈希）', () {
      // syncId 把 level 掺入哈希，同 key 不同 level 算出不同 syncId。
      // 这保证一级「dining」和二级「dining」不会因 syncId 碰撞被云端去重。
      final level1Id = SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 1,
        key: 'shopping_shoes',
      );
      final level2Id = SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 2,
        key: 'shopping_shoes',
      );

      expect(
        level1Id,
        isNot(equals(level2Id)),
        reason: '同 key 不同 level 必须产生不同 syncId，防止跨层级碰撞去重',
      );
    });

    test('不同 key 产生不同 syncId', () {
      final id1 = SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 1,
        key: 'transport',
      );
      final id2 = SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 1,
        key: 'dining',
      );

      expect(id1, isNot(equals(id2)), reason: '不同 key 必须产生不同 syncId');
    });

    test('syncId 为合法 UUID v5 格式', () {
      final id = SeedService.deterministicCategorySyncId(
        kind: 'expense',
        level: 1,
        key: 'dining',
      );

      // UUID v5 格式：8-4-4-4-12，version 位为 5
      expect(id.length, 36, reason: 'UUID 字符串长度应为 36（含 4 个连字符）');
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(id), isTrue, reason: '应为合法 UUID v5 格式（version=5）');
    });
  });
}
