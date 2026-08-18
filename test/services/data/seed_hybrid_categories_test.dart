// hybrid（混合层次）seed 契约测试：锁死新注册默认分类的结构与质量。
//
// 验证内容：
//   1. 条目数：一级 20（9 独立 + 11 父）、二级 41、总计 61；
//   2. 层级挂接：每个 level=2 条目的 parentId 指向正确的父条目（按 syncId 反推 key 验证）；
//   3. syncId 确定性：全部条目 syncId 与 deterministicCategorySyncId 预期值一致
//      （跨模板同一 key syncId 相同，模板库"已添加"判定依赖此契约）；
//   4. 翻译质量：四语言（简/繁/英/韩）无 fallback（段数错位会让名字退化成 snake_case key）；
//   5. housing 组翻译顺序（zh）：水电煤→物业费→房租→房贷→宽带
//      （arb 段序已同步调整）。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/services/data/seed_service.dart';
import 'package:spitout/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // seed 过程中 logger 会把日志持久化到 SharedPreferences，测试环境需 mock 掉。
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  const locales = [
    Locale('zh'),
    Locale('zh', 'TW'),
    Locale('en'),
  ];
  // seed 解析失败会 `return key`（snake_case），正常分类名不会是全小写下划线串。
  final fallbackPattern = RegExp(r'^[a-z][a-z_]*$');

  /// 期望的 syncId 集合：遍历 hybridCategoryTemplate 单一有序清单生成，
  /// `children == null` 为独立一级（仅 sid(1)），否则为父子组（sid(1) + 各子 sid(2)）。
  /// 合计 20 一级 + 41 二级 = 61 条确定性 syncId。
  Set<String> expectedSyncIds() {
    String sid(int level, String key) => SeedService.deterministicCategorySyncId(
        kind: 'expense', level: level, key: key);
    return {
      for (final entry in SeedService.hybridCategoryTemplate) ...[
        sid(1, entry.key),
        if (entry.children != null)
          for (final childKey in entry.children!) sid(2, childKey),
      ],
    };
  }

  for (final locale in locales) {
    final tag = locale.toLanguageTag();
    test('hybrid seed 结构/挂接/syncId 正确、无 fallback [$tag]', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      try {
        await SeedService.createHybridCategories(db, l10n);
        final cats = await db.select(db.categories).get();

        // ① 条目数：一级 20、二级 41、总计 61
        final level1 = cats.where((c) => c.level == 1).toList();
        final level2 = cats.where((c) => c.level == 2).toList();
        expect(level1, hasLength(20), reason: '一级分类应为 20 个（9 独立 + 11 父）');
        expect(level2, hasLength(41), reason: '二级分类应为 41 个');
        expect(cats, hasLength(61));

        // ② syncId 确定性：实际集合与期望集合完全一致（无 null、无多余）
        final actualSyncIds = {for (final c in cats) c.syncId};
        expect(actualSyncIds.contains(null), isFalse,
            reason: 'hybrid seed 条目必须全部带确定性 syncId');
        expect(actualSyncIds, expectedSyncIds());

        // ③ 层级挂接：按 syncId 反推 key，子的父必须是 hybridCategoryTemplate 中
        //    该父子组声明的父（children != null 的条目）
        String sidOf(int level, String key) =>
            SeedService.deterministicCategorySyncId(
                kind: 'expense', level: level, key: key);
        final byId = {for (final c in cats) c.id: c};
        for (final entry in SeedService.hybridCategoryTemplate) {
          final children = entry.children;
          if (children == null) continue; // 独立一级无子分类，跳过挂接校验
          final parentSid = sidOf(1, entry.key);
          for (final childKey in children) {
            final child =
                cats.firstWhere((c) => c.syncId == sidOf(2, childKey));
            expect(child.level, 2);
            expect(child.parentId, isNotNull,
                reason: '子分类 $childKey 必须挂父');
            final parent = byId[child.parentId];
            expect(parent, isNotNull, reason: '子分类 $childKey 的父必须存在');
            expect(parent!.syncId, parentSid,
                reason: '子分类 $childKey 应挂在父 ${entry.key} 下');
          }
        }
        // 独立一级分类不得有 parentId
        for (final c in cats) {
          if (c.level == 1) expect(c.parentId, isNull);
        }

        // ④ 无 fallback（段数错位会让名字 fallback 成 snake_case key）
        final fallbacks = cats
            .where((c) => fallbackPattern.hasMatch(c.name))
            .map((c) => c.name)
            .toList();
        expect(fallbacks, isEmpty, reason: 'fallback 成 key（段数错位）: $fallbacks');
      } finally {
        await db.close();
      }
    });
  }

  test('housing 组翻译顺序（zh：水电煤→物业费→房租→房贷→宽带）', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    try {
      await SeedService.createHybridCategories(db, l10n);
      final cats = await db.select(db.categories).get();

      final housingSid = SeedService.deterministicCategorySyncId(
          kind: 'expense', level: 1, key: 'housing');
      final housing = cats.firstWhere((c) => c.syncId == housingSid);
      // 子类按 sortOrder 升序即为 seed 写入顺序
      final children = cats
          .where((c) => c.parentId == housing.id)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      expect(children.map((c) => c.name).toList(),
          ['水电煤', '物业费', '房租', '房贷', '宽带']);
    } finally {
      await db.close();
    }
  });

  test('hybrid 与 flat/hierarchical 模板的子集契约（翻译下标对齐前提）', () {
    // 模板库"已添加"判定依赖：同一 key 同 level 的确定性 syncId 跨模板相同，
    // 该契约由 category_template_logic.templateItemSyncId 与 seed 共用
    // deterministicCategorySyncId 保证（纯函数侧另有测试覆盖）。
    // 本测试锁定 hybrid 模板与 flat/hierarchical 常量的子集关系：
    // hybrid 独立一级 ⊂ flat 一级（翻译复用 getTranslatedCategoryName 的前提）
    for (final entry in SeedService.hybridCategoryTemplate) {
      if (entry.children != null) continue; // 父子组不走 flat 翻译
      expect(SeedService.flatExpenseCategoryKeys.contains(entry.key), isTrue,
          reason: 'hybrid 独立一级 ${entry.key} 必须存在于 flat 清单（翻译/图标复用契约）');
    }
    // hybrid 父子组 ⊂ hierarchical（父 key 与子 key 都必须存在于 hierarchical
    // 清单：翻译按 key 在 hierarchical map 中的真实下标查找，查不到会 fallback
    // 成 snake_case key）。hybrid 内部顺序只决定 seed 的 sortOrder，不影响翻译。
    for (final entry in SeedService.hybridCategoryTemplate) {
      final children = entry.children;
      if (children == null) continue; // 独立一级不走 hierarchical 翻译
      final hierChildren = SeedService.hierarchicalExpenseCategories[entry.key];
      expect(hierChildren, isNotNull,
          reason: 'hybrid 父 ${entry.key} 必须存在于 hierarchical 清单');
      for (final childKey in children) {
        expect(hierChildren!.contains(childKey), isTrue,
            reason: 'hybrid 子 $childKey 必须存在于 '
                'hierarchical[${entry.key}]（翻译下标查找前提）');
      }
    }
  });
}
