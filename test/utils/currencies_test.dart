import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/utils/currency/currencies.dart';

void main() {
  group('currencies 全量 ISO 4217', () {
    test('覆盖全部币种且含 issue#273 请求的 KES', () {
      // 146 = 完整 ISO 4217 中剔除 5 个无单一主权国家归属的区域货币
      // (XAF/XOF/XCD/XPF/ANG)
      expect(kCurrencyCodes.length, 146);
      expect(kCurrencyCodes, contains('KES'));
      // 区域货币不在支持列表中
      expect(kCurrencyCodes, isNot(containsAll(['XAF', 'XOF', 'XCD', 'XPF', 'ANG'])));
      // 原有主流币种仍在
      expect(kCurrencyCodes, containsAll(['CNY', 'USD', 'EUR', 'JPY', 'GBP']));
    });

    test('code 无重复', () {
      expect(kCurrencyCodes.toSet().length, kCurrencyCodes.length);
    });

    test('英文名兜底表覆盖长尾币种,未知 code 回退自身', () {
      expect(currencyEnglishName('KES'), 'Kenyan Shilling');
      expect(currencyEnglishName('MRU'), 'Mauritanian Ouguiya');
      expect(currencyEnglishName('kes'), 'Kenyan Shilling'); // 大小写不敏感
      expect(currencyEnglishName('ZZZ'), 'ZZZ'); // 未知回退 code
    });

    test('符号:已知币种给符号,长尾币种回退 code', () {
      expect(getCurrencySymbol('USD'), '\$');
      expect(getCurrencySymbol('CNY'), '¥');
      expect(getCurrencySymbol('KES'), 'KSh');
      expect(getCurrencySymbol('BWP'), 'BWP'); // 无专属符号,回退 code
      expect(getCurrencySymbol('ZZZ'), 'ZZZ'); // 未知回退 code
    });
  });
}
