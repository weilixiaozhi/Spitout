/// 通用 CSV 账单解析器
///
/// 合并入口后为唯一解析器。表头定位分三层递进：
///   1. 关键词检测（兼容支付宝/微信含描述性前言的导出文件）；
///   2. 通用表头特征检测（按可识别字段数定位，见 `_findHeaderByFieldRecognition`）；
///   3. 列数一致性兜底（含 ±1 列容差，吸收行尾多逗号等脏数据）。
/// 第 2 层不依赖"表头与数据行列数一致"，因此对各类第三方记账 App 的
/// 导出格式（含列数不对称的脏数据）更鲁棒。
class GenericBillParser {
  int findHeaderRow(List<List<String>> rows) {
    if (rows.isEmpty) return -1;

    // 优先：通过关键词定位表头（兼容支付宝/微信含前言的导出文件）。
    // 任一关键词集合被某行全部命中即认为该行是表头。
    final keywordIndex = _findHeaderByKeywords(
      rows,
      keywordSets: const [
        ['交易时间', '商品说明'], // 支付宝导出表头特征
        ['交易时间', '交易类型'], // 微信支付导出表头特征
      ],
    );
    if (keywordIndex != null) return keywordIndex;

    // 第二层：通用表头特征检测。
    // 设计意图：很多第三方记账 App（如本项目的"萌猪"导出）表头是「时间/分类/
    // 类型/金额/账户1/账户2/备注」这类自定义表头，既不匹配支付宝/微信关键词，
    // 又常因数据行末尾多一个逗号导致列数与表头不一致，从而被一致性兜底误判。
    // 这里统计每行能映射到多少个"已知字段名"：表头行几乎每一列都是字段名，
    // 而数据行的具体数值（如「2025-09-28 14:44:05」「交通」「330.0」）几乎无法
    // 映射到字段名。于是识别字段数最多的一行即为表头。
    final fieldHeaderIndex = _findHeaderByFieldRecognition(rows);
    if (fieldHeaderIndex >= 0) return fieldHeaderIndex;

    // 兜底：使用列数一致性规则查找表头（已支持 ±1 列容差）。
    // 表头行的特征是后续数据行的列数都和表头行接近；如果前面有描述文案，
    // 列数通常不一致，从而被跳过。
    final headerIndex = _findHeaderByColumnConsistency(rows);
    if (headerIndex >= 0) return headerIndex;

    // 最终兜底：使用第一行
    return 0;
  }

  /// 通过"通用表头特征"查找表头行
  ///
  /// 在前 30 行中，统计每一行能被 `_normalizeToKey` 识别为已知字段名的【去重】
  /// 列数。表头行通常能把多个列名映射到字段（如「时间→date、金额→amount、
  /// 分类→category」），而数据行的具体取值几乎无法映射到字段名。因此识别字段
  /// 数最多、且达到阈值（≥2）的一行即认定为表头。
  ///
  /// 去重计数而非原始命中计数的原因：像「账户1/账户2」会都映射到 `account`，
  /// 若按原始命中数会虚高分数，去重后更能反映"表头覆盖了多少种不同字段"。
  int _findHeaderByFieldRecognition(List<List<String>> rows) {
    final maxRows = rows.length < 30 ? rows.length : 30;
    int bestIndex = -1;
    int bestScore = 0;

    for (int i = 0; i < maxRows; i++) {
      final row = rows[i];
      // 表头至少要有 2 列才有意义
      if (row.length < 2) continue;

      // 统计本行能识别出的【去重】字段集合
      final recognized = <String>{};
      for (final cell in row) {
        final key = _normalizeToKey(cell);
        if (key != null) recognized.add(key);
      }

      // 至少要能识别 2 个字段，才认为这行具备"表头特征"。
      // 阈值可挡掉恰好命中 1 个字段的异常数据行，避免误判。
      if (recognized.length >= 2 && recognized.length > bestScore) {
        bestScore = recognized.length;
        bestIndex = i;
      }
    }

    return bestIndex; // -1 表示没有任何行达到表头特征阈值
  }

  /// 通过关键词集合查找表头行
  ///
  /// 在前 30 行中，找到第一个「同时包含某关键词集合内全部关键词」的行。
  /// 用于跳过支付宝/微信导出文件开头的描述性前言，直接定位到真正的表头。
  int? _findHeaderByKeywords(
    List<List<String>> rows, {
    required List<List<String>> keywordSets,
  }) {
    final maxRows = rows.length < 30 ? rows.length : 30;
    for (int i = 0; i < maxRows; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final rowStr = row.map((e) => e.toString().trim()).toList();

      // 逐个关键词集合判断：某集合的全部关键词都在本行出现即命中
      for (final keywords in keywordSets) {
        bool containsAll = true;
        for (final keyword in keywords) {
          bool found = false;
          for (final cell in rowStr) {
            if (cell.contains(keyword)) {
              found = true;
              break;
            }
          }
          if (!found) {
            containsAll = false;
            break;
          }
        }
        if (containsAll) return i;
      }
    }
    return null;
  }

  /// 通过列数一致性查找表头行
  ///
  /// 策略：在前 30 行中，找到第一个列数 >=3 且后续至少有 5 行数据列数与之
  /// 接近（相差 ≤1，吸收行尾多逗号等脏数据）的行。
  /// 容差说明：部分导出文件表头列数与数据行列数并不严格相等（例如表头 8 列、
  /// 数据行因末尾多一个逗号变成 9 列）。若要求严格相等，表头会因"无一致数据行"
  /// 被跳过、反而把第一条数据行误判为表头。允许 ±1 列偏差可让这类文件正确归位。
  int _findHeaderByColumnConsistency(List<List<String>> rows) {
    final maxRows = rows.length < 30 ? rows.length : 30;

    for (int i = 0; i < maxRows; i++) {
      final headerCandidateColCount = rows[i].length;

      // 表头至少要有3列才有意义
      if (headerCandidateColCount < 3) continue;

      // 检查后续至少5行的列数是否相近（±1 容差）
      int consistentCount = 0;
      final checkRange = rows.length < i + 10 ? rows.length : i + 10;

      for (int j = i + 1; j < checkRange; j++) {
        // 容差：允许后续数据行列数与候选表头相差 ≤1（吸收行尾多逗号等脏数据）
        if ((rows[j].length - headerCandidateColCount).abs() <= 1) {
          consistentCount++;
        }
      }

      // 如果至少有5行数据列数相近，认为找到了表头
      if (consistentCount >= 5) {
        return i;
      }
    }

    return -1; // 未找到
  }

  Map<String, int> mapColumns(List<String> headerRow) {
    final mapping = <String, int>{};

    for (int i = 0; i < headerRow.length; i++) {
      final key = _normalizeToKey(headerRow[i]);
      if (key != null && !mapping.containsKey(key)) {
        mapping[key] = i;
      }
    }

    return mapping;
  }

  /// 将表头文本规范化为字段key
  String? _normalizeToKey(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final lower = s.toLowerCase();
    final noSpace = lower.replaceAll(RegExp(r'\s+'), '');

    // 英文匹配
    if (noSpace == 'date' || noSpace == 'time' || noSpace == 'datetime') {
      return 'date';
    }
    if (noSpace == 'type' || noSpace == 'inout' || noSpace == 'direction') {
      return 'type';
    }
    if (noSpace == 'amount' ||
        noSpace == 'money' ||
        noSpace == 'price' ||
        noSpace == 'value') {
      return 'amount';
    }
    if (noSpace == 'currency' || noSpace == 'currencycode') {
      return 'currency';
    }
    if (noSpace == 'category' ||
        noSpace == 'cate' ||
        noSpace == 'subject' ||
        noSpace == 'tag') {
      return 'category';
    }
    if (noSpace == 'note' ||
        noSpace == 'memo' ||
        noSpace == 'desc' ||
        noSpace == 'description' ||
        noSpace == 'remark' ||
        noSpace == 'title') {
      return 'note';
    }

    // 中文匹配
    if (_containsAny(s, ['日期', '时间', '交易时间', '账单时间', '创建时间'])) {
      return 'date';
    }
    if (_containsAny(s, ['金额', '金额(元)', '交易金额', '变动金额', '收支金额'])) {
      return 'amount';
    }
    // 多币种:币种列。注意在「分类/类型」等之前匹配,
    // 「币种」不含歧义字,顺序无冲突。
    if (_containsAny(s, ['币种', '幣種', '货币', '貨幣'])) {
      return 'currency';
    }
    // 先匹配"交易类型"等更具体的分类字段（避免被"类型"匹配为type）
    // 优先匹配二级分类相关字段（注意：必须先匹配更长的字符串，避免被短字符串提前匹配）
    if (_containsAny(s, ['二级分类', '子分类', '次分类', 'Subcategory', 'Sub Category'])) {
      return 'sub_category';
    }
    if (_containsAny(s, ['分类', '类别', '账目名称', '科目', '交易分类', '交易类型'])) {
      return 'category';
    }
    // 标签匹配（注意：不要和分类混淆，"标签"单独作为tags字段）
    if (noSpace == 'tags' || _containsAny(s, ['标签', 'Tags'])) {
      return 'tags';
    }
    // 再匹配收支类型字段
    if (_containsAny(s, ['类型', '收支', '收/支', '方向'])) {
      return 'type';
    }
    if (_containsAny(
        s, ['备注', '说明', '标题', '摘要', '附言', '商品名称', '商品说明', '交易对方', '商家'])) {
      return 'note';
    }
    // 账户匹配
    if (_containsAny(s, ['账户', 'Account'])) {
      return 'account';
    }

    // 明确忽略的字段
    if (_containsAny(s, [
      '账目编号',
      '编号',
      '单号',
      '流水号',
      '交易号',
      '相关图片',
      '图片',
      '交易单号',
      '订单号'
    ])) {
      return null;
    }

    return null;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
