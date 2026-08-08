// 元 ↔ 分 精度换算测试。
//
// 需求锚点：
//   1. yuanToCents 在 Decimal 上完成，避免浮点尾差（0.29 元 → 29 分）；
//   2. centsToDecimal 精确还原；
//   3. centsToDouble 仅供展示边界使用。

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/utils/currency/money_cents.dart';

void main() {
  test('yuanToCents：十进制精确换算', () {
    expect(yuanToCents(Decimal.parse('0.29')), 29);
    expect(yuanToCents(Decimal.parse('12.34')), 1234);
    expect(yuanToCents(Decimal.parse('100')), 10000);
    // 0.1+0.2 浮点经典场景：十进制下精确 30 分
    expect(
      yuanToCents(Decimal.parse('0.1') + Decimal.parse('0.2')),
      30,
    );
  });

  test('centsToDecimal 精确还原', () {
    expect(centsToDecimal(1234), Decimal.parse('12.34'));
    expect(centsToDecimal(29), Decimal.parse('0.29'));
  });

  test('centsToDouble 展示换算', () {
    expect(centsToDouble(1234), 12.34);
    expect(centsToDouble(0), 0);
  });
}
