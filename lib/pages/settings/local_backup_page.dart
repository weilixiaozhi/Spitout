import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import 'package:spitout/providers/providers.dart';
import '../../services/backup/local_backup_service.dart';
import '../../core/logging/logger_service.dart';
import '../../theme/colors.dart';
import '../../theme/icons/app_icons.dart';
import '../../utils/file_picker_helper.dart';
import '../../widgets/widgets.dart';

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

class _LocalBackupPageState extends ConsumerState<LocalBackupPage> {
  bool _backingUp = false;
  bool _restoring = false;

  // 列表刷新计数：备份/恢复后 +1 让 FutureBuilder 重新拉取目录
  int _refreshTick = 0;

  /// 手动立即备份：不受按天去重限制；成功后写入当天日期，
  /// 避免当天再被自动触发重复备份（今天已有新鲜快照）。
  Future<void> _backupNow() async {
    if (_backingUp || _restoring) return;
    // Android 11+ 写公共 Download 需「所有文件访问」授权：手动备份是用户主动
    // 动作，适合在此引导一次；未授权也不阻断，服务层会自动降级到应用专属目录。
    // 非 Android 平台无此授权流程，直接放行（保持原语义）。
    if (Platform.isAndroid && await ensureExportDirAccess(context, ref) == null) {
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
      await prefs.setString(LocalBackupService.prefsKeyLastBackupDate,
          LocalBackupService.todayString());
      if (!mounted) return;
      showToast(context, l10n.localBackupSuccess);
      setState(() => _refreshTick++);
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
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const SizedBox(height: 16),
                      // ===== 自动本地备份开关 =====
                      // 背景色由 Material 承载：若用带背景色的 Container 包裹
                      // SwitchListTile，其 ink 波纹会画在 DecoratedBox 之下而被
                      // 遮挡，触发 Flutter 的 ListTile 背景调试断言。
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Material(
                          color: SpitoutTokens.surface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isDark
                                ? BorderSide(
                                    color: SpitoutTokens.border(context))
                                : BorderSide.none,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SwitchListTile(
                          title: Text(
                            l10n.localBackupAutoTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: SpitoutTokens.textPrimary(context),
                            ),
                          ),
                          subtitle: Text(
                            l10n.localBackupAutoSubtitle,
                            style: TextStyle(
                              fontSize: 10,
                              color: SpitoutTokens.textSecondary(context),
                            ),
                          ),
                          // 默认 true（零干预兜底）；加载期间也按 true 展示避免闪烁
                          value: autoBackup.value ?? true,
                          onChanged: (v) =>
                              ref.read(autoBackupSetterProvider).set(v),
                          activeThumbColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ===== 恢复列表 =====
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.localBackupListHint,
                          style: TextStyle(
                            fontSize: 14,
                            color: SpitoutTokens.textSecondary(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<LocalBackupFile>>(
                        // _refreshTick 进 key：备份/恢复后强制重建 Future 重读目录
                        key: ValueKey(_refreshTick),
                        future: ref
                            .read(localBackupServiceProvider)
                            .listBackups(),
                        builder: (context, snapshot) {
                          final backups = snapshot.data ?? [];
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }
                          if (backups.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  l10n.localBackupListEmpty,
                                  style: TextStyle(
                                    color:
                                        SpitoutTokens.textTertiary(context),
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
                      const SizedBox(height: 16),
                      // 导入文件恢复入口：卸载重装后历史备份可能不在恢复列表中，
                      // 此处常驻一个手动指定文件的兜底通道，避免"备份还在却恢复不了"。
                      // 放在列表底部居中，避免与标题区视觉冲突，且空列表时同样可见。
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: (_backingUp || _restoring)
                              ? null
                              : _importAndRestore,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  AppIcons.fileUpload,
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.localBackupImportFromFile,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 恢复中全屏遮罩：半透明阻断所有点击 + loading 与文案
          if (_restoring)
            Positioned.fill(
              child: ModalBarrier(
                color: Colors.black.withValues(alpha: 0.45),
                dismissible: false,
              ),
            ),
          if (_restoring)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.localBackupRestoring,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 单个备份快照列表项：文件名（主）+ 大小（副），点击进入恢复确认
  Widget _buildBackupTile(
      BuildContext context, LocalBackupFile backup, bool isDark) {
    // 背景色交给 Material 承载（原因同自动备份开关卡片），
    // 外层仅留 margin，确保 ListTile 的最近 Material 祖先先于任何带背景的 DecoratedBox。
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: SpitoutTokens.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDark
              ? BorderSide(color: SpitoutTokens.border(context))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(
            backup.fileName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: SpitoutTokens.textPrimary(context),
            ),
          ),
          subtitle: Text(
            backup.sizeLabel,
            style: TextStyle(
              fontSize: 13,
              color: SpitoutTokens.textSecondary(context),
            ),
          ),
          onTap: () => _restoreFile(backup.file),
        ),
      ),
    );
  }
}
