/// CapsuleSwitcher 空选项回归测试。
///
/// 修复点：options 为空时 `options.length * 2 - 1 = -1`，`Iterable.take(-1)`
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
    expect(tester.takeException(), isNull,
        reason: '空选项不得触发 take(-1) RangeError');
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
}

void _noop(int _) {}
