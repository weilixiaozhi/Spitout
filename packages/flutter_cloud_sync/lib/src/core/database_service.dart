/// 云数据库服务。
///
/// 云数据库 CRUD + Realtime 的抽象接口，用于替代文件级同步实现记录级同步。
library;

/// 数据库事件类型。
enum DatabaseEventType {
  /// 记录插入。
  insert,

  /// 记录更新。
  update,

  /// 记录删除。
  delete,
}

/// 数据库事件。
class DatabaseEvent {
  /// 事件类型。
  final DatabaseEventType type;

  /// 表名。
  final String table;

  /// 新 / 当前记录数据。
  final Map<String, dynamic> record;

  /// 旧记录数据（update / delete 事件）。
  final Map<String, dynamic>? oldRecord;

  /// 事件时间戳（可选）。
  ///
  /// 缺省为 null，避免消费方把 1970-01-01 哨兵值当成真实时间。
  final DateTime? timestamp;

  DatabaseEvent({
    required this.type,
    required this.table,
    required this.record,
    this.oldRecord,
    this.timestamp,
  });

  @override
  String toString() {
    return 'DatabaseEvent(type: $type, table: $table, record: $record)';
  }
}

/// 查询过滤器。
class QueryFilter {
  /// 列名。
  final String column;

  /// 操作符（eq、gt、lt、gte、lte、like、in 等）。
  final String operator;

  /// 值。
  final dynamic value;

  const QueryFilter({
    required this.column,
    required this.operator,
    required this.value,
  });

  /// 等于。
  static QueryFilter eq(String column, dynamic value) {
    return QueryFilter(column: column, operator: 'eq', value: value);
  }

  /// 大于。
  static QueryFilter gt(String column, dynamic value) {
    return QueryFilter(column: column, operator: 'gt', value: value);
  }

  /// 小于。
  static QueryFilter lt(String column, dynamic value) {
    return QueryFilter(column: column, operator: 'lt', value: value);
  }

  /// 大于等于。
  static QueryFilter gte(String column, dynamic value) {
    return QueryFilter(column: column, operator: 'gte', value: value);
  }

  /// 小于等于。
  static QueryFilter lte(String column, dynamic value) {
    return QueryFilter(column: column, operator: 'lte', value: value);
  }

  /// 模糊匹配。
  static QueryFilter like(String column, String pattern) {
    return QueryFilter(column: column, operator: 'like', value: pattern);
  }

  /// 值在列表中。
  static QueryFilter inList(String column, List<dynamic> values) {
    return QueryFilter(column: column, operator: 'in', value: values);
  }

  @override
  String toString() {
    return 'QueryFilter($column $operator $value)';
  }
}

/// 云数据库服务接口。
///
/// 提供 CRUD 与实时订阅能力。
///
/// 示例：
/// ```dart
/// final dbService = SupabaseDatabaseProvider(client);
///
/// // 插入
/// final record = await dbService.insert(
///   table: 'transactions',
///   data: {'amount': 100, 'note': 'Test'},
/// );
///
/// // 查询
/// final records = await dbService.query(
///   table: 'transactions',
///   filters: [QueryFilter.eq('user_id', userId)],
///   orderBy: 'created_at',
///   descending: true,
///   limit: 10,
/// );
///
/// // 订阅变更
/// dbService.subscribe(
///   table: 'transactions',
///   filters: [QueryFilter.eq('ledger_id', ledgerId)],
/// ).listen((event) {
///   print('${event.type}: ${event.record}');
/// });
/// ```
abstract class CloudDatabaseService {
  /// 插入记录。
  ///
  /// 返回插入后的记录（含服务端生成字段，如 id、时间戳）。
  ///
  /// [autoInjectUserId] - 自动注入当前用户 ID（默认 true）。
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> data,
    bool autoInjectUserId = true,
  });

  /// 按 [id] 更新记录。
  ///
  /// 返回更新后的记录。
  ///
  /// [autoFilterByUser] - 自动追加用户过滤，防止修改其他用户数据（默认 true）。
  Future<Map<String, dynamic>> update({
    required String table,
    required String id,
    required Map<String, dynamic> data,
    bool autoFilterByUser = true,
  });

  /// 按 [id] 删除记录。
  ///
  /// [autoFilterByUser] - 自动追加用户过滤，防止删除其他用户数据（默认 true）。
  Future<void> delete({
    required String table,
    required String id,
    bool autoFilterByUser = true,
  });

  /// 查询记录。
  ///
  /// [filters] - 查询过滤器列表（AND 逻辑）
  /// [orderBy] - 排序列
  /// [descending] - 是否降序（默认 false）
  /// [limit] - 返回上限
  /// [offset] - 跳过的记录数
  /// [autoFilterByUser] - 自动追加用户过滤（默认 true）
  Future<List<Map<String, dynamic>>> query({
    required String table,
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
    int? offset,
    bool autoFilterByUser = true,
  });

  /// 按 ID 获取单条记录。
  ///
  /// 不存在时返回 null。
  ///
  /// [autoFilterByUser] - 自动追加用户过滤（默认 true），
  /// 防止适配器直接按 id 查表造成跨用户读取（IDOR）。
  Future<Map<String, dynamic>?> getById({
    required String table,
    required String id,
    bool autoFilterByUser = true,
  });

  /// 订阅表变更（Realtime）。
  ///
  /// 返回数据库事件流；记录插入 / 更新 / 删除时触发。
  ///
  /// [filters] - 事件过滤条件
  /// [event] - 事件类型（insert / update / delete，'*' 表示全部）
  /// [autoFilterByUser] - 订阅流必须按当前用户过滤（默认 true），
  /// 实现方不得把其他用户的变更推送给订阅方。
  Stream<DatabaseEvent> subscribe({
    required String table,
    List<QueryFilter>? filters,
    String event = '*',
    bool autoFilterByUser = true,
  });

  /// 批量插入。
  ///
  /// 返回插入后的记录列表。
  ///
  /// [autoInjectUserId] - 自动为每条记录注入当前用户 ID（默认 true），
  /// 与单条 [insert] 保持一致的越权防御语义。
  Future<List<Map<String, dynamic>>> batchInsert({
    required String table,
    required List<Map<String, dynamic>> data,
    bool autoInjectUserId = true,
  });

  /// 批量更新。
  ///
  /// [idField] - 标识记录的字段（默认 'id'），每条 data 需包含该字段。
  /// [autoFilterByUser] - 自动追加用户过滤（默认 true），
  /// 防止凭 id 批量修改其他用户记录。
  Future<void> batchUpdate({
    required String table,
    required List<Map<String, dynamic>> data,
    String idField = 'id',
    bool autoFilterByUser = true,
  });

  /// 按过滤器批量删除。
  ///
  /// [autoFilterByUser] - 自动追加用户过滤（默认 true），
  /// 防止删除范围意外覆盖其他用户记录。
  Future<void> batchDelete({
    required String table,
    required List<QueryFilter> filters,
    bool autoFilterByUser = true,
  });

  /// 执行自定义查询（提供方特有）。
  ///
  /// 安全约束：
  /// - 仅限服务端内部 / 受信任调用方使用，禁止把用户输入直接拼进 [query]；
  /// - 适配器实现必须使用参数化绑定，避免 SQL 注入；
  /// - 接口不可移植，跨提供方行为不保证一致。
  Future<List<Map<String, dynamic>>> rawQuery(String query);
}
