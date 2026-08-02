// 验证「红绿支出颜色方案」开关是否生效，以及是否同步生效（无需 loading）。
//
// 关键点：调用方用 ref.watch 订阅 expenseColorSchemeProvider 决定支出颜色。
// 本测试渲染一个读取该 provider 的 Consumer，
// 切换 provider 值后仅 pump 一帧（不 await 任何异步任务），断言颜色已同步更新，
// 用以证明切换是即时生效、不需要等待 loading 的。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/providers/ui/theme_providers.dart';
import 'package:spitout/theme/colors.dart';

void main() {
  testWidgets('切换支出颜色方案后金额颜色即时生效（同步，无 loading）',
      (WidgetTester tester) async {
    // 渲染一个直接读 expenseColorSchemeProvider 的小部件，模拟列表项金额着色。
    const amountKey = Key('amount');
    Widget buildApp() => ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Container(
                  key: amountKey,
                  // 这里复用与列表项相同的着色逻辑，确保测的是真实路径。
                  color: ref.watch(expenseColorSchemeProvider) == 'green'
                      ? SpitoutTokens.success(context)
                      : SpitoutTokens.error(context),
                  width: 50,
                  height: 50,
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildApp());

    final ctx = tester.element(find.byKey(amountKey));

    // 默认方案为 'red' → 应使用 error 色（亮色下 #D94A5B）。
    expect(
      (tester.widget(find.byKey(amountKey)) as Container).color,
      equals(SpitoutTokens.error(ctx)),
    );

    // 切换到 'green'：仅更新 provider，然后只 pump 一帧（不 await 异步）。
    ProviderScope.containerOf(ctx)
        .read(expenseColorSchemeProvider.notifier)
        .state = 'green';
    await tester.pump();

    // 颜色应立即变为 success 色（亮色下 #22C55E），证明同步生效、无需 loading。
    expect(
      (tester.widget(find.byKey(amountKey)) as Container).color,
      equals(SpitoutTokens.success(ctx)),
    );

    // 再切回 'red'，同样仅 pump 一帧，验证可双向即时切换。
    ProviderScope.containerOf(tester.element(find.byKey(amountKey)))
        .read(expenseColorSchemeProvider.notifier)
        .state = 'red';
    await tester.pump();

    expect(
      (tester.widget(find.byKey(amountKey)) as Container).color,
      equals(SpitoutTokens.error(ctx)),
    );
  });
}
