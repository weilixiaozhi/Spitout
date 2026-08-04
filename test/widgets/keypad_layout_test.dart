/// computeKeypadU 纯函数单元测试。
///
/// 该函数在 transaction_editor_sheet 中用于算定自定义键盘行高 u，
/// 核心契约：
///   1. u 始终落在 [30,35]（下限保证可点、上限保持紧凑，整体已按用户
///      「偏大」反馈压缩：上限 48→35、下限 36→30）；
///   2. 空间充足时 u = 35，富余高度全部回流给分类区（多展示几行）；
///   3. 空间不足时（如系统键盘拉起）优先压缩键盘，分类区保底
///      minCategoryH(96)。
///
/// 不依赖 widget/provider，纯数值断言，运行快且稳定。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/keypad_layout.dart';

void main() {
  // 与 keypad_layout.dart 默认值保持一致
  const topFixed = 48.0;
  const bottomFixedNoKeypad = 124.0;
  const minCategoryH = 96.0;

  /// 给定可用高度，算定键盘行高与剩余分类区高度。
  (double, double) derive(double available) {
    final u = computeKeypadU(availableHeight: available);
    final keypadH = 4 * u + 24; // 4 行 + 3*8 间距
    final categoryH = available - topFixed - bottomFixedNoKeypad - keypadH;
    return (u, categoryH);
  }

  test('普通手机(availH≈786)：u=35，富余空间回流分类区', () {
    final (u, categoryH) = derive(786);
    expect(u, 35);
    expect(
      categoryH,
      greaterThan(minCategoryH),
      reason: '空间充足时富余高度全部留给分类区，多展示几行',
    );
  });

  test('大屏(availH=1000)：u 维持上限 35，不再更大', () {
    final (u, categoryH) = derive(1000);
    expect(u, 35);
    expect(categoryH, greaterThan(minCategoryH));
  });

  test('临界(availH=432)：键盘恰好满高 35，分类区恰好保底 96', () {
    // 432 = 48 + 124 + 96 + (4*35+24)，预算刚好够键盘满高 + 分类区地板
    final (u, categoryH) = derive(432);
    expect(u, 35);
    expect(categoryH, closeTo(minCategoryH, 0.5));
  });

  test('空间不足(availH=420)：u 被压缩，分类区仍保底 96', () {
    final (u, categoryH) = derive(420);
    expect(u, inInclusiveRange(30, 35));
    expect(u, lessThan(35), reason: '空间不足时压缩的是键盘');
    expect(
      categoryH,
      greaterThanOrEqualTo(minCategoryH - 0.5),
      reason: '分类区保底约一行高度，不被键盘吃掉',
    );
  });

  test('物理极限(availH=320)：u 压到下限 30，不再更矮', () {
    final (u, _) = derive(320);
    expect(u, 30);
  });

  test('任意高度下 u 始终落在 [30,35]', () {
    for (var h = 280; h <= 1200; h += 40) {
      final (u, _) = derive(h.toDouble());
      expect(u, inInclusiveRange(30, 35), reason: 'availH=$h 时 u 越界');
    }
  });
}
