/// 账本编辑二级页面
///
/// 承载新建 / 编辑（本地+共享）两种模式。
/// 布局参考编辑分类页：PrimaryHeader + Card 模块列表 + 底部保存按钮。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spitout/cloud/spitout_cloud.dart' show CloudBackendType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/providers/providers.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart';
import '../../data/models.dart';
import '../../routes.dart';
import '../../widgets/widgets.dart';
import '../../theme/colors.dart';
import '../../core/logging/logger_service.dart';
import '../../utils/format_utils.dart';
import 'package:spitout/providers/core/post_processor.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/icons/app_icons.dart';

/// 账本编辑二级页面
///
/// [ledger] 为 null 时表示新建模式；非 null 时为编辑模式。
class LedgerEditPage extends ConsumerStatefulWidget {
  final LedgerDisplayItem? ledger;

  const LedgerEditPage({
    super.key,
    this.ledger,
  });

  @override
  ConsumerState<LedgerEditPage> createState() => _LedgerEditPageState();
}

class _LedgerEditPageState extends ConsumerState<LedgerEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String _currency = '';
  int _monthStartDay = 1;
  bool _saving = false;
  bool _initialized = false;

  /// AA 分摊开关(编辑态,随「保存」落库;跨设备同步)。
  bool _aaEnabled = false;

  /// 已落库的 AA 开关值。「查看分摊结算 / 管理虚拟用户」入口按此值展示,
  /// 避免用户刚打开开关(未保存)就跳到与实际数据不符的页面(§6.5)。
  bool _aaEnabledSaved = false;

  /// 当前账本的云端 external_id(本地 syncId),成员协作模块的数据源标识;
  /// 仅编辑模式异步加载,本地账本 / 未同步账本为 null。
  String? _syncId;

  /// 新建模式下用户显式选择的账本归属；null = 尚未手动改过，用默认值。
  ///
  /// 不在 initState 里定死默认值，是因为默认值取决于「当前是否登录
  /// Spitout Cloud」，而云配置是异步 provider —— 留 null 让 build 每次按
  /// 最新登录态推导，避免出现"进页面时没登录、选项却卡在旧默认"的情况。
  String? _storageMode;

  bool get _isEditing => widget.ledger != null;
  bool get _isCreating => widget.ledger == null;

  /// 归属默认值：已登录 Spitout Cloud → 云端账本（用户既然接了云服务，
  /// 新账本默认参与同步符合预期）；否则只能是本地账本。
  String _effectiveStorageMode(bool isSpitoutCloud) =>
      _storageMode ?? (isSpitoutCloud ? 'cloud' : 'local');

  /// 协作者只读判断：仅当「编辑已有账本」且「当前账本为共享账本」且「自己非拥有者」时为 true。
  /// 此时账本元信息（名称 / 币种 / 起始日）不可编辑。
  /// 依赖前置条件：_isEditing 为真时 widget.ledger 必然非空，故此处使用 ! 非空断言是安全的。
  bool get _isReadOnly =>
      _isEditing && widget.ledger!.isShared && widget.ledger!.myRole != 'owner';

  @override
  void initState() {
    super.initState();
    // 注意：initState 中不能用 translateLedgerName(context, ...)，
    // 它依赖 AppLocalizations.of(context)（InheritedWidget），
    // 在 initState 完成前访问会抛 dependOnInheritedWidgetOfExactType 异常。
    // 名称输入框初始值用原始账本名，翻译仅用于标题展示（在 build 中调用）。
    _nameController = TextEditingController(
      text: widget.ledger != null ? widget.ledger!.name : '',
    );
    if (widget.ledger != null) {
      _currency = widget.ledger!.currency;
      _monthStartDay = 1; // 真实值在 _loadLedgerData 中异步加载
      _loadLedgerData();
    } else {
      _initDefaultCurrency();
    }
  }

  /// 编辑模式：从 DB 加载完整的账本数据（monthStartDay 等）
  Future<void> _loadLedgerData() async {
    try {
      final repo = ref.read(repositoryProvider);
      final data = await repo.getLedgerById(widget.ledger!.id);
      if (data != null && mounted) {
        setState(() {
          _currency = data.currency;
          _monthStartDay = data.monthStartDay;
          _syncId = data.syncId;
          _aaEnabled = data.aaEnabled;
          _aaEnabledSaved = data.aaEnabled;
          _initialized = true;
        });
      }
    } catch (e) {
      logger.warning('LedgerEditPage', '加载账本数据失败: $e');
      if (mounted) setState(() => _initialized = true);
    }
  }

  /// 新建模式：默认币种链 — 当前账本本位币 → welcome 选币 → CNY
  Future<void> _initDefaultCurrency() async {
    String currency = ref.read(currentLedgerProvider).valueOrNull?.currency ?? '';
    if (currency.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        currency = prefs.getString('selected_currency') ?? 'CNY';
      } catch (e) {
        logger.warning('LedgerEditPage', '读取默认币种失败: $e');
        currency = 'CNY';
      }
    }
    if (mounted) {
      setState(() {
        _currency = currency;
        _monthStartDay = 1;
        _initialized = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 页面标题：编辑模式用账本名称，新建模式用「新建账本」
    final title = _isCreating
        ? l10n.ledgersNew
        : translateLedgerName(context, widget.ledger!.name);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: title,
            showBack: true,
            // 仅编辑模式展示右上角「更多」菜单，收纳账本敏感操作；
            // 新建模式没有清空/删除等危险入口，无需菜单。
            actions: _isEditing ? [_buildMoreMenu(context, l10n)] : null,
          ),
          Expanded(
            child: _initialized
                ? _buildBody(context, l10n)
                : const Center(child: CircularProgressIndicator()),
          ),
          // 底部保存按钮（新建和编辑模式显示）
          // 协作者只读时不渲染保存按钮，从源头杜绝推送账本元信息变更
          if (!_isReadOnly) _buildSaveButton(context, l10n),
        ],
      ),
    );
  }

  /// 模块标题 — 页面统一采用「标题在外 + 内容卡片」的版块结构。
  ///
  /// 左侧 3px 主题色条 + 加粗标题,与「备份与云同步配置」等页面的模块标题
  /// 风格一致,让编辑页各模块(账本名称 / 币种 / 每月起始日 / 成员管理 /
  /// 成员收支 / 存储位置)在长列表中区分更明显;水平内缩与 Card 默认
  /// margin(all: 4) 对齐;[disabled] 时色条与文字整行置灰,与只读内容的
  /// 禁用色保持一致。
  Widget _buildSectionTitle(BuildContext context, String text,
      {bool disabled = false}) {
    final color = disabled
        ? Theme.of(context).disabledColor
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. 账本名称 ──
          // 不设置 elevation，与编辑分类等其他模块保持一致的扁平卡片风格。
          _buildSectionTitle(context, l10n.ledgerNameLabel,
              disabled: _isReadOnly),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              // 协作者只读：不渲染带边框的输入框，仅展示账本名称文本，
              // 避免「看起来还能编辑」的误导；文字同步置灰。
              child: _isReadOnly
                  ? Text(
                      _nameController.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).disabledColor,
                          ),
                    )
                  : TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: l10n.ledgerNameHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.ledgerNameLabel;
                        }
                        return null;
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 2. 主币种 ──
          _buildSectionTitle(context, l10n.ledgerBaseCurrencyLabel,
              disabled: _isReadOnly),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: currencyFlagLabel(
                context,
                _currency,
                // 可编辑：与账本名称编辑框同用全局 bodyLarge（14px / 主色），
                // 避免可编辑值显示为灰色误导"不可编辑"；
                // 只读：对齐账本名称的只读样式（bodyLarge + disabledColor 置灰），
                // 与 ListTile 的 enabled=false 灰化保持一致。
                textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _isReadOnly
                          ? Theme.of(context).disabledColor
                          : null,
                    ),
              ),
              // 协作者只读时整行置灰（enabled=false 灰化文字与图标），且不显示右箭头，
              // 避免「看起来还能点击」的误导
              trailing: !_isReadOnly
                  ? Icon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: SpitoutTokens.iconTertiary(context),
                    )
                  : null,
              enabled: !_isReadOnly,
              onTap: !_isReadOnly
                  ? () async {
                      // 在首个 await 之前先捕获主题色：Theme.of(context) 跨 await 间隙使用会被
                      // use_build_context_synchronously 告警，提前取出引用后 await 之后仅复用局部变量。
                      final primaryColor = Theme.of(context).colorScheme.primary;
                      // 键盘守卫：与记账页/分类页一致，避免面板关闭后键盘重弹。
                      await prepareForOverlay();
                      // 闭包内 context 为 build 参数，用 context.mounted 与同源，方能被分析器识别为有效守卫。
                      if (!context.mounted) return;
                      final picked = await showCurrencyPickerSheet(
                        context,
                        selected: _currency.toUpperCase(),
                        primaryColor: primaryColor,
                        title: l10n.ledgerBaseCurrencyLabel,
                        showRateAsBaseLabel: true,
                        visibleCurrencies: ref.read(visibleCurrenciesProvider),
                      );
                      if (picked != null) {
                        setState(() => _currency = picked);
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. 每月起始日 ──
          _buildSectionTitle(context, l10n.ledgersMonthStartDay,
              disabled: _isReadOnly),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                _monthStartDay <= 1
                    ? l10n.ledgersMonthStartDayNatural
                    : l10n.ledgersMonthStartDayValue(_monthStartDay),
                // 可编辑：与账本名称编辑框同用全局 bodyLarge（14px / 主色），
                // 避免可编辑值显示为灰色误导"不可编辑"；
                // 只读：对齐账本名称的只读样式（bodyLarge + disabledColor 置灰），
                // 与 ListTile 的 enabled=false 灰化保持一致。
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _isReadOnly
                          ? Theme.of(context).disabledColor
                          : null,
                    ),
              ),
              // 协作者只读时整行置灰且不显示右箭头
              trailing: !_isReadOnly
                  ? Icon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: SpitoutTokens.iconTertiary(context),
                    )
                  : null,
              enabled: !_isReadOnly,
              onTap: !_isReadOnly
                  ? () async {
                      final picked = await _showMonthStartDayPicker(
                        context,
                        initial: _monthStartDay,
                      );
                      if (picked != null) {
                        setState(() => _monthStartDay = picked);
                      }
                    }
                  : null,
            ),
          ),

          // ── 4. AA 分摊(开关 + 分摊设置入口) ──
          // 间距内化:AA 区块自带顶部 16px(见 _buildAaSection),
          // 与成员区/归属区策略一致,避免外层独立 SizedBox 在区块隐藏时残留孤儿间隙。
          _buildAaSection(context, l10n),

          // ── 5. 新建模式的账本归属选择 ──
          if (_isCreating) ...[
            const SizedBox(height: 16),
            _buildStorageModeSelector(context, l10n),
          ],

          // ── 5. 编辑模式的成员协作区 + 归属移动 ──
          //
          // 成员协作区与归属移动区都可能整体隐藏，且两者显示条件并不等价，
          // 无法靠外层统一 if 包裹来同步。故间距采用"内化"策略：各区隐藏时
          // 返回零高度 SizedBox.shrink()，展示时自带 Padding(top: 16)。
          // 此处不垫独立 SizedBox，避免两区同时隐藏时累积出孤儿间隙。
          //
          // 敏感操作（清空/删除/退出并删除）已收纳到右上角 [_buildMoreMenu]。
          if (_isEditing) ...[
            _buildMemberSections(context, l10n),
            _buildStorageActions(context, l10n),
          ],
        ],
      ),
    );
  }

  /// AA 分摊设置模块(文档 §6.5)。
  ///
  /// 结构:开关行(随「保存」落库,与其他账本元信息同一保存语义)+
  /// 编辑模式且 AA 已生效时的「查看分摊结算 / 管理虚拟用户」入口。
  /// 入口按 [_aaEnabledSaved](已落库值)展示,与 §6.7「关闭后入口隐藏」一致。
  ///
  /// 间距内化:区块自带顶部 16px(标题外包 Padding),与成员区/归属区一致——
  /// 这样区块始终展示开关行时,与上一个区块之间恰为 16px,不依赖外层 SizedBox。
  Widget _buildAaSection(BuildContext context, AppLocalizations l10n) {
    final readOnlyColor = _isReadOnly ? Theme.of(context).disabledColor : null;
    // 分摊结算页按「当前账本」取数,仅编辑当前账本时展示入口,
    // 避免从非当前账本跳入看到另一本账的结算数据。
    final isCurrentLedger =
        _isEditing && widget.ledger!.id == ref.watch(currentLedgerIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 内化顶部间距:区块顶到此标题之间无额外间隔,16px 全部在标题上方。
          padding: const EdgeInsets.only(top: 16),
          child: _buildSectionTitle(context, l10n.ledgerAaEnabled,
              disabled: _isReadOnly),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  l10n.ledgerAaEnabled,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: readOnlyColor),
                ),
                subtitle: Text(
                  l10n.ledgerAaEnabledHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SpitoutTokens.textTertiary(context),
                      ),
                ),
                value: _aaEnabled,
                // 协作者只读:与其他账本元信息一致,禁用开关(onChanged=null 灰化)
                onChanged: _isReadOnly
                    ? null
                    : (v) => setState(() => _aaEnabled = v),
              ),
              if (_isEditing && _aaEnabledSaved) ...[
                if (isCurrentLedger) ...[
                  Divider(height: 1, color: SpitoutTokens.divider(context)),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(AppIcons.pieChart,
                        size: 20,
                        color: SpitoutTokens.iconSecondary(context)),
                    title: Text(l10n.ledgerAaSettlementEntry),
                    trailing: Icon(AppIcons.chevronRight,
                        size: 16,
                        color: SpitoutTokens.iconTertiary(context)),
                    onTap: () =>
                        Navigator.of(context).pushNamed(Routes.aaSettlement),
                  ),
                ],
                Divider(height: 1, color: SpitoutTokens.divider(context)),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(AppIcons.people,
                      size: 20,
                      color: SpitoutTokens.iconSecondary(context)),
                  title: Text(l10n.ledgerAaVirtualUsersEntry),
                  trailing: Icon(AppIcons.chevronRight,
                      size: 16,
                      color: SpitoutTokens.iconTertiary(context)),
                  onTap: () => showVirtualUserManageSheet(
                    context,
                    ledgerId: widget.ledger!.id,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 新建账本时的归属选择（本地账本 / Spitout Cloud 账本）。
  ///
  /// 归属模型下「这本账会不会上云」必须由用户在创建时就看清楚，而不是
  /// 靠"当前登没登录"隐式决定 —— 后者会让用户在不知情的情况下把私密账本
  /// 传上云。未登录时云端选项直接禁用并给出登录引导，不留误点的机会。
  Widget _buildStorageModeSelector(
      BuildContext context, AppLocalizations l10n) {
    final isSpitoutCloud =
        ref.watch(activeCloudConfigProvider).valueOrNull?.type ==
            CloudBackendType.spitoutCloud;
    final mode = _effectiveStorageMode(isSpitoutCloud);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.ledgersStorageLocation,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'local',
                  icon: const Icon(AppIcons.localStorage, size: 16),
                  label: Text(l10n.ledgersSectionLocal),
                ),
                ButtonSegment(
                  value: 'cloud',
                  icon: const Icon(AppIcons.cloudQueue, size: 16),
                  label: Text(l10n.ledgersSectionCloud),
                  enabled: isSpitoutCloud,
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _storageMode = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              isSpitoutCloud
                  ? (mode == 'cloud'
                      ? l10n.ledgersStorageCloudHint
                      : l10n.ledgersStorageLocalHint)
                  : l10n.ledgersSectionCloudSignInHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SpitoutTokens.textSecondary(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 成员协作区（成员管理 / 成员收支）
  ///
  /// 间距内化：隐藏时返回零高度 [SizedBox.shrink]（不带任何 Padding），
  /// 展示时由本方法自带 `Padding(top: 16)`。这样上层 [_buildBody] 无需为
  /// 本区预留独立间隔 —— 否则本区隐藏时那段间隔会变成"孤儿间隙"。
  Widget _buildMemberSections(BuildContext context, AppLocalizations l10n) {
    // 守卫条件需要先确定 ledger，因为要读 ledger.isCloudLedger。
    final ledger = widget.ledger!;
    // 用 watch 而非 read：本区展示与否取决于登录态，必须独立订阅 cloud 配置。
    // 用 read 时本区的刷新依赖「同一 build 里恰好有别的方法 watch 了它」，
    // 一旦 _buildStorageActions 被移走或变为条件渲染，登录/登出时本区就会僵在旧状态。
    final isSpitoutCloud =
        ref.watch(activeCloudConfigProvider).valueOrNull?.type ==
            CloudBackendType.spitoutCloud;
    // fail-closed：本地账本没有 syncId，接不进协作端；非 Spitout Cloud 后端
    // 也没有成员体系；syncId 尚未加载或缺失时同样无法拉取成员数据。
    // 三种情况整区隐藏，不展示不可用的协作内容。
    final syncId = _syncId;
    if (!isSpitoutCloud ||
        !ledger.isCloudLedger ||
        syncId == null ||
        syncId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, l10n.sharedMembersPageTitle),
          const SizedBox(height: 8),
          MemberManagementSection(
            ledgerExternalId: syncId,
            ledgerName: ledger.name,
          ),
          // 成员支出仅共享账本有意义：个人云端账本没有其他成员可统计
          if (ledger.isShared) ...[
            const SizedBox(height: 16),
            // 模块自带标题（右侧展示账本总支出金额副标题）
            MemberStatsSection(ledgerExternalId: syncId),
          ],
        ],
      ),
    );
  }

  /// 账本归属移动区:统一在编辑页内操作。
  ///
  /// 显示逻辑与列表页一致(fail-closed,避免点了才报错的死路):
  ///   - 本地 + 已登录 Spitout Cloud + 非共享 → 移动到 Spitout Cloud
  ///   - 云端 + 非共享 + 已登录 Spitout Cloud → 移动到本地
  ///   - 云端 + 已登录 Spitout Cloud         → 复制到本地(共享账本只能复制留档)
  ///
  /// 间距内化：与 [_buildSharedLedgerEntries] 同一策略 —— 隐藏时返回零高度
  /// [SizedBox.shrink]，展示时自带 `Padding(top: 16)`，避免上层垫的独立间隔
  /// 在本区隐藏时沦为孤儿间隙。
  Widget _buildStorageActions(BuildContext context, AppLocalizations l10n) {
    final isSpitoutCloud =
        ref.watch(activeCloudConfigProvider).valueOrNull?.type ==
            CloudBackendType.spitoutCloud;
    final ledger = widget.ledger!;

    final canMoveToCloud =
        !ledger.isCloudLedger && !ledger.isShared && isSpitoutCloud;
    final canMoveToLocal =
        ledger.isCloudLedger && !ledger.isShared && isSpitoutCloud;
    final canCopyToLocal = ledger.isCloudLedger && isSpitoutCloud;

    if (!canMoveToCloud && !canMoveToLocal && !canCopyToLocal) {
      return const SizedBox.shrink();
    }

    // 「标题在外 + 内容卡片」与其他模块统一:存储归属操作(移动 / 复制到
    // 本地)不是散落的裸卡片,先给出模块标题,再收纳具体操作项。
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, l10n.ledgersStorageLocation),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (canMoveToCloud)
                  ListTile(
                    leading: const Icon(AppIcons.cloudUpload),
                    title: Text(l10n.ledgersActionMoveToCloud),
                    onTap: () => _confirmStorageMove(
                      ledger,
                      title: l10n.ledgersActionMoveToCloud,
                      message: l10n.ledgersMoveToCloudMessage(
                        translateLedgerName(context, ledger.name),
                      ),
                      successText: l10n.ledgersMoveToCloudSuccess,
                      action: () => moveLedgerToCloudProvider(ref,
                          ledgerId: ledger.id),
                    ),
                  ),
                if (canMoveToLocal) ...[
                  if (canMoveToCloud) const Divider(height: 1),
                  ListTile(
                    leading: const Icon(AppIcons.cloudDownload),
                    title: Text(l10n.ledgersActionMoveToLocal),
                    onTap: () => _confirmStorageMove(
                      ledger,
                      title: l10n.ledgersActionMoveToLocal,
                      message: l10n.ledgersMoveToLocalMessage(
                        translateLedgerName(context, ledger.name),
                      ),
                      successText: l10n.ledgersMoveToLocalSuccess,
                      action: () => moveLedgerToLocalProvider(ref,
                          ledgerId: ledger.id),
                    ),
                  ),
                ],
                if (canCopyToLocal) ...[
                  if (canMoveToCloud || canMoveToLocal)
                    const Divider(height: 1),
                  ListTile(
                    leading: const Icon(AppIcons.copy),
                    title: Text(l10n.ledgersActionCopyToLocal),
                    onTap: () => _confirmStorageMove(
                      ledger,
                      title: l10n.ledgersActionCopyToLocal,
                      message: l10n.ledgersCopyToLocalMessage(
                        translateLedgerName(context, ledger.name),
                      ),
                      successText: l10n.ledgersCopyToLocalSuccess,
                      // 复制到本地只是云端留一份本地副本,云端原件归属不变,
                      // 编辑页快照仍然有效,无需 pop 回列表。
                      popAfter: false,
                      action: () => copyLedgerToLocalProvider(ref,
                          ledgerId: ledger.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 归属移动的统一执行壳:二次确认 → 执行 → 成功 Toast / 失败弹窗。
  ///
  /// 移动会改变数据的存放位置(甚至删除云端副本),属于不可逆操作,必须先让用户确认;
  /// 底层 move provider 是 fail-closed 的,失败时账本归属原样不动,这里只需把异常
  /// 原文摊给用户,不需要任何本地回滚。
  ///
  /// [popAfter] 控制成功后是否返回列表:移动到本地/云端会改变账本归属,编辑页持有的
  /// `widget.ledger` 快照会过期,必须 pop 回列表让底层 `_refreshAfterMove` 刷新后的
  /// 数据重新进场;复制到本地不改变云端原件,快照仍有效,故不 pop。
  Future<void> _confirmStorageMove(
    LedgerDisplayItem ledger, {
    required String title,
    required String message,
    required String successText,
    required Future<void> Function() action,
    bool popAfter = true,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: title,
      message: message,
    );
    if (confirmed != true || !mounted) return;

    try {
      await action();
      if (!mounted) return;
      showToast(context, successText);
      if (popAfter) Navigator.of(context).pop();
    } catch (e, st) {
      logger.warning('LedgerEditPage', '账本归属移动失败(${ledger.id}): $e', st);
      if (!mounted) return;
      await AppDialog.error(context, title: l10n.commonFailed, message: '$e');
    }
  }

  /// 右上角「更多」菜单：收纳账本敏感操作（清空/删除/退出并删除）。
  ///
  /// 菜单项按角色动态生成，点击后调用对应的处理函数：
  /// - Owner：清空账本
  /// - 共享账本 Owner：删除共享账本（云端级联踢人 + 广播），
  ///   不能用本地+云端备份删除
  /// - 共享账本协作者：退出并删除（走云端退出 + 清本地），
  ///   不能用「仅删本地」（否则下次 sync re-insert）
  /// - 个人账本：删除账本（全局删除：远端 + 本地 + 待推送变更），
  ///   只删本地会导致下次 sync re-insert 形成"幽灵账本"
  Widget _buildMoreMenu(BuildContext context, AppLocalizations l10n) {
    final ledger = widget.ledger!;
    final isOwner = ledger.myRole == 'owner';
    final isShared = ledger.isShared;
    return SpitoutPopupMenu(
      items: [
        if (isOwner)
          // 清空是可逆的警示级操作，用黄色与红色破坏级操作（删除/退出）区分
          SpitoutMenuItem.action(
            value: 'clear',
            label: l10n.ledgersClear,
            color: SpitoutTokens.warning(context),
          ),
        if (isShared && isOwner)
          SpitoutMenuItem.action(
            value: 'delete_shared',
            label: l10n.ledgersDeleteShared,
            isDanger: true,
          ),
        if (isShared && !isOwner)
          SpitoutMenuItem.action(
            value: 'leave_and_delete',
            label: l10n.ledgersLeaveAndDelete,
            isDanger: true,
          ),
        if (!isShared)
          SpitoutMenuItem.action(
            value: 'delete',
            label: l10n.ledgersDelete,
            isDanger: true,
          ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'clear':
            _handleClearLedger();
          case 'delete_shared':
            _handleDeleteSharedLedgerAsOwner();
          case 'leave_and_delete':
            _handleLeaveAndDeleteSharedLedger();
          case 'delete':
            _handleDeleteLocalLedger();
        }
      },
    );
  }

  /// 底部保存按钮
  Widget _buildSaveButton(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: FilledButton(
        onPressed: _saving ? null : _handleSave,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(_isCreating ? l10n.ledgersCreate : l10n.commonSave),
      ),
    );
  }

  /// 保存（新建或编辑）
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      if (_isCreating) {
        await _saveNewLedger(name);
      } else {
        await _saveExistingLedger(name);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        await AppDialog.error(
          context,
          title: AppLocalizations.of(context).commonFailed,
          message: '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 新建账本（逻辑与原 _showCreateLedgerDialog 一致）
  ///
  /// 关键设计：本方法内所有「状态类副作用」（首快照、当前账本切换、列表刷新）
  /// 一律通过方法入口捕获的根 [ProviderContainer] 执行，与页面挂载状态解耦。
  /// 原因：用户新建后可能极快退出，此时 mounted 变 false，若用 ref 执行会被
  /// `if (!mounted) return` 整段跳过 —— 表现为「首快照没发 + 首本账本没被选中
  /// + 账本列表不刷新」。mounted 守卫只保留给真正需要 BuildContext 的 UI 反馈。
  Future<void> _saveNewLedger(String name) async {
    // 必须在任何 await 之前捕获：此刻由按钮回调同步进入，context 必然有效。
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(repositoryProvider);

    // 这里读后端类型只为「归属二次夹紧」这一 UI 语义，与同步触发无关。
    final isSpitoutCloud = ref.read(activeCloudConfigProvider).valueOrNull?.type ==
        CloudBackendType.spitoutCloud;
    // 二次夹紧：未登录 Spitout Cloud 时无论 UI 状态如何都只能建本地账本，
    // 否则会造出"标了 cloud 却没有云端副本"的孤儿账本。
    final storageMode = isSpitoutCloud ? _effectiveStorageMode(true) : 'local';
    final newLedgerId = await repo.createLedger(
      name: name,
      currency: _currency,
      storageMode: storageMode,
    );

    // 创建时选了非 1 的起始日 → 补写
    if (_monthStartDay != 1) {
      await repo.updateLedger(id: newLedgerId, monthStartDay: _monthStartDay);
    }
    // 创建时开启了 AA 分摊 → 补写开关(默认 false,跨设备同步)
    if (_aaEnabled) {
      await repo.updateLedger(id: newLedgerId, aaEnabled: true);
    }

    // 同步触发已完全响应式化(规则4):createLedger 在数据层同事务登记变更信号
    // —— Spitout Cloud 写 local_changes(SyncCoordinator 监听)、快照型后端写
    // snapshot_dirty_ledgers(SnapshotSyncCoordinator 监听),页面零后端知识,
    // 不显式调用任何 sync 方法,消除页面 mounted 竞态与双触发窗口。

    // 空账本场景切换到新账本：同样走 container，避免快速退出后「建了第一本
    // 账本却仍处于无当前账本」的状态。
    final currentLedger = await container.read(currentLedgerProvider.future);
    if (currentLedger == null) {
      container.read(currentLedgerIdProvider.notifier).state = newLedgerId;
      container.invalidate(currentLedgerProvider);
    }
    // 列表刷新信号同理：账本列表页在本页 pop 后仍存活，必须收到
    container.read(ledgerListRefreshProvider.notifier).state++;

    // 仅 UI 反馈需要 mounted
    if (!mounted) return;
    showToast(context, AppLocalizations.of(context).ledgersCreateSuccess);
  }

  /// 编辑账本
  ///
  /// 与 [_saveNewLedger] 同理：写库完成后的「刷新信号 + 同步触发」是纯状态
  /// 副作用，必须走方法入口捕获的根 container。否则用户保存后极快退出时，
  /// ref 已随页面销毁失效，`ref.read` 抛错会被 _handleSave 静默吞掉 ——
  /// 表现为「改名已落库但列表不刷新 + 云端不同步」。
  Future<void> _saveExistingLedger(String name) async {
    final ledger = widget.ledger!;
    // 协作者只读防御（第二道防线）：即使 UI 层被绕过（如直接调用保存），
    // 也不允许推送账本元信息变更。与隐藏保存按钮形成双重保险。
    if (ledger.isShared && ledger.myRole != 'owner') return;
    // 必须在任何 await 之前捕获：此刻 context 必然有效。
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(repositoryProvider);
    final ledgerData = await repo.getLedgerById(ledger.id);
    if (ledgerData == null || !mounted) return;

    // 币种变更：确认弹窗 + updateLedger + 拉汇率 + 全量重算 + 刷新 + 同步
    final currencyChanged =
        _currency.toUpperCase() != ledgerData.currency.toUpperCase();
    if (currencyChanged) {
      final applied = await applyLedgerCurrencyChange(
        context,
        ref,
        ledgerId: ledger.id,
        newCurrency: _currency,
      );
      // 用户取消 → 整体中止
      if (!applied || !mounted) return;
    }

    // 名称/起始日/AA 开关变更
    final nameChanged = name != ledgerData.name;
    final startDayChanged = _monthStartDay != ledgerData.monthStartDay;
    final aaChanged = _aaEnabled != ledgerData.aaEnabled;
    if (!nameChanged && !startDayChanged && !currencyChanged && !aaChanged) {
      return;
    }

    if (nameChanged || startDayChanged || aaChanged) {
      await repo.updateLedger(
        id: ledger.id,
        name: name,
        monthStartDay: _monthStartDay,
        // 未变更时传 null = 不更新(updateLedger 语义)
        aaEnabled: aaChanged ? _aaEnabled : null,
      );
    }

    // 刷新信号在 sync 之前发；走 container 与页面生命周期解耦，
    // 保证快速退出后列表页/统计页仍能收到信号。
    container.read(ledgerListRefreshProvider.notifier).state++;
    container.invalidate(currentLedgerProvider);
    container.read(statsRefreshProvider.notifier).state++;

    // 触发同步更新云端（container 版，不依赖页面挂载）
    try {
      await PostProcessor.syncC(container, ledgerId: ledger.id);
    } catch (e) {
      logger.warning('LedgerEditPage', '改账本元数据后同步失败(本地已生效): $e');
    }
  }

  /// 清空账本（逻辑与原 _handleClearLedger 一致）
  Future<void> _handleClearLedger() async {
    final l10n = AppLocalizations.of(context);
    final ledger = widget.ledger!;
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.ledgersClearTitle,
      message: l10n.ledgersClearMessage(translateLedgerName(context, ledger.name)),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      await repo.clearLedgerTransactions(ledger.id);

      if (!mounted) return;
      ref.read(cachedTransactionsProvider.notifier).state = null;
      await PostProcessor.sync(ref, ledgerId: ledger.id);

      if (!mounted) return;
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
      showToast(context, l10n.ledgersClearSuccess);
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(context, title: l10n.commonFailed, message: '$e');
    }
  }

  /// 删除个人账本（全局删除:远端 + 本地 + 待推送变更）
  Future<void> _handleDeleteLocalLedger() async {
    final l10n = AppLocalizations.of(context);
    final ledger = widget.ledger!;

    final repo = ref.read(repositoryProvider);
    final allLedgers = await repo.getAllLedgers();
    if (!mounted) return;

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.ledgersDeleteConfirm,
      message: l10n.ledgersDeleteMessage,
    );
    if (confirmed != true || !mounted) return;

    try {
      final sync = ref.read(syncServiceProvider);
      final current = ref.read(currentLedgerIdProvider);
      final deletedLedgerId = ledger.id;

      if (current == deletedLedgerId) {
        final remain = allLedgers.where((l) => l.id != deletedLedgerId).toList();
        if (remain.isNotEmpty) {
          ref.read(currentLedgerIdProvider.notifier).state = remain.first.id;
        }
      }

      // 三步删除(远端删 → 本地删 → 清 change)收敛在 SyncService 内部,
      // UI 不感知后端类型,也不显式触发 PostProcessor.sync ——
      // 残留 change 由服务层清掉,推送只会打到已删除的远端资源上。
      await sync.deleteLedgerGlobally(deletedLedgerId);
      await _removeLedgerLocalPrefs(deletedLedgerId);

      if (!mounted) return;
      ref.invalidate(currentLedgerProvider);
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      showToast(context, l10n.ledgersDeleted);
      // 删除成功后返回上一页
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(context, title: l10n.ledgersDeleteFailed, message: '$e');
    }
  }

  /// 协作者「退出并删除」共享账本:先走云端 DELETE /members/self 退出,
  /// 再清本地数据(清 local_changes → 镜像表 → 交易 → 账本行)。
  /// 云端移除成员后 server 不返回该账本,下次 sync 不会被 re-insert 回来。
  Future<void> _handleLeaveAndDeleteSharedLedger() async {
    final l10n = AppLocalizations.of(context);
    final ledger = widget.ledger!;
    final repo = ref.read(repositoryProvider);
    // syncId 在 ledgers 表里,本地展示项不含,需回查。
    final row = await repo.getLedgerById(ledger.id);
    final syncId = row?.syncId;
    if (syncId == null || syncId.isEmpty) {
      if (mounted) showToast(context, l10n.sharedRequiresCloudSync);
      return;
    }
    // 预取账本列表(用于切换当前账本),并紧接 mounted 守卫,
    // 使下方 AppDialog.confirm(context) 不跨 await 使用 context。
    final allLedgers = await repo.getAllLedgers();
    if (!mounted) return;

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.ledgersLeaveAndDeleteConfirm,
      message: l10n.ledgersLeaveAndDeleteMessage(translateLedgerName(context, ledger.name)),
    );
    if (confirmed != true || !mounted) return;

    try {
      // cloud-first:先退出云端,再 purge 本地(两条路径汇到 repo.purgeSharedLedger)。
      await leaveAndDeleteSharedLedgerProvider(ref, ledgerId: syncId);
      if (!mounted) return;

      // 若删的是当前账本,切换走,避免 UI 指向已删账本
      final current = ref.read(currentLedgerIdProvider);
      if (current == ledger.id) {
        final remain = allLedgers.where((l) => l.id != ledger.id).toList();
        if (remain.isNotEmpty) {
          ref.read(currentLedgerIdProvider.notifier).state = remain.first.id;
        }
      }
      ref.invalidate(currentLedgerProvider);
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      if (!mounted) return;
      showToast(context, l10n.ledgersLeaveAndDeleteSuccess);
      // 退出并删除成功后返回上一页
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(context, title: l10n.commonFailed, message: '$e');
    }
  }

  /// Owner「全局删除」共享账本:走云端 DELETE /write/ledgers/{id}(server 级联
  /// 踢出所有成员并广播 member_change.removed),再清本地数据。无需客户端循环踢人。
  Future<void> _handleDeleteSharedLedgerAsOwner() async {
    final l10n = AppLocalizations.of(context);
    final ledger = widget.ledger!;
    final repo = ref.read(repositoryProvider);
    final row = await repo.getLedgerById(ledger.id);
    final syncId = row?.syncId;
    if (syncId == null || syncId.isEmpty) {
      if (mounted) showToast(context, l10n.sharedRequiresCloudSync);
      return;
    }
    final allLedgers = await repo.getAllLedgers();
    if (!mounted) return;

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.ledgersDeleteSharedConfirm,
      message: l10n.ledgersDeleteSharedMessage(translateLedgerName(context, ledger.name)),
    );
    if (confirmed != true || !mounted) return;

    try {
      await deleteSharedLedgerAsOwnerProvider(ref, ledgerId: syncId);
      if (!mounted) return;

      final current = ref.read(currentLedgerIdProvider);
      if (current == ledger.id) {
        final remain = allLedgers.where((l) => l.id != ledger.id).toList();
        if (remain.isNotEmpty) {
          ref.read(currentLedgerIdProvider.notifier).state = remain.first.id;
        }
      }
      ref.invalidate(currentLedgerProvider);
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      if (!mounted) return;
      showToast(context, l10n.ledgersDeleteSharedSuccess);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(context, title: l10n.commonFailed, message: '$e');
    }
  }

  /// 清理被删账本的本地残留
  Future<void> _removeLedgerLocalPrefs(int ledgerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(visibleCurrenciesKeyFor(ledgerId));
    } catch (e) {
      logger.warning('LedgerEditPage', '清理可见币种 prefs 失败(非阻断): $e');
    }
  }

  /// 28 宫格月起始日选择器
  Future<int?> _showMonthStartDayPicker(BuildContext context, {required int initial}) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: SpitoutTokens.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.ledgersMonthStartDay,
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(l10n.ledgersMonthStartDayHint,
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: SpitoutTokens.textTertiary(ctx))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(28, (index) {
                    final day = index + 1;
                    final isSelected = initial == day;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, day),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected
                              ? primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? primary : SpitoutTokens.divider(ctx),
                          ),
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: isSelected
                                ? primary
                                : SpitoutTokens.textPrimary(ctx),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}