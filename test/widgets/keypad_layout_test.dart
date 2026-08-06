/// computeKeypadU 纯函数单元测试。
///
/// 该函数在 transaction_editor_sheet 中用于算定自定义键盘行高 u，
/// 核心契约（本次需求：按键更大、底部输入区更紧凑）：
///   1. u 始终落在 [35,45]（下限 35 保证可点、上限 45 保持紧凑）；
///   2. 空间充足时 u = 45，富余高度全部回流给分类区（多展示几行）；
///   3. 空间不足时（如系统键盘拉起）优先压缩键盘，分类区保底
///      minCategoryH(96)；
///   4. 底部固定区 = 容器内边距(10+20) + 备注行(35) + 间距(5) +
///      金额栏(35) + 间距(10) = 115；键盘 4 行之间 3 个 10px 行距。
///
/// 不依赖 widget/provider，纯数值断言，运行快且稳定。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/keypad_layout.dart';

void main() {
  // 与 keypad_layout.dart 默认值保持一致
  const topFixed = 48.0;
  const bottomFixedNoKeypad = 115.0;
  const minCategoryH = 96.0;

  /// 给定可用高度，算定键盘行高与剩余分类区高度。
  (double, double) derive(double available) {
    final u = computeKeypadU(availableHeight: available);
    final keypadH = 4 * u + 30; // 4 行 + 3*10 行距
    final categoryH = available - topFixed - bottomFixedNoKeypad - keypadH;
    return (u, categoryH);
  }

  test('普通手机(availH≈786)：u=45，富余空间回流分类区', () {
    final (u, categoryH) = derive(786);
    expect(u, 45);
    expect(
      categoryH,
      greaterThan(minCategoryH),
      reason: '空间充足时富余高度全部留给分类区，多展示几行',
    );
  });

  test('大屏(availH=1000)：u 维持上限 45，不再更大', () {
    final (u, categoryH) = derive(1000);
    expect(u, 45);
    expect(categoryH, greaterThan(minCategoryH));
  });

  test('上限临界(availH=469)：键盘恰好满高 45，分类区恰好保底 96', () {
    // 469 = 48 + 115 + 96 + (4*45+30)，预算刚好够键盘满高 + 分类区地板
    final (u, categoryH) = derive(469);
    expect(u, 45);
    expect(categoryH, closeTo(minCategoryH, 0.5));
  });

  test('下限临界(availH=429)：键盘恰好压到保底 35', () {
    // 429 = 48 + 115 + 96 + (4*35+30)，再低预算也不够，u 停在 35
    final (u, _) = derive(429);
    expect(u, 35);
  });

  test('空间不足(availH=450)：u 被压缩，分类区仍保底 96', () {
    final (u, categoryH) = derive(450);
    expect(u, inInclusiveRange(35, 45));
    expect(u, lessThan(45), reason: '空间不足时压缩的是键盘');
    expect(
      categoryH,
      greaterThanOrEqualTo(minCategoryH - 0.5),
      reason: '分类区保底约一行高度，不被键盘吃掉',
    );
  });

  test('物理极限(availH=320)：u 压到下限 35，不再更矮', () {
    final (u, _) = derive(320);
    expect(u, 35);
  });

  test('任意高度下 u 始终落在 [35,45]', () {
    for (var h = 280; h <= 1200; h += 40) {
      final (u, _) = derive(h.toDouble());
      expect(u, inInclusiveRange(35, 45), reason: 'availH=$h 时 u 越界');
    }
  });
}
