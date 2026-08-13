/// AmountInputPanel 金额输入面板组件测试。
///
/// 需求锚点：
/// - 编辑模式回填金额，外币隐含汇率（nativeAmount / amount）回填汇率行；
/// - 计算器三态状态机：数字追加 / 两位小数限制 / 运算符替换 / 等号计算 /
///   除零保护 / 长按清空 / 退格 / 滑出取消回滚；
/// - 完成键可用性：金额 > 0 且已选分类，operating 态始终可用；提交回调
///   携带总额、交易币种与汇率；
/// - 多币种：币种选择 sheet 联动、汇率缺失提示与手填、折算预览、自动拉取；
/// - 日期键回调 onPickDate。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spitout/data/models.dart' show Ledger;
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/currency/exchange_rate_service.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/utils/currency/rate_math.dart' show EffectiveRate;
import 'package:spitout/widgets/amount_expression_bar.dart';
import 'package:spitout/widgets/amount_input_panel.dart';
import 'package:spitout/widgets/press_key.dart';

class _MockRepo extends Mock implements LocalRepository {}

/// 假汇率服务：fetch 立即失败，避免自动拉汇率触发真实网络。
class _FailingRateService implements ExchangeRateService {
  int fetchCount = 0;
  @override
  Future<RateFetchResult> fetch(String base) async {
    fetchCount++;
    throw RateFetchException('fake fail');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Ledger _ledger({String currency = 'CNY'}) => Ledger(
  id: 1,
  name: '测试账本',
  currency: currency,
  type: 'personal',
  createdAt: DateTime(2026, 1, 1),
  myRole: 'owner',
  memberCount: 1,
  isShared: false,
  monthStartDay: 1,
  storageMode: 'local',
  aaEnabled: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late _FailingRateService rateService;

  setUp(() {
    repo = _MockRepo();
    rateService = _FailingRateService();
    // effectiveRatesForLedgerProvider 依赖的 repo 读操作给空值。
    when(() => repo.getLatestAutoRates(any())).thenAnswer((_) async => const []);
    when(() => repo.getOverrides(any())).thenAnswer((_) async => const []);
    // 自动拉汇率走 refreshExchangeRatesImpl：无账本时直接跳过拉取。
    when(() => repo.getAllLedgers()).thenAnswer((_) async => <Ledger>[]);
  });

  /// 挂载 AmountInputPanel。
  ///
  /// [rates] 注入有效汇率表（交易币种 → 本位币）；默认空表（无汇率）。
  Future<GlobalKey> pumpPanel(
    WidgetTester tester, {
    double? initialAmount,
    String? initialCurrencyCode,
    double? initialNativeAmount,
    DateTime? date,
    bool categorySelected = true,
    VoidCallback? onPickDate,
    void Function(double, String, double?)? onSubmit,
    Map<String, EffectiveRate> rates = const {},
    Map<String, double>? pickerRates,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          currentLedgerProvider.overrideWith(
            (ref) => Stream<Ledger?>.value(_ledger()),
          ),
          effectiveRatesForLedgerProvider.overrideWith(
            (ref) async => rates,
          ),
          exchangeRateServiceProvider.overrideWithValue(rateService),
          spitoutCloudProviderInstance.overrideWith((ref) async => null),
          currencyPickerRatesProvider.overrideWith(
            (ref, base) async => pickerRates ?? const {},
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 480,
                child: AmountInputPanel(
                  key: key,
                  initialAmount: initialAmount,
                  initialCurrencyCode: initialCurrencyCode,
                  initialNativeAmount: initialNativeAmount,
                  date: date ?? DateTime(2026, 8, 8, 9, 30),
                  categorySelected: categorySelected,
                  onPickDate: onPickDate ?? () {},
                  onSubmit: onSubmit ?? (_, _, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return key;
  }

  /// 读取当前 AmountExpressionBar 的属性（金额/运算状态的展示口径）。
  AmountExpressionBar barOf(WidgetTester tester) =>
      tester.widget<AmountExpressionBar>(find.byType(AmountExpressionBar));

  Future<void> tapKey(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('编辑模式回填金额；外币隐含汇率回填汇率行', (tester) async {
    await pumpPanel(
      tester,
      initialAmount: 100,
      initialCurrencyCode: 'USD',
      initialNativeAmount: 720,
      rates: const {'USD': EffectiveRate(rate: '7.2', manual: false)},
    );

    // 金额保留两位以内的原始值。
    expect(barOf(tester).amountStr, '100');
    // 隐含汇率 = 720 / 100 = 7.2，折算预览可见。
    expect(barOf(tester).conversionPreview, '≈ 720.00 CNY');
    expect(barOf(tester).rateMissing, isFalse);
  });

  testWidgets('数字输入与两位小数限制', (tester) async {
    await pumpPanel(tester);
    await tapKey(tester, '1');
    await tapKey(tester, '2');
    expect(barOf(tester).amountStr, '12');

    await tapKey(tester, '.');
    await tapKey(tester, '5');
    await tapKey(tester, '5');
    expect(barOf(tester).amountStr, '12.55');

    // 第三位小数被拒绝。
    await tapKey(tester, '9');
    expect(barOf(tester).amountStr, '12.55');
  });

  testWidgets('运算符与等号：12 + 34 = 46，计算态进入 calculated', (tester) async {
    await pumpPanel(tester);
    await tapKey(tester, '1');
    await tapKey(tester, '2');
    await tapKey(tester, '+');
    expect(barOf(tester).op, '+');
    expect(barOf(tester).calcState, 'operating');

    await tapKey(tester, '3');
    await tapKey(tester, '4');
    expect(barOf(tester).equalsTotal, 46);

    // operating 态完成键显示 =，按下计算。
    await tapKey(tester, '=');
    expect(barOf(tester).calcState, 'calculated');
    expect(barOf(tester).amountStr, '46');
  });

  testWidgets('连续运算符替换：12 + → × 时只保留后一个', (tester) async {
    await pumpPanel(tester);
    await tapKey(tester, '1');
    await tapKey(tester, '2');
    await tapKey(tester, '+');
    await tapKey(tester, '×');
    expect(barOf(tester).op, '×');
    expect(barOf(tester).acc, 12);
  });

  testWidgets('除零保护：12 ÷ 0 = 保持被除数', (tester) async {
    await pumpPanel(tester);
    await tapKey(tester, '1');
    await tapKey(tester, '2');
    await tapKey(tester, '÷');
    // 数字 0 键（金额区初始也显示 0，需限定在 PressKey 内）。
    await tester.tap(find.widgetWithText(PressKey, '0'));
    await tester.pump();
    await tapKey(tester, '=');
    expect(barOf(tester).amountStr, '12');
  });

  testWidgets('减法与有限精度除法：9 − 4 = 5；1 ÷ 3 四舍五入到 0.33',
      (tester) async {
    await pumpPanel(tester);
    await tapKey(tester, '9');
    // 键盘显示真减号 −（opGlyph 映射）。
    await tapKey(tester, '−');
    await tapKey(tester, '4');
    await tapKey(tester, '=');
    expect(barOf(tester).amountStr, '5');

    // calculated 态直接输入新数字 → 回到 waiting 并替换为 1。
    await tapKey(tester, '1');
    expect(barOf(tester).calcState, 'waiting');
    expect(barOf(tester).amountStr, '1');

    await tapKey(tester, '÷');
    await tapKey(tester, '3');
    await tapKey(tester, '=');
    expect(barOf(tester).amountStr, '0.33');
  });

  testWidgets('退格删除一位；calculated 态退格回到 waiting', (tester) async {
    await pumpPanel(tester);
    // 先完成一次计算进入 calculated 态。
    await tapKey(tester, '1');
    await tapKey(tester, '+');
    await tapKey(tester, '2');
    await tapKey(tester, '=');
    expect(barOf(tester).calcState, 'calculated');

    // calculated 态退格 → 回 waiting 并删最后一位。
    final deleteKey = find.byKey(const ValueKey('amount_delete_key'));
    await tester.tap(deleteKey);
    await tester.pump();
    expect(barOf(tester).calcState, 'waiting');
    // '3' 退格后为空 → 兜底 '0'。
    expect(barOf(tester).amountStr, '0');

    // 继续输入 1/2/3 → '123'，普通退格 → '12'。
    await tapKey(tester, '1');
    await tapKey(tester, '2');
    await tapKey(tester, '3');
    await tester.tap(deleteKey);
    await tester.pump();
    expect(barOf(tester).amountStr, '12');

    await tester.tap(deleteKey);
    await tester.pump();
    await tester.tap(deleteKey);
    await tester.pump();
    expect(barOf(tester).amountStr, '0');
  });

  testWidgets('负值初值：退格到 -0 后输入数字带负号', (tester) async {
    await pumpPanel(
      tester,
      initialAmount: -0.10,
      initialCurrencyCode: 'CNY',
    );
    expect(barOf(tester).amountStr, '-0.1');

    final deleteKey = find.byKey(const ValueKey('amount_delete_key'));
    await tester.tap(deleteKey);
    await tester.pump();
    // -0.1 → -0. → -0
    await tester.tap(deleteKey);
    await tester.pump();
    expect(barOf(tester).amountStr, '-0');

    await tester.tap(find.text('7'));
    await tester.pump();
    expect(barOf(tester).amountStr, '-7');
  });

  testWidgets('长按删除键清空金额与运算状态', (tester) async {
    await pumpPanel(tester);
    await tapKey(tester, '5');
    await tapKey(tester, '+');
    await tapKey(tester, '3');
    final deleteKey = find.byKey(const ValueKey('amount_delete_key'));
    await tester.longPress(deleteKey);
    await tester.pump();

    expect(barOf(tester).amountStr, '0');
    expect(barOf(tester).op, isNull);
    expect(barOf(tester).calcState, 'waiting');
  });

  testWidgets('按键滑出取消：回滚最近一次即时提交', (tester) async {
    await pumpPanel(tester);
    await tapKey(tester, '5');
    expect(barOf(tester).amountStr, '5');

    // 按住数字 3（onDown 追加）后取消手势 → 回滚到 5。
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('3')),
    );
    await tester.pump();
    expect(barOf(tester).amountStr, '53');
    await gesture.cancel();
    await tester.pump();
    expect(barOf(tester).amountStr, '5');
  });

  testWidgets('完成键禁用：未选分类时点完成不触发提交', (tester) async {
    var submitted = false;
    await pumpPanel(
      tester,
      categorySelected: false,
      onSubmit: (t, c, r) => submitted = true,
    );
    await tapKey(tester, '1');
    await tester.tap(find.byIcon(AppIcons.keyboardReturn), warnIfMissed: false);
    await tester.pump();
    expect(submitted, isFalse);
  });

  testWidgets('完成键提交：金额/币种/汇率透传', (tester) async {
    double? total;
    String? currency;
    double? rate;
    await pumpPanel(
      tester,
      onSubmit: (t, c, r) {
        total = t;
        currency = c;
        rate = r;
      },
    );
    await tapKey(tester, '1');
    await tapKey(tester, '0');
    await tapKey(tester, '0');
    await tester.tap(find.byIcon(AppIcons.keyboardReturn));
    await tester.pump();
    expect(total, 100);
    expect(currency, 'CNY');
    expect(rate, isNull);
  });

  testWidgets('operating 态完成键：等号计算而非提交', (tester) async {
    var submitted = false;
    await pumpPanel(tester, onSubmit: (t, c, r) => submitted = true);
    await tapKey(tester, '5');
    await tapKey(tester, '+');
    await tapKey(tester, '3');

    // operating 态完成键显示 =，点击触发等号计算。
    await tapKey(tester, '=');
    expect(barOf(tester).calcState, 'calculated');
    expect(barOf(tester).amountStr, '8');
    expect(submitted, isFalse);
  });

  testWidgets('币种选择：打开 sheet 选择 USD 后切换交易币种并显示折算',
      (tester) async {
    await pumpPanel(
      tester,
      rates: const {'USD': EffectiveRate(rate: '7.2', manual: false)},
      pickerRates: const {'USD': 7.2},
    );

    await tester.tap(find.byKey(const ValueKey('amount_currency_chip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // sheet 中选中 USD 行（行文本含 "美元 (USD)"）。
    await tester.tap(find.textContaining('美元'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(barOf(tester).txCurrency, 'USD');
    expect(barOf(tester).conversionPreview, isNotNull);
  });

  testWidgets('汇率缺失：显示提示，手填后提交携带手动汇率', (tester) async {
    double? rate;
    await pumpPanel(
      tester,
      onSubmit: (t, c, r) => rate = r,
    );

    // 初始本位币 CNY 无汇率缺失提示。
    expect(barOf(tester).rateMissing, isFalse);

    // 打开币种选择，选 USD（无汇率）→ 提示缺失。
    await tester.tap(find.byKey(const ValueKey('amount_currency_chip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.textContaining('美元'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(barOf(tester).rateMissing, isTrue);

    // 自动拉汇率失败后仍保持缺失态（fake service 抛错）。
    await tester.pump(const Duration(milliseconds: 200));
    expect(barOf(tester).rateMissing, isTrue);

    // 点击提示打开手填对话框。
    await tester.tap(find.text('请手动填写本笔汇率后保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), '7.25');
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(barOf(tester).rateMissing, isFalse);
    await tapKey(tester, '1');
    await tester.tap(find.byIcon(AppIcons.keyboardReturn));
    await tester.pump();
    expect(rate, 7.25);
  });

  testWidgets('汇率对话框取消：不修改汇率', (tester) async {
    double? rate;
    await pumpPanel(
      tester,
      onSubmit: (t, c, r) => rate = r,
    );

    // 选 USD（无汇率）→ 提示缺失 → 打开对话框。
    await tester.tap(find.byKey(const ValueKey('amount_currency_chip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.textContaining('美元'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('请手动填写本笔汇率后保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // 取消后仍缺失汇率。
    expect(barOf(tester).rateMissing, isTrue);
    await tapKey(tester, '1');
    await tester.tap(find.byIcon(AppIcons.keyboardReturn));
    await tester.pump();
    expect(rate, isNull);
  });

  testWidgets('日期键触发 onPickDate', (tester) async {
    var picked = false;
    await pumpPanel(tester, onPickDate: () => picked = true);

    await tester.tap(find.text('2026/8/8'));
    await tester.pump();
    expect(picked, isTrue);
  });
}
