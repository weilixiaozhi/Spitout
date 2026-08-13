import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import 'package:spitout/services/backup/local_backup_service.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/theme/colors.dart';
import 'package:spitout/theme/dimens.dart';
import 'package:spitout/theme/icons/app_icons.dart';
import 'package:spitout/theme/typography.dart';
import 'package:spitout/utils/file_picker_helper.dart';
import 'package:spitout/widgets/widgets.dart';

/// 本地存储页：自动本地备份开关 + 手动备份 + 备份快照列表恢复。
///
/// 设计意图：
/// - 页面只做"展示与反馈"：文件级逻辑由 [LocalBackupService] 承载，
///   恢复后的热重建与账本归属体检由 [restoreBackupAndReconcile] 承载，
///   本页仅按返回的 [RestoreStatus] 做 toast 分支；
/// - 恢复期间 PopScope 拦截返回 + 全屏遮罩，杜绝覆盖中途退出造成半截状态。
class LocalBackupPage extends ConsumerStatefulWidget {
  const LocalBackupPage({super.key});

  @override
  ConsumerState<LocalBackupPage> createState() => _LocalBackupPageState();
}

class _LocalBackupPageState extends ConsumerState<LocalBackupPage>
    with WidgetsBindingObserver {
  bool _backingUp = false;
  bool _restoring = false;

  /// 备份列表 Future：initState 创建，下拉刷新 / resume / 备份成功后重建，
  /// FutureBuilder 依赖其实例变化触发重读，避免每次 build 都新建 Future。
  late Future<List<LocalBackupFile>> _backupsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _backupsFuture = _loadBackups();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统「所有文件访问」设置页返回后重读目录，让刚授予的权限立即生效，
    // 旧版本备份重新出现在列表中。
    if (state == AppLifecycleState.resumed) {
      _reloadBackups();
    }
  }

  Future<List<LocalBackupFile>> _loadBackups() =>
      ref.read(localBackupServiceProvider).listBackups();

  /// 重建列表 Future 并刷新 UI（内部有 mounted 守卫，可安全在异步回调中调用）。
  void _reloadBackups() {
    if (!mounted) return;
    setState(() {
      _backupsFuture = _loadBackups();
    });
  }

  /// 下拉刷新：等待新 Future 完成，让 RefreshIndicator 的转圈正确收尾。
  Future<void> _refreshBackups() async {
    final future = _loadBackups();
    setState(() {
      _backupsFuture = future;
    });
    try {
      await future;
    } catch (e, st) {
      logger.error('LocalBackup', '下拉刷新备份列表失败', e, st);
    }
  }

  /// 手动立即备份：不受按天去重限制；成功后写入当天日期，
  /// 避免当天再被自动触发重复备份（今天已有新鲜快照）。
  Future<void> _backupNow() async {
    if (_backingUp || _restoring) return;
    // Android 11+ 写公共 Download 需「所有文件访问」授权：手动备份是用户主动
    // 动作，适合在此引导一次；未授权也不阻断，服务层会自动降级到应用专属目录。
    // 非 Android 平台无此授权流程，直接放行（保持原语义）。
    if (Platform.isAndroid &&
        await ensureExportDirAccess(context, ref) == null) {
      return;
    }
    if (!mounted) return;
    setState(() => _backingUp = true);
    final l10n = AppLocalizations.of(context);
    try {
      final db = ref.read(databaseProvider);
      final localSelfId = await ref.read(localSelfIdProvider.future);
      await ref
          .read(localBackupServiceProvider)
          .createBackup(db: db, localSelfId: localSelfId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LocalBackupService.prefsKeyLastBackupDate,
        LocalBackupService.todayString(),
      );
      if (!mounted) return;
      showToast(context, l10n.localBackupSuccess);
      _reloadBackups();
    } catch (e, st) {
      logger.error('LocalBackup', '手动备份失败', e, st);
      if (!mounted) return;
      showToast(context, l10n.localBackupFailed);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  /// 点击快照 → 二次确认 → 执行恢复 → 按结果反馈。
  /// 任何失败路径当前库都未被改动（服务层保证），停留本页可重试。
  Future<void> _restoreFile(File file) async {
    if (_backingUp || _restoring) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.localBackupRestoreTitle,
      message: l10n.localBackupRestoreMessage,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _restoring = true);
    try {
      // 恢复 → 热重建 → 归属体检（已登录认领 / 未登录归一化）→ 回退当前账本，
      // 整条链路由 restoreBackupAndReconcile 统一编排，UI 只负责结果反馈。
      final result = await restoreBackupAndReconcile(
        read: ref.read,
        invalidate: ref.invalidate,
        backupFile: file,
      );
      // await 之后 widget 可能已卸载（如恢复期间被系统回收），用 mounted 守卫
      // 避免对失效 BuildContext 调用 showToast / pop。
      if (!mounted) return;
      switch (result.status) {
        case RestoreStatus.success:
          showToast(context, l10n.localBackupRestoreSuccess);
          Navigator.of(context).pop();
        case RestoreStatus.emergencyFailed:
          showToast(context, l10n.localBackupEmergencyFailed);
        case RestoreStatus.integrityFailed:
          showToast(context, l10n.localBackupIntegrityFailed);
        case RestoreStatus.versionTooNew:
          showToast(context, l10n.localBackupVersionTooNew);
        case RestoreStatus.copyFailed:
          logger.error('LocalBackup', '恢复失败: ${result.error}');
          showToast(context, l10n.localBackupRestoreFailed);
      }
    } catch (e, st) {
      // 恢复服务异常(文件损坏/磁盘错误等)不得冒泡:提示并停留本页可重试。
      logger.error('LocalBackup', '恢复备份异常', e, st);
      if (!mounted) return;
      showToast(context, l10n.localBackupRestoreFailed);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// 导入文件恢复：从系统文件选择器挑一个 .sqlite 备份，再走与列表恢复相同的
  /// 确认 → 覆盖流程。
  ///
  /// 设计意图：卸载重装后，历史备份可能散落在公共 Download 等目录而不出现在
  /// 恢复列表（候选目录读不到 / 文件名前缀不匹配），给用户一个手动指定文件的兜底
  /// 入口，避免"备份明明还在却恢复不了"。
  Future<void> _importAndRestore() async {
    if (_backingUp || _restoring) return;
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePickerHelper.pickSqliteFile();
      // 用户取消选择：静默返回，不打扰
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) {
        // 极端设备只给流不给路径：无法走文件级恢复，按无效文件处理
        if (!mounted) return;
        showToast(context, l10n.localBackupImportInvalidFile);
        return;
      }
      if (!mounted) return;
      // 恢复确认与覆盖逻辑与列表恢复完全一致，复用同一入口保证行为统一
      await _restoreFile(File(path));
    } on FileExtensionException {
      // 设备不支持扩展名过滤时用户可能误选其他类型文件，给出明确引导
      if (!mounted) return;
      showToast(context, l10n.localBackupImportInvalidFile);
    } catch (e, st) {
      logger.error('LocalBackup', '导入备份文件失败', e, st);
      if (!mounted) return;
      showToast(context, l10n.localBackupRestoreFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = SpitoutTokens.isDark(context);
    final autoBackup = ref.watch(autoBackupValueProvider);
    final showOldBackupLink = ref.watch(showOldBackupLinkProvider);

    return PopScope(
      // 恢复执行中禁止返回：覆盖数据库文件中途离开会造成用户不可感知的临界状态
      canPop: !_restoring,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: SpitoutTokens.scaffoldBackground(context),
            body: Column(
              children: [
                PrimaryHeader(
                  title: l10n.localBackupPageTitle,
                  showBack: true,
                  actions: [
                    HeaderIconAction(
                      icon: AppIcons.fileDownload,
                      tooltip: l10n.localBackupNowTooltip,
                      spinning: _backingUp,
                      onPressed: _restoring ? null : _backupNow,
                    ),
                  ],
                ),
                Expanded(
                  // 下拉刷新：内容不足一屏时也允许下拉，保证刷新手势始终可用
                  child: RefreshIndicator(
                    onRefresh: _refreshBackups,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: SpitoutDimens.p16),
                        // ===== 自动本地备份开关 =====
                        // 背景色由 Material 承载：若用带背景色的 Container 包裹
                        // SwitchListTile，其 ink 波纹会画在 DecoratedBox 之下而被
                        // 遮挡，触发 Flutter 的 ListTile 背景调试断言。
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
                          child: Material(
                            color: SpitoutTokens.surface(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
                              side: isDark
                                  ? BorderSide(
                                      color: SpitoutTokens.border(context),
                                    )
                                  : BorderSide.none,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SwitchListTile(
                              title: Text(
                                l10n.localBackupAutoTitle,
                                style: SpitoutTextTokens.title(context).copyWith(color: SpitoutTokens.textPrimary(context)),
                              ),
                              subtitle: Text(
                                l10n.localBackupAutoSubtitle,
                                style: SpitoutTextTokens.caption(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                              ),
                              // 默认 true（零干预兜底）；加载期间也按 true 展示避免闪烁
                              value: autoBackup.value ?? true,
                              onChanged: (v) =>
                                  ref.read(autoBackupSetterProvider).set(v),
                              activeThumbColor: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: SpitoutDimens.p20),
                        // ===== 恢复列表 =====
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16),
                          child: Text(
                            l10n.localBackupListHint,
                            style: SpitoutTextTokens.body(context).copyWith(color: SpitoutTokens.textSecondary(context)),
                          ),
                        ),
                        if (showOldBackupLink)
                          Align(
                            alignment: Alignment.center,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                              onTap: _showOldBackupHelpDialog,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpitoutDimens.p8,
                                  vertical: SpitoutDimens.p4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.help,
                                      size: SpitoutDimens.icon12,
                                      color: SpitoutTokens.textSecondary(
                                        context,
                                      ),
                                    ),
                                    const SizedBox(width: SpitoutDimens.p4),
                                    Text(
                                      l10n.localBackupOldLink,
                                      style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(
                                          context,
                                        )),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: SpitoutDimens.p8),
                        FutureBuilder<List<LocalBackupFile>>(
                          future: _backupsFuture,
                          builder: (context, snapshot) {
                            final backups = snapshot.data ?? [];
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.all(SpitoutDimens.p32),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (backups.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(SpitoutDimens.p32),
                                child: Center(
                                  child: Text(
                                    l10n.localBackupListEmpty,
                                    style: TextStyle(
                                      color: SpitoutTokens.textTertiary(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (final backup in backups)
                                  _buildBackupTile(context, backup, isDark),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: SpitoutDimens.p16),
                        // 导入文件恢复入口：卸载重装后历史备份可能不在恢复列表中，
                        // 此处常驻一个手动指定文件的兜底通道，避免"备份还在却恢复不了"。
                        // 放在列表底部居中，避免与标题区视觉冲突，且空列表时同样可见。
                        Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(SpitoutDimens.radius8),
                            onTap: (_backingUp || _restoring)
                                ? null
                                : _importAndRestore,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpitoutDimens.p12,
                                vertical: SpitoutDimens.p8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.fileUpload,
                                    size: SpitoutDimens.icon16,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: SpitoutDimens.p4),
                                  Text(
                                    l10n.localBackupImportFromFile,
                                    style: SpitoutTextTokens.body(context).copyWith(color: Theme.of(context).primaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: SpitoutDimens.p20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 恢复中全屏遮罩：半透明阻断所有点击 + loading 与文案
          if (_restoring)
            Positioned.fill(
              child: ModalBarrier(
                color: SpitoutTokens.overlay(context),
                dismissible: false,
              ),
            ),
          if (_restoring)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: SpitoutDimens.p16),
                  Text(
                    l10n.localBackupRestoring,
                    style: SpitoutTextTokens.body(context).copyWith(color: Colors.white,
                      decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 找回旧版本备份引导弹窗：解释 Android 隐藏旧备份的原因，
  /// 并提供「去开启」拉起系统「所有文件访问」授权；返回后由 resume 自动刷新。
  Future<void> _showOldBackupHelpDialog() async {
    final l10n = AppLocalizations.of(context);
    // 打开弹窗前查询「所有文件访问」状态：已开启时主按钮显示「已开启」，
    // 避免用户重复点击「去开启」却无反应（已授权时系统不跳转设置页）。
    var allFilesGranted = false;
    try {
      allFilesGranted = await ref.read(allFilesAccessCheckerProvider)();
    } catch (e, st) {
      logger.warning('LocalBackup', '查询「所有文件访问」状态失败: $e', st);
    }
    if (!mounted) return;
    final grant = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SpitoutTokens.surfaceElevated(dialogContext),
        title: Row(
          children: [
            Icon(
              AppIcons.info,
              color: Theme.of(dialogContext).colorScheme.primary,
              size: SpitoutDimens.icon22,
            ),
            const SizedBox(width: SpitoutDimens.p12),
            Expanded(
              child: Text(
                l10n.localBackupOldDialogTitle,
                style: SpitoutTextTokens.boldTitle(context).copyWith(color: SpitoutTokens.textPrimary(dialogContext),),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOldBackupGuideSection(
                dialogContext,
                icon: AppIcons.warning,
                iconColor: SpitoutTokens.warning(dialogContext),
                title: l10n.localBackupOldReasonTitle,
                body: l10n.localBackupOldReasonBody,
              ),
              const SizedBox(height: SpitoutDimens.p16),
              _buildOldBackupGuideSection(
                dialogContext,
                icon: AppIcons.settings,
                iconColor: Theme.of(dialogContext).colorScheme.primary,
                title: l10n.localBackupOldHowTitle,
                body: allFilesGranted
                    ? l10n.localBackupOldHowBodyGranted
                    : l10n.localBackupOldHowBody,
              ),
              const SizedBox(height: SpitoutDimens.p16),
              _buildOldBackupGuideSection(
                dialogContext,
                icon: AppIcons.verifiedUser,
                iconColor: SpitoutTokens.success(dialogContext),
                title: l10n.localBackupOldSafeTitle,
                body: l10n.localBackupOldSafeBody,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.localBackupOldLater,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
          ),
          if (allFilesGranted)
            TextButton(
              onPressed: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.check,
                    size: SpitoutDimens.icon16,
                    color: Theme.of(dialogContext).disabledColor,
                  ),
                  const SizedBox(width: SpitoutDimens.p4),
                  Text(
                    l10n.localBackupOldGranted,
                    style: TextStyle(
                      color: Theme.of(dialogContext).disabledColor,
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                l10n.localBackupOldGrant,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );

    if (grant != true || !mounted) return;
    try {
      await ref.read(requestAllFilesAccessProvider)();
    } catch (e, st) {
      logger.error('LocalBackup', '拉起「所有文件访问」授权失败', e, st);
      if (!mounted) return;
      showToast(context, l10n.localBackupOldGrantFailed);
    }
    // 授权页返回时生命周期回调可能先于 await 完成，这里再兜底刷新一次，
    // 保证列表与权限状态同步。
    _reloadBackups();
  }

  /// 找回旧备份弹窗内的单块说明：图标 + 小标题 + 正文。
  Widget _buildOldBackupGuideSection(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: SpitoutDimens.icon16, color: iconColor),
            const SizedBox(width: SpitoutDimens.p4),
            Expanded(
              child: Text(
                title,
                style: SpitoutTextTokens.strongTitle(context).copyWith(color: SpitoutTokens.textPrimary(context),),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpitoutDimens.p4),
        Padding(
          padding: const EdgeInsets.only(left: SpitoutDimens.p20),
          child: Text(
            body,
            style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context),
              height: 1.5),
          ),
        ),
      ],
    );
  }

  /// 单个备份快照列表项：文件名（主）+ 大小（副），点击进入恢复确认
  Widget _buildBackupTile(
    BuildContext context,
    LocalBackupFile backup,
    bool isDark,
  ) {
    // 背景色交给 Material 承载（原因同自动备份开关卡片），
    // 外层仅留 margin，确保 ListTile 的最近 Material 祖先先于任何带背景的 DecoratedBox。
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: SpitoutDimens.p16, vertical: SpitoutDimens.p4),
      child: Material(
        color: SpitoutTokens.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SpitoutDimens.radius12),
          side: isDark
              ? BorderSide(color: SpitoutTokens.border(context))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(
            backup.fileName,
            style: SpitoutTextTokens.title(context).copyWith(color: SpitoutTokens.textPrimary(context)),
          ),
          subtitle: Text(
            backup.sizeLabel,
            style: SpitoutTextTokens.label(context).copyWith(color: SpitoutTokens.textSecondary(context)),
          ),
          onTap: () => _restoreFile(backup.file),
        ),
      ),
    );
  }
}
