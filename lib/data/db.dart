import 'dart:io';

import 'package:drift/drift.dart';
import '../core/logging/logger_service.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// 迁移幂等工具箱:onUpgrade 内的所有 DDL 必须经此扩展的 helper。
import 'migration_helpers.dart';

part 'db.g.dart';

// --- Tables ---

class Ledgers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get type => text().withDefault(const Constant('personal'))();  // personal / shared
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // 跨设备同步唯一标识：跟 categories 的 syncId 同语义，
  // 对齐 Spitout Cloud server 的 ledger.external_id。device B 首次登录
  // 通过 readLedgers() 拉到的 ext_id 会写到这里，后续 push/pull 都用这个
  // 做设备间的 ledger 匹配，而不是本地 autoIncrement id（A/B 本地 id 必然
  // 不一致）。
  TextColumn get syncId => text().nullable()();
  // 共享账本字段：server 端 LedgerMember.role 同步下来
  TextColumn get myRole => text().withDefault(const Constant('owner'))();  // owner / editor
  IntColumn get memberCount => integer().withDefault(const Constant(1))();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  TextColumn get ownerUserId => text().nullable()();  // 当前 Owner 是谁
  // 自定义每月起始日(1-28),统计/预算/小部件按 [当月N日, 次月N日) 聚合,
  // 1=自然月。随 sync 跨设备(payload key `monthStartDay`,server 列
  // ledgers.month_start_day)。
  IntColumn get monthStartDay => integer().withDefault(const Constant(1))();

  /// 账本归属(账本级"本地 / 云端"分离,由本字段决定,而非登录状态)。
  /// 'local' = 纯本地账本,永不被被动同步推上云;'cloud' = Spitout Cloud 云端账本,
  /// 走三路被动闸门(fullPush / triggerAutoSync / Phase2)。快照式备份
  /// (supabase/webdav/s3)是整库文件级操作,不属于账本级同步,本地账本一律标 local。
  /// 默认值 'local':新建账本默认本地归属,数据主权零风险。
  TextColumn get storageMode => text().withDefault(const Constant('local'))();

  /// AA 分摊开关。关闭后入口隐藏、历史数据不展示不参与统计;重开数据仍在。
  /// 必须跨设备同步(随 ledger 同通道下发)。
  BoolColumn get aaEnabled => boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => [
        // CHECK 约束兜底:导入/云端恢复/同步 apply 写入越界值时,数据库直接拒绝,
        // 避免统计月界算出错误范围(审计问题 7)。
        'CHECK (month_start_day BETWEEN 1 AND 28)',
      ];
}

/// 自动汇率本地缓存。日期键 append-only;可随时整表重建 → **不进同步**。
/// 方向:1 quote = rate base(rate 为 decimal 字符串)。
class ExchangeRates extends Table {
  TextColumn get baseCurrency => text()();
  TextColumn get quoteCurrency => text()();
  TextColumn get rateDate => text()(); // 'YYYY-MM-DD',取源数据自带日期
  TextColumn get rate => text()();
  TextColumn get source => text()(); // 'server'|'fawazahmed0'|'frankfurter'
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {baseCurrency, quoteCurrency, rateDate};
}

/// 手动汇率覆盖:固定生效直到删除。user-global 同步实体,
/// 字段约定对齐 Categories(syncId UUID)。方向同 ExchangeRates:1 quote = rate base。
/// 业务唯一键 (baseCurrency, quoteCurrency),唯一索引在 onCreate 中建立。
class ExchangeRateOverrides extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get baseCurrency => text()();
  TextColumn get quoteCurrency => text()();
  TextColumn get rate => text()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // 全局仅支出模式，kind 固定为 expense
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))(); // 排序顺序，数字越小越靠前
  IntColumn get parentId => integer().nullable()(); // 父分类ID，null 表示一级分类
  IntColumn get level =>
      integer().withDefault(const Constant(1))(); // 层级：1=一级，2=二级
  // 分类图标统一走 Lucide 内置图标(icon 列)，不存自定义图片/云端图标。
  TextColumn get syncId => text().nullable()(); // 跨设备同步唯一标识 (UUID)

  @override
  List<String> get customConstraints => [
        // CHECK 约束:层级只允许 1/2,导入或同步写入非法层级时数据库直接拒绝。
        'CHECK (level IN (1, 2))',
      ];
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 账本强引用:删账本级联删交易(与仓储层既有删除语义一致,双保险)。
  IntColumn get ledgerId => integer()
      .references(Ledgers, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // 全局仅支出模式，type 固定为 expense
  /// 交易金额,单位=最小货币单位(分),整数存储保证财务精度。
  /// 输入/同步接口仍按"元"口径,落库前统一换算成整数分。
  IntColumn get amount => integer()();
  // 分类弱引用:删分类不删交易,交易回退为"未分类"(避免误删历史账目)。
  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get happenedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  // 周期模板弱引用:删模板保留已生成的历史交易。
  IntColumn get recurringId => integer()
      .nullable()
      .references(RecurringTransactions, #id, onDelete: KeyAction.setNull)();
  TextColumn get syncId => text().nullable()(); // 跨设备同步唯一标识 (UUID)
  // 共享账本"谁记的"显示
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get lastEditedByUserId => text().nullable()();
  // 共享账本 sync_id override
  // Editor 在共享账本下记 tx 时,选 Owner 的 SharedLedgerCategories
  // 行,但本地 Categories 主表没有对应 int id。此 override
  // 字段直接存 Owner 的 syncId 字符串,categoryId 留 null;sync push
  // 时序列化优先用 override(server LWW key 是 syncId,主表 syncId 也是 string)。
  // Owner / 单人账本场景:override 字段为 null,走老路径(categoryId int 反查
  // Categories.syncId)。
  TextColumn get categorySyncIdOverride => text().nullable()();

  /// 不计入支出统计:true 时从支出统计/图表/月年汇总剔除,但仍计入
  /// 账单列表。
  BoolColumn get excludeFromStats =>
      boolean().withDefault(const Constant(false))();

  /// 交易级多币种:交易币种(ISO 大写)。
  /// 用户所选(默认账本本位币)。显式存让交易自包含(同步/统计不必每次 join)。
  TextColumn get currencyCode => text().nullable()();

  /// 折算到账本本位币的金额快照(按记账时汇率,保存即定,不随汇率重算)。
  /// 单币种/未折算 == amount(隐含汇率 1.0)。账本维度统计读本列(?? amount)。
  /// 单位同 [amount]:整数分。
  IntColumn get nativeAmount => integer().nullable()();

  /// 编辑版本号。创建时为 1,每次 update +1。
  /// 用于记录详情 Bottom Sheet 的编辑历史区块展示,以及并发编辑检测。
  IntColumn get version =>
      integer().withDefault(const Constant(1))();

  /// 最后编辑时间。创建时为 null(以此区分"创建"与"编辑"),
  /// 首次编辑后写入。列表项第二行的 HH:mm 与详情协作成员区块均读本字段
  /// (非 happenedAt,后者是"记账日期"语义)。
  DateTimeColumn get lastEditedAt => dateTime().nullable()();

  /// 支出人 userId(交易级全局字段,谁垫付/支出,非 AA 专属)。
  /// 任何一笔账都有支出人:新建未手选时由写入层回填操作者(默认支出人 = 创建人),
  /// 手选后恒写手选值;编辑未手选不更新保持原值。DB 不做非空约束(nullable);
  /// 迁移时从 created_by_user_id 回填,展示层空串降级"未知"。
  TextColumn get paidByUserId => text().nullable()();

  /// AA 分摊模式:null/0=人均,1=不分摊,2=指定金额。
  /// null 视为人均(历史交易默认进人均统计)。
  IntColumn get aaMode => integer().nullable()();

  /// AA 分摊参与人列表(JSON 数组,元素为 userId 或虚拟用户 syncId)。
  /// 空值在运行时展开为当前账本全部成员。
  TextColumn get aaParticipants => text().nullable()();

  /// AA 指定分摊金额(JSON 对象,key=参与人,value=金额字符串)。
  /// 仅 aaMode=2 时有意义。
  TextColumn get aaSplits => text().nullable()();

  @override
  List<String> get customConstraints => [
        // CHECK 约束:仅允许已定义的分摊模式,杜绝脏数据让 AA 分支全部落空。
        'CHECK (aa_mode IS NULL OR aa_mode IN (0, 1, 2))',
        // 多币种成对不变量:currencyCode 与 nativeAmount 必须同时为空或同时非空,
        // 杜绝统计按 `?? amount` 回退时静默用错币种金额(审计问题 7)。
        'CHECK ((currency_code IS NULL AND native_amount IS NULL) '
        'OR (currency_code IS NOT NULL AND native_amount IS NOT NULL))',
      ];
}

/// 记录编辑历史。对应记录详情 Bottom Sheet 的"编辑记录(仅供查看)"区块，
/// 每次交易被编辑(创建除外)时插入一条,
/// 记录版本号、操作者、摘要与时间,便于回溯"谁在什么时候改了什么"。
///
/// 走现有 data→repository→provider 分层:Repository 在 updateTransaction
/// 时 version+1 并写入本表;Provider 暴露 recordEditHistoryProvider(recordId)。
class RecordEditHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 编辑历史从属于交易:交易删除时级联清理,避免详情页"复活"孤儿历史(审计问题 5)。
  IntColumn get recordId => integer()
      .references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get version => integer()(); // 该次编辑后的版本号(从 2 起,1 为创建)
  TextColumn get operatorUserId => text().nullable()(); // 操作者 userId(单人账本为 null)
  TextColumn get summary => text()(); // 摘要:分类名 + 金额 + 日期的人类可读描述
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer()
      .references(Ledgers, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // 全局仅支出模式，type 固定为 expense
  /// 周期模板金额,单位=最小货币单位(分),与 [Transactions.amount] 同口径。
  IntColumn get amount => integer()();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get note => text().nullable()();

  // 重复规则
  TextColumn get frequency => text()(); // daily / weekly / monthly / yearly
  IntColumn get interval =>
      integer().withDefault(const Constant(1))(); // 间隔（每1天、每2周等）
  IntColumn get dayOfMonth => integer().nullable()(); // 月的第几天（1-31）
  IntColumn get dayOfWeek => integer().nullable()(); // 周几（1=周一, 7=周日）
  IntColumn get monthOfYear => integer().nullable()(); // 哪个月（1-12，用于yearly）

  // 时间范围
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()(); // 为空表示永久
  DateTimeColumn get lastGeneratedDate =>
      dateTime().nullable()(); // 最后一次生成交易的日期

  // 状态
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
        // CHECK 约束:重复规则的取值域在数据库层兜底,导入/同步写入非法值时直接拒绝。
        'CHECK (interval >= 1)',
        'CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31)',
        'CHECK (day_of_week IS NULL OR day_of_week BETWEEN 1 AND 7)',
        'CHECK (month_of_year IS NULL OR month_of_year BETWEEN 1 AND 12)',
      ];
}



// 本地变更追踪表（用于增量同步）
class LocalChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();       // transaction/category
  IntColumn get entityId => integer()();       // 本地实体ID
  TextColumn get entitySyncId => text()();     // 实体的 syncId (UUID)
  IntColumn get ledgerId => integer()();       // 关联账本ID
  TextColumn get action => text()();           // create/update/delete
  TextColumn get payloadJson => text().nullable()(); // 变更后的完整 JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get pushedAt => dateTime().nullable()(); // 非null表示已推送
}

// 同步状态表
class SyncState extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();         // 设备唯一标识
  TextColumn get providerType => text().withDefault(const Constant('spitout_cloud'))(); // 防止不同 provider 的 cursor 冲突
  IntColumn get serverCursor => integer().withDefault(const Constant(0))(); // 服务端变更游标
  DateTimeColumn get lastPushAt => dateTime().nullable()();
  DateTimeColumn get lastPullAt => dateTime().nullable()();
}





// sync pull 时 server 端下发的 change 在本地 apply 抛错的持久化记录。
// 健康用户这张表是空的;只在出错时写入,供 UI 暴露 + 用户重试/跳过 + 开发者
// 远程诊断。
class SyncPullErrors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get changeId => integer().unique()();      // server change_id,唯一
  TextColumn get ledgerExternalId => text().nullable()(); // user-global change 可空
  TextColumn get entityType => text()();
  TextColumn get entitySyncId => text()();
  TextColumn get action => text()();                   // upsert / delete
  TextColumn get rawChangeJson => text()();            // 完整 change JSON,供诊断 + 复制给用户
  TextColumn get errorClass => text().nullable()();    // Dart exception 类名
  TextColumn get errorMessage => text().nullable()();  // exception.toString() 首行
  TextColumn get stackTrace => text().nullable()();    // 截断到 ~2KB
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(1))();
  TextColumn get userAction => text().nullable()();    // null / 'skip' / 'retry_requested'
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}

/// 快照型后端(webdav/s3/supabase)的脏账本信号表。
///
/// 为什么独立于 [LocalChanges] 表:
/// - [LocalChanges] 是 Spitout Cloud 增量同步的待推送队列,按实体粒度记录,
///   且 `entity_sync_id` 列为非空 —— 快照后端账本 syncId=null,根本无法写入。
/// - 快照后端是整库文件级备份,只需知道"哪本账本脏了需要重传整本快照",
///   用本表以账本 id 为粒度记录,语义完全不同,不能复用 [LocalChanges]。
///
/// 生命周期(规则4:同步由数据变更驱动,不由 UI 点击直接调 sync):
///   1. createLedger 写入(数据层,同事务) —— 新建账本首快照信号;
///   2. SnapshotSyncCoordinator 监听本表 → debounce → 受 auto_sync 闸门约束
///      调 uploadCurrentLedger 上传整本快照;
///   3. 上传成功后 DELETE 本行(消费完成)。
///
/// UPSERT 语义:同一账本多次标记只保留一行(用 INSERT OR IGNORE 实现,
/// 保留首次 dirtyAt 便于诊断"脏了多久")。
class SnapshotDirtyLedgers extends Table {
  /// 脏账本的本地 id(对应 ledgers.id)。主键,同账本只留一行。
  IntColumn get ledgerId => integer()();

  /// 首次标记脏的时间,用于排序与诊断。重复标记不更新(INSERT OR IGNORE)。
  DateTimeColumn get dirtyAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {ledgerId};
}




// ============================================================================
// 共享账本
// ============================================================================

/// 账本成员镜像表。server `LedgerMember` 表的本地副本,用于"X 记的"显示 +
/// 离线渲染。`GET /api/v1/ledgers/{id}/members` 拉来后写入;`member_change`
/// WS 事件触发增量更新。
class LedgerMembers extends Table {
  TextColumn get ledgerSyncId => text()();        // ledger.syncId(全 user 唯一)
  TextColumn get userId => text()();
  TextColumn get account => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get role => text()();                // owner / editor
  DateTimeColumn get joinedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();   // 本地更新时间,用于 cache 失效

  @override
  Set<Column> get primaryKey => {ledgerSyncId, userId};
}

/// 共享账本里 Owner 的 user-global 分类镜像。Editor 在共享账本下打开"选分类"
/// 弹窗读这表(而非自己的 Categories)。`GET /api/v1/ledgers/{id}/shared-resources`
/// 拉来落库;`shared_resource_change` WS 事件增量更新。
class SharedLedgerCategories extends Table {
  TextColumn get ledgerSyncId => text()();
  TextColumn get syncId => text()();              // Owner 的 user-global category sync_id
  TextColumn get name => text()();
  TextColumn get kind => text()();                // 全局仅支出模式，kind 固定为 expense
  TextColumn get icon => text().nullable()();
  // 共享账本分类图标统一走 Lucide 内置图标(icon 列)。
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  TextColumn get parentName => text().nullable()();
  // 共享账本二级分类:parent 的 syncId,用于 picker 建稳定父子链
  // (parent_name 兜底/显示,parent_sync_id 主)。
  TextColumn get parentSyncId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ledgerSyncId, syncId};
}

/// AA 分摊:账本维度虚拟用户表。
///
/// 设计意图:共享账本下 AA 分摊需要指定参与人,但并非所有参与人都是
/// 注册用户(例如室友、家人),虚拟用户用于补充参与人标识。虚拟用户是
/// 账本内实体(ledger-scoped),不跨账本共享;删除走硬删 + change log delete
/// 投影(对齐 ledger_snapshot:delete 模式),名下有账不可删。
///
/// 不引入 color / avatar / deleted / avatar_seed 等需求未定义的字段;
/// 无 SQL 外键(ledgerId 仅做逻辑关联,不做约束)。
class LedgerVirtualUsers extends Table {
  /// 本地主键。
  IntColumn get id => integer().autoIncrement()();

  /// 所属账本(逻辑关联 ledgers.id,不做 SQL 外键)。
  IntColumn get ledgerId => integer()();

  /// 跨设备唯一标识(UUID),与 server 端 virtual_user 投影对齐。
  /// 本地新建时填 UUID;sync pull 时写回 server 下发的 syncId。
  TextColumn get syncId => text().nullable()();

  /// 虚拟用户昵称。
  TextColumn get name => text()();

  /// 创建时间。
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// 修改时间。
  DateTimeColumn get updatedAt => dateTime().nullable()();
}



@DriftDatabase(tables: [
  Ledgers,
  Categories,
  Transactions,
  RecordEditHistories,
  RecurringTransactions,
  LocalChanges,
  SyncState,
  LedgerMembers,
  SharedLedgerCategories,
  SyncPullErrors,
  ExchangeRates,
  ExchangeRateOverrides,
  SnapshotDirtyLedgers,
  LedgerVirtualUsers,
])
class SpitoutDatabase extends _$SpitoutDatabase {
  SpitoutDatabase() : super(_openConnection());

  /// 测试专用:直接注入 [QueryExecutor](通常是 NativeDatabase.memory()),
  /// 跳过 [_openConnection] 的文件系统 / 平台副作用。test/ 下的 unit test
  /// 用这个。
  SpitoutDatabase.forTesting(super.executor);

  /// 当前 schema 结构对应的数据库版本号 = 4。
  ///
  /// drift 不允许以 0 为起始版本（已知 bug，会破坏迁移），故基线从 1 起步；
  /// 任何 schema 版本升级都从这里递增版本号。
  ///
  /// 版本升级纪律：任何 schema 升级都必须 ① bump 本版本号 ② 在 onUpgrade 追加
  /// if (from < V) 迁移块（走 migration_helpers.dart 的幂等 helper）③ 重跑
  /// schema dump 快照 + 补升级端到端测试。绝不允许 onUpgrade 回到空实现
  /// （否则老用户升级即崩溃）。
  ///
  /// v2: AA 分摊功能 —— Transactions 加 4 字段(paidByUserId/aaMode/
  /// aaParticipants/aaSplits),Ledgers 加 aaEnabled,新增 LedgerVirtualUsers 表。
  /// v3: 支出人兜底回填 —— 存量 NULL/空串 paidByUserId 按
  ///     created_by_user_id → last_edited_by_user_id → 空串 回填,
  ///     让「默认支出人 = 创建人」的语义在存量数据上落地。
  /// v4: 财务精度与完整性加固 —— 金额列 REAL 改 INTEGER(分);
  ///     Transactions/RecordEditHistories/RecurringTransactions 加外键;
  ///     Ledgers/Categories/Transactions/ExchangeRateOverrides/
  ///     LedgerVirtualUsers 的 sync_id 与 SyncState(device_id,provider_type)
  ///     加唯一索引;高频查询列加二级索引;关键不变量加 CHECK 约束。
  /// v5: 账号语义统一 ——— ledger_members.email 改名为 account（数据不变）。
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // 幂等迁移工具箱见 migration_helpers.dart（扩展方法，单测可直接覆盖）。
        beforeOpen: (details) async {
          // SQLite 外键默认关闭,每次连接打开时显式开启,
          // 否则 schema 里的 REFERENCES/ON DELETE 约束不会生效(审计问题 5)。
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (migrator, from, to) async {
          // 入口日志：即使未来某个迁移块忘加起止日志，线上排查用户库
          // 升级路径时也有这一行兜底。
          logger.info('DBMigration', 'onUpgrade: from=$from to=$to');

          // ── 迁移范式（必读）────────────────────────────────────────────
          // 每次 schema 版本升级，bump schemaVersion 到新值 V（> 当前），
          // 并在此追加一个块（块可累积，延续下方范式）：
          //
          //   if (from < V) {
          //     // vV: 功能简述
          //     logger.info('DBMigration', '开始迁移到 vV: 功能简述');
          //     await addColumnIfMissing('table', 'col', 'ALTER TABLE ...');
          //     await createTableIfMissing(migrator, 'new_table', newTable);
          //     // 若需轻量回填（带 WHERE 守卫保证幂等重跑）：
          //     // await customStatement(
          //     //     'UPDATE table SET col = ... WHERE col IS NULL;');
          //     logger.info('DBMigration', 'vV 迁移完成');
          //   }
          //
          // 约束：
          // 1. 所有 DDL 必须经 migration_helpers.dart 的幂等 helper，
          //    不得直接 customStatement ALTER。
          // 2. 数据回填 SQL 必须带 WHERE 守卫（如 col IS NULL），保证幂等。
          // 3. 每个块都有 logger.info 起止日志。
          // 4. 绝不允许回到空实现（否则老用户升级即崩溃）。
          // 5. 需"按新规则转换旧数据 / 重建大表"的业务迁移走 Layer 2
          //    独立 MigrationService，不要塞在这里。
          // 6. 发版前必做（漏了等于没做迁移）：重跑 drift schema dump 生成
          //    新版本快照 + 补"vN 旧库升级到当前版本"端到端测试，并同步补齐
          //    分场景步骤与发布前清单。
          // ─────────────────────────────────────────────────────────────

          if (from < 2) {
            // v2: AA 分摊功能 schema 迁移
            logger.info('DBMigration', '开始迁移到 v2: AA 分摊功能');
            // 第一步:加可空列(两步法 —— SQLite 不允许对已有表加 NOT NULL
            // 无默认列,先加 nullable 列再回填)。addColumnIfMissing 幂等,
            // 中断重跑不会因 duplicate column 崩溃。
            await addColumnIfMissing(
              'transactions',
              'paid_by_user_id',
              'ALTER TABLE transactions ADD COLUMN paid_by_user_id TEXT;',
            );
            await addColumnIfMissing(
              'transactions',
              'aa_mode',
              'ALTER TABLE transactions ADD COLUMN aa_mode INTEGER;',
            );
            await addColumnIfMissing(
              'transactions',
              'aa_participants',
              'ALTER TABLE transactions ADD COLUMN aa_participants TEXT;',
            );
            await addColumnIfMissing(
              'transactions',
              'aa_splits',
              'ALTER TABLE transactions ADD COLUMN aa_splits TEXT;',
            );
            // ledgers 加 aa_enabled(NOT NULL DEFAULT 0,新列对旧行直接取默认值)
            await addColumnIfMissing(
              'ledgers',
              'aa_enabled',
              'ALTER TABLE ledgers ADD COLUMN aa_enabled INTEGER NOT NULL DEFAULT 0;',
            );
            // 新建虚拟用户表(createTableIfMissing 幂等)
            await createTableIfMissing(
              migrator,
              'ledger_virtual_users',
              ledgerVirtualUsers,
            );
            // 第二步:回填 paid_by_user_id(COALESCE + WHERE 守卫,幂等)。
            // 优先取 created_by_user_id,缺失则空串;运行时写入层 `?? 操作者
            // userId` 再兜底为非空。
            await customStatement(
              'UPDATE transactions SET paid_by_user_id = '
              "COALESCE(created_by_user_id, '') "
              'WHERE paid_by_user_id IS NULL;',
            );
            logger.info('DBMigration', 'v2 迁移完成');
          }

          if (from < 3) {
            // v3: 支出人兜底回填。历史存量(导入/旧 server pull/v2 回填空串)
            // 可能留下 NULL 或空串 paid_by_user_id,这里按「默认支出人 = 创建人」
            // 语义一次性回填:优先创建人,缺失退编辑人,双缺失落空串(展示层降级
            // "未知"、计算层跳过,不在 DB 层引入伪造身份)。
            // WHERE 守卫(IS NULL OR = '')保证幂等:已回填的非空值不会被重写。
            logger.info('DBMigration', '开始迁移到 v3: 支出人兜底回填');
            await customStatement(
              'UPDATE transactions SET paid_by_user_id = '
              "COALESCE(NULLIF(paid_by_user_id, ''), "
              "created_by_user_id, last_edited_by_user_id, '') "
              "WHERE paid_by_user_id IS NULL OR paid_by_user_id = '';",
            );
            logger.info('DBMigration', 'v3 迁移完成');
          }

          if (from < 4) {
            // v4: 金额 REAL→INTEGER(分) + 外键 + 唯一/二级索引 + CHECK 约束。
            logger.info('DBMigration', '开始迁移到 v4: 金额改整数分 + 完整性加固');

            // ── 第 1 步:数据归一化(必须在重建表之前,否则 CHECK/FK 建表即失败) ──
            // 1a) currencyCode/nativeAmount 成对约束:缺币种则清折算快照(统计仍
            //     按 amount 兜底);有币种缺快照则按 1:1 补 amount。
            await customStatement(
              'UPDATE transactions SET native_amount = NULL '
              'WHERE currency_code IS NULL AND native_amount IS NOT NULL;',
            );
            await customStatement(
              'UPDATE transactions SET native_amount = amount '
              'WHERE currency_code IS NOT NULL AND native_amount IS NULL;',
            );
            // 1b) 强引用孤儿清理:编辑历史无对应交易 → 删;
            //     交易引用的分类/周期模板不存在 → 置空(不误删账目);
            //     交易引用的账本不存在 → 删(幽灵数据,UI 本就不可达)。
            await customStatement(
              'DELETE FROM record_edit_histories '
              'WHERE record_id NOT IN (SELECT id FROM transactions);',
            );
            await customStatement(
              'UPDATE transactions SET category_id = NULL '
              'WHERE category_id IS NOT NULL AND category_id NOT IN '
              '(SELECT id FROM categories);',
            );
            await customStatement(
              'UPDATE transactions SET recurring_id = NULL '
              'WHERE recurring_id IS NOT NULL AND recurring_id NOT IN '
              '(SELECT id FROM recurring_transactions);',
            );
            // 1c) 分类孤儿修复:父分类不存在的二级分类提升为一级(保留数据,
            //     与分类树构建/记账选择口径一致)。
            await customStatement(
              'UPDATE categories SET parent_id = NULL, level = 1 '
              'WHERE parent_id IS NOT NULL AND parent_id NOT IN '
              '(SELECT id FROM categories);',
            );
            // 1d) 唯一索引前置去重:同 syncId 只保留本地 id 最小的一行
            //     (LWW 冲突的确定性收敛),否则 UNIQUE 索引建不出来。
            await customStatement(
              'DELETE FROM ledgers WHERE sync_id IS NOT NULL AND id NOT IN '
              '(SELECT MIN(id) FROM ledgers WHERE sync_id IS NOT NULL '
              'GROUP BY sync_id);',
            );
            await customStatement(
              'DELETE FROM transactions WHERE ledger_id NOT IN '
              '(SELECT id FROM ledgers);',
            );
            await customStatement(
              'DELETE FROM categories WHERE sync_id IS NOT NULL AND id NOT IN '
              '(SELECT MIN(id) FROM categories WHERE sync_id IS NOT NULL '
              'GROUP BY sync_id);',
            );
            await customStatement(
              'UPDATE categories SET parent_id = NULL, level = 1 '
              'WHERE parent_id IS NOT NULL AND parent_id NOT IN '
              '(SELECT id FROM categories);',
            );
            await customStatement(
              'UPDATE transactions SET category_id = NULL '
              'WHERE category_id IS NOT NULL AND category_id NOT IN '
              '(SELECT id FROM categories);',
            );
            await customStatement(
              'DELETE FROM transactions WHERE sync_id IS NOT NULL AND id NOT IN '
              '(SELECT MIN(id) FROM transactions WHERE sync_id IS NOT NULL '
              'GROUP BY sync_id);',
            );
            await customStatement(
              'DELETE FROM exchange_rate_overrides WHERE sync_id IS NOT NULL '
              'AND id NOT IN (SELECT MIN(id) FROM exchange_rate_overrides '
              'WHERE sync_id IS NOT NULL GROUP BY sync_id);',
            );
            await customStatement(
              'DELETE FROM ledger_virtual_users WHERE sync_id IS NOT NULL '
              'AND id NOT IN (SELECT MIN(id) FROM ledger_virtual_users '
              'WHERE sync_id IS NOT NULL GROUP BY sync_id);',
            );
            await customStatement(
              'DELETE FROM sync_state WHERE id NOT IN '
              '(SELECT MIN(id) FROM sync_state GROUP BY device_id, provider_type);',
            );

            // ── 第 2 步:重建表(REAL 金额→INTEGER 分 + CHECK + FK) ──
            // 依赖顺序:先建被引用表,再建引用表。
            await rebuildTableIfNeeded(
              migrator,
              'ledgers',
              ledgers,
              migratedCheckSql:
                  "SELECT 1 FROM sqlite_master WHERE type='table' "
                  "AND name='ledgers' AND sql LIKE '%BETWEEN 1 AND 28%'",
              copySql:
                  'INSERT INTO ledgers (id, name, currency, type, created_at, '
                  'sync_id, my_role, member_count, is_shared, owner_user_id, '
                  'month_start_day, storage_mode, aa_enabled) '
                  'SELECT id, name, currency, type, created_at, sync_id, '
                  'my_role, member_count, is_shared, owner_user_id, '
                  'month_start_day, storage_mode, aa_enabled FROM ledgers_old;',
            );
            await rebuildTableIfNeeded(
              migrator,
              'categories',
              categories,
              migratedCheckSql:
                  "SELECT 1 FROM sqlite_master WHERE type='table' "
                  "AND name='categories' AND sql LIKE '%level IN (1, 2)%'",
              copySql:
                  'INSERT INTO categories (id, name, kind, icon, sort_order, '
                  'parent_id, level, sync_id) '
                  'SELECT id, name, kind, icon, sort_order, parent_id, level, '
                  'sync_id FROM categories_old;',
            );
            await rebuildTableIfNeeded(
              migrator,
              'recurring_transactions',
              recurringTransactions,
              migratedCheckSql:
                  "SELECT 1 FROM pragma_table_info('recurring_transactions') "
                  "WHERE name='amount' AND type='INTEGER'",
              copySql:
                  'INSERT INTO recurring_transactions (id, ledger_id, type, '
                  'amount, category_id, note, frequency, interval, day_of_month, '
                  'day_of_week, month_of_year, start_date, end_date, '
                  'last_generated_date, enabled, created_at, updated_at) '
                  'SELECT id, ledger_id, type, '
                  'CAST(ROUND(amount * 100) AS INTEGER), category_id, note, '
                  'frequency, interval, day_of_month, day_of_week, month_of_year, '
                  'start_date, end_date, last_generated_date, enabled, created_at, '
                  'updated_at FROM recurring_transactions_old;',
            );
            await rebuildTableIfNeeded(
              migrator,
              'transactions',
              transactions,
              migratedCheckSql:
                  "SELECT 1 FROM pragma_table_info('transactions') "
                  "WHERE name='amount' AND type='INTEGER'",
              copySql:
                  'INSERT INTO transactions (id, ledger_id, type, amount, '
                  'category_id, happened_at, note, recurring_id, sync_id, '
                  'created_by_user_id, last_edited_by_user_id, '
                  'category_sync_id_override, exclude_from_stats, currency_code, '
                  'native_amount, version, last_edited_at, paid_by_user_id, '
                  'aa_mode, aa_participants, aa_splits) '
                  'SELECT id, ledger_id, type, '
                  'CAST(ROUND(amount * 100) AS INTEGER), category_id, '
                  'happened_at, note, recurring_id, sync_id, created_by_user_id, '
                  'last_edited_by_user_id, category_sync_id_override, '
                  'exclude_from_stats, currency_code, '
                  'CASE WHEN native_amount IS NULL THEN NULL '
                  'ELSE CAST(ROUND(native_amount * 100) AS INTEGER) END, '
                  'version, last_edited_at, paid_by_user_id, aa_mode, '
                  'aa_participants, aa_splits FROM transactions_old;',
            );
            await rebuildTableIfNeeded(
              migrator,
              'record_edit_histories',
              recordEditHistories,
              migratedCheckSql:
                  "SELECT 1 FROM pragma_foreign_key_list('record_edit_histories') "
                  "WHERE \"table\"='transactions'",
              copySql:
                  'INSERT INTO record_edit_histories (id, record_id, version, '
                  'operator_user_id, summary, created_at) '
                  'SELECT id, record_id, version, operator_user_id, summary, '
                  'created_at FROM record_edit_histories_old;',
            );

            // ── 第 3 步:唯一/二级索引(幂等,兼容所有升级路径) ──
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_ledgers_sync_id '
                'ON ledgers (sync_id);');
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_sync_id '
                'ON categories (sync_id);');
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_sync_id '
                'ON transactions (sync_id);');
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_exchange_rate_overrides_sync_id '
                'ON exchange_rate_overrides (sync_id);');
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_virtual_users_sync_id '
                'ON ledger_virtual_users (sync_id);');
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_state_device_provider '
                'ON sync_state (device_id, provider_type);');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_transactions_ledger_happened '
                'ON transactions (ledger_id, happened_at);');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_record_edit_histories_record_id '
                'ON record_edit_histories (record_id);');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_local_changes_pushed_at '
                'ON local_changes (pushed_at);');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_recurring_transactions_ledger_id '
                'ON recurring_transactions (ledger_id);');
            await customStatement(
                'CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_override_pair '
                'ON exchange_rate_overrides (base_currency, quote_currency);');

            logger.info('DBMigration', 'v4 迁移完成');
          }

          if (from < 5) {
            // v5: 账号语义统一 ——— ledger_members.email → account。
            // 旧库里这一列实际存的就是账号名，只做列名迁移，不碰数据。
            logger.info(
              'DBMigration',
              '开始迁移到 v5: ledger_members.email -> account',
            );
            await renameColumnIfExists(
              'ledger_members',
              'email',
              'account',
              'ALTER TABLE ledger_members RENAME COLUMN email TO account;',
            );
            logger.info('DBMigration', 'v5 迁移完成');
          }
        },

        onCreate: (m) async {
          await m.createAll();
          // 新建库直接补齐全部索引(与 v4 迁移保持同一套命名/定义)。
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_ledgers_sync_id '
              'ON ledgers (sync_id);');
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_sync_id '
              'ON categories (sync_id);');
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_sync_id '
              'ON transactions (sync_id);');
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_exchange_rate_overrides_sync_id '
              'ON exchange_rate_overrides (sync_id);');
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_virtual_users_sync_id '
              'ON ledger_virtual_users (sync_id);');
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_state_device_provider '
              'ON sync_state (device_id, provider_type);');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_ledger_happened '
              'ON transactions (ledger_id, happened_at);');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_record_edit_histories_record_id '
              'ON record_edit_histories (record_id);');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_local_changes_pushed_at '
              'ON local_changes (pushed_at);');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_recurring_transactions_ledger_id '
              'ON recurring_transactions (ledger_id);');
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_override_pair '
              'ON exchange_rate_overrides (base_currency, quote_currency);');
        },
      );

  // 数据层不感知种子服务，seed 由 services 层 SeedService.ensureSeed 负责，
  // 保持 data ← services 单向依赖。
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'spitout.sqlite'));

    // WAL 模式下 -wal/-shm 文件在连接关闭后仍会存在，属正常现象；
    // 因此这里不做 existsSync“锁文件”检查（避免每次启动误报告警），
    // 也绝不提供删除它们的工具函数——数据库仍打开时删除会销毁 WAL 里未落盘的数据。
    return NativeDatabase.createInBackground(file);
  });
}
