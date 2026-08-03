import '../../l10n/app_localizations.dart';
import 'seed_service.dart';

/// 分类模板条目（模板库页面展示用）
///
/// 纯数据结构，无 DB / BuildContext 依赖，便于单测。
/// "已添加"判定为双通道：确定性 syncId 优先，名称兜底（见 [ExistingCategoryIndex]）。
class CategoryTemplateItem {
  /// 模板 key（如 dining_breakfast）
  final String key;

  /// 翻译后名称
  final String name;

  /// Lucide 图标名
  final String iconName;

  /// 确定性 syncId（与 seed 同源）
  final String syncId;

  /// 层级：1=一级，2=二级
  final int level;

  /// level=2 时的父 key
  final String? parentKey;

  /// 是否已存在于 categories 表（已添加条目勾选置灰，不可再选）
  final bool alreadyAdded;

  const CategoryTemplateItem({
    required this.key,
    required this.name,
    required this.iconName,
    required this.syncId,
    required this.level,
    this.parentKey,
    required this.alreadyAdded,
  });
}

/// hierarchical 模板的父子组
class CategoryTemplateGroup {
  final CategoryTemplateItem parent;
  final List<CategoryTemplateItem> children;

  const CategoryTemplateGroup({required this.parent, required this.children});
}

/// 写入计划：parentsToCreate 必须先于 childrenToCreate 执行
/// （子分类写入需拿到父分类 db id）。
class TemplateInsertPlan {
  /// 需新建的一级分类（flat 页全部选中项 / hierarchical 选中的父 +
  /// 被选中子类隐式依赖的未建父——子分类不能脱离父存在，由计划层兜底补父）
  final List<CategoryTemplateItem> parentsToCreate;

  /// 需新建的二级分类；parentSyncId/parentName 指向父（新父或已在表中的父），
  /// parentName 用于已存在父的名称兜底解析（syncId 不同源时仍能挂到同名父下）
  final List<({CategoryTemplateItem child, String parentSyncId, String parentName})>
      childrenToCreate;

  const TemplateInsertPlan({
    required this.parentsToCreate,
    required this.childrenToCreate,
  });

  /// 计划写入的总条目数
  int get total => parentsToCreate.length + childrenToCreate.length;
}

/// 已存在分类的轻量视图。
///
/// logic 层刻意不依赖 drift（保持纯函数可单测），
/// 由页面/执行层把 db.Category 映射为该记录后传入。
typedef ExistingCategoryLite = ({
  int id,
  String? syncId,
  String name,
  String kind,
  int level,
  int? parentId,
});

/// 已存在分类索引：模板条目"已添加"判定的双通道匹配。
///
/// 为什么需要名称通道：实机上用户可能手动创建过与模板同名的分类
/// （随机 v4 syncId，与模板确定性 syncId 不同源），单走 syncId 会把
/// 已存在的同名分类误判为"可添加"，写入时撞 DuplicateNameException。
/// syncId 通道覆盖 seed/模板写入的分类（改名后仍认得出），
/// 名称通道覆盖手动创建的同名分类，二者互补。
///
/// 仅匹配 expense 分类（模板库全局仅支出模式）。
class ExistingCategoryIndex {
  /// 全部 expense 分类的非空 syncId
  final Set<String> _syncIds;

  /// expense 一级分类
  final List<ExistingCategoryLite> _level1;

  /// expense 二级分类
  final List<ExistingCategoryLite> _level2;

  ExistingCategoryIndex(Iterable<ExistingCategoryLite> categories)
      : _syncIds = {
          for (final c in categories)
            if (c.kind == 'expense' && c.syncId != null) c.syncId!,
        },
        _level1 = [
          for (final c in categories)
            if (c.kind == 'expense' && c.level == 1) c,
        ],
        _level2 = [
          for (final c in categories)
            if (c.kind == 'expense' && c.level == 2) c,
        ];

  /// 一级条目是否已添加：syncId 命中，或已存在同名一级分类
  bool level1Added({required String syncId, required String name}) =>
      _syncIds.contains(syncId) || _level1.any((c) => c.name == name);

  /// 二级条目是否已添加：syncId 命中，或"模板父对应的已存在父"下已有同名二级。
  ///
  /// 对应父的定位同样双通道（syncId 命中或同名一级），保证手动建的父+子
  /// 组合也能被识别为已添加。
  bool level2Added({
    required String syncId,
    required String name,
    required String parentSyncId,
    required String parentName,
  }) {
    if (_syncIds.contains(syncId)) return true;
    final parentIds = {
      for (final p in _level1)
        if (p.syncId == parentSyncId || p.name == parentName) p.id,
    };
    if (parentIds.isEmpty) return false;
    return _level2.any((c) => c.name == name && parentIds.contains(c.parentId));
  }

  /// 解析一级分类的已存在 db id：syncId 优先，同名兜底；未找到返回 null。
  ///
  /// 写入计划挂子类时用：父已在表但 syncId 不同源（手动创建）时，
  /// 名称兜底解析出 db id，子类直接挂到该父下而不新建。
  int? resolveLevel1Id({required String syncId, required String name}) {
    for (final p in _level1) {
      if (p.syncId != null && p.syncId == syncId) return p.id;
    }
    for (final p in _level1) {
      if (p.name == name) return p.id;
    }
    return null;
  }

  /// 某父级（db id）下是否已存在同名二级分类（写入时防御性去重用）
  bool level2ExistsUnder({required int parentId, required String name}) =>
      _level2.any((c) => c.parentId == parentId && c.name == name);
}

/// 模板条目 syncId（与 seed 同源的确定性 UUID）
String templateItemSyncId(int level, String key) =>
    SeedService.deterministicCategorySyncId(kind: 'expense', level: level, key: key);

/// 构建 flat 模板条目列表
List<CategoryTemplateItem> buildFlatTemplateItems(
  AppLocalizations l10n,
  ExistingCategoryIndex existing,
) {
  return [
    for (final key in SeedService.flatExpenseCategoryKeys)
      CategoryTemplateItem(
        key: key,
        name: SeedService.getTranslatedCategoryName(key, 'expense', l10n),
        iconName: SeedService.getDefaultIcon(key),
        syncId: templateItemSyncId(1, key),
        level: 1,
        alreadyAdded: existing.level1Added(
          syncId: templateItemSyncId(1, key),
          name: SeedService.getTranslatedCategoryName(key, 'expense', l10n),
        ),
      ),
  ];
}

/// 构建 hierarchical 模板父子组列表
List<CategoryTemplateGroup> buildHierarchicalTemplateGroups(
  AppLocalizations l10n,
  ExistingCategoryIndex existing,
) {
  return [
    for (final entry in SeedService.hierarchicalExpenseCategories.entries)
      CategoryTemplateGroup(
        parent: () {
          final name = SeedService.getTranslatedParentCategoryName(
              entry.key, 'expense', l10n);
          final syncId = templateItemSyncId(1, entry.key);
          return CategoryTemplateItem(
            key: entry.key,
            name: name,
            iconName: SeedService.getDefaultIcon(entry.key),
            syncId: syncId,
            level: 1,
            alreadyAdded: existing.level1Added(syncId: syncId, name: name),
          );
        }(),
        children: [
          for (final childKey in entry.value)
            () {
              final parentName = SeedService.getTranslatedParentCategoryName(
                  entry.key, 'expense', l10n);
              final name = SeedService.getTranslatedSubCategoryName(
                  childKey, 'expense', l10n);
              final syncId = templateItemSyncId(2, childKey);
              return CategoryTemplateItem(
                key: childKey,
                name: name,
                iconName: SeedService.getDefaultIcon(childKey),
                syncId: syncId,
                level: 2,
                parentKey: entry.key,
                alreadyAdded: existing.level2Added(
                  syncId: syncId,
                  name: name,
                  parentSyncId: templateItemSyncId(1, entry.key),
                  parentName: parentName,
                ),
              );
            }(),
        ],
      ),
  ];
}

/// flat 页勾选切换（已添加条目不可选，调用方保证不传入）
Set<String> toggleFlatSelection(Set<String> selected, String key) {
  final next = {...selected};
  if (next.contains(key)) {
    next.remove(key);
  } else {
    next.add(key);
  }
  return next;
}

/// hierarchical 页勾选切换。
///
/// 约束：
/// - 子类独立勾选/取消，**不连带父**。父未在表时由写入计划自动补父
///   （解决"已有父未被 syncId 识别时勾子类连带勾父、写入撞重名"的问题）；
/// - 勾选父 → 连带选中其全部未添加子类（新父默认整组入表）；
/// - 取消父 → 连带取消其全部子类勾选；
/// - 已添加条目调用方置灰，不会传入本函数。
///
/// [childKey] 非空表示操作的是子类，否则操作父类本身。
/// [allChildKeys] 该父的全部模板子 key（取消父时连带清理）。
/// [selectableChildKeys] 该父的未添加子 key（勾选父时连带全选）。
Set<String> toggleHierarchicalSelection(
  Set<String> selected, {
  required String parentKey,
  String? childKey,
  List<String> allChildKeys = const [],
  List<String> selectableChildKeys = const [],
}) {
  final next = {...selected};

  // 操作子类：独立切换，不触碰父的勾选状态
  if (childKey != null) {
    if (next.contains(childKey)) {
      next.remove(childKey);
    } else {
      next.add(childKey);
    }
    return next;
  }

  // 操作父类
  if (next.contains(parentKey)) {
    next.remove(parentKey);
    // 连带取消全部已勾子类（父子同进退）
    next.removeAll(allChildKeys);
  } else {
    next.add(parentKey);
    // 新父默认整组入表：连带全选未添加子类（已添加子类置灰不可选，不进选中集）
    next.addAll(selectableChildKeys);
  }
  return next;
}

/// flat 页"全选"：只包含未添加条目
Set<String> computeFlatSelectAll(List<CategoryTemplateItem> items) =>
    {for (final it in items) if (!it.alreadyAdded) it.key};

/// hierarchical 页"全选"：只包含未添加条目
/// （父未添加时父与子一并选入；父已添加时仅选未添加子类）。
Set<String> computeHierarchicalSelectAll(List<CategoryTemplateGroup> groups) {
  final result = <String>{};
  for (final g in groups) {
    if (!g.parent.alreadyAdded) result.add(g.parent.key);
    for (final c in g.children) {
      if (!c.alreadyAdded) result.add(c.key);
    }
  }
  return result;
}

/// 生成写入计划（父先子后）。
///
/// [allItems] 扁平化的全部模板条目（含父子，用于解析子的父 syncId）。
/// 已添加条目即使在选中集合中也会被剔除（防御性过滤）。
/// 选中子类但其父既未选中也未在表时，自动把父并入 parentsToCreate——
/// 二级分类不能脱离父存在，UI 层允许单独勾子类，由计划层兜底补父。
TemplateInsertPlan buildInsertPlan({
  required List<CategoryTemplateItem> allItems,
  required Set<String> selectedKeys,
}) {
  final byKey = {for (final it in allItems) it.key: it};
  final parents = <CategoryTemplateItem>[];
  final children =
      <({CategoryTemplateItem child, String parentSyncId, String parentName})>[];
  final plannedParentKeys = <String>{};

  // 1. 显式选中的一级分类（保持模板定义顺序，sortOrder 依次递增）
  for (final it in allItems) {
    if (!selectedKeys.contains(it.key) || it.alreadyAdded) continue;
    if (it.level == 1) {
      parents.add(it);
      plannedParentKeys.add(it.key);
    }
  }

  // 2. 选中的二级分类；父未选中且未在表 → 自动并入待建父（兜底补父）
  for (final it in allItems) {
    if (!selectedKeys.contains(it.key) || it.alreadyAdded) continue;
    if (it.level != 2) continue;
    final parent = byKey[it.parentKey];
    // 子类必须有父 key 且能在模板中找到父，否则跳过（理论上不会发生）
    if (parent == null) continue;
    if (!parent.alreadyAdded && plannedParentKeys.add(parent.key)) {
      parents.add(parent);
    }
    children.add(
        (child: it, parentSyncId: parent.syncId, parentName: parent.name));
  }

  return TemplateInsertPlan(
    parentsToCreate: parents,
    childrenToCreate: children,
  );
}
