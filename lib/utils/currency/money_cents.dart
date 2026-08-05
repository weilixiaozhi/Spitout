/// 金额精度工具:统一「元 ↔ 分」换算。
///
/// 数据库金额一律以最小货币单位(分)存整数,杜绝 IEEE-754 double 尾差
/// (0.1 + 0.2 这类累计问题);所有进入 DB 的金额必须先经 [yuanToCents],
/// 展示层再按需转回元。同步 JSON 接口仍按"元"口径,由序列化层换算。
library;

import 'package:decimal/decimal.dart';

/// 元(Decimal,精确解析) → 分(int)。
///
/// 换算在 Decimal 上完成后再取整,避免 `double * 100` 的浮点尾差。
int yuanToCents(Decimal yuan) {
  return (yuan * Decimal.fromInt(100)).round().toBigInt().toInt();
}

/// 分(int) → 元(Decimal,精确)。
Decimal centsToDecimal(int cents) {
  return (Decimal.fromInt(cents) / Decimal.fromInt(100)).toDecimal();
}

/// 分(int) → 元(double),仅用于图表/格式化等展示边界。
double centsToDouble(int cents) => cents / 100;
