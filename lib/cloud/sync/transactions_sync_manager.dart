import 'dart:convert';

import 'package:crypto/crypto.dart';
// 仅为 drift 的聚合扩展方法(.max())提供作用域,勿删。
import 'package:drift/drift.dart' as drift;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' as fcs;

import '../../data/db.dart';
import '../../data/models/ledger_kind.dart';
import '../../data/repositories/base_repository.dart';
import '../../core/logging/logger_service.dart';
import 'sync_diff_service.dart';
import 'sync_service.dart';
import 'transactions_json.dart';

/// 账本交易的云同步管理器
///
/// 使用 flutter_cloud_sync 包实现云同步，保留 Spitout 特定的业务逻辑
class TransactionsSyncManager implements SyncService {
  final fcs.CloudServiceConfig config;
  final SpitoutDatabase db;
  final BaseRepository repo;

  fcs.CloudSyncManager<int>? _syncManager;
  fcs.CloudProvider? _provider;
  bool _isInitializing = false;
  bool _isInitialized = false;

  final Map<int, SyncStatus> _statusCache = {};
  final Map<int, DateTime> _recentLocalChangeAt = {};
  final Map<int, _RecentUpload> _recentUpload = {};

  TransactionsSyncManager({
    required this.config,
    required this.db,
    required this.repo,
  });

  @override
  void clearStatusCache({int? ledgerId}) {
    if (ledgerId != null) {
      _statusCache.remove(ledgerId);
    } else {
      _statusCache.clear();
    }
  }

  // 账本归属移动操作(moveToCloud/moveToLocal/copyToLocal)由 SyncEngine
  // (SpitoutCloud 主路径)完整实现。本快照同步实现仅用于非 SpitoutCloud 后端,
  // 暂不支持账本移动,显式抛错以便 UI 明确区分能力边界。
  @override
  Future<void> moveToCloud(int ledgerId) async {
    throw UnsupportedError('账本移动操作仅 SpitoutCloud(SyncEngine) 支持');
  }

  @override
  Future<void> moveToLocal(int ledgerId) async {
    throw UnsupportedError('账本移动操作仅 SpitoutCloud(SyncEngine) 支持');
  }

  @override
  Future<int> copyToLocal(int sourceLedgerId) async {
    throw UnsupportedError('账本复制操作仅 SpitoutCloud(SyncEngine) 支持');
  }

  /// 确保服务已初始化（延迟初始化）
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      // 等待初始化完成
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _isInitializing = true;
    try {
      await _initialize();
      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }

  /// 初始化 CloudProvider 和 SyncManager
  Future<void> _initialize() async {
    final services = await fcs.createCloudServices(config);
    _provider = services.provider;

    if (_provider == null) {
      // Provider 创建失败，标记为已初始化但无法使用
      logger.warning('CloudSync', 'Provider not available for ${config.type}');
      return;
    }

    _syncManager = fcs.CloudSyncManager<int>(
      provider: _provider!,
      serializer: _TransactionSerializer(db),
      logger: fcs.CloudSyncLogger(onLog: (level, message) {
        switch (level) {
          case fcs.LogLevel.debug:
            logger.info('CloudSync', message);
            break;
          case fcs.LogLevel.info:
            logger.info('CloudSync', message);
            break;
          case fcs.LogLevel.warning:
            logger.warning('CloudSync', message);
            break;
          case fcs.LogLevel.error:
            logger.error('CloudSync', message);
            break;
        }
      }),
    );
  }

  /// 纯本地账本(storage_mode='local' 且非共享)不参与任何云端拉取。
  ///
  /// 快照型后端同样要遵守归属闸门:本地账本刷新/状态查询不能发起远端下载,
  /// 否则坏网络时会把首页下拉刷新等主流程卡在 loading。
  Future<bool> _isLocalOnlyLedger(int ledgerId) async {
    final row = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    // 与 SyncEngine.sync() 的闸门一致:storage_mode='local' 且非共享的账本
    // 不上云,即使异常中间态残留了 syncId 也不应发起快照下载。
    return row != null && row.isLocalLedger;
  }

  String _pathForLedger(int ledgerId) {
    return 'ledger_$ledgerId.json';
  }

  /// 本地最大发生时间（用于 flutter_cloud_sync 的方向判断）。
  /// 取 `max(最近本地写入时间, SELECT MAX(happened_at) WHERE ledger=...)`。
  /// cold start 时 _recentLocalChangeAt 为 null,仅靠 count 判断方向不可靠 ——
  /// 两台设备交易条数相同、内容不同时,count 无法区分。
  Future<DateTime?> _computeLocalUpdatedAt(int ledgerId) async {
    final recentChange = _recentLocalChangeAt[ledgerId];
    DateTime? dbMax;
    try {
      final query = db.selectOnly(db.transactions)
        ..addColumns([db.transactions.happenedAt.max()])
        ..where(db.transactions.ledgerId.equals(ledgerId));
      final row = await query.getSingleOrNull();
      dbMax = row?.read(db.transactions.happenedAt.max());
    } catch (e) {
      logger.warning('CloudSync', '读取本地 MAX(happenedAt) 失败: $e');
    }
    if (recentChange == null) return dbMax;
    if (dbMax == null) return recentChange;
    return recentChange.isAfter(dbMax) ? recentChange : dbMax;
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    await _ensureInitialized();

    if (_syncManager == null) {
      throw fcs.CloudSyncException('云服务不可用，请检查配置或登录状态');
    }

    try {
      logger.info('CloudSync', '开始上传账本 $ledgerId');

      // 上传前先计算本地指纹（用于记录上传快照）
      String? localFp;
      int? localCount;
      try {
        final jsonStr = await exportTransactionsJson(db, ledgerId);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        localFp = _contentFingerprintFromMap(map);
        localCount = (map['count'] as num?)?.toInt();
      } catch (e) {
        logger.warning('CloudSync', '计算本地指纹失败: $e');
      }

      await _syncManager!.upload(
        data: ledgerId,
        path: _pathForLedger(ledgerId),
        metadata: {
          'version': '2',
          'uploadedAt': DateTime.now().toUtc().toIso8601String(),
          'ledgerId': ledgerId.toString(),
        },
      );

      // 记录近期上传，用于处理 CDN 缓存延迟
      if (localFp != null && localCount != null) {
        _recentUpload[ledgerId] = _RecentUpload(
          at: DateTime.now(),
          fp: localFp,
          count: localCount,
        );
        // 立即更新缓存为"已同步"状态
        _statusCache[ledgerId] = SyncStatus(
          diff: SyncDiff.inSync,
          localCount: localCount,
          localFingerprint: localFp,
          cloudCount: localCount,
          cloudFingerprint: localFp,
          cloudExportedAt: DateTime.now(),
        );
      } else {
        // 指纹计算失败，清除缓存等待下次查询
        _statusCache.remove(ledgerId);
      }

      // 清除本地变更标记
      _recentLocalChangeAt.remove(ledgerId);

      logger.info('CloudSync', '上传完成: $ledgerId');
    } catch (e, stack) {
      logger.error('CloudSync', '上传失败: $ledgerId', e);
      logger.error('CloudSync', '堆栈', stack);
      rethrow;
    }
  }

  @override
  Future<({int inserted, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
    await _ensureInitialized();

    if (_provider == null) {
      throw fcs.CloudSyncException('云服务不可用，请检查配置或登录状态');
    }

    try {
      logger.info('CloudSync', '开始下载账本 $ledgerId');

      // 直接使用 storage 下载原始 JSON 字符串
      final jsonStr =
          await _provider!.storage.download(path: _pathForLedger(ledgerId));

      if (jsonStr == null) {
        logger.warning('CloudSync', '云端备份不存在');
        return (inserted: 0, deletedDup: 0);
      }

      // 导入数据
      final result = await importTransactionsJson(repo, ledgerId, jsonStr);

      logger.info('CloudSync',
          '下载完成: inserted=${result.inserted}');

      // 清除缓存
      _statusCache.remove(ledgerId);
      _recentLocalChangeAt.remove(ledgerId);
      _recentUpload.remove(ledgerId);

      return (
        inserted: result.inserted,
        deletedDup: 0,
      );
    } catch (e, stack) {
      logger.error('CloudSync', '下载失败: $ledgerId', e);
      logger.error('CloudSync', '堆栈', stack);

      // 如果是 404,返回空结果
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return (inserted: 0, deletedDup: 0);
      }

      rethrow;
    }
  }

  @override
  Future<int> pullIncremental({required int ledgerId}) async {
    if (await _isLocalOnlyLedger(ledgerId)) {
      logger.info('CloudSync', '账本 $ledgerId 为本地账本,跳过增量拉取');
      return 0;
    }
    // 快照型后端(WebDAV/S3 等)没有增量通道,退化为快照下载。
    // 导入侧(importTransactions)已按 syncId 幂等去重,重复下载只会跳过
    // 已存在的记录,不会产生重复行。
    final r = await downloadAndRestoreToCurrentLedger(ledgerId: ledgerId);
    return r.inserted;
  }

  @override
  Future<PullOutcome> pullIncrementalWithHeal({required int ledgerId}) async {
    if (await _isLocalOnlyLedger(ledgerId)) {
      logger.info('CloudSync', '账本 $ledgerId 为本地账本,跳过自愈拉取');
      return const PullOutcome(incremental: 0);
    }
    // 快照型后端的 pullIncremental 本身已退化为幂等快照下载(导入侧按
    // syncId 去重),天然具备"自愈"能力 —— 直接委托,不重复造逻辑。
    // didHeal 标记 true 表示该后端每次都做全量对账;不存在增量游标越过
    // 历史变更的场景,故 gapRemaining 恒为 false。
    final inserted = await pullIncremental(ledgerId: ledgerId);
    return PullOutcome(
      incremental: inserted,
      didHeal: true,
      gapRemaining: false,
    );
  }

  /// 下载云端数据并计算 diff 预览
  ///
  /// 返回 (preview, importData, jsonVersion) 或 null（云端无数据）
  /// - preview 为 null 表示无法计算 diff（旧格式），应走全量替换
  /// - preview 不为 null 表示可以预览
  @override
  Future<({SyncPreview? preview, ImportData importData, int version})?> downloadAndPreview({
    required int ledgerId,
  }) async {
    await _ensureInitialized();

    if (_provider == null) {
      throw fcs.CloudSyncException('云服务不可用，请检查配置或登录状态');
    }

    logger.info('CloudSync', '开始下载预览: $ledgerId');

    final jsonStr =
        await _provider!.storage.download(path: _pathForLedger(ledgerId));

    if (jsonStr == null) {
      logger.warning('CloudSync', '云端备份不存在');
      return null;
    }

    // 解析 JSON
    final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
    final version = (jsonData['version'] as num?)?.toInt() ?? 1;
    final importData = parseJsonToImportData(jsonStr);

    // 检查是否含 syncId
    if (version >= 6) {
      final preview = await syncDiffService.computeDiff(
        repo: repo,
        ledgerId: ledgerId,
        cloudTransactions: importData.transactions,
      );

      if (preview != null) {
        return (preview: preview, importData: importData, version: version);
      }
    }

    // 旧格式或无法计算 diff
    return (preview: null, importData: importData, version: version);
  }

  /// 应用预览中选中的变更
  @override
  Future<SyncApplyResult> applyPreviewChanges({
    required int ledgerId,
    required List<SyncChange> selectedChanges,
    required ImportData importData,
  }) async {
    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: ledgerId,
      selectedChanges: selectedChanges,
      importData: importData,
    );

    // 清除缓存
    _statusCache.remove(ledgerId);
    _recentLocalChangeAt.remove(ledgerId);
    _recentUpload.remove(ledgerId);

    return result;
  }

  @override
  bool get supportsDiffPreview => true;

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    // 纯本地账本(不上云)直接返回 localOnly:快照型后端只备份云端账本,
    // 本地账本若走云侧对比会永远显示"本地有数据、云端没有"的假差异。
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    if (ledgerRow != null &&
        ledgerRow.isLocalLedger &&
        (ledgerRow.syncId == null || ledgerRow.syncId!.isEmpty)) {
      final status = SyncStatus(
        diff: SyncDiff.localOnly,
        localCount: 0,
        localFingerprint: '',
      );
      _statusCache[ledgerId] = status;
      return status;
    }

    await _ensureInitialized();

    // 如果 provider 不可用，返回未登录状态
    if (_syncManager == null || _provider == null) {
      return SyncStatus(
        diff: SyncDiff.notLoggedIn,
        localCount: 0,
        localFingerprint: '',
        message: '云服务不可用，请检查配置或登录状态',
      );
    }

    // 检查缓存
    final cached = _statusCache[ledgerId];
    if (cached != null) {
      logger.info('Sync', '缓存命中: ledgerId=$ledgerId, diff=${cached.diff}');
      return cached;
    }

    logger.info('Sync', '缓存未命中，开始计算: ledgerId=$ledgerId');

    try {
      // 计算本地指纹
      final jsonStr = await exportTransactionsJson(db, ledgerId);
      final localMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final localFp = _contentFingerprintFromMap(localMap);
      final localCount = (localMap['count'] as num).toInt();

      // 若刚刚上传成功且在短时间窗口内（15秒），且本地指纹与上传时一致，直接认定已同步
      // 权衡：窗口期只是 CDN 缓存延迟补偿，指纹已覆盖全字段快照契约
      // （币种/折算/统计排除/AA 等），因此不会掩盖真实差异；窗口内若真有
      // 远端变更，15 秒后下一次 getStatus 会做真实云侧校验并纠正。
      final ru = _recentUpload[ledgerId];
      if (ru != null) {
        final age = DateTime.now().difference(ru.at);
        if (age < const Duration(seconds: 15) && ru.fp == localFp) {
          final st = SyncStatus(
            diff: SyncDiff.inSync,
            localCount: localCount,
            localFingerprint: localFp,
            cloudCount: ru.count,
            cloudFingerprint: ru.fp,
            cloudExportedAt: ru.at,
          );
          _statusCache[ledgerId] = st;
          logger.info('CloudSync', '使用近期上传缓存: $ledgerId -> 已同步');
          return st;
        }
      }

      logger.info('CloudSync', '获取同步状态: $ledgerId');

      // 调用包的 getStatus，传入时间戳用于方向判断
      final fcsStatus = await _syncManager!.getStatus(
          data: ledgerId,
          path: _pathForLedger(ledgerId),
          localUpdatedAt: await _computeLocalUpdatedAt(ledgerId),
          forceRefresh: true);

      // 转换包的 SyncStatus 为 Spitout 的 SyncStatus
      final status = _convertSyncStatus(fcsStatus);

      _statusCache[ledgerId] = status;
      logger.info('CloudSync', '同步状态: $ledgerId -> ${status.diff}');
      logger.debug('CloudSync', '本地指纹: ${status.localFingerprint}');
      logger.debug('CloudSync', '云端指纹: ${status.cloudFingerprint ?? "无"}');
      logger.debug('CloudSync', '本地数量: ${status.localCount}, 云端数量: ${status.cloudCount ?? "无"}');

      return status;
    } catch (e, stack) {
      logger.error('CloudSync', '获取状态失败: $ledgerId', e);
      logger.error('CloudSync', '堆栈: $stack', null);

      // 返回错误状态
      final status = SyncStatus(
        diff: SyncDiff.error,
        localCount: 0,
        localFingerprint: '',
        message: e.toString(),
      );

      _statusCache[ledgerId] = status;

      return status;
    }
  }

  /// 转换包的 SyncStatus 为 Spitout 的 SyncStatus
  SyncStatus _convertSyncStatus(fcs.SyncStatus fcsStatus) {
    SyncDiff diff;

    switch (fcsStatus.state) {
      case fcs.SyncState.notConfigured:
        diff = SyncDiff.notConfigured;
        break;
      case fcs.SyncState.notAuthenticated:
        diff = SyncDiff.notLoggedIn;
        break;
      case fcs.SyncState.localOnly:
        diff = SyncDiff.noRemote;
        break;
      case fcs.SyncState.synced:
        diff = SyncDiff.inSync;
        break;
      case fcs.SyncState.outOfSync:
        // 根据方向确定
        if (fcsStatus.direction == fcs.SyncDirection.localNewer) {
          diff = SyncDiff.localNewer;
        } else if (fcsStatus.direction == fcs.SyncDirection.cloudNewer) {
          diff = SyncDiff.cloudNewer;
        } else {
          diff = SyncDiff.different;
        }
        break;
      case fcs.SyncState.error:
        diff = SyncDiff.error;
        break;
      default:
        diff = SyncDiff.different;
    }

    return SyncStatus(
      diff: diff,
      localCount: fcsStatus.localCount ?? 0,
      cloudCount: fcsStatus.cloudCount,
      localFingerprint: fcsStatus.localFingerprint ?? '',
      cloudFingerprint: fcsStatus.cloudFingerprint,
      cloudExportedAt: fcsStatus.cloudUpdatedAt,
      message: fcsStatus.message,
    );
  }

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async {
    await _ensureInitialized();

    try {
      logger.info('CloudSync', '刷新云端指纹: $ledgerId');

      // 强制刷新状态
      final status = await _syncManager!.getStatus(
        data: ledgerId,
        path: _pathForLedger(ledgerId),
        localUpdatedAt: await _computeLocalUpdatedAt(ledgerId),
        forceRefresh: true,
      );

      // 清除缓存以便下次 getStatus 重新获取
      _statusCache.remove(ledgerId);

      logger.info('CloudSync',
          '云端指纹: 指纹=${status.cloudFingerprint} 条数=${status.cloudCount} 时间=${status.cloudUpdatedAt}');

      return (
        fingerprint: status.cloudFingerprint,
        count: status.cloudCount,
        exportedAt: status.cloudUpdatedAt,
      );
    } catch (e) {
      logger.warning('CloudSync', '刷新云端指纹失败: $ledgerId - $e');
      return (fingerprint: null, count: null, exportedAt: null);
    }
  }

  @override
  void markLocalChanged({required int ledgerId}) {
    _statusCache.remove(ledgerId);
    _recentLocalChangeAt[ledgerId] = DateTime.now();
    logger.info('CloudSync', '标记本地变更: $ledgerId');
  }

  @override
  Future<void> deleteRemoteBackup({required int ledgerId}) async {
    await _ensureInitialized();

    if (_syncManager == null) {
      throw fcs.CloudSyncException('云服务不可用，请检查配置或登录状态');
    }

    try {
      logger.info('CloudSync', '删除云端备份: $ledgerId');

      await _syncManager!.deleteRemote(path: _pathForLedger(ledgerId));

      // 清除缓存
      _statusCache.remove(ledgerId);
      _recentLocalChangeAt.remove(ledgerId);
      _recentUpload.remove(ledgerId);

      logger.info('CloudSync', '删除完成: $ledgerId');
    } catch (e) {
      // 忽略 404 错误
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        logger.warning('CloudSync', '云端备份不存在（忽略）: $ledgerId');
        return;
      }

      logger.error('CloudSync', '删除失败: $ledgerId', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteLedgerGlobally(int ledgerId) async {
    // 三步收敛:远端删 → 本地删 → 清 change。顺序不可调换 ——
    // 远端删除必须在本地行删除之前(本行仍在才能确认账本存在);
    // 清 change 必须在本地删之后,抹掉 deleteLedger 登记的残留变更,
    // 避免同步协调器把「已删账本」的 change 再推向云端(快照复活)。
    // 注意:全程不触发 PostProcessor.sync。
    try {
      // Step 1: 删除云端备份文件(内部已忽略 404,幂等)。
      // 若远端删除因网络/鉴权失败会抛出,直接中断 —— 本地不能先删,
      // 否则云端残留快照会在后续同步中把账本复活。
      await deleteRemoteBackup(ledgerId: ledgerId);

      // Step 2: 删本地行(级联删交易;会向 local_changes 登记 delete change)。
      await repo.deleteLedger(ledgerId);

      // Step 3: 抹掉 Step 2 登记的残留 change,云端文件已删,无需再推。
      await repo.clearLocalChangesForLedger(ledgerId);

      logger.info('CloudSync', 'deleteLedgerGlobally($ledgerId) 完成');
    } catch (e, st) {
      logger.error('CloudSync', '全局删除账本失败 ledgerId=$ledgerId', e, st);
      rethrow;
    }
  }

  /// 刷新所有账本的同步状态（后台预热缓存）
  Future<void> refreshAllLedgersStatus() async {
    await _ensureInitialized();

    try {
      final ledgers = await db.select(db.ledgers).get();

      for (final ledger in ledgers) {
        try {
          await getStatus(ledgerId: ledger.id);
        } catch (e) {
          logger.warning('CloudSync', '刷新账本 ${ledger.id} 状态失败: $e');
        }
      }

      logger.info('CloudSync', '已刷新 ${ledgers.length} 个账本的同步状态');
    } catch (e) {
      logger.error('CloudSync', '刷新所有账本状态失败', e);
    }
  }

}

/// 账本交易数据序列化器
class _TransactionSerializer implements fcs.DataSerializer<int> {
  final SpitoutDatabase db;

  _TransactionSerializer(this.db);

  @override
  Future<String> serialize(int ledgerId) async {
    return await exportTransactionsJson(db, ledgerId);
  }

  @override
  Future<int> deserialize(String data) async {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return json['ledgerId'] as int;
  }

  @override
  String fingerprint(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return _contentFingerprintFromMap(json);
  }
}

/// 从快照 JSON payload 计算内容指纹（全字段快照契约）。
///
/// 快照栈用指纹判定“本地/云端是否一致”，必须覆盖币种、折算金额、
/// 统计排除、支出人与 AA 分摊字段——否则其他设备只改这些字段时，
/// 本端会静默判定“已同步”并保留旧值。
String _contentFingerprintFromMap(Map<String, dynamic> payload) {
  final items = (payload['items'] as List).cast<Map<String, dynamic>>();
  final canon = items
      .map((it) {
        final type = it['type'] as String? ?? '';
        return {
          'syncId': it['syncId'] as String? ?? '',
          'happenedAt': it['happenedAt'] as String? ?? '',
          'type': type,
          'amount': (it['amount'] as num?)?.toDouble().toString() ?? '0.0',
          'categoryName': it['categoryName'] as String? ?? '',
          'categoryKind': it['categoryKind'] as String? ?? '',
          'note': it['note'] as String? ?? '',
          'currencyCode': it['currencyCode'] as String? ?? '',
          'nativeAmount':
              (it['nativeAmount'] as num?)?.toDouble().toString() ?? '',
          'excludeFromStats':
              (it['excludeFromStats'] as bool? ?? false).toString(),
          'createdByUserId': it['createdByUserId'] as String? ?? '',
          'paidByUserId': it['paidByUserId'] as String? ?? '',
          'aaMode': (it['aaMode'] as num?)?.toString() ?? '',
          'aaParticipants': it['aaParticipants'] as String? ?? '',
          'aaSplits': it['aaSplits'] as String? ?? '',
        };
      })
      .toList();
  canon.sort((a, b) {
    final c1 =
        (a['happenedAt'] as String).compareTo(b['happenedAt'] as String);
    if (c1 != 0) return c1;
    final c2 = (a['syncId'] as String).compareTo(b['syncId'] as String);
    if (c2 != 0) return c2;
    final c3 = (a['type'] as String).compareTo(b['type'] as String);
    if (c3 != 0) return c3;
    final c4 = (a['amount'] as String).compareTo(b['amount'] as String);
    if (c4 != 0) return c4;
    final c5 =
        (a['categoryName'] as String).compareTo(b['categoryName'] as String);
    if (c5 != 0) return c5;
    return (a['categoryKind'] as String)
        .compareTo(b['categoryKind'] as String);
  });
  final bytes = utf8.encode(jsonEncode(canon));
  final fp = sha256.convert(bytes).toString();
  logger.debug(
      'Fingerprint', '交易数: ${canon.length}, 指纹: ${fp.substring(0, 16)}...');
  return fp;
}

/// 近期上传记录（用于处理 CDN 缓存延迟）
class _RecentUpload {
  final DateTime at;
  final String fp;
  final int count;

  _RecentUpload({
    required this.at,
    required this.fp,
    required this.count,
  });
}
