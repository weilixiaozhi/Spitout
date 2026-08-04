import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudLedgerMember;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/providers/core/post_processor.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import '../routes.dart';
import '../services/statistics/aa_edit_models.dart';
import '../services/statistics/aa_statistics_service.dart' show AaMode;
import '../theme/colors.dart';
import '../utils/category_utils.dart';
import 'app_route.dart';
import 'currency_picker_sheet.dart';
import 'toast.dart';
import 'wheel_date_picker.dart';
import 'overlay_keyboard_guard.dart';
import 'amount_expression_bar.dart';
import 'amount_keypad.dart';
import 'category_grid_section.dart';
import 'keypad_layout.dart';
import 'note_input_row.dart';
import 'collaborator_avatar.dart';
import '../theme/icons/app_icons.dart';

/// 记账编辑 BottomSheet（单页：分类 + 金额 + 备注 + 键盘同页）。
///
/// 布局（自上而下）：
/// 1. 拖拽条
/// 2. Header：返回按钮 + 「记一笔」标题 + 作者头像
/// 3. 分类网格区（独立滚动、无可见滚动条）
/// 4. 底部固定区：备注行 + 金额栏行 + 4×4 键盘
///
/// 计算器状态机：waiting / operating / calculated
/// - waiting：初始或清空后，金额区显示实际金额（空值显示 0），主按钮显示 Enter
/// - operating：用户点了运算符，金额区显示「累加值 运算符 当前输入 = 预览」，主按钮显示 =
/// - calculated：用户点了 = 后，金额区仅显示最终结果，主按钮显示 Enter
///
/// 系统键盘拉起时（备注聚焦）：整页（分类区 + 自定义键盘）保持可见并整体上移，
/// 仅把备注行 / 币种行顶到系统键盘之上，不收起分类区。
/// 点击非备注区域优先收起系统键盘；返回键仅收起键盘、保留记账页。
class TransactionEditorSheet extends ConsumerStatefulWidget {
  /// 值固定为 'expense'（全局仅支出模式）
  final String initialKind;

  /// 编辑模式交易 ID；null = 新建
  final int? editingTransactionId;

  /// 初始选中分类 ID（编辑模式回显 / 预选）
  final int? initialCategoryId;

  final double? initialAmount;
  final DateTime? initialDate;
  final String? initialNote;
  final String? initialCurrencyCode;
  final double? initialNativeAmount;

  /// AA 分摊方式初值(数据库列值:null/0=人均,2=指定);仅编辑模式回填。
  final int? initialAaMode;

  /// AA 参与人初值;null = 全部成员(运行时展开)。
  final List<String>? initialAaParticipants;

  /// AA 指定分摊金额初值(key=参与人标识,value=金额字符串)。
  final Map<String, String>? initialAaSplits;

  /// 支出人初值;编辑模式回填,新建为 null。
  ///
  /// 设计意图:编辑器本身不提供支出人编辑,该值仅作为分摊编辑页
  /// (AaEditPage)的支出人回显初值,保证编辑分摊时已保存的支出人不被
  /// 误判为「默认创建人」。编辑器提交时支出人字段一律不直接写入。
  final String? initialPaidByUserId;

  const TransactionEditorSheet({
    super.key,
    required this.initialKind,
    this.editingTransactionId,
    this.initialCategoryId,
    this.initialAmount,
    this.initialDate,
    this.initialNote,
    this.initialCurrencyCode,
    this.initialNativeAmount,
    this.initialAaMode,
    this.initialAaParticipants,
    this.initialAaSplits,
    this.initialPaidByUserId,
  });

  @override
  ConsumerState<TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

/// 计算器状态机
enum _CalcState { waiting, operating, calculated }

class _TransactionEditorSheetState
    extends ConsumerState<TransactionEditorSheet> {
  // —— 金额运算状态 ——
  late String _amountStr;
  double _acc = 0; // 运算累加值
  String? _op; // 当前运算符；null = waiting/calculated
  _CalcState _calcState = _CalcState.waiting;

  // —— 日期 / 备注 ——
  late DateTime _date;
  final TextEditingController _noteCtrl = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  // —— 多币种 ——
  String? _pickedCurrency; // 手选币种；null = 本位币
  String? _rateStr; // 本笔汇率（字符串）；编辑模式初值=隐含汇率，可改
  bool _rateManuallySet = false; // 手改/隐含汇率后不被有效汇率覆盖
  bool _fetchingRate = false; // 正在自动拉取汇率
  String? _rateFetchAttemptedFor; // 已自动拉过的币种（防循环重试）

  // —— 分类 / 备注 / 提交 ——
  Category? _selectedCategory;
  bool _isSubmitting = false;
  late final int _ledgerId;

  // —— AA 分摊(仅账本开启 AA 时展示并落库) ——
  late AaMode _aaMode; // 分摊方式;默认人均(不分摊不在编辑器提供入口)
  List<String>? _aaParticipantIds; // null = 全部成员(运行时展开)
  Map<String, String>? _aaSplits; // 指定分摊金额(编辑模式回填/AaEditPage 回传)

  /// 本次提交是否跳转过 AaEditPage。
  ///
  /// 设计意图:AaEditPage 是在编辑器 sheet 之上 push 的全屏页,保存时
  /// AaEditPage 先 pop(200ms 退出动画),编辑器随后 pop 收起 sheet。
  /// 若两者几乎同时 pop,退出动画会重叠(sheet 与页面同时滑出,视觉混乱)。
  /// 标记跳转过 AA 页后,在收起 sheet 前 await 一个转场时长,
  /// 让 AA 页退出动画先完成,再收起 sheet,实现「先后收起」。
  bool _aaPagePushed = false;

  @override
  void initState() {
    super.initState();
    _ledgerId = ref.read(currentLedgerIdProvider);
    _date = widget.initialDate ?? DateTime.now();
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
    _noteCtrl.text = widget.initialNote ?? '';

    // AA 初值回填:编辑器支持人均/不分摊/指定三态循环切换,
    // 不分摊交易原样回显为「不分摊」。
    _aaMode = AaMode.fromDb(widget.initialAaMode);
    _aaParticipantIds = widget.initialAaParticipants;
    _aaSplits = widget.initialAaSplits;

    _noteFocusNode.addListener(() {
      // 备注聚焦变化时触发重建，让分类区/键盘区在系统键盘拉起时正确让位
      // （MediaQuery.viewInsets.bottom 也会触发重建，此处保留以确保即时响应）
      setState(() {});
    });

    // 解析初始分类（编辑模式 / 预选）：含共享账本 synthetic id 反查
    _resolveInitialCategory();
  }

  @override
  void dispose() {
    _noteFocusNode.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// 解析初始分类 ID 对应的 Category（含共享账本 synthetic 反查），
  /// 设置 _selectedCategory 以便提交时直接拿到分类。
  Future<void> _resolveInitialCategory() async {
    if (widget.initialCategoryId == null) return;
    final repo = ref.read(repositoryProvider);
    final id = widget.initialCategoryId!;
    // 共享账本:synthetic id(< 0)走 SharedLedger* 表反查,正数 id 查主表
    // —— 接口方法内部已统一分派,UI 无需 is 判断下探 LocalRepository.db。
    final c = await repo.findCategoryBySyntheticId(id);
    if (c != null && mounted) {
      setState(() => _selectedCategory = c);
    }
  }

  // —— 多币种逻辑 ——

  /// 交易币种（币种优先联动）：手选币种优先，否则账本本位币。
  String _txCurrency() {
    return _pickedCurrency ?? ref.read(currentLedgerCurrencyProvider);
  }

  /// 本笔汇率：手改/隐含 > 有效汇率（effectiveRatesForLedgerProvider）。
  double? _currentRate() {
    if (_rateManuallySet) return double.tryParse(_rateStr ?? '');
    final rates = ref.read(effectiveRatesForLedgerProvider).valueOrNull;
    final er = rates?[_txCurrency()];
    return er == null ? null : double.tryParse(er.rate);
  }

  /// 外币且本地无该币种汇率时，自动拉一次。同一币种只自动试一次，
  /// 失败后由用户手填（汇率缺失阻断仍兜底）。
  void _maybeAutoFetchRate() {
    final base = ref.read(currentLedgerCurrencyProvider);
    final txCurrency = _txCurrency();
    if (txCurrency == base || _rateManuallySet || _fetchingRate) return;
    if (_rateFetchAttemptedFor == txCurrency) return;
    final ratesAsync = ref.read(effectiveRatesForLedgerProvider);
    final rates = ratesAsync.valueOrNull;
    if (rates == null) return; // provider 尚未解析，等它先出结果
    if (rates.containsKey(txCurrency)) return; // 已有汇率
    _rateFetchAttemptedFor = txCurrency;
    setState(() => _fetchingRate = true);
    refreshExchangeRatesFromUi(ref, force: true, extraQuotes: {txCurrency})
        .whenComplete(() {
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
      // 子 sheet 挂在当前 navigator 上，可 pop 回本 sheet；不显示遮罩
      useRootNavigator: false,
      barrierColor: Colors.transparent,
      // 记账页内调用，符号化展示汇率
      showRateAsBaseLabel: true,
      // 仅展示用户勾选的可见币种;账本本位币(rateBase)与已选币种
      // 由 sheet 内部强制保留,保证折算目标与当前值始终可见
      visibleCurrencies: ref.read(visibleCurrenciesProvider),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedCurrency =
          picked.toUpperCase() == base ? null : picked.toUpperCase();
      // 换币种后隐含/手改汇率作废，重新带有效汇率
      _rateStr = null;
      _rateManuallySet = false;
    });
  }

  Future<void> _editRate() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(
        text: _rateStr ?? _currentRate()?.toStringAsPrecision(6) ?? '');
    final entered = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.txRateLabel),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText:
                '1 ${_txCurrency()} = ? ${ref.read(currentLedgerCurrencyProvider)}',
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
    setState(() {
      _rateStr = entered;
      _rateManuallySet = true;
    });
  }

  // —— 金额运算逻辑（三态状态机） ——

  void _append(String s) {
    setState(() {
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
    SystemSound.play(SystemSoundType.click);
  }

  void _backspace() {
    setState(() {
      // calculated 状态下退格 → 进入 waiting（基于结果继续编辑）
      if (_calcState == _CalcState.calculated) {
        _calcState = _CalcState.waiting;
      }
      if (_amountStr.isEmpty) return;
      _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      if (_amountStr.isEmpty) _amountStr = '0';
    });
    SystemSound.play(SystemSoundType.click);
  }

  /// 一键清空金额与运算状态（删除键长按 560ms 触发）
  void _clearAmount() {
    setState(() {
      _amountStr = '0';
      _acc = 0;
      _op = null;
      _calcState = _CalcState.waiting;
    });
    SystemSound.play(SystemSoundType.click);
  }

  /// 用 Decimal 精确运算（避免浮点漂移如 0.1+0.2），左到右无运算符优先级，
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
        r = (da.toRational() / db.toRational())
            .toDecimal(scaleOnInfinitePrecision: 12);
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

  /// 应用运算符（waiting/calculated → operating）。
  /// 4 个独立运算符键 × ÷ − +，连续输入运算符时新符号替换旧符号。
  void _applyOp(String op) {
    final cur = _parsedAmount();
    setState(() {
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
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
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
    setState(() {
      _amountStr = trimmed.isEmpty ? '0' : trimmed;
      _acc = 0;
      _op = null;
      _calcState = _CalcState.calculated;
    });
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  double _parsedAmount() => double.tryParse(_amountStr) ?? 0.0;

  /// 当前总额（运算模式 = acc op amountStr，否则 = amountStr）
  double get _currentTotal =>
      _op == null ? _parsedAmount() : _compute(_acc, _op!, _parsedAmount());

  // —— 日期 ——

  /// 5 列滚轮同屏（年/月/日/时/分），始终显示完整时间。
  void _pickDate() async {
    // 收起键盘并等待动画结束，避免选择日期后键盘重新弹出（统一走 OverlayKeyboardGuard）。
    await prepareForOverlay();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final res = await showWheelDatePicker(
      context,
      initial: _date,
      mode: WheelDatePickerMode.datetime,
      // 组件默认边界 2000~2100，已可选任意未来时间，无需再显式传 maxDate。
      useRootNavigator: false,
      barrierColor: Colors.transparent,
      title: l10n.txSelectDateTimeTitle,
      subtitle: l10n.txSelectDateTimeHint,
      confirmLabel: l10n.commonFinish,
    );
    if (res != null) setState(() => _date = res);
  }

  // —— AA 分摊 ——

  /// 单点循环切换分摊方式:人均 → 不分摊 → 指定 → 人均。
  ///
  /// 设计意图:人均分摊是最高频场景,作为循环起点;不分摊次之;
  /// 指定分摊最重(需逐人填金额),故放最后。切换仅改本地状态,
  /// 落库(含指定分摊跳 [AaEditPage] 确认金额)统一在提交时处理。
  void _cycleAaMode() {
    setState(() {
      _aaMode = switch (_aaMode) {
        AaMode.perPerson => AaMode.noSplit,
        AaMode.noSplit => AaMode.custom,
        AaMode.custom => AaMode.perPerson,
      };
    });
  }

  /// 组装落库字段(AA 分摊 + 支出人)。
  ///
  /// 返回 null 表示用户取消(指定分摊跳 [AaEditPage] 后放弃)——
  /// 编辑器保持开启、内容保留、不落库。
  ///
  /// 支出人语义:编辑器不提供支出人编辑,paidByUserId 仅透传分摊编辑页
  /// 的结果——人均/指定分摊时由 [AaEditPage] 决定(未手选返回 null,新建
  /// 由落库层 markTxAuthor 回填操作者,编辑不更新保持原值);未开启 AA
  /// 或不分摊时不写入(update 语义下 null = 不更新)。
  ///
  /// 清空语义:updateTransaction 的 aa* 参数 null = 不更新,故编辑模式下
  /// 「指定 → 人均」「部分参与人 → 全部成员」需显式传空串清空旧值。
  Future<({int? aaMode, String? aaParticipants, String? aaSplits, String? paidByUserId})?>
      _resolveAaFields(double total, String txCurrency, Category c) async {
    final aaEnabled =
        ref.read(currentLedgerProvider).valueOrNull?.aaEnabled ?? false;
    // 未开启 AA 的账本:aa* 与 paidByUserId 恒 null。update 语义下 null =
    // 不更新,开关关闭后编辑历史交易不会清掉旧分摊/支出人数据,重开仍在。
    if (!aaEnabled) {
      return (
        aaMode: null,
        aaParticipants: null,
        aaSplits: null,
        paidByUserId: null,
      );
    }

    final isEditing = widget.editingTransactionId != null;

    // 人均/指定分摊:提交时统一跳 AaEditPage 配置——人均可改参与人/支出人,
    // 指定再逐人填金额;跳页前不落库,AaEditPage 是纯选择器,pop 返回 result。
    if (_aaMode == AaMode.perPerson || _aaMode == AaMode.custom) {
      _aaPagePushed = true;
      final result = await Navigator.of(context).pushNamed(
        Routes.aaEdit,
        arguments: AaEditPageArgs(
          ledgerId: _ledgerId,
          amount: total,
          currencyCode: txCurrency,
          categoryName: CategoryUtils.getDisplayName(c.name, context),
          categoryIconName: c.icon,
          date: _date,
          mode: _aaMode,
          // 支出人初值仅作分摊编辑页回显(编辑模式回填已保存值);编辑器本身
          // 不维护支出人状态,最终是否写入由 AaEditPage 的结果决定。
          paidByUserId: widget.initialPaidByUserId,
          participantIds: _aaParticipantIds,
          splits: _aaSplits,
        ),
      ) as AaEditResult?;
      if (result == null || !mounted) return null; // 取消:不落库
      // 回传值同步到本地状态,编辑器再次打开时现场与已确认的分摊一致。
      _aaMode = result.aaMode == 2 ? AaMode.custom : AaMode.perPerson;
      _aaParticipantIds = result.aaParticipants;
      _aaSplits = result.aaSplits;
      return (
        aaMode: result.aaMode,
        aaParticipants:
            result.aaParticipants == null ? null : jsonEncode(result.aaParticipants),
        // 人均结果不带金额:编辑模式显式清空旧 aaSplits;新建写 null
        aaSplits: result.aaSplits != null
            ? jsonEncode(result.aaSplits)
            : (isEditing ? '' : null),
        // 支出人透传分摊编辑页结果:未手选回传 null,新建由落库层回填
        // 操作者(默认支出人 = 创建人),编辑不更新保持原值。
        paidByUserId: result.paidByUserId,
      );
    }

    // 不分摊:不参与分摊算法,列入「不计入清单」;无参与人/指定金额,
    // 编辑模式显式清空旧分摊数据。支出人字段不写入(update 语义下 null =
    // 不更新),不分摊交易的支出人由创建时落库层回填操作者决定。
    return (
      aaMode: 1,
      aaParticipants: isEditing ? '' : null,
      aaSplits: isEditing ? '' : null,
      paidByUserId: null,
    );
  }

  // —— 提交逻辑 ——

  Future<void> _onSubmit() async {
    final c = _selectedCategory;
    if (c == null) {
      // 未选分类：提示并阻断（分类由用户主动选择，不预先选定）
      showToast(context, AppLocalizations.of(context).categoryEmpty);
      return;
    }
    // 防重复点击
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final total = _currentTotal.abs(); // 始终正数

    // 折本位币快照。外币且汇率无效 → 阻断。
    final txCurrency = _txCurrency();
    final ledgerBase = ref.read(currentLedgerCurrencyProvider);
    double? nativeAmount;
    if (txCurrency == ledgerBase) {
      nativeAmount = total;
    } else {
      final r = _currentRate();
      if (r == null || r <= 0) {
        setState(() => _isSubmitting = false);
        showToast(context, AppLocalizations.of(context).txRateMissingHint);
        return;
      }
      nativeAmount = total * r;
    }

    // AA 分流:指定分摊先跳 AaEditPage 取 result 后一次性落库;
    // 取消则中止提交,编辑器保持开启、内容保留。
    final aa = await _resolveAaFields(total, txCurrency, c);
    if (aa == null) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    final repo = ref.read(repositoryProvider);
    // Category 是 synthetic（id<0）时，categoryId 留 null，override 走 syncId
    final isSyntheticCategory = c.id < 0;
    final categoryIdForWrite = isSyntheticCategory ? null : c.id;
    final categoryOverride = isSyntheticCategory ? c.syncId : null;

    int transactionId;
    if (widget.editingTransactionId != null) {
      // 编辑模式：更新交易
      // 无旗标功能：excludeFromStats 恒为 false
      final newVersion = await repo.updateTransaction(
        id: widget.editingTransactionId!,
        type: widget.initialKind,
        amount: total,
        categoryId: categoryIdForWrite,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        happenedAt: _date,
        categorySyncIdOverride: categoryOverride,
        excludeFromStats: false,
        currencyCode: txCurrency,
        nativeAmount: nativeAmount,
        paidByUserId: aa.paidByUserId,
        aaMode: aa.aaMode,
        aaParticipants: aa.aaParticipants,
        aaSplits: aa.aaSplits,
      );
      transactionId = widget.editingTransactionId!;
      // 共享账本：本地 lastEditedByUserId 立即回填（云实例读取收敛到 providers 动作函数）
      await markTxEditedFromUi(ref, transactionId);

      // 闭环：在编辑历史表追加一条同版本号快照，让详情页"编辑记录"区块
      // 有内容可展示。updateTransaction 已将 transactions.version +1，
      // 此处用同版本号写历史，使 transactions.version 与
      // record_edit_histories.version 一一对应，详情页"vN"标签才能
      // 正确指代本次编辑。
      // summary 作为不本地化的快照文本（与 note 字段同理），直接用
      // 分类名 + 金额 + 交易发生日期拼接；operatorUserId 在单人账本下为 null，
      // 详情页对应行将不显示操作者，符合预期。
      final operatorUserId = await currentOperatorUserIdFromUi(ref);
      final summary = '${c.name} · ${total.toStringAsFixed(2)} · '
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
          '${_date.day.toString().padLeft(2, '0')} '
          '${_date.hour.toString().padLeft(2, '0')}:'
          '${_date.minute.toString().padLeft(2, '0')}';
      await repo.appendEditHistory(
        recordId: transactionId,
        version: newVersion,
        operatorUserId: operatorUserId,
        summary: summary,
      );
      // 主动失效编辑历史缓存：若详情 sheet 仍在 widget tree 上，
      // 下次读取会重查，立即看到刚写入的历史行。
      ref.invalidate(recordEditHistoryProvider(transactionId));
    } else {
      transactionId = await repo.addTransaction(
        ledgerId: _ledgerId,
        type: widget.initialKind,
        amount: total,
        categoryId: categoryIdForWrite,
        happenedAt: _date,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        categorySyncIdOverride: categoryOverride,
        excludeFromStats: false,
        currencyCode: txCurrency,
        nativeAmount: nativeAmount,
        paidByUserId: aa.paidByUserId,
        aaMode: aa.aaMode,
        aaParticipants: aa.aaParticipants,
        aaSplits: aa.aaSplits,
      );
      // 共享账本：新建本地 tx 回填创建人 + 编辑人（同一个 user）;
      // paidByUserId 为空时回填操作者,已显式写入的值(指定分摊)不覆盖。
      await markTxCreatedFromUi(ref, transactionId);
    }

    // 统一处理：自动/手动同步与状态刷新（后台静默）
    PostProcessor.sync(ref, ledgerId: _ledgerId);
    // 刷新：账本笔数与全局统计
    ref.invalidate(countsForLedgerProvider(_ledgerId));
    ref.read(statsRefreshProvider.notifier).state++;

    // 提交成功后关闭编辑器 sheet。
    // 若本次提交跳转过 AaEditPage,需等 AA 页退出动画(一个转场时长)完成
    // 后再收起 sheet,避免 AA 页与 sheet 同时滑出的重叠动画。
    if (mounted && Navigator.of(context).canPop()) {
      if (_aaPagePushed) {
        await Future<void>.delayed(kAppTransitionDuration);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _onCategorySelected(Category c) {
    setState(() => _selectedCategory = c);
  }

  void _onNotePicked(String note) {
    setState(() {
      _noteCtrl.text = note;
      _noteCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: note.length));
    });
  }

  // —— 折算预览计算 ——

  /// 计算折算预览文本；返回 null 表示本位币。
  /// operating 状态不显示外币换算。
  String? _conversionPreview() {
    final ledgerBase = ref.read(currentLedgerCurrencyProvider);
    final txCurrency = _txCurrency();
    if (txCurrency == ledgerBase) return null;
    final rate = _currentRate();
    if (rate == null || rate <= 0) return null;
    final preview = _parsedAmount() * rate;
    return '≈ ${preview.toStringAsFixed(2)} $ledgerBase';
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final keyboardOpen = mq.viewInsets.bottom > 0;
    // —— 高度自适应 ——
    // 键盘行高 u 由 computeKeypadU 按可用高度算定：默认 48，
    // 空间不足时（系统键盘拉起、极小屏）压到 36 保底防溢出。
    // useSafeArea:true 时 route 不 removePadding，内部 padding.top 即真实
    // 状态栏高度（SafeArea 已自动把 sheet 顶到状态栏下面，这里仅用于可用
    // 高度预算，不再做任何头部空白补偿）。
    final topInset = mq.padding.top; // 状态栏（useSafeArea:true 下 route 内真实值）
    final bottomInset = mq.viewPadding.bottom; // 底部安全区（刘海/Home Indicator）
    final keyboardH = mq.viewInsets.bottom; // 系统键盘
    // 背景高度上限 = 全屏 − 系统键盘；实际受 route 约束（SafeArea 已扣顶部
    // 状态栏）限制，顶部正好顶到状态栏下面、底部铺到屏幕底。
    final available = mq.size.height - keyboardH;
    // 内容真实可用高度：全屏高度扣除状态栏、底部 Home Indicator 与键盘。
    final contentH = available - topInset - bottomInset;
    // sheet 背景高度上限 = available（全屏 − 键盘），铺满屏顶且不被键盘遮挡；
    // 真实高度由内容决定，仅作为 Container 上限封顶。
    final sheetMaxH = available;
    final keypadU = computeKeypadU(availableHeight: contentH);

    // 外币无汇率时自动拉一次（post-frame 防 build 中副作用）
    final ledgerBase = ref.watch(currentLedgerCurrencyProvider);
    ref.watch(effectiveRatesForLedgerProvider);
    final txCurrency = _txCurrency();
    final isForeign = txCurrency != ledgerBase;
    final rate = _currentRate();
    if (isForeign && rate == null && !_fetchingRate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeAutoFetchRate();
      });
    }

    final isInCalcMode = _calcState == _CalcState.operating;
    // 主按钮可用性：operating 状态 = 始终可用；waiting/calculated = 金额>0 且分类已选
    final doneEnabled = (isInCalcMode || _currentTotal.abs() > 0) &&
        _selectedCategory != null &&
        !_isSubmitting;

    // AA 区块仅账本开启 AA 时展示(功能隔离)
    final aaEnabled =
        ref.watch(currentLedgerProvider).valueOrNull?.aaEnabled ?? false;

    // 编辑模式 + 共享账本 → 展示作者头像（创建者/最后编辑者）
    final editingTxId = widget.editingTransactionId;

    return PopScope(
      // 系统键盘拉起时，Android 返回键只收起键盘、保留记账页，
      // 不直接关闭整个 BottomSheet（否则 sheet 缩成极小时点击空白会误关）。
      canPop: !keyboardOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && keyboardOpen) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Padding(
        // 系统键盘拉起时把整个 sheet 上推，确保备注 / 金额栏不被遮挡，
        // 同时整页（含分类区 / 自定义键盘）保持可见，不收起。
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
        constraints: BoxConstraints(maxHeight: sheetMaxH),
        decoration: BoxDecoration(
          color: SpitoutTokens.surfaceSheet(context),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Padding(
          // sheet 背景已由 SafeArea 顶到状态栏下面，顶部无需再内缩；
          // 仅底部内缩 Home Indicator 高度，最底排按键不被手势条压住。
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
          // 始终填满可用高度：分类区用 Expanded 占据剩余空间并独立滚动。
          // sheetMaxH = available（全屏 − 键盘）。键盘拉起时整页上移且不收起内容，
          // 满足「保留整个记账页、系统键盘不遮挡备注行与币种行」的需求。
          mainAxisSize: MainAxisSize.max,
          children: [
            // —— 拖拽条 ——
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: SpitoutTokens.textTertiary(context)
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // —— Header：返回 + 记一笔 + 分摊方式(弱化) + 作者头像 ——
            _buildHeader(context, l10n, editingTxId, aaEnabled),
            // —— 分类区（始终显示，含系统键盘拉起时） ——
            // 键盘拉起时分类区保持可见，整页上移保留。
            // 弱分隔线
            Divider(
              height: 1,
              thickness: 0.5,
              color: SpitoutTokens.cardInnerDividerColor(context),
            ),
            // 分类区（独立滚动、无可见滚动条）
            // Expanded 占据剩余空间：空间充足时多展示几行分类，
            // 不足时（如系统键盘拉起）分类区被压缩、超出部分滚动查看。
            Expanded(
              child: CategoryGridSection(
                kind: widget.initialKind,
                initialSelectedId: widget.initialCategoryId,
                onCategorySelected: _onCategorySelected,
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: SpitoutTokens.cardInnerDividerColor(context),
            ),
            // —— 底部固定区：备注行 + 金额栏行（始终显示） + 键盘（仅键盘关闭时） ——
            // 备注行必须始终在树中，否则键盘拉起→NoteInputRow 移除→
            // TextField 销毁→焦点丢失→键盘收起，形成死循环导致备注无法输入。
            // 输入区整体包一层带向上阴影的容器：分类区可独立滚动，阴影让
            // 底部固定输入区产生「悬浮于分类内容之上」的层次分隔感。
            // 注意必须带与 sheet 一致的实色背景，否则阴影会透过透明区域渗出来。
            Container(
              decoration: BoxDecoration(
                color: SpitoutTokens.surfaceSheet(context),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    // 负 Y 偏移：阴影只向上（分类区方向）投射
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
              // 底部留白 16：最底排按键距屏幕下沿过近，留出呼吸空间
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 备注输入行（备注行在金额栏行上方）
                  NoteInputRow(
                    noteController: _noteCtrl,
                    noteFocusNode: _noteFocusNode,
                    onNotePicked: _onNotePicked,
                  ),
                  const SizedBox(height: 4),
                  // 金额栏行：[币种][金额][删除]
                  AmountExpressionBar(
                    txCurrency: txCurrency,
                    ledgerBase: ledgerBase,
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
                  ),
                  // 4×4 键盘（始终显示；系统键盘拉起时整页上移，
                  // 键盘区随之上移，不会与系统键盘叠加遮挡备注/币种行）
                  const SizedBox(height: 8),
                  AmountKeypad(
                    u: keypadU,
                    date: _date,
                    showTime: true, // 5 列滚轮始终含时分
                    calcState: _calcStateStr,
                    op: _op,
                    isDoneEnabled: doneEnabled,
                    isSubmitting: _isSubmitting,
                    opGlyph: _opGlyph,
                    onAppend: _append,
                    onApplyOp: _applyOp,
                    onApplyEquals: _applyEquals,
                    onPickDate: _pickDate,
                    onSubmit: _onSubmit,
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    ),
  ),
  );
  }

  /// 构建 Header：返回按钮 + 「记一笔」标题 + 分摊方式(弱化) + 作者头像。
  Widget _buildHeader(
      BuildContext context, AppLocalizations l10n, int? editingTxId, bool aaEnabled) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          // 返回按钮：关闭整个 sheet
          GestureDetector(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                AppIcons.backChevron,
                size: 18,
                color: SpitoutTokens.iconTertiary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 标题 + 分摊方式:作为左对齐整体,分摊方式紧贴标题约 10px(「隔壁」),
          // 而非被 Expanded 推到行尾;标题超宽时省略号截断,保证 toggle 不被挤出。
          if (aaEnabled) ...[
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.txAddEntryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: SpitoutTokens.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildAaModeToggle(context, l10n),
                ],
              ),
            ),
            // 作者头像:Spacer 推至行尾,避免挤占「标题+分摊方式」组
            if (editingTxId != null) ...[
              const Spacer(),
              _TxAuthorAvatars(editingTransactionId: editingTxId),
            ],
          ] else ...[
            // 无 AA 账本:标题直接顶满剩余空间
            Expanded(
              child: Text(
                l10n.txAddEntryTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SpitoutTokens.textPrimary(context),
                ),
              ),
            ),
            if (editingTxId != null)
              _TxAuthorAvatars(editingTransactionId: editingTxId),
          ],
        ],
      ),
    );
  }

  /// 分摊方式切换按钮:固定宽度,左右箭头 + 中间方式文本,单点循环切换。
  ///
  /// 设计意图:
  /// - 固定宽度:边框不随「人均分摊/不分摊/指定分摊」字符数变化而抖动;
  /// - 左右箭头:直观暗示「可切换」(左/右箭头指向切换方向),
  ///   与边框一起构成明确的可点击提示;
  /// - 小圆角(6px)+ 弱色小字号:保持弱化,不抢标题与金额输入区焦点。
  /// 尺寸与编辑分摊页 [AaEditPage._buildAaModeToggle] 一致(88x28 / 字号 12),
  /// 保证两处切换体验统一、文案完整显示(不再过小截断)。
  Widget _buildAaModeToggle(BuildContext context, AppLocalizations l10n) {
    final modeText = switch (_aaMode) {
      AaMode.perPerson => l10n.aaModePerPerson,
      AaMode.noSplit => l10n.aaModeNoSplit,
      AaMode.custom => l10n.aaModeCustom,
    };
    // 边框色:文字三级色 35% 透明度,亮暗模式下均清晰可见但不抢眼
    final borderColor =
        SpitoutTokens.textTertiary(context).withValues(alpha: 0.35);
    final arrowColor = SpitoutTokens.iconTertiary(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _cycleAaMode,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          // 固定宽度 88:容纳最长文案「人均分摊」(4 字 @12px ≈48px)
          // + 左右箭头(24px) + 内边距,不随当前方式文字长度变化
          width: 88,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(AppIcons.chevronLeft, size: 12, color: arrowColor),
              Expanded(
                child: Text(
                  modeText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: SpitoutTokens.textTertiary(context),
                  ),
                ),
              ),
              Icon(AppIcons.chevronRight, size: 12, color: arrowColor),
            ],
          ),
        ),
      ),
    );
  }

}

// =============================================================================
// 编辑模式下的共享账本作者头像展示
// =============================================================================

/// 从交易ID中解析出作者信息所需的上下文:
/// - 创建者userId / 最后编辑者userId
/// - 所属共享账本的syncId(用于查成员列表)
class _TxAuthorContext {
  _TxAuthorContext({
    required this.creatorUserId,
    required this.lastEditedByUserId,
    required this.ledgerSyncId,
  });
  final String? creatorUserId;
  final String? lastEditedByUserId;
  final String ledgerSyncId;
}

/// 从本地数据库获取交易作者上下文。
/// 仅当交易属于共享账本时返回非null;非共享账本直接返回null不展示头像。
final _txAuthorContextProvider = FutureProvider.autoDispose
    .family<_TxAuthorContext?, int>((ref, txId) async {
  final repo = ref.read(repositoryProvider);
  final tx = await repo.getTransactionById(txId);
  if (tx == null) return null;
  final ledger = await repo.getLedgerById(tx.ledgerId);
  // 只有共享账本才需要展示协作者头像
  if (!(ledger?.isShared ?? false)) return null;
  return _TxAuthorContext(
    creatorUserId: tx.createdByUserId,
    lastEditedByUserId: tx.lastEditedByUserId,
    ledgerSyncId: ledger!.syncId!, // 已确认isShared=true的账本syncId必然非空
  );
});

/// 编辑模式下的共享账本作者头像组件。
///
/// UX规则:
///   - 创建人 == 编辑人 == 自己 → 不展示(看自己头像无意义)
///   - 创建人 == 编辑人 != 自己 → 展示1个头像 + Tooltip "X 创建并编辑"
///   - 创建人 != 编辑人 → 展示2个头像(左侧偏移3px叠放) + 分别Tooltip
class _TxAuthorAvatars extends ConsumerWidget {
  const _TxAuthorAvatars({required this.editingTransactionId});
  final int editingTransactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(_txAuthorContextProvider(editingTransactionId));
    // 获取云端baseUrl用于拼接头像绝对路径
    final baseUrl =
        ref.watch(spitoutCloudProviderInstance).valueOrNull?.baseUrl ?? '';

    return contextAsync.when(
      // 加载中 / 出错 / 非共享账本 → 不展示
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ctx) {
        if (ctx == null) return const SizedBox.shrink();
        // 从成员列表中查找创作者/编辑者信息
        final membersAsync = ref.watch(ledgerMembersProvider(ctx.ledgerSyncId));
        return membersAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (members) {
            final byId = <String, SpitoutCloudLedgerMember>{
              for (final m in members) m.userId: m,
            };
            final creator = ctx.creatorUserId != null
                ? byId[ctx.creatorUserId]
                : null;
            final editor = ctx.lastEditedByUserId != null
                ? byId[ctx.lastEditedByUserId]
                : null;
            // 判断当前用户是否就是这笔交易的创建者/编辑者(二者皆为同一人)
            final creatorIsSelf = members
                .where((m) => m.isSelf)
                .any((m) => m.userId == ctx.creatorUserId);
            final editorIsSelf = members
                .where((m) => m.isSelf)
                .any((m) => m.userId == ctx.lastEditedByUserId);
            final isSelf = creatorIsSelf && editorIsSelf;

            // 规则1:创建人==编辑人==自己 → 不展示
            if (isSelf) return const SizedBox.shrink();

            // 复用共享头像组：创建人==编辑人!=自己 → 1个头像；
            // 创建人!=编辑人 → 2个重叠头像。两者规则与首页列表一致，
            // 且图片加载失败时回退首字母（修复"只有圆形占位、没有首字母"）。
            return CollaboratorAvatarGroup(
              creator: creator,
              editor: editor,
              creatorUserId: ctx.creatorUserId,
              editorUserId: ctx.lastEditedByUserId,
              baseUrl: baseUrl,
              radius: 11,
            );
          },
        );
      },
    );
  }
}


