# AA 分摊功能 · 最终落地实施方案（多方评审收敛版）

> 实施蓝图，基于 `multi-agent-review.md` 多轮评审的**收敛结论**提炼，仅含最终方案。范围：客户端实施 + server 配合需求。未改动任何代码。
> 关键决议：落库时机收敛为 **模型 B'**（§6.1）。

## 〇、实施顺序（按依赖链）

> **重要**：下文一至九章按**架构分层组织**，非实施先后。实际开发必须按本节顺序推进，否则会出现"字段被服务端静默丢弃却找不到原因"等联调问题。

### 依赖关系图

```
阶段 1（schema 迁移） ─┬─→ 阶段 3（repository 层）─→ 阶段 4（同步层）─┐
                       │                                                ├─→ 阶段 5（服务层）─→ 阶段 6（Provider）─→ 阶段 7（UI）─→ 阶段 8（本地化 + 测试）
阶段 2（服务端扩列） ─┴──────────────────────────────────────────────────┘
```

- 阶段 1、2 **可并行**（互不依赖）
- 阶段 3 依赖阶段 1（db schema 生成后才能写 repository）
- 阶段 4 依赖阶段 2 和 3 都完成（否则联调字段被服务端丢弃，客户端不报错但跨设备不同步）
- 阶段 5→6→7→8 严格串行

### 实施顺序

| 阶段 | 内容 | 对应文档章节 | 前置依赖 |
|---|---|---|---|
| **1** | **schema 迁移 + 生成代码** | §二 | 无 |
| | - `lib/data/db.dart` bump schemaVersion 1→2，`Transactions` 加 4 字段，`Ledgers` 加 `aaEnabled`，新增 `LedgerVirtualUsers` 表 | | |
| | - `onUpgrade` 追加 v2 块（两步法：加可空列 → UPDATE 回填 + WHERE 守卫） | | |
| | - `fvm dart run build_runner build --delete-conflicting-outputs` | | |
| | - `fvm dart run drift_dev schema dump lib/data/db.dart drift_schemas/` | | |
| **2** | **服务端 alembic 迁移 + models + projection + sync_applier + snapshot_builder**（可与阶段 1 并行） | §七、§10.2 | 无 |
| | - `alembic/versions/0002_aa_settlement.py`：`read_tx_projection` 加 4 列 + `ledgers` 加 `aa_enabled` + 新建 `read_virtual_user_projection` 表 | | |
| | - `models.py`：`ReadTxProjection` 加 4 字段 + `Ledger` 加 `aa_enabled` + 新增 `ReadVirtualUserProjection` 类 | | |
| | - `projection.py`：`upsert_tx` 的 `values` 字典加 4 字段 + 新增 `upsert_virtual_user/delete_virtual_user` | | |
| | - `sync_applier.py`：`_LEDGER_MERGE_SPECS["transaction"]` 加 4 条 + `_LEDGER_MERGE_SPECS["virtual_user"]` 新增 + `_LEDGER_UPSERT_DISPATCH/_LEDGER_DELETE_DISPATCH` 登记 virtual_user（ledger-scoped） | | |
| | - `snapshot_builder.py`：`tx_stmt` SELECT 加 4 字段 + item dict 输出加 4 字段 + 新增 virtualUsers 数组 | | |
| **3** | **客户端 repository 层扩展** | §二 | 阶段 1 |
| | - `transaction_repository.dart`：`addTransaction/updateTransaction` 加新参数 + 新增 `getAaTransactionsByLedger` | | |
| | - `local_transaction_repository.dart`：实现新参数写入 + 按 `aaMode` 过滤查询 | | |
| | - 新增 `LedgerVirtualUserRepository` 接口 + `LocalLedgerVirtualUserRepository` 实现（含删除约束） | | |
| | - `local_repository.dart` 委托层透传 | | |
| **4** | **客户端同步层**（serializer + apply + transactions_json） | §三 | 阶段 2、3 |
| | - `entity_serializer.dart`：`serializeTransaction` 加 4 字段（"非空才发"守卫）+ 新增 `serializeVirtualUser` | | |
| | - `sync_engine_apply.dart`：`_applyTransactionChange` 解析新字段（`containsKey + Value.absent()` 缺键保护）+ 新增 `_applyVirtualUserChange` | | |
| | - `transactions_json.dart`：导入导出扩展，bump version 6→7，含 `virtualUsers` 数组 | | |
| | - **联调前提**：阶段 2 服务端 projection 已扩列，否则 push 字段被静默丢弃 | | |
| **5** | **服务层** | §四 | 阶段 4 |
| | - 新增 `lib/services/settlement/aa_settlement_service.dart`（纯计算，按 §8 算法 + §10.2 支出人兜底余数） | | |
| | - 新增 `lib/services/settlement/aa_decimal_util.dart`（Decimal 工具） | | |
| | - 扩展 `tx_author_service.dart`：`markTxCreated/markTxEdited` 同时写 `paidByUserId`（按需求 §2.2 默认值逻辑） | | |
| **6** | **Provider 层** | §五 | 阶段 5 |
| | - 新增 `lib/providers/settlement/settlement_providers.dart`：`aaEnabledProvider/aaSettlementProvider/ledgerVirtualUsersProvider/virtualUserManageProvider` | | |
| | - `database_providers.dart` 注入 `virtualUserRepositoryProvider` | | |
| | - `shared_ledger_providers.dart` 的 `markTxCreatedFromUi/markTxEditedFromUi` 扩展透传 `paidByUserId` | | |
| | - `all_providers.dart` barrel 导出 | | |
| **7** | **UI 层**（router → pages → widgets） | §六 | 阶段 6 |
| | - `router.dart` 新增 `Routes.aaSettlement/Routes.aaEdit` | | |
| | - 新增 `pages/settlement/aa_settlement_page.dart`（汇总卡 + 每人汇总表 + 转账方案 + 不计入清单） | | |
| | - 新增 `pages/settlement/aa_edit_page.dart`（主体只读 + 支出人 + 分摊方式 + 参与人 + 指定金额，pop result 不写库） | | |
| | - 新增 `pages/settlement/widgets/` 下 3 个 bottom sheet/selector 组件 | | |
| | - `widgets/transaction_editor_sheet.dart` 加"分摊方式"项 + `_onSubmit` 模型 B' 分流（人均/不分摊直接落库；指定分摊跳 `AaEditPage` 取 result 后一次性写入） | | |
| | - `pages/main/ledger_edit_page.dart` 加开关 + 分摊设置模块 | | |
| | - `pages/transaction/category_detail_page.dart` 加"支出人"字段 + 常驻"编辑记账"按钮 | | |
| **8** | **本地化 + 测试** | §九 | 阶段 7 |
| | - 4 个 `.arb` 文件补分摊文案 key | | |
| | - 新增 `test/services/settlement/aa_settlement_service_test.dart`（纯计算层单测） | | |
| | - 新增 `test/data/repositories/virtual_user_repository_test.dart`（CRUD + 删除约束） | | |
| | - 扩展 `test/cloud/sync/entity_serializer_test.dart`（新字段 round-trip + 缺键保护） | | |
| | - schema v1→v2 升级端到端测试 | | |
| | - `fvm flutter analyze` + `fvm flutter test` | | |
| **9** | **风险决议核对**（实施完成后的验收清单） | §八 | 阶段 8 |
| | - 逐条核对 §8 风险表，确认每个收敛决议已落实 | | |
| | - 重点核对 R0（迁移两步法）、R1（缺键保护）、R3（模型 B'）、R6（null=人均）、R7（硬删 + delete 投影） | | |

### 并行机会

- **阶段 1 与阶段 2 完全并行**：客户端 schema 迁移与服务端 alembic 迁移互不依赖，可分配给不同人同时推进
- **阶段 7 UI 层内部可部分并行**：`aa_settlement_page/aa_edit_page/widgets/ledger_edit_page/category_detail_page` 之间耦合度低，可拆分
- **阶段 8 测试可边开发边写**：阶段 5 完成后即可开始写 service 单测，不必等到阶段 7 全部完成

### 关键里程碑

| 里程碑 | 完成标志 | 阶段 |
|---|---|---|
| schema 就绪 | `fvm flutter test` schema 升级测试通过 | 1 |
| 服务端就绪 | 服务端单元测试通过 + `snapshot_builder` 输出含新字段 | 2 |
| 联调就绪 | 客户端 push → 服务端存储 → pull 回客户端，4 个新字段完整 round-trip | 4 |
| 功能可演示 | 单设备分摊统计页可用 | 7 |
| 跨设备可用 | 共享账本协作，虚拟用户 + 分摊数据跨设备同步 | 7 + 服务端阶段 2 |
| 全量交付 | `fvm flutter analyze` 0 error + 全测试通过 | 8 |

---

## 一、收敛结论总览

### 1.1 双方收敛的 10 个技术点（与评审文档一致，全部闭环）

1. **迁移两步法（R0）**：`paidByUserId` 声明为 nullable；`addColumnIfMissing` 加可空列 → `customStatement` 回填（WHERE 守卫幂等）。
2. **同步缺键保护（R1）**：apply 端 `containsKey + Value.absent()`；序列化"非空才发"。
3. **`paidByUserId` nullable + 运行时保证（R6）**：写入层 `?? 操作者 userId`；展示层空串降级"未知"。
4. **`aaMode=null` 视为人均（R6 修订）**：需求 §7.3 明文，历史交易默认进人均统计。
5. **`aa_enabled` 必须跨设备同步**：与 `ledger.name/currency/monthStartDay` 同通道（`serializeLedger` 内）。
6. **虚拟用户必须同步、硬删 + delete 投影、不软删（R7）**：共享账本核心场景；删除走 change log `delete` 投影。
7. **`LedgerVirtualUsers` 表结构**：`IntColumn autoIncrement + ledgerId(int) + syncId(text nullable) + name(text)`；**无 color/avatar/deleted**。
8. **Decimal 精度（R4/R10）**：service 入口 `Decimal.parse(amount.toStringAsFixed(2))` 全程 Decimal；`aaSplits` 金额一律存字符串。
9. **落库职责集中在编辑器**：`AaEditPage` 纯选择器不写库，只返回 result。
10. **落库时机（模型 B'）**：编辑器跳 `AaEditPage` 前**不落库**，返回 result 后一次性写入全部字段。

### 1.2 关键术语约定

- **"保存"** = 记账编辑器 `_onSubmit` 触发的**整体落库**。
- 指定分摊模式下，"保存"在编辑器收到 `AaEditPage` 返回的 result 后执行；**跳页前不落库**，返回 `null` 视为取消（回编辑器，内容保留、未保存）。

## 二、数据层（schema v1→v2）

### 2.1 `Transactions` 新增 4 个 nullable 字段

| Dart getter | 列名 | 类型 | 语义 |
|---|---|---|---|
| `paidByUserId` | `paid_by_user_id` | TEXT nullable | 支出人 userId；全局必填由**运行时保证**（写入 `?? 操作者 userId`），非 DB 约束 |
| `aaMode` | `aa_mode` | INTEGER nullable | **null/0=人均，1=不分摊，2=指定** |
| `aaParticipants` | `aa_participants` | TEXT nullable | JSON 数组（userId/虚拟用户 syncId）；**空 = 运行时展开为当前账本全部成员** |
| `aaSplits` | `aa_splits` | TEXT nullable | JSON 对象（键=参与人，值=金额**字符串**） |

```dart
TextColumn get paidByUserId => text().nullable()();
IntColumn get aaMode => integer().nullable()();
TextColumn get aaParticipants => text().nullable()();
TextColumn get aaSplits => text().nullable()();
```

### 2.2 `Ledgers` 新增 1 字段

| Dart getter | 列名 | 类型 | 说明 |
|---|---|---|---|
| `aaEnabled` | `aa_enabled` | BOOLEAN default false | 分摊开关；**必须跨设备同步** |

### 2.3 新表 `LedgerVirtualUsers`

| getter | 列名 | 类型 | 说明 |
|---|---|---|---|
| `id` | `id` | INTEGER autoIncrement (pk) | 本地主键 |
| `ledgerId` | `ledger_id` | INTEGER | 所属账本（不做 SQL 外键） |
| `syncId` | `sync_id` | TEXT nullable | 跨设备唯一标识（UUID） |
| `name` | `name` | TEXT notNull | 昵称 |
| `createdAt` | `created_at` | DATETIME default now | 创建时间 |
| `updatedAt` | `updated_at` | DATETIME nullable | 修改时间 |

**不引入** `color`（需求未提）、`deleted`/软删（需求 §3.1 硬约束已规避悬空）、`avatar_seed` 等需求未定义的字段。

### 2.4 schema v1→v2 迁移（两步法）

```dart
if (from < 2) {
  // 第一步：加可空列（SQLite 不允许对已有表加 NOT NULL 无默认列）
  await addColumnIfMissing('transactions', 'paid_by_user_id',
      'ALTER TABLE transactions ADD COLUMN paid_by_user_id TEXT;');
  await addColumnIfMissing('transactions', 'aa_mode',
      'ALTER TABLE transactions ADD COLUMN aa_mode INTEGER;');
  await addColumnIfMissing('transactions', 'aa_participants',
      'ALTER TABLE transactions ADD COLUMN aa_participants TEXT;');
  await addColumnIfMissing('transactions', 'aa_splits',
      'ALTER TABLE transactions ADD COLUMN aa_splits TEXT;');
  await createTableIfMissing(migrator, 'ledger_virtual_users', ...);
  await addColumnIfMissing('ledgers', 'aa_enabled',
      'ALTER TABLE ledgers ADD COLUMN aa_enabled INTEGER NOT NULL DEFAULT 0;');
  // 第二步：回填支出人（COALESCE + WHERE 守卫，幂等）
  await customStatement('UPDATE transactions SET paid_by_user_id = '
      'COALESCE(created_by_user_id, "") WHERE paid_by_user_id IS NULL;');
}
```

回填后写入层 `?? 操作者 userId` 保证非空；展示层对空串降级显示"未知"。

### 2.5 Repository 层扩展

- `LocalTransactionRepository`：`addTransaction`/`updateTransaction` 收 `paidByUserId/aaMode/aaParticipants/aaSplits` 直写（子仓收"已定值"）。
- `LocalRepository.addTransaction`：`markTxCreatedFromUi` 扩展——新建取操作者、编辑取编辑者、手改保留；写库后照常 `recordLedgerChange` 登记 sync 队列（`local_repository.dart` L366-388 现有模式）。
- `LocalLedgerRepository`：`aaEnabled` 写入 + `serializeLedger` 同步；虚拟用户 CRUD 写 `ledger_virtual_users`（`syncId` 走既有 UUID 生成）。

## 三、同步层

### 3.1 实体序列化（非空才发）

- `paidByUserId/aaMode/aaParticipants/aaSplits` 沿用 nullable 字段现有模式（`entity_serializer.dart` L48-51 写法）：仅非空才写投影 JSON。旧 server 收不到未知键。
- `aa_enabled` 并入 `serializeLedger`（ledger 同通道，必同步）。
- `virtual_user` 独立实体类型，change log 走 `action: create/update/delete`。

### 3.2 `sync_engine_apply` 缺键保护

- 解析 `transaction` 投影时 `json['aaMode'] as int?` 式兜底（`sync_engine_apply.dart` L152-154 现有模式），缺键视为未启用——旧交易/旧快照/旧 server 数据均不崩。
- `virtual_user` 投影缺键同理。

### 3.3 `transactions_json` v6→v7

- 增加：`paidByUserId`、`aaMode`、`aaParticipants`、`aaSplits`、`aaEnabled`、`virtualUsers`。
- 导入 v6 缺键兜底为空 → 视为未启用 AA。
- **虚拟用户随导出**（开放问题 #3，双方一致推荐）：导出含 `virtualUsers`，否则导入后指定分摊数据悬空。

### 3.4 虚拟用户 change log 与删除投影

- 创建/更新：`entityType: 'virtual_user'`，`action: create/update`。
- 删除：**硬删 + `action: 'delete'` 投影**（对齐 `ledger_snapshot:delete`，`local_repository.dart` L204-210 现有写法）；server 按 `entity_sync_id` 删投影。
- 悬空规避：需求 §3.1 硬约束"名下有账不可删"已禁止删除被引用虚拟用户，无需软删字段。

## 四、服务层

### 4.1 `aa_settlement_service`（纯计算）

**入口**：`Decimal.parse(amount.toStringAsFixed(2))`，全程 Decimal，输出 double 化；`aaSplits` 金额存字符串。

**分摊规则**：

| aaMode | 规则 |
|---|---|
| null/0（人均） | 全部参与人（`aaParticipants` 空则运行时展开为当前账本全部成员/虚拟用户）均分；`每人应摊 = floor(实付×100/n)/100`；**支出人实付差归支出人**（§10.2），保证 `sum(差额)=0` |
| 1（不分摊） | 不进入 AA 统计，跳过 |
| 2（指定） | `aaSplits` 即最终应摊，按分校验 `sum == 实付` |

**参与人解析**：真实成员取 `userId`，虚拟用户取 `syncId`；`tx_author_service` 提供身份映射。

## 五、Provider 层

- 新增 AA 分摊统计查询、虚拟用户 CRUD 状态入口。
- 全部写操作走 `LocalRepository`（保证 sync 登记统一，禁止绕过）。

## 六、UI 层

### 6.1 落库时机：模型 B'（最终统一流程）

```
用户点击"保存"（_onSubmit）
  ├─ 非 AA 交易 ─────────────────► 直接落库（现有路径不变）
  └─ AA 交易（指定分摊模式）
        ├─ 分摊未填写 ────────────► 编辑器内补齐后再落库
        └─ 需编辑分摊
              │ ① 编辑器【不落库】
              │ ② Navigator.push(AaEditPage)  // 编辑器 State 驻留导航栈
              │ ③ 返回 result（null=取消）
              │ ④ 收到 result 后一次性落库全部字段（主体+aa*）
              └─ 取消 ────────────► 编辑器保持开启，内容保留、未保存（§6.5）
```

要点：
- 编辑器是**唯一**落库入口；`AaEditPage` 纯选择器不写库、不触发任何 sync 登记。
- await 期间编辑器 `State` 驻留内存（`showModalBottomSheet` 独立 route + push 压栈，返回即恢复），无状态丢失。
- 中间态（`aaMode=2 + aaSplits=空`）**永不落库**，杜绝 `local_changes` 污染协作方（已核对 `local_repository.dart` L366-388：落库即登记 sync 队列）。
- 取消/放弃 = 零副作用，符合 §6.5"内容保留、未保存"。

### 6.2 记账编辑器（`transaction_editor_sheet.dart`）

- 新增 AA 区块：分摊方式（人均/指定）+ 参与人选择；`_onSubmit` 增加 AA 分流，选中"指定"先跳 `AaEditPage`，收到 result 后落库。
- 编辑已有交易：回填 `aa*`；主体信息展示来自**编辑器当前输入**（新建/编辑统一，符合"编辑流程与新建完全一致"）。

### 6.3 `AaEditPage`（纯选择器，不写库）

- 只读展示主体信息（金额/分类/日期，不可改）。
- 分摊项编辑：参与人列表（成员+虚拟用户）、每人金额输入（Decimal）、合计校验 = 交易金额（§10.3），偏差按**支出人兜底**修正。
- 返回 `result`：null=取消；否则携带 `aaMode/aaParticipants/aaSplits/paidByUserId` 回传编辑器。
- 虚拟用户管理入口（新建/重命名/删除；名下有账不可删）。

### 6.4 分摊统计页

- 按交易聚合每人参与金额；`aaMode=1` 的交易跳过。
- 人均交易按运行时展开成员计算；指定交易直接读 `aaSplits`。

### 6.5 账本设置页开关

- `ledger_edit_page.dart` 新增 `aaEnabled` 开关（同步至 `ledgers.aa_enabled`，跨设备生效）。
- 关闭后：入口隐藏、历史数据不展示不参与统计；重开数据仍在。

### 6.6 交易详情页

- 展示分摊明细（人均/指定两种样式）。

### 6.7 功能隔离

- `aaEnabled=false` 账本：不显示 AA 入口、不创建 AA 交易、`aa*` 字段恒 null。

## 七、服务器端配合需求

### 7.1 必选项目（cloud 型后端）

| 项 | 说明 |
|---|---|
| `transaction` projection 扩列 | `paidByUserId/aaMode/aaParticipants/aaSplits`，允许为空 |
| `virtual_user` 实体投影 | `create/update/delete` 三类 change |
| `ledger` projection 扩列 | `aaEnabled` |

### 7.2 快照型后端

- 零改动：新字段随 `transactions_json` v6→v7 透传，缺键由客户端兜底。
- **待确认**：cloud 端 `transaction` 投影是"白名单字段"还是"原样 JSON"（见 §10-3）。

### 7.3 兼容性

- 新客户端 + 旧 server：`aa*` 字段非空才发，旧 server 忽略未知键，AA 降级为不可用但不崩溃。
- 旧客户端 + 新 server：新字段被忽略。

## 八、风险决议表（全部已收敛）

| 风险 | 决议 |
|---|---|
| 迁移中断 | 两步法 + 可空列 + WHERE 守卫幂等（R0） |
| 旧数据/旧 server 缺键 | 缺键兜底（R1） |
| `paidByUserId` 跨设备冲突 | LWW 覆盖，同 `lastEditedByUserId` 语义（R2） |
| 中间态污染协作方 | 模型 B'：中间态不落库（R3） |
| 浮点误差 | Decimal 全程计算（R4） |
| 状态丢失 | push 返回值 + State 驻留导航栈（R5） |
| 历史交易语义 | `aaMode=null` 视为人均（R6） |
| 虚拟用户删除 | 硬删 + delete 投影；名下有账不可删（R7） |
| 开关关闭 | 入口隐藏 + 数据保留（R8） |
| 导入导出 | v6→v7 + 虚拟用户随导出（R9） |
| 表结构 | IntColumn autoIncrement + syncId，无外键（R10） |

## 九、测试计划（关键用例）

1. **迁移**：v1→v2 升级后存量交易 `paid_by_user_id` 均回填自 `created_by_user_id`；升级中断可回滚。
2. **同步**：新交易带 `aa*` 上行；旧 server 不收未知键；缺键快照 apply 不崩；`aa_enabled` 跨设备生效。
3. **落库时机**：指定分摊编辑中取消 → 无任何写库/change 记录；保存 → 恰好一条 `create` change。
4. **分摊精度**：3 人 10.00 → 3.34/3.33/3.33，支出人实付差归支出人，总和恒等。
5. **虚拟用户**：跨设备同步、删除投影、名下有账不可删。
6. **开关**：关闭后入口隐藏、统计剔除；重开数据恢复。
7. **导入导出**：v6 导入兜底；v7 导出含新字段与虚拟用户。

## 十、需求方 / 服务端确认结果（已确认）

> 以下为双方评审收敛后仅剩的开放项，已由需求方/产品方确认。技术实现按确认结论推进。

### 10.1 已确认的决策

| # | 问题 | 确认结论 |
|---|---|---|
| 1 | §10.9 表述矛盾 | 按第二段实现：**指定分摊后金额表单加减**（默认空 + 用户逐人填写） |
| 2 | "保存"语义 | 按 B' 实现：**保存 = 编辑器整体落库，跳 `AaEditPage` 前不落库** |
| 3 | `transaction` projection 字段策略 | **已确认模式 A（白名单 projection）**，服务端必须显式扩列（详见 §10.2） |
| 4 | virtual_user 投影升级 | **本期服务端配合新增 `virtual_user` 实体投影**（含 create/update/delete 三类 change） |

### 10.2 待服务端确认项：transaction projection 字段策略

**已确认**：经核对 `D:\_code\Spitout-Cloud` 服务端源码，**服务端是模式 A（白名单 projection）**，必须显式扩列。

**证据链**：

| 证据点 | 文件/行号 | 说明 |
|---|---|---|
| `ReadTxProjection` 表模型显式字段 | `src/models.py` L385-416 | 每个字段都需 `Mapped[...]` 声明，无"原样 JSON"列 |
| `upsert_tx` 显式字段字典 | `src/projection.py` L184-214 | 只提取 `payload.get("...")` 列出的字段写入 `values`，未列出的字段被**静默丢弃** |
| `_LEDGER_MERGE_SPECS["transaction"]` 显式字段列表 | `src/sync_applier.py` L146-170 | 未登记的字段不会被 partial update 缺键保护 |
| `snapshot_builder.build` 显式 SELECT + dict 组装 | `src/snapshot_builder.py` L46-99 | 未列出的字段不会输出到 mobile `/sync/full` 响应 |
| CLAUDE.md "新增 entity" 步骤 | L64-76 | 明确要求"新建 `read_*_projection` 表 + alembic migration + `projection.py` 加 upsert_*" |

**结论**：客户端 push 的 `paidByUserId/aaMode/aaParticipants/aaSplits` 若未在服务端登记，会在 `upsert_tx` 被静默丢弃，跨设备同步时字段丢失，且客户端不报错。

**服务端必须配合的改动清单**：

1. **`alembic/versions/0002_aa_settlement.py`（新增迁移）**：
   - `read_tx_projection` 表 `ALTER TABLE ADD COLUMN` 4 列：`paid_by_user_id (TEXT)`、`aa_mode (INTEGER nullable)`、`aa_participants (TEXT nullable, JSON)`、`aa_splits (TEXT nullable, JSON)`
   - `ledgers` 表 `ALTER TABLE ADD COLUMN` 1 列：`aa_enabled (BOOLEAN NOT NULL DEFAULT FALSE)`
   - 新建 `read_virtual_user_projection` 表：`id (TEXT PK) / user_id (TEXT FK) / ledger_id (TEXT FK) / sync_id (TEXT) / name (TEXT) / created_at (DATETIME) / updated_at (DATETIME)`

2. **`src/models.py`**：
   - `ReadTxProjection` 类新增 4 个 `Mapped[...]` 字段声明
   - `Ledger` 类新增 `aa_enabled` 字段声明
   - 新增 `ReadVirtualUserProjection` 类

3. **`src/projection.py`**：
   - `upsert_tx` L184-214 的 `values` 字典新增 4 字段提取（参考现有 `excludeFromStats` 的 `_as_bool` + `currencyCode` 的 `_as_str` 模式）
   - 新增 `upsert_virtual_user` / `delete_virtual_user` 函数

4. **`src/sync_applier.py`**：
   - `_LEDGER_MERGE_SPECS["transaction"]` L147-169 的 fields 列表新增 4 条：(payload_key, projection_column) 映射，确保 partial update 缺键保护
   - `INDIVIDUAL_ENTITY_TYPES` L61 新增 `"virtual_user"`
   - 新增 `_USER_UPSERT_DISPATCH["virtual_user"]` / `_USER_DELETE_DISPATCH["virtual_user"]`（虚拟用户是 user-global 还是 ledger-scoped 见下注）
   - 若虚拟用户走 ledger-scoped：登记 `_LEDGER_MERGE_SPECS` / `_LEDGER_UPSERT_DISPATCH` / `_LEDGER_DELETE_DISPATCH`

5. **`src/snapshot_builder.py`**：
   - `build()` 的 `tx_stmt` SELECT 列表 L46-63 新增 4 字段
   - item dict 组装 L74-99 新增 4 字段输出（"非空才发"守卫，参考 `currencyCode/nativeAmount` L93-96）
   - 新增 virtualUsers 数组输出

6. **`src/routers/write/`**：
   - 若本期 web 端也要支持分摊：新增 `virtual_users.py` POST/PATCH/DELETE 端点
   - `transactions.py` 的 write 端点扩展新字段映射

7. **测试**（CLAUDE.md 要求）：
   - `tests/test_projection_consistency.py` 扩展：mixed-entities 含新字段
   - 新增 `test_mobile_push_transaction_partial_update_keeps_existing_fields` 风格的 merge 契约测试，覆盖 4 个新字段的缺键保护

**虚拟用户 scope**：**ledger-scoped**（与 transaction 同通道）。虚拟用户是账本内实体（需求 §3.1"账本维度"），不跨账本共享。

走 ledger-scope 同步通道的具体登记：
- `_LEDGER_MERGE_SPECS["virtual_user"]`：主键 `(ledger_id, sync_id)`，fields 含 `name` 等字段
- `_LEDGER_UPSERT_DISPATCH["virtual_user"]`：指向 `projection.upsert_virtual_user`
- `_LEDGER_DELETE_DISPATCH["virtual_user"]`：指向 `projection.delete_virtual_user`（硬删 + change log delete 投影，R7）
- `local_repository.dart` 端 `recordLedgerChange(entityType: 'virtual_user', ledgerId: 具体账本 id)` —— 不走 `recordUserGlobalChange` 通道

**同步语义**：upsert（新增/改名）+ delete（删除，经 change log `delete` 投影下发到协作设备）。删除前校验名下有账不可删（需求 §3.1 硬约束，R7）。

### 10.3 虚拟用户随导出

双方 Agent 已一致推荐"导出"（`transactions_json` v7 含 `virtualUsers`，否则导入后指定分摊数据悬空）。**产品方已确认无异议**，按推荐推进。
