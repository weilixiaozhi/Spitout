// 「管理展示币种」页币种行布局测试。
//
// 覆盖任务：与欢迎页币种列表、币种选择弹窗同一 UI 口径
//   1. 每行：固定宽度符号列 + 「名称 (ISO)」左对齐展示（如 ¥  人民币 (CNY)），
//      符号长短不一时名称列仍整列对齐（CNY 行符号 ¥ 与 HKD 行符号 HK$ 宽度差异明显）
//   2. 符号列宽度 = kCurrencySymbolColumnWidth，与全局口径一致

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/pages/currency/currency_manage_page.dart';
import 'package:spitout/providers/currency/currency_providers.dart';
import 'package:spitout/utils/currency/currencies.dart';
import 'package:spitout/widgets/currency_flag.dart';
import 'package:spitout/theme/icons/app_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 构建被测页面：override 当前账本本位币为 CNY、可见币种集合含 CNY + HKD，
  /// 避免触发真实数据库 provider（页面 build 仅 watch 这两个 provider）。
  ///
  /// 设计意图：CurrencyManagePage 依赖 currentLedgerCurrencyProvider 与
  /// visibleCurrenciesProvider。前者默认链到 currentLedgerProvider(StreamProvider,
  /// 依赖数据库)，测试中直接 override 成定值，规避数据库初始化成本与不确定性。
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        currentLedgerCurrencyProvider.overrideWith((ref) => 'CNY'),
        visibleCurrenciesProvider.overrideWithBuild(
          (ref, notifier) => {'CNY', 'HKD', 'USD'},
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const CurrencyManagePage(),
      ),
    );
  }

  /// 注入系统语言为简体中文并构建页面。
  ///
  /// 设计意图：orderCurrencies 会按系统语言给常用币种重排，zh 顺序里
  /// HKD 排在很靠前的位置（与 CNY 同属常用集），保证测试中 CNY 与 HKD
  /// 两行都可见、且 HKD 行不会被分页/折叠。locale 用 localeTestValue
  /// 注入，保证在任意测试主机上确定性。
  Future<void> prime(WidgetTester tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('zh');
    // 防御性清理：localeTestValue 是平台级全局状态，跨用例残留。
    // 用 try-catch 兜底，保证不会因「未设置」抛异常。
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

  testWidgets('币种行布局：固定宽度符号列 + 名称 (ISO) 左对齐展示', (tester) async {
    await prime(tester);

    // 名称文本为「本地化名称 + (ISO)」（例：人民币 (CNY)），
    // 用 (CNY) 包含匹配定位，避免本地化文案微调导致脆断。
    final cnyLabelFinder = find.textContaining('(CNY)');
    expect(cnyLabelFinder, findsOneWidget, reason: 'CNY 行应有「名称 (ISO)」文本');

    // CNY 行容器：名称所在的 InkWell（每行一个）
    final cnyRowFinder =
        find.ancestor(of: cnyLabelFinder, matching: find.byType(InkWell));
    expect(cnyRowFinder, findsOneWidget);

    // 同行应有固定宽度符号列（符号与 getCurrencySymbol 同源计算）
    final cnySymbolFinder = find.descendant(
        of: cnyRowFinder, matching: find.text(getCurrencySymbol('CNY')));
    expect(cnySymbolFinder, findsOneWidget, reason: 'CNY 行内应展示币种符号 ¥');
    final cnySymbolBox = tester.widget<SizedBox>(
      find.ancestor(of: cnySymbolFinder, matching: find.byType(SizedBox)).first,
    );
    expect(cnySymbolBox.width, kCurrencySymbolColumnWidth,
        reason: 'CNY 符号列应为固定宽度 kCurrencySymbolColumnWidth');

    // 同样验证 HKD 行（符号 HK$ 明显长于 ¥，是验证列宽固定意义的核心用例）
    final hkdLabelFinder = find.textContaining('(HKD)');
    expect(hkdLabelFinder, findsOneWidget, reason: 'HKD 行应可见');
    final hkdRowFinder =
        find.ancestor(of: hkdLabelFinder, matching: find.byType(InkWell));
    final hkdSymbolFinder = find.descendant(
        of: hkdRowFinder, matching: find.text(getCurrencySymbol('HKD')));
    expect(hkdSymbolFinder, findsOneWidget, reason: 'HKD 行内应展示币种符号 HK\$');
    final hkdSymbolBox = tester.widget<SizedBox>(
      find.ancestor(of: hkdSymbolFinder, matching: find.byType(SizedBox)).first,
    );
    expect(hkdSymbolBox.width, kCurrencySymbolColumnWidth,
        reason: 'HKD 符号列应为固定宽度 kCurrencySymbolColumnWidth');
  });

  testWidgets('符号长短不一时名称列跨行左对齐', (tester) async {
    await prime(tester);

    // 取 CNY 行与 HKD 行的名称文本起始 x 坐标，必须一致。
    // 这是固定符号列宽的核心目的：符号 ¥（1 字符）与 HK\$（3 字符）宽度
    // 差异明显，若符号按内容自适应宽度，两行名称起始 x 必然不同。
    final cnyLabelFinder = find.textContaining('(CNY)');
    final hkdLabelFinder = find.textContaining('(HKD)');
    expect(cnyLabelFinder, findsOneWidget);
    expect(hkdLabelFinder, findsOneWidget);

    final xCny = tester.getTopLeft(cnyLabelFinder).dx;
    final xHkd = tester.getTopLeft(hkdLabelFinder).dx;
    expect(xHkd, xCny,
        reason:
            '符号长短不一（¥ 与 HK\$）时名称列仍应左对齐到同一 x 位置');
  });

  testWidgets('主币种行锁定：Checkbox 强制勾选且禁用', (tester) async {
    await prime(tester);

    // CNY 是 override 的本位币，该行 Checkbox 应禁用（onChanged=null）且勾选。
    final cnyLabelFinder = find.textContaining('(CNY)');
    final cnyRowFinder =
        find.ancestor(of: cnyLabelFinder, matching: find.byType(InkWell));
    final cnyCheckbox = tester.widget<Checkbox>(
      find.descendant(of: cnyRowFinder, matching: find.byType(Checkbox)),
    );
    expect(cnyCheckbox.value, true, reason: '本位币行 Checkbox 应强制勾选');
    expect(cnyCheckbox.onChanged, isNull, reason: '本位币行 Checkbox 应禁用');

    // 同时行内应显示锁图标提示（主币种锁定提示文案）
    final lockFinder = find.descendant(of: cnyRowFinder, matching: find.byIcon(AppIcons.lock));
    expect(lockFinder, findsOneWidget, reason: '本位币行应显示锁图标提示');
  });
}
