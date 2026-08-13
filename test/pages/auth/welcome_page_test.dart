// 欢迎页（新用户引导页）币种列表布局测试。
//
// 覆盖任务：币种列表布局调整
//   1. 每行：Radio + 固定宽度符号列 + 「名称 (ISO)」左对齐展示（如 ¥  人民币 (CNY)），
//      与币种选择弹窗同一 UI 口径（符号长短不一时名称列仍整列对齐）
//   2. 列表下方间距由 16 压缩为 6，列表区总高度因此增加 10px

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/auth/welcome_page.dart';
import 'package:spitout/utils/currency/currencies.dart';
import 'package:spitout/widgets/currency_flag.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp() {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const WelcomePage(),
      ),
    );
  }

  /// 注入系统语言为简体中文并构建页面。
  ///
  /// 设计意图：必须在 [WidgetTester.pumpWidget] 之前设置
  /// [TestWidgetsFlutterBinding.platformDispatcher.localeTestValue]，
  /// 这样 [WelcomePage.initState] 读取平台 locale 时就能拿到 zh，
  /// 使欢迎页币种顺序首项为 CNY、且默认选中 CNY，保证"CNY 首行可见"在任意测试主机上确定通过。
  Future<void> prime(WidgetTester tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('zh');
    // 防御性清理：localeTestValue 是平台级全局状态，在同一 isolate 内跨用例残留。
    // prime 必然先设置再注册清除，故 clearLocaleTestValue 不会因"未设置"而抛异常；
    // 仍用 try-catch 兜底，保证任意执行顺序与新增用例都不读到上一个用例的 locale，
    // 从根源上消除该测试潜在的跨用例污染。
    addTearDown(() {
      try {
        tester.binding.platformDispatcher.clearLocaleTestValue();
      } catch (_) {
        // 未设置过 testValue，无需清除。
      }
    });
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
  }

  testWidgets('币种行布局：Radio + 符号列 + 名称 (ISO) 左对齐展示', (tester) async {
    await prime(tester);

    // 先定位币种列表，再在列表中定位"CNY 这一行"。
    // 名称文本为「本地化名称 + (ISO)」（例：人民币 (CNY)）；
    // 用 (CNY) 包含匹配定位，避免本地化文案微调导致脆断。
    final listFinder = find.byKey(const Key('currencyListView'));
    final labelFinder = find.descendant(
        of: listFinder, matching: find.textContaining('(CNY)'));
    expect(labelFinder, findsOneWidget, reason: 'CNY 行应有「名称 (ISO)」文本');

    // 行容器即 CNY 标签所在的那个 InkWell（每行一个）
    final rowFinder =
        find.ancestor(of: labelFinder, matching: find.byType(InkWell));

    // 同行应有固定宽度符号列（符号与 getCurrencySymbol 同源计算）
    final symbolFinder = find.descendant(
        of: rowFinder, matching: find.text(getCurrencySymbol('CNY')));
    expect(symbolFinder, findsOneWidget, reason: '行内应展示币种符号');
    final symbolBox = tester.widget<SizedBox>(
      find
          .ancestor(of: symbolFinder, matching: find.byType(SizedBox))
          .first,
    );
    expect(symbolBox.width, kCurrencySymbolColumnWidth,
        reason: '符号列应为固定宽度，保证名称列整列左对齐');

    // 坐标递增：Radio < 符号 < 名称
    final radioFinder =
        find.descendant(of: rowFinder, matching: find.byType(Icon));
    final xRadio = tester.getTopLeft(radioFinder).dx;
    final xSymbol = tester.getTopLeft(symbolFinder).dx;
    final xLabel = tester.getTopLeft(labelFinder).dx;
    expect(xRadio, lessThan(xSymbol), reason: 'Radio 应在符号左侧');
    expect(xSymbol, lessThan(xLabel), reason: '符号应在名称左侧');

    // 名称列跨行对齐：zh 顺序第 2 行为 HKD（符号 HK$ 明显长于 ¥），
    // 两行名称起始 x 必须一致——这是固定符号列宽的核心目的。
    final hkdLabelFinder = find.descendant(
        of: listFinder, matching: find.textContaining('(HKD)'));
    expect(hkdLabelFinder, findsOneWidget, reason: 'HKD 行应可见（zh 顺序第 2 行）');
    expect(tester.getTopLeft(hkdLabelFinder).dx, xLabel,
        reason: '符号长短不一（¥ 与 HK\$）时名称列仍应左对齐到同一 x 位置');
  });

  testWidgets('列表下方间距压缩为 4：列表区加高让位', (tester) async {
    await prime(tester);

    // 币种列表（Expanded）与底部描述文案之间的间距压缩为 4（SpitoutDimens.p4）。
    expect(
      find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 4 && w.width == null),
      findsOneWidget,
      reason: '列表下方应为 4px 间距（p4）',
    );
  });
}
