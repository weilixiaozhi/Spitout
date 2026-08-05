/// showToastOnOverlay 堆叠控制与移除防护回归测试。
///
/// 修复点：
/// - 同一 Overlay 连续弹 toast 只保留最后一个（后到覆盖前到）；
/// - 自动消失时判活后再 remove，Overlay 销毁不抛异常。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/toast.dart';

void main() {
  testWidgets('连续弹 toast：后到覆盖前到，且到期自动移除', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final context = tester.element(find.byType(Scaffold));
    final overlay = Overlay.of(context, rootOverlay: true);

    showToastOnOverlay(overlay, '第一条');
    showToastOnOverlay(overlay, '第二条');
    await tester.pump();

    expect(find.text('第一条'), findsNothing,
        reason: '旧 toast 应被新 toast 立即覆盖，不叠加多个全屏浮层');
    expect(find.text('第二条'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('第二条'), findsNothing,
        reason: '到期后 toast 应自动移除');
    expect(tester.takeException(), isNull);
  });
}
