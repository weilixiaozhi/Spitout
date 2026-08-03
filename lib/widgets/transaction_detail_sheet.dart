import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/identity/local_user_identity.dart';
import '../core/logging/logger_service.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'package:spitout/cloud/spitout_cloud.dart' show SpitoutCloudLedgerMember;
import 'package:spitout/providers/statistics/record_history_providers.dart';
import 'package:spitout/providers/providers.dart' show currentLedgerProvider, expenseColorSchemeProvider, ledgerVirtualUsersProvider;
import '../services/settlement/aa_settlement_service.dart' show AaMode;
import '../theme/colors.dart';
import 'category_icon.dart';
import 'currency_flag.dart';
import 'app_sheet.dart';
import 'format_money.dart';
import 'amount_text.dart';

/// 记录详情 Bottom Sheet(对应设计稿"记录详情 Bottom Sheet")。
///
/// 列表项点击 → 打开本 Sheet(展示详情) → 点"编辑记账"进入编辑器。
/// 详情 Sheet 让用户先看再改,并集中展示协作成员与编辑历史(共享账本场景)。
///
/// [memberDisplayMap] 由调用方从 ledgerMembersProvider 构建(userId→SpitoutCloudLedgerMember),
/// 用于协作成员区块与编辑历史的操作者展示。
///
/// [localOwnerDisplayName] 为本地账本场景下的昵称(取自 displayNameProvider,纯本地、
/// 不依赖云端登录态),当 userId 不在成员表且本地昵称已设置时兜底展示昵称而非 id。
Future<void> showTransactionDetailSheet({
  required BuildContext context,
  required Transaction transaction,
  required Category? category,
  required Map<String, SpitoutCloudLedgerMember> memberDisplayMap,
  String? localOwnerDisplayName,
  required Future<void> Function() onEdit,
  required Future<void> Function() onDelete,
}) {
  return showAppSheet<void>(
    context: context,
    child: _TransactionDetailBody(
      transaction: transaction,
      category: category,
      memberDisplayMap: memberDisplayMap,
      localOwnerDisplayName: localOwnerDisplayName,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _TransactionDetailBody extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Map<String, SpitoutCloudLedgerMember> memberDisplayMap;
  final String? localOwnerDisplayName;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  const _TransactionDetailBody({
    required this.transaction,
    required this.category,
    required this.memberDisplayMap,
    this.localOwnerDisplayName,
    required this.onEdit,
    required this.onDelete,
  });

  /// 展示名四级兜底:共享账本成员表(昵称 → 完整邮箱) → 本地昵称 → 原始 id。
  /// 本地账本无成员表,靠 [localOwnerDisplayName] 展示昵称;未设置昵称时回退 id。
  String _displayName(String? userId, AppLocalizations l10n) {
    if (userId == null || userId.isEmpty) return '';
    // 本地账本未登录云的自我占位:统一映射为本地昵称/「我」,禁止展示字面量 me。
    if (userId == kLocalSelfUserId) {
      final localName = localOwnerDisplayName?.trim() ?? '';
      return localName.isNotEmpty ? localName : l10n.aaMe;
    }
    final member = memberDisplayMap[userId];
    final memberName = member?.displayName?.trim() ?? '';
    if (memberName.isNotEmpty) return memberName;
    // 共享账本成员未设昵称:优先展示完整邮箱而非原始 id,与 AA 区/头像/成员统计口径一致
    final memberEmail = member?.email.trim() ?? '';
    if (memberEmail.isNotEmpty) return memberEmail;
    final localName = localOwnerDisplayName?.trim() ?? '';
    if (localName.isNotEmpty) return localName;
    return userId;
  }

  String _fmt(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  /// 解析 AA 相关标识(真实成员 userId / 虚拟成员标识)为展示名。
  /// 真实成员查 [memberDisplayMap],虚拟成员查 [virtualNames],兜底原始 id。
  String _aaNameOf(
      String? id, Map<String, String> virtualNames, AppLocalizations l10n) {
    if (id == null || id.isEmpty) return l10n.aaUnknownUser;
    // 本地账本未登录云的自我占位:统一映射为本地昵称/「我」,禁止展示字面量 me。
    if (id == kLocalSelfUserId) {
      final localName = localOwnerDisplayName?.trim() ?? '';
      return localName.isNotEmpty ? localName : l10n.aaMe;
    }
    final m = memberDisplayMap[id];
    if (m != null) {
      final dn = m.displayName;
      return (dn != null && dn.isNotEmpty) ? dn : m.email;
    }
    return virtualNames[id] ?? id;
  }

  /// 解析 aaParticipants(JSON 数组字符串);空 / 解析失败返回 null(全部成员)。
  List<String>? _parseAaIdList(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return (jsonDecode(json) as List).map((e) => e.toString()).toList();
    } catch (e, st) {
      logger.warning('TransactionDetailSheet', '解析 aaParticipants 失败', '$e\n$st');
      return null;
    }
  }

  /// 解析 aaSplits(JSON 对象字符串)为 参与人标识 → 金额字符串;失败返回空表。
  Map<String, String> _parseAaSplits(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final obj = jsonDecode(json) as Map<String, dynamic>;
      return {for (final e in obj.entries) e.key: e.value.toString()};
    } catch (e, st) {
      logger.warning('TransactionDetailSheet', '解析 aaSplits 失败', '$e\n$st');
      return const {};
    }
  }

  /// AA 分摊明细区块(人均 / 指定两种样式;不分摊仅标注)。
  ///
  /// 仅账本开启 AA 时由调用方渲染;aaMode=null 按人均展示(向后兼容)。
  List<Widget> _buildAaSection(BuildContext context, AppLocalizations l10n,
      Transaction t, Map<String, String> virtualNames) {
    final mode = AaMode.fromDb(t.aaMode);
    final currency =
        t.currencyCode?.trim().isNotEmpty == true ? t.currencyCode! : 'CNY';
    final widgets = <Widget>[
      const _Divider(),
      _SectionLabel(text: l10n.aaSplitMode),
      _InfoRow(label: l10n.aaPayer, value: _aaNameOf(t.paidByUserId, virtualNames, l10n)),
    ];
    if (mode == AaMode.noSplit) {
      // 不分摊模式:分摊方式展示「不分摊」(与编辑页/列表页展示值保持一致)。
      widgets.add(_InfoRow(
          label: l10n.aaSplitMode, value: l10n.aaModeNoSplit));
      return widgets;
    }
    widgets.add(_InfoRow(
      label: l10n.aaSplitMode,
      value: mode == AaMode.custom ? l10n.aaModeCustom : l10n.aaModePerPerson,
    ));
    if (mode == AaMode.custom) {
      // 指定分摊:逐人金额(aaSplits 的 key = 参与人标识)
      final splits = _parseAaSplits(t.aaSplits);
      for (final e in splits.entries) {
        widgets.add(_InfoRow(
          label: _aaNameOf(e.key, virtualNames, l10n),
          value: formatMoneyWithCurrency(double.tryParse(e.value) ?? 0,
              currencyCode: currency),
        ));
      }
    } else {
      // 人均:参与人为空 = 全部成员(运行时展开)
      final ids = _parseAaIdList(t.aaParticipants);
      widgets.add(_InfoRow(
        label: l10n.aaParticipants,
        value: ids == null
            ? l10n.aaParticipantsAll
            : ids.map((id) => _aaNameOf(id, virtualNames, l10n)).join('、'),
      ));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = transaction;
    final historyAsync = ref.watch(recordEditHistoryProvider(t.id));
    final categoryName = category?.name ?? l10n.homeDetailCategory;

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 头部:分类图标 + 分类名 + 备注
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SpitoutTokens.surfaceSecondary(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CategoryIconWidget(category: category, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(categoryName,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: SpitoutTokens.textPrimary(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (t.note != null && t.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(t.note!,
                            style: TextStyle(
                                fontSize: 13,
                                color: SpitoutTokens.textSecondary(context)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Divider(),
          // 2. 信息区
          _InfoRow(
              label: l10n.homeDetailDate, value: _fmt(t.happenedAt)),
          _InfoRow(
            label: l10n.homeDetailAmount,
            value: formatMoneyCompact(t.amount),
            // 主金额:显示交易原币种 + 原金额(与列表项一致)。
            // 设计意图:记账时的币种和金额不受账本主币种变更影响,
            // currencyCode 为 null(历史数据)时 AmountText 自动回退到账本币种符号。
            valueWidget: AmountText(
              value: (t.type == 'expense' ? -1 : 1) * t.amount,
              signed: true,
              showCurrency: true,
              currencyCode: t.currencyCode,
              decimals: 2,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ref.watch(expenseColorSchemeProvider) == 'green' ? SpitoutTokens.success(context) : SpitoutTokens.error(context),
              ),
            ),
          ),
          if (t.currencyCode != null && t.currencyCode!.isNotEmpty)
            _InfoRow(
                label: l10n.homeDetailCurrency,
                value: t.currencyCode!,
                // 全局统一「ISO + (符号)」展示；右对齐与其他信息行一致
                valueWidget: Align(
                  alignment: Alignment.centerRight,
                  child: currencyFlagLabel(
                    context,
                    t.currencyCode!,
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: SpitoutTokens.textPrimary(context),
                    ),
                  ),
                )),
          if (t.nativeAmount != null && t.nativeAmount != t.amount)
            _InfoRow(
                label: l10n.homeDetailNativeAmount,
                // ≈ 折算金额：符号+金额统一走唯一来源 formatMoneyWithCurrency
                value: '≈ ${formatMoneyWithCurrency(t.nativeAmount!, currencyCode: ref.watch(currentLedgerProvider).asData?.value?.currency ?? 'CNY')}'),
          // 2.5 AA 分摊明细(仅账本开启 AA 时展示,功能隔离)
          if (ref.watch(currentLedgerProvider).valueOrNull?.aaEnabled ??
              false)
            ..._buildAaSection(
              context,
              l10n,
              t,
              // 虚拟成员 标识→名称;真实成员走 memberDisplayMap
              <String, String>{
                for (final v in ref
                        .watch(ledgerVirtualUsersProvider(t.ledgerId))
                        .valueOrNull ??
                    const [])
                  v.syncId ?? 'vu_${v.id}': v.name,
              },
            ),
          // 3. 协作成员(共享账本才显示:有 createdBy/lastEditedBy 时)
          if (t.createdByUserId != null || t.lastEditedByUserId != null) ...[
            _Divider(),
            _SectionLabel(text: l10n.homeDetailMembers),
            if (t.createdByUserId != null)
              _MemberRow(
                  label: l10n.homeDetailCreator,
                  name: _displayName(t.createdByUserId, l10n)),
            if (t.lastEditedByUserId != null)
              _MemberRow(
                  label: l10n.homeDetailLastEditor,
                  name: _displayName(t.lastEditedByUserId, l10n),
                  subtext: t.lastEditedAt != null ? _fmt(t.lastEditedAt!) : null),
          ],
          // 4. 编辑记录(仅供查看)
          _Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              _SectionLabel(text: l10n.homeDetailEditHistory, dense: true),
              const SizedBox(width: 6),
              Text(l10n.homeDetailEditHistoryHint,
                  style: TextStyle(
                      fontSize: 11,
                      color: SpitoutTokens.textTertiary(context))),
            ]),
          ),
          historyAsync.when(
            data: (h) => h.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.homeDetailNoHistory,
                        style: TextStyle(
                            fontSize: 13,
                            color: SpitoutTokens.textTertiary(context))))
                : Column(
                    children: [
                      for (final e in h)
                        _HistoryRow(e, (id) => _displayName(id, l10n))
                    ]),
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)))),
            error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.homeDetailNoHistory,
                    style: TextStyle(
                        fontSize: 13,
                        color: SpitoutTokens.textTertiary(context)))),
          ),
          const SizedBox(height: 16),
          // 5. 底部:删除 + 编辑按钮
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onDelete();
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: SpitoutTokens.error(context),
                    side: BorderSide(
                        color: SpitoutTokens.error(context).withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(l10n.commonDelete),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onEdit();
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(l10n.homeDetailEditButton),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: SpitoutTokens.divider(context));
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool dense;
  const _SectionLabel({required this.text, this.dense = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 0 : 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SpitoutTokens.textSecondary(context))),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  // 自定义值组件(如带币种符号与负号的金额);优先于 [value] 渲染。
  final Widget? valueWidget;
  const _InfoRow(
      {required this.label, required this.value, this.valueWidget});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color: SpitoutTokens.textSecondary(context))),
            Flexible(
              child: valueWidget ??
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: SpitoutTokens.textPrimary(context)),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class _MemberRow extends StatelessWidget {
  final String label;
  final String name;
  final String? subtext;
  const _MemberRow({required this.label, required this.name, this.subtext});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: SpitoutTokens.textSecondary(context))),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SpitoutTokens.textPrimary(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtext != null)
                    Text(subtext!,
                        style: TextStyle(
                            fontSize: 11,
                            color: SpitoutTokens.textTertiary(context))),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 编辑历史行:vN 标签 + 摘要 + 操作者 · 时间。
class _HistoryRow extends StatelessWidget {
  final RecordEditHistory h;
  final String Function(String?) displayNameOf;
  const _HistoryRow(this.h, this.displayNameOf);

  @override
  Widget build(BuildContext context) {
    final operator = displayNameOf(h.operatorUserId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 版本号标签 vN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('v${h.version}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary)),
          ),
          const SizedBox(width: 8),
          // 摘要 + 操作者·时间
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.summary,
                    style: TextStyle(
                        fontSize: 13,
                        color: SpitoutTokens.textPrimary(context)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (operator.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('$operator · ${_fmtDate(h.createdAt)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: SpitoutTokens.textTertiary(context))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
