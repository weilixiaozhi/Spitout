/// AA 分摊 Decimal 工具。
///
/// 设计意图:全文 §8 算法 + §10.2 支出人兜底余数依赖 Decimal 全程计算,
/// 避免浮点误差(如 10.00 / 3 = 3.333... 在 double 下累计失真)。
/// 本工具集中封装 Decimal 入口转换 + 人均分摊 + 余数兜底逻辑,
/// 服务层 [AaSettlementService] 与 UI 层(AaEditPage 合计校验)共用。
library;

import 'package:decimal/decimal.dart';

/// 把金额(double)规范为 2 位小数的 Decimal。
///
/// 入口必须 `Decimal.parse(amount.toStringAsFixed(2))`:直接 Decimal.parse
/// 浮点字符串会带尾随精度(如 0.1 + 0.2 = 0.30000000000000004),
/// 全程 Decimal 计算才有意义(R4/R10)。
Decimal toDecimal2(double amount) {
  return Decimal.parse(amount.toStringAsFixed(2));
}

/// Decimal → double(仅在最终输出/落库时调用)。
double toDouble(Decimal d) {
  return double.parse(d.toString());
}

/// 人均分摊:每人应摊 = floor(实付 × 100 / n) / 100。
///
/// 返回每人应摊金额列表(顺序与参与人列表对齐),以及"支出人实付差"
/// (实付 - sum(每人应摊))归支出人,保证 sum(应摊) == 实付(§10.2)。
///
/// [payerIndex] 支出人在参与人列表中的下标;为 null 或越界时归第 0 个
/// (兜底,正常调用方都会传有效下标)。
///
/// 例:3 人 10.00 → [3.33, 3.33, 3.34](支出人取最后位,余数 0.01 归支出人)。
List<Decimal> splitEvenly({
  required Decimal total,
  required int participantCount,
  int? payerIndex,
}) {
  assert(participantCount > 0, '参与人数必须 > 0');
  // 转为"分"为单位(int)计算,避免 Decimal 除法精度问题。
  // totalCents = total × 100(取整,Decimal 2 位小数 × 100 必为整数)。
  final totalCents = (total * Decimal.fromInt(100)).toBigInt().toInt();
  final perPersonCents = totalCents ~/ participantCount;
  final remainderCents = totalCents - perPersonCents * participantCount;

  // 每人基础应摊(分 → Decimal)
  // Decimal / Decimal 返回 Rational,需 .toDecimal() 转回 Decimal。
  final perPerson = (Decimal.fromInt(perPersonCents) / Decimal.fromInt(100)).toDecimal();
  final splits = List<Decimal>.filled(participantCount, perPerson);

  // 余数(分)归支出人,保证 sum(应摊) == 实付。
  final idx = (payerIndex == null || payerIndex < 0 || payerIndex >= participantCount)
      ? 0
      : payerIndex;
  splits[idx] = splits[idx] + (Decimal.fromInt(remainderCents) / Decimal.fromInt(100)).toDecimal();
  return splits;
}

/// 校验指定分摊金额合计 == 实付(允许 0.01 容差,防止字符串解析尾差)。
///
/// 返回 true 表示校验通过。
bool validateSplitsTotal({
  required Decimal total,
  required List<Decimal> splits,
}) {
  var sum = Decimal.zero;
  for (final v in splits) {
    sum = sum + v;
  }
  // 容差 0.01:Decimal 解析字符串理论上无误差,但用户输入可能带尾差。
  final tolerance = Decimal.parse('0.01');
  final diff = sum - total;
  // diff 可能为负,取绝对值比较。
  final absDiff = diff < Decimal.zero ? -diff : diff;
  return absDiff <= tolerance;
}
