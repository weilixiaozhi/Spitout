part of 'sync_engine.dart';

/// pull 路径上把远端变更应用到本地 Drift 的逻辑。`_applyRemoteChange` 是
/// 总入口分发器,按 entity_type 分到具体的 `_apply*Change` handler。
///
/// 这里所有方法都是 private(以 `_` 开头),只在主 library 内被 `_pull` 调
/// 用,所以 extension 可以保持 private。
extension SyncEngineApplyExt on SyncEngine {
  /// 应用单条远程变更到本地数据库
  /// 返回 true 表示已应用，false 表示跳过
  Future<bool> applyRemoteChange(SpitoutCloudSyncChange change) async {
    // 跳过本设备自己的变更
    final deviceId = await _getDeviceId();
    if (change.updatedByDeviceId == deviceId) return false;

    // 如果没有 payload 且不是删除操作，跳过（无法应用）
    if (change.payload == null && change.action != 'delete') {
      logger.debug('SyncEngine',
          'pull: 跳过无 payload 的变更 ${change.entityType}/${change.entitySyncId}');
      return false;
    }

    switch (change.entityType) {
      case 'transaction':
        await _applyTransactionChange(change);
        return true;
      case 'category':
        await _applyCategoryChange(change);
        return true;
      case 'exchange_rate_override':
        await _applyExchangeRateOverrideChange(change);
        return true;
      case 'ledger':
        await _applyLedgerChange(change);
        return true;
      case 'virtual_user':
        await _applyVirtualUserChange(change);
        return true;
      case 'ledger_snapshot':
        // 账本删除信号必须对"增量 pull"与"replayAllChanges"都生效。
        // replayAllChanges() 不走 fullPull → ledger_snapshot:delete 如果跳过,
        // 已删账本连同其全部交易会被 ledger:create / transaction:create 重新建回
        // (幽灵复活 / ghost ledger)。
        // 因此这里就近处理 delete 动作:直接 purge 本地账本(连交易级联删除)。
        // 其余全量快照(upsert)仍交回 fullPull,避免这里解析整份快照 JSON 与 fullPull
        // 重复 / 冲突。
        if (change.action == 'delete') {
          final sid = change.entitySyncId;
          if (sid.isNotEmpty) {
            await _purgeLocalLedgerByExternalId(sid);
          }
          return true;
        }
        return false;
      default:
        logger.warning('SyncEngine', '未知 entityType: ${change.entityType}');
        return false;
    }
  }

  // ==================== Apply 方法 ====================

  Future<void> _applyTransactionChange(SpitoutCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      // delete 路径:先看 cache 拿 id(避免 N+1 SELECT);cache miss 再 DB
      final cachedTx = activePullCache?.transaction(syncId);
      int? existingId = cachedTx?.id;
      if (existingId == null && activePullCache == null) {
        final existing = await (db.select(db.transactions)
              ..where((t) => t.syncId.equals(syncId)))
            .getSingleOrNull();
        existingId = existing?.id;
      }
      if (existingId != null) {
        await (db.delete(db.transactions)
              ..where((t) => t.id.equals(existingId!)))
            .go();
        activePullCache?.removeTransaction(syncId);
        logger.debug('SyncEngine', 'pull: 删除交易 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    // change.ledgerId 是 server 的 external_id（string）。本地 B 设备 auto-
    // increment int id 跟 server 不一致，必须按 syncId 查本地 int id。
    // 只有没命中时才 fallback 到直接 parse（向后兼容老数据 ledger_id 就是
    // int 字符串的场景）。
    final ledgerIdInt = await _resolveLedgerIdBySyncId(change.ledgerId) ??
        int.tryParse(change.ledgerId) ??
        -1;

    // 解析 payload 字段
    final type = payload['type'] as String? ?? 'expense';
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final happenedAtStr = payload['happenedAt'] as String?;
    final happenedAt = happenedAtStr != null
        ? DateTime.tryParse(happenedAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();
    final note = payload['note'] as String?;
    final categoryName = payload['categoryName'] as String?;
    final categoryKind = payload['categoryKind'] as String?;

    // 解析关联实体 ID —— 优先用 syncId 映射（跨设备稳定），fallback 到名字。
    // payload 里的 categoryId 是 server snapshot.items[i] 存的远端实体 syncId，
    // B 设备 pull 后 category 已经上 syncId 了（P1 的 fallback 给 seed 补的，
    // 或 pull 新插入带的），按 syncId 查一定命中。
    // 名字 fallback 兜住旧 snapshot payload 没 syncId 的老数据。
    // server payload.categoryId 是 syncId。
    // 主表反查不到时(Editor 视角看 Owner 的 tx),检查 SharedLedger* 表 —
    // 命中则写 *SyncIdOverride 字段(本地 int id 留 null)。
    final rawCategoryId = payload['categoryId'] as String?;
    int? categoryId = await _resolveCategoryIdBySyncId(rawCategoryId) ??
        await _resolveCategoryId(
          categoryName: categoryName,
          categoryKind: categoryKind,
        );
    String? categorySyncIdOverride;
    if (categoryId == null &&
        rawCategoryId != null &&
        rawCategoryId.isNotEmpty) {
      final shared = await (db.select(db.sharedLedgerCategories)
            ..where((t) => t.syncId.equals(rawCategoryId)))
          .getSingleOrNull();
      if (shared != null) categorySyncIdOverride = shared.syncId;
    }
    // 查 existing 优先走 LookupCache(prime 时已全表加载 transactions 的
    // syncId / id / createdByUserId),消除 10k 条 = 10k 次 SELECT 的 N+1。
    // miss(冷启动新设备 / 老数据)再走 DB。
    final cachedTx = activePullCache?.transaction(syncId);
    int? existingId = cachedTx?.id;
    String? existingCreatedByUserId = cachedTx?.createdByUserId;
    if (existingId == null && activePullCache == null) {
      final existing = await (db.select(db.transactions)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      existingId = existing?.id;
      existingCreatedByUserId = existing?.createdByUserId;
    }

    // 共享账本:server 注入 createdByUserId / updatedByUserId,本地用来
    // 在 tx 末尾显示"X 记的"。payload 用 camelCase(server snapshot_mutator 出来的
    // 字段是 createdByUserId/updatedByUserId,跟 Drift 列名 createdByUserId /
    // lastEditedByUserId 对齐)。
    final createdByUserId = payload['createdByUserId'] as String?;
    final lastEditedByUserId =
        (payload['updatedByUserId'] as String?) ?? createdByUserId;

    // 账单标记(缺键保留):payload 不含该键 → null → update 走
    // Value.absent() 不覆盖本地;含键(包括显式 false)→ 覆盖。insert 路径
    // null 落默认 false。键名 camelCase 与 server 契约对齐。
    final excludeStats = payload.containsKey('excludeFromStats')
        ? (payload['excludeFromStats'] as bool? ?? false)
        : null;

    // 交易级多币种:payload 带键 → 用 payload 值;缺键(旧 App 的 change,
    // sync_changes 存的是原始 push payload,不经 server merge)→ 快照保护:
    // update 时本地已有折算且 amount 未变 → 保留本地;amount 变了 →
    // 退化 =amount(1:1,可通过当前汇率捞回,好过错值)。
    final hasCurrencyKey = payload.containsKey('currencyCode');
    final hasNativeKey = payload.containsKey('nativeAmount');
    final payloadCurrency =
        hasCurrencyKey ? (payload['currencyCode'] as String?) : null;
    final payloadNative =
        hasNativeKey ? (payload['nativeAmount'] as num?)?.toDouble() : null;

    // AA 分摊字段(缺键保护,对齐 excludeFromStats 模式):
    // payload 不含键 → null → update 走 Value.absent() 不覆盖本地;
    // insert 路径落 null(列默认值)。旧 server/旧客户端下发的 payload 不含
    // AA 键,apply 后本地 AA 字段保持原值/空,兼容性安全。
    final hasPaidByUserIdKey = payload.containsKey('paidByUserId');
    final hasAaModeKey = payload.containsKey('aaMode');
    final hasAaParticipantsKey = payload.containsKey('aaParticipants');
    final hasAaSplitsKey = payload.containsKey('aaSplits');
    final payloadPaidByUserId =
        hasPaidByUserIdKey ? (payload['paidByUserId'] as String?) : null;
    final payloadAaMode =
        hasAaModeKey ? (payload['aaMode'] as int?) : null;
    final payloadAaParticipants =
        hasAaParticipantsKey ? (payload['aaParticipants'] as String?) : null;
    final payloadAaSplits =
        hasAaSplitsKey ? (payload['aaSplits'] as String?) : null;

    if (existingId != null) {
      // 更新 — createdByUserId 走"本地为 null 就回填,否则保持"的策略。
      final shouldBackfillCreator =
          existingCreatedByUserId == null && createdByUserId != null;
      // 快照保护:缺 nativeAmount 键时查本地旧行判断 amount 是否变化。
      d.Value<double?> nativeValue;
      if (hasNativeKey) {
        nativeValue = d.Value(payloadNative);
      } else {
        final oldTx = await (db.select(db.transactions)
              ..where((t) => t.id.equals(existingId!)))
            .getSingleOrNull();
        final oldNative = oldTx?.nativeAmount;
        if (oldNative != null && oldTx!.amount != amount) {
          nativeValue = d.Value(amount); // 旧客户端改了金额 → 退化 1:1
        } else {
          nativeValue = const d.Value.absent(); // 金额未变 → 保留本地折算
        }
      }
      await (db.update(db.transactions)..where((t) => t.id.equals(existingId!)))
          .write(TransactionsCompanion(
        type: d.Value(type),
        amount: d.Value(amount),
        happenedAt: d.Value(happenedAt),
        note: d.Value(note),
        categoryId: d.Value(categoryId),
        categorySyncIdOverride: d.Value(categorySyncIdOverride),
        createdByUserId: shouldBackfillCreator
            ? d.Value(createdByUserId)
            : const d.Value.absent(),
        lastEditedByUserId: d.Value(lastEditedByUserId),
        excludeFromStats: excludeStats == null
            ? const d.Value.absent()
            : d.Value(excludeStats),
        currencyCode: hasCurrencyKey
            ? d.Value(payloadCurrency)
            : const d.Value.absent(), // 缺键保留本地币种
        nativeAmount: nativeValue,
        // AA 字段:缺键走 absent 保留本地,有键(含 null)显式写入。
        paidByUserId: hasPaidByUserIdKey
            ? d.Value(payloadPaidByUserId)
            : const d.Value.absent(),
        aaMode: hasAaModeKey
            ? d.Value(payloadAaMode)
            : const d.Value.absent(),
        aaParticipants: hasAaParticipantsKey
            ? d.Value(payloadAaParticipants)
            : const d.Value.absent(),
        aaSplits: hasAaSplitsKey
            ? d.Value(payloadAaSplits)
            : const d.Value.absent(),
      ));
      logger.debug('SyncEngine', 'pull: 更新交易 $syncId');
    } else {
      // 插入
      final id = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerIdInt,
              type: type,
              amount: amount,
              happenedAt: d.Value(happenedAt),
              note: d.Value(note),
              categoryId: d.Value(categoryId),
              syncId: d.Value(syncId),
              createdByUserId: d.Value(createdByUserId),
              lastEditedByUserId: d.Value(lastEditedByUserId),
              categorySyncIdOverride: d.Value(categorySyncIdOverride),
              excludeFromStats: d.Value(excludeStats ?? false),
              // 缺键的旧 payload:nativeAmount = amount(隐含汇率 1);currencyCode
              // 留 NULL(检测端 LEFT JOIN 账户币种兜底)。
              currencyCode: d.Value(payloadCurrency),
              nativeAmount: d.Value(hasNativeKey ? payloadNative : amount),
              // AA 字段:缺键落 null(列默认值),有键显式写入。
              // 支出人兜底:server 未下发(旧服务端缺键/显式 null)时
              // 默认与创建人一致(创建人由 server 注入),创建人缺失退编辑人,
              // 双缺失落空串(展示层降级"未知"、计算层跳过)。
              paidByUserId: d.Value(payloadPaidByUserId ??
                  createdByUserId ??
                  lastEditedByUserId ??
                  ''),
              aaMode: d.Value(payloadAaMode),
              aaParticipants: d.Value(payloadAaParticipants),
              aaSplits: d.Value(payloadAaSplits),
            ),
          );
      // 写回 cache,后续同 syncId 的 update change 能命中
      activePullCache?.putTransaction(syncId, id, createdByUserId);
      logger.debug('SyncEngine', 'pull: 新增交易 $syncId');
    }
  }

  Future<void> _applyCategoryChange(SpitoutCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      final existing = await (db.select(db.categories)
            ..where((c) => c.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        // 先删子分类再删自身(跟 LocalCategoryRepository 一致)
        await (db.delete(db.categories)
              ..where((c) => c.parentId.equals(existing.id)))
            .go();
        await (db.delete(db.categories)..where((c) => c.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除分类 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final name = payload['name'] as String? ?? '';
    final kind = payload['kind'] as String? ?? 'expense';
    final level = (payload['level'] as num?)?.toInt() ?? 1;
    final sortOrder = (payload['sortOrder'] as num?)?.toInt() ?? 0;
    final icon = payload['icon'] as String?;
    final parentName = payload['parentName'] as String?;
    final parentSyncId = payload['parentSyncId'] as String?;

    // 解析 parentId:优先按 parentSyncId 精确命中(serializer 推送时即携带,
    // 不受父分类重命名/同名影响);miss 再回退 parentName 反查(父行未同步时
    // 用名字兜底)。
    int? parentId;
    if (parentSyncId != null && parentSyncId.isNotEmpty) {
      final parent = await (db.select(db.categories)
            ..where((c) => c.syncId.equals(parentSyncId)))
          .getSingleOrNull();
      parentId = parent?.id;
    }
    if (parentId == null && parentName != null && parentName.isNotEmpty) {
      final parent = await (db.select(db.categories)
            ..where((c) => c.name.equals(parentName))
            ..where((c) => c.kind.equals(kind))
            ..where((c) => c.level.equals(1)))
          .getSingleOrNull();
      parentId = parent?.id;
    }

    var existing = await (db.select(db.categories)
          ..where((c) => c.syncId.equals(syncId)))
        .getSingleOrNull();

    // Fallback：syncId 查不到 → 本地可能是 seed 默认分类（syncId 为 NULL）。
    // 按 name + kind 匹配 NULL syncId 行，把 syncId 补上。避免 device B 首次
    // pull 远端分类插第二份同名 seed。
    //
    // 注意：默认 seed 允许跨父级同名二级分类(如「购物>鞋子」「服装>鞋子」)、
    // 以及一级/二级同名(如「服装」父 vs「购物>服装」子)，name+kind 可能命中
    // 多行 → 不能用 getSingleOrNull(命中多行会抛 StateError)。这里额外用
    // level + parentId 收窄到唯一行；仍多行时取 id 最小者，保证行为确定。
    //
    // 不可整段删除：种子默认分类首启时 syncId=null，若删掉此收编分支，
    // device B 首次 pull 远端同 entity 的 change 时会按 syncId 查不到 →
    // 走 insert 分支 → 数据库出现两份同名 seed（一份 syncId=null 一份有 syncId），
    // 这是真实的同步 BUG。此处保留是为多设备首次同步的种子收编路径。
    if (existing == null && name.isNotEmpty) {
      // 二级分类但父级未拉到（parentName 缺失或本地无此父行）时跳过收编：
      // 此时只能按 level=2 + name + kind 收窄，可能命中多个跨父同名二级 seed
      // 行，取最小 id 会错收编。正常路径下种子带确定性 syncId（走 syncId 直查
      // 命中），不会进到此分支；进入此分支说明远端 payload 缺 parentName 或
      // 父行尚未同步下来，让本 change 走 insert 兜底比错收编更安全。
      if (level == 2 && parentId == null) {
        logger.warning('SyncEngine',
            'pull: 二级分类 name="$name" kind=$kind parentName="$parentName" 未解析到 parentId，跳过 seed 收编走 insert 兜底');
      } else {
        final seededQuery = db.select(db.categories)
          ..where((c) => c.name.equals(name))
          ..where((c) => c.kind.equals(kind))
          ..where((c) => c.syncId.isNull())
          ..where((c) => c.level.equals(level));
        // 二级分类按解析出的 parentId 进一步收窄；一级分类要求 parentId 为空
        if (level == 2 && parentId != null) {
          final pid = parentId;
          seededQuery.where((c) => c.parentId.equals(pid));
        } else if (level == 1) {
          seededQuery.where((c) => c.parentId.isNull());
        }
        final seededRows = await seededQuery.get();
        Category? seeded;
        if (seededRows.isNotEmpty) {
          seededRows.sort((a, b) => a.id.compareTo(b.id));
          seeded = seededRows.first;
          if (seededRows.length > 1) {
            logger.warning('SyncEngine',
                'pull: seed 收编按名命中多行 name="$name" kind=$kind level=$level, 取 id=${seeded.id}');
          }
        }
        if (seeded != null) {
          final seededId = seeded.id; // 提取非 nullable 局部变量,绕过闭包内类型提升失效
          await (db.update(db.categories)..where((c) => c.id.equals(seededId)))
              .write(CategoriesCompanion(syncId: d.Value(syncId)));
          existing = seeded;
          logger.info('SyncEngine',
              'pull: 收编本地 seed 分类 name="$name" kind=$kind → syncId=$syncId');
        }
      }
    }

    int? localCategoryId;
    if (existing != null) {
      localCategoryId = existing.id;
      await (db.update(db.categories)
            ..where((c) => c.id.equals(localCategoryId!)))
          .write(CategoriesCompanion(
        name: d.Value(name),
        kind: d.Value(kind),
        level: d.Value(level),
        sortOrder: d.Value(sortOrder),
        icon: d.Value(icon),
        parentId: d.Value(parentId),
      ));
      logger.debug('SyncEngine', 'pull: 更新分类 $syncId');
    } else {
      localCategoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: name,
              kind: kind,
              level: d.Value(level),
              sortOrder: d.Value(sortOrder),
              icon: d.Value(icon),
              parentId: d.Value(parentId),
              syncId: d.Value(syncId),
            ),
          );
      activePullCache?.putCategory(syncId, localCategoryId);
      logger.debug('SyncEngine', 'pull: 新增分类 $syncId');
    }

    // 登记"已从 server 拉到本地"标记。
    await changeTracker.recordPulledFromServer(
      entityType: 'category',
      entityId: localCategoryId,
      entitySyncId: syncId,
      ledgerId: 0,
    );
  }

  /// 按币对收敛:双端离线各建同币对会产生两个 syncId,按 syncId insert 会撞
  /// idx_rate_override_pair 唯一索引;按币对 upsert + 吸收来包 syncId/updatedAt
  /// 实现收敛。
  ///
  /// 按币对收敛 + 依赖 pull 的 change_id 递增顺序实现 LWW(updatedAt 仅落库,
  /// 不参与决胜 —— 不要加 "incoming.updatedAt < existing.updatedAt 则跳过" 的
  /// 守卫,那会破坏 replayAllChanges 从 since=0 的重放)。
  ///
  /// apply 直写 db,不走 repo → 不记 change,防反向 push。
  Future<void> _applyExchangeRateOverrideChange(
      SpitoutCloudSyncChange change) async {
    if (change.action == 'delete') {
      // delete 按 syncId 精确匹配:币对收敛把行的 syncId 换成新值后,
      // 针对旧 syncId 的 delete 是有意的 no-op(该币对已有更新的 override 存活)。
      await (db.delete(db.exchangeRateOverrides)
            ..where((t) => t.syncId.equals(change.entitySyncId)))
          .go();
      return;
    }
    final p = change.payload!;
    final base = (p['baseCurrency'] as String?)?.toUpperCase();
    final quote = (p['quoteCurrency'] as String?)?.toUpperCase();
    final rate = p['rate']?.toString();
    if (base == null || quote == null || rate == null || rate.isEmpty) {
      logger.warning('SyncEngine', 'exchange_rate_override payload 缺字段,跳过');
      return;
    }
    final updatedAt = DateTime.tryParse(p['updatedAt']?.toString() ?? '');
    final existing = await (db.select(db.exchangeRateOverrides)
          ..where((t) =>
              t.baseCurrency.equals(base) & t.quoteCurrency.equals(quote)))
        .getSingleOrNull();
    if (existing == null) {
      await db
          .into(db.exchangeRateOverrides)
          .insert(ExchangeRateOverridesCompanion.insert(
            baseCurrency: base,
            quoteCurrency: quote,
            rate: rate,
            syncId: d.Value(change.entitySyncId),
            updatedAt: d.Value(updatedAt),
          ));
    } else {
      await (db.update(db.exchangeRateOverrides)
            ..where((t) => t.id.equals(existing.id)))
          .write(ExchangeRateOverridesCompanion(
        rate: d.Value(rate),
        syncId: d.Value(change.entitySyncId),
        updatedAt: d.Value(updatedAt),
      ));
    }
  }

  /// 应用远程下发的账本元数据变更(名字 / 币种)。
  ///
  /// 跟其他 entity 不同:不在本地"新建"账本 —— 账本的创建走 fullPush /
  /// ledger_snapshot 路径。这里只负责"已存在的账本"的 meta 更新。找不到
  /// 对应的本地账本就跳过,等快照路径把它 seed 出来后再复用。
  Future<void> _applyLedgerChange(SpitoutCloudSyncChange change) async {
    final syncId = change.entitySyncId;
    if (change.action == 'delete') {
      // 账本删除走 'ledger_snapshot' 的 delete change,这里不处理 —— 避免
      // 跟 ledger_snapshot 重复触发。
      return;
    }
    final payload = change.payload;
    if (payload == null) return;

    // 用 get() 不用 getSingleOrNull():dup ledger 同
    // syncId 可能导致 getSingleOrNull 撞多行抛 "Too many elements" 中断 replay。
    // 取第一行 + 清剩余 dup。
    final ledgerList = await (db.select(db.ledgers)
          ..where((l) => l.syncId.equals(syncId)))
        .get();
    final name = payload['ledgerName'] as String?;
    final currency = payload['currency'] as String?;
    // bool 不是 num,as num? 天然挡掉;越界 clamp。key 缺失 → null →
    // update 路径 Value.absent 不动原值(老 server payload 兼容)。
    final monthStartDay =
        ((payload['monthStartDay'] as num?)?.toInt())?.clamp(1, 28);
    // AA 分摊开关(缺键保护):payload 不含键 → null → update 走 absent
    // 保留本地;含键(包括显式 false)→ 覆盖。与 name/currency 模式一致。
    final aaEnabledKey = payload.containsKey('aaEnabled');
    final payloadAaEnabled = aaEnabledKey
        ? (payload['aaEnabled'] as bool? ?? false)
        : null;
    if (ledgerList.isEmpty) {
      // 本地未就绪时,若 payload 至少有 name + currency,主动 insert 一行本地
      // ledger,避免 web 端新建账本后 app 拉到 ledger change 却不落库。
      // payload 缺关键字段时仍 skip(等下次 syncLedgersFromServer 或 snapshot
      // 拉到完整 meta)。
      if (name == null || name.isEmpty) {
        logger.info('SyncEngine',
            'pull: 账本 $syncId 本地未就绪 + payload 无 name,跳过(等 snapshot)');
        return;
      }
      // insert 必须给值:payload 缺 key 时取列默认 1(与 update 路径的
      // absent 语义不同 —— 新建行没有"原值"可保)。
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
            name: name,
            currency: d.Value(currency ?? 'CNY'),
            syncId: d.Value(syncId),
            monthStartDay: d.Value(monthStartDay ?? 1),
            // aaEnabled 缺键落默认 false;有键显式写入。
            aaEnabled: d.Value(payloadAaEnabled ?? false),
          ));
      logger.info('SyncEngine',
          'pull: 新增账本 syncId=$syncId name=$name currency=${currency ?? "CNY"} aaEnabled=${payloadAaEnabled ?? false}');
      activePullCache?.putLedger(
          syncId,
          (await (db.select(db.ledgers)..where((l) => l.syncId.equals(syncId)))
                  .getSingle())
              .id);
      return;
    }
    final ledger = ledgerList.first;
    if (ledgerList.length > 1) {
      final dupIds = ledgerList.skip(1).map((l) => l.id).toList();
      logger.warning('SyncEngine',
          'pull: ledger.syncId=$syncId 撞多行 ${ledgerList.length},清除 dup id=$dupIds');
      await (db.delete(db.transactions)..where((t) => t.ledgerId.isIn(dupIds)))
          .go();
      await (db.delete(db.localChanges)..where((c) => c.ledgerId.isIn(dupIds)))
          .go();
      await (db.delete(db.ledgers)..where((l) => l.id.isIn(dupIds))).go();
    }

    final comp = LedgersCompanion(
      name: name != null ? d.Value(name) : const d.Value.absent(),
      currency: currency != null ? d.Value(currency) : const d.Value.absent(),
      monthStartDay: monthStartDay != null
          ? d.Value(monthStartDay)
          : const d.Value.absent(),
      // aaEnabled:缺键 absent 保留本地;有键(含 false)显式覆盖。
      // payloadAaEnabled 已在解析时 `?? false` 兜底,此处非 null。
      aaEnabled: aaEnabledKey
          ? d.Value(payloadAaEnabled!)
          : const d.Value.absent(),
    );
    await (db.update(db.ledgers)..where((l) => l.id.equals(ledger.id)))
        .write(comp);
    logger.debug(
        'SyncEngine', 'pull: 更新账本 $syncId name=$name currency=$currency aaEnabled=$payloadAaEnabled');

    // 云同步拉取到币种变更时全量重算 nativeAmount，
    // 否则多设备场景下其他设备拉到的交易 nativeAmount 仍是旧币种口径。
    if (currency != null) {
      await repo.recalcNativeAmountsForLedger(ledger.id, currency);
    }
  }

  /// 应用远程下发的虚拟用户变更(create/update/delete)。
  ///
  /// 虚拟用户是 ledger-scoped 实体(与 transaction 同通道),change log 走
  /// create/update/delete 三类 action。删除走硬删(对齐 ledger_snapshot:delete
  /// 模式),server 按 entity_sync_id 删投影。
  ///
  /// 缺键保护:payload 缺 name 键时 update 走 absent 保留本地。
  Future<void> _applyVirtualUserChange(SpitoutCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      // 硬删:按 syncId 删本地行(对齐 transaction:delete 模式)。
      // syncId 未匹配是 no-op(可能本地从未拉到此虚拟用户,或已被本地删)。
      await (db.delete(db.ledgerVirtualUsers)
            ..where((t) => t.syncId.equals(syncId)))
          .go();
      logger.debug('SyncEngine', 'pull: 删除虚拟用户 $syncId');
      return;
    }

    // upsert(create/update 同走 upsert 语义)
    final payload = change.payload!;
    final name = payload['name'] as String?;

    // 解析 ledgerId:change.ledgerId 是 server 的 external_id(string),
    // 本地 auto-increment int id 不一致,按 syncId 查本地 int id。
    final ledgerIdInt = await _resolveLedgerIdBySyncId(change.ledgerId) ??
        int.tryParse(change.ledgerId) ??
        -1;
    if (ledgerIdInt <= 0) {
      logger.warning('SyncEngine',
          'pull: 虚拟用户 $syncId 解析 ledgerId 失败(${change.ledgerId}),跳过');
      return;
    }

    // 查 existing:按 syncId 精确匹配
    final existing = syncId.isEmpty
        ? null
        : await (db.select(db.ledgerVirtualUsers)
              ..where((t) => t.syncId.equals(syncId)))
            .getSingleOrNull();

    if (existing != null) {
      // 更新:name 缺键走 absent 保留本地(缺键保护)。
      await (db.update(db.ledgerVirtualUsers)
            ..where((t) => t.id.equals(existing.id)))
          .write(LedgerVirtualUsersCompanion(
        name: name != null ? d.Value(name) : const d.Value.absent(),
        updatedAt: d.Value(DateTime.now()),
      ));
      logger.debug('SyncEngine', 'pull: 更新虚拟用户 $syncId name=$name');
    } else {
      // 插入:name 必须有值,缺则用空串兜底(列 notNull 约束)。
      await db.into(db.ledgerVirtualUsers).insert(
            LedgerVirtualUsersCompanion.insert(
              ledgerId: ledgerIdInt,
              syncId: d.Value(syncId),
              name: name ?? '',
            ),
          );
      logger.debug('SyncEngine', 'pull: 新增虚拟用户 $syncId name=$name');
    }
  }

}
