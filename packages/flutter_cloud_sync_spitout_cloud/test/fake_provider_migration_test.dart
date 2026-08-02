/// c8(fake 测试基建自包含)迁移验收用例。
///
/// 背景:主仓 `test/cloud/sync/_fakes/fake_spitout_cloud_provider.dart` 已迁移至
/// 本 adapter 包 `lib/src/testing/fake_spitout_cloud_provider.dart`,并经由
/// `lib/testing.dart`(仿 `package:http/testing.dart` 模式)作为正式 testing 入口
/// 随包分发 —— 消费方拿到本包即可独立跑测,无需依赖宿主工程 test/ 目录。
///
/// 本文件即"迁移用例":在新包 test/ 内直接验证迁移产物可用、行为未漂移,
/// 使 fake 正确性由新包内测试兜底,而非仅靠主仓 e2e 间接覆盖。覆盖:
///   1. 自包含性:仅通过 testing.dart 导入即可实例化 fake,不触碰宿主工程;
///   2. 核心能力:pull/push 切片、账本枚举、退出/删除、storage(fullPush JSON)、
///      自愈 stats 推导、写账本、realtime、reset。
library;

import 'dart:async';

import 'package:flutter_cloud_sync_spitout_cloud/flutter_cloud_sync_spitout_cloud.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('自包含性 & 构造(c8 验收)', () {
    test('仅通过 testing.dart 入口即可实例化,无需宿主工程依赖', () {
      final fake = FakeSpitoutCloudProvider();
      expect(fake, isA<SpitoutCloudProvider>());
      expect(fake.baseUrl, 'https://fake.test');
      expect(fake.apiPrefix, '/api/v1');
    });

    test('默认注入测试用户;自定义 userId/deviceId;登出后身份置空', () async {
      final fake = FakeSpitoutCloudProvider();
      expect((await fake.auth.currentUser)?.id, 'test-user-id');
      final auth = fake.auth as FakeSpitoutCloudAuthService;
      expect(auth.currentUserId, 'test-user-id');
      expect(auth.currentDeviceId, 'test-device-id');

      final custom = FakeSpitoutCloudProvider(userId: 'u-9', deviceId: 'd-9');
      expect((await custom.auth.currentUser)?.id, 'u-9');

      auth.setLoggedIn(userId: null, deviceId: null);
      expect(await fake.auth.currentUser, isNull);
      expect(auth.currentUserId, isNull);
    });
  });

  group('pull/push 同步语义(迁移后切片行为)', () {
    test('空 server:0 changes,cursor 回退 since;push 后按 since 切片', () async {
      final fake = FakeSpitoutCloudProvider();
      final empty = await fake.pullChanges(since: 0);
      expect(empty.changes, isEmpty);
      expect(empty.serverCursor, 0);

      fake.pushFakeChange(entitySyncId: 'tx-1', ledgerId: 'L1');
      fake.pushFakeChange(entitySyncId: 'tx-2', ledgerId: 'L1');
      fake.pushFakeChange(entitySyncId: 'cat-1', entityType: 'category');
      final all = await fake.pullChanges(since: 0);
      expect(all.changes, hasLength(3));
      expect(all.serverCursor, 3);
      final delta = await fake.pullChanges(since: 1);
      expect(delta.changes.map((c) => c.changeId), [2, 3]);
    });

    test('limit 分页 hasMore 正确可续拉;pullCalls 记录调用序列', () async {
      final fake = FakeSpitoutCloudProvider();
      fake.pushFakeChange(entitySyncId: 'tx-1');
      fake.pushFakeChange(entitySyncId: 'tx-2');
      final page1 = await fake.pullChanges(since: 0, limit: 1);
      expect(page1.changes.map((c) => c.changeId), [1]);
      expect(page1.hasMore, isTrue);
      final page2 =
          await fake.pullChanges(since: page1.serverCursor, limit: 1);
      expect(page2.hasMore, isFalse);
      final call = fake.pullCalls.last;
      expect(call.since, 1);
      expect(call.limit, 1);
    });

    test('pushChanges 记录 pushedBatches;pullErrorInjector 注入错误', () async {
      final fake = FakeSpitoutCloudProvider();
      await fake.pushChanges(changes: [
        {'entity_sync_id': 'tx-1'},
      ]);
      expect(fake.pushedBatches, hasLength(1));
      expect(fake.pushedBatches.single.single['entity_sync_id'], 'tx-1');

      fake.pullErrorInjector = (since) => Exception('pull down @ $since');
      await expectLater(
        fake.pullChanges(since: 7),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('pull down @ 7'),
        )),
      );
    });
  });

  group('账本枚举 / 退出 / 删除', () {
    test('pushFakeLedger + readLedgers;错误注入抛错', () async {
      final fake = FakeSpitoutCloudProvider();
      fake.pushFakeLedger(ledgerId: 'L1', ledgerName: '家庭账本', isShared: true);
      fake.pushFakeLedger(ledgerId: 'L2', monthStartDay: 15);
      final ledgers = await fake.readLedgers();
      expect(ledgers.map((l) => l.ledgerId), ['L1', 'L2']);
      expect(ledgers[0].isShared, isTrue);
      expect(ledgers[1].monthStartDay, 15);

      fake.readLedgersErrorInjector = () => Exception('server offline');
      await expectLater(
        fake.readLedgers(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('server offline'),
        )),
      );
    });

    test('leaveLedger 摘除并记录;deleteLedger 成功/失败(fail-closed)', () async {
      final fake = FakeSpitoutCloudProvider();
      fake.pushFakeLedger(ledgerId: 'L1');
      await fake.leaveLedger(ledgerId: 'L1');
      expect(fake.leaveLedgerCalls, ['L1']);
      expect(await fake.readLedgers(), isEmpty);

      // 成功:副作用钩子执行 + 级联摘除
      fake.pushFakeLedger(ledgerId: 'L2');
      final echoes = <String>[];
      fake.deleteLedgerSideEffect = () async => echoes.add('removed-echo');
      await fake.deleteLedger(ledgerId: 'L2');
      expect(fake.deleteLedgerCalls, ['L2']);
      expect(echoes, ['removed-echo']);
      expect(await fake.readLedgers(), isEmpty);

      // 失败:server 侧删除失败,账本必须保留(fail-closed)
      fake.pushFakeLedger(ledgerId: 'L3');
      fake.deleteLedgerErrorInjector = () => Exception('server refused');
      await expectLater(
        fake.deleteLedger(ledgerId: 'L3'),
        throwsA(isA<Exception>()),
      );
      expect(await fake.readLedgers(), isNotEmpty);
    });
  });

  group('storage(fullPush JSON) & 自愈 stats', () {
    test('upload/download/delete/exists;snapshot 列表 + 错误注入', () async {
      final fake = FakeSpitoutCloudProvider();
      await fake.storage.upload(
        path: 'ledgers/L1/full.json',
        data: '{"name":"家庭账本"}',
        metadata: const {'type': 'fullPush'},
      );
      expect(await fake.storage.download(path: 'ledgers/L1/full.json'),
          '{"name":"家庭账本"}');
      expect(await fake.storage.exists(path: 'ledgers/L1/full.json'), isTrue);
      await fake.storage.delete(path: 'ledgers/L1/full.json');
      expect(await fake.storage.download(path: 'ledgers/L1/full.json'), isNull);

      fake.pushFakeLedgerSnapshot(ledgerId: 'L1');
      expect((await fake.storage.list(path: '')).single.path, 'L1');
      fake.storageListError = Exception('list down');
      await expectLater(
        fake.storage.list(path: ''),
        throwsA(isA<Exception>()),
      );
    });

    test('readLedgerStats 推导存活实体;failingReadLedgerStats 抛错', () async {
      final fake = FakeSpitoutCloudProvider();
      // L1:tx-1 upsert → tx-2 upsert → tx-1 delete → 存活 tx-2
      fake.pushFakeChange(entitySyncId: 'tx-1', ledgerId: 'L1');
      fake.pushFakeChange(entitySyncId: 'tx-2', ledgerId: 'L1');
      fake.pushFakeChange(
        entitySyncId: 'tx-1',
        ledgerId: 'L1',
        action: 'delete',
      );
      fake.pushFakeChange(entitySyncId: 'tx-3', ledgerId: 'L2');
      fake.pushFakeChange(entitySyncId: 'cat-1', entityType: 'category');
      fake.pushFakeChange(
        entitySyncId: 'cat-1',
        entityType: 'category',
        action: 'delete',
      );

      final stats = await fake.readLedgerStats(ledgerId: 'L1');
      expect(stats.transactionCount, 1);
      expect(stats.transactionTotal, 2);
      expect(stats.categoryCount, 0);

      fake.failingReadLedgerStats = true;
      await expectLater(
        fake.readLedgerStats(ledgerId: 'L1'),
        throwsA(isA<Exception>()),
      );
      expect(fake.readLedgerStatsCalls, greaterThanOrEqualTo(2));
    });
  });

  group('写账本(fullPush) / realtime / reset', () {
    test('writeCreateLedger + autoRegister 二次确认;gate 阻塞闸门', () async {
      final fake = FakeSpitoutCloudProvider()..autoRegisterWrittenLedgers = true;
      final meta = await fake.writeCreateLedger(
        ledgerId: 'new-1',
        ledgerName: '新账本',
        currency: 'USD',
      );
      expect(meta.ledgerId, 'new-1');
      expect(fake.writeCreateLedgerCalls, hasLength(1));
      // 模拟真实 server:建完账本立刻出现在 readLedgers 列表(moveToCloud 二次确认)
      expect((await fake.readLedgers()).single.ledgerId, 'new-1');

      // gate:模拟 fullPush 卡在 writeCreateLedger 的 in-flight 场景
      final gate = Completer<void>();
      fake.writeCreateLedgerGate = gate;
      final pending = fake.writeCreateLedger(ledgerName: '卡住');
      await Future<void>.delayed(Duration.zero);
      expect(fake.writeCreateLedgerCalls, hasLength(1),
          reason: 'gate 未放行前应阻塞');
      gate.complete();
      await pending;
      expect(fake.writeCreateLedgerCalls, hasLength(2));
    });

    test('getMyProfile 返回空 profile(不炸);realtime 事件收发', () async {
      final fake = FakeSpitoutCloudProvider();
      final profile = await fake.getMyProfile();
      expect(profile.userId, 'test-user-id');

      final events = <SpitoutCloudRealtimeEvent>[];
      final sub = fake.realtimeEvents.listen(events.add);
      fake.emitRealtimeEvent(
        const SpitoutCloudRealtimeEvent(
          type: 'sync_change',
          ledgerId: 'L1',
          serverCursor: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.single.type, 'sync_change');
      expect(events.single.serverCursor, 5);
      await sub.cancel();
    });

    test('reset() 清空 server 状态与全部错误注入', () async {
      final fake = FakeSpitoutCloudProvider();
      fake.pushFakeChange(entitySyncId: 'tx-1');
      fake.pushFakeLedger(ledgerId: 'L1');
      fake.pushFakeLedgerSnapshot(ledgerId: 'L1');
      await fake.pushChanges(changes: [
        {'a': 1},
      ]);
      fake.pullErrorInjector = (since) => Exception('x');
      fake.storageListError = Exception('x');
      fake.readLedgersErrorInjector = () => Exception('x');

      fake.reset();
      expect(fake.pullCalls, isEmpty);
      expect(fake.pushedBatches, isEmpty);
      expect(fake.pullErrorInjector, isNull);
      expect(fake.storageListError, isNull);
      expect(fake.readLedgersErrorInjector, isNull);
      expect((await fake.pullChanges()).changes, isEmpty);
      expect(await fake.readLedgers(), isEmpty);
      expect(await fake.storage.list(path: ''), isEmpty);
    });
  });
}
