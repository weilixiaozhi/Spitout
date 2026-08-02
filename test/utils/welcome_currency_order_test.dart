// 欢迎页币种顺序纯函数测试。
//
// 覆盖任务：按系统语言生成语言相关的 13 币种顺序，
// 默认选中币种（首项）与系统语言匹配，且包含全部常用币种、无重复。

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/utils/currency/currencies.dart';

void main() {
  test('welcomeCurrencyOrder: 各语言默认选中项(首项)与系统语言匹配', () {
    // 简体中文 → 人民币置顶
    expect(welcomeCurrencyOrder('zh', 'CN').first, 'CNY');
    // 繁体中文(台湾) → 新台币置顶
    expect(welcomeCurrencyOrder('zh', 'TW').first, 'TWD');
    // 韩语 → 韩币置顶
    expect(welcomeCurrencyOrder('ko', 'KR').first, 'KRW');
    // 英语 → 美元置顶（修复"英文却第一位还是人民币"的错位）
    expect(welcomeCurrencyOrder('en', 'US').first, 'USD');
  });

  test('welcomeCurrencyOrder: 返回完整 13 个常用币种且无重复、顺序唯一', () {
    final langs = [
      ['zh', 'CN'],
      ['zh', 'TW'],
      ['ko', 'KR'],
      ['en', 'US'],
    ];
    for (final l in langs) {
      final order = welcomeCurrencyOrder(l[0], l[1]);
      // 长度与 kCommonCurrencyCodes 一致（仍为完整 13 个，仅顺序重排）
      expect(order.length, kCommonCurrencyCodes.length,
          reason: '${l[0]} 顺序应包含全部 13 个常用币种');
      // 无重复币种
      expect(order.toSet().length, order.length,
          reason: '${l[0]} 顺序不应有重复币种');
      // 覆盖全部常用币种
      for (final c in kCommonCurrencyCodes) {
        expect(order.contains(c), isTrue, reason: '${l[0]} 顺序应含 $c');
      }
    }
  });

  test('welcomeCurrencyOrder: 未知语言回退到英语顺序(USD 置顶)', () {
    expect(welcomeCurrencyOrder('xx', '').first, 'USD',
        reason: '未知语言应回退到英语顺序');
    expect(welcomeCurrencyOrder('', '').first, 'USD',
        reason: '空语言码应回退到英语顺序');
  });
}
