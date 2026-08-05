import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_route.dart';
import '../l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import '../theme/colors.dart';
import '../utils/currency/currencies.dart';
import '../theme/icons/app_icons.dart';
import 'currency_flag.dart';

/// 币种选择 bottom sheet(搜索 + 币种符号 + 汇率 + 选中勾)。返回选中的 code,取消返回 null。
///
/// 从 exchange_rate_page._pickBaseCurrency 抽出,汇率页 / 个性化页 / 记账弹窗共用。
/// [rateBase] 传入(大写 ISO)时,每行右侧展示「1 该币种 ≈ x rateBase」的汇率
/// (弹窗内拉一次全量,缺失显示占位)。
/// [showRateAsBaseLabel] 为 true 时(记账页调用),仅主币种自身行使用符号化展示
/// 「账本主币种 · ¥1.00」;其他币种的汇率换算统一走 formatExchangeRate,
/// 输出「(1 USD = 7.24 CNY)」(ISO 代号 + 括号),不使用货币符号。
/// [visibleCurrencies] 传 null = 全量 146 个币种(首次引导页用);
/// 传非空集合 = 仅展示集合内币种。当前选中值(selected)与 rateBase(账本本位币)
/// 始终强制保留——避免当前值被过滤后看不到选中态,导致用户困惑。
Future<String?> showCurrencyPickerSheet(
  BuildContext context, {
  required String selected,
  required Color primaryColor,
  // 标题必传:不同入口语义不同(选交易币种/选账本本位币/管理可见集合),
  // 由调用方给准确文案,本组件不内置默认标题
  required String title,
  String? rateBase,
  // 子 sheet 挂载 navigator(false = 就近 / nested);默认 true 使用主 navigator
  bool useRootNavigator = true,
  // 子 sheet 遮罩色;记账页内调用传透明以不显示遮罩
  Color? barrierColor,
  // 记账页内调用传 true,符号化展示汇率
  bool showRateAsBaseLabel = false,
  // 可见币种集合(大写 ISO);null=全量,非空=仅展示集合内 + 当前值兜底
  Set<String>? visibleCurrencies,
}) {
  final current = selected.toUpperCase();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: SpitoutTokens.surfaceSheet(context),
    barrierColor: barrierColor,
    // 全局统一上滑动画：线性曲线（无加速减速），时长与页面切换一致。
    sheetAnimationStyle: kSheetAnimationStyle,
    // 抬升阴影：记账页内拉起时遮罩为透明，阴影让弹窗与下层记账页分出层级
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      // 顶部分隔线：sheet 左右/下边缘均在屏幕外或圆角内不可见，
      // 整圈描边最终只呈现为顶部一条细分隔线
      side: BorderSide(
        color: SpitoutTokens.borderStrong(context),
        width: 2,
      ),
    ),
    builder: (bctx) {
      String query = '';
      final sheetTitle = title;
      return StatefulBuilder(builder: (sctx, setSheetState) {
        // 排序:主币种(rateBase)/ 选中值(selected)常驻置顶 + 常用币种按系统语言
        // 排序(与欢迎页一致) + 其余按地区原顺序。复用 orderCurrencies 保证多入口一致。
        final allCur = getCurrencies(bctx);
        // 可见性过滤:visibleCurrencies 非空时仅保留集合内币种;
        // 当前选中值与 rateBase 强制保留(兜底,避免当前值被隐藏后看不到选中态)。
        final rateBaseUp = rateBase?.toUpperCase();
        final source = visibleCurrencies == null
            ? allCur
            : allCur
                .where((c) =>
                    visibleCurrencies.contains(c.code) ||
                    c.code == current ||
                    c.code == rateBaseUp)
                .toList();
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        // 置顶集合:主币种(rateBase)优先,其次当前选中值(selected),去重。
        // 两者无论是否常用币种都常驻置顶(主币种永远第一位)。
        final pins = <String>[];
        if (rateBaseUp != null) pins.add(rateBaseUp);
        if (!pins.contains(current)) pins.add(current);
        final ordered = orderCurrencies(source, locale, pinned: pins);
        final filtered = ordered.where((c) {
          final q = query.trim();
          if (q.isEmpty) return true;
          final uq = q.toUpperCase();
          return c.code.contains(uq) || c.name.contains(q);
        }).toList();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + MediaQuery.of(bctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: 440,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: SpitoutTokens.textTertiary(bctx).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  sheetTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: SpitoutTokens.textPrimary(bctx),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(AppIcons.search),
                    hintText: AppLocalizations.of(bctx).ledgersSearchCurrency,
                  ),
                  onChanged: (v) => setSheetState(() => query = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  // 汇率展示:rateBase 传入时用 Consumer 拿全量汇率;否则空 map。
                  child: Consumer(builder: (cctx, ref, _) {
                    final rates = rateBase == null
                        ? const <String, double>{}
                        : (ref
                                .watch(currencyPickerRatesProvider(
                                    rateBase.toUpperCase()))
                                .value ??
                            const <String, double>{});
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final sel = c.code == current;
                        // 汇率行:1 该币种 ≈ x rateBase(base 自身/缺失不显示)
                        // 记账页(showRateAsBaseLabel=true)符号化展示
                        String? rateText;
                        if (rateBase != null) {
                          final baseCode = rateBase.toUpperCase();
                          final baseSym = getCurrencySymbol(baseCode);
                          if (c.code == baseCode) {
                            // 主币种自身
                            if (showRateAsBaseLabel) {
                              // 「账本主币种 · ¥1.00」(仅自身行用符号,汇率换算统一走 ISO)
                              rateText =
                                  '${AppLocalizations.of(cctx).txLedgerBaseCurrency} · $baseSym${(1.0).toStringAsFixed(2)}';
                            }
                          } else {
                            final r = rates[c.code];
                            if (r != null) {
                              // 汇率换算文案统一来源:(1 USD = 7.24 CNY)
                              rateText = formatExchangeRate(c.code, baseCode, r.toString());
                            }
                          }
                        }
                        return ListTile(
                          // 符号列固定宽度（kCurrencySymbolColumnWidth），
                          // 符号长短不一（¥ 与 HK$），不定宽会导致各行名称
                          // 起始 x 随符号宽度漂移；固定列宽 + ListTile 默认
                          // horizontalTitleGap 后「名称 (ISO)」整列左对齐。
                          leading: currencySymbolColumn(
                            c.code,
                            style: TextStyle(
                              fontSize: 16,
                              color: SpitoutTokens.textSecondary(cctx),
                            ),
                          ),
                          title: Text(
                            '${c.name} (${c.code})',
                            style: TextStyle(
                              color: sel
                                  ? primaryColor
                                  : SpitoutTokens.textPrimary(bctx),
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: rateText == null
                              ? null
                              : Text(
                                  rateText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: SpitoutTokens.textTertiary(cctx),
                                  ),
                                ),
                          trailing: sel
                              ? Icon(AppIcons.check, color: primaryColor)
                              : null,
                          onTap: () => Navigator.pop(bctx, c.code),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      });
    },
  );
}
