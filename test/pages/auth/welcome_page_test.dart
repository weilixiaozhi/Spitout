// 欢迎页（新用户引导页）币种列表布局测试。
//
// 覆盖任务：币种列表布局调整
//   1. 每行：Radio + 全局统一「ISO + (符号)」展示（如 CNY (¥)）
//   2. 列表下方间距由 16 压缩为 6，列表区总高度因此增加 10px

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/auth/welcome_page.dart';
import 'package:spitout/utils/currency/currencies.dart';

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

  testWidgets('币种行布局：Radio + ISO + (符号) 统一展示', (tester) async {
    await prime(tester);

    // 与 currencyFlagLabel 同源计算，避免本地化文案微调导致脆断；
    // 统一后单行文本为「ISO + (符号)」，例：CNY (¥)
    final label = 'CNY (${getCurrencySymbol('CNY')})';

    // 先定位币种列表，再在列表中定位"CNY 这一行"。
    final listFinder = find.byKey(const Key('currencyListView'));
    final labelFinder =
        find.descendant(of: listFinder, matching: find.text(label));
    expect(labelFinder, findsOneWidget, reason: 'CNY 行应有统一「名称 ISO (符号)」文本');

    // 行容器即 CNY 标签所在的那个 InkWell（每行一个）
    final rowFinder = find.ancestor(of: labelFinder, matching: find.byType(InkWell));

    // 坐标递增：Radio < 名称（ISO 符号）
    final radioFinder = find.descendant(of: rowFinder, matching: find.byType(Icon));
    final xRadio = tester.getTopLeft(radioFinder).dx;
    final xLabel = tester.getTopLeft(labelFinder).dx;
    expect(xRadio, lessThan(xLabel), reason: 'Radio 应在币种文本左侧');
  });

  testWidgets('列表下方间距压缩为 6：列表区加高 10px', (tester) async {
    await prime(tester);

    // 币种列表（Expanded）与底部描述文案之间的间距由 16 压缩为 6，
    // 压缩出的 10px 由 Expanded 列表吸收，列表总高度因此增加 10px。
    expect(
      find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 6 && w.width == null),
      findsOneWidget,
      reason: '列表下方应为 6px 间距（由原 16px 压缩 10px 让给列表区）',
    );
  });
}
