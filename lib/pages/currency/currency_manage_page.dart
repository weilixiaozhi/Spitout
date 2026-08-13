import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/utils/currency/currencies.dart';
import 'package:spitout/widgets/widgets.dart';
import 'package:spitout/theme/icons/app_icons.dart';

/// 管理展示币种页。
///
/// 设计意图:全量 146 个币种在各选择列表(汇率页、账本主币种、记账币种、
/// 账本管理币种)里过长,用户在此勾选「常用子集」,勾选的币种才会出现在
/// 上述选择列表中。仅影响 UI 展示,不影响 API 拉取与交易数据。
///
/// - 主币种(折算基准)始终锁定不可取消,行内显示锁图标与提示。
/// - 已有交易记录的币种允许自由隐藏:交易数据保留原币种码,随时可重新启用。
/// - 默认展示 [kCommonCurrencyCodes](13 个常用币种)。
class CurrencyManagePage extends ConsumerStatefulWidget {
  const CurrencyManagePage({super.key});

  @override
  ConsumerState<CurrencyManagePage> createState() => _CurrencyManagePageState();
}

class _CurrencyManagePageState extends ConsumerState<CurrencyManagePage> {
  // 币种筛选关键词:按 code(大写包含)或本地化名称(原文包含)匹配,
  // 复用各 picker 的过滤交互,空关键词展示全部。
  String _query = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    // 释放控制器避免内存泄漏
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 锁定基准 = 当前账本本位币(每账本一套可见集合,仅锁定自己的本位币)
    final base = ref.watch(currentLedgerCurrencyProvider);
    final visible = ref.watch(visibleCurrenciesProvider);
    final allCur = getCurrencies(context);

    // 排序:主币种(当前账本本位币 base)常驻置顶 + 常用币种按系统语言排序
    // (与欢迎页一致) + 其余按地区原顺序。复用 orderCurrencies,与 picker 行为统一。
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final ordered = orderCurrencies(allCur, locale, pinned: [base.toUpperCase()]);

    // 关键词过滤:与各 picker 一致(code 大写包含 / 名称原文包含)
    final filtered = ordered.where((c) {
      final q = _query.trim();
      if (q.isEmpty) return true;
      final uq = q.toUpperCase();
      return c.code.contains(uq) || c.name.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.currencyManageTitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: SpitoutDimens.p12,
                vertical: SpitoutDimens.p8,
              ),
              children: [
                // 顶部统计:已选 N 个币种。实时跟随 visible 集合变化。
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpitoutDimens.p4,
                    vertical: SpitoutDimens.p4,
                  ),
                  child: Text(
                    l10n.currencyManageCount(visible.length),
                    style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                  ),
                ),
                const SizedBox(height: SpitoutDimens.p4),
                // 搜索框:复用 ledgersSearchCurrency 文案与各 picker 交互
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(AppIcons.search),
                    hintText: l10n.ledgersSearchCurrency,
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(AppIcons.close, size: SpitoutDimens.icon20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: SpitoutDimens.p8),
                if (filtered.isEmpty)
                  // 筛选无匹配:空状态提示
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: SpitoutDimens.p32),
                    child: Center(
                      child: Text(
                        l10n.commonEmpty,
                        style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textTertiary(context)),
                      ),
                    ),
                  )
                else
                  // 币种列表:每行 币种符号 + 名称(code) + 右侧 Checkbox
                  // 主币种行锁定:Checkbox 禁用 + 锁图标 + 提示文案
                  Container(
                    decoration: BoxDecoration(
                      color: SpitoutTokens.surfaceElevated(context),
                      borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < filtered.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 12.0,
                              endIndent: 12.0,
                              color: SpitoutTokens.divider(context),
                            ),
                          _CurrencyManageRow(
                            info: filtered[i],
                            // 本位币锁定按大小写不敏感比较,与 pinned 口径一致,
                            // 避免数据异常(小写/混合大小写)时基准币种行解锁。
                            isBase:
                                filtered[i].code.toUpperCase() ==
                                base.toUpperCase(),
                            isVisible: visible.contains(filtered[i].code),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: SpitoutDimens.p16),
                // 底部说明:隐藏的币种不影响已有交易,随时可重新启用
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p4),
                  child: Text(
                    l10n.currencyManageHint,
                    style: SpitoutTextTokens.caption(context).copyWith(color: SpitoutTokens.textTertiary(context),
                      height: 1.4),
                  ),
                ),
                const SizedBox(height: SpitoutDimens.p8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条币种管理行。
///
/// 账本本位币行(isBase=true):Checkbox 强制勾选且禁用,右侧显示锁图标与
/// 「账本本位币，不可隐藏」提示,点击不触发切换。
/// 普通币种行:点击整行切换勾选状态,通过 [toggleCurrencyVisibility] 持久化。
class _CurrencyManageRow extends ConsumerWidget {
  final CurrencyInfo info;
  final bool isBase;
  final bool isVisible;

  const _CurrencyManageRow({
    required this.info,
    required this.isBase,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      // 本位币行不可点击切换(锁定),其余行点击切换可见性
      onTap: isBase
          ? null
          : () => toggleCurrencyVisibility(ref, info.code),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpitoutDimens.p12,
          vertical: SpitoutDimens.p8,
        ),
        child: Row(
          children: [
            // 与币种选择弹窗、欢迎页币种列表同一布局：固定宽度符号列
            // (kCurrencySymbolColumnWidth)。币种符号长短不一（如 ¥ 与 HK$），
            // 若按内容自适应宽度，各行名称起始 x 会随符号宽度漂移，列表参差不齐。
            // 固定列宽后，名称列在所有行中对齐到同一 x 位置，UI 口径全局一致。
            currencySymbolColumn(
              info.code,
              style: SpitoutTextTokens.title(context).copyWith(color: SpitoutTokens.textSecondary(context)),
            ),
            // 与弹窗 ListTile 的 horizontalTitleGap=16 保持一致，
            // 保证符号列到名称列的间距与各处选择列表相同。
            const SizedBox(width: SpitoutDimens.p16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${info.name} (${info.code})',
                    style: SpitoutTextTokens.title(context).copyWith(color: SpitoutTokens.textPrimary(context)),
                  ),
                  if (isBase)
                    // 主币种锁定提示:让用户明确为何该行不可取消
                    Padding(
                      padding: const EdgeInsets.only(top: SpitoutDimens.p4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.lock,
                            size: SpitoutDimens.icon12,
                            color: SpitoutTokens.textTertiary(context),
                          ),
                          const SizedBox(width: SpitoutDimens.p4),
                          Text(
                            l10n.currencyManageBaseLocked,
                            style: SpitoutTextTokens.caption(context).copyWith(color: SpitoutTokens.textTertiary(context)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Checkbox:主币种强制勾选且禁用;其余正常切换
            Checkbox(
              value: isBase ? true : isVisible,
              onChanged: isBase
                  ? null
                  : (_) => toggleCurrencyVisibility(ref, info.code),
              activeColor: primary,
            ),
          ],
        ),
      ),
    );
  }
}
