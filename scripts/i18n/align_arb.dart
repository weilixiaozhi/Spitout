#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// 对齐官方语言 ARB 文件（en / zh / zh_TW）：
/// 1. 键顺序统一为模板 app_en.arb 的顺序；
/// 2. 每个键的 @元数据块三份文件保持一致（缺则从其他文件补齐，优先级 en > zh > zh_TW）；
/// 3. 统一 4 空格缩进，便于对比 diff。
///
/// 用法：dart scripts/i18n/align_arb.dart
library;

import 'dart:convert';
import 'dart:io';

const arbDir = 'lib/l10n';
const locales = ['en', 'zh', 'zh_TW'];

void main() {
  final data = <String, Map<String, dynamic>>{};
  for (final locale in locales) {
    final file = File('$arbDir/app_$locale.arb');
    data[locale] =
        jsonDecode(file.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
  }

  // 模板键顺序（en），剔除 @ 元数据键。
  final templateKeys = data['en']!.keys.toList();
  final messageKeys =
      templateKeys.where((key) => !key.startsWith('@')).toList();

  // 每个键的元数据取三份中第一份存在的，保证三份内容一致。
  final metadata = <String, dynamic>{};
  for (final key in messageKeys) {
    for (final locale in locales) {
      final meta = data[locale]!['@$key'];
      if (meta != null) {
        metadata[key] = meta;
        break;
      }
    }
  }

  final encoder = const JsonEncoder.withIndent('    ');
  for (final locale in locales) {
    final original = data[locale]!;
    final rebuilt = <String, dynamic>{};
    // 每份文件都带 @@locale（缺失则按语言代码补齐）。
    rebuilt['@@locale'] = original['@@locale'] ?? locale;
    for (final key in messageKeys) {
      rebuilt[key] = original[key];
      final meta = metadata[key];
      if (meta != null) {
        rebuilt['@$key'] = meta;
      }
    }
    for (final key in original.keys) {
      if (!rebuilt.containsKey(key)) {
        if (key.startsWith('@')) {
          print('⚠️  $locale：丢弃孤儿元数据 $key（无对应消息键）');
        } else {
          print('⚠️  $locale：追加额外消息键 $key');
          rebuilt[key] = original[key];
        }
      }
    }
    final file = File('$arbDir/app_$locale.arb');
    file.writeAsStringSync('${encoder.convert(rebuilt)}\n', encoding: utf8);
    print('✅ app_$locale.arb：${rebuilt.length} 键，元数据 ${metadata.length} 块，已按模板对齐');
  }
}
