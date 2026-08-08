// OverlayKeyboardGuard 扩展测试。
//
// 需求锚点：prepareForOverlay 收起当前焦点键盘并等待 ~100ms 动画，之后可继续弹层。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/overlay_keyboard_guard.dart';

void main() {
  testWidgets('prepareForOverlay 等待 100ms 并正常返回', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: _Host()),
      ),
    );

    final state = tester.state<_HostState>(find.byType(_Host));
    final future = state.prepareForOverlay();
    await tester.pump(const Duration(milliseconds: 101));
    await future;
    expect(tester.takeException(), isNull);
  });
}

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}
