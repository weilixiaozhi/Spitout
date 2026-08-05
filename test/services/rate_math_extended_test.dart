/// rate_math 纯函数层扩展测试:覆盖边界值、异常路径、大小写归一等。
///
/// 设计意图:确保多币种折算逻辑在极端条件下不静默回落 1.0,
/// 手动汇率优先级正确,空值/零值/负值等边界场景有明确行为。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/utils/currency/rate_math.dart';

void main() {
  // ===========================================================================
  // invertRate
  // ===========================================================================
  group('invertRate', () {
    test('正常正值:返回 12 位有效数字的倒数', () {
      expect(invertRate(7.2), '0.138888888889');
      expect(invertRate(1), '1.00000000000');
      expect(invertRate(0.5), '2.00000000000');
    });

    test('极大值:不溢出,返回极小正数', () {
      final result = double.parse(invertRate(1e15));
      expect(result, closeTo(1e-15, 1e-27));
    });

    test('极小正值:返回极大数', () {
      final result = double.parse(invertRate(1e-10));
      expect(result, closeTo(1e10, 1));
    });

    test('零值:抛 ArgumentError', () {
      expect(() => invertRate(0), throwsArgumentError);
    });

    test('负值:抛 ArgumentError', () {
      expect(() => invertRate(-7.2), throwsArgumentError);
    });

    test('NaN:NaN 逃逸 <=0 检查,返回 "NaN"(已知缺陷,非本次修复范围)', () {
      // double.nan <= 0 在 Dart 中为 false,所以不抛 ArgumentError。
      // 1/nan = nan,toStringAsPrecision(12) 返回 'NaN'。
      // 审查发现:invertRate 未显式拦截 NaN,建议后续修复时加 !rate.isFinite 检查。
      expect(invertRate(double.nan), 'NaN');
    });

    test('无穷大:不抛异常,返回极接近 0 的字符串', () {
      // double.infinity <= 0 为 false,所以不抛 ArgumentError;
      // 1/infinity = 0.0,toStringAsPrecision(12) = "0.00000000000"
      final result = invertRate(double.infinity);
      expect(double.tryParse(result), isNotNull);
    });
  });

  // ===========================================================================
  // mergeEffectiveRates
  // ===========================================================================
  group('mergeEffectiveRates', () {
    test('空输入:返回空 Map', () {
      final m = mergeEffectiveRates(autoRates: [], overrides: []);
      expect(m, isEmpty);
    });

    test('仅有自动汇率:全部标记 manual=false', () {
      final m = mergeEffectiveRates(
        autoRates: [
          (quote: 'USD', rate: '7.2', rateDate: '2026-07-20'),
        ],
        overrides: [],
      );
      expect(m['USD']!.rate, '7.2');
      expect(m['USD']!.manual, isFalse);
      expect(m['USD']!.rateDate, '2026-07-20');
    });

    test('仅有手动汇率:全部标记 manual=true,rateDate=null', () {
      final m = mergeEffectiveRates(
        autoRates: [],
        overrides: [(quote: 'USD', rate: '7.5')],
      );
      expect(m['USD']!.rate, '7.5');
      expect(m['USD']!.manual, isTrue);
      expect(m['USD']!.rateDate, isNull);
    });

    test('手动覆盖自动:同 quote 手动优先', () {
      final m = mergeEffectiveRates(
        autoRates: [
          (quote: 'USD', rate: '7.2', rateDate: '2026-07-20'),
        ],
        overrides: [(quote: 'USD', rate: '7.5')],
      );
      expect(m['USD']!.rate, '7.5');
      expect(m['USD']!.manual, isTrue);
    });

    test('大小写归一:小写 quote 统一转大写', () {
      final m = mergeEffectiveRates(
        autoRates: [
          (quote: 'usd', rate: '7.2', rateDate: '2026-07-20'),
        ],
        overrides: [(quote: 'Usd', rate: '7.5')],
      );
      // 两个都归一到 'USD',手动覆盖自动
      expect(m['USD']!.rate, '7.5');
      expect(m['USD']!.manual, isTrue);
    });

    test('不同 quote:各自独立保留', () {
      final m = mergeEffectiveRates(
        autoRates: [
          (quote: 'USD', rate: '7.2', rateDate: '2026-07-20'),
          (quote: 'JPY', rate: '0.048', rateDate: '2026-07-19'),
        ],
        overrides: [(quote: 'KRW', rate: '0.005')],
      );
      expect(m.length, 3);
      expect(m['USD']!.manual, isFalse);
      expect(m['JPY']!.manual, isFalse);
      expect(m['KRW']!.manual, isTrue);
    });
  });

  // ===========================================================================
  // computeNativeAmount
  // ===========================================================================
  group('computeNativeAmount', () {
    test('同币种:直接返回 amount,不查表(rate=1)', () {
      expect(
        computeNativeAmount(
            amountCents: 10000, txCurrency: 'CNY', ledgerBase: 'CNY', rates: {}),
        10000,
      );
    });

    test('同币种大小写不敏感', () {
      expect(
        computeNativeAmount(
            amountCents: 5000, txCurrency: 'usd', ledgerBase: 'USD', rates: {}),
        5000,
      );
      expect(
        computeNativeAmount(
            amountCents: 5000, txCurrency: 'Usd', ledgerBase: 'uSd', rates: {}),
        5000,
      );
    });

    test('外币有汇率:返回 amount × rate', () {
      final rates = {
        'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
      };
      expect(
        computeNativeAmount(
            amountCents: 1200, txCurrency: 'USD', ledgerBase: 'CNY', rates: rates),
        8640,
      );
    });

    test('外币有手动汇率:优先使用手动汇率', () {
      final rates = {
        'USD': const EffectiveRate(rate: '7.5', manual: true),
      };
      expect(
        computeNativeAmount(
            amountCents: 10000, txCurrency: 'USD', ledgerBase: 'CNY', rates: rates),
        75000,
      );
    });

    test('缺失汇率:返回 null(绝无 1.0 回落)', () {
      expect(
        computeNativeAmount(
            amountCents: 1200, txCurrency: 'USD', ledgerBase: 'CNY', rates: {}),
        isNull,
      );
    });

    test('汇率值非数字:返回 null(不入脏数据)', () {
      expect(
        computeNativeAmount(
            amountCents: 1200,
            txCurrency: 'USD',
            ledgerBase: 'CNY',
            rates: {'USD': const EffectiveRate(rate: 'abc', manual: true)}),
        isNull,
      );
    });

    test('汇率值为零:返回 null(非正 rate 视为无效)', () {
      expect(
        computeNativeAmount(
            amountCents: 1200,
            txCurrency: 'USD',
            ledgerBase: 'CNY',
            rates: {'USD': const EffectiveRate(rate: '0', manual: true)}),
        isNull,
      );
    });

    test('汇率值为负:返回 null(非正 rate 视为无效)', () {
      expect(
        computeNativeAmount(
            amountCents: 1200,
            txCurrency: 'USD',
            ledgerBase: 'CNY',
            rates: {'USD': const EffectiveRate(rate: '-7.2', manual: true)}),
        isNull,
      );
    });

    test('amount 为零:同币种返回 0,外币返回 0×rate=0', () {
      expect(
        computeNativeAmount(
            amountCents: 0, txCurrency: 'CNY', ledgerBase: 'CNY', rates: {}),
        0,
      );
      final rates = {
        'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
      };
      expect(
        computeNativeAmount(
            amountCents: 0, txCurrency: 'USD', ledgerBase: 'CNY', rates: rates),
        0,
      );
    });

    test('amount 为负:正常折算(退款/冲账场景)', () {
      final rates = {
        'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
      };
      expect(
        computeNativeAmount(
            amountCents: -5000, txCurrency: 'USD', ledgerBase: 'CNY', rates: rates),
        -36000,
      );
    });

    test('极大金额:不溢出(double 精度内)', () {
      final rates = {
        'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
      };
      final result = computeNativeAmount(
          amountCents: 100000000000000000,
          txCurrency: 'USD',
          ledgerBase: 'CNY',
          rates: rates);
      expect(result, isNotNull);
      expect(result!, 720000000000000000);
    });

    test('极小金额:正常折算', () {
      final rates = {
        'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
      };
      expect(
        computeNativeAmount(
            amountCents: 1, txCurrency: 'USD', ledgerBase: 'CNY', rates: rates),
        7,
      );
    });

    test('大小写不敏感:txCurrency 小写也能匹配大写 key', () {
      final rates = {
        'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
      };
      expect(
        computeNativeAmount(
            amountCents: 10000, txCurrency: 'usd', ledgerBase: 'CNY', rates: rates),
        72000,
      );
    });
  });

  // ===========================================================================
  // convertAmountsToBase
  // ===========================================================================
  group('convertAmountsToBase', () {
    test('空输入:total=0,无 missing', () {
      final r = convertAmountsToBase(amounts: {}, rates: const {}, base: 'CNY');
      expect(r.total, 0);
      expect(r.convertedByCurrency, isEmpty);
      expect(r.missingCurrencies, isEmpty);
    });

    test('仅 base 币种:rate=1,直接累加', () {
      final r = convertAmountsToBase(
        amounts: {'CNY': 100.0},
        rates: const {},
        base: 'CNY',
      );
      expect(r.total, closeTo(100, 0.001));
      expect(r.convertedByCurrency['CNY'], closeTo(100, 0.001));
      expect(r.missingCurrencies, isEmpty);
    });

    test('混合币种:可折算累加 + 缺失剔除并列名', () {
      final r = convertAmountsToBase(
        amounts: {'CNY': 5800.0, 'USD': 1000.0, 'KRW': 500000.0},
        rates: {
          'USD': const EffectiveRate(rate: '7.20', manual: false, rateDate: '2026-07-20'),
        },
        base: 'CNY',
      );
      expect(r.total, closeTo(5800 + 7200, 0.001));
      expect(r.convertedByCurrency['CNY'], closeTo(5800, 0.001));
      expect(r.convertedByCurrency['USD'], closeTo(7200, 0.001));
      expect(r.convertedByCurrency.containsKey('KRW'), isFalse);
      expect(r.missingCurrencies, ['KRW']);
    });

    test('base 自身大小写归一', () {
      final r = convertAmountsToBase(
        amounts: {'usd': 100.0},
        rates: const {},
        base: 'USD',
      );
      expect(r.total, closeTo(100, 0.001));
      expect(r.missingCurrencies, isEmpty);
    });

    test('全部缺失:total=0,全部列入 missing(排序)', () {
      final r = convertAmountsToBase(
        amounts: {'KRW': 500.0, 'JPY': 1000.0},
        rates: const {},
        base: 'CNY',
      );
      expect(r.total, 0);
      expect(r.convertedByCurrency, isEmpty);
      expect(r.missingCurrencies, ['JPY', 'KRW']); // 排序
    });

    test('零金额:正常折算(0×rate=0)', () {
      final r = convertAmountsToBase(
        amounts: {'USD': 0.0},
        rates: {
          'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
        },
        base: 'CNY',
      );
      expect(r.total, 0);
      expect(r.convertedByCurrency['USD'], 0);
      expect(r.missingCurrencies, isEmpty);
    });

    test('负金额:正常折算(退款场景)', () {
      final r = convertAmountsToBase(
        amounts: {'USD': -100.0},
        rates: {
          'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
        },
        base: 'CNY',
      );
      expect(r.total, closeTo(-720, 0.001));
    });

    test('手动与自动汇率混合:手动优先', () {
      final r = convertAmountsToBase(
        amounts: {'USD': 100.0},
        rates: {
          'USD': const EffectiveRate(rate: '7.5', manual: true),
        },
        base: 'CNY',
      );
      expect(r.total, closeTo(750, 0.001));
    });

    test('非法汇率值:视为缺失,列入 missing', () {
      final r = convertAmountsToBase(
        amounts: {'USD': 100.0},
        rates: {
          'USD': const EffectiveRate(rate: 'invalid', manual: true),
        },
        base: 'CNY',
      );
      expect(r.total, 0);
      expect(r.missingCurrencies, ['USD']);
    });

    test('零汇率:视为缺失,列入 missing', () {
      final r = convertAmountsToBase(
        amounts: {'USD': 100.0},
        rates: {
          'USD': const EffectiveRate(rate: '0', manual: true),
        },
        base: 'CNY',
      );
      expect(r.total, 0);
      expect(r.missingCurrencies, ['USD']);
    });

    test('单元素集合:正常折算', () {
      final r = convertAmountsToBase(
        amounts: {'USD': 100.0},
        rates: {
          'USD': const EffectiveRate(rate: '7.2', manual: false, rateDate: '2026-07-20'),
        },
        base: 'CNY',
      );
      expect(r.total, closeTo(720, 0.001));
      expect(r.convertedByCurrency.length, 1);
      expect(r.missingCurrencies, isEmpty);
    });

    test('missingCurrencies 排序:确保 UI 展示稳定', () {
      final r = convertAmountsToBase(
        amounts: {'ZWL': 1.0, 'AUD': 1.0, 'BRL': 1.0},
        rates: const {},
        base: 'CNY',
      );
      expect(r.missingCurrencies, ['AUD', 'BRL', 'ZWL']);
    });
  });
}
