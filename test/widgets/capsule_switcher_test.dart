/// CapsuleSwitcher 空选项测试。
///
/// options 为空时 `options.length * 2 - 1 = -1`，`Iterable.take(-1)`
/// 会抛 RangeError；空列表应降级为空容器而不是崩溃。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/capsule_switcher.dart';

void main() {
  testWidgets('空选项渲染空容器，不崩溃', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CapsuleSwitcher<int>(
            selectedValue: 1,
            options: [],
            onChanged: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(CapsuleSwitcher<int>), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: '空选项不得触发 take(-1) RangeError',
    );
  });

  testWidgets('正常选项仍可点击切换', (tester) async {
    final changed = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CapsuleSwitcher<int>(
            selectedValue: 1,
            options: const [
              CapsuleOption(value: 1, label: '月'),
              CapsuleOption(value: 2, label: '周'),
            ],
            onChanged: changed.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('周'));
    expect(changed, [2]);
  });

  testWidgets('英文长标签在 maxWidth 214 内自适应，不触发 RenderFlex overflow', (tester) async {
    // 统计页底部悬浮周期胶囊固定 maxWidth 214：Week/Month/Year 英文文案在
    // 三段均分后每段仅剩约 42.7px，放不下时会溢出（RenderFlex overflow）。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 214),
              child: CapsuleSwitcher<String>(
                selectedValue: 'month',
                options: const [
                  CapsuleOption(value: 'week', label: 'Week'),
                  CapsuleOption(value: 'month', label: 'Month'),
                  CapsuleOption(value: 'year', label: 'Year'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNull,
      reason: '英文 Week/Month/Year 不得在 214 宽度内触发 RenderFlex overflow',
    );
  });
}

void _noop(int _) {}
