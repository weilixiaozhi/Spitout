library;

import 'package:spitout/data/models/import_models.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

/// 数据导入端口（data 层抽象）。
///
/// cloud 层的全量恢复 / diff 预览只依赖本端口，不感知具体导入实现；
/// [DataImportService]（services 层）实现本端口，并在 Provider 装配点注入。
/// 这样 cloud → services 的导入依赖被替换为 cloud → data 的单向依赖。
abstract class DataImportPort {
  /// 导入完整数据集（账本元数据 / 分类 / 虚拟用户 / 交易）。
  Future<ImportResult> importData(
    LocalRepository repo,
    int ledgerId,
    ImportData data, {
    String defaultCurrency = 'CNY',
    void Function(int done, int total)? onProgress,
    bool recordChanges = true,
    String? authorUserId,
  });

  /// 导入分类（先一级后二级），返回分类缓存供交易导入复用。
  Future<Map<String, int>> importCategories(
    LocalRepository repo,
    List<ImportCategory> categories,
  );

  /// 导入交易（统一 batch 路径）。
  Future<ImportResult> importTransactions(
    LocalRepository repo,
    int ledgerId,
    List<ImportTransaction> transactions, {
    required Map<String, int> categoryCache,
    void Function(int done, int total)? onProgress,
    bool recordChanges = true,
    String? authorUserId,
  });
}
