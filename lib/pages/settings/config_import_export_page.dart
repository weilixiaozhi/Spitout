import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/widgets.dart';
import '../../theme/colors.dart';
import '../../utils/file_picker_helper.dart';
import 'package:spitout/providers/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export/config_export_service.dart';
import '../../core/logging/logger_service.dart';
import '../../theme/icons/app_icons.dart';

/// 配置导入导出页面
class ConfigImportExportPage extends ConsumerStatefulWidget {
  const ConfigImportExportPage({super.key});

  @override
  ConsumerState<ConfigImportExportPage> createState() =>
      _ConfigImportExportPageState();
}

class _ConfigImportExportPageState
    extends ConsumerState<ConfigImportExportPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _lastExportedFilePath;

  /// 最近一次导出的展示用路径（公共 Download 时为 `Download/Spitout/...`，
  /// 降级目录时为完整绝对路径），与存储路径解耦，仅供 UI 展示
  String? _lastExportedDisplayPath;

  Future<void> _exportConfig() async {
    // Step 1: 显示选择导出内容对话框
    final options = await showDialog<ExportOptions>(
      context: context,
      builder: (context) => _ExportOptionsDialog(ref: ref),
    );

    if (options == null || !mounted) return;

    setState(() {
      _isExporting = true;
      _lastExportedFilePath = null;
    });

    try {
      // 获取仓库和当前账本ID
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);

      // Step 2: 生成预览内容
      final yamlContent = await ConfigExportService.exportToYaml(
        repository: repo,
        ledgerId: ledgerId,
        options: options,
      );

      if (!mounted) return;

      // Step 3: 显示预览并确认导出
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => _ExportPreviewDialog(yamlContent: yamlContent),
      );

      if (confirm != true || !mounted) {
        setState(() => _isExporting = false);
        return;
      }

      // Step 4: 执行导出
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'spitout_config_$timestamp.yml';

      if (Platform.isAndroid) {
        // Android 11+ 写公共 Download 需「所有文件访问」授权：先引导一次，
        // 未授权时服务层自动降级到应用专属目录，导出能力不中断。
        // helper 已实时解析目录（含授权后二次探测），返回 null 仅当页面
        // 已销毁或外部存储整体不可用，直接退出由 finally 兜底复位状态。
        final dir = await ensureExportDirAccess(context, ref);
        if (dir == null) return;
        final filePath = '${dir.dir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsString(yamlContent);

        logger.info('ConfigExport', '配置已导出到: $filePath');

        if (!mounted) return;

        setState(() {
          _lastExportedFilePath = filePath;
          _lastExportedDisplayPath = '${dir.displayPath}/$fileName';
        });

        showToast(context, AppLocalizations.of(context).configExportSuccess);
      } else {
        // iOS: 使用分享功能
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsString(yamlContent);

        if (!mounted) return;

        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath)],
            subject: AppLocalizations.of(context).configExportShareSubject,
          ),
        );

        if (result.status == ShareResultStatus.success) {
          if (!mounted) return;
          showToast(context, AppLocalizations.of(context).configExportSuccess);
        }
      }
    } catch (e) {
      logger.error('ConfigExport', '导出配置失败: $e');
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).configExportFailed,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// 查看配置文件内容
  Future<void> _viewExportedContent() async {
    if (_lastExportedFilePath == null) return;

    try {
      final file = File(_lastExportedFilePath!);
      final content = await file.readAsString();

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);

      await showDialog(
        context: context,
        builder: (ctx) => _ConfigContentDialog(
          content: content,
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: content));
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            if (!mounted) return;
            showToast(context, l10n.configExportContentCopied);
          },
        ),
      );
    } catch (e) {
      logger.error('ConfigExport', '读取配置文件失败: $e');
      if (!mounted) return;
      showToast(context, AppLocalizations.of(context).configExportReadFileFailed);
    }
  }

  Future<void> _importConfig() async {
    setState(() => _isImporting = true);

    try {
      // Step 1: 选择文件（使用 FilePickerHelper 处理部分设备不支持扩展名过滤的问题）
      final result = await FilePickerHelper.pickYamlFile();

      if (result == null || result.files.isEmpty) {
        if (mounted) {
          setState(() => _isImporting = false);
        }
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (!mounted) return;
        throw Exception(AppLocalizations.of(context).configImportNoFilePath);
      }

      // Step 2: 读取文件并检测可用内容
      if (!mounted) return;
      final file = File(filePath);
      final yamlContent = await file.readAsString();

      // 检测文件中包含哪些配置项
      final contentInfo = ConfigExportService.detectContent(yamlContent);

      // Step 3: 显示预览并选择导入内容的对话框
      if (!mounted) return;
      final options = await showDialog<ExportOptions>(
        context: context,
        builder: (context) => _ImportPreviewDialog(
          ref: ref,
          yamlContent: yamlContent,
          contentInfo: contentInfo,
        ),
      );

      if (options == null || !mounted) {
        setState(() => _isImporting = false);
        return;
      }

      // Step 4: 执行导入
      // 注意：不传入 ledgerId，让导入逻辑使用 yml 中指定的账本名称
      // 这样预算等数据会导入到正确的账本，而不是当前账本
      final repo = ref.read(repositoryProvider);

      await ConfigExportService.importFromFile(
        filePath,
        repository: repo,
        options: options,
      );

      // 导入后立即刷新相关的 Provider 状态
      if (options.appSettings) {
        await _refreshProvidersAfterImport();
      }

      if (!mounted) return;
      showToast(context, AppLocalizations.of(context).configImportSuccess);

      // 提示需要重启应用（部分设置可能仍需重启）
      if (!mounted) return;
      await AppDialog.info(
        context,
        title: AppLocalizations.of(context).configImportRestartTitle,
        message: AppLocalizations.of(context).configImportRestartMessage,
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).configImportFailed,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// 导入后刷新相关的 Provider 状态
  Future<void> _refreshProvidersAfterImport() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 刷新主题模式
      final themeMode = prefs.getString('themeMode');
      if (themeMode != null) {
        switch (themeMode) {
          case 'light':
            ref.read(themeModeProvider.notifier).state = ThemeMode.light;
            break;
          case 'dark':
            ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
            break;
          default:
            ref.read(themeModeProvider.notifier).state = ThemeMode.system;
        }
        logger.info('ConfigImport', '主题模式已刷新: $themeMode');
      }

      logger.info('ConfigImport', 'Provider 状态刷新完成');
    } catch (e) {
      logger.error('ConfigImport', '刷新 Provider 状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.configImportExportTitle,
            subtitle: l10n.configImportExportSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              children: [
                // 说明卡片
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              AppIcons.info,
                              size: 20.0,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8.0),
                            Text(
                              l10n.configImportExportInfoTitle,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                                color: SpitoutTokens.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          l10n.configImportExportInfoMessage,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: SpitoutTokens.textSecondary(context),
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 12.0),
                        // 包含的配置项列表（合并自原底部说明卡片，仅保留一个说明区域）
                        Text(
                          l10n.configImportExportIncludesTitle,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: SpitoutTokens.textPrimary(context),
                          ),
                        ),
                        SizedBox(height: 8.0),
                        _buildConfigItem(context, ref, AppIcons.book, l10n.configIncludeLedgers),
                        SizedBox(height: 6.0),
                        _buildConfigItem(context, ref, AppIcons.category, l10n.configIncludeCategories),
                        SizedBox(height: 6.0),
                        _buildConfigItem(context, ref, AppIcons.repeat, l10n.configIncludeRecurringTransactions),
                        SizedBox(height: 6.0),
                        _buildConfigItem(context, ref, AppIcons.cloud, l10n.configIncludeSupabase),
                        SizedBox(height: 6.0),
                        _buildConfigItem(context, ref, AppIcons.folder, l10n.configIncludeWebdav),
                        SizedBox(height: 6.0),
                        _buildConfigItem(context, ref, AppIcons.storage, l10n.configIncludeS3),
                        SizedBox(height: 6.0),
                        _buildConfigItem(context, ref, AppIcons.cloudSync, l10n.configIncludeSpitoutCloud),
                        SizedBox(height: 6.0),
                        _buildConfigItem(context, ref, AppIcons.settings, l10n.configIncludeAppSettings),
                        SizedBox(height: 12.0),
                        // 注意事项：用橙色背景区块突出敏感信息和覆盖风险
                        Container(
                          padding: EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                AppIcons.warning,
                                size: 18.0,
                                color: Colors.orange[700],
                              ),
                              SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  l10n.configImportExportWarning,
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    color: Colors.orange[900],
                                    height: 1.5,
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
                SizedBox(height: 8.0),
                // 功能按钮
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 导出配置
                      AppListTile(
                        leading: AppIcons.fileUpload,
                        title: l10n.configExportTitle,
                        subtitle: l10n.configExportSubtitle,
                        trailing: _isExporting
                            ? SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : null,
                        onTap: _isExporting ? null : _exportConfig,
                      ),
                      // Android平台显示导出路径和打开按钮
                      if (Platform.isAndroid && _lastExportedFilePath != null) ...[
                        SpitoutTokens.cardDivider(context),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.checkCircle,
                                    size: 16.0,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      l10n.configExportSavedTo(_lastExportedDisplayPath ?? _lastExportedFilePath!),
                                      style: TextStyle(
                                        fontSize: 13.0,
                                        color: SpitoutTokens.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.0),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _viewExportedContent,
                                  icon: const Icon(AppIcons.visibility, size: 18),
                                  label: Text(l10n.configExportViewContent),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    side: BorderSide(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SpitoutTokens.cardDivider(context),
                      // 导入配置
                      AppListTile(
                        leading: AppIcons.download,
                        title: l10n.configImportTitle,
                        subtitle: l10n.configImportSubtitle,
                        trailing: _isImporting
                            ? SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : null,
                        onTap: _isImporting ? null : _importConfig,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(
    BuildContext context,
    WidgetRef ref,
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18.0,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: 8.0),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.0,
              color: SpitoutTokens.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// 配置内容查看对话框
class _ConfigContentDialog extends StatelessWidget {
  final String content;
  final VoidCallback onCopy;

  const _ConfigContentDialog({
    required this.content,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.description),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.configExportViewContent,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(AppIcons.copy, size: 18),
                  label: Text(l10n.configExportCopyContent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 导出选项选择对话框
class _ExportOptionsDialog extends StatefulWidget {
  final WidgetRef ref;

  const _ExportOptionsDialog({required this.ref});

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  // 默认全选
  bool _ledgers = true;
  bool _categories = true;
  bool _recurringTransactions = true;
  bool _appSettings = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: SpitoutTokens.surfaceElevated(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.checklist),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.configExportSelectTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // 选项列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                CheckboxListTile(
                  value: _ledgers,
                  onChanged: (v) => setState(() => _ledgers = v ?? true),
                  title: Text(l10n.configIncludeLedgers),
                  secondary: Icon(AppIcons.book, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _categories,
                  onChanged: (v) => setState(() => _categories = v ?? true),
                  title: Text(l10n.configIncludeCategories),
                  secondary: Icon(AppIcons.category, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _recurringTransactions,
                  onChanged: (v) => setState(() => _recurringTransactions = v ?? true),
                  title: Text(l10n.configIncludeRecurringTransactions),
                  secondary: Icon(AppIcons.repeat, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _appSettings,
                  onChanged: (v) => setState(() => _appSettings = v ?? true),
                  title: Text(l10n.configIncludeOtherSettings),
                  subtitle: Text(
                    l10n.configIncludeOtherSettingsSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: SpitoutTokens.textSecondary(context),
                    ),
                  ),
                  secondary: Icon(AppIcons.settings, color: primary),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    final options = ExportOptions(
                      ledgers: _ledgers,
                      categories: _categories,
                      recurringTransactions: _recurringTransactions,
                      appSettings: _appSettings,
                    );
                    Navigator.pop(context, options);
                  },
                  child: Text(l10n.commonNext),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 导出预览对话框
class _ExportPreviewDialog extends StatelessWidget {
  final String yamlContent;

  const _ExportPreviewDialog({required this.yamlContent});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: SpitoutTokens.surfaceElevated(context),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.preview),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.configExportPreviewTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpitoutTokens.surface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpitoutTokens.border(context)),
                ),
                child: SelectableText(
                  yamlContent,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: SpitoutTokens.textPrimary(context),
                  ),
                ),
              ),
            ),
          ),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.configExportConfirmTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 导入预览对话框（先预览内容，再选择导入项）
class _ImportPreviewDialog extends StatefulWidget {
  final WidgetRef ref;
  final String yamlContent;
  final ConfigContentInfo contentInfo;

  const _ImportPreviewDialog({
    required this.ref,
    required this.yamlContent,
    required this.contentInfo,
  });

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  // 默认全选（仅对文件中存在的项）
  late bool _ledgers;
  late bool _categories;
  late bool _recurringTransactions;
  late bool _appSettings;

  @override
  void initState() {
    super.initState();
    _ledgers = widget.contentInfo.hasLedgers;
    _categories = widget.contentInfo.hasCategories;
    _recurringTransactions = widget.contentInfo.hasRecurringTransactions;
    _appSettings = widget.contentInfo.hasAppSettings;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final info = widget.contentInfo;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: SpitoutTokens.surfaceElevated(context),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.preview),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.configImportPreviewTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // YAML 内容预览
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 警告提示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.warning,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.configImportOverwriteWarning,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // YAML 内容
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: SpitoutTokens.surface(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SpitoutTokens.border(context)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.yamlContent,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: SpitoutTokens.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 选择导入内容标题
                  Text(
                    l10n.configImportSelectTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SpitoutTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 选项列表
                  if (info.hasLedgers)
                    CheckboxListTile(
                      value: _ledgers,
                      onChanged: (v) => setState(() => _ledgers = v ?? true),
                      title: Text(l10n.configIncludeLedgers),
                      secondary: Icon(AppIcons.book, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasCategories)
                    CheckboxListTile(
                      value: _categories,
                      onChanged: (v) => setState(() => _categories = v ?? true),
                      title: Text(l10n.configIncludeCategories),
                      secondary: Icon(AppIcons.category, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasRecurringTransactions)
                    CheckboxListTile(
                      value: _recurringTransactions,
                      onChanged: (v) => setState(() => _recurringTransactions = v ?? true),
                      title: Text(l10n.configIncludeRecurringTransactions),
                      secondary: Icon(AppIcons.repeat, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (info.hasAppSettings)
                    CheckboxListTile(
                      value: _appSettings,
                      onChanged: (v) => setState(() => _appSettings = v ?? true),
                      title: Text(l10n.configIncludeOtherSettings),
                      subtitle: Text(
                        l10n.configIncludeOtherSettingsSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: SpitoutTokens.textSecondary(context),
                        ),
                      ),
                      secondary: Icon(AppIcons.settings, color: primary),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
          // 底部按钮
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpitoutTokens.surfaceElevated(context),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    final options = ExportOptions(
                      ledgers: _ledgers,
                      categories: _categories,
                      recurringTransactions: _recurringTransactions,
                      appSettings: _appSettings,
                    );
                    Navigator.pop(context, options);
                  },
                  child: Text(l10n.configImportConfirmTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}