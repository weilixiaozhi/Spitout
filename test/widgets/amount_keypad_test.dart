/// AmountKeypad 数字键盘组件测试。
///
///   A. 逻辑行为：
///     1. 渲染所有数字键 0-9、小数点、4 个运算符、日期、完成键；
///     2. 点击数字键 → onAppend；点击运算符 → onApplyOp；点击日期 → onPickDate；
///     3. operating 态显示 `=` 并点击 → onApplyEquals；
///     4. waiting/calculated 态显示 Enter 图标，isDoneEnabled=true 点击 → onSubmit；
///     5. isDoneEnabled=false 完成键禁用，不触发回调；
///     6. isSubmitting=true 显示 loading 指示器。
///
///   B. 布局：
///     7. 单行高 h = (键盘高 - 3×2px 行距) / 4，数字网格区 = 3h + 2×2px，
///        底部行 = h，随容器高度伸缩（无绝对像素行高）；
///     8. 运算符顺序自上而下 + - × ÷；
///     9. 数字/运算符/日期为白色色块，完成为主题主色；
///     10. 键距/行距全局 2px、按键圆角统一 5px；
///     11. textScaler 封顶 1.0：系统 1.5× 大字体下文字高度不超 1.0× 基线。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/widgets/amount_keypad.dart';
import 'package:spitout/widgets/keypad_constants.dart';
import 'package:spitout/widgets/press_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构建测试宿主：提供本地化 + 主题 + 固定宽高约束。
  ///
  /// 设计意图：AmountKeypad 行高从自身约束反推，测试通过 [keypadHeight]
  /// 模拟键盘容器在不同机型/键盘状态下的高度；宽度 360 模拟主流手机。
  ///
  /// [textScaler] 通过外层 MediaQuery 注入（而非 tester.view.textScaler），
  /// 以兼容不同 Flutter 版本，验证 keypad 内部封顶逻辑。
  Widget buildHarness({
    required double keypadHeight,
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
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: textScaler == null
                  ? mq
                  : mq.copyWith(textScaler: textScaler),
              child: Center(
                child: SizedBox(
                  width: screenWidth,
                  height: keypadHeight,
                  child: AmountKeypad(
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

  /// 定位包裹指定按键文本的 PressKey。
  PressKey pressKeyOf(WidgetTester tester, String label) =>
      tester.widget<PressKey>(
        find
            .ancestor(of: find.text(label), matching: find.byType(PressKey))
            .first,
      );

  group('A. 逻辑行为（迁移防回归）', () {
    testWidgets('渲染所有按键：0-9、小数点、4 运算符、日期、完成键', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      // 数字键 + 小数点
      for (final n in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.']) {
        expect(find.text(n), findsOneWidget, reason: '数字键 $n 应渲染');
      }
      // 4 个运算符（opGlyph 直返原值）
      for (final op in ['+', '-', '×', '÷']) {
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
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          onAppend: appended.add,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      await tester.tap(find.text('7'));
      await tester.tap(find.text('.'));
      await tester.tap(find.text('0'));

      expect(appended, ['7', '.', '0']);
    });

    testWidgets('点击运算符触发 onApplyOp 传入对应运算符', (tester) async {
      final applied = <String>[];
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          onApplyOp: applied.add,
          onAppend: noopAppend,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      await tester.tap(find.text('+'));
      await tester.tap(find.text('-'));
      await tester.tap(find.text('×'));
      await tester.tap(find.text('÷'));

      expect(applied, ['+', '-', '×', '÷']);
    });

    testWidgets('点击日期键触发 onPickDate', (tester) async {
      var picked = 0;
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          onPickDate: () => picked++,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onSubmit: noop,
        ),
      );

      await tester.tap(find.text('2026/7/27'));
      expect(picked, 1);
    });

    testWidgets('operating 态显示 = 并点击触发 onApplyEquals', (tester) async {
      var equalsCalled = false;
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          calcState: 'operating',
          op: '+',
          onApplyEquals: () => equalsCalled = true,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      expect(find.text('='), findsOneWidget);
      await tester.tap(find.text('='));
      expect(equalsCalled, isTrue);
    });

    testWidgets('waiting 态 isDoneEnabled=true 点击 Enter 触发 onSubmit', (
      tester,
    ) async {
      var submitted = false;
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          calcState: 'waiting',
          isDoneEnabled: true,
          onSubmit: () => submitted = true,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
        ),
      );

      final icon = find.byIcon(AppIcons.keyboardReturn);
      expect(icon, findsOneWidget);
      await tester.tap(icon);
      expect(submitted, isTrue);
    });

    testWidgets('isDoneEnabled=false 完成键禁用，不触发 onSubmit', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          calcState: 'waiting',
          isDoneEnabled: false,
          onSubmit: () => submitted = true,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
        ),
      );

      // 图标仍在，但 PressKey 禁用 → tap 不触发回调
      final icon = find.byIcon(AppIcons.keyboardReturn);
      expect(icon, findsOneWidget);
      await tester.tap(icon, warnIfMissed: false);
      await tester.pump();
      expect(submitted, isFalse);
    });

    testWidgets('isSubmitting=true 显示 loading 指示器', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          isSubmitting: true,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('B. 布局重构（无绝对像素行高）', () {
    testWidgets('行高从容器高度反推：h=(高-3×2)/4，网格=3h+4，底部行=h', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      final h = (400 - 3 * KeypadLayout.rowGap) / 4;
      final gridH = tester
          .getSize(find.byKey(const ValueKey('keypad_num_grid')))
          .height;
      expect(gridH, closeTo(3 * h + 2 * KeypadLayout.rowGap, 0.01));

      final bottomH = tester
          .getSize(find.byKey(const ValueKey('keypad_bottom_row')))
          .height;
      expect(bottomH, closeTo(h, 0.01));
    });

    testWidgets('小高度容器下行高同步缩小（如系统键盘拉起时）', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 250,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      final h = (250 - 3 * KeypadLayout.rowGap) / 4;
      final gridH = tester
          .getSize(find.byKey(const ValueKey('keypad_num_grid')))
          .height;
      expect(gridH, closeTo(3 * h + 2 * KeypadLayout.rowGap, 0.01));
      expect(
        tester.getSize(find.byKey(const ValueKey('keypad_bottom_row'))).height,
        closeTo(h, 0.01),
      );
    });

    testWidgets('运算符顺序自上而下为 + - × ÷', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      final dy = <String, double>{
        for (final op in ['+', '-', '×', '÷'])
          op: tester.getTopLeft(find.text(op)).dy,
      };
      expect(dy['+']!, lessThan(dy['-']!), reason: '加号应在减号上方');
      expect(dy['-']!, lessThan(dy['×']!), reason: '减号应在乘号上方');
      expect(dy['×']!, lessThan(dy['÷']!), reason: '乘号应在除号上方');
    });

    testWidgets('数字/运算符/日期白色色块，完成主题主色', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      // 数字键与运算符长条 = 白色色块
      expect(
        pressKeyOf(tester, '5').backgroundColor,
        SpitoutColors.lightKeyDigit,
      );
      expect(
        pressKeyOf(tester, '0').backgroundColor,
        SpitoutColors.lightKeyDigit,
      );
      final opBar = tester.widget<Material>(
        find.byKey(const ValueKey('keypad_op_bar')),
      );
      expect(opBar.color, SpitoutColors.lightKeyDigit);

      // 日期键 = 白色色块；完成键 = 主题主色（主操作按钮）
      expect(
        pressKeyOf(tester, '2026/7/27').backgroundColor,
        SpitoutColors.lightKeyDigit,
      );
      final doneKey = find.ancestor(
        of: find.byIcon(AppIcons.keyboardReturn),
        matching: find.byType(PressKey),
      );
      final primary = Theme.of(
        tester.element(find.byType(AmountKeypad)),
      ).colorScheme.primary;
      expect(tester.widget<PressKey>(doneKey).backgroundColor, primary);
    });

    testWidgets('键距/行距全局 2px、按键圆角统一 5px', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );

      // 常量单一来源
      expect(KeypadLayout.gap, 2);
      expect(KeypadLayout.rowGap, 2);
      expect(KeypadLayout.keyRadius, 5);

      // 底部行水平键距 2px：'0' 与 '.' 中心距 = 列宽 + 2
      final colWidth = (360 - 3 * KeypadLayout.gap) / 4;
      final x0 = tester.getCenter(find.text('0')).dx;
      final xDot = tester.getCenter(find.text('.')).dx;
      expect(xDot - x0, closeTo(colWidth + KeypadLayout.gap, 0.01));

      // 数字网格区与底部行纵向行距 2px
      final gridBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('keypad_num_grid')))
          .dy;
      final bottomTop = tester
          .getTopLeft(find.byKey(const ValueKey('keypad_bottom_row')))
          .dy;
      expect(bottomTop - gridBottom, KeypadLayout.rowGap);

      // 所有带圆角的按键统一 5px（运算符热区透明、由长条统一圆角）
      for (final key in tester.widgetList<PressKey>(find.byType(PressKey))) {
        if (key.borderRadius != null) {
          expect(
            key.borderRadius,
            BorderRadius.circular(KeypadLayout.keyRadius),
          );
        }
      }
      expect(
        tester
            .widget<Material>(find.byKey(const ValueKey('keypad_op_bar')))
            .borderRadius,
        BorderRadius.circular(KeypadLayout.keyRadius),
      );
    });

    testWidgets('textScaler 封顶 1.0：系统 1.5× 大字体下文字不超 1.0× 基线', (tester) async {
      // 基线：textScaler=1.0
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          textScaler: TextScaler.linear(1.0),
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );
      final baseH = tester.getSize(find.text('5')).height;

      // 放大到 1.5×，应被 keypad 内部封顶到 1.0×
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          textScaler: TextScaler.linear(1.5),
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );
      final cappedH = tester.getSize(find.text('5')).height;

      // 取 1.0× 参照高度，验证 1.5× 输入被 cap 到与 1.0× 一致
      await tester.pumpWidget(
        buildHarness(
          keypadHeight: 400,
          textScaler: TextScaler.linear(1.0),
          onAppend: noopAppend,
          onApplyOp: noopOp,
          onApplyEquals: noop,
          onPickDate: noop,
          onSubmit: noop,
        ),
      );
      final refH = tester.getSize(find.text('5')).height;

      // 1.5× 被封顶 → 渲染高度应等于 1.0× 参照
      expect(cappedH, closeTo(refH, 0.5));
      // 且明显小于未封顶时的 1.5× 预期（baseH*1.5），证明封顶生效
      expect(cappedH, lessThan(baseH * 1.45));
    });
  });
}
