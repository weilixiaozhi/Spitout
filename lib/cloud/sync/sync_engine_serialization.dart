part of 'sync_engine.dart';

/// push 路径上把本地实体序列化成 server payload 的逻辑。
///
/// 包括:
/// - `_serializeEntityForPush`: 增量 push,按 entity_type 序列化单个实体
/// - `_pushAllEntities`: fullPush 路径,一次批量序列化全部实体
/// - `_exportLedgerJson`: 生成完整 ledger JSON snapshot
///
/// 所有方法都是 private,只在 library 内被 `_push` / `fullPush` 调用,所以
/// extension 保持 private。
extension SyncEngineSerializationExt on SyncEngine {
  /// 从 DB 读取实体并序列化为 push payload
  Future<Map<String, dynamic>> _serializeEntityForPush({
    required String entityType,
    required int entityId,
    required int ledgerId,
  }) async {
    // 取父 ledger 的 syncId，下面 serialize 时塞进 tx payload。对端
    // apply 先用 payload.ledgerSyncId 解析本地 ledger id，跨设备的 int id
    // 不一致问题（如 A 的账本 2 = B 的账本 3）才不会把 tx 错挂到别处。
    final parentLedger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final parentLedgerSyncId = parentLedger?.syncId;

    switch (entityType) {
      case 'transaction':
        final tx = await (db.select(db.transactions)
              ..where((t) => t.id.equals(entityId)))
            .getSingleOrNull();
        if (tx == null) return <String, dynamic>{};

        // 获取关联数据
        final cat = tx.categoryId != null
            ? await (db.select(db.categories)
                  ..where((c) => c.id.equals(tx.categoryId!)))
                .getSingleOrNull()
            : null;
        // 共享账本:tx 有 *SyncIdOverride 字段时(Editor 在共享账本下
        // 记的 tx),override 优先 — push 给 server 的 categoryId 走 override
        // (Owner 的 syncId)。同时反查 SharedLedgerCategories 拿 name/kind
        // 用作 denormalized 文本(server LWW 名字字段)。
        String? finalCategorySyncId = tx.categorySyncIdOverride;
        String? finalCategoryName = cat?.name;
        String? finalCategoryKind = cat?.kind;
        if (finalCategorySyncId != null && finalCategorySyncId.isNotEmpty) {
          final shared = await (db.select(db.sharedLedgerCategories)
                ..where((t) => t.syncId.equals(finalCategorySyncId!)))
              .getSingleOrNull();
          if (shared != null) {
            finalCategoryName = shared.name;
            finalCategoryKind = shared.kind;
          }
        } else {
          finalCategorySyncId = cat?.syncId;
        }

        return EntitySerializer.serializeTransaction(
          tx,
          categoryName: finalCategoryName,
          categoryKind: finalCategoryKind,
          categorySyncId: finalCategorySyncId,
          ledgerSyncId: parentLedgerSyncId,
        );

      case 'exchange_rate_override':
        // 按 entityId 反查行,跟 account 分支同款;行已删(delete change)
        // 返回空 payload(delete 路径 server 只看 action,不读 payload)。
        // server 端 projection.upsert_exchange_rate_override 对缺字段静默 return
        // （防御分支：缺字段时 server 端静默 return），空 payload upsert 无害。
        final override = await (db.select(db.exchangeRateOverrides)
              ..where((o) => o.id.equals(entityId)))
            .getSingleOrNull();
        if (override == null) return <String, dynamic>{};
        return EntitySerializer.serializeExchangeRateOverride(override);

      case 'category':
        final category = await (db.select(db.categories)
              ..where((c) => c.id.equals(entityId)))
            .getSingleOrNull();
        if (category == null) return <String, dynamic>{};
        String? parentName;
        String? parentSyncId;
        if (category.parentId != null) {
          final parent = await (db.select(db.categories)
                ..where((c) => c.id.equals(category.parentId!)))
              .getSingleOrNull();
          parentName = parent?.name;
          parentSyncId = parent?.syncId;
        }
        return EntitySerializer.serializeCategory(
          category,
          parentName: parentName,
          parentSyncId: parentSyncId,
        );

      // 无 tag/budget 表,对应 entity_type 不会产生 changes。

      case 'ledger':
        // 账本元数据(名字 / 币种 / AA 开关)。entityId 是本地 int id,取出后按 syncId
        // 推送,server materialize 时更新 `ledger_snapshot.ledgerName/currency`
        // + `Ledger` 自身,web 下次 read 就拿到新名字。
        final ledger = await (db.select(db.ledgers)
              ..where((l) => l.id.equals(entityId)))
            .getSingleOrNull();
        if (ledger == null || ledger.syncId == null || ledger.syncId!.isEmpty) {
          return <String, dynamic>{};
        }
        return EntitySerializer.serializeLedger(ledger);

      case 'virtual_user':
        // 虚拟用户:ledger-scoped 实体,按 entityId 查本地行,按 syncId 推送。
        // 行已删(delete change)时返回空 payload,delete 路径 server 只看 action。
        final virtualUser = await (db.select(db.ledgerVirtualUsers)
              ..where((u) => u.id.equals(entityId)))
            .getSingleOrNull();
        if (virtualUser == null) return <String, dynamic>{};
        return EntitySerializer.serializeVirtualUser(virtualUser);

      default:
        return <String, dynamic>{};
    }
  }

  // 跨设备 ID 解析方法搬到 sync_engine_resolvers.dart 这个 part 文件:
  //   _resolveLedgerIdBySyncId / _resolveCategoryIdBySyncId
  //   _resolveCategoryId / _getDeviceId

  // ==================== 全量推送/拉取 ====================

  /// 首次全量推送(将本地所有数据推送到服务端)。
  ///
  /// **in-flight 单飞**:同 ledger 的并发调用复用第一个 future,避免 sync_changes
  /// 表膨胀。
  Future<void> fullPush({required int ledgerId, bool force = false}) async {
    // moveToLocal 中止检查(放在闸门/查库之前):该账本正处于 moveToLocal 窗口时
    // 直接 return,不查库、不建 completer。命中即返回,对 waitFullPushSettle 而言
    // 与「completer.complete() 后被移除」等效(读不到 in-flight → 立即返回),
    // 放在最前面可省掉一次闸门查库开销。
    if (_moveToLocalAbortRequests.contains(ledgerId)) {
      logger.info('SyncEngine', 'fullPush 命中 moveToLocal 中止信号,跳过 ledger=$ledgerId');
      return;
    }
    // 闸门:纯本地账本(storage_mode == 'local')不执行全量推送,从源头杜绝
    // 本地数据被误传到云端。双重保险:sync() 入口也有同款闸门。
    // force=true 仅用于 moveToCloud 主动移动场景:账本尚为 local 但用户已显式
    // 意图上云,需绕过闸门强制推送;推送成功并经 readLedgers 确认云端存在后,
    // moveToCloud 才翻 mode(确认失败则账本保持 local,无副作用)。
    if (!force) {
      final ledger = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingleOrNull();
      // 闸门判定统一走 ledger_kind.dart 的 isLocalLedger(显式 local + 非共享),
      // 与 sync() / ChangeTracker 三处闸门语义保持一致。
      if (ledger == null || ledger.isLocalLedger) {
        logger.info('SyncEngine', 'fullPush 跳过本地账本 ledger=$ledgerId');
        return;
      }
    }
    final inFlight = _fullPushInFlight[ledgerId];
    if (inFlight != null) {
      logger.info('SyncEngine', 'fullPush(ledger=$ledgerId) 已在执行,复用 in-flight');
      return inFlight.future;
    }
    final completer = Completer<void>();
    completer.future.ignore(); // 防 unhandled async error
    _fullPushInFlight[ledgerId] = completer;
    try {
      await _doFullPush(ledgerId: ledgerId);
      completer.complete();
    } on FullPushAborted {
      // 被 moveToLocal 主动中止:这是中性终结而非失败。complete() 正常完成
      // (不 completeError),让 waitFullPushSettle 视为已收敛;不 rethrow,
      // 避免上层同步链把「主动中止」当真实错误上报。
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_fullPushInFlight[ledgerId] == completer) {
        _fullPushInFlight.remove(ledgerId);
      }
    }
  }

  Future<void> _doFullPush({required int ledgerId}) async {
    logger.info('SyncEngine', '开始全量推送 ledger=$ledgerId');

    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingle();
    final pathForSnapshot = ledger.syncId ?? ledger.id.toString();

    // 0. 先用专用的 writeCreateLedger API(POST /write/ledgers)显式带 currency
    //    创建 server 端账本:storage.upload 触发 server auto-create 时不读
    //    metadata 的 currency、fallback 到默认 CNY;后续的 ledger:upsert
    //    change 在某些 server 实现下也只更新已存在 ledger,不能改它的 currency。
    //    用 dedicated API 显式声明 ledger_id + ledger_name + currency,server
    //    能正确建账本。
    //    幂等性:如果账本已存在(例如老数据 / 重试),server 会返回 409 或类似错误,
    //    这里 try/catch 吞掉,不阻塞后续 storage.upload + _pushAllEntities。
    //
    // moveToLocal 中止检查(检查点 1)。**必须放在下面 try 之外**:writeCreateLedger
    // 的 try/catch 会吞掉一切异常(含 FullPushAborted),放 try 内则中止信号被吞、
    // 流程照常往下写 S1,起不到中止作用。
    if (_moveToLocalAbortRequests.contains(ledgerId)) throw const FullPushAborted();
    try {
      await provider.writeCreateLedger(
        ledgerId: pathForSnapshot,
        ledgerName: ledger.name,
        currency: ledger.currency,
      );
      logger.info('SyncEngine',
          'writeCreateLedger 成功: ledgerId=$pathForSnapshot, name=${ledger.name}, currency=${ledger.currency}');
    } catch (e, st) {
      // 已存在 / 其他错误都不阻断流程,后续 storage.upload + _pushAllEntities
      // 仍会跑,部分 server 实现会从这两条路径 auto-create / 修正 meta。
      logger.warning('SyncEngine',
          'writeCreateLedger 失败（已存在或其他原因,继续走 storage 上传）: $e', st);
    }

    // 1. 上传 JSON 快照
    //    path 用 ledger.syncId，跟 _pushAllEntities 的 ledger_id 一致，
    //    避免 server 出现两条 external_id 指向同一账本的分裂。
    //
    // moveToLocal 中止检查(检查点 2)。**必须放在下面 try 之外**:storage.upload
    // 的 try/catch 只 log 不 rethrow,放 try 内 FullPushAborted 会被吞掉,流程继续
    // 写 S1 快照。
    if (_moveToLocalAbortRequests.contains(ledgerId)) throw const FullPushAborted();
    try {
      final jsonData = await _exportLedgerJson(ledger);
      await provider.storage.upload(
        path: pathForSnapshot,
        data: jsonData,
        metadata: {
          'ledger_name': ledger.name,
          'currency': ledger.currency,
          'type': 'full_push',
        },
      );
      logger.info('SyncEngine', 'JSON 快照上传成功');
    } catch (e, st) {
      logger.error('SyncEngine', 'JSON 快照上传失败（继续推送个体变更）', e, st);
    }

    // 2. 推送所有实体的个体变更（用于 Web 端和增量同步）
    await _pushAllEntities(ledger);

    // 标记本次 fullPush 已经覆盖的变更为已推送。
    //
    // 关键:**只 mark 非 delete change**。`_pushAllEntities` 是从当前 DB
    // 实体 build syncChanges,只会 upsert 当前还存在的行;对应 delete change
    // 的实体已经被本地删掉、不在当前 DB 里、不在 _pushAllEntities 的输出里,
    // 所以 server 没收到 delete 操作,canonical state 还保留旧数据。
    //
    // delete change 留作未推送,sync() 在 fullPush 之后会再调一次 _push
    // 把它们推上去 + markPushed;若一并 markPushed,server 永远收不到删除
    // (典型症状:用户清空账本后 remote 还显示旧记录)。
    final unpushed = await changeTracker.getUnpushedChangesForLedger(ledgerId);
    final nonDeletes = unpushed.where((c) => c.action != 'delete').toList();
    if (nonDeletes.isNotEmpty) {
      await changeTracker.markPushed(nonDeletes.map((c) => c.id).toList());
    }

    logger.info('SyncEngine',
        '全量推送完成 ledger=${ledger.name},markPushed ${nonDeletes.length}/${unpushed.length}(剩余 delete change 留给 _push)');
  }

  /// 推送所有实体为个体变更(fullPush 时调用)。
  ///
  /// **只处理 ledger-scope 实体**(ledger / transaction)。user-global
  /// 实体(category)由调用方通过 [pushUserGlobalEntities] 统一
  /// 推送 — 本函数入口处会调它一次,跨 ledger 并发的 fullPush 共享同一份
  /// user-global push,避免重复。
  Future<void> _pushAllEntities(Ledger ledger) async {
    // 1) 先推 user-global(单飞,多账本并行 fullPush 时共享同一次推送)
    await pushUserGlobalEntities();

    // 2) 再处理本 ledger 的 ledger-scope 推送
    // 跟增量 _push 保持一致:用 ledger.syncId 作为 server 认的 external_id,
    // 跨设备时同一账本永远同一个 external_id,不会分裂成多条。
    final ledgerId = ledger.syncId ?? ledger.id.toString();
    final now = DateTime.now().toUtc().toIso8601String();
    final syncChanges = <Map<String, dynamic>>[];

    // 推一条 ledger:upsert,显式带 ledgerName + currency。否则:
    //   - storage.upload 的 metadata 虽然带了 currency,但 server 端 auto-create
    //     ledger 时不一定从 metadata 读 currency(字段名可能对不上,或默认走 CNY)
    //   - 结果:用户在 app 选 JPY 创建账本,server 端 canonical state 是 CNY
    // 推一条显式的 ledger upsert 可以兜底,server 收到后用 payload 里的 currency
    // 覆盖默认值。
    syncChanges.add({
      'ledger_id': ledgerId,
      'entity_type': 'ledger',
      'entity_sync_id': ledgerId,
      'action': 'upsert',
      'payload': EntitySerializer.serializeLedger(ledger),
      'updated_at': now,
    });

    // tx push 需要查类目的 syncId 做 denormalize 用。
    final categories = await db.select(db.categories).get();

    // 交易
    final transactions = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledger.id)))
        .get();

    for (final tx in transactions) {
      final syncId = tx.syncId ?? _uuid.v4();
      if (tx.syncId == null) {
        await (db.update(db.transactions)..where((t) => t.id.equals(tx.id)))
            .write(TransactionsCompanion(syncId: d.Value(syncId)));
      }

      final cat = tx.categoryId != null
          ? categories
              .cast<Category?>()
              .firstWhere((c) => c?.id == tx.categoryId, orElse: () => null)
          : null;

      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'transaction',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeTransaction(
          tx,
          categoryName: cat?.name,
          categoryKind: cat?.kind,
          categorySyncId: cat?.syncId,
          ledgerSyncId: ledger.syncId,
        ),
        'updated_at': now,
      });
    }

    // 统计实体数量
    final categoryCount = categories.length;
    final txCount = transactions.length;

    // 虚拟用户:ledger-scoped 实体,随本账本一起 fullPush。
    // syncId 缺失的本地行需先生成 syncId 再推送(与 tx 同模式)。
    final virtualUsers = await (db.select(db.ledgerVirtualUsers)
          ..where((u) => u.ledgerId.equals(ledger.id))
          ..orderBy([(u) => d.OrderingTerm.asc(u.id)]))
        .get();
    for (final vu in virtualUsers) {
      final vuSyncId = vu.syncId ?? _uuid.v4();
      if (vu.syncId == null) {
        await (db.update(db.ledgerVirtualUsers)
              ..where((u) => u.id.equals(vu.id)))
            .write(LedgerVirtualUsersCompanion(syncId: d.Value(vuSyncId)));
      }
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'virtual_user',
        'entity_sync_id': vuSyncId,
        'action': 'upsert',
        'payload': {
          'syncId': vuSyncId,
          'name': vu.name,
        },
        'updated_at': now,
      });
    }

    logger.info(
        'SyncEngine',
        '开始推送个体变更 共${syncChanges.length}条 '
            '(categories=$categoryCount, transactions=$txCount, virtualUsers=${virtualUsers.length})');

    // 分批推送:每条 change 平均 ~500 字节,500 条 ≈ 250KB,远低于网关限制,
    // 但单次请求内 server 事务处理时间 ~100ms 可接受;3 万条交易仅 60 批。
    const batchSize = 500;
    for (var i = 0; i < syncChanges.length; i += batchSize) {
      final end = (i + batchSize > syncChanges.length)
          ? syncChanges.length
          : i + batchSize;
      final batch = syncChanges.sublist(i, end);
      // moveToLocal 中止检查(检查点 3,批次循环内每批推送前)。**必须放在下面
      // try 之外**:批次推送的 try/catch 会 rethrow 普通错误,但为避免 FullPushAborted
      // 被误当「批次推送失败」记 error 日志再 rethrow(语义混淆),这里在 try 前先拦。
      if (_moveToLocalAbortRequests.contains(ledger.id)) throw const FullPushAborted();
      try {
        logger.info('SyncEngine',
            '推送批次 ${i ~/ batchSize + 1}: ${batch.length}条 (${i + 1}-$end)');
        await provider.pushChanges(changes: batch);
        logger.info('SyncEngine', '批次 ${i ~/ batchSize + 1} 推送成功');
      } catch (e, st) {
        logger.error('SyncEngine', '批次 ${i ~/ batchSize + 1} 推送失败', e, st);
        rethrow; // 让调用方知道失败
      }
    }

    logger.info('SyncEngine', '全量推送个体变更完成 ${syncChanges.length} 条');
  }

  Future<String> _exportLedgerJson(Ledger ledger) async {
    final transactions = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledger.id))
          ..orderBy([(t) => d.OrderingTerm.asc(t.happenedAt)]))
        .get();

    final categories = await db.select(db.categories).get();

    final items = <Map<String, dynamic>>[];
    for (final tx in transactions) {
      final cat = tx.categoryId != null
          ? categories
              .cast<Category?>()
              .firstWhere((c) => c?.id == tx.categoryId, orElse: () => null)
          : null;

      items.add(EntitySerializer.serializeTransaction(
        tx,
        categoryName: cat?.name,
        categoryKind: cat?.kind,
        categorySyncId: cat?.syncId,
        ledgerSyncId: ledger.syncId,
      ));
    }

    // 虚拟用户:随快照导出,否则对端导入后指定分摊数据会悬空。
    final virtualUsers = await (db.select(db.ledgerVirtualUsers)
          ..where((u) => u.ledgerId.equals(ledger.id))
          ..orderBy([(u) => d.OrderingTerm.asc(u.id)]))
        .get();
    final virtualUserItems = virtualUsers
        .map((u) => EntitySerializer.serializeVirtualUser(u))
        .toList();

    return jsonEncode({
      'version': 6,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'ledgerId': ledger.id,
      'ledgerName': ledger.name,
      'currency': ledger.currency,
      'monthStartDay': ledger.monthStartDay,
      'aaEnabled': ledger.aaEnabled,
      'count': items.length,
      'categories': categories.map((c) {
        String? parentName;
        String? parentSyncId;
        if (c.parentId != null) {
          final parent = categories
              .cast<Category?>()
              .firstWhere((p) => p?.id == c.parentId, orElse: () => null);
          parentName = parent?.name;
          parentSyncId = parent?.syncId;
        }
        return EntitySerializer.serializeCategory(c,
            parentName: parentName, parentSyncId: parentSyncId);
      }).toList(),
      'items': items,
      'virtualUsers': virtualUserItems,
    });
  }
}
