/// AmountKeypad 数字键盘组件测试。
///
/// 本次改动（UI 尺寸自适应：行高从写死 56 改为由父层下传的 u 派生）
/// 属于"不涉及逻辑变更的 UI 调整"，故先制定 widget 组件测试锁定行为，
/// 确保迁移安全无影响：
///
///   A. 逻辑行为（迁移前后不变，防止回归）：
///     1. 渲染所有数字键 0-9、小数点、4 个运算符、日期、完成键；
///     2. 点击数字键 → onAppend；点击运算符 → onApplyOp；点击日期 → onPickDate；
///     3. operating 态显示 `=` 并点击 → onApplyEquals；
///     4. waiting/calculated 态显示 Enter 图标，isDoneEnabled=true 点击 → onSubmit；
///     5. isDoneEnabled=false 完成键禁用，不触发回调；
///     6. isSubmitting=true 显示 loading 指示器。
///
///   B. 尺寸自适应（本次改动核心）：
///     7. u=56 → 数字网格区高度 = 3*56+2*8，底部行高度 = 56；
///     8. u=44 → 行高随 u 等比缩小，验证小屏自适应；
///     9. textScaler 封顶 1.2：系统 1.5× 大字体下文字高度不超 1.2× 基线。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/amount_keypad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构建测试宿主：提供本地化 + 主题 + 固定宽高约束。
  ///
  /// 设计意图：AmountKeypad 内部 Column 默认 mainAxisSize.max，需要有限高度
  /// 约束才能正常布局；高度给 400（> 内容高度 4*u+24）保证不溢出，且不影响
  /// 对按键行高（由 SizedBox(height: u) 固定）的断言。宽度 360 模拟主流手机。
  ///
  /// [textScaler] 通过外层 MediaQuery 注入（而非 tester.view.textScaler），
  /// 以兼容不同 Flutter 版本，验证 keypad 内部封顶逻辑。
  Widget buildHarness({
    required double u,
    DateTime? date,
    bool showTime = true,
    String calcState = 'waiting',
    String? op,
    bool isDoneEnabled = true,
    bool isSubmitting = false,
    double screenWidth = 360,
    TextScaler? textScaler,
    required ValueChanged<String> onAppend,
    required ValueChanged<String> onApplyOp,
    required VoidCallback onApplyEquals,
    required VoidCallback onPickDate,
    required VoidCallback onSubmit,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            // 注入测试用 textScaler（模拟系统大字体），验证 keypad 内部封顶逻辑。
            // 不直接操作 tester.view.textScaler，以兼容不同 Flutter 版本。
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data:
                  textScaler == null ? mq : mq.copyWith(textScaler: textScaler),
              child: Center(
                child: SizedBox(
                  width: screenWidth,
                  height: 400,
                  child: AmountKeypad(
                    u: u,
                    date: date ?? DateTime(2026, 7, 27, 9, 30),
                    showTime: showTime,
                    calcState: calcState,
                    op: op,
                    isDoneEnabled: isDoneEnabled,
                    isSubmitting: isSubmitting,
                    opGlyph: (o) => o,
                    onAppend: onAppend,
                    onApplyOp: onApplyOp,
                    onApplyEquals: onApplyEquals,
                    onPickDate: onPickDate,
                    onSubmit: onSubmit,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 默认回调集合（空操作），多数用例只需断言渲染，复用此变量减少样板。
  void noop() {}
  void noopAppend(String _) {}
  void noopOp(String _) {}

  group('A. 逻辑行为（迁移防回归）', () {
    testWidgets('渲染所有按键：0-9、小数点、4 运算符、日期、完成键', (tester) async {
      await tester.pumpWidget(buildHarness(
        u: 56,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));

      // 数字键 + 小数点
      for (final n in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.']) {
        expect(find.text(n), findsOneWidget, reason: '数字键 $n 应渲染');
      }
      // 4 个运算符（opGlyph 直返原值）
      for (final op in ['×', '÷', '-', '+']) {
        expect(find.text(op), findsOneWidget, reason: '运算符 $op 应渲染');
      }
      // 日期键显示日期文本
      expect(find.text('2026/7/27'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      // waiting 态显示 Enter 图标
      expect(find.byIcon(AppIcons.keyboardReturn), findsOneWidget);
    });

    testWidgets('点击数字键触发 onAppend 对应字符', (tester) async {
      final appended = <String>[];
      await tester.pumpWidget(buildHarness(
        u: 56,
        onAppend: appended.add,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));

      await tester.tap(find.text('7'));
      await tester.tap(find.text('.'));
      await tester.tap(find.text('0'));

      expect(appended, ['7', '.', '0']);
    });

    testWidgets('点击运算符触发 onApplyOp 传入对应运算符', (tester) async {
      final applied = <String>[];
      await tester.pumpWidget(buildHarness(
        u: 56,
        onApplyOp: applied.add,
        onAppend: noopAppend,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));

      await tester.tap(find.text('×'));
      await tester.tap(find.text('÷'));
      await tester.tap(find.text('-'));
      await tester.tap(find.text('+'));

      expect(applied, ['×', '÷', '-', '+']);
    });

    testWidgets('点击日期键触发 onPickDate', (tester) async {
      var picked = 0;
      await tester.pumpWidget(buildHarness(
        u: 56,
        onPickDate: () => picked++,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onSubmit: noop,
      ));

      await tester.tap(find.text('2026/7/27'));
      expect(picked, 1);
    });

    testWidgets('operating 态显示 = 并点击触发 onApplyEquals', (tester) async {
      var equalsCalled = false;
      await tester.pumpWidget(buildHarness(
        u: 56,
        calcState: 'operating',
        op: '+',
        onApplyEquals: () => equalsCalled = true,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onPickDate: noop,
        onSubmit: noop,
      ));

      expect(find.text('='), findsOneWidget);
      await tester.tap(find.text('='));
      expect(equalsCalled, isTrue);
    });

    testWidgets('waiting 态 isDoneEnabled=true 点击 Enter 触发 onSubmit',
        (tester) async {
      var submitted = false;
      await tester.pumpWidget(buildHarness(
        u: 56,
        calcState: 'waiting',
        isDoneEnabled: true,
        onSubmit: () => submitted = true,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
      ));

      final icon = find.byIcon(AppIcons.keyboardReturn);
      expect(icon, findsOneWidget);
      await tester.tap(icon);
      expect(submitted, isTrue);
    });

    testWidgets('isDoneEnabled=false 完成键禁用，不触发 onSubmit', (tester) async {
      var submitted = false;
      await tester.pumpWidget(buildHarness(
        u: 56,
        calcState: 'waiting',
        isDoneEnabled: false,
        onSubmit: () => submitted = true,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
      ));

      // 图标仍在，但 InkWell.onTap 为 null → tap 不触发回调
      final icon = find.byIcon(AppIcons.keyboardReturn);
      expect(icon, findsOneWidget);
      await tester.tap(icon, warnIfMissed: false);
      await tester.pump();
      expect(submitted, isFalse);
    });

    testWidgets('isSubmitting=true 显示 loading 指示器', (tester) async {
      await tester.pumpWidget(buildHarness(
        u: 56,
        isSubmitting: true,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('B. 尺寸自适应（本次改动核心）', () {
    testWidgets('u=56 时数字网格区高度 = 3*56+2*8，底部行高度 = 56',
        (tester) async {
      await tester.pumpWidget(buildHarness(
        u: 56,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));

      final gridH = tester
          .getSize(find.byKey(const ValueKey('keypad_num_grid')))
          .height;
      expect(gridH, 3 * 56 + 2 * 8);

      final bottomH = tester
          .getSize(find.byKey(const ValueKey('keypad_bottom_row')))
          .height;
      expect(bottomH, 56);
    });

    testWidgets('u=44 时行高随 u 等比缩小（小屏自适应）', (tester) async {
      await tester.pumpWidget(buildHarness(
        u: 44,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));

      final gridH = tester
          .getSize(find.byKey(const ValueKey('keypad_num_grid')))
          .height;
      expect(gridH, 3 * 44 + 2 * 8);

      final bottomH = tester
          .getSize(find.byKey(const ValueKey('keypad_bottom_row')))
          .height;
      expect(bottomH, 44);
    });

    testWidgets('u=36 时键盘压缩到方案 A 新下限，行高随 u 等比缩小',
        (tester) async {
      await tester.pumpWidget(buildHarness(
        u: 36,
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));

      final gridH = tester
          .getSize(find.byKey(const ValueKey('keypad_num_grid')))
          .height;
      expect(gridH, 3 * 36 + 2 * 8);

      final bottomH =
          tester.getSize(find.byKey(const ValueKey('keypad_bottom_row'))).height;
      expect(bottomH, 36);
    });

    testWidgets('textScaler 封顶 1.2：系统 1.5× 大字体下文字不超 1.2× 基线',
        (tester) async {
      // 基线：textScaler=1.0
      await tester.pumpWidget(buildHarness(
        u: 56,
        textScaler: TextScaler.linear(1.0),
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));
      final baseH = tester.getSize(find.text('5')).height;

      // 放大到 1.5×，应被 keypad 内部封顶到 1.2×
      await tester.pumpWidget(buildHarness(
        u: 56,
        textScaler: TextScaler.linear(1.5),
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));
      final cappedH = tester.getSize(find.text('5')).height;

      // 取 1.2× 参照高度，验证 1.5× 输入被 cap 到与 1.2× 一致
      await tester.pumpWidget(buildHarness(
        u: 56,
        textScaler: TextScaler.linear(1.2),
        onAppend: noopAppend,
        onApplyOp: noopOp,
        onApplyEquals: noop,
        onPickDate: noop,
        onSubmit: noop,
      ));
      final refH = tester.getSize(find.text('5')).height;

      // 1.5× 被封顶 → 渲染高度应等于 1.2× 参照
      expect(cappedH, closeTo(refH, 0.5));
      // 且明显小于未封顶时的 1.5× 预期（baseH*1.5），证明封顶生效
      expect(cappedH, lessThan(baseH * 1.45));
    });
  });
}
