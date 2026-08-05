import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spitout/cloud/spitout_cloud.dart'
    show
        CloudBackendType,
        CloudServiceConfig,
        CloudAuthException,
        createCloudServices;
import 'package:spitout/providers/sync/sync_providers.dart';
import 'package:spitout/providers/sync/shared_ledger_providers.dart'
    show purgeLocalCloudLedgersWithContainer;
import 'package:spitout/providers/core/database_providers.dart';
import 'package:spitout/providers/providers.dart' show localSelfIdProvider;
import 'package:spitout/services/data/tx_author_service.dart';
import 'package:spitout/services/data/local_identity_migration_service.dart';
import '../../core/logging/logger_service.dart';
import '../settings/local_backup_page.dart';
import 'cloud_sync_section.dart';
import 'spitout_cloud_sync_section.dart';
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
                          onShowGuide: _showWebdavHelpDialog,
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
                          onShowGuide: _showS3HelpDialog,
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
                          onShowGuide: _showSupabaseHelpDialog,
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
                          onShowGuide: _showSpitoutCloudHelpDialog,
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
      logger.error('CloudServicePage', '下拉刷新失败: $e', e, stackTrace);
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
        onTap: () => _showMultiDeviceDetailDialog(context),
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

  void _showMultiDeviceDetailDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryText = SpitoutTokens.textPrimary(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpitoutTokens.surfaceElevated(context),
        title: Row(
          children: [
            Icon(
              AppIcons.info,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.cloudSyncGuideTitle,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            // ignore: sort_child_properties_last
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 工作原理
                _buildGuideSection(
                  context,
                  icon: AppIcons.refresh,
                  title: l10n.cloudSyncGuideHowItWorks,
                  items: [
                    l10n.cloudSyncGuideHowItem1,
                    l10n.cloudSyncGuideHowItem2,
                    l10n.cloudSyncGuideHowItem3,
                  ],
                ),
                const SizedBox(height: 16),
                // 正确用法
                _buildGuideSection(
                  context,
                  icon: AppIcons.checkCircle,
                  iconColor: Colors.green,
                  title: l10n.cloudSyncGuideCorrect,
                  items: [
                    l10n.cloudSyncGuideCorrectItem1,
                    l10n.cloudSyncGuideCorrectItem2,
                    l10n.cloudSyncGuideCorrectItem3,
                    l10n.cloudSyncGuideCorrectItem4,
                  ],
                ),
                const SizedBox(height: 16),
                // 错误用法
                _buildGuideSection(
                  context,
                  icon: AppIcons.cancel,
                  iconColor: Colors.red,
                  title: l10n.cloudSyncGuideWrong,
                  items: [
                    l10n.cloudSyncGuideWrongItem1,
                    l10n.cloudSyncGuideWrongItem2,
                    l10n.cloudSyncGuideWrongItem3,
                  ],
                ),
                const SizedBox(height: 16),
                // 已知限制
                _buildGuideSection(
                  context,
                  icon: AppIcons.warning,
                  iconColor: SpitoutTokens.warning(context),
                  title: l10n.cloudSyncGuideLimitations,
                  items: [
                    l10n.cloudSyncGuideLimitItem1,
                    l10n.cloudSyncGuideLimitItem2,
                    l10n.cloudSyncGuideLimitItem3,
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cloudSyncGuideGotIt,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: iconColor ?? SpitoutTokens.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: SpitoutTokens.textPrimary(context),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: SpitoutTokens.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: SpitoutTokens.textSecondary(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  void _showSupabaseHelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.storage, color: SpitoutTokens.brandSupabase),
            const SizedBox(width: 8),
            Text(l10n.cloudSupabaseHelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(l10n.cloudSupabaseHelpIntro, [
                l10n.cloudSupabaseHelpIntro1,
                l10n.cloudSupabaseHelpIntro2,
                l10n.cloudSupabaseHelpIntro3,
              ]),
              const SizedBox(height: 16),
              _buildHelpSection(l10n.cloudSupabaseHelpSteps, [
                l10n.cloudSupabaseHelpStep1,
                l10n.cloudSupabaseHelpStep2,
                l10n.cloudSupabaseHelpStep3,
                l10n.cloudSupabaseHelpStep4,
                l10n.cloudSupabaseHelpStep5,
              ]),
              const SizedBox(height: 16),
              _buildHelpSection(l10n.cloudSupabaseHelpFaq, [
                '• ${l10n.cloudSupabaseHelpFaq1}',
                '• ${l10n.cloudSupabaseHelpFaq2}',
                '• ${l10n.cloudSupabaseHelpFaq3}',
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandSupabase.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.info,
                      color: SpitoutTokens.brandSupabase,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.cloudSupabaseHelpNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: SpitoutTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  void _showSpitoutCloudHelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.cloudQueue, color: SpitoutTokens.brandCloud),
            const SizedBox(width: 8),
            Text(l10n.cloudTutorialTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 介绍
              Text(
                l10n.cloudTutorialIntro,
                style: TextStyle(
                  fontSize: 13,
                  color: SpitoutTokens.textSecondary(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // 4 步教程
              _buildBeeCloudStep(
                '1',
                l10n.cloudTutorialStep1Title,
                l10n.cloudTutorialStep1Desc,
              ),
              _buildBeeCloudStep(
                '2',
                l10n.cloudTutorialStep2Title,
                l10n.cloudTutorialStep2Desc,
              ),
              _buildBeeCloudStep(
                '3',
                l10n.cloudTutorialStep3Title,
                l10n.cloudTutorialStep3Desc,
              ),
              _buildBeeCloudStep(
                '4',
                l10n.cloudTutorialStep4Title,
                l10n.cloudTutorialStep4Desc,
              ),
              const SizedBox(height: 4),
              // 特色功能 —— 强调 Web + 多设备协同 + 多用户 + 共享账本
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandCloud.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cloudTutorialFeaturesTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: SpitoutTokens.brandCloud,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.cloudTutorialFeature1,
                      style: const TextStyle(fontSize: 12.5, height: 1.7),
                    ),
                    Text(
                      l10n.cloudTutorialFeature2,
                      style: const TextStyle(fontSize: 12.5, height: 1.7),
                    ),
                    Text(
                      l10n.cloudTutorialFeature3,
                      style: const TextStyle(fontSize: 12.5, height: 1.7),
                    ),
                    Text(
                      l10n.cloudTutorialFeature4,
                      style: const TextStyle(fontSize: 12.5, height: 1.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Tip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandCloud.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.info,
                      color: SpitoutTokens.brandCloud,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${l10n.cloudTutorialTipTitle}: ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: SpitoutTokens.textSecondary(context),
                              ),
                            ),
                            TextSpan(
                              text: l10n.cloudTutorialTipDesc,
                              style: TextStyle(
                                fontSize: 13,
                                color: SpitoutTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cloudTutorialGotIt),
          ),
        ],
      ),
    );
  }

  Widget _buildBeeCloudStep(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: SpitoutTokens.brandCloud,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: SpitoutTokens.textSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWebdavHelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.folderShared, color: SpitoutTokens.brandWebdav),
            const SizedBox(width: 8),
            Text(l10n.cloudWebdavHelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(l10n.cloudWebdavHelpIntro, [
                l10n.cloudWebdavHelpIntro1,
                l10n.cloudWebdavHelpIntro2,
                l10n.cloudWebdavHelpIntro3,
              ]),
              const SizedBox(height: 16),
              _buildHelpSection(l10n.cloudWebdavHelpProviders, [
                l10n.cloudWebdavHelpProvider1,
                l10n.cloudWebdavHelpProvider2,
                l10n.cloudWebdavHelpProvider3,
                l10n.cloudWebdavHelpProvider4,
              ]),
              const SizedBox(height: 16),
              _buildHelpSection(l10n.cloudWebdavHelpSteps, [
                l10n.cloudWebdavHelpStep1,
                l10n.cloudWebdavHelpStep2,
                l10n.cloudWebdavHelpStep3,
                l10n.cloudWebdavHelpStep4,
                l10n.cloudWebdavHelpStep5,
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandWebdav.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.info,
                      color: SpitoutTokens.brandWebdav,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.cloudWebdavHelpNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: SpitoutTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  void _showS3HelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.storage, color: SpitoutTokens.brandS3),
            const SizedBox(width: 8),
            Text(l10n.cloudS3HelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(l10n.cloudS3HelpIntro, [
                l10n.cloudS3HelpIntro1,
                l10n.cloudS3HelpIntro2,
                l10n.cloudS3HelpIntro3,
              ]),
              const SizedBox(height: 16),
              _buildHelpSection(l10n.cloudS3HelpProviders, [
                l10n.cloudS3HelpProvider1,
                l10n.cloudS3HelpProvider2,
                l10n.cloudS3HelpProvider3,
                l10n.cloudS3HelpProvider4,
                l10n.cloudS3HelpProvider5,
                l10n.cloudS3HelpProvider6,
                l10n.cloudS3HelpProvider7,
              ]),
              const SizedBox(height: 16),
              _buildHelpSection(l10n.cloudS3HelpSteps, [
                l10n.cloudS3HelpStep1,
                l10n.cloudS3HelpStep2,
                l10n.cloudS3HelpStep3,
                l10n.cloudS3HelpStep4,
                l10n.cloudS3HelpStep5,
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.brandS3.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.info, color: SpitoutTokens.brandS3, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.cloudS3HelpNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: SpitoutTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: SpitoutTokens.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 13,
                color: SpitoutTokens.textSecondary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 切换到指定云端后端（带二次确认）。
  /// 仅负责「是否切换」的确认交互,实际激活动作统一委托给 [_activateService],
  /// 保证「点击卡片切换」与「首次保存后引导切换」行为完全一致。
  Future<void> _switchService(CloudBackendType type) async {
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
    final active = await ref.read(activeCloudConfigProvider.future);

    try {
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
          await _migrateLocalIdentityAfterLogin(container);
        }
      });

      if (mounted) {
        showToast(
          context,
          AppLocalizations.of(context).cloudSwitchedTo(_getTypeName(type)),
        );
      }
    } catch (e) {
      if (mounted) {
        await AppDialog.error(
          context,
          title: AppLocalizations.of(context).cloudSwitchFailedTitle,
          message: '$e',
        );
      }
    }
  }

  /// 登录 Spitout Cloud 后迁移本地身份(方案 B)。
  ///
  /// 读取当前登录用户的云 userId 与设备 localSelfId,把库中所有 localSelfId
  /// 引用改写为云 userId。迁移幂等(同一账号只跑一次),失败仅记日志不阻塞 UI。
  /// 用 container 而非 ref,避免页面销毁后迁移被跳过。
  Future<void> _migrateLocalIdentityAfterLogin(
    ProviderContainer container,
  ) async {
    try {
      final cloud = await container.read(spitoutCloudProviderInstance.future);
      if (cloud == null) return;
      final cloudUserId = await TxAuthorService.currentUserId(cloud.auth);
      if (cloudUserId == null || cloudUserId.isEmpty) return;
      final localSelfId = await container.read(localSelfIdProvider.future);
      final db = container.read(databaseProvider);
      await LocalIdentityMigrationService.migrateToCloudUserId(
        db: db,
        cloudUserId: cloudUserId,
        localSelfId: localSelfId,
      );
    } catch (e, st) {
      logger.warning('CloudServicePage', '登录后本地身份迁移失败(非阻塞,下次登录会重试)', '$e\n$st');
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
      child: _SpitoutCloudConfigDialog(
        initialUrl: existing?.spitoutCloudBaseUrl ?? '',
        initialApiPrefix: existing?.spitoutCloudApiPrefix ?? '/api/v1',
        initialEmail: existing?.spitoutCloudEmail ?? '',
        initialPassword: existing?.spitoutCloudPassword ?? '',
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
      } catch (e) {
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: e.toString(),
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
      child: _SupabaseConfigDialog(
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
      } catch (e) {
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: e.toString(),
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
      child: _WebdavConfigDialog(
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
      } catch (e) {
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: e.toString(),
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
      child: _S3ConfigDialog(
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
      } catch (e) {
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudSaveFailed,
            message: e.toString(),
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
      bool connectionSuccess = false;
      String? errorDetail;

      try {
        switch (config.type) {
          case CloudBackendType.local:
            break;

          case CloudBackendType.supabase:
            // Supabase 连接测试 - 查询不存在的表验证 URL 和 anon key
            // 200 或 404 表示连接正常且 key 有效，401/403 表示 key 无效
            final testUrl = Uri.parse(
              '${config.supabaseUrl}/rest/v1/_spitout_health_check?select=id&limit=1',
            );
            final response = await http
                .get(
                  testUrl,
                  headers: {
                    'apikey': config.supabaseAnonKey!,
                    'Authorization': 'Bearer ${config.supabaseAnonKey}',
                  },
                )
                .timeout(const Duration(seconds: 10));

            if (response.statusCode == 200 ||
                response.statusCode == 404 ||
                response.statusCode == 406) {
              connectionSuccess = true;
            } else if (response.statusCode == 401 ||
                response.statusCode == 403) {
              throw Exception(l10n.cloudErrorAuthFailed);
            } else {
              throw Exception(
                l10n.cloudErrorServerStatus('${response.statusCode}'),
              );
            }
            break;

          case CloudBackendType.webdav:
            // WebDAV 连接测试 - 发送 OPTIONS 请求
            final testUrl = Uri.parse(config.webdavUrl!);
            final credentials = base64Encode(
              utf8.encode('${config.webdavUsername}:${config.webdavPassword}'),
            );

            final request = http.Request('OPTIONS', testUrl);
            request.headers['Authorization'] = 'Basic $credentials';

            final streamedResponse = await request.send().timeout(
              const Duration(seconds: 10),
            );
            final response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode == 200 || response.statusCode == 204) {
              final davHeader = response.headers['dav'];
              if (davHeader != null || response.headers.containsKey('allow')) {
                connectionSuccess = true;
              } else {
                throw Exception(l10n.cloudErrorWebdavNotSupported);
              }
            } else if (response.statusCode == 401) {
              throw Exception(l10n.cloudErrorAuthFailedCredentials);
            } else if (response.statusCode == 403) {
              throw Exception(l10n.cloudErrorAccessDenied);
            } else if (response.statusCode == 404) {
              throw Exception(l10n.cloudErrorPathNotFound(testUrl.path));
            } else {
              throw Exception(
                l10n.cloudErrorServerStatus('${response.statusCode}'),
              );
            }
            break;

          case CloudBackendType.spitoutCloud:
            // Spitout Cloud 连接测试 - 调用健康检查接口
            try {
              final services = await createCloudServices(config);
              if (services.provider == null) {
                throw Exception('Spitout Cloud provider 初始化失败');
              }
              // 尝试列出文件验证连接
              await services.provider!.storage.list(path: '');
              connectionSuccess = true;
            } catch (e) {
              String errorMsg = e.toString();
              if (errorMsg.contains('Exception:')) {
                errorMsg = errorMsg.replaceFirst('Exception: ', '');
              }
              throw Exception(errorMsg);
            }
            break;

          case CloudBackendType.s3:
            // S3 连接测试 - 尝试列出对象（ListObjects）
            try {
              // 确保 endpoint 不包含协议前缀
              final cleanedConfig = CloudServiceConfig(
                type: config.type,
                name: config.name,
                s3Endpoint: config.s3Endpoint?.replaceFirst(
                  RegExp(r'^https?://'),
                  '',
                ),
                s3Region: config.s3Region,
                s3AccessKey: config.s3AccessKey,
                s3SecretKey: config.s3SecretKey,
                s3Bucket: config.s3Bucket,
                s3UseSSL: config.s3UseSSL,
                s3Port: config.s3Port,
              );

              logger.info(
                'CloudServicePage',
                'S3 连接测试开始: endpoint=${cleanedConfig.s3Endpoint}, bucket=${cleanedConfig.s3Bucket}',
              );

              final services = await createCloudServices(cleanedConfig);

              logger.info(
                'CloudServicePage',
                'S3 provider 创建结果: ${services.provider != null ? "成功" : "失败"}',
              );

              if (services.provider == null) {
                throw Exception(
                  'S3 provider 初始化失败 - createCloudServices 返回 null',
                );
              }

              // 实际测试连接：尝试列出 bucket 中的文件
              // 这会触发真正的 S3 API 调用，验证凭证和连接
              logger.info('CloudServicePage', 'S3 开始测试列出文件');
              await services.provider!.storage.list(path: '');

              logger.info('CloudServicePage', 'S3 连接测试成功');
              connectionSuccess = true;
            } catch (e, stackTrace) {
              logger.error('CloudServicePage', 'S3 连接测试失败: $e', e, stackTrace);
              // 提取最有用的错误信息
              String errorMsg = e.toString();
              if (errorMsg.contains('CloudConfigurationException:')) {
                errorMsg = errorMsg.replaceFirst(
                  'CloudConfigurationException: ',
                  '',
                );
              } else if (errorMsg.contains('Exception:')) {
                errorMsg = errorMsg.replaceFirst('Exception: ', '');
              }
              throw Exception(errorMsg);
            }
            break;
        }
      } on http.ClientException catch (e) {
        connectionSuccess = false;
        errorDetail = l10n.cloudErrorNetwork(e.message);
      } on Exception catch (e) {
        connectionSuccess = false;
        errorDetail = e.toString().replaceFirst('Exception: ', '');
      } catch (e) {
        connectionSuccess = false;
        errorDetail = e.toString();
      }

      // 纯内联展示测试结果（不弹窗）：写入内存状态并持久化到 SharedPreferences，
      // 由 _buildConnectionStatus 在头部信息块内联渲染「上次测试时间 / 状态详情」。
      await _setTestResult(
        config.id,
        connectionSuccess,
        connectionSuccess
            ? l10n.cloudTestSuccessMessage
            : (errorDetail ?? l10n.cloudTestFailedMessage),
      );
    } catch (e, st) {
      logger.error('CloudServicePage', '测试连接异常: $e', e, st);
      // 异常兜底：同样内联展示失败状态，不弹窗
      await _setTestResult(config.id, false, l10n.cloudTestFailedMessage);
    } finally {
      if (mounted) setState(() => _testingConnection = false);
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
class _SpitoutCloudConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialApiPrefix;
  final String initialEmail;
  final String initialPassword;
  // 已存在配置时标题栏显示清除图标;点击后由弹窗自身用路由 context pop 删除哨兵
  final bool canDelete;

  const _SpitoutCloudConfigDialog({
    required this.initialUrl,
    required this.initialApiPrefix,
    this.initialEmail = '',
    this.initialPassword = '',
    this.canDelete = false,
  });

  @override
  State<_SpitoutCloudConfigDialog> createState() =>
      _SpitoutCloudConfigDialogState();
}

class _SpitoutCloudConfigDialogState extends State<_SpitoutCloudConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController apiPrefixController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  // 显式 FocusNode:用于焦点链式切换,避免多输入框切换时键盘反复收起/拉起。
  late final FocusNode urlFocus;
  late final FocusNode emailFocus;
  late final FocusNode passwordFocus;
  bool obscurePassword = true;
  // 内联校验状态:url 为必填,保存时若为空则在字段下方显示弱提示,不切换弹窗、不丢失已填内容。
  String? _urlError;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    apiPrefixController = TextEditingController(text: widget.initialApiPrefix);
    emailController = TextEditingController(text: widget.initialEmail);
    passwordController = TextEditingController(text: widget.initialPassword);
    urlFocus = FocusNode();
    emailFocus = FocusNode();
    passwordFocus = FocusNode();
  }

  @override
  void dispose() {
    urlController.dispose();
    apiPrefixController.dispose();
    emailController.dispose();
    passwordController.dispose();
    // 释放焦点节点,防止内存泄漏与悬空引用。
    urlFocus.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用顶部贴边弹层(AppSheet + 自定义路由 showAppSheetTop):彻底规避底部弹层
    // AnimatedPadding 随键盘 viewInsets 动画导致的「弹窗弹跳」。弹层钉在屏幕顶部、
    // 高度随键盘瞬缩(普通 ConstrainedBox,无动画),保存/取消始终在键盘之上可点;
    // 删除图标常驻标题栏 trailing,内容区可滚动。
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: AppLocalizations.of(context).cloudConfigureSpitoutCloudTitle,
      // 删除图标放在标题栏右侧 trailing,吸顶时常驻可见。
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(AppIcons.delete, size: 22),
              tooltip: AppLocalizations.of(context).cloudClearConfig,
              // 用弹窗自身路由 context 直接 pop 删除哨兵。
              onPressed: () => Navigator.of(context).pop('__DELETE__'),
            )
          : null,
      showGrabHandle: false,
      // 内容区顶部内边距为 0:叠加 header 底部 0 后,标题↔首行间距收敛到最小
      // (仅剩标题在 32px 行内居中产生的 ~4px 行内空隙)。
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SingleChildScrollView(
        // ignore: sort_child_properties_last
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              focusNode: urlFocus,
              textInputAction: TextInputAction.next,
              // 回车/下一步:焦点移交给下一个字段,避免键盘因焦点丢失而收起。
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(emailFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudUrlLabel,
                hintText: AppLocalizations.of(context).cloudSpitoutCloudUrlHint,
                // 必填项为空时的内联弱提示(不弹窗),保留已填内容。
                errorText: _urlError,
              ),
              keyboardType: TextInputType.url,
            ),
            // API Prefix 输入框移除 —— 后端固定 /api/v1,前端用户没有配置场景;
            // 保留 apiPrefixController(默认 /api/v1)让 save 流程不破。
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              focusNode: emailFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(passwordFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudEmailLabel,
                hintText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudEmailHint,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              focusNode: passwordFocus,
              textInputAction: TextInputAction.done,
              // 最后一个字段:完成后收起键盘,不向下传递焦点。
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudPasswordLabel,
                hintText: AppLocalizations.of(
                  context,
                ).cloudSpitoutCloudPasswordHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? AppIcons.visibility
                        : AppIcons.visibilityOff,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: obscurePassword,
            ),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // 内联校验:必填项 url 为空时仅在字段下方显示弱提示,不切换弹窗、不丢失已填内容。
                final url = urlController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                setState(() {
                  _urlError = url.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                });
                if (_urlError != null) return;
                Navigator.of(context).pop({
                  'url': url,
                  'apiPrefix': apiPrefixController.text.trim(),
                  'email': email,
                  'password': password,
                });
              },
              child: Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupabaseConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialKey;
  final String initialBucket;
  // 已存在配置时标题栏显示清除图标;点击后由弹窗自身用路由 context pop 删除哨兵
  final bool canDelete;

  const _SupabaseConfigDialog({
    required this.initialUrl,
    required this.initialKey,
    required this.initialBucket,
    this.canDelete = false,
  });

  @override
  State<_SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<_SupabaseConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController keyController;
  late final TextEditingController bucketController;
  // 显式 FocusNode:用于焦点链式切换。
  late final FocusNode urlFocus;
  late final FocusNode keyFocus;
  late final FocusNode bucketFocus;
  // 内联校验状态:url 与 key 为必填,保存时若为空则在对应字段下方显示弱提示。
  String? _urlError;
  String? _keyError;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    keyController = TextEditingController(text: widget.initialKey);
    bucketController = TextEditingController(text: widget.initialBucket);
    urlFocus = FocusNode();
    keyFocus = FocusNode();
    bucketFocus = FocusNode();
  }

  @override
  void dispose() {
    urlController.dispose();
    keyController.dispose();
    bucketController.dispose();
    // 释放焦点节点,防止内存泄漏与悬空引用。
    urlFocus.dispose();
    keyFocus.dispose();
    bucketFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用顶部贴边弹层(showAppSheetTop),消除底部弹层 + 键盘 viewInsets 动画的弹窗弹跳。
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: AppLocalizations.of(context).cloudConfigureSupabaseTitle,
      // 删除图标常驻于标题栏右侧 trailing。
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(AppIcons.delete, size: 22),
              tooltip: AppLocalizations.of(context).cloudClearConfig,
              // 删除图标按钮高度固定 32px:默认 48px 最小高度会把标题栏 Row 撑到 48px,
              // 导致标题居中后下方多挤 12px 空白、且「无图标」状态 Row 仅 24px,两种状态
              // 顶部留白不一致。固定 32px 后 Row 恒为 32px,标题上沿与图标上沿对齐,
              // 标题↔首行间距收敛到 ~8px。点击宽度仍保留 48px,保证可点性。
              constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop('__DELETE__'),
            )
          : null,
      showGrabHandle: false,
      // 内容区顶部内边距为 0:叠加 header 底部 0 后,标题↔首行间距收敛到最小
      // (仅剩标题在 32px 行内居中产生的 ~4px 行内空隙)。
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SingleChildScrollView(
        // ignore: sort_child_properties_last
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              focusNode: urlFocus,
              textInputAction: TextInputAction.next,
              // 焦点移交给 key 字段。
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(keyFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudSupabaseUrlLabel,
                hintText: AppLocalizations.of(context).cloudSupabaseUrlHint,
                errorText: _urlError,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            // anon key 为多行输入框,保持换行动作,不强制 next 链式切换。
            TextField(
              controller: keyController,
              focusNode: keyFocus,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudAnonKeyLabel,
                hintText: AppLocalizations.of(
                  context,
                ).cloudSupabaseAnonKeyHintLong,
                errorText: _keyError,
              ),
              keyboardType: TextInputType.text,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bucketController,
              focusNode: bucketFocus,
              textInputAction: TextInputAction.done,
              // 最后一个字段:完成后收起键盘。
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudSupabaseBucketLabel,
                hintText: AppLocalizations.of(context).cloudSupabaseBucketHint,
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // 内联校验:url 与 key 必填,任一为空则在对应字段下显示弱提示,不关闭弹窗。
                final url = urlController.text.trim();
                final key = keyController.text.trim();
                setState(() {
                  _urlError = url.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _keyError = key.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                });
                if (_urlError != null || _keyError != null) return;
                Navigator.of(context).pop({
                  'url': url,
                  'key': key,
                  'bucket': bucketController.text.trim(),
                });
              },
              child: Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

// WebDAV配置对话框(独立Widget,避免controller生命周期问题)
class _WebdavConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialUsername;
  final String initialPassword;
  final String initialPath;
  // 已存在配置时标题栏显示清除图标;点击后由弹窗自身用路由 context pop 删除哨兵
  final bool canDelete;

  const _WebdavConfigDialog({
    required this.initialUrl,
    required this.initialUsername,
    required this.initialPassword,
    required this.initialPath,
    this.canDelete = false,
  });

  @override
  State<_WebdavConfigDialog> createState() => _WebdavConfigDialogState();
}

class _WebdavConfigDialogState extends State<_WebdavConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;
  late final TextEditingController pathController;
  // 显式 FocusNode:用于焦点链式切换。
  late final FocusNode urlFocus;
  late final FocusNode usernameFocus;
  late final FocusNode passwordFocus;
  late final FocusNode pathFocus;
  bool obscurePassword = true;
  // 内联校验状态:url/username/password 为必填,保存时若为空则在对应字段下显示弱提示。
  String? _urlError;
  String? _usernameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    usernameController = TextEditingController(text: widget.initialUsername);
    passwordController = TextEditingController(text: widget.initialPassword);
    pathController = TextEditingController(text: widget.initialPath);
    urlFocus = FocusNode();
    usernameFocus = FocusNode();
    passwordFocus = FocusNode();
    pathFocus = FocusNode();
  }

  @override
  void dispose() {
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    pathController.dispose();
    // 释放焦点节点,防止内存泄漏与悬空引用。
    urlFocus.dispose();
    usernameFocus.dispose();
    passwordFocus.dispose();
    pathFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用顶部贴边弹层(showAppSheetTop),消除底部弹层 + 键盘 viewInsets 动画的弹窗弹跳。
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: AppLocalizations.of(context).cloudConfigureWebdavTitle,
      // 删除图标常驻于标题栏右侧 trailing。
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(AppIcons.delete, size: 22),
              tooltip: AppLocalizations.of(context).cloudClearConfig,
              // 删除图标按钮高度固定 32px:默认 48px 最小高度会把标题栏 Row 撑到 48px,
              // 导致标题居中后下方多挤 12px 空白、且「无图标」状态 Row 仅 24px,两种状态
              // 顶部留白不一致。固定 32px 后 Row 恒为 32px,标题上沿与图标上沿对齐,
              // 标题↔首行间距收敛到 ~8px。点击宽度仍保留 48px,保证可点性。
              constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop('__DELETE__'),
            )
          : null,
      showGrabHandle: false,
      // 内容区顶部内边距为 0:叠加 header 底部 0 后,标题↔首行间距收敛到最小
      // (仅剩标题在 32px 行内居中产生的 ~4px 行内空隙)。
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SingleChildScrollView(
        // ignore: sort_child_properties_last
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              focusNode: urlFocus,
              textInputAction: TextInputAction.next,
              // 焦点依次移交下一个字段。
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(usernameFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudWebdavUrlLabel,
                hintText: AppLocalizations.of(context).cloudWebdavUrlHint,
                errorText: _urlError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              focusNode: usernameFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(passwordFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudWebdavUsernameLabel,
                errorText: _usernameError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              focusNode: passwordFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(pathFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudWebdavPasswordLabel,
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? AppIcons.visibility
                        : AppIcons.visibilityOff,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: obscurePassword,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pathController,
              focusNode: pathFocus,
              textInputAction: TextInputAction.done,
              // 最后一个字段:完成后收起键盘。
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).cloudWebdavRemotePathLabel,
                hintText: AppLocalizations.of(context).cloudWebdavPathHint,
                helperText: AppLocalizations.of(
                  context,
                ).cloudWebdavRemotePathHelperText,
              ),
            ),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // 内联校验:url/username/password 必填,任一为空则在对应字段下显示弱提示,不关闭弹窗。
                final url = urlController.text.trim();
                final username = usernameController.text.trim();
                final password = passwordController.text.trim();
                final path = pathController.text.trim();
                setState(() {
                  _urlError = url.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _usernameError = username.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _passwordError = password.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                });
                if (_urlError != null ||
                    _usernameError != null ||
                    _passwordError != null)
                  return;
                Navigator.of(context).pop({
                  'url': url,
                  'username': username,
                  'password': password,
                  'path': path,
                });
              },
              child: Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

// S3配置对话框(独立Widget,避免controller生命周期问题)
class _S3ConfigDialog extends StatefulWidget {
  final String initialEndpoint;
  final String initialRegion;
  final String initialAccessKey;
  final String initialSecretKey;
  final String initialBucket;
  final bool initialUseSSL;
  final int? initialPort;
  // 已存在配置时标题栏显示清除图标;点击后由弹窗自身用路由 context pop 删除哨兵
  final bool canDelete;

  const _S3ConfigDialog({
    required this.initialEndpoint,
    required this.initialRegion,
    required this.initialAccessKey,
    required this.initialSecretKey,
    required this.initialBucket,
    required this.initialUseSSL,
    this.initialPort,
    this.canDelete = false,
  });

  @override
  State<_S3ConfigDialog> createState() => _S3ConfigDialogState();
}

class _S3ConfigDialogState extends State<_S3ConfigDialog> {
  late final TextEditingController endpointController;
  late final TextEditingController regionController;
  late final TextEditingController accessKeyController;
  late final TextEditingController secretKeyController;
  late final TextEditingController bucketController;
  late final TextEditingController portController;
  // 显式 FocusNode:用于焦点链式切换。
  late final FocusNode endpointFocus;
  late final FocusNode regionFocus;
  late final FocusNode accessKeyFocus;
  late final FocusNode secretKeyFocus;
  late final FocusNode bucketFocus;
  late final FocusNode portFocus;
  late bool useSSL;
  bool obscureSecretKey = true;
  // 内联校验状态:endpoint/accessKey/secretKey/bucket 为必填,保存时若为空则在对应字段下显示弱提示。
  String? _endpointError;
  String? _accessKeyError;
  String? _secretKeyError;
  String? _bucketError;

  @override
  void initState() {
    super.initState();
    endpointController = TextEditingController(text: widget.initialEndpoint);
    regionController = TextEditingController(text: widget.initialRegion);
    accessKeyController = TextEditingController(text: widget.initialAccessKey);
    secretKeyController = TextEditingController(text: widget.initialSecretKey);
    bucketController = TextEditingController(text: widget.initialBucket);
    portController = TextEditingController(
      text: widget.initialPort?.toString() ?? '',
    );
    endpointFocus = FocusNode();
    regionFocus = FocusNode();
    accessKeyFocus = FocusNode();
    secretKeyFocus = FocusNode();
    bucketFocus = FocusNode();
    portFocus = FocusNode();
    useSSL = widget.initialUseSSL;
  }

  @override
  void dispose() {
    endpointController.dispose();
    regionController.dispose();
    accessKeyController.dispose();
    secretKeyController.dispose();
    bucketController.dispose();
    portController.dispose();
    // 释放焦点节点,防止内存泄漏与悬空引用。
    endpointFocus.dispose();
    regionFocus.dispose();
    accessKeyFocus.dispose();
    secretKeyFocus.dispose();
    bucketFocus.dispose();
    portFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用顶部贴边弹层(showAppSheetTop),消除底部弹层 + 键盘 viewInsets 动画的弹窗弹跳。
    final l10n = AppLocalizations.of(context);
    return AppSheet(
      title: AppLocalizations.of(context).cloudConfigureS3Title,
      // 删除图标常驻于标题栏右侧 trailing。
      trailing: widget.canDelete
          ? IconButton(
              icon: const Icon(AppIcons.delete, size: 22),
              tooltip: AppLocalizations.of(context).cloudClearConfig,
              // 删除图标按钮高度固定 32px:默认 48px 最小高度会把标题栏 Row 撑到 48px,
              // 导致标题居中后下方多挤 12px 空白、且「无图标」状态 Row 仅 24px,两种状态
              // 顶部留白不一致。固定 32px 后 Row 恒为 32px,标题上沿与图标上沿对齐,
              // 标题↔首行间距收敛到 ~8px。点击宽度仍保留 48px,保证可点性。
              constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop('__DELETE__'),
            )
          : null,
      showGrabHandle: false,
      // 内容区顶部内边距为 0:叠加 header 底部 0 后,标题↔首行间距收敛到最小
      // (仅剩标题在 32px 行内居中产生的 ~4px 行内空隙)。
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SingleChildScrollView(
        // ignore: sort_child_properties_last
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: endpointController,
              focusNode: endpointFocus,
              textInputAction: TextInputAction.next,
              // 焦点依次移交下一个字段。
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(regionFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3EndpointLabel,
                hintText: AppLocalizations.of(context).cloudS3EndpointHint,
                errorText: _endpointError,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: regionController,
              focusNode: regionFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(accessKeyFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3RegionLabel,
                hintText: AppLocalizations.of(context).cloudS3RegionHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: accessKeyController,
              focusNode: accessKeyFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(secretKeyFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3AccessKeyLabel,
                hintText: AppLocalizations.of(context).cloudS3AccessKeyHint,
                errorText: _accessKeyError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: secretKeyController,
              focusNode: secretKeyFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(bucketFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3SecretKeyLabel,
                hintText: AppLocalizations.of(context).cloudS3SecretKeyHint,
                errorText: _secretKeyError,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureSecretKey
                        ? AppIcons.visibility
                        : AppIcons.visibilityOff,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureSecretKey = !obscureSecretKey;
                    });
                  },
                ),
              ),
              obscureText: obscureSecretKey,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bucketController,
              focusNode: bucketFocus,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(portFocus),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3BucketLabel,
                hintText: AppLocalizations.of(context).cloudS3BucketHint,
                errorText: _bucketError,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context).cloudS3UseSSLLabel),
                ),
                Switch(
                  value: useSSL,
                  onChanged: (value) {
                    setState(() {
                      useSSL = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: portController,
              focusNode: portFocus,
              textInputAction: TextInputAction.done,
              // 最后一个字段:完成后收起键盘。
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3PortLabel,
                hintText: AppLocalizations.of(context).cloudS3PortHint,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                // 内联校验:endpoint/accessKey/secretKey/bucket 必填,任一为空则在对应字段下
                // 显示弱提示,不切换弹窗、不丢失已填内容。
                final endpoint = endpointController.text.trim();
                final accessKey = accessKeyController.text.trim();
                final secretKey = secretKeyController.text.trim();
                final bucket = bucketController.text.trim();
                setState(() {
                  _endpointError = endpoint.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _accessKeyError = accessKey.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _secretKeyError = secretKey.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                  _bucketError = bucket.isEmpty
                      ? l10n.cloudConfigInvalidMessage
                      : null;
                });
                if (_endpointError != null ||
                    _accessKeyError != null ||
                    _secretKeyError != null ||
                    _bucketError != null) {
                  return;
                }
                final portText = portController.text.trim();
                final port = portText.isEmpty ? null : int.tryParse(portText);
                Navigator.of(context).pop({
                  'endpoint': endpoint,
                  'region': regionController.text.trim(),
                  'accessKey': accessKey,
                  'secretKey': secretKey,
                  'bucket': bucket,
                  'useSSL': useSSL,
                  'port': port,
                });
              },
              child: Text(AppLocalizations.of(context).commonSave),
            ),
          ),
        ],
      ),
    );
  }
}
