import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/services/data/seed_service.dart';
import 'package:spitout/theme/icons/category_icons.dart';

/// 主题/图标架构约束 + 图标完整性审计（统一校验流程）。
///
/// 图标缺口审计逻辑与架构约束保护：
/// - colors.dart 不得反向依赖 provider（Token 层纯展示）；
/// - 主题色板魔法数字仅允许存在于 SpitoutColors（单一真相源）；
/// - seed 分类默认图标 100% 命中 lucideIconLibrary（图标资源完整无遗漏）。
void main() {
  group('架构约束: 主题 Token 层纯展示（阶段一/三）', () {
    test('colors.dart 不得反向依赖 provider', () {
      final content = File('lib/theme/colors.dart').readAsStringSync();
      expect(
        content.contains('flutter_riverpod'),
        isFalse,
        reason:
            'colors.dart 不应 import flutter_riverpod：Token 层禁止反向依赖 '
            'Provider（阶段三已删除 SpitoutTokens.expenseColor）',
      );
      expect(
        content.contains('theme_providers'),
        isFalse,
        reason: 'colors.dart 不应 import providers/theme_providers',
      );
    });

    /// 守护阶段二「颜色单一真相源」：除集中色板文件外，主题目录下不应再散落
    /// Color(0xFF..) 魔法数字，避免改色要满仓找。
    test('主题色板魔法数字仅存在于 SpitoutColors (colors.dart)', () {
      final offenders = <String>[];
      for (final entity in Directory('lib/theme').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('colors.dart')) continue; // 唯一允许颜色字面量的文件
        final c = entity.readAsStringSync();
        if (c.contains('Color(0x')) offenders.add(entity.path);
      }
      expect(
        offenders,
        isEmpty,
        reason:
            '除 colors.dart 外的主题文件不应再出现 Color(0xFF..) 魔法数字: '
            '${offenders.join(', ')}',
      );
    });
  });

  group('图标完整性审计（统一校验流程）', () {
    /// 整合自原 category_icon_audit_test.dart：seed 分类的默认图标名必须全部
    /// 命中 lucideIconLibrary，缺口必须为 0（回退到兜底即视为缺口）。
    test('seed 分类默认图标 100% 命中 lucideIconLibrary（缺口必须为 0）', () {
      // 合并一级(扁平) + 二级(层级)分类的所有 key。
      final allKeys = <String>{
        ...SeedService.flatExpenseCategoryKeys,
        ...SeedService.hierarchicalExpenseCategories.values.expand((c) => c),
      };

      final gaps = <String>[];
      final missingIconNames = <String>{};
      final sb = StringBuffer()..writeln('=== 分类图标缺口审计 ===');

      for (final key in allKeys) {
        final iconName = SeedService.getDefaultIcon(key); // seed 意图图标名
        final icon =
            lucideIconLibrary[iconName] ??
            lucideFallback; // 运行时真实解析（与 category_icon.dart 的 resolveCategoryIcon 口径一致）
        if (icon == lucideFallback) {
          // 命中注册表兜底即视为缺口。
          gaps.add('$key -> "$iconName" 未命中 lucideIconLibrary');
          missingIconNames.add(iconName);
        }
      }

      for (final g in gaps) {
        sb.writeln('  ⚠ $g');
      }
      sb
        ..writeln('---')
        ..writeln('共 ${allKeys.length} 个分类, ${gaps.length} 个缺口')
        ..writeln('缺失的 icon 名(去重): ${missingIconNames.join(', ')}');
      debugPrint(sb.toString());

      // 回归保护：seed 分类的默认图标名必须全部命中注册表。
      // 仅在有缺口时才写入报告文件，避免每次通过都生成冗余文件。
      if (gaps.isNotEmpty) {
        final reportFile = File('.icon_audit_report.txt');
        reportFile.writeAsStringSync(sb.toString());
        expect(
          gaps,
          isEmpty,
          reason: 'seed 分类默认图标必须全部命中注册表: ${gaps.join('; ')}',
        );
      }
    });

    /// 防御性约束：lucideIconLibrary 除兜底键 'helpCircle' 本身（其值就是
    /// lucideFallback，供 CategoryService 未命中时回退）外，其余 key 不应再
    /// 直接映射到兜底图标，防止误把兜底当成真实语义映射提交。
    test('lucideIconLibrary 内不允许把兜底图标当作真实映射', () {
      final misuse = lucideIconLibrary.entries
          .where((e) => e.key != 'helpCircle' && e.value == lucideFallback)
          .map((e) => e.key)
          .toList();
      expect(
        misuse,
        isEmpty,
        reason:
            'lucideIconLibrary 不应有任何 key 直接映射到兜底 helpCircle: '
            '${misuse.join(', ')}',
      );
    });
  });
}
