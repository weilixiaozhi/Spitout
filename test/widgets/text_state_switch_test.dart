/// TextStateSwitch 状态色测试。
///
/// 需求：开关有「开启/关闭 × 可编辑/只读」四种组合，视觉上必须两两可区分，
/// 只读态不能把开启和关闭画成同一种灰。断言锚点：
/// - 可编辑态轨道色不透明（开启=主色、关闭=非激活轨道色）；
/// - 只读态轨道色半透明（保留开/关语义，同时与可编辑态区分）；
/// - 四种组合的轨道色互不相同。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/theme/colors.dart';
import 'package:spitout/widgets/text_state_switch.dart';

/// 按给定状态挂载开关，返回轨道色。
Future<Color> _trackColor(
  WidgetTester tester, {
  required bool value,
  required bool editable,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TextStateSwitch(
          value: value,
          onChanged: editable ? (_) {} : null,
          onLabel: '开',
          offLabel: '关',
        ),
      ),
    ),
  );
  final container = tester.widget<AnimatedContainer>(
    find.byType(AnimatedContainer),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('开启/关闭 × 可编辑/只读 四种轨道色两两可区分', (tester) async {
    final onEditable = await _trackColor(tester, value: true, editable: true);
    final context = tester.element(find.byType(TextStateSwitch));
    final offEditable = await _trackColor(tester, value: false, editable: true);
    final onReadOnly = await _trackColor(tester, value: true, editable: false);
    final offReadOnly = await _trackColor(tester, value: false, editable: false);

    // 可编辑态：轨道色不透明，开启/关闭各自使用语义色。
    expect(onEditable, Theme.of(context).colorScheme.primary);
    expect(offEditable, SpitoutTokens.switchInactiveTrack(context));
    expect(onEditable.a, 1);
    expect(offEditable.a, 1);

    // 只读态：半透明保留开/关语义，与可编辑态区分。
    expect(onReadOnly.a, lessThan(1));
    expect(offReadOnly.a, lessThan(1));

    // 四种组合互不相同（区分是本需求的核心）。
    expect(
      {onEditable, offEditable, onReadOnly, offReadOnly}.length,
      4,
      reason: '四种状态必须两两可区分',
    );
  });
}
