import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:spitout/providers/core/simple_state_notifier.dart';
import 'package:spitout/providers/core/database_providers.dart';

import 'package:spitout/services/export/config_export_service.dart';
import 'package:spitout/services/export/detail_export_service.dart';

// 页面统一经 providers 门面引用服务层模型类型,不直接 import services 文件。
export 'package:spitout/services/export/config_export_service.dart'
    show ExportOptions, ConfigContentInfo;
export 'package:spitout/services/export/detail_export_service.dart' show DetailExportResult;

// 导入任务进度：用于显示"后台导入中"状态与进度
class ImportProgress {
  final bool running;
  final int total;
  final int done;
  final int ok;
  final int fail;
  final int? ledgerId; // 关联的账本ID，用于导入完成后触发刷新
  final int skipped; // 跳过的记录数
  final Map<String, int> skippedTypes; // 跳过的类型及数量

  const ImportProgress({
    required this.running,
    required this.total,
    required this.done,
    required this.ok,
    required this.fail,
    this.ledgerId,
    this.skipped = 0,
    this.skippedTypes = const {},
  });

  ImportProgress copyWith({
    bool? running,
    int? total,
    int? done,
    int? ok,
    int? fail,
    int? ledgerId,
    int? skipped,
    Map<String, int>? skippedTypes,
  }) => ImportProgress(
    running: running ?? this.running,
    total: total ?? this.total,
    done: done ?? this.done,
    ok: ok ?? this.ok,
    fail: fail ?? this.fail,
    ledgerId: ledgerId ?? this.ledgerId,
    skipped: skipped ?? this.skipped,
    skippedTypes: skippedTypes ?? this.skippedTypes,
  );

  /// 判断是否刚完成导入（从运行中变为完成状态）
  bool get isJustCompleted => !running && total > 0;

  static const empty = ImportProgress(
    running: false,
    total: 0,
    done: 0,
    ok: 0,
    fail: 0,
  );
}

final importProgressProvider =
    NotifierProvider<SimpleStateNotifier<ImportProgress>, ImportProgress>(
      () => SimpleStateNotifier((ref) => ImportProgress.empty),
    );

/// 配置导入动作门面：页面只依赖 providers，不直接触碰服务层。
///
/// [options] 控制导入哪些内容与是否覆盖凭据(见 [ExportOptions.includeCredentials])。
Future<void> importConfigFromYaml(
  WidgetRef ref,
  String yamlContent,
  ExportOptions options,
) {
  return ConfigExportService.importFromYaml(
    yamlContent,
    repository: ref.read(repositoryProvider),
    options: options,
  );
}

/// 配置导出动作门面：按选项生成 YAML 字符串。
Future<String> exportConfigToYaml(WidgetRef ref, ExportOptions options) {
  return ConfigExportService.exportToYaml(
    repository: ref.read(repositoryProvider),
    options: options,
  );
}

/// 检测 YAML 中包含哪些配置项（纯函数门面）。
ConfigContentInfo detectConfigContent(String yamlContent) =>
    ConfigExportService.detectContent(yamlContent);

/// 明细导出动作门面：导出指定账本 CSV 并返回保存路径。
Future<DetailExportResult> exportDetailCsvFromUi(
  WidgetRef ref, {
  required int ledgerId,
  DateTimeRange? dateRange,
  required void Function(double) onProgress,
}) {
  return exportDetailCsv(
    context: ref.context,
    repo: ref.read(repositoryProvider),
    ledgerId: ledgerId,
    dateRange: dateRange,
    onProgress: onProgress,
  );
}
