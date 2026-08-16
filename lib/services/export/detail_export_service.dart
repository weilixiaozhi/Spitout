import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/services/system/public_export_dir_service.dart';
import 'package:spitout/utils/category_utils.dart';

/// 导出结果：实际文件路径 + 展示用路径。
typedef DetailExportResult = ({String path, String displayPath});

/// 将指定账本的交易明细导出为 CSV 文件,优先写入公共 Download/Spitout 目录
/// （Android 11+ 未授权「所有文件访问」时自动降级到应用专属外部目录）。
///
/// [dateRange] 非空时仅导出该时间范围内的交易(由导出明细页的
/// 起止日期展开而来);为空则导出该账本全部交易(对应「全选数据」勾选)。
/// 返回最终保存的文件路径与展示路径,结果展示(弹窗 / Toast)由调用方决定。
Future<DetailExportResult> exportDetailCsv({
  required BuildContext context,
  required LocalRepository repo,
  required int ledgerId,
  DateTimeRange? dateRange,
  required void Function(double) onProgress,
  // 测试注入点：非空时跳过系统目录解析，直接写入该目录。
  Directory? outputDirOverride,
}) async {
  final l10n = AppLocalizations.of(context);

  // 统一目录解析：Android 优先公共 Download（能力探测，未授权自动降级）；
  // 非 Android 落到应用文档目录（公共 Download 语义在 iOS/桌面端不存在）
  late final Directory dir;
  late final String displayDirPath;
  if (outputDirOverride != null) {
    dir = outputDirOverride;
    displayDirPath = dir.path;
  } else {
    final resolved = await const PublicExportDirService().resolve();
    if (resolved != null) {
      dir = resolved.dir;
      displayDirPath = resolved.displayPath;
    } else if (!Platform.isAndroid) {
      dir = await getApplicationDocumentsDirectory();
      displayDirPath = dir.path;
    } else {
      // 外部存储整体不可用（如 SD 卡被卸载）
      throw StateError(l10n.exportStorageUnavailable);
    }
  }
  final directory = dir.path;

  // 获取交易和分类数据
  final transactionsWithCategory = await repo.transactionsWithCategoryAll(
    ledgerId: ledgerId,
  );

  // 按时间范围过滤(为空则全部)
  final list = dateRange == null
      ? transactionsWithCategory
      : transactionsWithCategory.where((txWithCat) {
          final d = txWithCat.t.happenedAt;
          // 闭区间:落在 [start, end] 内即导出
          return !d.isBefore(dateRange.start) && !d.isAfter(dateRange.end);
        }).toList();

  final total = list.length;
  final rows = <List<dynamic>>[];
  rows.add([
    l10n.exportCsvHeaderType,
    l10n.exportCsvHeaderCategory,
    l10n.exportCsvHeaderSubCategory, // 二级分类名称
    l10n.exportCsvHeaderAmount,
    l10n.exportCsvHeaderCurrency, // 多币种:交易原币种
    l10n.exportCsvHeaderNote,
    l10n.exportCsvHeaderTime,
  ]);

  // 多币种:账本本位币(currencyCode 为 NULL 的行按本位币兜底)
  final ledgerData = await repo.getLedgerById(ledgerId);
  final ledgerBase =
      ((ledgerData?.currency.isNotEmpty ?? false)
              ? ledgerData!.currency
              : 'CNY')
          .toUpperCase();

  // 缓存全部分类信息（主表 + 共享账本镜像），用于回填分类名与父分类名。
  // 共享账本 Editor 的交易只持有 Owner 分类 syncId，主表查不到这些分类；
  // 这里用一次性全量接口拿全，二级分类的「分类 / 二级分类」两列才能正确拆分。
  final allCategories = {
    for (final cat in await repo.getAllCategoriesIncludingShared())
      cat.id: cat,
  };

  // 异步加载分类数据后,检查 context 是否仍然有效
  if (!context.mounted) return (path: '', displayPath: '');

  for (int i = 0; i < list.length; i++) {
    final txWithCat = list[i];
    final t = txWithCat.t;
    final c = txWithCat.category;

    // 完整时间格式:YYYY-MM-DD HH:mm:ss,前后补空格增加列宽
    final timeStr = () {
      try {
        final localTime = t.happenedAt.toLocal();
        return '  ${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}  ';
      } catch (e) {
        return '';
      }
    }();
    final typeStr = _getTypeDisplayName(t.type, l10n);

    String categoryName;
    String subCategoryName;
    if (c != null) {
      if (c.level == 2 && c.parentId != null) {
        // 二级分类:分类列填一级分类名,二级分类列填当前分类名
        final parentCategory = allCategories[c.parentId];
        categoryName = CategoryUtils.getDisplayName(
          parentCategory?.name,
          context,
        );
        subCategoryName = CategoryUtils.getDisplayName(c.name, context);
      } else {
        categoryName = CategoryUtils.getDisplayName(c.name, context);
        subCategoryName = '';
      }
    } else {
      categoryName = '';
      subCategoryName = '';
    }

    final currencyStr = (t.currencyCode ?? ledgerBase).toUpperCase();
    rows.add([
      typeStr,
      categoryName,
      subCategoryName,
      // 数据库金额为整数分，导出统一换算成“元”再保留两位小数。
      (t.amount / 100).toStringAsFixed(2),
      currencyStr,
      t.note ?? '',
      timeStr,
    ]);
    if (i % 50 == 0) {
      onProgress((i + 1) / (total == 0 ? 1 : total));
    }
  }

  // CsvEncoder 按 \n 行分隔符输出 CSV。
  final csvStr = const CsvEncoder(lineDelimiter: '\n').convert(rows);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fileName = 'spitout_$ts.csv';
  final path = p.join(directory, fileName);

  // 添加 UTF-8 BOM 标记,确保 Excel 正确识别中文编码
  const utf8Bom = '\uFEFF';
  await File(
    path,
  ).writeAsString(utf8Bom + csvStr, encoding: Encoding.getByName('utf-8')!);

  onProgress(1);
  return (path: path, displayPath: '$displayDirPath/$fileName');
}

// 全局仅支出模式,类型恒为支出
String _getTypeDisplayName(String type, AppLocalizations l10n) {
  switch (type) {
    case 'expense':
      return l10n.exportTypeExpense;
    default:
      return type; // 兜底返回原始值
  }
}
