/// computeNativeAmount(交易级多币种):amount × rate(1 交易币种 = rate 本位币)。
/// 同币种 → amount;缺失/非法 rate → null(L8 红线,绝不静默 1.0)。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/utils/currency/rate_math.dart';

void main() {
  test('交易币种==本位币 → 返回 amount(rate 1,不查表)', () {
    expect(
      computeNativeAmount(
          amountCents: 10000, txCurrency: 'CNY', ledgerBase: 'CNY', rates: {}),
      10000,
    );
    // 大小写不敏感
    expect(
      computeNativeAmount(
          amountCents: 5000, txCurrency: 'usd', ledgerBase: 'USD', rates: {}),
      5000,
    );
  });

  test('外币按 rate 折算(1 USD = 7.2 CNY)', () {
    final rates = {
      'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-10'),
    };
    expect(
      computeNativeAmount(
          amountCents: 1200, txCurrency: 'USD', ledgerBase: 'CNY', rates: rates),
      8640,
    );
  });

  test('缺失汇率 → null(L8,要求手填)', () {
    expect(
      computeNativeAmount(
          amountCents: 1200, txCurrency: 'USD', ledgerBase: 'CNY', rates: {}),
      isNull,
    );
  });

  test('非法/非正 rate → null(不入脏数据)', () {
    expect(
      computeNativeAmount(
          amountCents: 1200,
          txCurrency: 'USD',
          ledgerBase: 'CNY',
          rates: {'USD': const EffectiveRate(rate: 'abc', manual: true)}),
      isNull,
    );
    expect(
      computeNativeAmount(
          amountCents: 1200,
          txCurrency: 'USD',
          ledgerBase: 'CNY',
          rates: {'USD': const EffectiveRate(rate: '0', manual: true)}),
      isNull,
    );
  });
}
