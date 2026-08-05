import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:spitout/providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../data/models.dart' as schema;
import '../../l10n/app_localizations.dart';
import '../../core/logging/logger_service.dart';
import '../../services/import/csv_parser.dart';
import '../../utils/category_utils.dart';
import '../../services/import/bill_parser.dart';
import '../../services/import/parsers/generic_parser.dart';
import 'package:spitout/providers/core/post_processor.dart';
import '../../services/import/data_import_service.dart';
import '../../utils/date/date_parser.dart';
import '../../theme/colors.dart';

class ImportConfirmPage extends ConsumerStatefulWidget {
  final String csvText;
  final bool hasHeader;
  const ImportConfirmPage({
    super.key,
    required this.csvText,
    required this.hasHeader,
  });

  @override
  ConsumerState<ImportConfirmPage> createState() => _ImportConfirmPageState();
}

class _ImportConfirmPageState extends ConsumerState<ImportConfirmPage> {
  List<List<String>> rows = const [];
  bool parsing = true;
  bool _parseError = false;
  // 自动识别到的表头所在行（仅当 hasHeader 为 true 时使用）
  int headerRow = 0;
  final Map<String, int?> mapping = {
    'date': null,
    'type': null,
    'amount': null,
    'currency': null,            // 多币种:币种列
    'category': null,
    'sub_category': null,       // 二级分类
    'note': null,
    // 无标签和附件字段
  };
  bool importing = false;
  int ok = 0, fail = 0, skipped = 0; // skipped: 跳过的非支出类型记录
  int step = 0; // 0: 字段映射, 1: 分类映射
  bool _cancelled = false;
  int _sessionSeq = 0; // 导入会话号:延迟清空进度时校验仍是最新会话
  List<String> distinctCategories = [];
  Map<String, int?> categoryMapping = {}; // 源分类名 -> 目标分类ID（null表示保持原名）
  Future<List<schema.Category>>? allCategoriesFuture;
  late final BillParser _billParser;
  final Map<String, int> _badRows = {}; // 解析失败原因 -> 行数

  @override
  void initState() {
    super.initState();
    // 合并入口后统一使用通用解析器（已吸收支付宝/微信关键词检测）
    _billParser = GenericBillParser();

    // 解析在后台 isolate 完成，避免主线程卡顿
    () async {
      List<List<String>> parsed;
      try {
        parsed = await compute(_parseRowsIsolate, widget.csvText);
      } catch (e, st) {
        // isolate 解析异常(畸形 CSV/内存不足等)不能停在加载态:
        // 置错误态并提示用户返回,而不是永久转圈。
        logger.error('ImportConfirmPage', 'CSV 后台解析失败', e, st);
        if (!mounted) return;
        setState(() {
          parsing = false;
          _parseError = true;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        rows = parsed;
        parsing = false;
      });
      // 解析完成
      // 使用解析器查找表头
      if (widget.hasHeader && rows.isNotEmpty) {
        headerRow = _billParser.findHeaderRow(rows);
        if (headerRow < 0) headerRow = 0; // 兜底
      }
      _autoDetectMapping();
      // 预取分类列表供第二步选择
      allCategoriesFuture = _loadAllCategories(ref);
    }();
  }

  void _autoDetectMapping() {
    if (rows.isEmpty || !widget.hasHeader) return;
    final headers = rows[headerRow].map((e) => e.toString().trim()).toList();

    // 使用解析器的列映射功能
    final detectedMapping = _billParser.mapColumns(headers);

    // 更新 mapping
    detectedMapping.forEach((key, index) {
      if (mapping.containsKey(key)) {
        mapping[key] = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (parsing) {
      return Scaffold(
        body: Column(
          children: [
            PrimaryHeader(
                title: AppLocalizations.of(context).importPreparing,
                showBack: true),
            Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          ],
        ),
      );
    }
    if (_parseError) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        body: Column(
          children: [
            PrimaryHeader(
              title: l10n.importPreparing,
              showBack: true,
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.commonOperationFailed,
                      style: TextStyle(
                        color: SpitoutTokens.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(l10n.commonBack),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    final columnCount =
        rows.isNotEmpty ? rows[widget.hasHeader ? headerRow : 0].length : 0;
    List<DropdownMenuItem<int>> items() => List.generate(columnCount, (i) {
          final header = widget.hasHeader
              ? rows[headerRow]
              : (rows.isNotEmpty ? rows.first : const <String>[]);
          final label = (widget.hasHeader &&
                  i < header.length &&
                  header[i].trim().isNotEmpty)
              ? header[i].trim()
              : AppLocalizations.of(context).importColumnNumber(i + 1);
          return DropdownMenuItem(
              value: i, child: Text(label, overflow: TextOverflow.ellipsis));
        });

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrimaryHeader(
              title: step == 0
                  ? AppLocalizations.of(context).importConfirmMapping
                  : AppLocalizations.of(context).importCategoryMapping,
              showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (step == 0) ...[
                  if (rows.isEmpty)
                    Text(AppLocalizations.of(context).importNoDataParsed),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _mapRow(AppLocalizations.of(context).importFieldDate,
                          'date', items()),
                      _mapRow(AppLocalizations.of(context).importFieldType,
                          'type', items()),
                      _mapRow(AppLocalizations.of(context).importFieldAmount,
                          'amount', items()),
                      _mapRow(AppLocalizations.of(context).importFieldCurrency,
                          'currency', items()),
                      _mapRow(AppLocalizations.of(context).importFieldCategory,
                          'category', items()),
                      _mapRow(AppLocalizations.of(context).exportCsvHeaderSubCategory,
                          'sub_category', items()),
                      _mapRow(AppLocalizations.of(context).importFieldNote,
                          'note', items()),

                    ],
                  ),
                  const SizedBox(height: 12),
                  // 预览仅展示前 N 行，避免大文件一次性渲染导致卡顿
                  Text(AppLocalizations.of(context).importPreview,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SizedBox(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Builder(builder: (_) {
                        const int maxPreview = 10; // 预览最多 100 行
                        final totalRows = rows.length;
                        final dataStart =
                            widget.hasHeader ? (headerRow + 1) : 0;
                        // 保证包含表头行 + 最多 maxPreview-1 行数据
                        final header = widget.hasHeader
                            ? [rows[headerRow]]
                            : <List<String>>[];
                        final body = totalRows > dataStart
                            ? () {
                                final take = (maxPreview - header.length);
                                final end = (dataStart + take <= totalRows)
                                    ? dataStart + take
                                    : totalRows;
                                return rows.sublist(dataStart, end);
                              }()
                            : const <List<String>>[];
                        final limited = [...header, ...body];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PreviewTable(rows: limited),
                            if (totalRows > limited.length)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  AppLocalizations.of(context)
                                      .importPreviewLimit(
                                          limited.length, totalRows),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: SpitoutTokens.textTertiary(context)),
                                ),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ] else ...[
                  if (mapping['category'] == null)
                    Text(AppLocalizations.of(context)
                        .importCategoryNotSelected),
                  Text(AppLocalizations.of(context)
                      .importCategoryMappingDescription),
                  const SizedBox(height: 8),
                  FutureBuilder<List<schema.Category>>(
                    future: allCategoriesFuture,
                    builder: (context, snap) {
                      final cats = snap.data ?? [];
                      final l10n = AppLocalizations.of(context);
                      // 按「先一级、再其下二级、再下个一级」分组排序，便于用户按层级浏览
                      final orderedCats = _groupCategoriesByLevel(cats);
                      final items = <DropdownMenuItem<int?>>[
                        DropdownMenuItem(
                            value: null,
                            child: Text(l10n.importKeepOriginalName)),
                        ...orderedCats.map((c) {
                          // 显示分类名 + 层级标签（一级/二级）
                          final levelLabel = c.level == 1
                              ? l10n.categoryTopLevelLabel
                              : l10n.categorySecondLevelLabel;
                          final isSub = c.level != 1;
                          return DropdownMenuItem<int?>(
                            value: c.id,
                            // 二级分类缩进，视觉上体现父子层级
                            child: Padding(
                              padding: EdgeInsets.only(left: isSub ? 16.0 : 0.0),
                              child: Text(
                                  '${CategoryUtils.getDisplayName(c.name, context, kind: c.kind)}（$levelLabel）'),
                            ),
                          );
                        }),
                      ];
                      return Column(
                        children: [
                          for (final name in distinctCategories)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 12),
                                  DropdownButton<int?>(
                                    value: categoryMapping[name],
                                    items: items,
                                    onChanged: (v) => setState(
                                        () => categoryMapping[name] = v),
                                  ),
                                ],
                              ),
                            )
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (importing)
                    Text(
                        AppLocalizations.of(context).importProgress(ok, fail)),
                  const Spacer(),
                  if (step == 0)
                    FilledButton(
                      onPressed: () {
                        // 检查是否有分类列映射
                        if (mapping['category'] == null) {
                          // 没有分类列，提示用户先选择分类列
                          showToast(
                              context,
                              AppLocalizations.of(context)
                                  .importSelectCategoryFirst);
                          return;
                        }
                        _buildDistinctCategories();
                        setState(() => step = 1);
                      },
                      child: Text(AppLocalizations.of(context).importNextStep),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed:
                          importing ? null : () => setState(() => step = 0),
                      child: Text(
                          AppLocalizations.of(context).importPreviousStep),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: importing ? null : _startImport,
                      child:
                          Text(AppLocalizations.of(context).importStartImport),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapRow(String label, String key, List<DropdownMenuItem<int>> items) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 64, child: Text(label)),
        const SizedBox(width: 8),
        SizedBox(
          width: 220,
          child: DropdownButton<int>(
            isExpanded: true,
            value: mapping[key],
            hint: Text(AppLocalizations.of(context).importAutoDetect),
            items: items,
            onChanged: (v) => setState(() => mapping[key] = v),
          ),
        ),
      ],
    );
  }

  Future<void> _startImport() async {
    // 无当前账本时阻断:避免交易落到无效账本,引导先创建账本。
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId == 0) {
      if (mounted) {
        showToast(
          context,
          AppLocalizations.of(context).importNoLedger,
        );
      }
      return;
    }

    // 使用根容器，保证页面被销毁后仍可更新全局进度供"我的"页展示
    final container = ProviderScope.containerOf(context, listen: false);
    final currentContext = context;
    final session = ++_sessionSeq;
    _cancelled = false;
    setState(() {
      importing = true;
      ok = 0;
      fail = 0;
    });
    final repo = ref.read(repositoryProvider);

    // 获取当前账本的币种信息
    final currentLedger = await repo.getLedgerById(ledgerId);
    if (currentLedger == null) {
      if (mounted) {
        showToast(context, AppLocalizations.of(context).importNoLedger);
      }
      setState(() => importing = false);
      return;
    }
    final ledgerCurrency = currentLedger.currency;

    final dataStart = widget.hasHeader ? (headerRow + 1) : 0;
    final total = rows.length - dataStart;
    // 初始化全局进度
    container.read(importProgressProvider.notifier).set(ImportProgress(
      running: true,
      total: total,
      done: 0,
      ok: 0,
      fail: 0,
    ));

    bool dialogOpen = true;
    // 进度弹窗（可转后台）
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dctx) {
        return Consumer(builder: (dctx, r, _) {
          final p = r.watch(importProgressProvider);
          final percent =
              p.total == 0 ? 0.0 : (p.done / p.total).clamp(0.0, 1.0);
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(AppLocalizations.of(context).importInProgress),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                    value: percent > 0 && percent < 1 ? percent : null),
                const SizedBox(height: 8),
                // 实时进度文案（每50条更新一次，足够流畅）
                Text(
                    AppLocalizations.of(context)
                        .importProgressDetail(p.done, p.fail, p.ok, p.total),
                    style: Theme.of(dctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: SpitoutTokens.textTertiary(context))),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  dialogOpen = false;
                  Navigator.of(dctx).pop();
                  // 返回到明细导入导出页继续后台导入
                  // 栈:明细导入导出页 -> ImportConfirmPage,仅需 pop 一次
                  if (mounted) {
                    Navigator.of(currentContext).pop(); // Close ImportConfirmPage
                  }
                },
                child:
                    Text(AppLocalizations.of(context).importBackgroundImport),
              ),
              TextButton(
                onPressed: () {
                  _cancelled = true;
                  dialogOpen = false;
                  Navigator.of(dctx).pop();
                },
                child: Text(AppLocalizations.of(context).importCancelImport),
              ),
            ],
          );
        });
      },
    );

    // 定义进度变量
    int done = 0;
    _badRows.clear();

    // 收集跳过的类型（用于提示用户）
    final Map<String, int> skippedTypes = {};

    try {
      if (_cancelled) return;
      // 使用统一导入服务：将CSV数据转换为ImportData格式
      final importData = _buildImportDataFromCsv(
        rows: rows,
        dataStart: dataStart,
        mapping: mapping,
        categoryMapping: categoryMapping,
        skippedTypes: skippedTypes,
        badRows: _badRows,
        ledgerCurrency: ledgerCurrency,
      );

      // 调用统一导入服务
      final result = await dataImportService.importData(
        repo,
        ledgerId,
        importData,
        defaultCurrency: ledgerCurrency,
        onProgress: (processed, progressTotal) {
          // 批次间隙检查取消:抛异常中止导入服务,未处理批次不再写入。
          if (_cancelled) {
            throw const ImportCancelledException();
          }
          done = processed;
          // 更新全局进度
          container.read(importProgressProvider.notifier).set(ImportProgress(
            running: true,
            total: total,
            done: done,
            ok: ok,
            fail: fail,
          ));
          if (mounted) setState(() {});
        },
      );

      ok = result.inserted;
      fail = result.failed +
          _badRows.values.fold(0, (sum, count) => sum + count);
      skipped = skippedTypes.values.fold(0, (a, b) => a + b);
      done = total;

      // 显式触发一次同步上推。SyncCoordinator 监听 local_changes 表已经会
      // 自动调度,这里作为兜底:provider 重建瞬间 / 边界条件下 coordinator
      // 还没就位时,UI 显式触发也能把刚导入的数据推上云端。
      // fire-and-forget:不阻塞导入完成动画。
      try {
        // ignore: unawaited_futures
        PostProcessor.syncC(container, ledgerId: ledgerId);
      } catch (_) {
        // 忽略同步触发错误,导入本身已经成功
      }
    } on ImportCancelledException {
      // 用户取消:已落库的批次保留,未处理批次不再写入;清空全局进度
      // 并提示,不展示完成弹窗、不跳转。
      try {
        container.read(importProgressProvider.notifier).set(ImportProgress.empty);
      } catch (_) {}
      if (mounted) {
        showToast(context, AppLocalizations.of(context).importCancelled);
        setState(() => importing = false);
      }
      return;
    } catch (e, st) {
      // 导入失败:原始异常只进日志,页面展示统一友好文案。
      logger.error('ImportConfirmPage', '明细导入失败', e, st);
      if (mounted) {
        showToast(context, AppLocalizations.of(context).commonOperationFailed);
      }
      fail = total - ok; // 更新失败数
    }

    // 即使页面已被关闭（mounted=false），也要继续更新全局进度供"我的"页展示
    // 先切换为"完成"以驱动 UI 展示成功动画/提示（不等待云上传）
    try {
      container.read(importProgressProvider.notifier).set(ImportProgress(
        running: false,
        total: total,
        done: done,
        ok: ok,
        fail: fail,
        ledgerId: ledgerId, // 设置账本ID，用于触发账本列表页面刷新
        skipped: skipped, // 跳过的记录数
        skippedTypes: skippedTypes, // 跳过的类型及数量
      ));
    } catch (_) {
      // 忽略进度更新错误
    }

    // 延迟清空和刷新（不依赖页面状态，即使页面销毁也要执行）
    if (!_cancelled) {
      Future<void>.delayed(const Duration(seconds: 5), () {
        // 会话号校验:期间若发起了新导入,旧回调不得清掉新进度。
        if (session != _sessionSeq) return;
        // 延长到5秒，让用户看到动画
        try {
          container
              .read(importProgressProvider.notifier)
              .set(ImportProgress.empty);
          // 刷新"我的"页统计（笔数/天数）
          container.invalidate(countsForLedgerProvider(ledgerId));
          // 触发全局统计刷新（用于"我的"页顶部聚合信息）
          container.read(statsRefreshProvider.notifier).tick();
          // 触发一次同步状态刷新（UI 端会复用缓存避免闪烁）
          container.read(syncStatusRefreshProvider.notifier).tick();
        } catch (_) {
          // 忽略延迟刷新错误
        }
      });
    }

    // Check if context is still mounted for UI operations
    if (!currentContext.mounted) {
      return;
    }

    // 显示导入完成提示
    final cancelledText =
        _cancelled ? AppLocalizations.of(currentContext).importCancelled : '';
    final l10nToast = AppLocalizations.of(currentContext);

    // 构建提示信息
    String message = l10nToast.importCompleted(cancelledText, fail, ok);
    final badRowCount =
        _badRows.values.fold(0, (sum, count) => sum + count);
    if (badRowCount > 0) {
      message += '\n${l10nToast.importInvalidRowsSkipped(badRowCount)}';
    }
    bool hasSkipped = skipped > 0;

    if (hasSkipped) {
      // 显示类型不匹配的跳过记录
      final typeSkipped = skippedTypes.values.fold(0, (a, b) => a + b);

      if (typeSkipped > 0) {
        final skippedList = skippedTypes.entries
            .map((e) => '${e.key}(${e.value})')
            .join('、');
        message += '\n${l10nToast.importSkippedNonTransactionTypes(typeSkipped)}\n$skippedList';
      }
    }

    // Handle UI operations before cloud upload
    if (dialogOpen) {
      Navigator.of(currentContext).pop();
    }

    // 判断显示方式: 完全成功用toast,有失败或跳过用弹窗
    if (fail == 0 && !hasSkipped) {
      // 完全成功: 使用toast,然后关闭页面
      showToast(currentContext, message);
      // 关闭确认页 -> 返回到明细导入导出页
      // 栈:明细导入导出页 -> ImportConfirmPage,仅需 pop 一次
      Navigator.of(currentContext).pop(); // Close ImportConfirmPage
    } else {
      // 有失败或跳过: 使用弹窗显示详细信息,等待用户确认后再关闭页面
      await showDialog(
        context: currentContext,
        builder: (ctx) => AlertDialog(
          title: Text(l10nToast.importCompleteTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10nToast.commonConfirm),
            ),
          ],
        ),
      );

      // 用户确认后再关闭页面
      // 栈:明细导入导出页 -> ImportConfirmPage,仅需 pop 一次
      if (currentContext.mounted) {
        Navigator.of(currentContext).pop(); // Close ImportConfirmPage
      }
    }
    // 返回后再显式刷新一次全局统计，确保顶部汇总即时更新
    try {
      container.read(statsRefreshProvider.notifier).tick();
    } catch (_) {}

    // 导入完成后，账本列表页面会通过监听 importProgressProvider 自动刷新
    // ledgerId 已经在上面的 importProgressProvider 中设置
  }

  /// 将CSV数据转换为统一的ImportData格式
  schema.ImportData _buildImportDataFromCsv({
    required List<List<String>> rows,
    required int dataStart,
    required Map<String, int?> mapping,
    required Map<String, int?> categoryMapping,
    required Map<String, int> skippedTypes,
    required Map<String, int> badRows,
    required String ledgerCurrency,
  }) {
    final categories = <schema.ImportCategory>[];
    final transactions = <schema.ImportTransaction>[];

    // 标签和附件功能已从导入流程中移除
    // 收集分类信息（用于创建分类）
    final categoryInfoMap = <String, ({String kind, String? icon, String? parentName})>{};

    // 第一遍：收集账户、标签、分类信息
    for (int i = dataStart; i < rows.length; i++) {
      final r = rows[i];

      String? getBy(String key) {
        final userIdx = mapping[key];
        if (userIdx != null && userIdx >= 0 && userIdx < r.length) {
          final val = r[userIdx].toString().trim();
          return val.isNotEmpty ? val : null;
        }
        return null;
      }

      // 无标签收集步骤

      // 解析类型用于分类收集（全局仅支出模式，所有交易类型均为 expense）
      final typeRaw = getBy('type') ?? 'expense';
      final typeStr = typeRaw.trim().toLowerCase();
      String? type;
      if (typeStr == '支出' || typeStr == '支' || typeStr == '出账' ||
          typeStr == '消费' || typeStr == '花费' ||
          typeStr == '出帳' || typeStr == '消費' || typeStr == '花費' ||  // 繁体
          typeStr == 'expense' || typeStr == 'spending' || typeStr == 'expenditure') {
        type = 'expense';
      }

      // 收集分类信息
      if (type != null) {
        final categoryName = getBy('category');
        final subCategoryName = getBy('sub_category');
        final categoryIcon = getBy('category_icon');
        final subCategoryIcon = getBy('sub_category_icon');

        if (subCategoryName != null && categoryName != null) {
          // 有二级分类
          final parentKey = '$categoryName:$type';
          categoryInfoMap.putIfAbsent(parentKey, () => (
            kind: type!,
            icon: categoryIcon,
            parentName: null,
          ));
          final subKey = '$subCategoryName:$type:$categoryName';
          categoryInfoMap.putIfAbsent(subKey, () => (
            kind: type!,
            icon: subCategoryIcon,
            parentName: categoryName,
          ));
        } else if (categoryName != null) {
          // 只有一级分类（仅当用户选择"保持原名"时才需要创建）
          final chosen = categoryMapping[categoryName];
          if (chosen == null) {
            final key = '$categoryName:$type';
            categoryInfoMap.putIfAbsent(key, () => (
              kind: type!,
              icon: categoryIcon,
              parentName: null,
            ));
          }
        }
      }
    }

    // 构建分类列表（先一级后二级）
    final level1Categories = categoryInfoMap.entries
        .where((e) => e.value.parentName == null)
        .toList();
    final level2Categories = categoryInfoMap.entries
        .where((e) => e.value.parentName != null)
        .toList();

    for (final entry in level1Categories) {
      final parts = entry.key.split(':');
      final name = parts[0];
      final kind = parts[1];
      categories.add(schema.ImportCategory(
        name: name,
        kind: kind,
        level: 1,
        icon: entry.value.icon,
      ));
    }
    for (final entry in level2Categories) {
      final parts = entry.key.split(':');
      final name = parts[0];
      final kind = parts[1];
      final parentName = parts[2];
      categories.add(schema.ImportCategory(
        name: name,
        kind: kind,
        level: 2,
        icon: entry.value.icon,
        parentName: parentName,
      ));
    }

    // 第二遍：构建交易列表
    for (int i = dataStart; i < rows.length; i++) {
      final r = rows[i];

      String? getBy(String key) {
        final userIdx = mapping[key];
        if (userIdx != null && userIdx >= 0 && userIdx < r.length) {
          final val = r[userIdx].toString().trim();
          return val.isNotEmpty ? val : null;
        }
        return null;
      }

      final dateStr = getBy('date');
      final typeRaw = getBy('type') ?? 'expense';
      final amountStr = getBy('amount');
      final currencyStr = getBy('currency')?.trim().toUpperCase();
      final categoryName = getBy('category');
      final subCategoryName = getBy('sub_category');
      final note = getBy('note');
      // 无标签和附件列

      // 类型识别（全局仅支出模式，仅识别支出类型）
      final typeStr = typeRaw.trim().toLowerCase();
      String? type;
      if (typeStr == '支出' || typeStr == '支' || typeStr == '出账' ||
          typeStr == '消费' || typeStr == '花费' ||
          typeStr == '出帳' || typeStr == '消費' || typeStr == '花費' ||  // 繁体
          typeStr == 'expense' || typeStr == 'spending' || typeStr == 'expenditure') {
        type = 'expense';
      } else {
        // 未识别的类型：记录并跳过
        skippedTypes[typeRaw.trim()] = (skippedTypes[typeRaw.trim()] ?? 0) + 1;
        continue;
      }

      // 金额解析:缺失或无法解析的行按失败计数并跳过,
      // 禁止把坏行静默当作 0 元交易写入账本。
      if (amountStr == null) {
        badRows['amount'] = (badRows['amount'] ?? 0) + 1;
        continue;
      }
      final amountClean = amountStr.replaceAll(RegExp(r'[¥$,+-]'), '');
      // 直接用 Decimal 精确解析 CSV 金额,不经过 double(审计问题 1)。
      final parsedAmount = Decimal.tryParse(amountClean.trim());
      if (parsedAmount == null) {
        badRows['amount'] = (badRows['amount'] ?? 0) + 1;
        continue;
      }
      final amount = parsedAmount.abs();
      if (amount <= Decimal.zero) {
        badRows['amount'] = (badRows['amount'] ?? 0) + 1;
        continue;
      }

      // 日期解析:缺失或格式无法识别同样按失败处理,不静默回退当前时间。
      final date = DateParser.tryParse(dateStr);
      if (date == null) {
        badRows['date'] = (badRows['date'] ?? 0) + 1;
        continue;
      }

      // 无标签和附件解析

      // 处理分类：支持用户映射和二级分类
      String? finalCategoryName;
      String? categoryKind;
      int? categoryId;

      if (subCategoryName != null && categoryName != null) {
        // 有二级分类：使用二级分类名称
        finalCategoryName = subCategoryName;
        categoryKind = type;
      } else if (categoryName != null) {
        // 只有一级分类：检查用户映射
        final chosen = categoryMapping[categoryName];
        if (chosen != null) {
          // 用户选择了现有分类，使用预解析的ID
          categoryId = chosen;
        } else {
          // 保持原名
          finalCategoryName = categoryName;
          categoryKind = type;
        }
      }

      transactions.add(schema.ImportTransaction(
        type: type,
        amount: amount,
        // 币种列有值且像 ISO code(3-8 位字母)才采纳,脏值回退兜底链
        currencyCode: (currencyStr != null &&
                RegExp(r'^[A-Z]{3,8}$').hasMatch(currencyStr))
            ? currencyStr
            : null,
        categoryName: finalCategoryName,
        categoryKind: categoryKind,
        categoryId: categoryId,
        happenedAt: date,
        note: note,
      ));
    }

    return schema.ImportData(
      categories: categories,
      transactions: transactions,
    );
  }

  void _buildDistinctCategories() {
    final catIdx = mapping['category'];
    if (catIdx == null) {
      distinctCategories = [];
      categoryMapping = {};
      return;
    }
    final set = <String>{};
    final dataStart = widget.hasHeader ? (headerRow + 1) : 0;
    for (int i = dataStart; i < rows.length; i++) {
      if (catIdx < rows[i].length) {
        final name = rows[i][catIdx].trim();
        if (name.isNotEmpty) set.add(name);
      }
    }
    distinctCategories = set.toList()..sort();

    // 初始化分类映射为 null,自动匹配由 _autoMatchCategories 在数据到达后执行。
    categoryMapping = {for (final n in distinctCategories) n: null};
    // 自动匹配移到数据回调中执行,不在 build 内改写状态。
    _autoMatchCategories();
  }

  /// 分类数据就绪后为源分类预设同名匹配。
  ///
  /// 设计意图:自动匹配属于数据到达后的初始化,若在 FutureBuilder 的 build
  /// 内直接改 categoryMapping 是 build 期副作用;这里由 [_buildDistinctCategories]
  /// 触发,await 分类列表后一次性计算并 setState。
  Future<void> _autoMatchCategories() async {
    final future = allCategoriesFuture;
    if (future == null) return;
    final cats = await future;
    if (!mounted || cats.isEmpty) return;

    var hasMatch = false;
    for (final sourceName in distinctCategories) {
      // 直接使用源分类名称查找匹配
      try {
        final matchingCategory = cats.firstWhere((c) => c.name == sourceName);
        categoryMapping[sourceName] = matchingCategory.id;
        hasMatch = true;
      } catch (_) {
        // 没有找到匹配的分类，保持为null
      }
    }
    if (hasMatch && mounted) {
      setState(() {});
    }
  }
}

// isolate 入口函数：在后台解析 CSV 文本
List<List<String>> _parseRowsIsolate(String input) {
  return CsvParser.parse(input);
}

Future<List<schema.Category>> _loadAllCategories(WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  // 全局仅支出模式，只查 expense 分类。
  // 一次全量查询后按 kind 过滤,避免每个一级分类一次子分类查询(N+1)。
  final all = await repo.getAllCategories();
  return all.where((c) => c.kind == 'expense').toList();
}

/// 将分类列表按「先一级、再其下二级、再下个一级」的顺序重排。
///
/// 设计意图：默认加载顺序是「全部一级在前、全部二级在后」，在「分类映射」下拉中
/// 父子关系被割裂、不直观。这里按 parentId 分组后，每个一级分类紧跟其二级子分类，
/// 更符合用户按层级选择分类的直觉。排序字段统一用 sortOrder 保持与系统内顺序一致。
List<schema.Category> _groupCategoriesByLevel(List<schema.Category> all) {
  // 一级分类：parentId 为空；按 sortOrder 升序
  final top = all.where((c) => c.parentId == null).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final result = <schema.Category>[];
  for (final t in top) {
    result.add(t);
    // 该一级分类下的二级子分类，同样按 sortOrder 升序
    final subs = all.where((c) => c.parentId == t.id).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    result.addAll(subs);
  }
  return result;
}

class _PreviewTable extends StatelessWidget {
  final List<List<String>> rows;
  // 预览表格: 固定单元格宽度，避免在横向滚动环境中使用 Expanded 触发布局错误
  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    const double cellWidth = 140;
    final isDark = SpitoutTokens.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: SpitoutTokens.border(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            for (int r = 0; r < rows.length; r++)
              Container(
                color: r == 0
                    ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                    : SpitoutTokens.surfaceElevated(context),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  children: [
                    for (final cell in rows[r])
                      SizedBox(
                        width: cellWidth,
                        child: Text(
                          cell,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: SpitoutTokens.textPrimary(context),
                            fontWeight: r == 0 ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
