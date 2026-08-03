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
import '../../widgets/widgets.dart';

/// AA 分摊编辑页(纯选择器,不写库)。
///
/// 职责(文档 §6.3):
/// - 只读展示主体信息(金额 / 分类 / 日期,不可改);
/// - 编辑支出人、分摊方式、参与人、指定金额;
/// - 合计校验 = 交易金额,偏差按支出人兜底修正(§10.3);
/// - pop 返回 [AaEditResult](null = 取消),不落库、不触发任何 sync 登记,
///   由编辑器(模型 B')收到 result 后一次性写入全部字段。
///
/// 虚拟用户管理入口在参与人区(新建 / 重命名 / 删除,名下有账不可删)。
class AaEditPage extends ConsumerStatefulWidget {
  final AaEditPageArgs args;

  const AaEditPage({super.key, required this.args});

  @override
  ConsumerState<AaEditPage> createState() => _AaEditPageState();
}

class _AaEditPageState extends ConsumerState<AaEditPage> {
  /// 分摊方式(人均 / 指定)。
  late AaMode _mode = widget.args.mode == AaMode.custom
      ? AaMode.custom
      : AaMode.perPerson;

  /// 支出人标识;null 时取参与人列表首个兜底(展示层空串降级"未知")。
  String? _paidById;

  /// 参与人标识列表;null = 全部成员(运行时展开)。
  List<String>? _participantIds;

  /// 指定金额输入控制器(key=参与人标识),随参与人变化同步增删。
  final Map<String, TextEditingController> _amountCtrls = {};

  /// 参与人选项异步加载完成后只初始化一次(避免用户输入被流刷新覆盖)。
  bool _initialized = false;

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 参与人选项到达后的首次初始化:支出人兜底、指定金额回填。
  void _initOnce(List<AaParticipantOption> options) {
    if (_initialized || options.isEmpty) return;
    _initialized = true;
    // 支出人:初值优先,其次参与人首个(文档 §6.3 兜底逻辑)。
    _paidById = widget.args.paidByUserId ?? options.first.id;
    _participantIds = widget.args.participantIds;
    _syncAmountControllers(options);
    // 编辑模式回填既有指定金额。
    widget.args.splits?.forEach((id, amount) {
      _amountCtrls[id]?.text = amount;
    });
  }

  /// 按当前参与人集合同步金额输入控制器:新增补空控制器,移除释放。
  void _syncAmountControllers(List<AaParticipantOption> options) {
    final ids = _effectiveParticipants(options);
    for (final id in ids) {
      _amountCtrls.putIfAbsent(id, () => TextEditingController());
    }
    final stale = _amountCtrls.keys.where((k) => !ids.contains(k)).toList();
    for (final k in stale) {
      _amountCtrls.remove(k)?.dispose();
    }
  }

  /// 当前生效的参与人集合:未选(null) = 全部成员。
  List<String> _effectiveParticipants(List<AaParticipantOption> options) =>
      _participantIds ?? options.map((o) => o.id).toList();

  String _optionName(List<AaParticipantOption> options, String id) {
    for (final o in options) {
      if (o.id == id) return o.name;
    }
    // 参与人标识查不到(如虚拟用户已删)按"未知"降级展示。
    return AppLocalizations.of(context).aaUnknownUser;
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
  /// 指定分摊校验(§10.3):每人金额必填;合计 ≠ 交易金额时偏差按支出人
  /// 兜底修正(支出人应摊 += 差额),修正后为负则阻断。
  void _onConfirm(List<AaParticipantOption> options) {
    final l10n = AppLocalizations.of(context);
    final participants = _effectiveParticipants(options);
    if (participants.isEmpty) {
      showToast(context, l10n.aaNoParticipants);
      return;
    }
    // 支出人缺省时取参与人首个兜底,保证 result 支出人非空。
    final paidBy = _paidById ?? participants.first;

    if (_mode == AaMode.perPerson) {
      Navigator.of(context).pop(AaEditResult(
        paidByUserId: paidBy,
        aaMode: 0,
        aaParticipants: _participantIds,
        aaSplits: null,
      ));
      return;
    }

    // —— 指定分摊:逐人读取金额,空值阻断 ——
    final splits = <String, double>{};
    for (final id in participants) {
      final v = double.tryParse(_amountCtrls[id]?.text.trim() ?? '');
      if (v == null || v < 0) {
        showToast(context, l10n.aaSplitAmountIncomplete);
        return;
      }
      splits[id] = v;
    }

    // 合计校验 = 交易金额,偏差按支出人兜底修正(§10.3)。
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
        // 支出人不在参与人内,无法兜底,阻断并提示逐人核对金额。
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
      // 金额一律存字符串(文档 §1.1.8),与落库 JSON 口径一致。
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
                      const SizedBox(height: 16),
                      _buildSettingCard(context, l10n, options),
                      if (_mode == AaMode.custom) ...[
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

  /// 主体信息只读卡:金额(大字号居中) + 分类 · 日期(不可改)。
  Widget _buildSubjectCard(
      BuildContext context, AppLocalizations l10n, String? currencyCode) {
    final d = widget.args.date.toLocal();
    final dateText =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          AmountText(
            value: widget.args.amount,
            signed: false,
            showCurrency: true,
            currencyCode: currencyCode,
            decimals: 2,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: SpitoutTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.args.categoryName} · $dateText',
            style: TextStyle(
              fontSize: 13,
              color: SpitoutTokens.textSecondary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 分摊设置卡:支出人 / 分摊方式 / 参与人 / 虚拟用户管理入口。
  Widget _buildSettingCard(BuildContext context, AppLocalizations l10n,
      List<AaParticipantOption> options) {
    final payerName = _paidById == null
        ? l10n.aaUnknownUser
        : _optionName(options, _paidById!);
    final modeText = _mode == AaMode.custom
        ? l10n.aaModeCustom
        : l10n.aaModePerPerson;
    final participantsText = _participantIds == null
        ? l10n.aaParticipantsAll
        : l10n.aaParticipantsSelected(_participantIds!.length);

    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _buildNavRow(
            context,
            label: l10n.aaPayer,
            value: payerName,
            onTap: () async {
              final picked = await showAaPayerPickerSheet(
                context,
                options: options,
                selectedId: _paidById,
              );
              if (picked != null) setState(() => _paidById = picked);
            },
          ),
          _cardDivider(context),
          _buildNavRow(
            context,
            label: l10n.aaSplitMode,
            value: modeText,
            onTap: () async {
              final picked =
                  await showAaModePickerSheet(context, selected: _mode);
              if (picked != null && picked != _mode) {
                setState(() {
                  _mode = picked;
                  _syncAmountControllers(options);
                });
              }
            },
          ),
          _cardDivider(context),
          _buildNavRow(
            context,
            label: l10n.aaParticipants,
            value: participantsText,
            onTap: () async {
              final picked = await showAaParticipantPickerSheet(
                context,
                options: options,
                initialSelectedIds: _participantIds,
              );
              if (picked != null) {
                setState(() {
                  _participantIds = picked.all ? null : picked.ids;
                  _syncAmountControllers(options);
                });
              }
            },
          ),
          _cardDivider(context),
          _buildNavRow(
            context,
            label: l10n.aaVirtualUserTitle,
            value: '',
            onTap: () async {
              await showVirtualUserManageSheet(context,
                  ledgerId: widget.args.ledgerId);
              // 虚拟用户增删改后重取参与人选项,并同步金额输入行。
              ref.invalidate(
                  aaParticipantOptionsProvider(widget.args.ledgerId));
            },
          ),
        ],
      ),
    );
  }

  /// 指定金额卡:逐人金额输入 + 合计校验行。
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
    // 差额容差 0.005(半分):小于视为已配平。
    final balanced = diff.abs() < 0.005;

    return SectionCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < participants.length; i++) ...[
            if (i > 0) _cardDivider(context),
            _buildAmountRow(
                context, options, participants[i], currencyCode),
          ],
          _cardDivider(context),
          // 合计校验行:合计 vs 交易金额;未配平时差额按支出人兜底(§10.3)。
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.aaSplitTotal,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SpitoutTokens.textPrimary(context),
                        ),
                      ),
                      if (!balanced)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l10n.aaSplitPayerAdjustHint,
                            style: TextStyle(
                              fontSize: 11,
                              color: SpitoutTokens.warning(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${formatMoneyWithCurrency(sum, currencyCode: currencyCode)}'
                  ' / ${formatMoneyWithCurrency(total, currencyCode: currencyCode)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: balanced
                        ? SpitoutTokens.success(context)
                        : SpitoutTokens.warning(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单个参与人金额输入行。
  Widget _buildAmountRow(BuildContext context,
      List<AaParticipantOption> options, String id, String? currencyCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _optionName(options, id),
              style: TextStyle(
                fontSize: 15,
                color: SpitoutTokens.textPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _amountCtrls[id],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // 金额输入限制:非负、最多两位小数,与落库精度一致。
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: SpitoutTokens.textPrimary(context),
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: SpitoutTokens.textTertiary(context),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: SpitoutTokens.surfaceInput(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              // 输入变化驱动合计行刷新。
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  /// 设置卡导航行:左标签 + 右值 + 右箭头。
  Widget _buildNavRow(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: SpitoutTokens.textPrimary(context),
              ),
            ),
            const Spacer(),
            if (value.isNotEmpty)
              Flexible(
                child: Text(
                  value,
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
