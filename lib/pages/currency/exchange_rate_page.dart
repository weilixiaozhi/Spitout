import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/providers/core/post_processor.dart';
import '../../utils/currency/rate_math.dart';
import '../../theme/colors.dart';
import '../../utils/currency/currencies.dart';
import '../../widgets/widgets.dart';
import 'currency_manage_page.dart';
import '../../theme/icons/app_icons.dart';

/// 汇率管理页(账本维度化后):
/// - 基准 = 当前账本本位币(ledger.currency),切账本自动换组
/// - 自动拉取(24h 节流,单币种内部 no-op)+ 手动编辑覆盖
/// - 基准行点击 = 切当前账本本位币(确认/重算/同步走统一公共函数)
/// 方向约定全链统一:rate 字符串 = 「1 quote = rate base」。
class ExchangeRatePage extends ConsumerStatefulWidget {
  const ExchangeRatePage({super.key});

  @override
  ConsumerState<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends ConsumerState<ExchangeRatePage> {
  // 缓存上一次成功加载的汇率数据。
  // 目的:刷新期间 effectiveRatesForLedgerProvider 短暂 loading 时用缓存承接列表,
  // 避免全屏 CircularProgressIndicator 导致的闪屏。
  // 基准币种(base)变化时 _lastBase != base 自动失效,走首次加载态。
  String? _lastBase;
  Map<String, EffectiveRate>? _lastRates;

  // 币种筛选关键词。复用 showCurrencyPickerSheet 的过滤逻辑:
  // 按 code(大写包含)或本地化名称(原文包含)匹配,空关键词展示全部。
  String _query = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // 进页静默拉取:24h 节流 + 单币种 no-op,内部自判,不阻塞 UI。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshExchangeRatesFromUi(ref);
    });
  }

  @override
  void dispose() {
    // 释放搜索框控制器,避免内存泄漏(TextField 在页面销毁后不再被引用)。
    _searchController.dispose();
    super.dispose();
  }

  /// 6 位有效数字展示(方向已是「1 quote = rate base」)。
  String _fmt6(String rate) {
    final v = double.tryParse(rate);
    if (v == null) return rate;
    return v.toStringAsPrecision(6);
  }

  Future<void> _onRefresh() async {
    final l10n = AppLocalizations.of(context);
    final ok = await refreshExchangeRatesFromUi(ref, force: true);
    if (!mounted) return;
    showToast(context, ok ? l10n.rateRefreshSuccess : l10n.rateRefreshFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    // 基准 = 当前账本本位币(折算基准唯一来源);切账本自动换组
    final base = ref.watch(currentLedgerCurrencyProvider);
    final ratesAsync = ref.watch(effectiveRatesForLedgerProvider);
    final currentLedger = ref.watch(currentLedgerProvider).valueOrNull;

    // 缓存:有数据时存入 _lastRates,base 与缓存 base 一致时刷新期间用缓存承接,
    // 避免 effectiveRatesForLedgerProvider 短暂 loading 触发全屏 spinner 闪屏。
    if (ratesAsync.hasValue && ratesAsync.value != null) {
      _lastBase = base;
      _lastRates = Map<String, EffectiveRate>.from(ratesAsync.value!);
    }
    final bool hasCache = _lastBase == base && _lastRates != null;
    // refresh 期间 use cache;无缓存或 base 变了才走 provider raw value
    final rates = hasCache
        ? _lastRates!
        : (ratesAsync.valueOrNull ?? const <String, EffectiveRate>{});

    // 外币 = 用户可见币种集合 − 基准币种(「管理展示币种」页勾选子集,
    // 仅影响 UI 展示;API 仍全量拉取存储,隐藏币种随时可重新启用)。
    // 按 kCurrencyCodes 原顺序过滤,保持与币种选择弹窗一致的列表顺序。
    final visible = ref.watch(visibleCurrenciesProvider);
    final allQuotes = kCurrencyCodes
        .where((c) => visible.contains(c.toUpperCase()) && c.toUpperCase() != base)
        .toList();
    // 币种筛选:复用 showCurrencyPickerSheet 的过滤逻辑,
    // 按 code(大写包含)或本地化名称(原文包含)匹配,与币种选择弹窗体验一致。
    final quotes = allQuotes.where((code) {
      final q = _query.trim();
      if (q.isEmpty) return true;
      final uq = q.toUpperCase();
      final name = getCurrencyName(code, context);
      return code.toUpperCase().contains(uq) || name.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.exchangeRatePageTitle,
            showBack: true,
            actions: [
              HeaderIconAction(
                icon: AppIcons.refresh,
                tooltip: l10n.exchangeRatePageTitle,
                onPressed: _onRefresh,
              ),
            ],
          ),
          // 首次加载(无缓存):弱化 loading,仅 24x24 小圈 + stroke 2px,
          // 比默认 36px 全屏 spinner 轻量,减少视觉突兀感。
          if (ratesAsync.isLoading && !hasCache)
            const Expanded(
              child: Center(
                child: SizedBox(
                  width: 24.0,
                  height: 24.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              ),
            )
          // 首次加载出错(无缓存):显示错误信息与重试按钮。
          // 有缓存时即使出错也走正常内容区(用旧数据兜底),不阻断浏览。
          else if (ratesAsync.hasError && !hasCache)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.error,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.6),
                      ),
                      SizedBox(height: 12),
                      Text(
                        l10n.analyticsLoadFailed,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: SpitoutTokens.textSecondary(context),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _onRefresh(),
                        icon: Icon(AppIcons.refresh, size: 18),
                        label: Text(l10n.analyticsRetry),
                      ),
                    ],
                  ),
                ),
              ),
            )
          // 有数据或缓存:常驻内容区,刷新时仅顶部 2px 极淡细线指示
          else
            Expanded(
            child: Column(
              children: [
                // 刷新指示器:仅 2px 极淡细线,alpha=0.15 几乎不可见。
                // 仅 ratesAsync 正在 loading 且已有缓存时才显示,首屏加载不出现。
                if (ratesAsync.isLoading && hasCache)
                  SizedBox(
                    height: 2.0,
                    child: LinearProgressIndicator(
                      minHeight: 2.0,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              children: [
                // 顶部说明模块(主币种含义与手动汇率用法)
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              AppIcons.info,
                              size: 20.0,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8.0),
                            Text(
                              l10n.exchangeRateInfoTitle,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                                color: SpitoutTokens.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          l10n.exchangeRateInfoMessage,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: SpitoutTokens.textSecondary(context),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8.0),
                // 作用域标注(按账本维度):
                // 汇率组 = 当前账本视角,避免用户误以为基准仍是全局的。
                // 无账本时隐藏。
                if (currentLedger != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                    child: Text(
                      l10n.exchangeRateCurrentLedger(currentLedger.name),
                      style: TextStyle(
                        fontSize: 12,
                        color: SpitoutTokens.textTertiary(context),
                      ),
                    ),
                  ),
                // 1. 基准币种(账本本位币;无账本时置灰,点击仅提示先创建账本)
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => _pickBaseCurrency(context),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            l10n.ledgerBaseCurrencyLabel,
                            style: TextStyle(
                              fontSize: 15,
                              color: SpitoutTokens.textPrimary(context),
                            ),
                          ),
                          const Spacer(),
                          // 全局统一「ISO + (符号)」展示
                          currencyFlagLabel(
                            context,
                            base,
                            textStyle: TextStyle(
                              fontSize: 14,
                              color: currentLedger == null
                                  ? SpitoutTokens.textTertiary(context)
                                  : SpitoutTokens.textSecondary(context),
                            ),
                          ),
                          SizedBox(width: 4.0),
                          Icon(
                            AppIcons.chevronRight,
                            size: 18.0,
                            color: SpitoutTokens.iconTertiary(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.0),
                // 1.5 币种管理入口:跳转「管理展示币种」页,
                // 右侧实时显示已选币种数,让用户一眼知道当前过滤范围。
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      appPageRoute(
                        builder: (_) => const CurrencyManagePage(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            l10n.currencyManageEntry,
                            style: TextStyle(
                              fontSize: 15,
                              color: SpitoutTokens.textPrimary(context),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.currencyManageCount(visible.length),
                            style: TextStyle(
                              fontSize: 14,
                              color: SpitoutTokens.textSecondary(context),
                            ),
                          ),
                          SizedBox(width: 4.0),
                          Icon(
                            AppIcons.chevronRight,
                            size: 18.0,
                            color: SpitoutTokens.iconTertiary(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.0),

                // 币种筛选框:复用 ledgersSearchCurrency 文案与
                // showCurrencyPickerSheet 的搜索交互,让用户在汇率列表中
                // 快速定位目标币种(按名称/代码筛选)。
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(AppIcons.search),
                    hintText: l10n.ledgersSearchCurrency,
                    // 有输入时显示清除按钮,便于一键清空筛选回到全量列表
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(AppIcons.close, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                SizedBox(height: 8.0),

                // 2. 汇率列表
                SectionCard(
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  child: quotes.isEmpty
                      // 筛选无匹配:展示空状态提示,避免空白列表
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Text(
                              l10n.commonEmpty,
                              style: TextStyle(
                                fontSize: 14,
                                color: SpitoutTokens.textTertiary(context),
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (int i = 0; i < quotes.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 12.0,
                                  endIndent: 12.0,
                                  color: SpitoutTokens.divider(context),
                                ),
                              _RateRow(
                                quote: quotes[i],
                                base: base,
                                eff: rates[quotes[i]],
                                primary: primary,
                                onEdit: () => _editRate(
                                    context, quotes[i], base, rates[quotes[i]]),
                                onReset: () => _resetRate(quotes[i], base),
                              ),
                            ],
                          ],
                        ),
                ),

                SizedBox(height: 16.0),
                // 3. 免责声明
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.0,
                  ),
                  child: Text(
                    l10n.rateDisclaimer,
                    style: TextStyle(
                      fontSize: 11,
                      color: SpitoutTokens.textTertiary(context),
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 8.0),
              ],
            ),    // ListView
            ),    // Expanded (nested in inner Column)
          ],      // inner Column.children
          ),      // inner Column
          ),      // Expanded (outer)
        ],
      ),
    );
  }

  /// 基准币种选择底部弹窗(可见币种子集 + 搜索)。
  /// 选中 = 切当前账本本位币,确认弹窗/拉汇率/重算/刷新/同步全收敛在
  /// 公共函数 applyLedgerCurrencyChange(与账本编辑入口共用)。
  /// 无账本时不可切(P4):Toast 引导先创建账本。
  Future<void> _pickBaseCurrency(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ledger = ref.read(currentLedgerProvider).valueOrNull;
    if (ledger == null) {
      showToast(context, l10n.homeBaseCurrencyNeedLedger);
      return;
    }
    final primary = Theme.of(context).colorScheme.primary;
    final picked = await showCurrencyPickerSheet(
      context,
      selected: ledger.currency.toUpperCase(),
      primaryColor: primary,
      title: l10n.ledgerBaseCurrencyLabel,
      showRateAsBaseLabel: true,
      // 与账本编辑页一致:主币种选择不展示汇率换算行(rateBase 不传)
      visibleCurrencies: ref.read(visibleCurrenciesProvider),
    );
    if (picked == null || !context.mounted) return;
    await applyLedgerCurrencyChange(context, ref,
        ledgerId: ledger.id, newCurrency: picked);
  }

  /// 编辑某币种的手动汇率。
  Future<void> _editRate(
    BuildContext context,
    String quote,
    String base,
    EffectiveRate? eff,
  ) async {
    // 弹窗自持 TextEditingController(State.dispose 在路由完全移除后才被调用)。
    // 不要在 await showDialog 返回后立刻 dispose —— 退场动画期间 TextField
    // 仍引用 controller,会 use-after-dispose 红屏。
    final result = await showDialog<({bool reset, String rate})>(
      context: context,
      builder: (_) => _RateEditDialog(
        quote: quote,
        base: base,
        hadManual: eff?.manual ?? false,
        // 预填:手动值回填原始字符串(保留用户精度);自动值用 _fmt6 展示(6 位有效,
        // 编辑后会被新输入覆盖,截断无妨);无汇率则留空。
        initialText: eff == null
            ? ''
            : (eff.manual ? eff.rate : _fmt6(eff.rate)),
      ),
    );
    if (result == null || !mounted) return; // 取消/遮罩关闭

    final repo = ref.read(repositoryProvider);
    if (result.reset) {
      await repo.removeOverride(base: base, quote: quote);
    } else {
      // rate 字符串原样存用户输入(trim),不二次格式化。
      await repo.setOverride(base: base, quote: quote, rate: result.rate);
    }
    ref.read(rateRefreshTickProvider.notifier).state++;
    final activeLedgerId = ref.read(currentLedgerIdProvider);
    if (activeLedgerId > 0) {
      unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
    }
  }

  /// 恢复某币种为自动汇率:删除手动覆盖 → bump tick → 触发 PostProcessor 同步。
  /// 与编辑弹窗内 reset 分支逻辑一致,此处为列表行「恢复自动」文字链外显。
  Future<void> _resetRate(String quote, String base) async {
    final repo = ref.read(repositoryProvider);
    await repo.removeOverride(base: base, quote: quote);
    ref.read(rateRefreshTickProvider.notifier).state++;
    final activeLedgerId = ref.read(currentLedgerIdProvider);
    if (activeLedgerId > 0) {
      unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
    }
  }
}

/// 汇率编辑弹窗:自持 controller,关闭时通过返回值告知动作
/// (reset=true 恢复自动;reset=false 保存 rate;null=取消)。
class _RateEditDialog extends ConsumerStatefulWidget {
  final String quote;
  final String base;
  final bool hadManual;
  final String initialText;

  const _RateEditDialog({
    required this.quote,
    required this.base,
    required this.hadManual,
    required this.initialText,
  });

  @override
  ConsumerState<_RateEditDialog> createState() => _RateEditDialogState();
}

class _RateEditDialogState extends ConsumerState<_RateEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    // 实时反向参考:1 base ≈ (1/rate) quote
    final parsed = double.tryParse(_controller.text.trim());
    final inverseText = (parsed != null && parsed > 0)
        ? (1 / parsed).toStringAsPrecision(6)
        : '—';

    return AlertDialog(
      backgroundColor: SpitoutTokens.surfaceElevated(context),
      title: Text(
        l10n.rateEditTitle,
        style: TextStyle(color: SpitoutTokens.textPrimary(context)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              prefixText: '1 ${widget.quote} = ',
              suffixText: widget.base,
            ),
          ),
          SizedBox(height: 10.0),
          Text(
            l10n.rateInverseHint(widget.base, inverseText, widget.quote),
            style: TextStyle(
              fontSize: 12,
              color: SpitoutTokens.textTertiary(context),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.hadManual)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, (reset: true, rate: '')),
            child: Text(
              l10n.rateResetToAuto,
              style: TextStyle(color: SpitoutTokens.textSecondary(context)),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.commonCancel,
            style: TextStyle(color: SpitoutTokens.textSecondary(context)),
          ),
        ),
        TextButton(
          onPressed: () {
            final raw = _controller.text.trim();
            final v = double.tryParse(raw);
            // 校验:输入必须为大于 0 的有效数字,否则 Toast 提示并禁止提交
            if (v == null || v <= 0) {
              showToast(context, l10n.rateInvalidInput);
              return;
            }
            Navigator.pop(context, (reset: false, rate: raw));
          },
          child: Text(
            l10n.commonSave,
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// 单条汇率行。
/// 状态文案中性;右侧汇率值下方右对齐常驻「编辑」文字链;仅「手动」汇率
/// 才并列「恢复自动」。
class _RateRow extends ConsumerWidget {
  final String quote;
  final String base;
  final EffectiveRate? eff;
  final Color primary;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  const _RateRow({
    required this.quote,
    required this.base,
    required this.eff,
    required this.primary,
    required this.onEdit,
    required this.onReset,
  });

  /// rateDate 距今 > 7 天?(rateDate 形如 "2026-06-10")
  bool _isStale(String? rateDate) {
    if (rateDate == null) return false;
    final d = DateTime.tryParse(rateDate);
    if (d == null) return false;
    return DateTime.now().difference(d) > const Duration(days: 7);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mainName = getCurrencyName(quote, context);
    final bool isManual = eff?.manual == true;

    // 中性状态文案(非按钮样式,仅作标识)
    Widget status;
    if (eff == null) {
      status = Text(
        l10n.rateNotFetched,
        style: TextStyle(
          fontSize: 12,
          color: SpitoutTokens.textTertiary(context),
        ),
      );
    } else if (isManual) {
      status = Text(
        l10n.rateSourceManual,
        style: TextStyle(
          fontSize: 12,
          color: SpitoutTokens.textSecondary(context),
        ),
      );
    } else {
      final stale = _isStale(eff!.rateDate);
      status = Text(
        '${l10n.rateSourceAuto} · ${l10n.rateUpdatedAt(eff!.rateDate ?? '')}',
        style: TextStyle(
          fontSize: 12,
          color: stale ? Colors.orange : SpitoutTokens.textTertiary(context),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 12.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左:币种名 + 码 / 状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mainName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: SpitoutTokens.textPrimary(context),
                        ),
                      ),
                    ),
                    SizedBox(width: 6.0),
                    Text(
                      quote,
                      style: TextStyle(
                        fontSize: 12,
                        color: SpitoutTokens.textTertiary(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.0),
                // 状态文案 + 「恢复自动」文字链（仅手动态显示）。
                // 放在状态文案右侧、左对齐，与右侧编辑按钮分离，避免误触。
                // isManual=true 时 status 为「手动」（短文本），不会与链接溢出。
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: status),
                    if (isManual) ...[
                      SizedBox(width: 8.0),
                      // 「恢复自动」文字链使用 primary 色，让用户明确感知到
                      // 它是可点击的操作入口。
                      // 纯动作文字链（恢复自动），无选中态，按统一原则补涟漪反馈
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onReset,
                          borderRadius: BorderRadius.circular(6),
                          // 对称 padding：涟漪在文字四周均匀外扩（参照 TextButton）。
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Text(
                              l10n.rateResetToAuto,
                              style: TextStyle(
                                fontSize: 12,
                                color: primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.0),
          // 右:汇率值 + 下方编辑文字链（右对齐）
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 汇率换算值
              Text(
                // 统一汇率换算文案:(1 USD = 7.24 CNY),未获取时回退占位符
                eff == null
                    ? '—'
                    : formatExchangeRate(quote, base, eff!.rate),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: eff == null
                      ? SpitoutTokens.textTertiary(context)
                      : SpitoutTokens.textPrimary(context),
                ),
              ),
              SizedBox(height: 4.0),
              // 编辑文字链常驻右对齐。「恢复自动」位于左侧手动文案旁边，
              // 不与编辑链并列，避免两个操作入口紧挨导致误触。
              // 纯动作文字链（编辑汇率），无选中态，按统一原则补涟漪反馈
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  // 对称 padding：涟漪在文字四周均匀外扩（参照 TextButton）。
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      l10n.rateEditLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}