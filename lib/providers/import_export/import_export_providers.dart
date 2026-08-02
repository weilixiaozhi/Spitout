import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }) =>
      ImportProgress(
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

  static const empty =
      ImportProgress(running: false, total: 0, done: 0, ok: 0, fail: 0);
}

final importProgressProvider =
    StateProvider<ImportProgress>((ref) => ImportProgress.empty);

