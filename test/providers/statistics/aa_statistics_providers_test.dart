// aa_statistics_providers 其余 provider 测试（本地/单人账本分支）。
//
// 需求锚点：
//   1. aaEnabledProvider 反映 ledger.aaEnabled 流；
//   2. setAaEnabled / 虚拟用户 CRUD 走 repository 并失效率刷新；失败向上抛；
//   3. currentOperatorIdForLedger：本地账本回退 localSelfId，云端账本返回云 userId；
//   4. aaParticipantOptionsProvider：单人账本把 owner（或 localSelfId 兜底）纳入参与人，并追加虚拟用户；
//   5. aaStatisticsProvider：AA 关闭返回空汇总；开启后含参与人/虚拟用户；
//   6. aaParticipantAvatarContextProvider：本地账本返回空上下文；
//   7. aaMemberDetailProvider：非 AA 或成员缺失返回 null。

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_isolation.dart';
import 'package:flutter_cloud_sync_spitout_cloud/testing.dart';
import 'package:spitout/data/db.dart';
import 'package:spitout/data/repositories/base_repository.dart';
import 'package:spitout/data/repositories/local/local_repository.dart';
import 'package:spitout/core/logging/logger_service.dart';
import 'package:spitout/providers/providers.dart';

class _MockRepo extends Mock implements BaseRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => resetGlobalTestState());

  late SpitoutDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = SpitoutDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await repo.createLedger(
      name: 'AA账本',
      storageMode: 'local',
      ownerUserId: 'u-owner',
      aaEnabled: true,
    );
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      spitoutCloudProviderInstance.overrideWith((ref) async => null),
      localSelfIdProvider.overrideWith((ref) async => 'local-self'),
      currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() async => db.close());

  /// 通过 Consumer 捕获与容器绑定的 WidgetRef（动作函数参数）。
  Future<WidgetRef> captureRef(WidgetTester tester, ProviderContainer c) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const Placeholder();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return captured;
  }

  test('aaEnabledProvider 反映账本开关', () async {
    final enabled = await readProviderFutureFromContainer(
      container,
      aaEnabledProvider.future,
    );
    expect(enabled, isTrue);
    // 开关联动由 repo.watchLedger 流语义保证，此处锁定首帧即可。
  });

  testWidgets('虚拟用户 CRUD 走 repository', (tester) async {
    final ref = await captureRef(tester, container);
    final id = await createVirtualUser(
      ref,
      ledgerId: 1,
      name: '小明',
    );
    expect(id, greaterThan(0));

    await renameVirtualUser(ref, id: id, name: '小红');
    final users = await repo.getByLedger(1);
    expect(users.single.name, '小红');

    await deleteVirtualUser(ref, id);
    expect(await repo.getByLedger(1), isEmpty);
  });

  testWidgets('currentOperatorIdForLedger：本地账本回退 localSelfId', (tester) async {
    final ref = await captureRef(tester, container);
    expect(await currentOperatorIdForLedger(ref, 1), 'local-self');
  });

  testWidgets('currentOperatorIdForLedger：云端账本返回缓存的云 userId', (tester) async {
    final cloudLedgerId = await repo.createLedger(
      name: '云端账本',
      storageMode: 'cloud',
      ownerUserId: 'cloud-owner',
    );
    final cloudContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        spitoutCloudProviderInstance.overrideWith(
          (ref) async => FakeSpitoutCloudProvider(userId: 'cloud-user-1'),
        ),
        localSelfIdProvider.overrideWith((ref) async => 'local-self'),
        currentLedgerIdProvider.overrideWithBuild((ref, notifier) => 1),
      ],
    );
    addTearDown(cloudContainer.dispose);
    final ref = await captureRef(tester, cloudContainer);
    expect(
      await currentOperatorIdForLedger(ref, cloudLedgerId),
      'cloud-user-1',
    );
  });

  test('aaParticipantOptionsProvider：单人账本含 owner 与虚拟用户', () async {
    await repo.create(ledgerId: 1, name: '虚拟A');
    final options = await container.read(aaParticipantOptionsProvider(1).future);

    expect(options.any((o) => o.id == 'u-owner' && !o.isVirtual), isTrue,
        reason: 'owner 自动纳入参与人');
    expect(options.any((o) => o.name == '虚拟A' && o.isVirtual), isTrue);
  });

  test('aaStatisticsProvider：AA 关闭返回空汇总，开启后含参与人', () async {
    final empty = await container.read(aaStatisticsProvider(1).future);
    expect(empty.participants, isNotEmpty, reason: '开启 AA 且含 owner');

    await repo.updateLedger(id: 1, aaEnabled: false);
    container.invalidate(aaStatisticsProvider(1));
    final closed = await container.read(aaStatisticsProvider(1).future);
    expect(closed.participants, isEmpty);
  });

  test('aaParticipantAvatarContextProvider：本地账本空上下文', () async {
    final ctx = await container.read(
      aaParticipantAvatarContextProvider(1).future,
    );
    expect(ctx.members, isEmpty);
  });

  test('aaMemberDetailProvider：非 AA 账本返回 null', () async {
    await repo.updateLedger(id: 1, aaEnabled: false);
    final detail = await container.read(
      aaMemberDetailProvider((ledgerId: 1, participantId: 'u-owner')).future,
    );
    expect(detail, isNull);
  });

  testWidgets('setAaEnabled 失败向上抛', (tester) async {
    final mock = _MockRepo();
    when(
      () => mock.updateLedger(
        id: any(named: 'id'),
        aaEnabled: any(named: 'aaEnabled'),
      ),
    ).thenThrow(Exception('db down'));
    final c2 = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(mock),
        // setAaEnabled 会 invalidate currentLedgerProvider；给确定流避免失效重建炸掉。
        currentLedgerProvider.overrideWith(
          (ref) => Stream<Ledger?>.value(null),
        ),
      ],
    );
    addTearDown(c2.dispose);
    final ref2 = await captureRef(tester, c2);

    expect(
      setAaEnabled(ref2, 1, true),
      throwsException,
    );
    // logger.error 触发落盘定时器，清空取消避免残留 pending timer。
    await logger.clear();
  });
}
