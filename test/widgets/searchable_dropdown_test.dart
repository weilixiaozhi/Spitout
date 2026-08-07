/// SearchableDropdown 浮层测试。
///
/// - 浮层通过 CompositedTransformFollower 跟随触发框；
/// - 全屏 barrier 支持「点击浮层外部关闭」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/widgets/searchable_dropdown.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required ValueChanged<String?> onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SearchableDropdown<String>(
              items: const ['苹果', '香蕉'],
              onChanged: onChanged,
              itemBuilder: (item) => Text(item),
              filter: (item, query) =>
                  item.toLowerCase().contains(query.toLowerCase()),
              labelExtractor: (item) => item,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('打开浮层后点击外部区域关闭', (tester) async {
    await pumpHost(tester, onChanged: (_) {});

    await tester.tap(find.byType(SearchableDropdown<String>));
    await tester.pump();
    expect(find.text('搜索...'), findsOneWidget, reason: '打开后应显示搜索输入框');

    // 点击浮层外（左上角）→ barrier 命中 → 关闭
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(find.text('搜索...'), findsNothing, reason: '点击浮层外部必须关闭下拉');
  });

  testWidgets('选中项回调并自动关闭', (tester) async {
    final selected = <String?>[];
    await pumpHost(tester, onChanged: selected.add);

    await tester.tap(find.byType(SearchableDropdown<String>));
    await tester.pump();

    await tester.tap(find.text('香蕉'));
    await tester.pump();

    expect(selected, ['香蕉']);
    expect(find.text('搜索...'), findsNothing, reason: '选中后浮层应自动关闭');
  });

  testWidgets('搜索过滤即时生效', (tester) async {
    await pumpHost(tester, onChanged: (_) {});

    await tester.tap(find.byType(SearchableDropdown<String>));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '苹果');
    await tester.pump();

    // 输入框自身也包含「苹果」文本，只断言选项列表内的过滤结果。
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('苹果')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('香蕉')),
      findsNothing,
      reason: '过滤后不匹配项应隐藏',
    );
  });
}
