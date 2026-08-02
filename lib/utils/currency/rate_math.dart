/// 多币种 MVP 的纯函数层:不碰 IO,可单测。
/// 方向约定:EffectiveRate.rate = 「1 quote = rate base」(decimal 字符串)。
/// 红线:汇率缺失就是缺失,绝不静默回落 1.0。
library;

class EffectiveRate {
  final String rate;
  final bool manual;
  final String? rateDate; // 自动来源的数据日期;手动为 null
  const EffectiveRate({required this.rate, required this.manual, this.rateDate});
}

/// 倒数:输入「1 base = x quote」,输出「1 quote = ? base」字符串(12 位有效数字)。
String invertRate(num oneBaseEqualsXQuote) {
  if (oneBaseEqualsXQuote <= 0) {
    throw ArgumentError.value(oneBaseEqualsXQuote, 'oneBaseEqualsXQuote', '必须为正数');
  }
  return (1 / oneBaseEqualsXQuote).toStringAsPrecision(12);
}

/// 合成有效汇率:手动 > 最新自动;两边都没有的 quote 不出现在结果里。
Map<String, EffectiveRate> mergeEffectiveRates({
  required List<({String quote, String rate, String rateDate})> autoRates,
  required List<({String quote, String rate})> overrides,
}) {
  final result = <String, EffectiveRate>{};
  for (final a in autoRates) {
    result[a.quote.toUpperCase()] =
        EffectiveRate(rate: a.rate, manual: false, rateDate: a.rateDate);
  }
  for (final o in overrides) {
    result[o.quote.toUpperCase()] = EffectiveRate(rate: o.rate, manual: true);
  }
  return result;
}

/// 交易级多币种:nativeAmount = amount × rate(1 账户币种 = rate 账本本位币)。
/// 账户币种 == 本位币 → 直接 amount(rate 1,不查表);
/// 缺失 / 非法 / 非正 rate → 返回 null(L8:要求手填,绝不静默按 1.0 入账)。
/// 方向复用本文件约定(1 quote = rate base;quote=账户币种,base=本位币)。
double? computeNativeAmount({
  required double amount,
  required String accountCurrency,
  required String ledgerBase,
  required Map<String, EffectiveRate> rates,
}) {
  if (accountCurrency.toUpperCase() == ledgerBase.toUpperCase()) return amount;
  final er = rates[accountCurrency.toUpperCase()];
  if (er == null) return null;
  final r = double.tryParse(er.rate);
  if (r == null || r <= 0) return null;
  return amount * r;
}

/// 通用折算:按币种金额表折到 base。供净资产明细/分组小计/构成图复用。
/// base 自身 rate=1;某币种缺有效汇率(rate 解析失败 / 非正)→ 剔除并列入 missing,
/// 绝不静默按 1.0 折入。missing 已排序便于 UI 稳定展示。
({double total, Map<String, double> convertedByCurrency, List<String> missingCurrencies})
    convertAmountsToBase({
  required Map<String, double> amounts, // 币种(任意大小写) -> 原币金额
  required Map<String, EffectiveRate> rates,
  required String base,
}) {
  var total = 0.0;
  final convertedByCurrency = <String, double>{};
  final missing = <String>[];
  final baseUp = base.toUpperCase();
  for (final e in amounts.entries) {
    final code = e.key.toUpperCase();
    double? rate;
    if (code == baseUp) {
      rate = 1.0;
    } else {
      final eff = rates[code];
      if (eff != null) rate = double.tryParse(eff.rate);
    }
    if (rate == null || rate <= 0) {
      missing.add(code);
      continue;
    }
    final converted = e.value * rate;
    convertedByCurrency[code] = converted;
    total += converted;
  }
  missing.sort();
  return (total: total, convertedByCurrency: convertedByCurrency, missingCurrencies: missing);
}


