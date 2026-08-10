import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/providers/providers.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'amount_expression_bar.dart';
import 'amount_keypad.dart';
import 'currency_picker_sheet.dart';
import 'keypad_constants.dart';

/// 记账编辑器的金额输入面板：金额/运算状态 + 币种/汇率 + 金额栏 + 键盘。
///
/// 设计意图：
/// - 金额输入状态（_amountStr/_acc/_op/_calcState）与币种汇率状态全部下沉到本组件，
///   每次按键只重建本面板，不带动 Header/分类网格/备注行整树重建；
/// - 按键在按下瞬间提交（PressKey），滑出取消时通过 [_rollbackLast] 回滚最近一次提交；
/// - 反馈单一来源：触觉反馈由本面板状态变更统一触发，组件层不重复触发；
/// - "完成"提交仍由键盘松手触发（防误触），由父 sheet 的 [onSubmit] 处理落库。
class AmountInputPanel extends ConsumerStatefulWidget {
  const AmountInputPanel({
    super.key,
    required this.initialAmount,
    required this.initialCurrencyCode,
    required this.initialNativeAmount,
    required this.date,
    required this.categorySelected,
    required this.onPickDate,
    required this.onSubmit,
  });

  /// 编辑模式回填初值；新建为 null。
  final double? initialAmount;
  final String? initialCurrencyCode;
  final double? initialNativeAmount;

  /// 当前交易日期（日期键显示；变更由父 sheet 驱动）。
  final DateTime date;

  /// 是否已选分类（完成键可用性的一部分）。
  final bool categorySelected;

  /// 打开日期滚轮（父 sheet 负责收起键盘与回写日期）。
  final VoidCallback onPickDate;

  /// 提交回调：金额总额（可能含未按 = 的运算）、交易币种、本笔汇率（可为 null）。
  final void Function(double total, String txCurrency, double? rate) onSubmit;

  @override
  ConsumerState<AmountInputPanel> createState() => _AmountInputPanelState();
}

/// 计算器状态机
enum _CalcState { waiting, operating, calculated }

/// 触觉反馈类型（唯一触发点）
enum _Haptic { selection, light, medium }

class _AmountInputPanelState extends ConsumerState<AmountInputPanel> {
  // —— 金额运算状态 ——
  late String _amountStr;
  double _acc = 0; // 运算累加值
  String? _op; // 当前运算符；null = waiting/calculated
  _CalcState _calcState = _CalcState.waiting;

  // —— 多币种 ——
  String? _pickedCurrency; // 手选币种；null = 本位币
  String? _rateStr; // 本笔汇率（字符串）；编辑模式初值隐含汇率，可改
  bool _rateManuallySet = false; // 手改/隐含汇率后不被有效汇率覆盖
  bool _fetchingRate = false; // 正在自动拉取汇率
  String? _rateFetchAttemptedFor; // 已自动拉过的币种（防循环重试）

  /// 最近一次即时提交的撤销闭包（按键滑出取消时回滚）。
  VoidCallback? _lastUndo;

  @override
  void initState() {
    super.initState();
    _pickedCurrency = widget.initialCurrencyCode?.toUpperCase();

    // 编辑外币交易：汇率行初值 = 该笔隐含汇率（nativeAmount / amount），
    // 只改备注/分类时折算基准不漂移。
    final initAmount = widget.initialAmount ?? 0;
    final initNative = widget.initialNativeAmount;
    if (initNative != null && initAmount > 0 && initNative != initAmount) {
      _rateStr = (initNative / initAmount).toStringAsPrecision(6);
      _rateManuallySet = true;
    }

    // 保留原始小数（最多两位），避免编辑已有记录时小数被截断为整数
    final s = initAmount.toStringAsFixed(2);
    final trimmed = s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
    _amountStr = trimmed.isEmpty ? '0' : trimmed;
  }

  // —— 状态快照与撤销 ——

  ({String amountStr, double acc, String? op, _CalcState calcState})
  _snapshot() =>
      (amountStr: _amountStr, acc: _acc, op: _op, calcState: _calcState);

  bool _sameSnap(
    ({String amountStr, double acc, String? op, _CalcState calcState}) a,
    ({String amountStr, double acc, String? op, _CalcState calcState}) b,
  ) =>
      a.amountStr == b.amountStr &&
      a.acc == b.acc &&
      a.op == b.op &&
      a.calcState == b.calcState;

  void _fireHaptic(_Haptic haptic) {
    switch (haptic) {
      case _Haptic.selection:
        HapticFeedback.selectionClick();
      case _Haptic.light:
        HapticFeedback.lightImpact();
      case _Haptic.medium:
        HapticFeedback.mediumImpact();
    }
  }

  /// 统一提交入口：有实际变化才重建并触发触觉反馈，同时记录可回滚的撤销闭包。
  void _commit(VoidCallback mutate, {_Haptic haptic = _Haptic.selection}) {
    final before = _snapshot();
    mutate();
    final after = _snapshot();
    if (_sameSnap(before, after)) return;
    _fireHaptic(haptic);
    setState(() {});
    _lastUndo = () {
      if (!mounted) return;
      if (_sameSnap(_snapshot(), after)) {
        _amountStr = before.amountStr;
        _acc = before.acc;
        _op = before.op;
        _calcState = before.calcState;
        setState(() {});
      }
    };
  }

  /// 撤销最近一次即时提交（仅当状态未被后续输入覆盖时生效）。
  void _rollbackLast() {
    final undo = _lastUndo;
    _lastUndo = null;
    undo?.call();
  }

  // —— 金额运算逻辑（三态状态机）——

  void _append(String s) {
    _commit(() {
      // calculated 状态下输入新数字 → 进入 waiting（新金额）
      if (_calcState == _CalcState.calculated) {
        _acc = 0;
        _op = null;
        _amountStr = '0';
        _calcState = _CalcState.waiting;
      }
      if (s == '.') {
        if (_amountStr.contains('.')) return;
      }
      // 限制两位小数
      if (_amountStr.contains('.')) {
        final dot = _amountStr.indexOf('.');
        final decimals = _amountStr.length - dot - 1;
        if (s != '.' && decimals >= 2) return;
      }
      // 去除前导 0
      if (_amountStr == '0' && s != '.') {
        _amountStr = s;
      } else if (_amountStr == '-0' && s != '.') {
        _amountStr = '-$s';
      } else {
        _amountStr += s;
      }
    });
  }

  void _backspace() {
    _commit(() {
      // calculated 状态下退格 → 进入 waiting（基于结果继续编辑）
      if (_calcState == _CalcState.calculated) {
        _calcState = _CalcState.waiting;
      }
      if (_amountStr.isEmpty) return;
      _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      if (_amountStr.isEmpty) _amountStr = '0';
    });
  }

  /// 一键清空金额与运算状态（删除键长按触发）。
  void _clearAmount() {
    _commit(() {
      _amountStr = '0';
      _acc = 0;
      _op = null;
      _calcState = _CalcState.waiting;
    }, haptic: _Haptic.medium);
  }

  /// 应用运算符（waiting/calculated → operating）。
  /// 4 个独立运算符键：× ÷ − +；连续输入运算符时新符号替换旧符号。
  void _applyOp(String op) {
    final cur = _parsedAmount();
    _commit(() {
      if (_op == null) {
        // 首次点击运算符：将当前值存入累加器
        _acc = cur;
      } else {
        // 左到右：先把上一个运算符算掉
        _acc = _compute(_acc, _op!, cur);
      }
      _op = op;
      _amountStr = '0';
      _calcState = _CalcState.operating;
    });
  }

  /// 应用等号（operating → calculated）。
  void _applyEquals() {
    if (_op == null) return; // 没有运算符，不执行
    final cur = _parsedAmount();
    final total = _compute(_acc, _op!, cur);
    final s = total.abs().toStringAsFixed(2);
    final trimmed = s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
    _commit(() {
      _amountStr = trimmed.isEmpty ? '0' : trimmed;
      _acc = 0;
      _op = null;
      _calcState = _CalcState.calculated;
    }, haptic: _Haptic.light);
  }

  double _parsedAmount() => double.tryParse(_amountStr) ?? 0.0;

  /// 当前总额（运算模式 = acc op amountStr，否则 = amountStr）
  double get _currentTotal =>
      _op == null ? _parsedAmount() : _compute(_acc, _op!, _parsedAmount());

  /// 用 Decimal 精确运算（避免浮点漂移如 0.1+0.2），左到右无运算符优先级；
  /// 除零保护；结果四舍五入到最多两位小数（金额精度）。
  double _compute(double a, String op, double b) {
    final da = Decimal.parse(a.toStringAsFixed(2));
    final db = Decimal.parse(b.toStringAsFixed(2));
    final Decimal r;
    switch (op) {
      case '+':
        r = da + db;
        break;
      case '-':
        r = da - db;
        break;
      case '×':
        r = da * db;
        break;
      case '÷':
        if (db == Decimal.zero) return a; // 除零保护：保持被除数不变
        r = (da.toRational() / db.toRational()).toDecimal(
          scaleOnInfinitePrecision: 12,
        );
        break;
      default:
        return b;
    }
    return r.round(scale: 2).toDouble();
  }

  /// 运算符显示字形（减号用真减号 −，而非连字符 -）。
  String _opGlyph(String op) {
    switch (op) {
      case '-':
        return '−';
      case '×':
        return '×';
      case '÷':
        return '÷';
      default:
        return '+';
    }
  }

  /// 状态机字符串表示（传给子组件）
  String get _calcStateStr {
    switch (_calcState) {
      case _CalcState.waiting:
        return 'waiting';
      case _CalcState.operating:
        return 'operating';
      case _CalcState.calculated:
        return 'calculated';
    }
  }

  // —— 多币种逻辑 ——

  /// 交易币种（币种优先联动）：手选币种优先，否则账本本位币。
  String get _txCurrency =>
      _pickedCurrency ?? ref.read(currentLedgerCurrencyProvider);

  /// 本笔汇率：手改/隐含 > 有效汇率（effectiveRatesForLedgerProvider）。
  double? _currentRate() {
    if (_rateManuallySet) return double.tryParse(_rateStr ?? '');
    final rates = ref.read(effectiveRatesForLedgerProvider).value;
    final er = rates?[_txCurrency];
    return er == null ? null : double.tryParse(er.rate);
  }

  /// 外币且本地无该币种汇率时，自动拉一次。同一币种只自动试一次，
  /// 失败后由用户手填（汇率缺失阻塞仍兜底）。
  void _maybeAutoFetchRate() {
    final base = ref.read(currentLedgerCurrencyProvider);
    final txCurrency = _txCurrency;
    if (txCurrency == base || _rateManuallySet || _fetchingRate) return;
    if (_rateFetchAttemptedFor == txCurrency) return;
    final ratesAsync = ref.read(effectiveRatesForLedgerProvider);
    final rates = ratesAsync.value;
    if (rates == null) return; // provider 尚未解析，等它先出结果
    if (rates.containsKey(txCurrency)) return; // 已有汇率
    _rateFetchAttemptedFor = txCurrency;
    setState(() => _fetchingRate = true);
    refreshExchangeRatesFromUi(
      ref,
      force: true,
      extraQuotes: {txCurrency},
    ).whenComplete(() {
      if (mounted) setState(() => _fetchingRate = false);
    });
  }

  Future<void> _pickCurrency() async {
    final l10n = AppLocalizations.of(context);
    final base = ref.read(currentLedgerCurrencyProvider);
    final picked = await showCurrencyPickerSheet(
      context,
      selected: _pickedCurrency ?? base,
      primaryColor: Theme.of(context).colorScheme.primary,
      title: l10n.txCurrencyPickerTitle,
      rateBase: base,
      // 挂 sheet 在当前 navigator 上，只 pop 回本 sheet；不显示遮罩
      useRootNavigator: false,
      barrierColor: Colors.transparent,
      // 记账页内调用，符号化显示汇率
      showRateAsBaseLabel: true,
      // 仅显示用户勾选的可见币种；账本本位币(rateBase)与已选币种
      // 由 sheet 内部强制保留，保证折算目标与当前值始终可见
      visibleCurrencies: ref.read(visibleCurrenciesProvider),
    );
    if (picked == null || !mounted) return;
    _lastUndo = null;
    setState(() {
      _pickedCurrency = picked.toUpperCase() == base
          ? null
          : picked.toUpperCase();
      // 换币种后隐含/手改汇率作废，重新带有效汇率
      _rateStr = null;
      _rateManuallySet = false;
    });
  }

  Future<void> _editRate() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(
      text: _rateStr ?? _currentRate()?.toStringAsPrecision(6) ?? '',
    );
    final entered = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.txRateLabel),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText:
                '1 $_txCurrency = ? ${ref.read(currentLedgerCurrencyProvider)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(AppLocalizations.of(dctx).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
            child: Text(AppLocalizations.of(dctx).commonConfirm),
          ),
        ],
      ),
    );
    if (entered == null || !mounted) return;
    final v = double.tryParse(entered);
    if (v == null || v <= 0) return;
    _lastUndo = null;
    setState(() {
      _rateStr = entered;
      _rateManuallySet = true;
    });
  }

  /// 折算预览文本（如 "≈ 86.40 CNY"）；null 表示本位币或无汇率。
  String? _conversionPreview() {
    final ledgerBase = ref.read(currentLedgerCurrencyProvider);
    final txCurrency = _txCurrency;
    if (txCurrency == ledgerBase) return null;
    final rate = _currentRate();
    if (rate == null || rate <= 0) return null;
    final preview = _parsedAmount() * rate;
    return '≈ ${preview.toStringAsFixed(2)} $ledgerBase';
  }

  void _handleSubmit() {
    widget.onSubmit(_currentTotal, _txCurrency, _currentRate());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = ref.watch(currentLedgerCurrencyProvider);
    ref.watch(effectiveRatesForLedgerProvider);
    final txCurrency = _txCurrency;
    final isForeign = txCurrency != base;
    final rate = _currentRate();
    // 外币无汇率时自动拉一次（post-frame 防 build 中副作用）
    if (isForeign && rate == null && !_fetchingRate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeAutoFetchRate();
      });
    }

    final isInCalcMode = _calcState == _CalcState.operating;
    // 完成键可用性：operating 始终可用；waiting/calculated = 金额>0 且分类已选。
    // 提交期间不改变按钮外观（本地落库仅数毫秒，loading/置灰会一闪而过），
    // 重复点击由父 sheet 的 _onSubmit 内 _isSubmitting 守卫拦截。
    final doneEnabled =
        (isInCalcMode || _currentTotal.abs() > 0) &&
        widget.categorySelected;

    // 行高由父 sheet 的键盘容器按剩余空间均分后以 SizedBox 提供，
    // 本面板内部：金额栏 = 单行高 h，键盘 = 4h + 3 个行距。
    return LayoutBuilder(
      builder: (ctx, c) {
        // 面板 = 金额栏(1 行) + 键盘(4 行)，含 4 个行距
        // （金额栏↔键盘 1 个 + 键盘内部 3 个）
        final h = (c.maxHeight - 4 * KeypadLayout.rowGap) / 5;
        return Column(
          children: [
            SizedBox(
              height: h,
              child: AmountExpressionBar(
                txCurrency: txCurrency,
                ledgerBase: base,
                amountStr: _amountStr,
                acc: _acc,
                op: _op,
                opGlyph: _opGlyph,
                equalsTotal: _currentTotal,
                calcState: _calcStateStr,
                conversionPreview: _conversionPreview(),
                rateFetching: _fetchingRate,
                rateMissing: rate == null && !_fetchingRate && isForeign,
                rateMissingHint: l10n.txRateMissingHint,
                onPickCurrency: _pickCurrency,
                onEditRate: _editRate,
                onClearAmount: _clearAmount,
                onDeleteOne: _backspace,
                onRollback: _rollbackLast,
              ),
            ),
            const SizedBox(height: KeypadLayout.rowGap),
            Expanded(
              child: AmountKeypad(
                date: widget.date,
                showTime: true, // 5 列滚轮始终含时分
                calcState: _calcStateStr,
                op: _op,
                isDoneEnabled: doneEnabled,
                opGlyph: _opGlyph,
                onAppend: _append,
                onApplyOp: _applyOp,
                onApplyEquals: _applyEquals,
                onPickDate: widget.onPickDate,
                onSubmit: _handleSubmit,
                onRollback: _rollbackLast,
              ),
            ),
          ],
        );
      },
    );
  }
}
