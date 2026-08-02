// seed 默认分类契约测试:① 无「同父级作用域内」(name,kind) 重复 ② 无
// fallback(段数错位会让名字 fallback 成 snake_case key)。锁死三语言
// (简/繁/英)seed 二级分类质量。
//
// 唯一性契约说明(2026-07 分类默认结构重排后调整):
//  - 一级分类之间:name+kind 必须唯一;
//  - 同一父级下的二级分类之间:name+kind 必须唯一;
//  - 跨父级的二级分类**允许**同名(如「购物>鞋子」与「服装>鞋子」)、
//    一级与二级也允许同名(如「服装」父分类 vs「购物>服装」子分类)。
//    按名反查的调用点(sync 收编/解析)已按 level+parentId 收窄并容错多行。
//
// 历史坑(均已修,见 #118):
//  1. 英文词内连字符(Part-time / Year-end / Ride-hailing)被 split('-') 拆碎 → 改空格。
//  2. 三语言部分分类缺「父分类名」致段数错位、fallback 成 key → 补父名,对齐
//     「子类数 + 1」段。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import '../../helpers/test_isolation.dart';

import 'package:spitout/data/db.dart';
import 'package:spitout/services/data/seed_service.dart';
import 'package:spitout/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // seed 过程中 logger 会把日志持久化到 SharedPreferences,测试环境需 mock 掉。
  // 每个用例前重置全局状态（prefs mock / 平台 TestValue / 通知单例），
  // 防止跨用例残留导致的顺序依赖。详见 test/helpers/test_isolation.dart。
  setUp(() => resetGlobalTestState());

  const locales = [
    Locale('zh'),
    Locale('zh', 'TW'),
    Locale('en'),
  ];
  // seed 解析失败会 `return key`(snake_case),正常分类名不会是全小写下划线串。
  final fallbackPattern = RegExp(r'^[a-z][a-z_]*$');

  for (final locale in locales) {
    final tag = locale.toLanguageTag();
    test('seed 二级分类无重复、无 fallback [$tag]', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
      try {
        await SeedService.createHierarchicalCategories(db, l10n);
        final cats = await db.select(db.categories).get();

        // ① 无「同父级作用域内」(name,kind) 重复:
        //    以 parentId 作为作用域 key(一级分类 parentId 为 null,
        //    自然归入同一个「根作用域」互相比较)。跨父级同名是合法设计。
        final seen = <String>{};
        final dups = <String>[];
        for (final c in cats) {
          if (!seen.add('${c.parentId}|${c.name}|${c.kind}')) {
            dups.add('${c.name}|${c.kind} (L${c.level}, parent=${c.parentId})');
          }
        }
        expect(dups, isEmpty, reason: '同父级下重复分类: $dups');

        // ② 无 fallback(段数错位会让名字 fallback 成 snake_case key)
        final fallbacks = cats
            .where((c) => fallbackPattern.hasMatch(c.name))
            .map((c) => c.name)
            .toList();
        expect(fallbacks, isEmpty, reason: 'fallback 成 key(段数错位): $fallbacks');
      } finally {
        await db.close();
      }
    });
  }
}
