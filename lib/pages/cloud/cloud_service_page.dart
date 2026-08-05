import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show
        CloudBackendType,
        CloudServiceConfig,
        CloudAuthException;
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart'
    show purgeLocalCloudLedgersWithContainer;
import 'package:spitout/providers/core/database_providers.dart';
import '../../core/logging/logger_service.dart';
import '../settings/local_backup_page.dart';
import 'cloud_sync_section.dart';
import 'spitout_cloud_sync_section.dart';
import 'cloud_config_dialogs.dart';
import 'cloud_help_dialogs.dart';
import '../../widgets/widgets.dart';
import '../../theme/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/icons/app_icons.dart';
import '../../cloud/auth_error_localizer.dart';

class CloudServicePage extends ConsumerStatefulWidget {
  const CloudServicePage({super.key});
  @override
  ConsumerState<CloudServicePage> createState() => _CloudServicePageState();
}

class _CloudServicePageState extends ConsumerState<CloudServicePage> {
  bool _testingConnection = false;
  final Map<String, bool> _connectionTestResults = {};

  /// 各后端上次测试时间，用于头部内联展示「上次测试时间：YYYY-MM-DD HH:MM:SS」。
  final Map<String, DateTime> _connectionTestTimes = {};

  /// 各后端上次测试结果详情文案（成功/失败具体原因），内联展示不弹窗。
  final Map<String, String> _connectionTestMessages = {};

  /// SharedPreferences 句柄，用于跨页面持久化测试结果。initState 中初始化。
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    // 进入页面即恢复上次测试结果，避免每次进页面都回到「未测试」。
    _loadPersistedTestResults();
  }

  /// SpitoutCloud 同步区块的 key：宿主下拉刷新时把刷新动作转发给区块的
  /// [SpitoutCloudSyncSectionState.refresh]（原独立页面的 _onRefresh）。
  /// 仅在 spitoutCloud 激活时挂载到区块上，切走后组件 unmount，
  /// currentState 自动置空，无需额外清理。
  final GlobalKey<SpitoutCloudSyncSectionState> _spitoutSyncKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeCloudConfigProvider);
    final spitoutCloudAsync = ref.watch(spitoutCloudConfigProvider);
    final supabaseAsync = ref.watch(supabaseConfigProvider);
    final webdavAsync = ref.watch(webdavConfigProvider);
    final s3Async = ref.watch(s3ConfigProvider);

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          activeAsync.when(
            loading: () => PrimaryHeader(
              title: AppLocalizations.of(context).mineCloudService,
              showBack: true,
            ),
            error: (e, _) => PrimaryHeader(
              title: AppLocalizations.of(context).mineCloudService,
              showBack: true,
            ),
            data: (active) => PrimaryHeader(
              title: AppLocalizations.of(context).mineCloudService,
              showBack: true,
              // 头部在三种激活态（本地/备份/云端）下保持一致：配置信息行始终展示
              // （本地展示「本地存储」状态），不因激活类型不同而出现缺胳膊少腿的差异。
              // 「测试连接」入口内联到配置信息行（见 _buildConnectionStatus 的「测试连接」文字链），
              // 不用头部 icon 按钮，避免与内联状态重复。
              content: Padding(
                // 底部留白 4：收紧配置信息自身底部留白，让分组标题更贴近。
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _buildConnectionStatus(active),
              ),
            ),
          ),

          Expanded(
            child: activeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('${AppLocalizations.of(context).commonError}: $e'),
              ),
              data: (active) {
                // 单列表展示：按离线模式 / 备份同步 / 云端协同分组，主标题下依次
                // 平铺该分组内的服务卡片。各卡片的切换/配置/教程/测试逻辑各自独立。
                // RefreshIndicator 统一负责下拉刷新（见 _onHostRefresh）。
                return RefreshIndicator(
                  onRefresh: () => _onHostRefresh(active),
                  child: ListView(
                    // 顶部留白从 8 增至 16：首个分组“离线模式”距顶部 PrimaryHeader 太近，增加呼吸感
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    // 内容不足一屏时也允许下拉手势触发刷新
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // ===== 离线模式 =====
                      _buildSectionHeader(
                        context,
                        AppLocalizations.of(context).cloudTabOffline,
                      ),
                      _buildServiceCard(
                        context: context,
                        icon: AppIcons.localStorage,
                        iconColor: SpitoutTokens.brandLocal,
                        title: AppLocalizations.of(
                          context,
                        ).cloudLocalStorageTitle,
                        subtitle: AppLocalizations.of(
                          context,
                        ).cloudLocalStorageSubtitle,
                        isSelected: active.type == CloudBackendType.local,
                        isDisabled: false,
                        onTap: () => _switchService(CloudBackendType.local),
                        // 齿轮「配置」入口：进入本地存储页（自动备份开关 / 快照恢复）。
                        // 复用卡片内置 onConfigure 浮层按钮，零改动卡片组件。
                        onConfigure: () => Navigator.of(context).push(
                          appPageRoute(builder: (_) => const LocalBackupPage()),
                        ),
                      ),

                      const SizedBox(height: 20),
                      // ===== 备份同步 =====
                      _buildSectionHeader(
                        context,
                        AppLocalizations.of(context).cloudTabBackup,
                      ),
                      if (active.type != CloudBackendType.local &&
                          active.type != CloudBackendType.spitoutCloud) ...[
                        _buildMultiDeviceWarning(context),
                        const SizedBox(height: 12),
                      ],

                      // WebDAV
                      webdavAsync.when(
                        loading: () => const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (webdavCfg) => _buildServiceCard(
                          context: context,
                          icon: AppIcons.folderShared,
                          iconColor: SpitoutTokens.brandWebdav,
                          title: AppLocalizations.of(
                            context,
                          ).cloudCustomWebdavTitle,
                          subtitle: webdavCfg?.valid == true
                              ? webdavCfg!.obfuscatedUrl()
                              : AppLocalizations.of(
                                  context,
                                ).cloudCustomWebdavSubtitle,
                          isSelected: active.type == CloudBackendType.webdav,
                          isConfigured: webdavCfg?.valid == true,
                          isDisabled: false,
                          onTap: () => webdavCfg?.valid == true
                              ? _switchService(CloudBackendType.webdav)
                              : _configureService(CloudBackendType.webdav),
                          onConfigure: webdavCfg?.valid == true
                              ? () => _configureService(CloudBackendType.webdav)
                              : null,
                          onShowGuide: () => showWebdavHelpDialog(context),
                        ),
                      ),
                      // 备份同步操作区块：仅当前选中 WebDAV 时显示在该卡片正下方
                      //（需求：选中哪个模块就展示在哪个模块下，local/SpitoutCloud 时隐藏）
                      if (active.type == CloudBackendType.webdav) ...[
                        const SizedBox(height: 8),
                        const CloudSyncSection(),
                      ],

                      const SizedBox(height: 12),
                      // S3
                      s3Async.when(
                        loading: () => const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (s3Cfg) => _buildServiceCard(
                          context: context,
                          icon: AppIcons.storage,
                          iconColor: SpitoutTokens.brandS3,
                          title: AppLocalizations.of(
                            context,
                          ).cloudCustomS3Title,
                          subtitle: s3Cfg?.valid == true
                              ? s3Cfg!.obfuscatedUrl()
                              : AppLocalizations.of(
                                  context,
                                ).cloudCustomS3Subtitle,
                          isSelected: active.type == CloudBackendType.s3,
                          isConfigured: s3Cfg?.valid == true,
                          isDisabled: false,
                          onTap: () => s3Cfg?.valid == true
                              ? _switchService(CloudBackendType.s3)
                              : _configureService(CloudBackendType.s3),
                          onConfigure: s3Cfg?.valid == true
                              ? () => _configureService(CloudBackendType.s3)
                              : null,
                          onShowGuide: () => showS3HelpDialog(context),
                        ),
                      ),
                      // 备份同步操作区块：仅当前选中 S3 时显示在该卡片正下方
                      if (active.type == CloudBackendType.s3) ...[
                        const SizedBox(height: 8),
                        const CloudSyncSection(),
                      ],

                      const SizedBox(height: 12),
                      // Supabase
                      supabaseAsync.when(
                        loading: () => const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (supabaseCfg) => _buildServiceCard(
                          context: context,
                          // Supabase 本质是数据库后端,图标语义为 database。
                          icon: AppIcons.storage,
                          iconColor: SpitoutTokens.brandSupabase,
                          title: AppLocalizations.of(
                            context,
                          ).cloudCustomSupabaseTitle,
                          subtitle: supabaseCfg?.valid == true
                              ? supabaseCfg!.obfuscatedUrl()
                              : AppLocalizations.of(
                                  context,
                                ).cloudCustomSupabaseSubtitle,
                          isSelected: active.type == CloudBackendType.supabase,
                          isConfigured: supabaseCfg?.valid == true,
                          isDisabled: false,
                          onTap: () => supabaseCfg?.valid == true
                              ? _switchService(CloudBackendType.supabase)
                              : _configureService(CloudBackendType.supabase),
                          onConfigure: supabaseCfg?.valid == true
                              ? () =>
                                    _configureService(CloudBackendType.supabase)
                              : null,
                          onShowGuide: () => showSupabaseHelpDialog(context),
                        ),
                      ),
                      // 备份同步操作区块：仅当前选中 Supabase 时显示在该卡片正下方
                      if (active.type == CloudBackendType.supabase) ...[
                        const SizedBox(height: 8),
                        const CloudSyncSection(),
                      ],

                      const SizedBox(height: 20),
                      // ===== 云端协同 (Spitout Cloud) =====
                      _buildSectionHeader(
                        context,
                        AppLocalizations.of(context).cloudTabCloudSync,
                      ),
                      spitoutCloudAsync.when(
                        loading: () => const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (bcCfg) => _buildServiceCard(
                          context: context,
                          // Spitout Cloud 用 cloudy 云形图标,与账本卡片图标语义对齐。
                          icon: AppIcons.cloudQueue,
                          iconColor: SpitoutTokens.brandCloud,
                          title: AppLocalizations.of(
                            context,
                          ).cloudSpitoutCloudTitle,
                          subtitle: bcCfg?.valid == true
                              ? bcCfg!.obfuscatedUrl()
                              : AppLocalizations.of(
                                  context,
                                ).cloudSpitoutCloudSubtitle,
                          isSelected:
                              active.type == CloudBackendType.spitoutCloud,
                          isConfigured: bcCfg?.valid == true,
                          isDisabled: false,
                          onTap: () => bcCfg?.valid == true
                              ? _switchService(CloudBackendType.spitoutCloud)
                              : _configureService(
                                  CloudBackendType.spitoutCloud,
                                ),
                          onConfigure: bcCfg?.valid == true
                              ? () => _configureService(
                                  CloudBackendType.spitoutCloud,
                                )
                              : null,
                          onShowGuide: () => showSpitoutCloudHelpDialog(context),
                        ),
                      ),
                      // SpitoutCloud 专属同步区块：仅当前选中 SpitoutCloud 时
                      // 显示在该卡片正下方（账号/2FA/对账面板/同步说明）。
                      // 挂 GlobalKey 供宿主下拉刷新转发。
                      if (active.type == CloudBackendType.spitoutCloud) ...[
                        const SizedBox(height: 8),
                        SpitoutCloudSyncSection(key: _spitoutSyncKey),
                      ],

                      // 备份方式切换引导：从「备份同步」分组标题副文案挪到页面底部居中，
                      // 作为整页通用提示，与上方最后一行信息保持约 30px 间距。
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          AppLocalizations.of(context).cloudTabBackupSubtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: SpitoutTokens.textSecondary(context),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 宿主统一下拉刷新分发（合并原 CloudSyncPage / SpitoutCloudSyncPage
  /// 两个独立页面各自的 RefreshIndicator 行为，逐行保持一致）：
  /// - local：无同步概念，轻量刷新配置展示；
  /// - spitoutCloud：转发给 SpitoutCloudSyncSection.refresh()
  ///   （对账 → 健康检查 → 有差异自动 sync）；
  /// - webdav/s3/supabase：清状态缓存 + bump tick + 等待状态刷新完成。
  Future<void> _onHostRefresh(CloudServiceConfig active) async {
    try {
      switch (active.type) {
        case CloudBackendType.local:
          ref.invalidate(activeCloudConfigProvider);
          break;
        case CloudBackendType.spitoutCloud:
          await _spitoutSyncKey.currentState?.refresh();
          break;
        default:
          final sync = ref.read(syncServiceProvider);
          final ledgerId = ref.read(currentLedgerIdProvider);
          sync.clearStatusCache(ledgerId: ledgerId);
          ref.read(syncStatusRefreshProvider.notifier).tick();
          // 等待状态刷新完成
          await ref.read(syncStatusProvider(ledgerId).future);
      }
    } catch (e, stackTrace) {
      logger.error('CloudServicePage', '下拉刷新失败', e, stackTrace);
    }
  }

  /// 头部「当前类型 / 脱敏 URL / 连接状态」信息块。
  ///
  /// 设计要点：
  /// - 「测试连接」入口内联为文字链，紧贴状态徽标左侧，不用头部 icon 按钮（避免重复）。
  /// - 测试结果（状态/时间/详情）全部内联展示，不弹窗。
  /// - 测试结果跨页面持久化：重新进入页面时从 SharedPreferences 恢复，
  ///   仅当从未点过「测试连接」（无历史记录）时才显示「未测试」。
  /// - 本地后端没有可连接的远端服务，自测无意义，故不展示测试链与状态徽标。
  Widget _buildConnectionStatus(CloudServiceConfig config) {
    final l10n = AppLocalizations.of(context);
    final testResult = _connectionTestResults[config.id];
    final testTime = _connectionTestTimes[config.id];
    final testMessage = _connectionTestMessages[config.id];
    final Color statusColor;
    final String statusText;

    if (testResult == null) {
      // 未测试
      statusColor = SpitoutTokens.warning(context);
      statusText = l10n.cloudStatusNotTested;
    } else if (testResult) {
      // 测试成功
      statusColor = SpitoutTokens.success(context);
      statusText = l10n.cloudStatusNormal;
    } else {
      // 测试失败
      statusColor = SpitoutTokens.error(context);
      statusText = l10n.cloudStatusFailed;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 长类型名（如 Spitout Cloud）在窄空间下省略号截断，
            // 防止与状态徽标挤压导致横向溢出（可见性测试暴露的既有缺陷）
            Expanded(
              child: Text(
                '${l10n.commonCurrent}: ${_getTypeName(config.type)}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            // 本地存储没有“连接”概念，不展示未测试/成功等状态徽标与测试链，仅显示当前类型
            if (config.type != CloudBackendType.local) ...[
              const SizedBox(width: 12),
              // 「测试连接」文字链紧贴状态徽标左侧
              _buildTestConnectionLink(config, l10n),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          config.obfuscatedUrl(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SpitoutTokens.textSecondary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // 上次测试时间：仅当存在历史测试记录（点过测试连接）时展示
        if (testTime != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.cloudLastTestTime(_formatTestTime(testTime)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        // 测试结果详情文案（成功绿 / 失败红），纯内联展示，不弹窗
        if (testMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            testMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: testResult == true
                  ? SpitoutTokens.success(context)
                  : SpitoutTokens.error(context),
            ),
          ),
        ],
      ],
    );
  }

  /// 「测试连接」文字链：紧贴状态徽标左侧。
  ///
  /// 仅在非本地后端且配置有效时可点击；测试进行中显示转圈，不弹窗。
  /// 配置无效（如未填 URL）时置灰禁用，与头部按钮的业务禁用条件一致。
  Widget _buildTestConnectionLink(
    CloudServiceConfig config,
    AppLocalizations l10n,
  ) {
    final bool canTest = config.valid;
    return TextButton(
      onPressed: (canTest && !_testingConnection)
          ? () => _testConnection(config)
          : null,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _testingConnection
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              l10n.cloudTestConnection,
              style: TextStyle(
                decoration: TextDecoration.underline,
                color: canTest
                    ? Theme.of(context).colorScheme.primary
                    : SpitoutTokens.textTertiary(context),
              ),
            ),
    );
  }

  Widget _buildMultiDeviceWarning(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 纯动作卡片（点开多设备详情），无选中态，按统一原则补 Material+InkWell 涟漪
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showMultiDeviceDetailDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpitoutTokens.warning(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SpitoutTokens.warning(context).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.warning,
                color: SpitoutTokens.warning(context),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cloudMultiDeviceWarningTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SpitoutTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.cloudMultiDeviceWarningMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: SpitoutTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                AppIcons.info,
                color: SpitoutTokens.warning(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 列表分组主标题，仅作视觉分组，无交互。
  /// 左侧色条用于清晰区分不同分组（离线模式 / 备份同步 / 云端协同）。
  ///
  /// [subtitle] 为可选参数：仅「备份同步」分组需要副标题提示（如操作引导），
  /// 传入时在其下方多渲染一行灰色小字；其余分组不传，保持单行标题布局，互不影响。
  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? subtitle,
  }) {
    final Widget titleRow = Row(
      children: [
        // 左侧色条：用主题主色区分分组边界
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: SpitoutTokens.textPrimary(context),
          ),
        ),
      ],
    );

    // 未传入副标题时，复用单行标题的原有布局，确保最新代码逻辑完全不受影响
    if (subtitle == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: titleRow,
      );
    }

    // 传入副标题时，在标题下方补充一行说明性文案，使用次级文字颜色降低视觉权重
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SpitoutTokens.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    bool isConfigured = true,
    bool isDisabled = false,
    required VoidCallback onTap,
    VoidCallback? onConfigure,
    VoidCallback? onShowGuide,
  }) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          // 选中/未选中均保留 2px 边框占位（未选中为透明），确保固定高度下所有卡片高度完全一致，
          // 不会因是否绘制绿色边框而产生 2px 高度差。
          border: Border.all(
            color: isSelected
                ? SpitoutTokens.success(context)
                : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SectionCard(
          margin: EdgeInsets.zero,
          // 将 SectionCard 默认 12 内边距收窄为 5：按钮/勾选浮层 right:0 仅距卡片外边 5px（保留轻量边缘留白）。
          // 图标与文字的间距由内部 InkWell 的 Padding(horizontal:12, vertical:10) 进一步保证。
          padding: const EdgeInsets.all(5),
          // Stack 让「配置 / 教程」按钮行以绝对定位浮在卡片右下角，不参与布局流，
          // 因此卡片内容区高度可严格等于本地卡片（无按钮行）的自然高度，保证整页卡片等高一致。
          child: Stack(
            children: [
              // 基础层：整卡可点击选中。高度写死为本地卡片内容自然高度（约 71，
              // 即「上下内边距 10+10 + 图标/文案 51」），不随按钮行的有无而伸缩，
              // 从而所有卡片（含无按钮的本地存储卡）高度完全相同、且贴合本地卡片视觉。
              InkWell(
                onTap: isDisabled ? null : onTap,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 71,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 图标
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: iconColor, size: 18),
                        ),
                        const SizedBox(width: 10),

                        // 文字信息。副标题为单行省略（兼顾固定卡片高度与长 URL 不横向溢出），
                        // 按钮行已下移到卡片底部右下角，与副标题在视觉上错开，无需额外右侧避让。
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  if (isDisabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SpitoutTokens.textTertiary(
                                          context,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '不可用',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: SpitoutTokens.textTertiary(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: SpitoutTokens.textSecondary(
                                        context,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 选中标记浮层：固定在卡片右上角，与右下角按钮行对称、互不重叠。
              // 仅当选中且未禁用时显示，纯展示、不参与布局高度。
              if (isSelected && !isDisabled)
                Positioned(
                  top: 0,
                  right: 6,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: SpitoutTokens.success(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.check,
                      color: SpitoutTokens.textOnPrimary(context),
                      size: 18,
                    ),
                  ),
                ),

              // 覆盖层：配置 / 教程按钮行浮于右下角，拥有独立点击区域，
              // 不会触发卡片选中，也不参与布局高度（浮在卡片之上）。
              if (!isDisabled &&
                  ((isConfigured && onConfigure != null) ||
                      onShowGuide != null))
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onShowGuide != null)
                        TextButton.icon(
                          onPressed: onShowGuide,
                          icon: const Icon(AppIcons.help, size: 16),
                          label: Text(
                            AppLocalizations.of(context).commonTutorial,
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (isConfigured && onConfigure != null) ...[
                        if (onShowGuide != null) const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: onConfigure,
                          icon: const Icon(AppIcons.settings, size: 16),
                          label: Text(
                            AppLocalizations.of(context).commonConfigure,
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切换到指定云端后端（带二次确认）。
  /// 仅负责「是否切换」的确认交互,实际激活动作统一委托给 [_activateService],
  /// 保证「点击卡片切换」与「首次保存后引导切换」行为完全一致。
  Future<void> _switchService(CloudBackendType type) async {
    try {
      // 读取当前激活配置也纳入 try:prefs 损坏时切换流程要能给出反馈,不能静默失败。
      final active = await ref.read(activeCloudConfigProvider.future);

      if (active.type == type) return; // 已经是当前类型

      // 确认切换
      if (!mounted) return;
      final confirmed = await AppDialog.confirm(
        context,
        title: AppLocalizations.of(context).cloudSwitchConfirmTitle,
        message: AppLocalizations.of(context).cloudSwitchConfirmMessage,
      );
      if (confirmed != true || !mounted) return;

      await _activateService(type);
    } catch (e, st) {
      logger.error('CloudServicePage', '切换云服务失败', e, st);
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).cloudSwitchFailedTitle,
        message: AppLocalizations.of(context).commonOperationFailed,
      );
    }
  }

  /// 激活指定云端后端:选中并切换为当前同步配置。
  /// 不含二次确认弹窗,供 [_switchService]（切换确认后）与
  /// 首次创建配置保存后的「保存并切换」引导复用。
  Future<void> _activateService(CloudBackendType type) async {
    // 捕获 app 级 container：页面销毁后 container 仍随 app 生命周期存活,purge
    // 不受 mounted 守卫限制,避免"退出页面即跳过清理"的僵尸账本 bug。须在首个
    // await 之前捕获,此时 context 仍安全可用(点击回调同步进入,页面必然存活)。
    final container = ProviderScope.containerOf(context, listen: false);
    final store = ref.read(cloudServiceStoreProvider);

    try {
      // 读取当前激活配置也纳入 try:prefs 损坏时激活流程要能给出反馈,不能未处理冒泡。
      final active = await ref.read(activeCloudConfigProvider.future);

      // 切换前先登出旧服务,避免旧会话残留影响新配置的认证状态（本地存储无需登出）
      if (active.type != CloudBackendType.local) {
        try {
          final authService = await ref.read(authServiceProvider.future);
          await authService.signOut();
        } catch (_) {
          // 登出失败不影响后续激活,忽略
        }
      }

      // 激活新配置
      final success = await store.activate(type);
      if (!success && type != CloudBackendType.local) {
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSwitchFailedTitle,
            message: AppLocalizations.of(
              context,
            ).cloudSwitchFailedConfigMissing,
          );
        }
        return;
      }

      // 延迟刷新 providers，避免在 build 阶段触发 setState。
      // 只 invalidate「级联根」activeCloudConfigProvider + 各卡片配置 provider：
      // - authServiceProvider / syncServiceProvider / spitoutCloudProviderInstance
      //   三者都 ref.watch(activeCloudConfigProvider)，invalidate 级联根会自动重建
      //   它们，手写反而冗余且易漏（将来新增依赖 active 的 provider 不会不同步）。
      // container 已在方法开头捕获,此处直接用于 postFrame 清理。
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // 级联根：自动重建所有读活跃配置的 provider（auth / sync / cloud instance …）
        container.invalidate(activeCloudConfigProvider);
        // 各卡片「已配置」徽标刷新（handler 保存后已 invalidate 过一次，这里再刷
        // 一次确保激活态下卡片 UI 同步；纯属 UI 徽标，无副作用）。
        container.invalidate(supabaseConfigProvider);
        container.invalidate(webdavConfigProvider);
        // Surface 2：目标非 SpitoutCloud（local/webdav/s3/supabase 均属本地快照
        // 备份范畴）即全量清云端账本。SyncEngine 已随 invalidate 级联重建销毁,
        // purge 不会与其 GC1/WS 竞态重拉;回调用 container 执行,不受页面 mounted 限制。
        if (type != CloudBackendType.spitoutCloud) {
          final ok = await purgeLocalCloudLedgersWithContainer(container);
          // purge 失败不静默,提示用户云端账本残留需手动处理。
          if (!ok && mounted) {
            showToast(context, AppLocalizations.of(context).cloudPurgeFailed);
          }
        } else {
          // 登录 Spitout Cloud 后触发本地身份迁移(方案 B):
          // 把库中所有 localSelfId 引用改写为云 userId,使本地账本「我」与
          // 云身份统一。迁移幂等(标记位防重跑),失败仅记日志不阻塞 UI。
          // 放在 invalidate 之后:spitoutCloudProviderInstance 已级联重建,
          // 可读到当前登录用户的 cloud userId。
          await migrateLocalIdentityAfterLoginWithContainer(container);
        }
      });

      if (mounted) {
        showToast(
          context,
          AppLocalizations.of(context).cloudSwitchedTo(_getTypeName(type)),
        );
      }
    } catch (e, st) {
      logger.error('CloudServicePage', '激活云服务失败 type=${type.name}', e, st);
      if (mounted) {
        await AppDialog.error(
          context,
          title: AppLocalizations.of(context).cloudSwitchFailedTitle,
          message: AppLocalizations.of(context).commonOperationFailed,
        );
      }
    }
  }

  /// 配置保存成功后,统一询问用户是否立即切换为当前同步配置。
  /// 新建与编辑场景都会弹出（标题即「配置已保存」,承接保存反馈,故不额外 toast）。
  /// 返回 true 表示「保存并切换」;false（含点击遮罩关闭）表示「仅保存配置」。
  Future<bool> _confirmSaveSwitch() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final result = await AppDialog.confirm<bool>(
      context,
      title: l10n.cloudFirstSaveSwitchTitle,
      message: l10n.cloudFirstSaveSwitchMessage,
      cancelLabel: l10n.cloudSaveOnlyNoSwitch,
      okLabel: l10n.cloudSaveAndSwitch,
    );
    return result == true;
  }

  Future<void> _configureService(CloudBackendType type) async {
    // 根据类型显示配置对话框
    if (type == CloudBackendType.spitoutCloud) {
      await _showSpitoutCloudConfigDialog();
    } else if (type == CloudBackendType.supabase) {
      await _showSupabaseConfigDialog();
    } else if (type == CloudBackendType.webdav) {
      await _showWebdavConfigDialog();
    } else if (type == CloudBackendType.s3) {
      await _showS3ConfigDialog();
    }
  }

  Future<void> _showSpitoutCloudConfigDialog() async {
    final existing = await ref.read(spitoutCloudConfigProvider.future);

    if (!mounted) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    final result = await showAppSheetTop<dynamic>(
      context: context,
      child: SpitoutCloudConfigDialog(
        initialUrl: existing?.spitoutCloudBaseUrl ?? '',
        initialApiPrefix: existing?.spitoutCloudApiPrefix ?? '/api/v1',
        initialEmail: existing?.spitoutCloudEmail ?? '',
        // 密码不持久化(见 CloudServiceStore):即使旧版本残留过密码也不回填,
        // 避免把已失效的明文凭据再次展示/复用。
        initialPassword: '',
        canDelete: existing != null,
      ),
    );

    // 删除哨兵:用户在对话框标题栏点了清除图标
    if (result == '__DELETE__') {
      await _deleteConfig(CloudBackendType.spitoutCloud);
      return;
    }

    if (result != null) {
      final url = result['url'] as String;
      final apiPrefix = result['apiPrefix'] as String;
      final email = result['email'] as String;
      final password = result['password'] as String;

      // 必填校验(url)已下放到弹窗内联提示(不切换弹窗、保留已填内容),此处直接组装配置。
      final cfg = CloudServiceConfig(
        type: CloudBackendType.spitoutCloud,
        name: l10n.cloudSpitoutCloudTitle,
        spitoutCloudBaseUrl: url,
        spitoutCloudApiPrefix: apiPrefix.isEmpty ? '/api/v1' : apiPrefix,
        spitoutCloudEmail: email.isNotEmpty ? email : null,
      );

      try {
        // 仅持久化配置：不改动 _kActiveType，也不在此级联刷新 SyncEngine。
        // 这样「暂不切换」时活跃服务完全不动，符合「保存 ≠ 生效」原则。
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        // 仅刷新本类型配置列表，便于「暂不切换」时也能看到刚保存的配置
        ref.invalidate(spitoutCloudConfigProvider);

        // 弹窗询问用户是否立即切换激活；只有用户确认后，所有「生效」副作用
        // （登录、激活、同步、provider 重建）才会在下方统一执行。
        final wantSwitch = await _confirmSaveSwitch();
        if (wantSwitch && mounted) {
          // 登录在用户确认激活后统一执行，不手动 invalidate 任何云端 provider，
          // 全部交给 _activateService 经级联统一重建。
          if (email.isNotEmpty && password.isNotEmpty) {
            try {
              // 走可覆盖的工厂 provider：运行时为真实 createCloudServices；
              // Widget 测试经 overrideWith 注入桩，无需触网即可验证登录分支。
              final services = await ref.read(cloudServicesFactoryProvider)(
                cfg,
              );
              if (services.auth != null) {
                await services.auth!.signInWithEmail(
                  email: email,
                  password: password,
                );
                // 标记自动同步开启并刷新开关状态；不 invalidate 任何云端 provider，
                // 交给 _activateService 经级联统一重建
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('auto_sync', true);
                ref.invalidate(autoSyncValueProvider);

                if (mounted) {
                  showToast(
                    context,
                    AppLocalizations.of(context).cloudSpitoutCloudLoginSuccess,
                  );
                }
              }
              // 能走到这里 = 登录成功（有凭证且成功登录）或本配置无 auth 可登录
              // （services.auth == null）。两种情况都应继续到下方激活服务。
              // 若登录失败，会走下方 catch 的 return，不会到达此处，从而避免
              // 「登录失败却仍激活服务」的半成品脏状态。
            } on CloudAuthException catch (e) {
              // 账号鉴权失败（邮箱/密码错、账号被锁等）：纯账号问题，用友好文案
              // 弹窗告知；不激活服务、也不弹网络 toast（本就非网络问题）。
              if (mounted) {
                await AppDialog.error(
                  context,
                  title: AppLocalizations.of(
                    context,
                  ).cloudSpitoutCloudLoginFailed,
                  message: friendlyAuthError(e, context),
                );
              }
              return;
            } catch (e) {
              // 其余异常（网络超时、服务端 5xx 等）：同样不激活服务，用友好文案提示。
              if (mounted) {
                await AppDialog.error(
                  context,
                  title: AppLocalizations.of(
                    context,
                  ).cloudSpitoutCloudLoginFailed,
                  message: friendlyAuthError(e, context),
                );
              }
              return;
            }
          }

          // —— 激活：修改 _kActiveType + addPostFrameCallback 级联 invalidate 所有相关
          // provider；Bootstrap 的 auto-sync 在此之后自动接管首次同步
          // （fullPush 会注册新账本并上传全部实体，能力严格强于原 uploadCurrentLedger）。
          await _activateService(CloudBackendType.spitoutCloud);
        }
      } catch (e, st) {
        logger.error('CloudServicePage', '保存 Spitout Cloud 配置失败', e, st);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: AppLocalizations.of(context).commonOperationFailed,
          );
        }
      }
    }
  }

  Future<void> _showSupabaseConfigDialog() async {
    final existing = await ref.read(supabaseConfigProvider.future);

    if (!mounted) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    final result = await showAppSheetTop<dynamic>(
      context: context,
      child: SupabaseConfigDialog(
        initialUrl: existing?.supabaseUrl ?? '',
        initialKey: existing?.supabaseAnonKey ?? '',
        initialBucket: existing?.supabaseBucket ?? '',
        canDelete: existing != null,
      ),
    );

    // 删除哨兵:用户在对话框标题栏点了清除图标
    if (result == '__DELETE__') {
      await _deleteConfig(CloudBackendType.supabase);
      return;
    }

    if (result != null) {
      final url = result['url'] as String;
      final key = result['key'] as String;
      final bucket = result['bucket'] as String;

      // 必填校验(url/key)已下放到弹窗内联提示,此处直接组装配置。
      final cfg = CloudServiceConfig(
        type: CloudBackendType.supabase,
        name: l10n.cloudCustomSupabaseTitle,
        supabaseUrl: url,
        supabaseAnonKey: key,
        supabaseBucket: bucket.isEmpty ? 'spitout-backups' : bucket, // 业务层提供默认值
      );

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(supabaseConfigProvider);

        // 保存成功后统一引导用户是否立即切换（新建与编辑均弹出）
        // 注：不 invalidate activeCloudConfigProvider —— 「保存 ≠ 生效」，
        // 活跃服务是否切换由下方 _activateService 在用户确认后统一处理。
        {
          final wantSwitch = await _confirmSaveSwitch();
          if (wantSwitch && mounted) {
            await _activateService(CloudBackendType.supabase);
          }
        }
      } catch (e, st) {
        logger.error('CloudServicePage', '保存 Supabase 配置失败', e, st);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: AppLocalizations.of(context).commonOperationFailed,
          );
        }
      }
    }
  }

  Future<void> _showWebdavConfigDialog() async {
    final existing = await ref.read(webdavConfigProvider.future);

    if (!mounted) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    final result = await showAppSheetTop<dynamic>(
      context: context,
      child: WebdavConfigDialog(
        initialUrl: existing?.webdavUrl ?? '',
        initialUsername: existing?.webdavUsername ?? '',
        initialPassword: existing?.webdavPassword ?? '',
        initialPath: existing?.webdavRemotePath ?? '/',
        canDelete: existing != null,
      ),
    );

    // 删除哨兵:用户在对话框标题栏点了清除图标
    if (result == '__DELETE__') {
      await _deleteConfig(CloudBackendType.webdav);
      return;
    }

    if (result != null) {
      final url = result['url'] as String;
      final username = result['username'] as String;
      final password = result['password'] as String;
      final path = result['path'] as String;

      // 必填校验(url/username/password)已下放到弹窗内联提示,此处直接组装配置。
      final cfg = CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: l10n.cloudCustomWebdavTitle,
        webdavUrl: url,
        webdavUsername: username,
        webdavPassword: password,
        webdavRemotePath: path.isEmpty ? '/' : path,
      );

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(webdavConfigProvider);

        // 保存成功后统一引导用户是否立即切换（新建与编辑均弹出）
        // 注：不 invalidate activeCloudConfigProvider —— 「保存 ≠ 生效」，
        // 活跃服务是否切换由下方 _activateService 在用户确认后统一处理。
        {
          final wantSwitch = await _confirmSaveSwitch();
          if (wantSwitch && mounted) {
            await _activateService(CloudBackendType.webdav);
          }
        }
      } catch (e, st) {
        logger.error('CloudServicePage', '保存 WebDAV 配置失败', e, st);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: AppLocalizations.of(context).commonOperationFailed,
          );
        }
      }
    }
  }

  Future<void> _showS3ConfigDialog() async {
    final existing = await ref.read(s3ConfigProvider.future);

    if (!mounted) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    final result = await showAppSheetTop<dynamic>(
      context: context,
      child: S3ConfigDialog(
        initialEndpoint: existing?.s3Endpoint ?? '',
        initialRegion: existing?.s3Region ?? 'us-east-1',
        initialAccessKey: existing?.s3AccessKey ?? '',
        initialSecretKey: existing?.s3SecretKey ?? '',
        initialBucket: existing?.s3Bucket ?? '',
        initialUseSSL: existing?.s3UseSSL ?? true,
        initialPort: existing?.s3Port,
        canDelete: existing != null,
      ),
    );

    // 删除哨兵:用户在对话框标题栏点了清除图标
    if (result == '__DELETE__') {
      await _deleteConfig(CloudBackendType.s3);
      return;
    }

    if (result != null) {
      var endpoint = result['endpoint'] as String;
      final region = result['region'] as String;
      final accessKey = result['accessKey'] as String;
      final secretKey = result['secretKey'] as String;
      final bucket = result['bucket'] as String;
      final useSSL = result['useSSL'] as bool;
      final port = result['port'] as int?;

      // 必填校验(endpoint/accessKey/secretKey/bucket)已下放到弹窗内联提示,
      // 此处直接去除 endpoint 协议前缀并组装配置。
      endpoint = endpoint.replaceFirst(RegExp(r'^https?://'), '');

      final cfg = CloudServiceConfig(
        type: CloudBackendType.s3,
        name: l10n.cloudCustomS3Title,
        s3Endpoint: endpoint,
        s3Region: region.isEmpty ? 'us-east-1' : region,
        s3AccessKey: accessKey,
        s3SecretKey: secretKey,
        s3Bucket: bucket,
        s3UseSSL: useSSL,
        s3Port: port,
      );

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(s3ConfigProvider);

        // 保存成功后统一引导用户是否立即切换（新建与编辑均弹出）
        // 注：不 invalidate activeCloudConfigProvider —— 「保存 ≠ 生效」，
        // 活跃服务是否切换由下方 _activateService 在用户确认后统一处理。
        {
          final wantSwitch = await _confirmSaveSwitch();
          if (wantSwitch && mounted) {
            await _activateService(CloudBackendType.s3);
          }
        }
      } catch (e, st) {
        logger.error('CloudServicePage', '保存 S3 配置失败', e, st);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: AppLocalizations.of(context).commonOperationFailed,
          );
        }
      }
    }
  }

  /// 清除指定云端后端的本地配置,回到未配置状态。
  /// - 不删除云端已备份数据;
  /// - SpitoutCloud 先登出再清配置,避免残留 token 在下次启动自动恢复会话,
  ///   且登出必须发生在 clearConfig 之前 —— 否则 authServiceProvider 可能已
  ///   随配置缺失重建为 NoopAuthService,登出空跑;
  /// - 无需手动 activate(local):loadActive() 在配置缺失时自动回退本地存储。
  Future<void> _deleteConfig(CloudBackendType type) async {
    final l10n = AppLocalizations.of(context);
    // 捕获 app 级 container：页面销毁后仍可完成清理,绕开 mounted 守卫(兜底栅栏,
    // 宽条件防御"删 active 的非 local 云配置后 active 回退本地"的僵尸残留)。
    // 须在首个 await 之前捕获,此时 context 仍安全可用。
    final container = ProviderScope.containerOf(context, listen: false);
    // 二次确认,避免误触清空连接信息
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.cloudClearConfigConfirmTitle,
      message: l10n.cloudClearConfigConfirmMessage,
    );
    if (confirmed != true || !mounted) return;

    try {
      // 清配置前捕获当前 active：只有被清的正是当前激活的云配置时，
      // 清掉后 active 才会回退到本地（云失活），才需要清共享账本；
      // 清一个无关的非激活配置（如 active=spitoutCloud 时清 supabase）
      // 不影响云会话，绝不能动共享账本。
      final activeBefore = await ref.read(activeCloudConfigProvider.future);
      final wasActive = activeBefore.type == type;

      // 防御项:purge 完成后需要 invalidate 旧 SyncEngine family 实例释放孤儿 WS,
      // 故必须在关闸(会令其降级)与登出之前捕获当前 Spitout 云 provider 实例。
      final cloudProviderBefore = type == CloudBackendType.spitoutCloud
          ? await ref.read(spitoutCloudProviderInstance.future)
          : null;

      // P0-b 关闸:先关闸再 invalidate,让下游在旧值窗口内直接降级为
      // null / LocalOnly —— 绝不重建云客户端,否则 setRecoveryCredentials +
      // currentUser 会用旧邮密静默重登,把已登出的账号拉回来。
      ref.read(cloudDeactivationInProgressProvider.notifier).set(true);

      // SpitoutCloud 先清登录态(非阻塞):失败不阻断配置清除
      if (type == CloudBackendType.spitoutCloud) {
        try {
          final auth = await ref.read(authServiceProvider.future);
          await auth.signOut();
        } catch (e) {
          logger.warning('cloud_config', '清除 SpitoutCloud 登录态失败(非阻塞): $e');
        }
      }

      final store = ref.read(cloudServiceStoreProvider);
      await store.clearConfig(type);

      // 刷新所有受影响的 provider,让卡片/顶栏立即回到未配置态。
      // - activeCloudConfigProvider 是级联根：syncServiceProvider、authServiceProvider、
      //   spitoutCloudProviderInstance 都 watch 它，invalidate 后三者自动重建
      //   （sync/auth 回到 LocalOnly/Noop，spitoutCloud provider 回到 null），无需手写。
      // - 下方四条是本类型配置列表的独立 provider（不 watch active），用于刷新卡片
      //   「已配置」徽标，必须显式 invalidate。
      ref.invalidate(activeCloudConfigProvider);
      ref.invalidate(spitoutCloudConfigProvider);
      ref.invalidate(supabaseConfigProvider);
      ref.invalidate(webdavConfigProvider);
      ref.invalidate(s3ConfigProvider);

      // Surface 2：被清的正是当前 active 云配置 → active 回退本地、云失活，
      // 全量清云端账本（本地账本不受影响）。放到 postFrame 确保 SyncEngine
      // 已随 invalidate 级联重建销毁，避免与 engine 的 GC1/WS 竞态重拉。
      if (wasActive && type != CloudBackendType.local) {
        // container 已在方法开头捕获,此处直接用于 postFrame 清理,绕开 mounted 守卫
        // (防御"删 active 的非 local 云配置后 active 回退本地"的残留)。
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          var ok = true;
          try {
            ok = await purgeLocalCloudLedgersWithContainer(container);
          } finally {
            // 收尾动作必须在 purge 完成后执行:
            // 1. 开闸 → 下游因 watch 闸门自动重建,按已回退的本地配置装配;
            // 2. invalidate SyncEngine family 实例 → 触发 engine.dispose(),
            //    释放可能残留的孤儿 WebSocket(防御项)。
            container
                .read(cloudDeactivationInProgressProvider.notifier)
                .set(false);
            if (cloudProviderBefore != null) {
              container.invalidate(syncEngineProvider(cloudProviderBefore));
            }
          }
          // purge 失败不静默,提示用户云端账本残留需手动处理。
          if (!ok && mounted) {
            showToast(context, l10n.cloudPurgeFailed);
          }
        });
      } else {
        // 无需 purge 的路径同样要开闸,否则闸门只关不开会永久降级本地同步。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          container
              .read(cloudDeactivationInProgressProvider.notifier)
              .set(false);
        });
      }

      if (mounted) showToast(context, l10n.cloudClearConfigDone);
    } catch (e, st) {
      // 异常路径也必须开闸兜底,防止闸门只关不开卡死后续所有云同步。
      container.read(cloudDeactivationInProgressProvider.notifier).set(false);
      logger.error('cloud_config', '清除云端配置失败', e, st);
      if (mounted) showToast(context, '${l10n.commonError}: $e');
    }
  }

  String _getTypeName(CloudBackendType type) {
    switch (type) {
      case CloudBackendType.local:
        return AppLocalizations.of(context).cloudLocalStorageTitle;
      case CloudBackendType.supabase:
        return 'Supabase';
      case CloudBackendType.webdav:
        return 'WebDAV';
      case CloudBackendType.s3:
        return 'S3';
      case CloudBackendType.spitoutCloud:
        return 'Spitout Cloud';
    }
  }

  // 测试连接
  Future<void> _testConnection(CloudServiceConfig config) async {
    if (!config.valid || config.type == CloudBackendType.local) return;

    // 在异步调用前提取 l10n，避免 use_build_context_synchronously 警告
    final l10n = AppLocalizations.of(context);

    setState(() => _testingConnection = true);
    try {
      // 网络探测全部下沉到 CloudConnectionTester(services 层),
      // 页面只负责把结构化结果映射为本地化文案并展示。
      final result = await ref.read(cloudConnectionTesterProvider).test(config);
      final error = result.error;
      final message = result.success
          ? l10n.cloudTestSuccessMessage
          : _mapConnectionError(error, l10n);

      await _setTestResult(config.id, result.success, message);
    } catch (e, st) {
      logger.error('CloudServicePage', '测试连接异常', e, st);
      // 异常兜底：同样内联展示失败状态，不弹窗
      await _setTestResult(config.id, false, l10n.cloudTestFailedMessage);
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  /// 把测试服务的结构化错误映射为本地化文案。
  String _mapConnectionError(
    CloudConnectionTestError? error,
    AppLocalizations l10n,
  ) {
    if (error == null) return l10n.cloudTestFailedMessage;
    switch (error.type) {
      case CloudConnectionTestErrorType.authFailed:
        return l10n.cloudErrorAuthFailed;
      case CloudConnectionTestErrorType.authFailedCredentials:
        return l10n.cloudErrorAuthFailedCredentials;
      case CloudConnectionTestErrorType.accessDenied:
        return l10n.cloudErrorAccessDenied;
      case CloudConnectionTestErrorType.webdavNotSupported:
        return l10n.cloudErrorWebdavNotSupported;
      case CloudConnectionTestErrorType.pathNotFound:
        return l10n.cloudErrorPathNotFound(error.path ?? '');
      case CloudConnectionTestErrorType.serverStatus:
        return l10n.cloudErrorServerStatus('${error.statusCode ?? ''}');
      case CloudConnectionTestErrorType.network:
        return l10n.cloudErrorNetwork(error.rawMessage ?? '');
      case CloudConnectionTestErrorType.initFailed:
      case CloudConnectionTestErrorType.unknown:
        // 初始化/未知错误不展示原始堆栈,统一给失败文案;细节已由服务层记录日志。
        return l10n.cloudTestFailedMessage;
    }
  }

  /// 写入「测试连接」结果到内存并持久化到 SharedPreferences。
  ///
  /// 统一处理三件套：结果(bool) / 时间(DateTime) / 详情文案(String)，
  /// 供 _buildConnectionStatus 内联渲染。持久化失败仅记日志，不影响内存展示。
  Future<void> _setTestResult(String id, bool success, String message) async {
    final now = DateTime.now();
    _connectionTestResults[id] = success;
    _connectionTestTimes[id] = now;
    _connectionTestMessages[id] = message;
    try {
      await _prefs?.setBool('cloud_test_result_$id', success);
      await _prefs?.setInt('cloud_test_time_$id', now.millisecondsSinceEpoch);
      await _prefs?.setString('cloud_test_message_$id', message);
    } catch (e, st) {
      logger.error('CloudServicePage', '持久化测试连接结果失败: $e', e, st);
    }
    if (mounted) setState(() {});
  }

  /// 进入页面时从 SharedPreferences 恢复各后端的测试结果，保证重新进页面保留上次状态。
  Future<void> _loadPersistedTestResults() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      for (final type in CloudBackendType.values) {
        final id = type.name;
        final result = _prefs!.getBool('cloud_test_result_$id');
        final time = _prefs!.getInt('cloud_test_time_$id');
        final message = _prefs!.getString('cloud_test_message_$id');
        if (result != null) _connectionTestResults[id] = result;
        if (time != null) {
          _connectionTestTimes[id] = DateTime.fromMillisecondsSinceEpoch(time);
        }
        if (message != null) _connectionTestMessages[id] = message;
      }
      if (mounted) setState(() {});
    } catch (e, st) {
      logger.error('CloudServicePage', '加载测试连接历史结果失败: $e', e, st);
    }
  }

  /// 将时间格式化为固定的 YYYY-MM-DD HH:MM:SS（手动格式化，避免 locale 改变日期顺序）。
  String _formatTestTime(DateTime dt) {
    // 使用函数声明而非变量赋值来绑定函数，避免 prefer_function_declarations_over_variables 警告
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
  }
}

// Supabase配置对话框(独立Widget,避免controller生命周期问题)
