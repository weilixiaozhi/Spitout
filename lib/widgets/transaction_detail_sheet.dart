import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/logger_service.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'package:spitout/providers/statistics/record_history_providers.dart';
import 'package:spitout/providers/providers.dart'
    show
        currentLedgerProvider,
        expenseColorSchemeProvider,
        ledgerVirtualUsersProvider;
import 'package:spitout/providers/sync/cloud_client_providers.dart'
    show cloudCurrentUserProvider;
import 'package:spitout/providers/ui/theme_providers.dart'
    show displayNameProvider;
import 'package:spitout/core/identity/local_user_identity.dart'
    show localSelfIdProvider;
import '../services/statistics/aa_statistics_service.dart' show AaMode;
import '../theme/colors.dart';
import 'category_icon.dart';
import 'currency_flag.dart';
import 'app_sheet.dart';
import 'format_money.dart';
import 'amount_text.dart';
import 'me_suffix.dart';
import 'user_display_name_resolver.dart';
import '../theme/icons/app_icons.dart';

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
///
/// [aaEnabled] 账本是否开启分摊。开启时底部常驻「编辑分摊(左) + 编辑记账(右)」,
/// 未开启时底部仅常驻「编辑记账」;删除 icon 始终置于右上角 trailing。
///
/// [onEditAa] 编辑分摊回调;仅 [aaEnabled] 为 true 时使用,跳 [AaEditPage]。
/// 不分摊的交易也允许进入,默认选中不分摊,在页内可切到其他分摊方式。
Future<void> showTransactionDetailSheet({
  required BuildContext context,
  required Transaction transaction,
  required Category? category,
  required Map<String, SpitoutCloudLedgerMember> memberDisplayMap,
  String? localOwnerDisplayName,
  bool aaEnabled = false,
  required Future<void> Function() onEdit,
  Future<void> Function()? onEditAa,
  required Future<void> Function() onDelete,
}) {
  return showAppSheet<void>(
    context: context,
    child: _TransactionDetailBody(
      transaction: transaction,
      category: category,
      memberDisplayMap: memberDisplayMap,
      localOwnerDisplayName: localOwnerDisplayName,
      aaEnabled: aaEnabled,
      onEdit: onEdit,
      onEditAa: onEditAa,
      onDelete: onDelete,
    ),
  );
}

class _TransactionDetailBody extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Map<String, SpitoutCloudLedgerMember> memberDisplayMap;
  final String? localOwnerDisplayName;

  /// 账本是否开启分摊。决定底部按钮态(单/双)与右上角删除 icon 是否影响布局。
  final bool aaEnabled;
  final Future<void> Function() onEdit;

  /// 编辑分摊回调;仅 [aaEnabled] 为 true 时使用。
  final Future<void> Function()? onEditAa;
  final Future<void> Function() onDelete;

  const _TransactionDetailBody({
    required this.transaction,
    required this.category,
    required this.memberDisplayMap,
    this.localOwnerDisplayName,
    this.aaEnabled = false,
    required this.onEdit,
    this.onEditAa,
    required this.onDelete,
  });

  /// 格式化日期时间为本地 yyyy-MM-dd HH:mm。
  String _fmt(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  /// 构建用户展示名解析器(同步读缓存值,sheet 打开时 provider 已就绪)。
  ///
  /// 统一解析 userId → 展示名,修复「同一账号在不同账本显示为 id/邮箱/昵称混用」:
  /// memberDisplayMap → 当前登录用户(userId 命中 cloudUserId)→ localSelfId → 虚拟用户 → 兜底。
  UserDisplayNameResolver _buildResolver(
    WidgetRef ref,
    AppLocalizations l10n,
    Map<String, String> virtualNames,
  ) {
    // 同步读取缓存值:这些 provider 在 app 启动后早已解析,sheet 打开时必然命中缓存。
    // 若极端情况下未就绪(首次启动极早期),asData?.value 返回 null,解析器走兜底逻辑。
    final localSelfId = ref.read(localSelfIdProvider).asData?.value ?? '';
    final currentUser = ref.read(cloudCurrentUserProvider).asData?.value;
    final localName = localOwnerDisplayName ?? ref.read(displayNameProvider);
    return UserDisplayNameResolver(
      memberDisplayMap: memberDisplayMap,
      localOwnerDisplayName: localName,
      localSelfId: localSelfId,
      currentUser: currentUser,
      virtualNames: virtualNames,
      l10n: l10n,
    );
  }

  /// 解析 aaParticipants(JSON 数组字符串);空 / 解析失败返回 null(全部成员)。
  List<String>? _parseAaIdList(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return (jsonDecode(json) as List).map((e) => e.toString()).toList();
    } catch (e, st) {
      logger.warning(
          'TransactionDetailSheet', '解析 aaParticipants 失败', '$e\n$st');
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

  /// AA 分摊明细区块(只读,与编辑分摊页对齐)。
  ///
  /// 布局:分摊方式 / 支出人 / 参与人 三行,均为只读信息行。
  /// - 分摊方式:不分摊/人均分摊/指定分摊(右对齐值);
  /// - 参与人:昵称前若干人逗号隔开,剩余以「…(x人)」省略;全选显示「全部成员(x人)」。
  /// 指定分摊时仍逐人展示金额行(只读),与人均保持区块结构一致。
  List<Widget> _buildAaSection(
    BuildContext context,
    AppLocalizations l10n,
    Transaction t,
    UserDisplayNameResolver resolver,
  ) {
    final mode = AaMode.fromDb(t.aaMode);
    final currency =
        t.currencyCode?.trim().isNotEmpty == true ? t.currencyCode! : 'CNY';
    final widgets = <Widget>[
      const _Divider(),
      _SectionLabel(text: l10n.aaSplitMode),
      // 分摊方式(右对齐值)
      _InfoRow(
        label: l10n.aaSplitMode,
        value: mode == AaMode.custom
            ? l10n.aaModeCustom
            : mode == AaMode.perPerson
                ? l10n.aaModePerPerson
                : l10n.aaModeNoSplit,
      ),
    ];
    // 支出人:本人追加「(我)」共享后缀(样式与成员管理/AA 记账页一致),
    // 非本人仍用纯文本;unknown 时不追加后缀。
    final paidById = t.paidByUserId;
    final paidByName = resolver.resolve(paidById);
    final paidByNameDisplay =
        paidByName.isEmpty ? l10n.aaUnknownUser : paidByName;
    widgets.add(_InfoRow(
      label: l10n.aaPayer,
      value: paidByNameDisplay,
      valueWidget: paidByName.isNotEmpty && resolver.isSelf(paidById)
          ? _infoRichValue(context, paidByNameDisplay,
              isSelf: true, l10n: l10n)
          : null,
    ));
    if (mode == AaMode.noSplit) {
      return widgets;
    }
    // 参与人展示:昵称前若干人逗号隔开,剩余「…(x人)」;全选显示「全部成员(x人)」。
    // 用富文本逐名渲染,本人名字后追加「(我)」共享后缀。
    final ids = _parseAaIdList(t.aaParticipants);
    widgets.add(_InfoRow(
      label: l10n.aaParticipants,
      value: '',
      valueWidget: _participantsValue(context, l10n, ids, resolver),
    ));
    if (mode == AaMode.custom) {
      // 指定分摊:逐人金额(只读);label 为参与人名,本人时同样追加后缀。
      final splits = _parseAaSplits(t.aaSplits);
      for (final e in splits.entries) {
        final name = resolver.resolve(e.key);
        final nameDisplay = name.isEmpty ? l10n.aaUnknownUser : name;
        widgets.add(_InfoRow(
          label: nameDisplay,
          labelWidget: name.isNotEmpty && resolver.isSelf(e.key)
              ? _labelRichValue(context, nameDisplay,
                  isSelf: true, l10n: l10n)
              : null,
          value: formatMoneyWithCurrency(double.tryParse(e.value) ?? 0,
              currencyCode: currency),
        ));
      }
    }
    return widgets;
  }

  /// 构建信息行右对齐值样式(与 [_InfoRow] 默认值一致)。
  TextStyle _infoValueStyle(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: SpitoutTokens.textPrimary(context),
      );

  /// 构建信息行 label 样式(与 [_InfoRow] 默认 label 一致)。
  TextStyle _infoLabelStyle(BuildContext context) => TextStyle(
        fontSize: 14,
        color: SpitoutTokens.textSecondary(context),
      );

  /// 构建带「(我)」共享后缀的右对齐富文本值。
  ///
  /// [text] 为纯名;本人标记通过 [isSelf] 传入,由 [meSuffixSpan] 渲染
  /// 统一样式的「(我)」后缀,避免整体字符串拼接导致样式不一致。
  Widget _infoRichValue(BuildContext context, String text,
      {required bool isSelf, required AppLocalizations l10n}) {
    return Text.rich(
      TextSpan(
        text: text,
        style: _infoValueStyle(context),
        children: [if (isSelf) meSuffixSpan(context, l10n)],
      ),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建带「(我)」共享后缀的 label 富文本(指定分摊行的参与人名)。
  Widget _labelRichValue(BuildContext context, String text,
      {required bool isSelf, required AppLocalizations l10n}) {
    return Text.rich(
      TextSpan(
        text: text,
        style: _infoLabelStyle(context),
        children: [if (isSelf) meSuffixSpan(context, l10n)],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建参与人展示组件:昵称前若干人逗号隔开,剩余以「…(x人)」省略。
  ///
  /// 全选([ids]==null)时显示「全部成员」;否则展示前 2 人 + 「…(x人)」。
  /// 富文本逐名渲染,本人名字后追加「(我)」共享后缀。
  Widget _participantsValue(
    BuildContext context,
    AppLocalizations l10n,
    List<String>? ids,
    UserDisplayNameResolver resolver,
  ) {
    final style = _infoValueStyle(context);
    if (ids == null || ids.isEmpty) {
      return Text(l10n.aaParticipantsAll,
          style: style,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
    }
    final count = ids.length;
    final headCount = count <= 2 ? count : 2;
    final spans = <TextSpan>[];
    for (var i = 0; i < headCount; i++) {
      final id = ids[i];
      final name = resolver.resolve(id);
      final display = name.isEmpty ? l10n.aaUnknownUser : name;
      if (i > 0) spans.add(TextSpan(text: '、'));
      spans.add(TextSpan(
        text: display,
        children: [if (resolver.isSelf(id)) meSuffixSpan(context, l10n)],
      ));
    }
    final tail = count <= 2
        ? '（$count${l10n.aaParticipantsUnit}）'
        : '…（${count - 2}${l10n.aaParticipantsUnit}）';
    spans.add(TextSpan(text: tail));
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = transaction;
    final historyAsync = ref.watch(recordEditHistoryProvider(t.id));
    final categoryName = category?.name ?? l10n.homeDetailCategory;
    // 账本是否开启分摊由调用方传入,详情 sheet 不再重复读取账本 provider,
    // 避免与首页/分类详情页的口径分歧;AA 区块的展示仍按当前交易分摊态渲染。
    final aaOn = aaEnabled;

    // 虚拟成员 标识→名称;真实成员走 memberDisplayMap。
    final virtualNames = <String, String>{
      for (final v
          in ref.watch(ledgerVirtualUsersProvider(t.ledgerId)).valueOrNull ??
              const [])
        v.syncId ?? 'vu_${v.id}': v.name,
    };
    // 统一展示名解析器:修复 id/邮箱/昵称混用,统一走 memberDisplayMap→
    // 当前登录用户→localSelfId→虚拟用户→兜底。
    final resolver = _buildResolver(ref, l10n, virtualNames);

    return AppSheet(
      // 删除 icon 内嵌到内容区分类标题行右侧(与分类标题同行对齐),
      // 不再用 AppSheet.trailing,避免 trailing 单独成行撑高 header、
      // 与分类标题错位。
      footer: aaOn
          ? Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await onEditAa?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.aaEditSplitButton),
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
            ])
          // 未开启分摊时仅剩「编辑记账」一个按钮,需占满整行宽度,与
          // 开启分摊时的双按钮布局(两个 Expanded)在视觉宽度上保持一致。
          : SizedBox(
              width: double.infinity,
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
      // 内容区:超出弹层可用高度时内部滚动,保证标题栏 trailing 与底部操作
      // 按钮始终常驻可见(账本开启分摊后内容行数更多,小屏/测试视口下可能放不下,
      // 用 SingleChildScrollView 吸收垂直溢出,避免被 Flexible 截断)。
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 头部:分类图标 + 分类名 + 备注 + 右侧删除 icon
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
                // 删除 icon:与分类标题同行右对齐,shrinkWrap 不撑高行
                _DeleteTrailingIcon(onTap: () async {
                  Navigator.pop(context);
                  await onDelete();
                }),
              ],
            ),
            const SizedBox(height: 12),
            _Divider(),
            // 2. 信息区
            _InfoRow(label: l10n.homeDetailDate, value: _fmt(t.happenedAt)),
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
                  color: ref.watch(expenseColorSchemeProvider) == 'green'
                      ? SpitoutTokens.success(context)
                      : SpitoutTokens.error(context),
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
                  value:
                      '≈ ${formatMoneyWithCurrency(t.nativeAmount!, currencyCode: ref.watch(currentLedgerProvider).asData?.value?.currency ?? 'CNY')}'),
            // 2.5 AA 分摊明细(仅账本开启 AA 时展示,功能隔离)
            if (aaOn)
              ..._buildAaSection(
                context,
                l10n,
                t,
                resolver,
              ),
            // 3. 协作成员(共享账本才显示:有 createdBy/lastEditedBy 时)
            if (t.createdByUserId != null || t.lastEditedByUserId != null) ...[
              _Divider(),
              _SectionLabel(text: l10n.homeDetailMembers),
              if (t.createdByUserId != null)
                _MemberRow(
                    label: l10n.homeDetailCreator,
                    name: resolver.resolve(t.createdByUserId),
                    // 本人创建人:追加「(我)」共享后缀,与 AA 区块口径一致。
                    isSelf: resolver.isSelf(t.createdByUserId)),
              if (t.lastEditedByUserId != null)
                _MemberRow(
                    label: l10n.homeDetailLastEditor,
                    name: resolver.resolve(t.lastEditedByUserId),
                    // 本人最后编辑人:同样追加「(我)」共享后缀。
                    isSelf: resolver.isSelf(t.lastEditedByUserId),
                    subtext:
                        t.lastEditedAt != null ? _fmt(t.lastEditedAt!) : null),
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
                  : Column(children: [
                      for (final e in h)
                        _HistoryRow(e, (id) => resolver.resolve(id),
                            // 操作者本人判定:传入后历史行操作者名自动追加「(我)」后缀。
                            isSelfOf: (id) => resolver.isSelf(id))
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
          ],
        ),
      ),
    );
  }
}

/// 右上角删除 icon。吸顶常驻,色用 error token,语义与文案删除按钮一致。
///
/// 设计意图:删除从底部按钮区上移,腾出底部空间给「编辑分摊/编辑记账」双按钮;
/// icon 形式更轻量,不抢底部主操作焦点,符合"删除是次要操作"的语义层级。
class _DeleteTrailingIcon extends StatelessWidget {
  final Future<void> Function() onTap;
  const _DeleteTrailingIcon({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => onTap(),
      icon: Icon(
        AppIcons.delete,
        size: 20,
        color: SpitoutTokens.error(context),
      ),
      // 收紧尺寸:与其他 sheet 顶部 trailing 一致(32px 行高),
      // 不撑大标题栏高度。
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      // shrinkWrap 去除 Material 默认 8px 点击区域额外 padding,
      // 避免 IconButton 实际渲染高度超过 32px 把标题栏顶高、与分类标题错位。
      // materialTapTargetSize 非 IconButton 构造参数(Flutter 3.27 已移除),
      // 通过 style 传递;未设置 style.padding,不影响下方显式 padding。
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      tooltip: AppLocalizations.of(context).commonDelete,
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
  // 自定义值组件(如带币种符号与负号的金额、本人「(我)」富文本);优先于 [value] 渲染。
  final Widget? valueWidget;
  // 自定义 label 组件(如本人「(我)」富文本);优先于 [label] 渲染。
  final Widget? labelWidget;
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueWidget,
    this.labelWidget,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            labelWidget ??
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
  // 是否本人;为真时名字后追加「(我)」共享后缀,与全局规范一致。
  final bool isSelf;
  const _MemberRow({
    required this.label,
    required this.name,
    this.subtext,
    this.isSelf = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: SpitoutTokens.textSecondary(context))),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      text: name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SpitoutTokens.textPrimary(context)),
                      children: [
                        if (isSelf)
                          meSuffixSpan(context, AppLocalizations.of(context)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
  // 操作者是否本人的判定;为真时在操作者名后追加「(我)」共享后缀。
  final bool Function(String?)? isSelfOf;
  const _HistoryRow(this.h, this.displayNameOf, {this.isSelfOf});

  @override
  Widget build(BuildContext context) {
    final operator = displayNameOf(h.operatorUserId);
    final operatorIsSelf = isSelfOf?.call(h.operatorUserId) ?? false;
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
                    child: Text.rich(
                      TextSpan(
                        text: operator,
                        style: TextStyle(
                            fontSize: 11,
                            color: SpitoutTokens.textTertiary(context)),
                        children: [
                          // 本人操作者:追加「(我)」共享后缀,与全局规范一致。
                          if (operatorIsSelf)
                            meSuffixSpan(context, AppLocalizations.of(context)),
                          TextSpan(
                              text: ' · ${_fmtDate(h.createdAt)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: SpitoutTokens.textTertiary(context))),
                        ],
                      ),
                    ),
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
