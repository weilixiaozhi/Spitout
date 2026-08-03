import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../services/settlement/aa_decimal_util.dart';
import '../../services/settlement/aa_edit_models.dart';
import '../../services/settlement/aa_settlement_service.dart';
import '../../theme/colors.dart';
import '../../theme/icons/app_icons.dart';
import '../../utils/category_utils.dart';
import '../../widgets/widgets.dart';

/// AA 分摊编辑页(纯选择器,不写库)。
///
/// 职责:
/// - 只读展示主体信息(金额 / 分类 / 日期 / 货币,不可改);
/// - 主体卡内嵌分摊方式三态切换按钮(人均 / 不分摊 / 指定,与记账编辑器一致);
/// - 切换为人均/指定后在下方展示分摊配置:支出人(bottom sheet)+ 参与人(页内直接勾选);
///   人均:勾选项决定均摊人数,金额实时重算、输入框置灰不可改;
///   指定:每人金额可填,合计偏差按支出人兜底修正;
/// - pop 返回 [AaEditResult](null = 取消),由调用方落库。
class AaEditPage extends ConsumerStatefulWidget {
  final AaEditPageArgs args;

  const AaEditPage({super.key, required this.args});

  @override
  ConsumerState<AaEditPage> createState() => _AaEditPageState();
}

class _AaEditPageState extends ConsumerState<AaEditPage> {
  /// 分摊方式(人均 / 指定 / 不分摊)。
  late AaMode _mode = widget.args.mode;

  /// 支出人标识;null 时取参与人列表首个兜底。
  String? _paidById;

  /// 参与人勾选集合;null = 全部成员(运行时展开为 options 全集)。
  ///
  /// 需求:支出人必是参与人且置顶置灰、不可反选;
  /// 取消勾选某人 → 不计入分摊(人均时实时重算,指定时金额栏置灰)。
  Set<String>? _participantIds;

  /// 指定金额输入控制器(key=参与人标识),随参与人变化同步增删。
  final Map<String, TextEditingController> _amountCtrls = {};

  /// 参与人选项异步加载完成后只初始化一次,避免用户输入被流刷新覆盖。
  bool _initialized = false;

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 参与人选项到达后的首次初始化:支出人兜底、参与人回填、指定金额回填。
  ///
  /// 不分摊模式不预填金额,切换到人均/指定时按需填充。
  void _initOnce(List<AaParticipantOption> options) {
    if (_initialized || options.isEmpty) return;
    _initialized = true;
    _paidById = widget.args.paidByUserId ?? options.first.id;
    _participantIds = widget.args.participantIds?.toSet();
    _syncAmountControllers(options);
    if (_mode == AaMode.noSplit) return;
    final hasSplits =
        widget.args.splits != null && widget.args.splits!.isNotEmpty;
    if (_mode == AaMode.custom && !hasSplits) {
      // 指定分摊默认填人均金额,便于在人均基础上微调。
      _fillPerPersonAmounts(options);
    } else if (hasSplits) {
      // 编辑模式回填既有指定金额。
      widget.args.splits?.forEach((id, amount) {
        _amountCtrls[id]?.text = amount;
      });
    }
  }

  /// 按人均分摊默认填充所有参与人金额(总额 / 人数,保留两位小数)。
  ///
  /// 除不尽的尾差由保存时的合计校验按支出人兜底修正。
  void _fillPerPersonAmounts(List<AaParticipantOption> options) {
    final participants = _effectiveParticipants(options);
    if (participants.isEmpty) return;
    final per = widget.args.amount / participants.length;
    final perText = per.toStringAsFixed(2);
    for (final id in participants) {
      _amountCtrls[id]?.text = perText;
    }
  }

  /// 按当前参与人集合同步金额输入控制器:新增补空控制器,移除释放。
  void _syncAmountControllers(List<AaParticipantOption> options) {
    final ids = options.map((o) => o.id).toSet();
    for (final id in ids) {
      _amountCtrls.putIfAbsent(id, () => TextEditingController());
    }
    final stale = _amountCtrls.keys.where((k) => !ids.contains(k)).toList();
    for (final k in stale) {
      _amountCtrls.remove(k)?.dispose();
    }
  }

  /// 当前生效的参与人集合(已勾选);未选(null) = 全部成员。
  List<String> _effectiveParticipants(List<AaParticipantOption> options) {
    final all = options.map((o) => o.id).toList();
    final selected = _participantIds;
    if (selected == null) return all;
    // 保持 options 顺序,且仅返回已勾选的;支出人必在内(锁定)。
    return all.where((id) => selected.contains(id)).toList();
  }

  String _optionName(List<AaParticipantOption> options, String id) {
    for (final o in options) {
      if (o.id == id) return o.name;
    }
    return AppLocalizations.of(context).aaUnknownUser;
  }

  /// 切换某参与人勾选态;支出人锁定不可反选。
  void _toggleParticipant(String id) {
    if (id == _paidById) return;
    setState(() {
      final selected = _participantIds ?? <String>{};
      if (!selected.remove(id)) {
        selected.add(id);
      }
      // 选中集合覆盖全部 options → 视为「全部成员」(落 null);
      // 否则保留具体名单。
      _participantIds = selected.length == _currentOptionsLength
          ? null
          : selected;
      // 指定分摊:切到人均补默认人均金额(避免空金额阻断)
      if (_mode == AaMode.custom) {
        final hasAnyAmount = _effectiveParticipants(_lastOptions).any(
            (id) => (_amountCtrls[id]?.text.trim() ?? '').isNotEmpty);
        if (!hasAnyAmount) {
          _fillPerPersonAmounts(_lastOptions);
        }
      }
    });
  }

  /// 当前 options 快照(供 _toggleParticipant 内部判断全覆盖用)。
  List<AaParticipantOption> _lastOptions = const [];

  int get _currentOptionsLength => _lastOptions.length;

  /// 单点循环切换分摊方式:人均 → 不分摊 → 指定 → 人均。
  ///
  /// 与记账编辑器保持一致的循环顺序与切换语义。
  void _cycleAaMode() {
    setState(() {
      _mode = switch (_mode) {
        AaMode.perPerson => AaMode.noSplit,
        AaMode.noSplit => AaMode.custom,
        AaMode.custom => AaMode.perPerson,
      };
      _syncAmountControllers(_lastOptions);
      // 从不分摊/人均切到指定分摊:金额栏为空时默认填人均金额。
      if (_mode == AaMode.custom) {
        final hasAnyAmount = _effectiveParticipants(_lastOptions).any(
            (id) => (_amountCtrls[id]?.text.trim() ?? '').isNotEmpty);
        if (!hasAnyAmount) {
          _fillPerPersonAmounts(_lastOptions);
        }
      }
    });
  }

  /// 已填指定金额合计(Decimal 精确累加,避免浮点尾差)。
  double _filledSum() {
    var sum = Decimal.zero;
    for (final c in _amountCtrls.values) {
      final v = double.tryParse(c.text.trim());
      if (v != null) sum += toDecimal2(v);
    }
    return toDouble(sum);
  }

  /// 完成:校验并 pop [AaEditResult]。
  ///
  /// 不分摊:直接 pop(aaMode=1,无参与人/支出人/指定金额)。
  /// 指定分摊校验:每人金额必填;合计 ≠ 交易金额时偏差按支出人
  /// 兜底修正(支出人应摊 += 差额),修正后为负则阻断。
  void _onConfirm(List<AaParticipantOption> options) {
    final l10n = AppLocalizations.of(context);

    if (_mode == AaMode.noSplit) {
      Navigator.of(context).pop(const AaEditResult(
        paidByUserId: null,
        aaMode: 1,
        aaParticipants: null,
        aaSplits: null,
      ));
      return;
    }

    final participants = _effectiveParticipants(options);
    if (participants.isEmpty) {
      showToast(context, l10n.aaNoParticipants);
      return;
    }
    final paidBy = _paidById ?? participants.first;

    if (_mode == AaMode.perPerson) {
      Navigator.of(context).pop(AaEditResult(
        paidByUserId: paidBy,
        aaMode: 0,
        // 全选(null)落 null,运行时展开;部分选落具体名单。
        aaParticipants: _participantIds == null ? null : participants,
        aaSplits: null,
      ));
      return;
    }

    // 指定分摊:逐人读取金额,空值阻断
    final splits = <String, double>{};
    for (final id in participants) {
      final v = double.tryParse(_amountCtrls[id]?.text.trim() ?? '');
      if (v == null || v < 0) {
        showToast(context, l10n.aaSplitAmountIncomplete);
        return;
      }
      splits[id] = v;
    }

    // 合计校验 = 交易金额,偏差按支出人兜底修正
    final total = toDecimal2(widget.args.amount);
    var sum = Decimal.zero;
    for (final v in splits.values) {
      sum += toDecimal2(v);
    }
    final diff = total - sum;
    final halfCent = Decimal.parse('0.005');
    final absDiff = diff < Decimal.zero ? -diff : diff;
    if (absDiff >= halfCent) {
      if (!splits.containsKey(paidBy)) {
        showToast(context, l10n.aaSplitAmountIncomplete);
        return;
      }
      final adjusted = toDecimal2(splits[paidBy]!) + diff;
      if (adjusted < Decimal.zero) {
        showToast(context, l10n.aaSplitAmountIncomplete);
        return;
      }
      splits[paidBy] = toDouble(adjusted);
    }

    Navigator.of(context).pop(AaEditResult(
      paidByUserId: paidBy,
      aaMode: 2,
      aaParticipants: participants,
      aaSplits: {
        for (final e in splits.entries) e.key: e.value.toStringAsFixed(2),
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final optionsAsync =
        ref.watch(aaParticipantOptionsProvider(widget.args.ledgerId));
    final options = optionsAsync.valueOrNull ?? const <AaParticipantOption>[];
    _lastOptions = options;
    _initOnce(options);
    if (_initialized) _syncAmountControllers(options);

    final participants = _effectiveParticipants(options);
    // 交易币种缺省时回退账本本位币展示。
    final currencyCode = widget.args.currencyCode ??
        ref.watch(currentLedgerProvider).valueOrNull?.currency;

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.aaEditTitle,
            showBack: true,
          ),
          Expanded(
            child: optionsAsync.isLoading && options.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSubjectCard(context, l10n, currencyCode),
                      if (_mode != AaMode.noSplit) ...[
                        const SizedBox(height: 16),
                        _buildSplitCard(
                            context, l10n, options, participants, currencyCode),
                      ],
                    ],
                  ),
          ),
          _buildConfirmBar(context, l10n, options),
        ],
      ),
    );
  }

  /// 主体信息只读卡:icon + 类目 / 日期 / 金额 / 货币 / 分摊方式三态切换。
  ///
  /// 样式与记账详情头部模块对齐:顶部 icon+类目,分隔线,日期、金额、货币,
  /// 最后一行「分摊方式」标题 + 三态切换 toggle(与记账编辑器一致,可点击切换)。
  Widget _buildSubjectCard(
      BuildContext context, AppLocalizations l10n, String? currencyCode) {
    final d = widget.args.date.toLocal();
    final dateText =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final primary = Theme.of(context).colorScheme.primary;
    final iconData = resolveCategoryIcon(widget.args.categoryIconName);

    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部:icon + 类目(只读)
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SpitoutTokens.surfaceSecondary(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, size: 20, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  CategoryUtils.getDisplayName(
                      widget.args.categoryName, context),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: SpitoutTokens.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          _cardDivider(context),
          // 日期(只读)
          _infoRow(context, l10n.homeDetailDate, dateText),
          // 金额(只读)
          _infoRow(
            context,
            l10n.homeDetailAmount,
            '',
            valueWidget: AmountText(
              value: widget.args.amount,
              signed: false,
              showCurrency: false,
              decimals: 2,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SpitoutTokens.textPrimary(context),
              ),
            ),
          ),
          // 货币(只读)
          if (widget.args.currencyCode != null &&
              widget.args.currencyCode!.isNotEmpty)
            _infoRow(context, l10n.homeDetailCurrency, widget.args.currencyCode!),
          _cardDivider(context),
          // 分摊方式:标题 + 三态切换 toggle(可点击)
          // 固定行高避免切换 toggle 文本宽度变化时主体卡高度自适应跳动。
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Text(
                  l10n.aaSplitMode,
                  style: TextStyle(
                    fontSize: 14,
                    color: SpitoutTokens.textSecondary(context),
                  ),
                ),
                const Spacer(),
                _buildAaModeToggle(context, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 分摊方式切换按钮:固定宽度,左右箭头 + 中间方式文本,单点循环切换。
  ///
  /// 样式与记账编辑器 [TransactionEditorSheet._buildAaModeToggle] 完全一致,
  /// 保证两处切换体验统一。
  Widget _buildAaModeToggle(BuildContext context, AppLocalizations l10n) {
    final modeText = switch (_mode) {
      AaMode.perPerson => l10n.aaModePerPerson,
      AaMode.noSplit => l10n.aaModeNoSplit,
      AaMode.custom => l10n.aaModeCustom,
    };
    final borderColor =
        SpitoutTokens.textTertiary(context).withValues(alpha: 0.35);
    final arrowColor = SpitoutTokens.iconTertiary(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _cycleAaMode,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 64,
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Icon(AppIcons.chevronLeft, size: 8, color: arrowColor),
              Expanded(
                child: Text(
                  modeText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: SpitoutTokens.textTertiary(context),
                  ),
                ),
              ),
              Icon(AppIcons.chevronRight, size: 8, color: arrowColor),
            ],
          ),
        ),
      ),
    );
  }

  /// 分摊配置卡:支出人 + 合计 + 参与人列表(页内直接勾选 + 金额输入框)。
  ///
  /// 人均分摊:参与人勾选决定均摊人数,金额输入框置灰、实时重算展示;
  /// 指定分摊:每人金额可填,合计偏差按支出人兜底。
  /// 支出人置顶置灰(锁定勾选、icon/名称置灰,金额输入框若未勾选则置灰不可操作)。
  Widget _buildSplitCard(
    BuildContext context,
    AppLocalizations l10n,
    List<AaParticipantOption> options,
    List<String> participants,
    String? currencyCode,
  ) {
    final total = widget.args.amount;
    final sum = _filledSum();
    final diff = total - sum;
    final balanced = diff.abs() < 0.005;

    // 合计行的合计值:人均分摊按勾选人数均摊(展示用);
    // 指定分摊按已填金额累加。两者在 _filledSum 内统一处理(人均时控制器
    // 已被 _fillPerPersonAmounts 填充,故合计 = 总额;切人或切模式时实时重算)。
    final displaySum = _mode == AaMode.perPerson ? total : sum;

    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // 支出人(bottom sheet 选择)
          _buildPayerRow(context, l10n, options),
          _cardDivider(context),
          // 合计行(放在参与人列表最上方)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(
                  l10n.aaSplitTotal,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SpitoutTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${formatMoneyWithCurrency(displaySum, currencyCode: currencyCode)}'
                  ' / ${formatMoneyWithCurrency(total, currencyCode: currencyCode)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _mode == AaMode.perPerson || balanced
                        ? SpitoutTokens.success(context)
                        : SpitoutTokens.warning(context),
                  ),
                ),
              ],
            ),
          ),
          // 参与人列表:支出人置顶置灰,其余按 options 顺序。
          // 逐行:方框勾选 + 名称 + 右对齐金额输入框。
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) _cardDivider(context),
            _buildParticipantRow(
                context, options, options[i], currencyCode),
          ],
        ],
      ),
    );
  }

  /// 支出人导航行:点击弹 bottom sheet 选择。
  Widget _buildPayerRow(BuildContext context, AppLocalizations l10n,
      List<AaParticipantOption> options) {
    final payerName = _paidById == null
        ? l10n.aaUnknownUser
        : _optionName(options, _paidById!);
    return InkWell(
      onTap: () async {
        final picked = await showAaPayerPickerSheet(
          context,
          options: options,
          selectedId: _paidById,
        );
        if (picked != null && picked != _paidById) {
          setState(() {
            _paidById = picked;
            // 支出人必是参与人:新支出人若不在已选名单内,自动补入。
            if (_participantIds != null &&
                !_participantIds!.contains(picked)) {
              _participantIds = {..._participantIds!, picked};
              _syncAmountControllers(options);
            }
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(
              l10n.aaPayer,
              style: TextStyle(
                fontSize: 15,
                color: SpitoutTokens.textPrimary(context),
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                payerName,
                style: TextStyle(
                  fontSize: 14,
                  color: SpitoutTokens.textSecondary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              AppIcons.chevronRight,
              size: 16,
              color: SpitoutTokens.iconTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 单个参与人行:方框勾选 + 名称 + 右对齐金额输入框。
  ///
  /// 支出人:置顶置灰(勾选锁定、icon 与名称置灰、金额输入框可填但不可取消勾选)。
  /// 未勾选的参与人:金额输入框置灰不可操作。
  /// 人均分摊:金额输入框置灰只读,值随勾选人数实时重算。
  Widget _buildParticipantRow(
    BuildContext context,
    List<AaParticipantOption> options,
    AaParticipantOption option,
    String? currencyCode,
  ) {
    final isPayer = option.id == _paidById;
    final selected = _participantIds == null
        ? true
        : _participantIds!.contains(option.id);
    final primary = Theme.of(context).colorScheme.primary;
    final tertiary = SpitoutTokens.textTertiary(context);

    // 人均分摊:按勾选人数实时均摊。
    final perPersonAmount = _mode == AaMode.perPerson
        ? _computePerPerson(options)
        : null;

    // 名称颜色:支出人/未勾选 → 置灰;已勾选 → 一级色。
    final nameColor = (isPayer || !selected)
        ? tertiary
        : SpitoutTokens.textPrimary(context);

    // 金额输入框可用性:
    // - 支出人:可填(指定分摊);人均置灰展示
    // - 未勾选:置灰不可操作
    // - 人均:全部置灰只读
    final amountEnabled = !isPayer &&
        selected &&
        _mode == AaMode.custom;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 方框勾选:支出人锁定不可反选
          _buildCheckbox(
            context,
            checked: selected,
            locked: isPayer,
            onTap: isPayer ? null : () => _toggleParticipant(option.id),
          ),
          const SizedBox(width: 10),
          // icon + 名称(支出人/未勾选置灰)
          Icon(
            AppIcons.person,
            size: 16,
            color: (isPayer || !selected) ? tertiary : primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.name,
              style: TextStyle(
                fontSize: 15,
                color: nameColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // 金额输入框 / 展示
          SizedBox(
            width: 120,
            child: _mode == AaMode.perPerson
                ? _readOnlyAmount(
                    context,
                    perPersonAmount ?? 0,
                    dimmed: !selected,
                  )
                : TextField(
                    controller: _amountCtrls[option.id],
                    enabled: amountEnabled,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: amountEnabled
                          ? SpitoutTokens.textPrimary(context)
                          : tertiary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: tertiary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: amountEnabled
                          ? SpitoutTokens.surfaceInput(context)
                          : SpitoutTokens.surfaceSecondary(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
          ),
        ],
      ),
    );
  }

  /// 方框勾选组件:未选空方框,选中实心带勾,锁定态不可点击但仍展示选中。
  Widget _buildCheckbox(
    BuildContext context, {
    required bool checked,
    bool locked = false,
    VoidCallback? onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor = checked
        ? primary
        : SpitoutTokens.textTertiary(context).withValues(alpha: 0.5);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: checked ? primary : Colors.transparent,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: checked
            ? Icon(AppIcons.check, size: 14, color: Colors.white)
            : null,
      ),
    );
  }

  /// 人均分摊金额展示(只读,未勾选置灰)。
  Widget _readOnlyAmount(
    BuildContext context,
    double value,
    {required bool dimmed}
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: SpitoutTokens.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value.toStringAsFixed(2),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: dimmed
              ? SpitoutTokens.textTertiary(context)
              : SpitoutTokens.textPrimary(context),
        ),
      ),
    );
  }

  /// 按当前勾选人数计算人均金额(总额 / 已勾选人数,保留两位小数)。
  double _computePerPerson(List<AaParticipantOption> options) {
    final n = _effectiveParticipants(options).length;
    if (n == 0) return 0;
    return widget.args.amount / n;
  }

  /// 主体卡信息行(只读):左标签 + 右值。
  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    Widget? valueWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: SpitoutTokens.textSecondary(context),
            ),
          ),
          Flexible(
            child: valueWidget ??
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: SpitoutTokens.textPrimary(context),
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
        ],
      ),
    );
  }

  /// 底部完成按钮(返回 result;取消走系统返回/pop null)。
  Widget _buildConfirmBar(BuildContext context, AppLocalizations l10n,
      List<AaParticipantOption> options) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: FilledButton(
        onPressed: () => _onConfirm(options),
        child: Text(l10n.commonFinish),
      ),
    );
  }

  Widget _cardDivider(BuildContext context) => Divider(
        height: 1,
        thickness: 0.5,
        color: SpitoutTokens.divider(context),
      );
}
