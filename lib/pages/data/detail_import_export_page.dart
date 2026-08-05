import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/logging/logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/import/file_reader.dart';
import '../../services/import/xlsx_reader.dart';
import '../../widgets/widgets.dart';
import '../../theme/colors.dart';
import 'detail_export_page.dart';
import 'import_confirm_page.dart';
import '../../theme/icons/app_icons.dart';

/// 明细导入导出页
///
/// 结构对齐配置导入导出页：
/// - 头部「功能说明」卡片：整合导入差异说明、导出格式说明与模板列预览。
/// - 功能按钮卡片：单个「导入明细」按钮 + 单个「导出明细」按钮。
///
/// 导入路径已简化：点击「导入明细」直接拉起系统文件选择器，选完文件后
/// 流式读取并直接进入映射页（`ImportConfirmPage`），不经过中转页。
/// 导出路径：点击「导出明细」跳转 `DetailExportPage` 二级页面。
class DetailImportExportPage extends StatefulWidget {
  const DetailImportExportPage({super.key});

  @override
  State<DetailImportExportPage> createState() =>
      _DetailImportExportPageState();
}

class _DetailImportExportPageState
    extends State<DetailImportExportPage> {
  // 文件读取进度状态
  bool _reading = false;
  double? _readProgress; // 0~1，null 表示准备中
  bool _cancelRead = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: SpitoutTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.detailImportExportTitle,
            showBack: true,
          ),
          Expanded(
            // Stack 用于叠加文件读取进度遮罩
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  children: [
                    // —— 头部：功能说明模块（整合原「功能说明」+「模板预览」两个卡片）——
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
                            // 导入说明：结构化分条展示（原长段落不利于扫读）
                            _infoSection(
                              context,
                              icon: AppIcons.fileUpload,
                              title: l10n.detailImportExportImportTitle,
                              points: [
                                l10n.detailImportExportImportPoint1,
                                l10n.detailImportExportImportPoint2,
                                l10n.detailImportExportImportPoint3,
                              ],
                            ),
                            SizedBox(height: 10.0),
                            // 导出说明：结构化分条展示
                            _infoSection(
                              context,
                              icon: AppIcons.fileDownload,
                              title: l10n.detailImportExportExportTitle,
                              points: [
                                l10n.detailImportExportExportPoint1,
                                l10n.detailImportExportExportPoint2,
                                l10n.detailImportExportExportPoint3,
                              ],
                              // 表头模板预览：展示 CSV 实际列名与顺序，
                              // 与「包含字段如下：」引导语配套，采用模板样式（13px 三级文字）
                              footer: Padding(
                                padding:
                                    const EdgeInsets.only(top: 4.0, left: 12.0),
                                child: Text(
                                  '${l10n.exportCsvHeaderType} / ${l10n.exportCsvHeaderCategory} / ${l10n.exportCsvHeaderSubCategory} / ${l10n.exportCsvHeaderAmount} / ${l10n.exportCsvHeaderCurrency} / ${l10n.exportCsvHeaderNote} / ${l10n.exportCsvHeaderTime}',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    color:
                                        SpitoutTokens.textTertiary(context),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 10.0),
                            // 账本迁移提示：说明可经「导出当前账本 → 导入目标账本」完成账本间平滑迁移
                            _infoSection(
                              context,
                              icon: AppIcons.lightbulb,
                              title: l10n.detailImportExportMigrateTitle,
                              points: [
                                l10n.detailImportExportMigrateTip,
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8.0),
                    // —— 功能按钮卡片：导入明细 + 导出明细 ——
                    SectionCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // 导入明细（三按钮合一，点击直接拉起文件选择器）
                          AppListTile(
                            leading: AppIcons.fileUpload,
                            title: l10n.detailImportExportImportTitle,
                            subtitle: l10n.detailImportExportImportSubtitle,
                            trailing: _reading
                                ? SizedBox(
                                    width: 20.0,
                                    height: 20.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  )
                                :                                 Icon(AppIcons.chevronRight,
                                    color: SpitoutTokens.iconTertiary(context),
                                    size: 20),
                            onTap: _reading ? null : _pickAndImport,
                          ),
                          SpitoutTokens.cardDivider(context),
                          // 导出明细：跳转二级页面选择账本与导出范围
                          AppListTile(
                            leading: AppIcons.fileDownload,
                            title: l10n.detailImportExportExportTitle,
                            subtitle: l10n.detailImportExportExportSubtitle,
                            trailing: Icon(AppIcons.chevronRight,
                                color: SpitoutTokens.iconTertiary(context),
                                size: 20),
                            onTap: () {
                              Navigator.of(context).push(
                                appPageRoute(
                                  builder: (_) => const DetailExportPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 文件读取进度遮罩
                if (_reading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: SpitoutTokens.surfaceElevated(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          width: 320,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(AppLocalizations.of(context).importReading),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(value: _readProgress),
                              const SizedBox(height: 8),
                              Text(_readProgress == null
                                  ? AppLocalizations.of(context).importPreparing
                                  : '${((_readProgress ?? 0) * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() => _cancelRead = true);
                                },
                                child: Text(
                                    AppLocalizations.of(context).commonCancel),
                              ),
                            ],
                          ),
                        ),
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

  /// 功能说明分节：小标题（图标 + 加粗文字）+ 圆点条目列表。
  ///
  /// 设计意图：说明内容分节 + 分条展示，每条只讲一个要点，便于扫读。
  Widget _infoSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> points,

    /// 分节尾部附加内容（可选），如导出分节的 CSV 表头模板预览
    Widget? footer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分节小标题：复用功能按钮的标题文案（导入明细 / 导出明细）
        Row(
          children: [
            Icon(icon, size: 16.0, color: SpitoutTokens.textSecondary(context)),
            SizedBox(width: 6.0),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: SpitoutTokens.textPrimary(context),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.0),
        // 圆点条目：圆点与正文首行基线对齐，折行时悬挂缩进保持对齐
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: SpitoutTokens.textSecondary(context),
                    height: 1.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontSize: 14.0,
                      color: SpitoutTokens.textSecondary(context),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // 尾部附加内容（如模板预览）
        ?footer,
      ],
    );
  }

  /// 拉起系统文件选择器，选中后流式读取并跳转到映射页。
  ///
  /// 流程：选文件 → 流式读取（含进度/取消）→ 直接进入 `ImportConfirmPage`，
  /// 不经过中转页，也不区分账单类型
  /// （统一由 `GenericBillParser` 处理表头定位与列映射）。
  Future<void> _pickAndImport() async {
    // 促使插件完成注册，规避热重载后偶现的 MissingPluginException
    // ignore: unawaited_futures
    FilePicker.clearTemporaryFiles();

    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt', 'xlsx'],
        allowMultiple: false,
        // 优先走文件路径流式读取,避免把整个文件 bytes 拉进内存;
        // FileReaderService 在 path 缺失时才回退 bytes。
        withData: false,
      );
      if (!context.mounted) return;
      if (res == null || res.files.isEmpty) return;

      final picked = res.files.first;
      final csvText = await _readFileStreaming(picked);
      if (!mounted) return;
      if (csvText.isEmpty) return; // 可能读取被取消

      // 直接进入映射页（默认首行即表头）
      await Navigator.of(context).push(
        appPageRoute(
          builder: (_) => ImportConfirmPage(
            csvText: csvText,
            hasHeader: true,
          ),
        ),
      );
    } on Exception catch (e, st) {
      logger.error('DetailImport', '选择/读取导入文件失败', e, st);
      if (!mounted) return;
      showToast(context, AppLocalizations.of(context).commonOperationFailed);
    }
  }

  /// 流式读取文件并显示进度。
  Future<String> _readFileStreaming(PlatformFile picked) async {
    if (!mounted) return '';

    setState(() {
      _reading = true;
      _readProgress = 0;
      _cancelRead = false;
    });

    try {
      final text = await FileReaderService.readFile(
        picked,
        isCancelled: () => _cancelRead,
        onProgress: (progress) {
          if (_cancelRead) return;
          if (mounted) {
            setState(() {
              _readProgress = progress;
            });
          }
        },
        xlsxConverter: (bytes) {
          try {
            return XlsxReader.convertXlsxToCSV(bytes);
          } catch (e, st) {
            logger.error('DetailImport', 'XLSX 转 CSV 失败', e, st);
            if (mounted) {
              showToast(
                context,
                AppLocalizations.of(context).commonOperationFailed,
              );
            }
            return '';
          }
        },
      );

      if (_cancelRead) {
        // 读取被取消:丢弃已读内容,不进入映射页。
        throw const FileReadCancelledException();
      }

      if (mounted) {
        setState(() {
          _reading = false;
          _readProgress = null;
        });
      }

      return text;
    } on FileReadCancelledException {
      if (mounted) {
        setState(() {
          _reading = false;
          _readProgress = null;
          _cancelRead = false;
        });
        showToast(context, AppLocalizations.of(context).importCancelled);
      }
      return '';
    } catch (e) {
      logger.error('DetailImport', '读取文件失败', e);
      if (mounted) {
        setState(() {
          _reading = false;
          _readProgress = null;
        });
        showToast(
          context,
          AppLocalizations.of(context).commonOperationFailed,
        );
      }
      return '';
    }
  }

}
