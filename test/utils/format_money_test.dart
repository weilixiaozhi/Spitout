/// formatMoneyWithCurrency（金额 + 币种统一格式化）单元测试。
///
/// 固定口径：「符号后带空格、负号在最前且负号也带空格」；
/// currencyCode 为 null/空时退化为无符号纯数字。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spitout/widgets/format_money.dart';

void main() {
  group('formatMoneyWithCurrency · 币种符号', () {
    test('带币种：符号后带空格', () {
      expect(formatMoneyWithCurrency(72, currencyCode: 'CNY'), '¥ 72');
      expect(formatMoneyWithCurrency(1234.5, currencyCode: 'USD'), '\$ 1,234.5');
      expect(formatMoneyWithCurrency(0.5, currencyCode: 'EUR'), '€ 0.5');
    });

    test('币种代码大小写不敏感（内部归一为 ISO 大写）', () {
      expect(formatMoneyWithCurrency(72, currencyCode: 'cny'), '¥ 72');
      expect(formatMoneyWithCurrency(72, currencyCode: 'usd'), '\$ 72');
    });

    test('长尾/未知币种代码：回退为代码本身', () {
      expect(formatMoneyWithCurrency(72, currencyCode: 'XXX'), 'XXX 72');
    });

    test('currencyCode 为 null / 空串：退化为无符号纯数字（兜底）', () {
      expect(formatMoneyWithCurrency(72), '72');
      expect(formatMoneyWithCurrency(72, currencyCode: ''), '72');
      expect(formatMoneyWithCurrency(-72), '-72');
    });
  });

  group('formatMoneyWithCurrency · 符号位置与 signed', () {
    test('负号在币种符号之前（- ¥72 而非 ¥-72）', () {
      expect(formatMoneyWithCurrency(-72, currencyCode: 'CNY'), '- ¥ 72');
      expect(formatMoneyWithCurrency(-1234.5, currencyCode: 'USD'), '- \$ 1,234.5');
    });

    test('signed=true：正数显式输出 +，负数输出 -', () {
      expect(formatMoneyWithCurrency(72, currencyCode: 'CNY', signed: true),
          '+ ¥ 72');
      expect(formatMoneyWithCurrency(-72, currencyCode: 'CNY', signed: true),
          '- ¥ 72');
    });

    test('signed=false（默认）：正数无符号', () {
      expect(formatMoneyWithCurrency(72, currencyCode: 'CNY'), '¥ 72');
    });

    test('负零不输出负号（-0.0 < 0 为 false）', () {
      expect(formatMoneyWithCurrency(-0.0, currencyCode: 'CNY'), '¥ 0');
    });
  });

  group('formatMoneyWithCurrency · 数字格式（与 formatMoneyCompact 口径一致）', () {
    test('千分位', () {
      expect(formatMoneyWithCurrency(1234567.89, currencyCode: 'CNY'),
          '¥ 1,234,567.89');
    });

    test('小数去尾零', () {
      expect(formatMoneyWithCurrency(100.0, currencyCode: 'CNY'), '¥ 100');
      expect(formatMoneyWithCurrency(100.50, currencyCode: 'CNY'), '¥ 100.5');
      expect(formatMoneyWithCurrency(100.55, currencyCode: 'CNY'), '¥ 100.55');
    });

    test('decimals 控制最大小数位', () {
      expect(formatMoneyWithCurrency(100.555, currencyCode: 'CNY', decimals: 0),
          '¥ 101');
      expect(formatMoneyWithCurrency(100.5, currencyCode: 'CNY', decimals: 1),
          '¥ 100.5');
    });
  });
}
