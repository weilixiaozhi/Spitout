import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart' as db;
import '../../services/data/category_template_logic.dart';
import '../core/database_providers.dart';

// 分类模板 UI 统一经本门面引用服务层:类型与写库入口都从 providers 拿,
// 页面/组件不直接 import services 文件,也不触碰 repository。
export '../../services/data/category_template_logic.dart';

/// 执行模板写入计划:UI 只传计划与现有分类,repository 由 providers 层注入。
///
/// 写库失败向上抛给调用方展示,不在本层吞掉,便于页面统一提示。
Future<int> executeTemplateInsertPlanFromUi(
  WidgetRef ref, {
  required TemplateInsertPlan plan,
  required List<db.Category> existingCategories,
}) {
  final repo = ref.read(repositoryProvider);
  return executeTemplateInsertPlan(
    repo: repo,
    plan: plan,
    existingCategories: existingCategories,
  );
}
