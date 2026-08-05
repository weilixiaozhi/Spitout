/// DEEP 方案红测试:云同步页 refresh 不再依赖 currentLedgerIdProvider。
///
/// 覆盖两项根因修复:
/// 1. 云端账本枚举降为私有 `_queryCloudLedgers`,外部统一走账户级入口 ——
///    checkAccountHealth 自选载体(第一个云账本);验证"仅 storage_mode=='cloud'
///    (或 isShared)且 syncId 非空的账本算云端账本"与"无云端账本 → null
///    (UI 展示「暂无云端账本」)"。(红:公开方法移除 → 测试编译失败;
///    绿:checkAccountHealth 载体自选正确 / 返回 null)
/// 2. [SyncEngine.checkLedgerHealth] 删除 `?? ledger.id.toString()` 兜底 ——
///    无 syncId 的本地账本不得用本地 id 拼 server 路径发起 stats 请求,
///    必须直接判定检测失败。(红:现在会调用 readLedgerStats → 计数>0;
///    绿:直接 error 且 stats 计数保持 0)
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart'
    show SpitoutCloudLedgerStats;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/cloud/sync/sync_engine.dart';
import 'package:spitout/cloud/sync/change_tracker.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';

import '../../helpers/test_isolation.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';

Future<(SpitoutDatabase, ChangeTracker, LocalRepository, FakeSpitoutCloudProvider,
    SyncEngine)> _harness() async {
  final db = SpitoutDatabase.forTesting(NativeDatabase.memory());
  final changeTracker = ChangeTracker(db);
  final repo = LocalRepository(db, changeTracker: changeTracker);
  final provider = FakeSpitoutCloudProvider();
  final engine = SyncEngine(
    db: db,
    provider: provider,
    changeTracker: changeTracker,
    repo: repo,
  );
  return (db, changeTracker, repo, provider, engine);
}

void main() {
  setUp(() {
    resetGlobalTestState();
    SharedPreferences.setMockInitialValues({});
  });

  group('云端账本枚举降私有(账户级内部锚点自选)', () {
    test('仅 storageMode=cloud 且 syncId 非空的账本会被自选为 stats 锚点', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      // cloud + syncId → 应被选为内部锚点
      await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Cloud 1',
              syncId: const Value('ledger-1'),
              storageMode: const Value('cloud'),
            ),
          );
      // 本地账本 → 排除
      await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Local 1',
              syncId: const Value(null),
              storageMode: const Value('local'),
            ),
          );
      // cloud 但 syncId 为空 → 排除(从未同步过,无法 push/stats)
      await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Cloud NoSync',
              syncId: const Value(null),
              storageMode: const Value('cloud'),
            ),
          );

      provider.ledgerStatsOverrides['ledger-1'] = const SpitoutCloudLedgerStats(
        transactionCount: 0,
        transactionTotal: 0,

        categoryCount: 0,
        categoryTotal: 0,
      );

      final report = await engine.checkAccountHealth();
      expect(report, isNotNull);
      // 自选锚点确实生效:唯一合格账本(cloud + syncId 非空)的 stats 被打到了,
      // 本地账本与 syncId 空的云账本都没被选中(否则 Fake 会因缺 override 抛错)。
      expect(provider.readLedgerStatsCalls, 1);
      expect(report!.error, isNull);
      // 但锚点是内部工程细节,不外泄:carrierLedgerId 只在调用方显式指定
      // 当前选中的云账本时才回填。
      expect(report.carrierLedgerId, isNull,
          reason: 'id 升序自选无用户语义,绝不外泄为 carrierLedgerId');
    });

    test('无云端账本 → checkAccountHealth 返回 null(供 UI「暂无云端账本」)', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Local',
              storageMode: const Value('local'),
            ),
          );

      final report = await engine.checkAccountHealth();
      expect(report, isNull,
          reason: '没有任何云端账本时,账户级检查返回 null,UI 展示「暂无云端账本」');
      expect(provider.readLedgerStatsCalls, 0,
          reason: '无载体账本不发起任何 stats 请求');
    });
  });

  group('checkLedgerHealth 删除 syncId 兜底(DEEP)', () {
    test('本地无 syncId 账本 → 直接 error,不发起 readLedgerStats 请求', () async {
      final (db, _, _, provider, engine) = await _harness();
      addTearDown(db.close);

      final localId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Local',
              storageMode: const Value('local'),
            ),
          );

      final report = await engine.checkLedgerHealth(ledgerId: localId);
      expect(report.error, isNotNull,
          reason: '无 syncId 的账本应判定健康检测失败(本地账本未同步到云端)');
      expect(provider.readLedgerStatsCalls, 0,
          reason: '无 syncId 时不得用本地 id 拼 server 路径发起 stats 请求(删兜底)');
    });
  });
}
