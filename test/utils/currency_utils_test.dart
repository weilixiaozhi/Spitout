// 币种工具测试
//
// 验证内容：
//   1. kCommonCurrencyCodes — 常用币种列表包含预期币种且顺序正确
//   2. getCurrencySymbol — 符号查找（含 JPY 消歧）
//   3. currencyEnglishName — 英文名兜底（不依赖 context）

import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/utils/currency/currencies.dart';

void main() {
  group('kCommonCurrencyCodes — 常用币种列表', () {
    test('包含引导页系统语言映射涉及的核心币种', () {
      // 默认币种跟随系统语言：zh→CNY, zh_TW→TWD, en→USD, ko→KRW
      // 这些币种必须在首屏常用列表中可被选中
      expect(kCommonCurrencyCodes, contains('CNY'), reason: '应包含人民币');
      expect(kCommonCurrencyCodes, contains('USD'), reason: '应包含美元');
      expect(kCommonCurrencyCodes, contains('TWD'), reason: '应包含新台币');
      expect(kCommonCurrencyCodes, contains('KRW'), reason: '应包含韩元');
    });

    test('CNY 排在首位（中国用户为主）', () {
      expect(kCommonCurrencyCodes.first, 'CNY', reason: 'CNY 应排在常用币种首位');
    });

    test('列表数量为 13', () {
      expect(kCommonCurrencyCodes.length, 13, reason: '常用币种应为 13 个');
    });

    test('所有常用币种均在完整币种列表中', () {
      for (final code in kCommonCurrencyCodes) {
        expect(kCurrencyCodes.contains(code), isTrue,
            reason: '常用币种 $code 应在完整币种列表中');
      }
    });

    test('无重复项', () {
      final unique = kCommonCurrencyCodes.toSet();
      expect(unique.length, kCommonCurrencyCodes.length,
          reason: '常用币种列表不应有重复');
    });
  });

  group('getCurrencySymbol — 币种符号', () {
    test('已知币种返回正确符号', () {
      expect(getCurrencySymbol('CNY'), '¥');
      expect(getCurrencySymbol('USD'), '\$');
      expect(getCurrencySymbol('KRW'), '₩');
      expect(getCurrencySymbol('EUR'), '€');
      expect(getCurrencySymbol('GBP'), '£');
    });

    test('JPY 使用 JP¥ 消歧（与 CNY 的 ¥ 区分）', () {
      // JPY 与 CNY 符号同为 ¥，采用 JP¥ 前缀消歧
      expect(getCurrencySymbol('JPY'), 'JP¥', reason: 'JPY 应使用 JP¥ 消歧');
      expect(getCurrencySymbol('JPY'), isNot(equals(getCurrencySymbol('CNY'))),
          reason: 'JPY 与 CNY 符号不应相同');
    });

    test('未知币种回退为 code 本身', () {
      expect(getCurrencySymbol('XYZ'), 'XYZ');
    });

    test('大小写不敏感', () {
      expect(getCurrencySymbol('cny'), getCurrencySymbol('CNY'));
    });
  });

  group('currencyEnglishName — 英文名兜底（不依赖 context）', () {
    test('已知币种返回英文名', () {
      expect(currencyEnglishName('CNY'), 'Chinese Yuan');
      expect(currencyEnglishName('USD'), 'US Dollar');
      expect(currencyEnglishName('KRW'), 'South Korean Won');
      expect(currencyEnglishName('EUR'), 'Euro');
      expect(currencyEnglishName('JPY'), 'Japanese Yen');
    });

    test('未知币种回退为 code', () {
      expect(currencyEnglishName('XYZ'), 'XYZ');
    });

    test('大小写不敏感', () {
      expect(currencyEnglishName('cny'), currencyEnglishName('CNY'));
    });
  });

  group('CurrencyInfo 数据模型', () {
    test('code 和 name 可正确访问', () {
      const info = CurrencyInfo('CNY', '人民币');
      expect(info.code, 'CNY');
      expect(info.name, '人民币');
    });
  });
}
