// PressKey 按压视觉回归测试。
//
// 背景：PressKey 的按压态由原始指针事件（Listener）驱动，而不是
// TapGestureRecognizer.onTapDown。原因是在 BottomSheet 中按键会和 sheet
// 自带的 VerticalDragGestureRecognizer 竞争手势竞技场，onTapDown 会被推迟
// 到 kPressTimeout（100ms）或抬手 sweep 才触发，快速点击时按压态无法渲染。
// 本测试用 RawGestureDetector 模拟 BottomSheet 的拖拽识别器，验证按下瞬间
// 按压态仍立即出现、松开后恢复。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/press_key.dart';

void main() {
  Widget buildHarness({VoidCallback? onDown}) {
    return MaterialApp(
      home: Scaffold(
        body: RawGestureDetector(
          // 复刻 BottomSheet._BottomSheetGestureDetector：整层注册竖向拖拽，
          // 与按键 Tap 识别器进入同一手势竞技场。
          gestures: <Type, GestureRecognizerFactory<GestureRecognizer>>{
            VerticalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  VerticalDragGestureRecognizer
                >(
                  () => VerticalDragGestureRecognizer(),
                  (VerticalDragGestureRecognizer instance) {
                    instance
                      ..onStart = (_) {}
                      ..onUpdate = (_) {}
                      ..onEnd = (_) {}
                      ..onlyAcceptDragOnThreshold = true;
                  },
                ),
          },
          child: Center(
            child: PressKey(
              scale: 0.94,
              onDown: onDown,
              backgroundColor: Colors.white,
              borderRadius: BorderRadius.circular(5),
              child: const SizedBox(
                width: 100,
                height: 60,
                child: Center(child: Text('7')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('拖拽手势竞争下：按下瞬间立即变暗并缩放，松开恢复', (tester) async {
    await tester.pumpWidget(buildHarness());

    final key = find.byType(PressKey);
    final material = find.descendant(of: key, matching: find.byType(Material));
    final scaleFinder = find.descendant(
      of: key,
      matching: find.byType(AnimatedScale),
    );
    final normal = tester.widget<Material>(material).color!;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressKey)),
    );
    await tester.pump();

    final pressedColor = tester.widget<Material>(material).color!;
    final pressedScale = tester.widget<AnimatedScale>(scaleFinder).scale;
    expect(
      pressedColor,
      isNot(normal),
      reason: '存在拖拽识别器竞争时，按下瞬间也应立即变暗',
    );
    expect(pressedScale, 0.94, reason: '存在拖拽识别器竞争时，按下瞬间也应立即缩放');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Material>(material).color,
      normal,
      reason: '松开后应恢复常态背景',
    );
    expect(
      tester.widget<AnimatedScale>(scaleFinder).scale,
      1.0,
      reason: '松开后应恢复原始缩放',
    );
  });

  testWidgets('按下仍会触发 onDown 回调（提交语义不变）', (tester) async {
    var downCount = 0;
    await tester.pumpWidget(buildHarness(onDown: () => downCount++));

    await tester.tap(find.byType(PressKey));
    await tester.pumpAndSettle();

    expect(downCount, 1, reason: '快速点击时 onDown 仍应触发一次');
  });
}
