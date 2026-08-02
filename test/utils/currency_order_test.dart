// orderCurrencies 排序 helper 纯函数测试。
//
// 覆盖任务：主币种常驻置顶（无论常用/非常用）+ 常用币种按系统语言排序
// （与欢迎页 welcomeCurrencyOrder 一致）+ 其余非常用币种保持原始地区顺序。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:spitout/utils/currency/currencies.dart';

void main() {
  // 构造测试用源列表：13 个常用币种 + 若干非常用币种(BTC/XAU/AAA/ZZZ)。
  // 其中 AAA 作为「其他币种」代表（不在 kCommonCurrencyCodes 中）。
  List<CurrencyInfo> buildSource() {
    const codes = [
      'CNY', 'USD', 'EUR', 'JPY', 'HKD', 'TWD', 'MOP', 'GBP', 'KRW', 'AUD',
      'CAD', 'SGD', 'THB', // 13 个常用
      'BTC', 'XAU', 'AAA', 'ZZZ', // 非常用（AAA = 其他币种主币种场景）
    ];
    return codes.map((c) => CurrencyInfo(c, c)).toList();
  }

  test('非常用主币种(AAA)常驻置顶，不受语言排序影响', () {
    // 英文环境常用币种首项应为 USD，但主币种 AAA(非常用)必须压到最前。
    final ordered = orderCurrencies(buildSource(), const Locale('en', 'US'),
        pinned: ['AAA']);
    expect(ordered.first.code, 'AAA', reason: '非常用主币种应置顶');
    // 紧接着应是英文优先的常用币种 USD
    expect(ordered[1].code, 'USD', reason: '英文环境常用币种首项应为 USD');
    // AAA 不能在后面重复出现
    expect(ordered.where((c) => c.code == 'AAA').length, 1);
  });

  test('常用主币种(USD)常驻置顶：繁中环境也应压过语言排序', () {
    // 繁体中文(TW)常用币种首项为 TWD，但主币种 USD 必须置顶。
    final ordered = orderCurrencies(buildSource(), const Locale('zh', 'TW'),
        pinned: ['USD']);
    expect(ordered.first.code, 'USD', reason: '常用主币种应置顶');
    // 之后出现 TWD（TW 环境常用首项）
    expect(ordered.any((c) => c.code == 'TWD'), isTrue);
  });

  test('常用主币种只出现一次：置顶区与常用列表不重复', () {
    // 严重 bug 回归:主币种为常用币种(USD)时,不能既置顶又在常用列表中再出现一条,
    // 否则同一币种产生两条记录(两个勾选态)。
    final ordered = orderCurrencies(buildSource(), const Locale('en', 'US'),
        pinned: ['USD']);
    expect(ordered.where((c) => c.code == 'USD').length, 1,
        reason: '常用主币种不应重复出现');
    // 非常用主币种(AAA)同样只出现一次
    final ordered2 = orderCurrencies(buildSource(), const Locale('en', 'US'),
        pinned: ['AAA']);
    expect(ordered2.where((c) => c.code == 'AAA').length, 1);
  });

  test('主币种与选中值相同(selected==主币种)时不产生重复项', () {
    final ordered = orderCurrencies(buildSource(), const Locale('en', 'US'),
        pinned: ['AAA', 'AAA']);
    expect(ordered.where((c) => c.code == 'AAA').length, 1,
        reason: '重复 pin 不应产生重复行');
    expect(ordered.first.code, 'AAA');
  });

  test('常用币种按系统语言排序（与欢迎页口径一致）', () {
    // 英文：USD 应在 EUR/CNY 之前；简体：CNY 应在 USD 之前。
    final en = orderCurrencies(buildSource(), const Locale('en', 'US'));
    final enCommon = en.where((c) => kCommonCurrencyCodes.contains(c.code));
    expect(enCommon.first.code, 'USD');

    final zh = orderCurrencies(buildSource(), const Locale('zh', 'CN'));
    final zhCommon = zh.where((c) => kCommonCurrencyCodes.contains(c.code));
    expect(zhCommon.first.code, 'CNY');

    // 繁体中文(TW)首项为 TWD
    final tw = orderCurrencies(buildSource(), const Locale('zh', 'TW'));
    final twCommon = tw.where((c) => kCommonCurrencyCodes.contains(c.code));
    expect(twCommon.first.code, 'TWD');
  });

  test('非常用且未置顶币种保持源列表原始地区顺序', () {
    // 不置顶任何币种，尾巴部分的非常用币种应保持 BTC→XAU→AAA→ZZZ 原顺序。
    final ordered = orderCurrencies(buildSource(), const Locale('en', 'US'));
    final tail =
        ordered.where((c) => !kCommonCurrencyCodes.contains(c.code)).toList();
    expect(tail.map((c) => c.code).toList(), ['BTC', 'XAU', 'AAA', 'ZZZ']);
  });

  test('所有源币种均出现在结果中（无丢失）', () {
    final src = buildSource();
    final ordered = orderCurrencies(src, const Locale('en', 'US'),
        pinned: ['AAA']);
    expect(ordered.length, src.length, reason: '不应丢失或新增币种');
    for (final c in src) {
      expect(ordered.any((o) => o.code == c.code), isTrue,
          reason: '币种 ${c.code} 应保留');
    }
  });
}
